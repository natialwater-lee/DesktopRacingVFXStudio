extends RefCounted

const VfxAnchorEditorModel := preload("res://src/editor/inspector/vfx_anchor_editor.gd")
const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPresetInspectorModel := preload("res://src/editor/inspector/vfx_preset_inspector.gd")
const VfxLayerInspectorModel := preload("res://src/editor/inspector/vfx_layer_inspector.gd")


static func run(tests: TestAssert) -> void:
	var editor := VfxAnchorEditorModel.new()
	var host := Control.new()
	host.add_child(editor)
	var committed: Array = []
	var cleared: Array = []
	editor.anchors_committed.connect(func(anchors: Array) -> void: committed.append(anchors))
	editor.anchors_cleared.connect(func() -> void: cleared.append(true))
	editor.set_schema(_schema_fixture())
	editor.set_effective_space("VEHICLE_LOCAL")
	tests.expect_true(editor.is_visible(), "vehicle space shows Anchors")
	editor.commit_selection(["CENTER", "TIRE_RL"])
	tests.expect_true(editor.selected_anchors() == ["CENTER", "TIRE_RL"], "multiple Anchors are retained")
	tests.expect_true(committed == [["CENTER", "TIRE_RL"]], "vehicle Anchor selection emits one filtered multi-select commit")
	editor.commit_selection([])
	tests.expect_true(editor.selected_anchors() == ["CENTER", "TIRE_RL"] and committed.size() == 1, "normal vehicle editing retains at least one Anchor")
	editor.set_effective_space("WORLD_AREA")
	tests.expect_true(not editor.is_visible(), "world space hides Anchors")
	tests.expect_true(editor.selected_anchors().is_empty(), "world space clears Anchors")
	tests.expect_true(cleared.is_empty(), "refreshing a non-vehicle Anchor view is passive")
	host.free()
	_test_anchor_space_commits(tests)
	_test_default_space_commit_normalizes_inheriting_layers(tests, "WORLD_AREA")
	_test_default_space_commit_normalizes_inheriting_layers(tests, "SCREEN_UI")
	_test_default_space_commit_adds_vehicle_defaults(tests)


static func _test_anchor_space_commits(tests: TestAssert) -> void:
	var controller := VfxEditorControllerModel.new()
	var created := controller.create_new_preset("utility.anchors", "Anchors", "UTILITY", "ONE_SHOT", "VEHICLE_LOCAL")
	tests.expect_true(created.success, "controller creates a vehicle-space Preset for Anchor commits")
	if not created.success:
		return
	controller.add_active_layer("GLOW")
	var layer_id: String = controller.working_preset()["phases"]["one_shot"]["layers"][0]["id"]
	controller.select_layer(layer_id)
	controller.clear_selected_layer_anchors()
	tests.expect_true(_has_issue(controller.current_issues(), "vehicle_anchor_required"), "committing a vehicle Layer without Anchors refreshes the existing Contract issue")
	controller.undo()
	controller.set_selected_layer_space_override("WORLD_AREA")
	var layer: Dictionary = controller.working_preset()["phases"]["one_shot"]["layers"][0]
	var allowed_planes: Array = _render_rule(_loaded_registry().schema())["allowed_planes_by_space"]["WORLD_AREA"]
	tests.expect_true(not layer.has("anchors") and allowed_planes.has(layer.get("render_plane")), "world Space Mode removes Anchors and selects a Schema-permitted render plane before validation")
	tests.expect_true(not _has_issue(controller.current_issues(), "anchor_not_allowed") and not _has_issue(controller.current_issues(), "render_plane_for_space"), "world Space Mode common commit leaves no stale Anchor or render-plane issue")
	controller.undo()
	var restored: Dictionary = controller.working_preset()["phases"]["one_shot"]["layers"][0]
	tests.expect_true(not restored.has("space_mode") and restored.has("anchors"), "one undo restores the complete prior effective-space common state")


