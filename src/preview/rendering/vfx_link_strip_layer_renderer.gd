class_name VfxLinkStripLayerRenderer
extends "res://src/preview/rendering/vfx_preview_layer_renderer.gd"
## Persistent strip from the layer Anchor to `frame_context.link_target_source` (host source px).

const VfxLinkStripGeometryModel := preload("res://src/preview/rendering/vfx_link_strip_geometry.gd")


func restart(frame_context: Dictionary) -> void:
	super.restart(frame_context)
	update_effective_packet(frame_context)


func advance(delta_seconds: float, frame_context: Dictionary) -> void:
	super.advance(delta_seconds, frame_context)
	update_effective_packet(frame_context)


func stop_emission() -> void:
	super.stop_emission()
	_packets.clear()


func update_effective_packet(frame_context: Dictionary) -> void:
	_packets.clear()
	if not _source_active or not frame_context.get("link_target_source") is Vector2:
		return
	var parameters := _parameters()
	var offset: Vector2 = _effective_state.effective_offset() if _effective_state != null else _instance.layer_spec().authored_offset()
	var width_scale: float = (_effective_state.effective_scale() as Vector2).x if _effective_state != null else (_instance.layer_spec().authored_scale() as Vector2).x
	var sag_offset: float = _effective_state.link_sag_offset() if _effective_state != null else 0.0
	var start: Vector2 = (_instance.anchor_source_position() as Vector2) + offset
	var sag := float(parameters.get("sag_source_px", 0.0)) + sag_offset + VfxLinkStripGeometryModel.gap_sag(parameters, _elapsed_seconds)
	var lines := VfxLinkStripGeometryModel.build(start, frame_context["link_target_source"], parameters, sag, _elapsed_seconds)
	for index in lines.size():
		var packet := _packet_base(frame_context)
		packet["position"] = Vector2.ZERO
		packet["geometry_scale"] = Vector2.ONE
		packet["geometry_rotation_degrees"] = 0.0
		packet["segment_index"] = index
		packet["points"] = lines[index]
		packet["width"] = float(parameters.get("width_source_px", 1.0)) * width_scale
		packet["texture_mode"] = str(parameters.get("texture_mode", "TILE"))
		packet["color_rgba"] = parameters.get("color_rgba", [1.0, 1.0, 1.0, 1.0])
		packet["alpha"] = final_visual_alpha(float(parameters.get("opacity", 1.0)))
		_packets.append(packet)
