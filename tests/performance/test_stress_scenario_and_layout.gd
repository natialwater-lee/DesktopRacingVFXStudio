extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const VfxPreviewRendererFactoryModel := preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxStressScenarioModel := preload("res://src/performance/vfx_stress_scenario.gd")


static func run(tests: TestAssert) -> void:
	_test_scenario_counts_and_game_scale_are_not_fit_scaled(tests)
	_test_same_stage_baseline_disables_all_vfx_work(tests)
	_test_celebration_stress_is_not_derived_or_available(tests)


static func _test_scenario_counts_and_game_scale_are_not_fit_scaled(tests: TestAssert) -> void:
	var stage_script := load("res://src/preview/performance/vfx_performance_stress_stage.gd") as Script
	if stage_script == null:
		tests.expect_true(false, "Dedicated Studio Preview Stress Stage script is available")
		return
	var stage = _stage(stage_script)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(stage)
	var scenario := VfxStressScenarioModel.new("20x3", 20, 3, "VEHICLE_STRESS", "STEADY_LOOP")
	var plan := _zero_zone_plan()
	var prepared: VfxResult = stage.prepare(scenario, [plan, plan, plan], _profile_data(), _game_scale_contract())
	tests.expect_true(prepared.success and stage.vehicle_count() == 20 and stage.runtime_slot_count() == 60, "20x3 Studio Stress constructs twenty minimal vehicles and sixty runtime slots without cloning VfxVehiclePreview controls")
	var scales: Array = stage.vehicle_scales()
	tests.expect_true(scales.size() == 20 and scales.all(func(value: Vector2) -> bool: return value.is_equal_approx(Vector2(0.095, 0.095))), "Stress vehicle scale uses base sprite scale x visual scale x track scale and never fits vehicles or VFX to Stage size")
	tree.root.remove_child(stage)
	stage.free()


static func _test_celebration_stress_is_not_derived_or_available(tests: TestAssert) -> void:
	var stage_script := load("res://src/preview/performance/vfx_performance_stress_stage.gd") as Script
	if stage_script == null:
		tests.expect_true(false, "Celebration seam test requires the dedicated Stress Stage")
		return
	var stage = _stage(stage_script)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(stage)
	var celebration_scenario := VfxStressScenarioModel.new("celebration", 1, 1, "CELEBRATION_STRESS", "STEADY_LOOP")
	var prepared: VfxResult = stage.prepare(celebration_scenario, [_zero_zone_plan()], _profile_data(), _game_scale_contract())
	tests.expect_true(not prepared.success and prepared.issues.any(func(issue: VfxIssue) -> bool: return issue.code == "stress_scope"), "Phase 4 exposes VEHICLE_STRESS only; CELEBRATION_STRESS remains an explicit unavailable future seam")
	tree.root.remove_child(stage)
	stage.free()


static func _test_same_stage_baseline_disables_all_vfx_work(tests: TestAssert) -> void:
	var stage_script := load("res://src/preview/performance/vfx_performance_stress_stage.gd") as Script
	if stage_script == null:
		tests.expect_true(false, "Baseline behavior requires the Dedicated Studio Preview Stress Stage")
		return
	var stage = _stage(stage_script)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(stage)
	var scenario := VfxStressScenarioModel.new("10x3", 10, 3, "VEHICLE_STRESS", "STEADY_LOOP")
	var plan := _zero_zone_plan()
	var prepared: VfxResult = stage.prepare(scenario, [plan, plan, plan], _profile_data(), _game_scale_contract())
	var before_ids: Array = stage.vehicle_node_ids()
	stage.set_vfx_enabled(false)
	var baseline_facts: Dictionary = stage.advance(1.0)
	var after_baseline_ids: Array = stage.vehicle_node_ids()
	tests.expect_true(prepared.success and baseline_facts.get("active_vfx_instances", -1) == 0 and baseline_facts.get("active_layer_renderers", -1) == 0 and baseline_facts.get("packet_count", -1) == 0, "Baseline advances no playback, simulation, packet generation, or VFX routing while preserving allocated runtime objects")
	tests.expect_true(before_ids == after_baseline_ids, "Baseline measurement retains the same Stress vehicle nodes, grid, profile, and game-scale state for the paired VFX run")
	stage.set_vfx_enabled(true)
	var vfx_facts: Dictionary = stage.advance(1.0 / 60.0)
	tests.expect_true(vfx_facts.get("active_vfx_instances", 0) == 30 and vfx_facts.get("active_layer_renderers", 0) == 150 and vfx_facts.get("packet_count", 0) > 0, "Enabling the same Stage starts synchronized STEADY_LOOP work through existing Runtime and Playback paths")
	tree.root.remove_child(stage)
	stage.free()


static func _stage(stage_script: Script) -> Control:
	var registry := _registry()
	var asset_registry := VfxPreviewAssetRegistryModel.new()
	return stage_script.new(registry, VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(asset_registry))


static func _zero_zone_plan() -> RefCounted:
	var document: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document.value.normalized_data) if document.success else VfxResult.failure(document.issues)
	return result.value if result.success else null


static func _profile_data() -> Dictionary:
	return {
		"reference_image": {"path": "res://assets/reference/vehicles/formula_reference.png", "expected_source_size_px": [256, 512]},
		"anchors": {"CENTER": [0, 0]}
	}


static func _game_scale_contract() -> Dictionary:
	return {"base_car_sprite_scale": [0.38, 0.38], "car_visual_scale": 0.25, "track_scales": [1.0]}


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
