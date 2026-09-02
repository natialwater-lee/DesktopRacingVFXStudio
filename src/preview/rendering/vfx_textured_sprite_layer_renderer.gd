class_name VfxTexturedSpriteLayerRenderer
extends "res://src/preview/rendering/vfx_preview_layer_renderer.gd"


func restart(frame_context: Dictionary) -> void:
	super.restart(frame_context)
	_create_persistent_packet(frame_context)


func advance(delta_seconds: float, frame_context: Dictionary) -> void:
	super.advance(delta_seconds, frame_context)
	update_effective_packet(frame_context)


func stop_emission() -> void:
	super.stop_emission()
	_packets.clear()


func _create_persistent_packet(frame_context: Dictionary) -> void:
	_packets.clear()
	if not _source_active:
		return
	var packet := _packet_base(frame_context)
	packet["alpha"] = final_visual_alpha(float(_parameters().get("opacity", 1.0)))
	_packets.append(packet)


func update_effective_packet(frame_context: Dictionary) -> void:
	if not _source_active or _packets.is_empty():
		return
	var packet: Dictionary = _packets[0]
	packet["position"] = VfxPreviewCoordinateResolver.canonical_origin_with_effective(_instance, _effective_state, frame_context)
	packet["geometry_scale"] = VfxPreviewCoordinateResolver.geometry_scale_with_effective(_instance, _effective_state, frame_context)
	packet["geometry_rotation_degrees"] = VfxPreviewCoordinateResolver.geometry_rotation_with_effective(_instance, _effective_state, frame_context)
	packet["alpha"] = final_visual_alpha(float(_parameters().get("opacity", 1.0)))
