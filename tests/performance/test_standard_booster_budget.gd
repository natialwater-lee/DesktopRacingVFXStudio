extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")


static func run(tests: TestAssert) -> void:
	_test_standard_booster_lod_preserves_two_core_jets_on_low(tests)
	_test_twenty_cars_one_booster_projection_stays_within_the_authored_flame_envelope(tests)


static func _test_standard_booster_lod_preserves_two_core_jets_on_low(tests: TestAssert) -> void:
	var filter_script := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var policy_script := load("res://src/performance/vfx_performance_policy.gd") as Script
	var analyzer_script := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var expected := {"HIGH": [8, 8], "MEDIUM": [6, 6], "LOW": [2, 2]}
	if filter_script == null or policy_script == null or analyzer_script == null:
		tests.expect_true(false, "Standard Booster LOD budget requires the existing filter, policy, and analyzer")
		return
	var policy_result: VfxResult = policy_script.new().load(_registry())
	var plan := _booster_plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "Standard Booster LOD budget requires a valid policy and Preset render plan")
		return
	var matches := true
	for lod_level in expected:
		var filtered: VfxResult = filter_script.new().filter(plan, lod_level, policy_result.value)
		if not filtered.success:
			matches = false
			continue
		var budget_result: VfxResult = analyzer_script.new(_registry()).analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP")
		var values: Array = expected[lod_level]
		var workload = budget_result.value.active_workload() if budget_result.success else null
		matches = matches and workload != null \
			and workload.expanded_instance_count() == values[0] \
			and workload.continuous_particle_capacity() == values[1]
	tests.expect_true(matches, "Standard Booster HIGH/MEDIUM/LOW keeps 8/6/2 LOOP flame Layers and 8/6/2 continuous sprite capacity, leaving two CORE jets visible on LOW")


static func _test_twenty_cars_one_booster_projection_stays_within_the_authored_flame_envelope(tests: TestAssert) -> void:
	var filter_script := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var policy_script := load("res://src/performance/vfx_performance_policy.gd") as Script
	var analyzer_script := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var scenario_script := load("res://src/performance/vfx_stress_scenario.gd") as Script
	var projection_script := load("res://src/performance/vfx_scenario_projection.gd") as Script
	var expected := {"HIGH": [160, 160], "MEDIUM": [120, 120], "LOW": [40, 40]}
	if filter_script == null or policy_script == null or analyzer_script == null or scenario_script == null or projection_script == null:
		tests.expect_true(false, "Standard Booster scenario projection requires the existing performance components")
		return
	var policy_result: VfxResult = policy_script.new().load(_registry())
	var plan := _booster_plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "Standard Booster scenario projection requires a valid policy and Preset render plan")
		return
	var scenario = scenario_script.new("20x1_standard_booster", 20, 1, "VEHICLE_STRESS", "STEADY_LOOP")
	var matches := true
	for lod_level in expected:
		var filtered: VfxResult = filter_script.new().filter(plan, lod_level, policy_result.value)
		if not filtered.success:
			matches = false
			continue
		var budget_result: VfxResult = analyzer_script.new(_registry()).analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP")
		var workload = budget_result.value.active_workload() if budget_result.success else null
		var projection = projection_script.new().project([workload], scenario) if workload != null else null
		var values: Array = expected[lod_level]
		matches = matches and projection != null \
			and projection.expanded_instance_count() == values[0] \
			and projection.continuous_particle_capacity() == values[1]
	tests.expect_true(matches, "Twenty cars with one Standard Booster project HIGH/MEDIUM/LOW to 160/120/40 runtime Layers and 160/120/40 continuously alive flame sprites")


static func _booster_plan() -> RefCounted:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.standard_boost.vfx.json")
	if not document_result.success:
		return null
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document_result.value.normalized_data)
	return plan_result.value if plan_result.success else null


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
