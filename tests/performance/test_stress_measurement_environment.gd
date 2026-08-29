extends RefCounted

const VfxStressMeasurementEnvironmentModel := preload("res://src/performance/vfx_stress_measurement_environment.gd")
const VfxPerformanceStressPreviewModel := preload("res://src/preview/performance/vfx_performance_stress_preview.gd")
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
	_test_environment_captures_not_requested_and_confirmed_readbacks(tests)
	_test_environment_reports_partial_and_unsupported_without_guessing(tests)
	_test_environment_reports_restore_readback_failure(tests)
	_test_stress_runner_restores_on_complete_cancel_error_and_teardown(tests)


static func _test_environment_captures_not_requested_and_confirmed_readbacks(tests: TestAssert) -> void:
	var unchanged_backend := FakeStressEnvironmentBackend.new(true, 17, 1, 144)
	var unchanged_environment = VfxStressMeasurementEnvironmentModel.new(unchanged_backend)
	var unchanged: Dictionary = unchanged_environment.begin(false)
	tests.expect_true(unchanged.get("before_run") == {"window_id": 17, "vsync_mode": 1, "engine_max_fps": 144} and unchanged.get("uncap_requested") == false and unchanged.get("uncap_verification") == "NOT_REQUESTED" and unchanged.get("after_uncap_request") == {"window_id": 17, "vsync_mode": 1, "engine_max_fps": 144}, "Environment records actual before/after read-backs without changing state when Temporary Uncap is not requested")

	var confirmed_backend := FakeStressEnvironmentBackend.new(true, 17, 1, 144)
	var confirmed_environment = VfxStressMeasurementEnvironmentModel.new(confirmed_backend)
	var confirmed: Dictionary = confirmed_environment.begin(true)
	tests.expect_true(confirmed.get("before_run") == {"window_id": 17, "vsync_mode": 1, "engine_max_fps": 144} and confirmed.get("uncap_requested") == true and confirmed.get("after_uncap_request") == {"window_id": 17, "vsync_mode": 0, "engine_max_fps": 0} and confirmed.get("uncap_verification") == "CONFIRMED" and confirmed.get("external_cap_possible") == true, "Environment separates a requested checkbox from CONFIRMED Godot VSync-disabled and Engine-cap-zero read-backs while retaining external-cap uncertainty")
	var restored: Dictionary = confirmed_environment.restore()
	tests.expect_true(restored.get("after_restore") == {"window_id": 17, "vsync_mode": 1, "engine_max_fps": 144} and restored.get("restore_verified") == true, "Environment restores and records the original VSync and Engine cap through actual post-restore read-back")


static func _test_environment_reports_partial_and_unsupported_without_guessing(tests: TestAssert) -> void:
	var partial_backend := FakeStressEnvironmentBackend.new(true, 3, 1, 120)
	partial_backend.reject_disable_vsync = true
	var partial_environment = VfxStressMeasurementEnvironmentModel.new(partial_backend)
	var partial: Dictionary = partial_environment.begin(true)
	tests.expect_true(partial.get("uncap_verification") == "PARTIAL" and partial.get("after_uncap_request") == {"window_id": 3, "vsync_mode": 1, "engine_max_fps": 0} and partial.get("cap_limited") == true and not partial.get("warnings", []).is_empty(), "Environment reports PARTIAL when read-back proves only the Engine cap changed and retains cap-limited interpretation")
	partial_environment.restore()

	var unsupported_backend := FakeStressEnvironmentBackend.new(false, 9, 1, 60)
	var unsupported_environment = VfxStressMeasurementEnvironmentModel.new(unsupported_backend)
	var unsupported: Dictionary = unsupported_environment.begin(true)
	tests.expect_true(unsupported.get("uncap_verification") == "UNSUPPORTED" and unsupported.get("uncap_requested") == true and unsupported.get("after_uncap_request") == {"window_id": null, "vsync_mode": null, "engine_max_fps": 60} and unsupported.get("warnings", []).size() == 1, "Environment reports UNSUPPORTED instead of inferring VSync state when the platform API cannot be controlled or read")
	unsupported_environment.restore()


static func _test_environment_reports_restore_readback_failure(tests: TestAssert) -> void:
	var backend := FakeStressEnvironmentBackend.new(true, 5, 1, 90)
	var environment = VfxStressMeasurementEnvironmentModel.new(backend)
	environment.begin(true)
	backend.reject_restore_vsync = true
	var restored: Dictionary = environment.restore()
	tests.expect_true(restored.get("restore_verified") == false and restored.get("after_restore") == {"window_id": 5, "vsync_mode": 0, "engine_max_fps": 90} and not restored.get("warnings", []).is_empty(), "Environment surfaces a restore read-back mismatch rather than silently claiming restoration succeeded")


