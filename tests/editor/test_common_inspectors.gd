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
	var created := controller.create_new_preset("utility.inspector", "Inspector", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(created.success, "controller creates a Preset for inspector commits")
	if created.success:
		controller.commit_preset_field("/display_name", "Committed")
		tests.expect_true(controller.can_undo(), "one inspector focus commit records an undo action")
		controller.undo()
		tests.expect_true(controller.working_preset().get("display_name") == "Inspector", "undo restores one root inspector commit")
		controller.add_active_layer("GLOW")
		var layer_id: String = controller.working_preset()["phases"]["one_shot"]["layers"][0]["id"]
		controller.select_layer(layer_id)
		controller.set_selected_layer_space_override("INHERIT_DEFAULT")
		tests.expect_true(not controller.working_preset()["phases"]["one_shot"]["layers"][0].has("space_mode"), "unset Layer space remains absent after controller refresh")


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