static func _test_default_space_commit_normalizes_inheriting_layers(tests: TestAssert, target_space: String) -> void:
	var controller := VfxEditorControllerModel.new()
	var inspector_host := Control.new()
	var preset_inspector := VfxPresetInspectorModel.new()
	var layer_inspector := VfxLayerInspectorModel.new()
	inspector_host.add_child(preset_inspector)
	inspector_host.add_child(layer_inspector)
	controller.configure_inspectors(preset_inspector, layer_inspector)
	var created := controller.create_new_preset("utility.default_%s" % target_space.to_lower(), "Default Space", "UTILITY", "ONE_SHOT", "VEHICLE_LOCAL")
	tests.expect_true(created.success, "controller creates a vehicle default Preset for %s inheritance repair" % target_space)
	if not created.success:
		inspector_host.free()
		return
	controller.add_active_layer("GLOW")
	controller.add_active_layer("RING")
	controller.add_active_layer("SHIELD")
	var layers: Array = controller.working_preset()["phases"]["one_shot"]["layers"]
	var explicit_id: String = layers[0]["id"]
	controller.select_layer(explicit_id)
	controller.set_selected_layer_space_override("VEHICLE_LOCAL")
	var default_space := preset_inspector.get_node_or_null("DefaultSpace") as OptionButton
	var target_index := _item_index(default_space, target_space)
	default_space.select(target_index)
	default_space.emit_signal("item_selected", target_index)
	var changed_layers: Array = controller.working_preset()["phases"]["one_shot"]["layers"]
	var allowed_target_planes: Array = _render_rule(_loaded_registry().schema())["allowed_planes_by_space"][target_space]
	tests.expect_true(controller.working_preset().get("default_space_mode") == target_space, "Preset Inspector commits default %s Space Mode through the controller" % target_space)
	tests.expect_true(changed_layers[0].get("space_mode") == "VEHICLE_LOCAL" and changed_layers[0].get("anchors", []).size() > 0 and _render_rule(_loaded_registry().schema())["allowed_planes_by_space"]["VEHICLE_LOCAL"].has(changed_layers[0].get("render_plane")), "explicit vehicle Layer remains unaffected by inherited %s repair" % target_space)
	var inheriting_layers_repaired := true
	for layer_index in range(1, changed_layers.size()):
		var inherited_layer: Dictionary = changed_layers[layer_index]
		inheriting_layers_repaired = inheriting_layers_repaired and not inherited_layer.has("space_mode") and not inherited_layer.has("anchors") and allowed_target_planes.has(inherited_layer.get("render_plane"))
	tests.expect_true(inheriting_layers_repaired, "all inheriting Layers remove Anchors and use a Schema-permitted %s plane" % target_space)
	tests.expect_true(not _has_issue(controller.current_issues(), "anchor_not_allowed") and not _has_issue(controller.current_issues(), "render_plane_for_space"), "default %s repair validates before the passive Inspector refresh" % target_space)
	controller.undo()
	var restored_layers: Array = controller.working_preset()["phases"]["one_shot"]["layers"]
	var restored_inheriting_layers := true
	for layer_index in range(1, restored_layers.size()):
		var restored_layer: Dictionary = restored_layers[layer_index]
		restored_inheriting_layers = restored_inheriting_layers and restored_layer.get("anchors", []).size() > 0 and _render_rule(_loaded_registry().schema())["allowed_planes_by_space"]["VEHICLE_LOCAL"].has(restored_layer.get("render_plane"))
	tests.expect_true(controller.working_preset().get("default_space_mode") == "VEHICLE_LOCAL" and restored_inheriting_layers, "one undo restores the root default and every inherited Layer state after %s repair" % target_space)
	inspector_host.free()


