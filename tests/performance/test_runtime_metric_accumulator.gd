extends RefCounted


static func run(tests: TestAssert) -> void:
	_test_measurement_samples_average_max_p95_and_peaks(tests)
	_test_snapshot_prioritizes_preview_frame_time_delta(tests)
	_test_environment_context_respects_current_settings_by_default(tests)


static func _test_measurement_samples_average_max_p95_and_peaks(tests: TestAssert) -> void:
	var accumulator_script := load("res://src/performance/vfx_runtime_metric_accumulator.gd") as Script
	if accumulator_script == null:
		tests.expect_true(false, "Runtime Metric Accumulator script is available")
		return
	var accumulator = accumulator_script.new()
	accumulator.sample(0.25, {"alive_particle_count": 99})
	accumulator.begin_measurement()
	for sample in [0.010, 0.020, 0.030, 0.040, 0.050]:
		accumulator.sample(sample, {"active_vfx_instances": 3, "active_layer_renderers": 7, "active_runtime_instances": 7, "alive_particle_count": int(sample * 1000.0), "active_trail_point_count": 4, "active_ring_count": 2})
	var summary: Dictionary = accumulator.finish()
	tests.expect_true(summary.get("sample_count") == 5 and is_equal_approx(float(summary.get("average_frame_time_ms")), 30.0) and is_equal_approx(float(summary.get("max_frame_time_ms")), 50.0) and is_equal_approx(float(summary.get("p95_frame_time_ms")), 50.0), "Measurement excludes pre-begin warm-up samples and derives average, max, and bounded P95 Preview frame time")
	tests.expect_true(is_equal_approx(float(summary.get("average_fps")), 1000.0 / 30.0) and summary.get("alive_particle_peak") == 50 and summary.get("trail_point_peak") == 4 and summary.get("ring_peak") == 2, "Average Preview FPS is reciprocal of average frame time and runtime visual values are measured peaks")


static func _test_snapshot_prioritizes_preview_frame_time_delta(tests: TestAssert) -> void:
	var snapshot_script := load("res://src/performance/vfx_performance_snapshot.gd") as Script
	if snapshot_script == null:
		tests.expect_true(false, "Performance Snapshot script is available")
		return
	var snapshot = snapshot_script.new({"average_frame_time_ms": 11.0}, {"average_frame_time_ms": 17.5}, {"calibration_state": "UNCALIBRATED"}, {"vsync_mode": 1, "engine_max_fps": 60, "cap_limited": true})
	tests.expect_true(is_equal_approx(snapshot.preview_frame_time_delta_ms(), 6.5), "Session-only Snapshot exposes VFX minus baseline as the primary Preview Frame Time Delta")
	tests.expect_true(snapshot.calibration_state() == "UNCALIBRATED" and snapshot.environment_context().get("cap_limited") == true and not snapshot.has_preset_write_path(), "Snapshot records Uncalibrated guidance and VSync/cap context without a Preset persistence path")


static func _test_environment_context_respects_current_settings_by_default(tests: TestAssert) -> void:
	var environment_script := load("res://src/performance/vfx_stress_measurement_environment.gd") as Script
	if environment_script == null:
		tests.expect_true(false, "Stress Measurement Environment script is available")
		return
	var environment = environment_script.new()
	var context: Dictionary = environment.begin(false)
	tests.expect_true(context.has("vsync_mode") and context.has("engine_max_fps") and context.has("cap_limited") and context.get("temporary_uncap_applied") == false, "Studio Stress records current VSync/frame-cap context and changes neither by default")
	environment.restore()
