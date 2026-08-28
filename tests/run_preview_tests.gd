extends SceneTree

const TestAssertHelper := preload("res://tests/support/test_assert.gd")
const VehicleProfileTests := preload("res://tests/preview/test_vehicle_profiles.gd")
const PreviewGameScaleTests := preload("res://tests/preview/test_preview_game_scale.gd")
const PreviewFoundationTests := preload("res://tests/preview/test_preview_foundation.gd")
const AnchorPreviewInteractionTests := preload("res://tests/preview/test_anchor_preview_interaction.gd")
const EditorPreviewIntegrationTests := preload("res://tests/preview/test_editor_preview_integration.gd")
const PreviewStabilizationTests := preload("res://tests/preview/test_preview_stabilization.gd")
const PreviewRenderPlanTests := preload("res://tests/preview/test_preview_render_plan.gd")
const StaticLayerRendererTests := preload("res://tests/preview/test_static_layer_renderers.gd")
const DynamicLayerRendererTests := preload("res://tests/preview/test_dynamic_layer_renderers.gd")
const PreviewPlaybackTests := preload("res://tests/preview/test_preview_playback.gd")
const PreviewStaleStateTests := preload("res://tests/preview/test_preview_stale_state.gd")
const RendererShowcaseTests := preload("res://tests/preview/test_renderer_showcase.gd")
const ZeroZoneVisibilityDiagnosticTests := preload("res://tests/preview/test_zero_zone_visibility_diagnostic.gd")
const TexturedParticleAssetTests := preload("res://tests/preview/test_textured_particle_assets.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tests := TestAssertHelper.new()
	VehicleProfileTests.run(tests)
	PreviewGameScaleTests.run(tests)
	PreviewFoundationTests.run(tests)
	AnchorPreviewInteractionTests.run(tests)
	EditorPreviewIntegrationTests.run(tests)
	PreviewStabilizationTests.run(tests)
	PreviewRenderPlanTests.run(tests)
	StaticLayerRendererTests.run(tests)
	DynamicLayerRendererTests.run(tests)
	PreviewPlaybackTests.run(tests)
	PreviewStaleStateTests.run(tests)
	RendererShowcaseTests.run(tests)
	ZeroZoneVisibilityDiagnosticTests.run(tests)
	TexturedParticleAssetTests.run(tests)
	print("PREVIEW_TEST_ASSERTIONS=%d FAILURES=%d" % [tests.assertion_count(), tests.failure_count()])
	quit(1 if tests.failure_count() > 0 else 0)
