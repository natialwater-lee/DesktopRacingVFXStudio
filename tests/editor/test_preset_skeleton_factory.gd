extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")


static func run(tests: TestAssert) -> void:
	var factory := VfxPresetSkeletonFactoryModel.new(_loaded_registry())
	var pipeline := VfxPresetPipelineModel.new()
	var one_shot := factory.create("utility.flash", "Flash", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(one_shot.success, "one-shot Skeleton is created")
	if not one_shot.success:
		return
	tests.expect_true(one_shot.value["schema_version"] == 1, "Skeleton selects Schema version from Schema enum")
	tests.expect_true(one_shot.value["runtime_inputs"].is_empty(), "Skeleton initializes required runtime inputs without hidden values")
	tests.expect_true(one_shot.value["phases"].keys() == ["one_shot"], "one-shot Skeleton has Schema-configured phase stack")
	tests.expect_true(one_shot.value["phases"]["one_shot"]["layers"].is_empty(), "new Skeleton has no hidden Layer")
	tests.expect_true(one_shot.value["phases"]["one_shot"]["duration_seconds"] >= 0.001, "required phase duration uses a valid Schema-derived initial value")
	var empty_result := pipeline.build_document_from_value(one_shot.value)
	tests.expect_true(not empty_result.success, "empty Skeleton is transient-invalid")
	tests.expect_true(_has_issue(empty_result.issues, "preset_has_no_layers"), "empty Skeleton reports the existing no-layer Contract issue")

	var start_loop_end := factory.create("utility.channel", "Channel", "UTILITY", "START_LOOP_END", "VEHICLE_LOCAL")
	tests.expect_true(start_loop_end.success, "start-loop-end Skeleton is created")
	if start_loop_end.success:
		tests.expect_true(start_loop_end.value["phases"].keys() == ["start", "loop", "end"], "start-loop-end uses Schema-configured phases")
		tests.expect_true(not start_loop_end.value["phases"]["loop"].has("duration_seconds"), "loop phase omits duration when Schema does not require it")


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _has_issue(issues: Array, code: String) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false
