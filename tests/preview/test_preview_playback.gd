extends RefCounted

const VfxPreviewRenderPlanModel := preload("res://src/preview/rendering/vfx_preview_render_plan.gd")
const VfxPreviewPhasePlanModel := preload("res://src/preview/rendering/vfx_preview_phase_plan.gd")


static func run(tests: TestAssert) -> void:
	_test_one_shot_stops_sources_then_drains(tests)
	_test_start_loop_end_uses_preview_only_loop_duration(tests)
	_test_manual_phase_isolated_from_auto_route(tests)
	_test_pause_freezes_fixed_simulation_time(tests)


static func _test_one_shot_stops_sources_then_drains(tests: TestAssert) -> void:
	var controller_script := load("res://src/preview/rendering/vfx_preview_playback_controller.gd") as Script
	tests.expect_true(controller_script != null, "Preview Playback Controller script is available")
	if controller_script == null:
		return
	var runtime := _FakeRuntime.new()
	var controller = controller_script.new(_one_shot_plan(), runtime)
	controller.restart({})
	controller.advance(0.2, {})
	tests.expect_true(runtime.stopped_phases == ["one_shot"] and controller.state_name() == "DRAINING", "ONE_SHOT stops its declared source duration before waiting for renderer residual drain")
	runtime.residual = false
	controller.advance(1.0 / 60.0, {})
	tests.expect_true(controller.state_name() == "TERMINATED", "Playback terminates after the last declared residual is gone")


static func _test_start_loop_end_uses_preview_only_loop_duration(tests: TestAssert) -> void:
	var controller_script := load("res://src/preview/rendering/vfx_preview_playback_controller.gd") as Script
	if controller_script == null:
		tests.expect_true(false, "Lifecycle test requires the Preview Playback Controller")
		return
	var runtime := _FakeRuntime.new()
	runtime.residual = false
	var controller = controller_script.new(_start_loop_end_plan(), runtime)
	controller.restart({})
	controller.advance(0.11, {})
	controller.advance(2.01, {})
	controller.advance(0.11, {})
	tests.expect_true(runtime.activated_phases == ["start", "loop", "end"] and runtime.stopped_phases == ["start", "loop", "end"], "Auto START_LOOP_END activates Start, an unsaved two-second Preview Loop, then End")


static func _test_pause_freezes_fixed_simulation_time(tests: TestAssert) -> void:
	var controller_script := load("res://src/preview/rendering/vfx_preview_playback_controller.gd") as Script
	if controller_script == null:
		tests.expect_true(false, "Pause test requires the Preview Playback Controller")
		return
	var controller = controller_script.new(_one_shot_plan(), _FakeRuntime.new())
	controller.restart({})
	controller.advance(0.1, {})
	var before_pause: float = controller.simulation_time()
	controller.pause()
	controller.advance(1.0, {})
	tests.expect_true(is_equal_approx(controller.simulation_time(), before_pause), "Pause freezes the fixed Preview simulation clock rather than merely stopping new emission")


static func _test_manual_phase_isolated_from_auto_route(tests: TestAssert) -> void:
	var controller_script := load("res://src/preview/rendering/vfx_preview_playback_controller.gd") as Script
	if controller_script == null:
		tests.expect_true(false, "Manual lifecycle test requires the Preview Playback Controller")
		return
	var runtime := _FakeRuntime.new()
	var controller = controller_script.new(_start_loop_end_plan(), runtime)
	controller.set_auto_playback(false)
	controller.set_manual_phase("loop")
	controller.restart({})
	controller.advance(3.0, {})
	tests.expect_true(runtime.activated_phases == ["loop"] and runtime.stopped_phases.is_empty() and controller.active_phase_name() == "loop", "Manual playback isolates the selected loop phase instead of applying the Auto Start/Loop/End route")


static func _one_shot_plan() -> RefCounted:
	return VfxPreviewRenderPlanModel.new("utility.playback", "ONE_SHOT", [VfxPreviewPhasePlanModel.new("one_shot", 0.1, [])], 1)


static func _start_loop_end_plan() -> RefCounted:
	return VfxPreviewRenderPlanModel.new("utility.playback", "START_LOOP_END", [VfxPreviewPhasePlanModel.new("start", 0.1, []), VfxPreviewPhasePlanModel.new("loop", null, []), VfxPreviewPhasePlanModel.new("end", 0.1, [])], 1)


class _FakeRuntime:
	extends RefCounted

	var activated_phases: Array[String] = []
	var stopped_phases: Array[String] = []
	var residual := true

	func clear() -> void:
		activated_phases.clear()
		stopped_phases.clear()

	func activate_phase(phase_name: String, _frame_context: Dictionary) -> void:
		activated_phases.append(phase_name)

	func stop_phase_sources(phase_name: String) -> void:
		stopped_phases.append(phase_name)

	func advance(_delta_seconds: float, _frame_context: Dictionary) -> void:
		pass

	func has_residual() -> bool:
		return residual
