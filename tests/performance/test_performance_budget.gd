extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")


static func run(tests: TestAssert) -> void:
	_test_multi_anchor_and_renderer_metadata_aggregation(tests)
	_test_scenario_projection_and_uncalibrated_threshold(tests)


static func _test_multi_anchor_and_renderer_metadata_aggregation(tests: TestAssert) -> void:
	var analyzer_script := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	if analyzer_script == null:
		tests.expect_true(false, "Performance Budget Analyzer script is available")
		return
	var document: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/utility.renderer_showcase.vfx.json")
	if not document.success:
		tests.expect_true(false, "Renderer showcase must remain a valid Budget fixture")
		return
	var normalized: Dictionary = document.value.normalized_data.duplicate(true)
	for layer in normalized["phases"]["loop"]["layers"]:
		if layer.get("type") == "TRAIL":
			layer["anchors"] = ["TIRE_FL", "TIRE_FR", "TIRE_RL", "TIRE_RR"]
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(normalized)
	var profile := {"anchors": {"CENTER": [0, 0], "REAR_CENTER": [0, 100], "TIRE_FL": [-10, -10], "TIRE_FR": [10, -10], "TIRE_RL": [-10, 10], "TIRE_RR": [10, 10]}}
	var budget_result: VfxResult = analyzer_script.new(_registry()).analyze(plan_result.value, profile, "STEADY_LOOP") if plan_result.success else VfxResult.failure(plan_result.issues)
	var workload = budget_result.value.active_workload() if budget_result.success else null
	tests.expect_true(budget_result.success and workload.expanded_instance_count() == 6, "Four-anchor Trail expands one active workload Layer into four independent runtime instances")
	tests.expect_true(workload.trail_max_point_capacity() == 64 and workload.ring_active_potential() == 1 and workload.texture_asset_ids().size() == 2, "Workload Budget aggregates Trail max_points, Ring potential, and unique texture assets from ordinary renderer metadata")


static func _test_scenario_projection_and_uncalibrated_threshold(tests: TestAssert) -> void:
	var policy_script := load("res://src/performance/vfx_performance_policy.gd") as Script
	var filter_script := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer_script := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var scenario_script := load("res://src/performance/vfx_stress_scenario.gd") as Script
	var projection_script := load("res://src/performance/vfx_scenario_projection.gd") as Script
	var evaluator_script := load("res://src/performance/vfx_budget_threshold_evaluator.gd") as Script
	if policy_script == null or filter_script == null or analyzer_script == null or scenario_script == null or projection_script == null or evaluator_script == null:
		tests.expect_true(false, "Scenario projection requires Policy, LOD Filter, Analyzer, Scenario, Projection, and Threshold Evaluator")
		return
	var policy_result: VfxResult = policy_script.new().load(_registry())
	var scenario = scenario_script.new("20x3", 20, 3, "VEHICLE_STRESS", "STEADY_LOOP")
	var expected := {"HIGH": [300, 420], "MEDIUM": [240, 300], "LOW": [120, 180]}
	var all_match := true
	var high_evaluation: Variant = null
	for lod_level in expected:
		var filtered: VfxResult = filter_script.new().filter(_zero_zone_plan(), lod_level, policy_result.value) if policy_result.success else VfxResult.failure(policy_result.issues)
		var budget_result: VfxResult = analyzer_script.new(_registry()).analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP") if filtered.success else VfxResult.failure(filtered.issues)
		var projection = projection_script.new().project([budget_result.value.active_workload(), budget_result.value.active_workload(), budget_result.value.active_workload()], scenario) if budget_result.success else null
		var values: Array = expected[lod_level]
		all_match = all_match and projection != null and projection.expanded_instance_count() == values[0] and projection.continuous_particle_capacity() == values[1]
		if lod_level == "HIGH" and projection != null and policy_result.success:
			high_evaluation = evaluator_script.new().evaluate(projection, policy_result.value)
	tests.expect_true(all_match, "20x3 Zero Zone projections are HIGH 300/420, MEDIUM 240/300, and LOW 120/180 instances/continuous Particles")
	tests.expect_true(high_evaluation != null and high_evaluation.severity() == "SAFE" and high_evaluation.calibration_state() == "UNCALIBRATED", "Threshold output preserves SAFE as Uncalibrated Authoring Guidance rather than a game-runtime claim")


static func _zero_zone_plan() -> RefCounted:
	var result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	if not result.success:
		return null
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(result.value.normalized_data)
	return plan_result.value if plan_result.success else null


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
