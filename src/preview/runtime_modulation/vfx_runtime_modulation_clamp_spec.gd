class_name VfxRuntimeModulationClampSpec
extends RefCounted

var _layer_id: String
var _target_slot: int
var _has_minimum: bool
var _minimum_effective: float
var _has_maximum: bool
var _maximum_effective: float


func _init(layer_id_value: String, target_slot_value: int, has_minimum_value: bool, minimum_effective_value: float, has_maximum_value: bool, maximum_effective_value: float) -> void:
	_layer_id = layer_id_value
	_target_slot = target_slot_value
	_has_minimum = has_minimum_value
	_minimum_effective = minimum_effective_value
	_has_maximum = has_maximum_value
	_maximum_effective = maximum_effective_value


func layer_id() -> String:
	return _layer_id


func target_slot() -> int:
	return _target_slot


func has_minimum() -> bool:
	return _has_minimum


func minimum_effective() -> float:
	return _minimum_effective


func has_maximum() -> bool:
	return _has_maximum


func maximum_effective() -> float:
	return _maximum_effective
