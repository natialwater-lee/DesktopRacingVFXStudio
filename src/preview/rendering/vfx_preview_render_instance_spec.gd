class_name VfxPreviewRenderInstanceSpec
extends RefCounted

var _phase_name: String
var _layer_spec: RefCounted
var _anchor_name: String
var _anchor_source_position: Vector2
var _anchor_index: int


func _init(phase_name_value: String, layer_spec_value: RefCounted, anchor_name_value: String = "", anchor_source_position_value: Vector2 = Vector2.ZERO, anchor_index_value: int = 0) -> void:
	_phase_name = phase_name_value
	_layer_spec = layer_spec_value
	_anchor_name = anchor_name_value
	_anchor_source_position = anchor_source_position_value
	_anchor_index = anchor_index_value


func phase_name() -> String:
	return _phase_name


func layer_spec() -> RefCounted:
	return _layer_spec


func anchor_name() -> String:
	return _anchor_name


func anchor_source_position() -> Vector2:
	return _anchor_source_position


func anchor_index() -> int:
	return _anchor_index
