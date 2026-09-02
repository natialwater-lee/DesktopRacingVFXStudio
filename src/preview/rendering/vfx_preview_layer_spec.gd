class_name VfxPreviewLayerSpec
extends RefCounted

var _layer_id: String
var _layer_type: String
var _importance: String
var _blend_mode: String
var _render_plane: String
var _effective_space: String
var _anchors: Array[String] = []
var _transform: Dictionary
var _parameters: Dictionary
var _enabled: bool
var _sort_order: int
var _source_index: int
var _authored_offset := Vector2.ZERO
var _authored_scale := Vector2.ONE
var _authored_rotation_degrees := 0.0
var _modulation_pivot_local := Vector2.ZERO


func _init(
	layer_id_value: String,
	layer_type_value: String,
	importance_value: String,
	blend_mode_value: String,
	render_plane_value: String,
	effective_space_value: String,
	anchor_values: Array,
	transform_value: Dictionary,
	parameters_value: Dictionary,
	enabled_value: bool,
	sort_order_value: int,
	source_index_value: int
) -> void:
	_layer_id = layer_id_value
	_layer_type = layer_type_value
	_importance = importance_value
	_blend_mode = blend_mode_value
	_render_plane = render_plane_value
	_effective_space = effective_space_value
	for anchor_value in anchor_values:
		if anchor_value is String:
			_anchors.append(anchor_value)
	_transform = transform_value.duplicate(true)
	_authored_offset = _vector2(_transform.get("offset", [0.0, 0.0]))
	_authored_scale = _vector2(_transform.get("scale", [1.0, 1.0]))
	_authored_rotation_degrees = float(_transform.get("rotation_degrees", 0.0))
	_modulation_pivot_local = _vector2(_transform.get("modulation_pivot_local", [0.0, 0.0]))
	_parameters = parameters_value.duplicate(true)
	_enabled = enabled_value
	_sort_order = sort_order_value
	_source_index = source_index_value


func layer_id() -> String:
	return _layer_id


func layer_type() -> String:
	return _layer_type


func importance() -> String:
	return _importance


func blend_mode() -> String:
	return _blend_mode


func render_plane() -> String:
	return _render_plane


func effective_space() -> String:
	return _effective_space


func anchor_names() -> Array[String]:
	return _anchors.duplicate()


func transform() -> Dictionary:
	return _transform.duplicate(true)


func authored_offset() -> Vector2:
	return _authored_offset


func authored_scale() -> Vector2:
	return _authored_scale


func authored_rotation_degrees() -> float:
	return _authored_rotation_degrees


func modulation_pivot_local() -> Vector2:
	return _modulation_pivot_local


func parameters() -> Dictionary:
	return _parameters.duplicate(true)


func is_enabled() -> bool:
	return _enabled


func sort_order() -> int:
	return _sort_order


func source_index() -> int:
	return _source_index


func _vector2(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() == 2 else Vector2.ZERO
