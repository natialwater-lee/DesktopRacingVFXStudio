extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")


static func run(tests: TestAssert) -> void:
	_test_policy_is_uncalibrated_and_schema_checked(tests)
	_test_lod_filter_is_immutable_and_keeps_disabled_structure(tests)
	_test_zero_zone_steady_loop_lod_counts(tests)
	_test_disabled_layer_is_not_active_workload(tests)


static func _test_policy_is_uncalibrated_and_schema_checked(tests: TestAssert) -> void:
	var policy_script := load("res://src/performance/vfx_performance_policy.gd") as Script
	tests.expect_true(policy_script != null, "Performance Policy script is available")
	if policy_script == null:
		return
	var valid: VfxResult = policy_script.new().load(_registry())
	tests.expect_true(valid.success and valid.value.calibration_state() == "UNCALIBRATED" and valid.value.policy_version() == 1, "Performance policy declares version one Uncalibrated Authoring Guidance")
	var invalid: VfxResult = policy_script.new("res://tests/fixtures/performance/invalid_importance_policy.json").load(_registry())
	tests.expect_true(not invalid.success and invalid.issues.any(func(issue: VfxIssue) -> bool: return issue.code == "performance_policy_importance"), "Performance policy rejects an LOD Importance value absent from Schema v1")


static func _test_lod_filter_is_immutable_and_keeps_disabled_structure(tests: TestAssert) -> void:
	var filter_script := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var policy_script := load("res://src/performance/vfx_performance_policy.gd") as Script
	var plan := _zero_zone_plan()
	var policy_result: VfxResult = policy_script.new().load(_registry()) if policy_script != null else VfxResult.failure([])
	if filter_script == null or not policy_result.success or plan == null:
		tests.expect_true(false, "LOD filtering requires the policy, filter, and valid Zero Zone Render Plan")
		return
	var original_loop_count: int = plan.phase_named("loop").layer_specs().size()
	var medium: VfxResult = filter_script.new().filter(plan, "MEDIUM", policy_result.value)
	var low: VfxResult = filter_script.new().filter(plan, "LOW", policy_result.value)
	tests.expect_true(medium.success and medium.value.phase_named("loop").layer_specs().size() == 4 and low.success and low.value.phase_named("loop").layer_specs().size() == 2, "LOD filter retains all four HIGH/MEDIUM focus-tunnel Layers while LOW keeps only the CORE focus and tunnel arc")
	tests.expect_true(plan.phase_named("loop").layer_specs().size() == original_loop_count, "LOD filtering never mutates the original immutable Render Plan")

	var disabled_plan := _zero_zone_plan_with_disabled_focus_motes()
	var high: VfxResult = filter_script.new().filter(disabled_plan, "HIGH", policy_result.value)
	var high_loop_layers: Array = high.value.phase_named("loop").layer_specs() if high.success else []
	var disabled_present := high_loop_layers.any(func(layer: RefCounted) -> bool: return layer.layer_id() == "loop.focus_motes" and not layer.is_enabled())
	tests.expect_true(disabled_present, "LOD-filtered Plan retains disabled Layer structure for Authoring Inventory")


static func _test_zero_zone_steady_loop_lod_counts(tests: TestAssert) -> void:
	var analyzer_script := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var filter_script := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var policy_script := load("res://src/performance/vfx_performance_policy.gd") as Script
	var policy_result: VfxResult = policy_script.new().load(_registry()) if policy_script != null else VfxResult.failure([])
	if analyzer_script == null or filter_script == null or not policy_result.success:
		tests.expect_true(false, "Zero Zone Performance Budget requires Analyzer, LOD Filter, and Policy")
		return
	var expected := {"HIGH": [10, 4, 12], "MEDIUM": [10, 4, 12], "LOW": [3, 2, 4]}
	for lod_level in expected:
		var filtered: VfxResult = filter_script.new().filter(_zero_zone_plan(), lod_level, policy_result.value)
		var budget_result: VfxResult = analyzer_script.new(_registry()).analyze(filtered.value, _center_profile(), "STEADY_LOOP") if filtered.success else VfxResult.failure(filtered.issues)
		var values: Array = expected[lod_level]
		var inventory_layers: int = budget_result.value.authoring_inventory().included_layer_count() if budget_result.success else -1
		var workload_instances: int = budget_result.value.active_workload().expanded_instance_count() if budget_result.success else -1
		var workload_particles: int = budget_result.value.active_workload().continuous_particle_capacity() if budget_result.success else -1
		tests.expect_true(budget_result.success and inventory_layers == values[0] and workload_instances == values[1] and workload_particles == values[2], "Zero Zone %s separates Lifecycle Inventory from STEADY_LOOP active instances and Particle capacity" % lod_level)


static func _test_disabled_layer_is_not_active_workload(tests: TestAssert) -> void:
	var analyzer_script := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var filter_script := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var policy_script := load("res://src/performance/vfx_performance_policy.gd") as Script
	var policy_result: VfxResult = policy_script.new().load(_registry()) if policy_script != null else VfxResult.failure([])
	if analyzer_script == null or filter_script == null or not policy_result.success:
		tests.expect_true(false, "Disabled Layer budget behavior requires Analyzer, LOD Filter, and Policy")
		return
	var filtered: VfxResult = filter_script.new().filter(_zero_zone_plan_with_disabled_focus_motes(), "HIGH", policy_result.value)
	var budget_result: VfxResult = analyzer_script.new(_registry()).analyze(filtered.value, _center_profile(), "STEADY_LOOP") if filtered.success else VfxResult.failure(filtered.issues)
	var inventory_layers: int = budget_result.value.authoring_inventory().included_layer_count() if budget_result.success else -1
	var active_instances: int = budget_result.value.active_workload().expanded_instance_count() if budget_result.success else -1
	var active_particles: int = budget_result.value.active_workload().continuous_particle_capacity() if budget_result.success else -1
	tests.expect_true(budget_result.success and inventory_layers == 10 and active_instances == 3 and active_particles == 4, "Disabled focus-mote Layers remain visible in Lifecycle Inventory but are excluded from active Workload, Scenario, and threshold costs")


static func _zero_zone_plan() -> RefCounted:
	var result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	if not result.success:
		return null
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(result.value.normalized_data)
	return plan_result.value if plan_result.success else null


static func _zero_zone_plan_with_disabled_focus_motes() -> RefCounted:
	var result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	if not result.success:
		return null
	var normalized: Dictionary = result.value.normalized_data.duplicate(true)
	for layer in normalized["phases"]["loop"]["layers"]:
		if layer.get("id") == "loop.focus_motes":
			layer["enabled"] = false
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(normalized)
	return plan_result.value if plan_result.success else null


static func _center_profile() -> Dictionary:
	return {"anchors": {"CENTER": [0, 0]}}


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
