class_name VfxRuntimeModulationBindingSpec
extends RefCounted

const SOURCE_RUNTIME_INPUT := 0
const SOURCE_PRESET_SOURCE := 1

var _layer_id: String
var _source_kind: int
var _source_slot: int
var _source_id: String
var _target_slot: int
var _operation_slot: int
var _input_min: float
var _input_max: float
var _output_min: float
var _output_max: float


func _init(layer_id_value: String, source_kind_value: int, source_slot_value: int, source_id_value: String, target_slot_value: int, operation_slot_value: int, input_min_value: float, input_max_value: float, output_min_value: float, output_max_value: float) -> void:
	_layer_id = layer_id_value
	_source_kind = source_kind_value
	_source_slot = source_slot_value
	_source_id = source_id_value
	_target_slot = target_slot_value
	_operation_slot = operation_slot_value
	_input_min = input_min_value
	_input_max = input_max_value
	_output_min = output_min_value
	_output_max = output_max_value


func layer_id() -> String:
	return _layer_id


func source_kind() -> int:
	return _source_kind


func source_slot() -> int:
	return _source_slot


func source_id() -> String:
	return _source_id


func target_slot() -> int:
	return _target_slot


func operation_slot() -> int:
	return _operation_slot


func input_min() -> float:
	return _input_min


func input_max() -> float:
	return _input_max


func output_min() -> float:
	return _output_min


func output_max() -> float:
	return _output_max


func with_source_slot(source_slot_value: int) -> RefCounted:
	return get_script().new(_layer_id, _source_kind, source_slot_value, _source_id, _target_slot, _operation_slot, _input_min, _input_max, _output_min, _output_max)
