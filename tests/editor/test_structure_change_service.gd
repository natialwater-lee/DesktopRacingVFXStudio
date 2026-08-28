extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")
const VfxLayerFactoryModel := preload("res://src/editor/factories/vfx_layer_factory.gd")
const VfxStructureChangeServiceModel := preload("res://src/editor/factories/vfx_structure_change_service.gd")


static func run(tests: TestAssert) -> void:
	var registry := _loaded_registry()
	var skeleton_factory := VfxPresetSkeletonFactoryModel.new(registry)
	var layer_factory := VfxLayerFactoryModel.new(registry)
	var service := VfxStructureChangeServiceModel.new(skeleton_factory, layer_factory)
	var pipeline := VfxPresetPipelineModel.new()
	var valid_start_loop_end := skeleton_factory.create("utility.channel", "Channel", "UTILITY", "START_LOOP_END", "VEHICLE_LOCAL")
	tests.expect_true(valid_start_loop_end.success, "structure test creates lifecycle Skeleton")
	if not valid_start_loop_end.success:
		return
	var glow := layer_factory.create("GLOW", "start", valid_start_loop_end.value)
	tests.expect_true(glow.success, "structure test creates source Layer")
	if not glow.success:
		return
	var source: Dictionary = valid_start_loop_end.value.duplicate(true)
	source["phases"]["start"]["layers"].append(glow.value)
	tests.expect_true(pipeline.build_document_from_value(source).success, "source Preset is valid before destructive changes")

	var lifecycle_change := service.replace_lifecycle(source, "ONE_SHOT")
	tests.expect_true(lifecycle_change.success, "lifecycle replacement returns new data")
	if lifecycle_change.success:
		tests.expect_true(lifecycle_change.value["phases"].keys() == ["one_shot"], "lifecycle replacement discards old stacks")
		tests.expect_true(lifecycle_change.value["preset_id"] == source["preset_id"], "lifecycle replacement preserves root fields")
		var lifecycle_validation := pipeline.build_document_from_value(lifecycle_change.value)
		tests.expect_true(not lifecycle_validation.success and _only_has_issue(lifecycle_validation.issues, "preset_has_no_layers"), "empty lifecycle replacement is invalid only because it has no Layers")

	var type_change := service.replace_layer_type(source, "start", 0, "RING")
	tests.expect_true(type_change.success, "Layer Type replacement returns new data")
	if type_change.success:
		var replacement: Dictionary = type_change.value["phases"]["start"]["layers"][0]
		tests.expect_true(replacement["id"] == "start.glow", "type replacement retains Layer id")
		tests.expect_true(replacement["type"] == "RING", "type replacement changes type")
		tests.expect_true(replacement["anchors"] == glow.value["anchors"], "type replacement preserves common Layer fields")
		tests.expect_true(pipeline.build_document_from_value(type_change.value).success, "type replacement data is Contract-valid")


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _only_has_issue(issues: Array, code: String) -> bool:
	return issues.size() == 1 and issues[0].code == code
