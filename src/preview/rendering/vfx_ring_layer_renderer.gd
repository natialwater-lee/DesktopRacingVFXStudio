class_name VfxRingLayerRenderer
extends "res://src/preview/rendering/vfx_preview_layer_renderer.gd"

var _ring_ages: Array[float] = []
var _next_repeat_seconds := 0.0


func restart(frame_context: Dictionary) -> void:
	super.restart(frame_context)
	_ring_ages = [0.0]
	var repeat_interval: float = float(_parameters().get("repeat_interval_seconds", 0.0))
	_next_repeat_seconds = repeat_interval if repeat_interval > 0.0 else INF
	_refresh_packets(frame_context)


func advance(delta_seconds: float, frame_context: Dictionary) -> void:
	if _source_active:
		_elapsed_seconds += delta_seconds
	var parameters := _parameters()
	var duration_seconds: float = float(parameters.get("duration_seconds", 0.001))
	var next_ages: Array[float] = []
	for age in _ring_ages:
		var updated_age: float = age + delta_seconds
		if updated_age < duration_seconds:
			next_ages.append(updated_age)
	_ring_ages = next_ages
	if _source_active:
		var repeat_interval: float = float(parameters.get("repeat_interval_seconds", 0.0))
		while repeat_interval > 0.0 and _elapsed_seconds >= _next_repeat_seconds:
			_ring_ages.append(0.0)
			_next_repeat_seconds += repeat_interval
	_refresh_packets(frame_context)


func stop_emission() -> void:
	super.stop_emission()


func has_residual() -> bool:
	return not _ring_ages.is_empty()


func clear() -> void:
	super.clear()
	_ring_ages.clear()


func _refresh_packets(frame_context: Dictionary) -> void:
	_packets.clear()
	var parameters := _parameters()
	var duration_seconds: float = float(parameters.get("duration_seconds", 0.001))
	var radius_start: float = float(parameters.get("radius_start", 0.0))
	var radius_end: float = float(parameters.get("radius_end", 0.0))
	for age in _ring_ages:
		var packet := _packet_base(frame_context)
		packet["radius"] = lerpf(radius_start, radius_end, clampf(age / duration_seconds, 0.0, 1.0))
		packet["width"] = float(parameters.get("width", 0.0))
		packet["color_rgba"] = parameters.get("color_rgba", [1.0, 1.0, 1.0, 1.0]).duplicate()
		_packets.append(packet)
