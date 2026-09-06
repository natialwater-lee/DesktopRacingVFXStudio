class_name VfxRuntimeModulationSourceSpec
extends RefCounted

const SOURCE_OSCILLATOR_SINE := 0
const SOURCE_LINEAR_PHASE := 1

var _slot: int
var _source_id: String
var _source_kind: int
var _frequency_hz: float
var _phase_radians: float


func _init(slot_value: int, source_id_value: String, source_kind_value: int, frequency_hz_value: float, phase_radians_value: float) -> void:
	_slot = slot_value
	_source_id = source_id_value
	_source_kind = source_kind_value
	_frequency_hz = frequency_hz_value
	_phase_radians = phase_radians_value


func slot() -> int:
	return _slot


func source_id() -> String:
	return _source_id


func source_kind() -> int:
	return _source_kind


func frequency_hz() -> float:
	return _frequency_hz


func phase_radians() -> float:
	return _phase_radians


func with_slot(slot_value: int) -> RefCounted:
	return get_script().new(slot_value, _source_id, _source_kind, _frequency_hz, _phase_radians)
