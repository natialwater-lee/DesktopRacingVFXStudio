class_name VfxPreviewRuntimeInputState
extends RefCounted

var _values: PackedFloat64Array = PackedFloat64Array()


func _init(program: RefCounted) -> void:
	if program == null:
		return
	_values.resize(program.runtime_input_count())
	for slot in _values.size():
		_values[slot] = program.runtime_input_default(slot)


func set_slot(slot: int, value: float) -> void:
	if slot >= 0 and slot < _values.size():
		_values[slot] = value


func value_at(slot: int) -> float:
	return _values[slot] if slot >= 0 and slot < _values.size() else 0.0


func set_named_value(program: RefCounted, input_name: String, value: float) -> bool:
	if program == null:
		return false
	var slot: int = program.runtime_input_slot(input_name)
	if slot < 0:
		return false
	set_slot(slot, clampf(value, program.runtime_input_minimum(slot), program.runtime_input_maximum(slot)))
	return true
