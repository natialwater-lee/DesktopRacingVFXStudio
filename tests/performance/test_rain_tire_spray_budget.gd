extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")


static func run(tests: TestAssert) -> void:
	_test_rain_spray_lod_stays_within_two_wheel_band_budget(tests)
	_test_twenty_rain_spray_instances_stay_below_weather_particle_wall(tests)


static func _test_rain_spray_lod_stays_within_two_wheel_band_budget(tests: TestAssert) -> void:
	var expected := {"HIGH": [2, 4], "MEDIUM": [2, 4], "LOW": [2, 4]}
	var policy_result := _policy_result()
	var plan := _rain_plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "Rain Tire Spray LOD budget requires a valid policy and Preset render plan")
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
	tests.expect_true(matches, "Rain Tire Spray keeps two CORE wheel droplet layers (2 x 2 particles) at every LOD; the mist wake is drawn by the Game wake strip")


static func _test_twenty_rain_spray_instances_stay_below_weather_particle_wall(tests: TestAssert) -> void:
	var expected := {"HIGH": [40, 80], "MEDIUM": [40, 80], "LOW": [40, 80]}
	var policy_result := _policy_result()
	var plan := _rain_plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "Rain Tire Spray stress projection requires a valid policy and Preset render plan")
		return
	var filter := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var scenario_script := load("res://src/performance/vfx_stress_scenario.gd") as Script
	var projection_script := load("res://src/performance/vfx_scenario_projection.gd") as Script
	var scenario = scenario_script.new("20x1_rain_tire_spray", 20, 1, "VEHICLE_STRESS", "STEADY_LOOP") if scenario_script != null else null
	var matches := filter != null and analyzer != null and projection_script != null and scenario != null
	for lod_level in expected:
		var filtered: VfxResult = filter.new().filter(plan, lod_level, policy_result.value) if filter != null else VfxResult.failure([])
		var budget_result: VfxResult = analyzer.new(_registry()).analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP") if analyzer != null and filtered.success else VfxResult.failure(filtered.issues)
		var workload = budget_result.value.active_workload() if budget_result.success else null
		var projection = projection_script.new().project([workload], scenario) if projection_script != null and workload != null else null
		var values: Array = expected[lod_level]
		matches = matches and projection != null and projection.expanded_instance_count() == values[0] and projection.continuous_particle_capacity() == values[1]
	tests.expect_true(matches, "Twenty Rain Tire Spray instances project to 80 wheel droplets at every LOD")


static func _rain_plan() -> RefCounted:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.rain_tire_spray.vfx.json")
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
