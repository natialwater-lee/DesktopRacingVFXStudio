class_name VfxPreviewEffectiveLayerState
extends RefCounted

var _layer_id: String
var _layer_spec: RefCounted
var _pivot_local: Vector2
var _base_values: PackedFloat64Array = PackedFloat64Array()
var _effective_values: PackedFloat64Array = PackedFloat64Array()
var _offset_x_slot := -1
var _offset_y_slot := -1
var _rotation_slot := -1
var _scale_x_slot := -1
var _scale_y_slot := -1
var _opacity_slot := -1
var _bindings: Array = []
var _clamps: Array = []


func _init(program: RefCounted, layer_spec: RefCounted) -> void:
	_configure_target_slots(program)
	reset_from(layer_spec)
	if program != null:
		_bindings = program.binding_refs_for_layer(_layer_id)
		_clamps = program.clamp_refs_for_layer(_layer_id)


func reset_from(layer_spec: RefCounted) -> void:
	_layer_spec = layer_spec
	_layer_id = layer_spec.layer_id() if layer_spec != null else ""
	var transform: Dictionary = layer_spec.transform() if layer_spec != null else {}
	var offset := _vector2(transform.get("offset", [0.0, 0.0]))
	var scale := _vector2(transform.get("scale", [1.0, 1.0]))
	_pivot_local = _vector2(transform.get("modulation_pivot_local", [0.0, 0.0]))
	if _base_values.is_empty():
		return
	_set_base(_offset_x_slot, offset.x)
	_set_base(_offset_y_slot, offset.y)
	_set_base(_rotation_slot, float(transform.get("rotation_degrees", 0.0)))
	_set_base(_scale_x_slot, scale.x)
	_set_base(_scale_y_slot, scale.y)
	_set_base(_opacity_slot, 1.0)
	_effective_values = _base_values.duplicate()


func layer_id() -> String:
	return _layer_id


func layer_spec() -> RefCounted:
	return _layer_spec


func bindings() -> Array:
	return _bindings


func clamps() -> Array:
	return _clamps


func base_value(target_slot: int) -> float:
	return _base_values[target_slot] if target_slot >= 0 and target_slot < _base_values.size() else 0.0


func effective_value(target_slot: int) -> float:
	return _effective_values[target_slot] if target_slot >= 0 and target_slot < _effective_values.size() else 0.0


func set_effective_value(target_slot: int, value: float) -> void:
	if target_slot >= 0 and target_slot < _effective_values.size():
		_effective_values[target_slot] = value


func effective_offset() -> Vector2:
	return Vector2(effective_value(_offset_x_slot), effective_value(_offset_y_slot))


func effective_scale() -> Vector2:
	return Vector2(effective_value(_scale_x_slot), effective_value(_scale_y_slot))


func effective_rotation_degrees() -> float:
	return effective_value(_rotation_slot)


func visual_opacity_multiplier() -> float:
	return effective_value(_opacity_slot)


func modulation_pivot_local() -> Vector2:
	return _pivot_local


func apply_composed_values(offset_delta: Vector2, rotation_delta: float, scale_multiplier: Vector2, opacity_multiplier: float) -> void:
	set_effective_value(_offset_x_slot, base_value(_offset_x_slot) + offset_delta.x)
	set_effective_value(_offset_y_slot, base_value(_offset_y_slot) + offset_delta.y)
	set_effective_value(_rotation_slot, base_value(_rotation_slot) + rotation_delta)
	set_effective_value(_scale_x_slot, base_value(_scale_x_slot) * scale_multiplier.x)
	set_effective_value(_scale_y_slot, base_value(_scale_y_slot) * scale_multiplier.y)
	set_effective_value(_opacity_slot, base_value(_opacity_slot) * opacity_multiplier)


func _configure_target_slots(program: RefCounted) -> void:
	if program == null:
		return
	_base_values.resize(program.target_count())
	_effective_values.resize(program.target_count())
	for slot in program.target_count():
		match program.target_name(slot):
			"TRANSFORM_OFFSET_X": _offset_x_slot = slot
			"TRANSFORM_OFFSET_Y": _offset_y_slot = slot
			"TRANSFORM_ROTATION_DEGREES": _rotation_slot = slot
			"TRANSFORM_SCALE_X": _scale_x_slot = slot
			"TRANSFORM_SCALE_Y": _scale_y_slot = slot
			"VISUAL_OPACITY_MULTIPLIER": _opacity_slot = slot


func _set_base(slot: int, value: float) -> void:
	if slot >= 0 and slot < _base_values.size():
		_base_values[slot] = value


func _vector2(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() == 2 else Vector2.ZERO
