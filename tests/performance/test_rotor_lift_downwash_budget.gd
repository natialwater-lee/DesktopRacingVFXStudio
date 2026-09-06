extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")


static func run(tests: TestAssert) -> void:
	var document := VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.rotor_lift.downwash.vfx.json")
	var policy_script := load("res://src/performance/vfx_performance_policy.gd") as Script
	var filter_script := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer_script := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var projection_script := load("res://src/performance/vfx_scenario_projection.gd") as Script
	var scenario_script := load("res://src/performance/vfx_stress_scenario.gd") as Script
	var plan_result := VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document.value.normalized_data) if document.success else VfxResult.failure(document.issues)
	var policy_result: VfxResult = policy_script.new().load(_registry()) if policy_script != null else VfxResult.failure([])
	var matches: bool = plan_result.success and policy_result.success and filter_script != null and analyzer_script != null and projection_script != null and scenario_script != null
	var scenario = scenario_script.new("20x1_rotor_lift", 20, 1, "VEHICLE_STRESS", "STEADY_LOOP") if scenario_script != null else null
	var expected := {"HIGH": [6, 4, 6, 120, 80, 120], "MEDIUM": [4, 4, 0, 80, 80, 0], "LOW": [2, 2, 0, 40, 40, 0]}
	for level in expected:
		var filtered: VfxResult = filter_script.new().filter(plan_result.value, level, policy_result.value) if matches else VfxResult.failure([])
		var budget: VfxResult = analyzer_script.new(_registry()).analyze(filtered.value, {"anchors": {"CENTER": [0.0, 0.0]}}, "STEADY_LOOP") if filtered.success else VfxResult.failure([])
		var workload: Variant = budget.value.active_workload() if budget.success else null
		var projection: Variant = projection_script.new().project([workload], scenario) if workload != null and scenario != null else null
		var values: Array = expected[level]
		matches = matches and workload != null and projection != null and workload.expanded_instance_count() == values[0] and workload.persistent_textured_sprite_instance_count() == values[1] and workload.continuous_particle_capacity() == values[2] and projection.expanded_instance_count() == values[3] and projection.persistent_textured_sprite_instance_count() == values[4] and projection.continuous_particle_capacity() == values[5]
	tests.expect_true(matches, "Rotor Lift R3 keeps four persistent rotating sprites and two EXTRA turbulence emitters at HIGH with a six-particle cap, while MEDIUM and LOW remove EXTRA without changing the Core/Soft sprite contract")


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
