class_name VfxPreviewPlaybackController
extends RefCounted

const FIXED_TICK_SECONDS := 1.0 / 60.0
const DEFAULT_LOOP_DURATION_SECONDS := 2.0
const TIME_COMPARISON_EPSILON := 0.000001

var _plan: RefCounted
var _runtime: RefCounted
var _auto_playback := true
var _manual_phase := ""
var _state := "IDLE"
var _active_phase := ""
var _phase_elapsed_seconds := 0.0
var _simulation_time_seconds := 0.0
var _accumulator_seconds := 0.0
var _generation := 0


func _init(plan: RefCounted, runtime: RefCounted) -> void:
	_plan = plan
	_runtime = runtime


func set_auto_playback(enabled: bool) -> void:
	_auto_playback = enabled


func set_manual_phase(phase_name: String) -> void:
	_manual_phase = phase_name
	if not _auto_playback:
		restart({})


func play(frame_context: Dictionary = {}) -> void:
	if _state == "PAUSED":
		_state = "PLAYING"
	elif _state == "IDLE" or _state == "TERMINATED":
		restart(frame_context)


func pause() -> void:
	if _state == "PLAYING" or _state == "DRAINING":
		_state = "PAUSED"


func restart(frame_context: Dictionary = {}) -> void:
	if _runtime == null or _plan == null:
		_state = "IDLE"
		return
	_runtime.clear()
	_generation += 1
	_phase_elapsed_seconds = 0.0
	_simulation_time_seconds = 0.0
	_accumulator_seconds = 0.0
	_active_phase = _initial_phase()
	_state = "PLAYING"
	_runtime.activate_phase(_active_phase, _frame_context(frame_context))


func advance(real_delta_seconds: float, frame_context: Dictionary) -> void:
	if _state != "PLAYING" and _state != "DRAINING":
		return
	_accumulator_seconds += maxf(real_delta_seconds, 0.0)
	while _accumulator_seconds >= FIXED_TICK_SECONDS:
		_accumulator_seconds -= FIXED_TICK_SECONDS
		_simulation_time_seconds += FIXED_TICK_SECONDS
		_phase_elapsed_seconds += FIXED_TICK_SECONDS
		var tick_context := _frame_context(frame_context)
		_runtime.advance(FIXED_TICK_SECONDS, tick_context)
		_advance_lifecycle(tick_context)


func simulation_time() -> float:
	return _simulation_time_seconds


func state_name() -> String:
	return _state


func active_phase_name() -> String:
	return _active_phase


func generation() -> int:
	return _generation


func is_advancing() -> bool:
	return _state == "PLAYING" or _state == "DRAINING"


func _advance_lifecycle(frame_context: Dictionary) -> void:
	if _state == "DRAINING":
		if not _runtime.has_residual():
			_state = "TERMINATED"
		return
	if _auto_playback and _plan.lifecycle_mode() == "START_LOOP_END":
		if _active_phase == "start" and _duration_elapsed("start"):
			_transition_to("loop", frame_context)
		elif _active_phase == "loop" and _phase_elapsed_seconds >= DEFAULT_LOOP_DURATION_SECONDS:
			_transition_to("end", frame_context)
		elif _active_phase == "end" and _duration_elapsed("end"):
			_stop_and_drain()
		return
	if _active_phase != "loop" and _duration_elapsed(_active_phase):
		_stop_and_drain()


func _transition_to(next_phase: String, frame_context: Dictionary) -> void:
	_runtime.stop_phase_sources(_active_phase)
	_active_phase = next_phase
	_phase_elapsed_seconds = 0.0
	_runtime.activate_phase(_active_phase, frame_context)


func _stop_and_drain() -> void:
	_runtime.stop_phase_sources(_active_phase)
	_state = "DRAINING"


func _duration_elapsed(phase_name: String) -> bool:
	var phase_plan: RefCounted = _plan.phase_named(phase_name)
	return phase_plan != null and phase_plan.has_duration() and _phase_elapsed_seconds + TIME_COMPARISON_EPSILON >= phase_plan.duration_seconds()


func _initial_phase() -> String:
	if not _auto_playback and not _manual_phase.is_empty():
		return _manual_phase
	if _plan.lifecycle_mode() == "ONE_SHOT":
		return "one_shot"
	return "start"


func _frame_context(frame_context: Dictionary) -> Dictionary:
	var result := frame_context.duplicate(true)
	result["playback_generation"] = _generation
	result["preview_time"] = _simulation_time_seconds
	return result
