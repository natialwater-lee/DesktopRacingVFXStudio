class_name VfxGlowLayerRenderer
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
	var opacity: float = float(parameters.get("opacity", 0.0))
	var pulse_hz: float = float(parameters.get("pulse_hz", 0.0))
	var alpha := opacity if is_zero_approx(pulse_hz) else opacity * (0.5 + 0.5 * sin(TAU * pulse_hz * _elapsed_seconds))
	var packet := _packet_base(frame_context)
	packet["radius"] = float(parameters.get("radius", 0.0))
	packet["alpha"] = alpha
	packet["color_rgba"] = parameters.get("color_rgba", [1.0, 1.0, 1.0, 1.0]).duplicate()
	_packets.append(packet)
