class_name VfxPerformanceSnapshot
extends RefCounted

var _baseline_summary: Dictionary
var _vfx_summary: Dictionary
var _metadata: Dictionary
var _environment_context: Dictionary


func _init(baseline_summary: Dictionary, vfx_summary: Dictionary, metadata: Dictionary, environment_context: Dictionary) -> void:
	_baseline_summary = baseline_summary.duplicate(true)
	_vfx_summary = vfx_summary.duplicate(true)
	_metadata = metadata.duplicate(true)
	_environment_context = environment_context.duplicate(true)


func baseline_summary() -> Dictionary:
	return _baseline_summary.duplicate(true)


func vfx_summary() -> Dictionary:
	return _vfx_summary.duplicate(true)


func preview_frame_time_delta_ms() -> float:
	return float(_vfx_summary.get("average_frame_time_ms", 0.0)) - float(_baseline_summary.get("average_frame_time_ms", 0.0))


func calibration_state() -> String:
	return str(_metadata.get("calibration_state", ""))


func metadata() -> Dictionary:
	return _metadata.duplicate(true)


func environment_context() -> Dictionary:
	return _environment_context.duplicate(true)


func has_preset_write_path() -> bool:
	return false
