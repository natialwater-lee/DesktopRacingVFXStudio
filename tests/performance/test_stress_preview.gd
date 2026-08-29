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
	_test_paired_state_machine_uses_one_stage_and_creates_session_snapshot(tests)


static func _test_paired_state_machine_uses_one_stage_and_creates_session_snapshot(tests: TestAssert) -> void:
	var preview_script := load("res://src/preview/performance/vfx_performance_stress_preview.gd") as Script
	if preview_script == null:
		tests.expect_true(false, "Studio Preview Stress runner script is available")
		return
	var preview = preview_script.new(_registry(), VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()))
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(preview)
	preview.set_timing_seconds({"baseline_warmup": 0.1, "baseline_measurement": 0.2, "vfx_warmup": 0.1, "vfx_measurement": 0.2})
	var scenario := VfxStressScenarioModel.new("10x1", 10, 1, "VEHICLE_STRESS", "STEADY_LOOP")
	var plan := _zero_zone_plan()
	var configured: VfxResult = preview.configure_stress_input({"scenario": scenario, "slot_plans": [plan], "profile_data": _profile_data(), "game_scale_contract": _game_scale_contract()})
	var started: VfxResult = preview.run_studio_stress(false)
	var vehicle_ids: Array = preview.stage_vehicle_node_ids()
	preview.advance_stress(0.1)
	tests.expect_true(configured.success and started.success and preview.state_name() == "BASELINE_MEASURE" and preview.latest_stage_facts().get("packet_count") == 0, "Paired Studio Stress begins with a VFX-disabled baseline warm-up and moves to baseline measurement without packet work")
	preview.advance_stress(0.2)
	tests.expect_true(preview.state_name() == "VFX_WARMUP" and vehicle_ids == preview.stage_vehicle_node_ids(), "Baseline to VFX transition preserves the already-built vehicle Stage, grid, and scale")
	preview.advance_stress(0.1)
	preview.advance_stress(0.2)
	var snapshot = preview.latest_snapshot()
	var metadata: Dictionary = snapshot.metadata() if snapshot != null else {}
	tests.expect_true(preview.state_name() == "COMPLETE" and snapshot != null and snapshot.preview_frame_time_delta_ms() is float and snapshot.environment_context().has("cap_limited") and preview.state_history() == ["PREPARE", "BASELINE_WARMUP", "BASELINE_MEASURE", "VFX_WARMUP", "VFX_MEASURE", "COMPLETE"] and metadata.get("workload_type") == "STEADY_LOOP" and metadata.get("synchronization") == "SYNCHRONIZED", "Paired Studio Stress records the complete PREPARE-to-COMPLETE order and a session-only Snapshot with Studio workload, synchronization, and environment context")
	tree.root.remove_child(preview)
	preview.free()


static func _zero_zone_plan() -> RefCounted:
	var document: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document.value.normalized_data) if document.success else VfxResult.failure(document.issues)
	return result.value if result.success else null


static func _profile_data() -> Dictionary:
	return {"reference_image": {"path": "res://assets/reference/vehicles/formula_reference.png", "expected_source_size_px": [256, 512]}, "anchors": {"CENTER": [0, 0]}}


static func _game_scale_contract() -> Dictionary:
	return {"base_car_sprite_scale": [0.38, 0.38], "car_visual_scale": 0.25, "track_scales": [1.0]}


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
