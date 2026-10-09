extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")


static func run(tests: TestAssert) -> void:
	_test_headlights_keep_core_pair_at_low_lod_without_particle_capacity(tests)
	_test_headlight_persistent_instances_project_linearly_per_car(tests)


static func _test_headlights_keep_core_pair_at_low_lod_without_particle_capacity(tests: TestAssert) -> void:
	var expected := {"HIGH": [4, 4, 0, 68], "MEDIUM": [4, 4, 0, 68], "LOW": [2, 2, 0, 34]}
	var expected_loop_layer_ids := {
		"HIGH": ["loop.left_soft_beam", "loop.right_soft_beam", "loop.left_core_beam", "loop.right_core_beam"],
		"MEDIUM": ["loop.left_soft_beam", "loop.right_soft_beam", "loop.left_core_beam", "loop.right_core_beam"],
		"LOW": ["loop.left_core_beam", "loop.right_core_beam"]
	}
	var policy_result := _policy_result()
	var plan := _headlight_plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "Headlight LOD budget requires a valid static headlight Preset and performance policy")
		return
	var filter := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var matches := filter != null and analyzer != null
	for lod_level in expected:
		var filtered: VfxResult = filter.new().filter(plan, lod_level, policy_result.value) if filter != null else VfxResult.failure([])
		var budget_result: VfxResult = analyzer.new(_registry()).analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP") if analyzer != null and filtered.success else VfxResult.failure(filtered.issues)
		var workload = budget_result.value.active_workload() if budget_result.success else null
		var values: Array = expected[lod_level]
		matches = matches and workload != null \
			and workload.expanded_instance_count() == values[0] \
			and workload.persistent_textured_sprite_instance_count() == values[1] \
			and workload.continuous_particle_capacity() == values[2] \
			and filtered.value.runtime_modulation_program() != null and filtered.value.runtime_modulation_program().binding_count() == values[3] \
			and _loop_layer_ids(filtered.value) == expected_loop_layer_ids[lod_level]
	tests.expect_true(matches, "Headlight LOD keeps four persistent sprites at HIGH and MEDIUM, two CORE center beams at LOW, zero particle capacity, and prunes all Soft modulation bindings before runtime construction")


static func _test_headlight_persistent_instances_project_linearly_per_car(tests: TestAssert) -> void:
	var policy_result := _policy_result()
	var plan := _headlight_plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "Headlight stress projection requires a valid static headlight Preset and performance policy")
		return
	var filter := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var scenario_script := load("res://src/performance/vfx_stress_scenario.gd") as Script
	var projection_script := load("res://src/performance/vfx_scenario_projection.gd") as Script
	var matches := filter != null and analyzer != null and scenario_script != null and projection_script != null
	for car_count in [10, 20]:
		var expected := {"HIGH": car_count * 4, "MEDIUM": car_count * 4, "LOW": car_count * 2}
		var scenario = scenario_script.new("%dx1_headlights" % car_count, car_count, 1, "VEHICLE_STRESS", "STEADY_LOOP") if scenario_script != null else null
		for lod_level in expected:
			var filtered: VfxResult = filter.new().filter(plan, lod_level, policy_result.value) if filter != null else VfxResult.failure([])
			var budget_result: VfxResult = analyzer.new(_registry()).analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP") if analyzer != null and filtered.success else VfxResult.failure(filtered.issues)
			var workload = budget_result.value.active_workload() if budget_result.success else null
			var projection = projection_script.new().project([workload], scenario) if projection_script != null and workload != null and scenario != null else null
			matches = matches and projection != null \
				and projection.persistent_textured_sprite_instance_count() == expected[lod_level] \
				and projection.continuous_particle_capacity() == 0
	tests.expect_true(matches, "Ten and twenty static Headlight baselines project only their persistent textured-sprite pairs with no particle workload")


static func _headlight_plan() -> RefCounted:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.headlights.vfx.json")
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


static func _loop_layer_ids(plan: RefCounted) -> Array:
	var loop_phase: RefCounted = plan.phase_named("loop") if plan != null and plan.has_method("phase_named") else null
	return loop_phase.layer_specs().map(func(layer: RefCounted) -> String: return layer.layer_id()) if loop_phase != null else []
