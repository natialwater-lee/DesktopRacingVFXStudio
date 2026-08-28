class_name VfxPreviewLayerRenderer
extends RefCounted

const VfxPreviewCoordinateResolverModel := preload("res://src/preview/rendering/vfx_preview_coordinate_resolver.gd")

var _instance: RefCounted
var _asset: Dictionary
var _source_active := false
var _elapsed_seconds := 0.0
var _packets: Array[Dictionary] = []


func _init(instance: RefCounted, asset: Dictionary) -> void:
	_instance = instance
	_asset = asset.duplicate(true)


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


func _packet_base(frame_context: Dictionary) -> Dictionary:
	var layer_spec: RefCounted = _instance.layer_spec()
	return {
		"layer_id": layer_spec.layer_id(),
		"type": layer_spec.layer_type(),
		"blend_mode": layer_spec.blend_mode(),
		"render_plane": layer_spec.render_plane(),
		"space": layer_spec.effective_space(),
		"position": VfxPreviewCoordinateResolverModel.canonical_origin(_instance, frame_context),
		"geometry_scale": VfxPreviewCoordinateResolverModel.geometry_scale(_instance, frame_context),
		"geometry_rotation_degrees": VfxPreviewCoordinateResolverModel.geometry_rotation_degrees(_instance, frame_context),
		"transform": layer_spec.transform(),
		"asset": _asset.duplicate(true)
	}


func _parameters() -> Dictionary:
	return _instance.layer_spec().parameters()
