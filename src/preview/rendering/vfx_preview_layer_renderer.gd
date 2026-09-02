class_name VfxPreviewLayerRenderer
extends RefCounted

const VfxPreviewCoordinateResolverModel := preload("res://src/preview/rendering/vfx_preview_coordinate_resolver.gd")

var _instance: RefCounted
var _asset: Dictionary
var _source_active := false
var _elapsed_seconds := 0.0
var _packets: Array[Dictionary] = []
var _effective_state: RefCounted


func _init(instance: RefCounted, asset: Dictionary, effective_state: RefCounted = null) -> void:
	_instance = instance
	_asset = asset.duplicate(true)
	_effective_state = effective_state


func restart(frame_context: Dictionary) -> void:
	_source_active = true
	_elapsed_seconds = 0.0
	_packets.clear()


func advance(delta_seconds: float, frame_context: Dictionary) -> void:
	if _source_active:
		_elapsed_seconds += delta_seconds


func stop_emission() -> void:
	_source_active = false


func is_source_active() -> bool:
	return _source_active


func has_residual() -> bool:
	return false


func clear() -> void:
	_source_active = false
	_elapsed_seconds = 0.0
	_packets.clear()


func draw_packets() -> Array:
	return _packets.duplicate(true)


func set_effective_state(effective_state: RefCounted) -> void:
	_effective_state = effective_state


func update_effective_packet(_frame_context: Dictionary) -> void:
	pass


func final_visual_alpha(authored_or_animated_alpha: float) -> float:
	var multiplier: float = float(_effective_state.visual_opacity_multiplier()) if _effective_state != null else 1.0
	return clampf(authored_or_animated_alpha * multiplier, 0.0, 1.0)


func _packet_base(frame_context: Dictionary) -> Dictionary:
	var layer_spec: RefCounted = _instance.layer_spec()
	return {
		"layer_id": layer_spec.layer_id(),
		"type": layer_spec.layer_type(),
		"blend_mode": layer_spec.blend_mode(),
		"render_plane": layer_spec.render_plane(),
		"space": layer_spec.effective_space(),
		"position": VfxPreviewCoordinateResolverModel.canonical_origin_with_effective(_instance, _effective_state, frame_context),
		"geometry_scale": VfxPreviewCoordinateResolverModel.geometry_scale_with_effective(_instance, _effective_state, frame_context),
		"geometry_rotation_degrees": VfxPreviewCoordinateResolverModel.geometry_rotation_with_effective(_instance, _effective_state, frame_context),
		"transform": layer_spec.transform(),
		"asset": _asset.duplicate(true)
	}


func _parameters() -> Dictionary:
	return _instance.layer_spec().parameters()
