extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")


static func run(tests: TestAssert) -> void:
	_test_dual_lod_inventory(tests)
	_test_twenty_dual_instances_project_linearly(tests)


static func _test_dual_lod_inventory(tests: TestAssert) -> void:
	var policy_result := _policy_result()
	var plan := _plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "Dual Super Booster budget requires a valid saved Preset render plan and performance policy.")
		return
	var filter := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var expected := {"HIGH": [6, 4, 12, 24], "MEDIUM": [4, 4, 0, 24], "LOW": [2, 2, 0, 12]}
	var matches := filter != null and analyzer != null
	for lod_level in expected:
		var filtered: VfxResult = filter.new().filter(plan, lod_level, policy_result.value) if filter != null else VfxResult.failure([])
		var budget_result: VfxResult = analyzer.new(_registry()).analyze(filtered.value, {"anchors": {"REAR_CENTER": [0.0, 220.0]}}, "STEADY_LOOP") if analyzer != null and filtered.success else VfxResult.failure(filtered.issues)
		var workload = budget_result.value.active_workload() if budget_result.success else null
		var values: Array = expected[lod_level]
		matches = matches and workload != null and workload.expanded_instance_count() == values[0] \
			and workload.persistent_textured_sprite_instance_count() == values[1] and workload.continuous_particle_capacity() == values[2] \
			and filtered.value.runtime_modulation_program().binding_count() == values[3]
	tests.expect_true(matches, "Dual Super Booster full-size authoring keeps 6/4/2 active layers, 4/4/2 persistent sprites, 12/0/0 particle capacity, and 24/24/12 shared-pulse-plus-turn bindings across HIGH/MEDIUM/LOW")


static func _test_twenty_dual_instances_project_linearly(tests: TestAssert) -> void:
	var policy_result := _policy_result()
	var plan := _plan()
	if not policy_result.success or plan == null:
		tests.expect_true(false, "Dual Super Booster stress projection requires a valid saved Preset render plan and performance policy.")
		return
	var filter := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var scenario_script := load("res://src/performance/vfx_stress_scenario.gd") as Script
	var projection_script := load("res://src/performance/vfx_scenario_projection.gd") as Script
	var matches := filter != null and analyzer != null and scenario_script != null and projection_script != null
	var scenario = scenario_script.new("20x1_super_booster_dual", 20, 1, "VEHICLE_STRESS", "STEADY_LOOP") if scenario_script != null else null
	for lod_level in ["HIGH", "MEDIUM", "LOW"]:
		var filtered: VfxResult = filter.new().filter(plan, lod_level, policy_result.value) if filter != null else VfxResult.failure([])
		var budget_result: VfxResult = analyzer.new(_registry()).analyze(filtered.value, {"anchors": {"REAR_CENTER": [0.0, 220.0]}}, "STEADY_LOOP") if analyzer != null and filtered.success else VfxResult.failure(filtered.issues)
		var workload = budget_result.value.active_workload() if budget_result.success else null
		var projection = projection_script.new().project([workload], scenario) if projection_script != null and workload != null and scenario != null else null
		var expected_sprites := 80 if lod_level != "LOW" else 40
		var expected_particles := 240 if lod_level == "HIGH" else 0
		matches = matches and projection != null and projection.persistent_textured_sprite_instance_count() == expected_sprites and projection.continuous_particle_capacity() == expected_particles
	tests.expect_true(matches, "Twenty full-size Dual Super Boosters project 80/80/40 persistent sprites and retain the two-emitter 240-particle hard cap only at HIGH")


static func _plan() -> RefCounted:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.super_booster.dual.vfx.json")
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