static func _test_stress_runner_restores_on_complete_cancel_error_and_teardown(tests: TestAssert) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var completion_backend := FakeStressEnvironmentBackend.new(true, 0, 1, 144)
	var completion_environment = VfxStressMeasurementEnvironmentModel.new(completion_backend)
	var completion_preview = _preview(tree, completion_environment)
	completion_preview.set_timing_seconds({"baseline_warmup": 0.01, "baseline_measurement": 0.01, "vfx_warmup": 0.01, "vfx_measurement": 0.01})
	completion_preview.configure_stress_input(_valid_input())
	completion_preview.run_studio_stress(true)
	completion_preview.advance_stress(0.01)
	completion_preview.advance_stress(0.01)
	completion_preview.advance_stress(0.01)
	completion_preview.advance_stress(0.01)
	var completion_context: Dictionary = completion_preview.latest_snapshot().environment_context()
	tests.expect_true(completion_context.get("after_restore") == {"window_id": 0, "vsync_mode": 1, "engine_max_fps": 144}, "Normal Studio Stress completion stores the verified restore read-back in its session Snapshot")
	_cleanup_preview(tree, completion_preview)

	var cancel_backend := FakeStressEnvironmentBackend.new(true, 0, 1, 144)
	var cancel_environment = VfxStressMeasurementEnvironmentModel.new(cancel_backend)
	var cancel_preview = _preview(tree, cancel_environment)
	cancel_preview.configure_stress_input(_valid_input())
	cancel_preview.run_studio_stress(true)
	cancel_preview.cancel_studio_stress()
	tests.expect_true(cancel_environment.context().get("after_restore") == {"window_id": 0, "vsync_mode": 1, "engine_max_fps": 144}, "Cancel restores VSync and Engine max FPS through the same Measurement Environment")
	_cleanup_preview(tree, cancel_preview)

	var error_backend := FakeStressEnvironmentBackend.new(true, 0, 1, 144)
	var error_environment = VfxStressMeasurementEnvironmentModel.new(error_backend)
	var error_preview = _preview(tree, error_environment)
	error_preview.configure_stress_input(_valid_input())
	error_preview.run_studio_stress(true)
	error_preview.abort_studio_stress("test measurement error")
	tests.expect_true(error_preview.state_name() == "ERROR" and error_environment.context().get("after_restore") == {"window_id": 0, "vsync_mode": 1, "engine_max_fps": 144}, "Measurement error restores the captured environment before reporting ERROR")
	_cleanup_preview(tree, error_preview)

	var setup_backend := FakeStressEnvironmentBackend.new(true, 0, 1, 144)
	var setup_environment = VfxStressMeasurementEnvironmentModel.new(setup_backend)
	setup_environment.begin(true)
	var setup_preview = _preview(tree, setup_environment)
	var setup_result: VfxResult = setup_preview.run_studio_stress(false)
	tests.expect_true(not setup_result.success and setup_preview.state_name() == "ERROR" and setup_environment.context().get("after_restore") == {"window_id": 0, "vsync_mode": 1, "engine_max_fps": 144}, "Setup error restores a previously captured environment before returning its configuration error")
	_cleanup_preview(tree, setup_preview)

	var teardown_backend := FakeStressEnvironmentBackend.new(true, 0, 1, 144)
	var teardown_environment = VfxStressMeasurementEnvironmentModel.new(teardown_backend)
	var teardown_preview = _preview(tree, teardown_environment)
	teardown_preview.configure_stress_input(_valid_input())
	teardown_preview.run_studio_stress(true)
	_cleanup_preview(tree, teardown_preview)
	tests.expect_true(teardown_environment.context().get("after_restore") == {"window_id": 0, "vsync_mode": 1, "engine_max_fps": 144}, "Preview teardown restores the captured VSync and Engine max FPS state")


static func _preview(tree: SceneTree, environment: RefCounted) -> Node:
	var preview = VfxPerformanceStressPreviewModel.new(_registry(), VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()))
	preview.set_measurement_environment(environment)
	tree.root.add_child(preview)
	return preview


static func _cleanup_preview(tree: SceneTree, preview: Node) -> void:
	tree.root.remove_child(preview)
	preview.free()


static func _valid_input() -> Dictionary:
	return {
		"scenario": VfxStressScenarioModel.new("1x1", 1, 1, "VEHICLE_STRESS", "STEADY_LOOP"),
		"slot_plans": [_zero_zone_plan()],
		"profile_data": {"reference_image": {"path": "res://assets/reference/vehicles/formula_reference.png", "expected_source_size_px": [256, 512]}, "anchors": {"CENTER": [0, 0]}},
		"game_scale_contract": {"base_car_sprite_scale": [0.38, 0.38], "car_visual_scale": 0.25, "track_scales": [1.0]}
	}


static func _zero_zone_plan() -> RefCounted:
	var document: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document.value.normalized_data) if document.success else VfxResult.failure(document.issues)
	return result.value if result.success else null


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


class FakeStressEnvironmentBackend extends RefCounted:
	var supported: bool
	var window_id: int
	var vsync_mode: int
	var max_fps: int
	var reject_disable_vsync := false
	var reject_restore_vsync := false

	func _init(is_supported: bool, current_window_id: int, current_vsync_mode: int, current_max_fps: int) -> void:
		supported = is_supported
		window_id = current_window_id
		vsync_mode = current_vsync_mode
		max_fps = current_max_fps

	func supports_uncap() -> bool:
		return supported

	func main_window_id() -> int:
		return window_id

	func vsync_disabled_mode() -> int:
		return 0

	func read_vsync(target_window_id: int) -> Variant:
		return vsync_mode if supported and target_window_id == window_id else null

	func write_vsync(next_mode: int, _target_window_id: int) -> void:
		if next_mode == 0 and reject_disable_vsync:
			return
		if next_mode == 1 and reject_restore_vsync:
			return
		vsync_mode = next_mode

	func read_max_fps() -> int:
		return max_fps

	func write_max_fps(next_max_fps: int) -> void:
		max_fps = next_max_fps
