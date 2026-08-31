extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const VfxPreviewWorkspaceModel := preload("res://src/preview/vfx_preview_workspace.gd")
const VfxPerformanceSnapshotModel := preload("res://src/performance/vfx_performance_snapshot.gd")


static func run(tests: TestAssert) -> void:
	_test_authoring_preview_lod_and_performance_sections_are_separate(tests)


static func _test_authoring_preview_lod_and_performance_sections_are_separate(tests: TestAssert) -> void:
	var workspace := VfxPreviewWorkspaceModel.new()
	if workspace == null:
		tests.expect_true(false, "Performance UI test requires the runtime Preview Workspace")
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(workspace)
	workspace.set_schema_registry(_registry())
	workspace.set_game_scale_contract(_game_scale_contract())
	workspace.set_profile_data(_profile_data())
	workspace.apply_render_plan(_zero_zone_plan())
	var lod_select := workspace.get_node_or_null("VfxVehiclePreview/PreviewControls/PerformanceRow/LodSelect") as OptionButton
	var performance_panel := workspace.get_node_or_null("PerformancePanel")
	var mode_select := workspace.get_node_or_null("WorkspaceControls/PreviewModeSelect") as OptionButton
	tests.expect_true(lod_select != null and lod_select.item_count == 3 and performance_panel != null and mode_select != null, "Runtime Preview Workspace separates its Authoring LOD control from the Authoring/Performance mode switch without changing the main Editor scene")
	workspace.set_preview_lod_level("LOW")
	var low_plan: RefCounted = workspace.active_render_plan()
	tests.expect_true(low_plan != null and low_plan.phase_named("loop").layer_specs().size() == 2, "Authoring Preview LOD selection retains the CORE focus and tunnel arc through the same immutable LOD filter used by Studio Stress")
	tests.expect_true(performance_panel.has_authoring_budget_section() and performance_panel.has_studio_stress_result_section() and performance_panel.guidance_text().contains("UNCALIBRATED"), "Performance UI separates Authoring Budget from Studio Preview Stress Result and labels threshold guidance as Uncalibrated")
	performance_panel.present_snapshot(VfxPerformanceSnapshotModel.new({"average_frame_time_ms": 10.0}, {"average_frame_time_ms": 10.0, "max_frame_time_ms": 20.0, "p95_frame_time_ms": 18.0, "average_fps": 76.9, "alive_particle_peak": 12, "trail_point_peak": 8, "ring_peak": 3, "active_vfx_instance_peak": 4, "active_layer_renderer_peak": 5, "active_runtime_instance_peak": 6}, {"calibration_state": "UNCALIBRATED"}, {"cap_limited": false, "uncap_requested": true, "uncap_verification": "CONFIRMED", "external_cap_possible": true, "actual_headroom_unknown": true, "restore_verified": false, "before_run": {"window_id": 0, "vsync_mode": 1, "engine_max_fps": 0}, "after_uncap_request": {"window_id": 0, "vsync_mode": 0, "engine_max_fps": 0}, "after_restore": {"window_id": 0, "vsync_mode": 1, "engine_max_fps": 0}}))
	var result_text: String = performance_panel.stress_result_text()
	tests.expect_true(result_text.contains("Baseline Avg") and result_text.contains("VFX Avg") and result_text.contains("Preview Frame Time Delta") and result_text.contains("Max") and result_text.contains("P95") and result_text.contains("Average Preview FPS") and result_text.contains("Particle Peak") and result_text.contains("Trail Point Peak") and result_text.contains("Ring Peak") and result_text.contains("Runtime Instance Count") and result_text.contains("Uncap Verification: CONFIRMED") and result_text.contains("EXTERNAL CAP POSSIBLE") and result_text.contains("Preview cost below observable limiter") and result_text.contains("Actual headroom unknown") and result_text.contains("ENVIRONMENT RESTORE WARNING") and result_text.contains("GPU time: N/A"), "Studio Stress Result distinguishes internally confirmed uncap from external-cap uncertainty and never interprets a zero delta as zero VFX cost")
	tree.root.remove_child(workspace)
	workspace.free()


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
