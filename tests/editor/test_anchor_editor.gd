extends RefCounted

const VfxAnchorEditorModel := preload("res://src/editor/inspector/vfx_anchor_editor.gd")
const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")


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
	tests.expect_true(cleared.size() == 1, "non-vehicle space emits the Anchor clear request")
	host.free()
	_test_anchor_space_commits(tests)


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
