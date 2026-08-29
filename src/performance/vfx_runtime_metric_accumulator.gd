class_name VfxRuntimeMetricAccumulator
extends RefCounted

var _measuring := false
var _frame_times_ms: Array[float] = []
var _peaks := {
	"active_vfx_instance_peak": 0,
	"active_layer_renderer_peak": 0,
	"active_runtime_instance_peak": 0,
	"alive_particle_peak": 0,
	"trail_point_peak": 0,
	"ring_peak": 0
}


func begin_measurement() -> void:
	_measuring = true
	_frame_times_ms.clear()
	for key in _peaks:
		_peaks[key] = 0


func sample(frame_delta_seconds: float, runtime_facts: Dictionary) -> void:
	if not _measuring:
		return
	_frame_times_ms.append(maxf(frame_delta_seconds, 0.0) * 1000.0)
	_peaks["active_vfx_instance_peak"] = maxi(_peaks["active_vfx_instance_peak"], int(runtime_facts.get("active_vfx_instances", 0)))
	_peaks["active_layer_renderer_peak"] = maxi(_peaks["active_layer_renderer_peak"], int(runtime_facts.get("active_layer_renderers", 0)))
	_peaks["active_runtime_instance_peak"] = maxi(_peaks["active_runtime_instance_peak"], int(runtime_facts.get("active_runtime_instances", 0)))
	_peaks["alive_particle_peak"] = maxi(_peaks["alive_particle_peak"], int(runtime_facts.get("alive_particle_count", 0)))
	_peaks["trail_point_peak"] = maxi(_peaks["trail_point_peak"], int(runtime_facts.get("active_trail_point_count", 0)))
	_peaks["ring_peak"] = maxi(_peaks["ring_peak"], int(runtime_facts.get("active_ring_count", 0)))


func finish() -> Dictionary:
	_measuring = false
	var average_ms := 0.0
	var max_ms := 0.0
	for value in _frame_times_ms:
		average_ms += value
		max_ms = maxf(max_ms, value)
	if not _frame_times_ms.is_empty():
		average_ms /= float(_frame_times_ms.size())
	var ordered := _frame_times_ms.duplicate()
	ordered.sort()
	var p95_ms := 0.0
	if not ordered.is_empty():
		var p95_index := mini(ordered.size() - 1, maxi(0, int(ceil(float(ordered.size()) * 0.95)) - 1))
		p95_ms = ordered[p95_index]
	return {
		"sample_count": _frame_times_ms.size(),
		"average_frame_time_ms": average_ms,
		"max_frame_time_ms": max_ms,
		"p95_frame_time_ms": p95_ms,
		"average_fps": 1000.0 / average_ms if average_ms > 0.0 else 0.0,
		"active_vfx_instance_peak": _peaks["active_vfx_instance_peak"],
		"active_layer_renderer_peak": _peaks["active_layer_renderer_peak"],
		"active_runtime_instance_peak": _peaks["active_runtime_instance_peak"],
		"alive_particle_peak": _peaks["alive_particle_peak"],
		"trail_point_peak": _peaks["trail_point_peak"],
		"ring_peak": _peaks["ring_peak"]
	}
