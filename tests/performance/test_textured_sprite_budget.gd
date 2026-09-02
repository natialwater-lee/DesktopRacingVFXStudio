extends RefCounted

const TexturedSpriteContractTests := preload("res://tests/unit/test_textured_sprite_contract.gd")
const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")


static func run(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().build_document_from_value(TexturedSpriteContractTests.preset_data())
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	var analyzer_script := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var projection_script := load("res://src/performance/vfx_scenario_projection.gd") as Script
	var scenario_script := load("res://src/performance/vfx_stress_scenario.gd") as Script
	var budget_result: VfxResult = analyzer_script.new(_registry()).analyze(plan_result.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP") if analyzer_script != null and plan_result.success else VfxResult.failure([])
	var workload: Variant = budget_result.value.active_workload() if budget_result.success and budget_result.value != null else null
	var scenario: Variant = scenario_script.new("20x3_textured_sprite", 20, 3, "VEHICLE_STRESS", "STEADY_LOOP") if scenario_script != null else null
	var projection: Variant = projection_script.new().project([workload, workload, workload], scenario) if projection_script != null and workload != null and scenario != null else null
	var workload_count: int = int(workload.persistent_textured_sprite_instance_count()) if workload != null and workload.has_method("persistent_textured_sprite_instance_count") else -1
	var projected_count: int = int(projection.persistent_textured_sprite_instance_count()) if projection != null and projection.has_method("persistent_textured_sprite_instance_count") else -1
	var texture_backed_count: int = int(workload.texture_backed_renderer_instance_count()) if workload != null else -1
	tests.expect_true(workload_count == 1 and projected_count == 60 and texture_backed_count == 1, "Performance analysis counts one generic persistent texture node per active Layer and projects 20 cars by three slots without inventing particle capacity")


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
