extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")

# preset id -> LOD -> [expanded instances, persistent sprites, continuous particle capacity, modulation bindings]
const EXPECTED := {
	"equipment.super_booster": {"HIGH": [9, 7, 5, 57], "MEDIUM": [5, 5, 0, 47], "LOW": [1, 1, 0, 19]},
	"equipment.super_booster.dual": {"HIGH": [14, 11, 6, 94], "MEDIUM": [8, 8, 0, 78], "LOW": [2, 2, 0, 38]},
	"equipment.super_booster.mk4": {"HIGH": [17, 14, 6, 117], "MEDIUM": [11, 11, 0, 101], "LOW": [4, 4, 0, 52]}
}


static func run(tests: TestAssert) -> void:
	for preset_id in EXPECTED:
		_test_lod_budget(tests, preset_id)
		_test_twenty_vehicle_projection_stays_safe(tests, preset_id)


static func _test_lod_budget(tests: TestAssert, preset_id: String) -> void:
	var policy_result := _policy_result()
	var plan := _plan(preset_id)
	if not policy_result.success or plan == null:
		tests.expect_true(false, "%s LOD budget requires a valid Preset render plan and performance policy" % preset_id)
		return
	var filter := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var matches := filter != null and analyzer != null
	for lod_level in EXPECTED[preset_id]:
		var filtered: VfxResult = filter.new().filter(plan, lod_level, policy_result.value) if filter != null else VfxResult.failure([])
		var budget_result: VfxResult = analyzer.new(_registry()).analyze(filtered.value, {"anchors": {"REAR_CENTER": [0.0, 220.0]}}, "STEADY_LOOP") if analyzer != null and filtered.success else VfxResult.failure(filtered.issues)
		var workload = budget_result.value.active_workload() if budget_result.success else null
		var values: Array = EXPECTED[preset_id][lod_level]
		matches = matches and workload != null and workload.expanded_instance_count() == values[0] \
			and workload.persistent_textured_sprite_instance_count() == values[1] and workload.continuous_particle_capacity() == values[2] \
			and filtered.value.runtime_modulation_program().binding_count() == values[3]
	tests.expect_true(matches, "%s keeps its documented renderer, sprite, particle-capacity and binding inventory at HIGH/MEDIUM/LOW (EXTRA sparks and pulses drop at MEDIUM, only the CORE jets stay at LOW)" % preset_id)


static func _test_twenty_vehicle_projection_stays_safe(tests: TestAssert, preset_id: String) -> void:
	var policy_result := _policy_result()
	var plan := _plan(preset_id)
	if not policy_result.success or plan == null:
		tests.expect_true(false, "%s stress projection requires a valid Preset render plan and performance policy" % preset_id)
		return
	var filter := load("res://src/performance/vfx_preview_lod_filter.gd") as Script
	var analyzer := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var scenario_script := load("res://src/performance/vfx_stress_scenario.gd") as Script
	var projection_script := load("res://src/performance/vfx_scenario_projection.gd") as Script
	var scenario = scenario_script.new("20x1_super_booster", 20, 1, "VEHICLE_STRESS", "STEADY_LOOP")
	var matches := filter != null and analyzer != null and projection_script != null
	for lod_level in ["HIGH", "MEDIUM", "LOW"]:
		var filtered: VfxResult = filter.new().filter(plan, lod_level, policy_result.value)
		var budget_result: VfxResult = analyzer.new(_registry()).analyze(filtered.value, {"anchors": {"REAR_CENTER": [0.0, 220.0]}}, "STEADY_LOOP") if filtered.success else VfxResult.failure(filtered.issues)
		var workload = budget_result.value.active_workload() if budget_result.success else null
		var projection = projection_script.new().project([workload], scenario) if workload != null else null
		var values: Array = EXPECTED[preset_id][lod_level]
		matches = matches and projection != null and projection.persistent_textured_sprite_instance_count() == 20 * values[1] \
			and projection.continuous_particle_capacity() == 20 * values[2] \
			and 20 * values[0] < 360 # SAFE threshold: expanded_runtime_instances
	tests.expect_true(matches, "Twenty %s vehicles project linearly and stay under the SAFE expanded-instance threshold of 360 at every LOD" % preset_id)


static func _plan(preset_id: String) -> RefCounted:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/%s.vfx.json" % preset_id)
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
