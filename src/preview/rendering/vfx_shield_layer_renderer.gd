class_name VfxShieldLayerRenderer
extends "res://src/preview/rendering/vfx_preview_layer_renderer.gd"


func restart(frame_context: Dictionary) -> void:
	super.restart(frame_context)
	_refresh_packet(frame_context)


func advance(delta_seconds: float, frame_context: Dictionary) -> void:
	super.advance(delta_seconds, frame_context)
	_refresh_packet(frame_context)


func stop_emission() -> void:
	super.stop_emission()
	_packets.clear()


func _refresh_packet(frame_context: Dictionary) -> void:
	_packets.clear()
	if not _source_active:
		return
	var parameters := _parameters()
	var packet := _packet_base(frame_context)
	packet["radius"] = float(parameters.get("radius", 0.0))
	packet["arc_degrees"] = float(parameters.get("arc_degrees", 360.0))
	packet["thickness"] = float(parameters.get("thickness", 0.0))
	packet["alpha"] = float(parameters.get("opacity", 0.0))
	packet["scroll_offset"] = _elapsed_seconds * float(parameters.get("scroll_speed", 0.0))
	packet["color_rgba"] = parameters.get("color_rgba", [1.0, 1.0, 1.0, 1.0]).duplicate()
	_packets.append(packet)
