extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")
const VfxLayerFactoryModel := preload("res://src/editor/factories/vfx_layer_factory.gd")
const VfxLayerStackModel := preload("res://src/editor/workspace/vfx_layer_stack.gd")
const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")


static func run(tests: TestAssert) -> void:
	var registry := _loaded_registry()
	var skeleton_factory := VfxPresetSkeletonFactoryModel.new(registry)
	var layer_factory := VfxLayerFactoryModel.new(registry)
	var created := skeleton_factory.create("utility.channel", "Channel", "UTILITY", "START_LOOP_END", "WORLD_AREA")
	tests.expect_true(created.success, "layer stack fixture creates lifecycle Skeleton")
	if not created.success:
		return
	var first := layer_factory.create("GLOW", "loop", created.value)
	if not first.success:
		return
	var source: Dictionary = created.value.duplicate(true)
	source["phases"]["loop"]["layers"].append(first.value)
	var second := layer_factory.duplicate("loop", first.value, source)
	if not second.success:
		return
	source["phases"]["loop"]["layers"].append(second.value)
	var stack := VfxLayerStackModel.new(layer_factory)

	var moved := stack.move_layer(source, "loop", 1, -1)
	tests.expect_true(moved["phases"]["loop"]["layers"][0]["id"] == second.value["id"], "move up changes active phase order")
	tests.expect_true(source["phases"]["loop"]["layers"][0]["id"] == first.value["id"], "move returns a deep-copied Preset")
	tests.expect_true(moved["phases"]["start"]["layers"].is_empty() and moved["phases"]["end"]["layers"].is_empty(), "move leaves other phase arrays untouched")

	var toggled := stack.set_layer_enabled(source, "loop", first.value["id"], false)
	tests.expect_true(not toggled["phases"]["loop"]["layers"][0]["enabled"], "toggle changes only the requested Layer")
	tests.expect_true(source["phases"]["loop"]["layers"][0]["enabled"], "toggle does not alias source Layer")
	var deleted := stack.delete_layer(source, "loop", first.value["id"])
	tests.expect_true(deleted["phases"]["loop"]["layers"].size() == 1, "delete removes exactly one active-phase Layer")
	var duplicated := stack.duplicate_layer(source, "loop", first.value["id"])
	tests.expect_true(duplicated["phases"]["loop"]["layers"].size() == 3, "duplicate appends an active-phase Layer")
	tests.expect_true(duplicated["phases"]["loop"]["layers"][2]["id"] != first.value["id"], "duplicate creates an id unique across phases")
	tests.expect_true(VfxPresetPipelineModel.new().build_document_from_value(duplicated).success, "Layer Stack duplicate remains Contract-valid")
	stack.free()

	var controller := VfxEditorControllerModel.new()
	var controller_created := controller.create_new_preset("utility.controller", "Controller", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(controller_created.success, "controller creates a Preset for command history")
	if controller_created.success:
		controller.add_active_layer("GLOW")
		var selected_id: String = controller.working_preset()["phases"]["one_shot"]["layers"][0]["id"]
		controller.select_layer(selected_id)
		controller.delete_active_layer(selected_id)
		tests.expect_true(controller.selected_layer_id().is_empty(), "deleting the selected Layer clears its stale selection")
		controller.undo()
		tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"][0]["id"] == selected_id, "undo restores the deleted Layer data")
		tests.expect_true(controller.selected_layer_id().is_empty(), "undo does not retain a stale deleted Layer id")


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
