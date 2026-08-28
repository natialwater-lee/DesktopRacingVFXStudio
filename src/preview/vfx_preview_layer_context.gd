class_name VfxPreviewLayerContext
extends RefCounted

var layer_id: String
var _anchors: Array[String] = []
var _effective_space: String
var _transform_offset: Vector2
var _render_plane: String


func _init(layer_id_value: String, anchor_values: Array, effective_space_value: String, transform_offset_value: Vector2, render_plane_value: String) -> void:
	layer_id = layer_id_value
	for anchor_value in anchor_values:
		if anchor_value is String and not _anchors.has(anchor_value):
			_anchors.append(anchor_value)
	_effective_space = effective_space_value
	_transform_offset = transform_offset_value
	_render_plane = render_plane_value


func anchor_names() -> Array[String]:
	return _anchors.duplicate()


func effective_space() -> String:
	return _effective_space


func transform_offset() -> Vector2:
	return _transform_offset


func render_plane() -> String:
	return _render_plane
