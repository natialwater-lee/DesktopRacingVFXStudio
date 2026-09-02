class_name VfxRuntimeModulationSourceSpec
extends RefCounted

var _slot: int
var _source_id: String
var _frequency_hz: float
var _phase_radians: float


func _init(slot_value: int, source_id_value: String, frequency_hz_value: float, phase_radians_value: float) -> void:
	_slot = slot_value
	_source_id = source_id_value
	_frequency_hz = frequency_hz_value
	_phase_radians = phase_radians_value


func slot() -> int:
	return _slot


func source_id() -> String:
	return _source_id


func frequency_hz() -> float:
	return _frequency_hz


func phase_radians() -> float:
	return _phase_radians


func with_slot(slot_value: int) -> RefCounted:
	return get_script().new(slot_value, _source_id, _frequency_hz, _phase_radians)
