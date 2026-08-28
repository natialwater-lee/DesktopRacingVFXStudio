class_name VfxTrailLayerRenderer
extends "res://src/preview/rendering/vfx_preview_layer_renderer.gd"

var _samples: Array[Dictionary] = []


func restart(frame_context: Dictionary) -> void:
	super.restart(frame_context)
	_samples.clear()
	_append_sample(frame_context)
	_refresh_packets(frame_context)


func advance(delta_seconds: float, frame_context: Dictionary) -> void:
	var lifetime_seconds: float = float(_parameters().get("lifetime_seconds", 0.001))
	var surviving: Array[Dictionary] = []
	for sample in _samples:
		var age: float = float(sample.get("age", 0.0)) + delta_seconds
		if age < lifetime_seconds:
			sample["age"] = age
			surviving.append(sample)
	_samples = surviving
	if _source_active:
		_elapsed_seconds += delta_seconds
		_append_sample(frame_context)
	_refresh_packets(frame_context)


func has_residual() -> bool:
	return not _samples.is_empty()


func clear() -> void:
	super.clear()
	_samples.clear()


func _append_sample(frame_context: Dictionary) -> void:
	_samples.append({"position": _canonical_source_position(frame_context), "age": 0.0})
	var max_points: int = int(_parameters().get("max_points", 2))
	while _samples.size() > max_points:
		_samples.remove_at(0)


func _canonical_source_position(frame_context: Dictionary) -> Vector2:
	return VfxPreviewCoordinateResolverModel.canonical_origin(_instance, frame_context)


func _refresh_packets(frame_context: Dictionary) -> void:
	_packets.clear()
	if _samples.is_empty():
		return
	var packet := _packet_base(frame_context)
	var points: Array[Vector2] = []
	for sample in _samples:
		points.append(sample.get("position", Vector2.ZERO))
	packet["points"] = points
	packet["width_start"] = float(_parameters().get("width_start", 0.0))
	packet["width_end"] = float(_parameters().get("width_end", 0.0))
	packet["color_rgba"] = _parameters().get("color_rgba", [1.0, 1.0, 1.0, 1.0]).duplicate()
	_packets.append(packet)
