extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")
const VfxLayerFactoryModel := preload("res://src/editor/factories/vfx_layer_factory.gd")
const VfxSchemaReaderModel := preload("res://src/editor/inspector/vfx_schema_reader.gd")
const VfxPresetInspectorModel := preload("res://src/editor/inspector/vfx_preset_inspector.gd")
const VfxLayerInspectorModel := preload("res://src/editor/inspector/vfx_layer_inspector.gd")
const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")


static func run(tests: TestAssert) -> void:
	var registry := _loaded_registry()
	var reader := VfxSchemaReaderModel.new(registry)
	var root_schema := registry.schema()
	var changed_schema: Dictionary = root_schema.duplicate(true)
	changed_schema["$defs"]["category"]["enum"] = ["FIXTURE_CATEGORY"]
	var fixture_registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	fixture_registry.load_data(changed_schema)
	var preset_inspector := VfxPresetInspectorModel.new()
	preset_inspector.set_schema_reader(VfxSchemaReaderModel.new(fixture_registry))
	preset_inspector.set_preset({"preset_id": "utility.fixture", "display_name": "Fixture", "category": "FIXTURE_CATEGORY", "lifecycle": {"mode": "ONE_SHOT"}, "default_space_mode": "WORLD_AREA"})
	var category_select := preset_inspector.get_node_or_null("Category") as OptionButton
	tests.expect_true(category_select != null and category_select.get_item_text(0) == "FIXTURE_CATEGORY", "root enum controls use a supplied Schema fixture")
	preset_inspector.free()

	var layer_inspector := VfxLayerInspectorModel.new()
	layer_inspector.set_schema_reader(reader)
	var sort_schema := reader.property_schema(reader.layer_schema().value, "sort_order")
	var sort := layer_inspector.create_numeric_control("SortOrder", sort_schema.value) as SpinBox
	tests.expect_true(sort != null and sort.min_value == -100.0 and sort.max_value == 100.0, "numeric controls expose their Schema range")
	if sort != null:
		sort.free()
	var layer_without_override := {"id": "loop.glow", "type": "GLOW"}
	var next := layer_inspector.apply_space_override(layer_without_override, "INHERIT_DEFAULT")
	tests.expect_true(not next.has("space_mode"), "inherit removes Layer override")
	var explicit := layer_inspector.apply_space_override(layer_without_override, "WORLD_AREA")
	tests.expect_true(explicit.get("space_mode") == "WORLD_AREA", "space selection writes an explicit Layer override")
	layer_inspector.free()

	var controller := VfxEditorControllerModel.new()
	var inspector_host := Control.new()
	var root_inspector := VfxPresetInspectorModel.new()
	var common_layer_inspector := VfxLayerInspectorModel.new()
	inspector_host.add_child(root_inspector)
	inspector_host.add_child(common_layer_inspector)
	controller.configure_inspectors(root_inspector, common_layer_inspector)
	tests.expect_true(root_inspector.preset_field_commit.is_connected(Callable(controller, "_on_preset_field_commit")), "controller connects Preset field commits")
	tests.expect_true(root_inspector.lifecycle_change_requested.is_connected(Callable(controller, "_on_lifecycle_change_requested")), "controller connects Preset lifecycle requests")
	tests.expect_true(common_layer_inspector.layer_field_commit.is_connected(Callable(controller, "_on_layer_field_commit")), "controller connects Layer field commits")
	tests.expect_true(common_layer_inspector.space_override_changed.is_connected(Callable(controller, "_on_space_override_changed")), "controller connects Layer space override requests")
	tests.expect_true(common_layer_inspector.layer_type_change_requested.is_connected(Callable(controller, "_on_layer_type_change_requested")), "controller connects Layer type requests")
	var created := controller.create_new_preset("utility.inspector", "Inspector", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(created.success, "controller creates a Preset for inspector commits")
	if created.success:
		var display_name := root_inspector.get_node_or_null("DisplayName") as LineEdit
		display_name.text = "Focus Committed"
		display_name.emit_signal("focus_exited")
		tests.expect_true(controller.working_preset().get("display_name") == "Focus Committed", "Preset focus exit commits through the configured Inspector")
		controller.undo()
		tests.expect_true(controller.working_preset().get("display_name") == "Inspector" and not controller.can_undo(), "one Preset focus commit creates exactly one history action")

		controller.add_active_layer("GLOW")
		var layer_id: String = controller.working_preset()["phases"]["one_shot"]["layers"][0]["id"]
		controller.select_layer(layer_id)
		var layer_id_edit := common_layer_inspector.get_node_or_null("LayerId") as LineEdit
		layer_id_edit.text = "one_shot.renamed"
		layer_id_edit.emit_signal("focus_exited")
		tests.expect_true(controller.selected_layer_id() == "one_shot.renamed" and common_layer_inspector.visible, "Layer ID focus commit keeps the renamed Layer selected")
		controller.undo()
		tests.expect_true(controller.selected_layer_id().is_empty(), "undo clears a stale renamed Layer selection")
		controller.redo()
		tests.expect_true(controller.selected_layer_id().is_empty(), "redo preserves cleared UI-only selection when its prior id is stale")

		controller.select_layer("one_shot.renamed")
		var space_mode := common_layer_inspector.get_node_or_null("SpaceMode") as OptionButton
		var world_area_index := _item_index(space_mode, "WORLD_AREA")
		space_mode.select(world_area_index)
		space_mode.emit_signal("item_selected", world_area_index)
		tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"][0].get("space_mode") == "WORLD_AREA", "explicit Layer space option commits through the configured Inspector")
		space_mode.select(0)
		space_mode.emit_signal("item_selected", 0)
		tests.expect_true(not controller.working_preset()["phases"]["one_shot"]["layers"][0].has("space_mode") and space_mode.get_item_text(space_mode.selected) == "INHERIT DEFAULT", "Layer inherit selection removes the override and refreshes its Inspector state")

		var offset_x := common_layer_inspector.get_node_or_null("OffsetX") as SpinBox
		offset_x.value = -250.0
		offset_x.get_line_edit().emit_signal("focus_exited")
		tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"][0]["transform"]["offset"][0] == -250.0 and offset_x.value == -250.0, "unbounded negative offsets survive Inspector focus commit and refresh")
		var scale_x := common_layer_inspector.get_node_or_null("ScaleX") as SpinBox
		scale_x.value = 500.001
		scale_x.get_line_edit().emit_signal("focus_exited")
		tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"][0]["transform"]["scale"][0] == 500.001 and scale_x.value == 500.001, "unbounded large scales survive Inspector focus commit and refresh")
	inspector_host.free()


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _item_index(select: OptionButton, item_text: String) -> int:
	for index in select.item_count:
		if select.get_item_text(index) == item_text:
			return index
	return -1
