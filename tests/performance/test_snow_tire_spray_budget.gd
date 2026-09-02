extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")


static func run(tests: TestAssert) -> void:
	_test_snow_mist_lod_stays_within_two_wheel_band_budget(tests)
	_test_twenty_snow_mist_instances_stay_below_weather_particle_wall(tests)


static func _test_snow_mist_lod_stays_within_two_wheel_band_budget(tests: TestAssert) -> void:
	var expected := {"HIGH": [4, 8], "MEDIUM": [4, 8], "LOW": [4, 8]}
	var policy_result := _policy_result()
	var plan := _snow_plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "Snow Tire Mist LOD budget requires a valid policy and Preset render plan")
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
	tests.expect_true(matches, "Snow Tire Mist keeps four continuous CORE wheel plumes at every LOD for a capped translucent weather workload")


static func _test_twenty_snow_mist_instances_stay_below_weather_particle_wall(tests: TestAssert) -> void:
	var expected := {"HIGH": [80, 160], "MEDIUM": [80, 160], "LOW": [80, 160]}
	var policy_result := _policy_result()
	var plan := _snow_plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "Snow Tire Mist stress projection requires a valid policy and Preset render plan")
		return
	var filter := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var scenario_script := load("res://src/performance/vfx_stress_scenario.gd") as Script
	var projection_script := load("res://src/performance/vfx_scenario_projection.gd") as Script
	var scenario = scenario_script.new("20x1_snow_tire_spray", 20, 1, "VEHICLE_STRESS", "STEADY_LOOP") if scenario_script != null else null
	var matches := filter != null and analyzer != null and projection_script != null and scenario != null
	for lod_level in expected:
		var filtered: VfxResult = filter.new().filter(plan, lod_level, policy_result.value) if filter != null else VfxResult.failure([])
		var budget_result: VfxResult = analyzer.new(_registry()).analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP") if analyzer != null and filtered.success else VfxResult.failure(filtered.issues)
		var workload = budget_result.value.active_workload() if budget_result.success else null
		var projection = projection_script.new().project([workload], scenario) if projection_script != null and workload != null else null
		var values: Array = expected[lod_level]
		matches = matches and projection != null and projection.expanded_instance_count() == values[0] and projection.continuous_particle_capacity() == values[1]
	tests.expect_true(matches, "Twenty Snow Tire Mist instances project to 160 continuous wheel-mist particles at every LOD without optional detail layers")


static func _snow_plan() -> RefCounted:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.snow_tire_spray.vfx.json")
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