static func _test_default_space_commit_adds_vehicle_defaults(tests: TestAssert) -> void:
	var controller := VfxEditorControllerModel.new()
	var inspector_host := Control.new()
	var preset_inspector := VfxPresetInspectorModel.new()
	var layer_inspector := VfxLayerInspectorModel.new()
	inspector_host.add_child(preset_inspector)
	inspector_host.add_child(layer_inspector)
	controller.configure_inspectors(preset_inspector, layer_inspector)
	var created := controller.create_new_preset("utility.default_vehicle", "Default Vehicle", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(created.success, "controller creates a world default Preset for vehicle inheritance repair")
	if not created.success:
		inspector_host.free()
		return
	controller.add_active_layer("GLOW")
	controller.add_active_layer("RING")
	controller.add_active_layer("SHIELD")
	var layers: Array = controller.working_preset()["phases"]["one_shot"]["layers"]
	controller.select_layer(layers[0]["id"])
	controller.set_selected_layer_space_override("SCREEN_UI")
	var default_space := preset_inspector.get_node_or_null("DefaultSpace") as OptionButton
	var vehicle_index := _item_index(default_space, "VEHICLE_LOCAL")
	default_space.select(vehicle_index)
	default_space.emit_signal("item_selected", vehicle_index)
	var changed_layers: Array = controller.working_preset()["phases"]["one_shot"]["layers"]
	var vehicle_planes: Array = _render_rule(_loaded_registry().schema())["allowed_planes_by_space"]["VEHICLE_LOCAL"]
	tests.expect_true(changed_layers[0].get("space_mode") == "SCREEN_UI" and not changed_layers[0].has("anchors") and _render_rule(_loaded_registry().schema())["allowed_planes_by_space"]["SCREEN_UI"].has(changed_layers[0].get("render_plane")), "explicit screen Layer stays untouched by inherited vehicle repair")
	var inheriting_layers_repaired := true
	for layer_index in range(1, changed_layers.size()):
		var inherited_layer: Dictionary = changed_layers[layer_index]
		inheriting_layers_repaired = inheriting_layers_repaired and inherited_layer.get("anchors", []).size() > 0 and vehicle_planes.has(inherited_layer.get("render_plane"))
	tests.expect_true(inheriting_layers_repaired, "vehicle default repair gives every inheriting Layer a Schema-derived Anchor and permitted plane")
	tests.expect_true(not _has_issue(controller.current_issues(), "vehicle_anchor_required") and not _has_issue(controller.current_issues(), "render_plane_for_space"), "vehicle default repair validates before Inspector refresh")
	controller.undo()
	var restored_layers: Array = controller.working_preset()["phases"]["one_shot"]["layers"]
	var restored_inheriting_layers := true
	for layer_index in range(1, restored_layers.size()):
		var restored_layer: Dictionary = restored_layers[layer_index]
		restored_inheriting_layers = restored_inheriting_layers and not restored_layer.has("anchors") and _render_rule(_loaded_registry().schema())["allowed_planes_by_space"]["WORLD_AREA"].has(restored_layer.get("render_plane"))
	tests.expect_true(controller.working_preset().get("default_space_mode") == "WORLD_AREA" and restored_inheriting_layers, "one undo restores every inherited world Layer after vehicle default repair")
	inspector_host.free()


static func _schema_fixture() -> Dictionary:
	return {
		"$defs": {"anchor": {"enum": ["CENTER", "TIRE_RL"]}},
		"x_vfx_rules": [{
			"name": "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS",
			"vehicle_space_modes": ["VEHICLE_LOCAL"]
		}]
	}


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _render_rule(schema: Dictionary) -> Dictionary:
	for rule in schema.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == "RENDER_PLANE_FOR_EFFECTIVE_SPACE":
			return rule
	return {}


static func _has_issue(issues: Array[VfxIssue], code: String) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false


static func _item_index(select: OptionButton, item_text: String) -> int:
	for index in select.item_count:
		if select.get_item_text(index) == item_text:
			return index
	return -1
