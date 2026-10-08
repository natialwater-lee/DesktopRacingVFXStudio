extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")


static func run(tests: TestAssert) -> void:
	_test_high_speed_wind_lod_keeps_one_core_airflow_layer(tests)
	_test_twenty_high_speed_cars_stay_within_the_lightweight_sprite_target(tests)


static func _test_high_speed_wind_lod_keeps_one_core_airflow_layer(tests: TestAssert) -> void:
	var expected := {"HIGH": [7, 8], "MEDIUM": [4, 7], "LOW": [1, 4]}
	var policy_result := _policy_result()
	var plan := _wind_plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "High-Speed Wind LOD budget requires a valid policy and Preset render plan")
		return
	var filter := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var matches := filter != null and analyzer != null
	for lod_level in expected:
		var filtered: VfxResult = filter.new().filter(plan, lod_level, policy_result.value) if filter != null else VfxResult.failure([])
		var budget_result: VfxResult = analyzer.new(_registry()).analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP") if analyzer != null and filtered.success else VfxResult.failure(filtered.issues)
		var workload = budget_result.value.active_workload() if budget_result.success else null
		var values: Array = expected[lod_level]
		matches = matches and workload != null and workload.expanded_instance_count() == values[0] and workload.continuous_particle_capacity() == values[1]
	tests.expect_true(matches, "High-Speed Wind keeps three streak layers plus four flank sprites at HIGH, Main/Fine plus the two DETAIL flank sprites at MEDIUM, and only the four-cap Main airflow layer at LOW; the flank sprites add no continuous particle capacity")


static func _test_twenty_high_speed_cars_stay_within_the_lightweight_sprite_target(tests: TestAssert) -> void:
	var expected := {"HIGH": [140, 160], "MEDIUM": [80, 140], "LOW": [20, 80]}
	var policy_result := _policy_result()
	var plan := _wind_plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "High-Speed Wind stress projection requires a valid policy and Preset render plan")
		return
	var filter := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var scenario_script := load("res://src/performance/vfx_stress_scenario.gd") as Script
	var projection_script := load("res://src/performance/vfx_scenario_projection.gd") as Script
	var scenario = scenario_script.new("20x1_high_speed_wind", 20, 1, "VEHICLE_STRESS", "STEADY_LOOP") if scenario_script != null else null
	var matches := filter != null and analyzer != null and projection_script != null and scenario != null
	for lod_level in expected:
		var filtered: VfxResult = filter.new().filter(plan, lod_level, policy_result.value) if filter != null else VfxResult.failure([])
		var budget_result: VfxResult = analyzer.new(_registry()).analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP") if analyzer != null and filtered.success else VfxResult.failure(filtered.issues)
		var workload = budget_result.value.active_workload() if budget_result.success else null
		var projection = projection_script.new().project([workload], scenario) if projection_script != null and workload != null else null
		var values: Array = expected[lod_level]
		matches = matches and projection != null and projection.expanded_instance_count() == values[0] and projection.continuous_particle_capacity() == values[1]
	tests.expect_true(matches, "Twenty High-Speed Wind instances project to 140/80/20 Layers and 160/140/80 continuous sprites at HIGH/MEDIUM/LOW")


static func _wind_plan() -> RefCounted:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.high_speed_wind.vfx.json")
	if not document_result.success:
		return null
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document_result.value.normalized_data)
	return plan_result.value if plan_result.success else null


static func _policy_result() -> VfxResult:
	var policy_script := load("res://src/performance/vfx_performance_policy.gd") as Script
	return policy_script.new().load(_registry()) if policy_script != null else VfxResult.failure([])


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
