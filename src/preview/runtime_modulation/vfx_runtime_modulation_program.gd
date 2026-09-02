class_name VfxRuntimeModulationProgram
extends RefCounted

const VfxRuntimeModulationBindingSpecModel := preload("res://src/preview/runtime_modulation/vfx_runtime_modulation_binding_spec.gd")

var _sources: Array[RefCounted] = []
var _runtime_input_names: Array[String] = []
var _runtime_input_defaults: PackedFloat64Array = PackedFloat64Array()
var _runtime_input_minimums: PackedFloat64Array = PackedFloat64Array()
var _runtime_input_maximums: PackedFloat64Array = PackedFloat64Array()
var _target_names: Array[String] = []
var _target_minimums: PackedFloat64Array = PackedFloat64Array()
var _target_has_minimums: PackedByteArray = PackedByteArray()
var _bindings_by_layer: Dictionary = {}
var _clamps_by_layer: Dictionary = {}
var _binding_count: int = 0


func _init(sources_value: Array, input_names_value: Array, input_defaults_value: PackedFloat64Array, input_minimums_value: PackedFloat64Array, input_maximums_value: PackedFloat64Array, target_names_value: Array, target_minimums_value: PackedFloat64Array, target_has_minimums_value: PackedByteArray, bindings_by_layer_value: Dictionary, clamps_by_layer_value: Dictionary) -> void:
	for source in sources_value:
		if source is RefCounted:
			_sources.append(source)
	for input_name in input_names_value:
		_runtime_input_names.append(str(input_name))
	_runtime_input_defaults = input_defaults_value.duplicate()
	_runtime_input_minimums = input_minimums_value.duplicate()
	_runtime_input_maximums = input_maximums_value.duplicate()
	for target_name in target_names_value:
		_target_names.append(str(target_name))
	_target_minimums = target_minimums_value.duplicate()
	_target_has_minimums = target_has_minimums_value.duplicate()
	_bindings_by_layer = _copy_layer_map(bindings_by_layer_value)
	_clamps_by_layer = _copy_layer_map(clamps_by_layer_value)
	for bindings in _bindings_by_layer.values():
		if bindings is Array:
			_binding_count += bindings.size()


func binding_count() -> int:
	return _binding_count


func source_count() -> int:
	return _sources.size()


func source_at(slot: int) -> RefCounted:
	return _sources[slot] if slot >= 0 and slot < _sources.size() else null


func runtime_input_count() -> int:
	return _runtime_input_names.size()


func runtime_input_slot(input_name: String) -> int:
	return _runtime_input_names.find(input_name)


func runtime_input_name(slot: int) -> String:
	return _runtime_input_names[slot] if slot >= 0 and slot < _runtime_input_names.size() else ""


func runtime_input_default(slot: int) -> float:
	return _runtime_input_defaults[slot] if slot >= 0 and slot < _runtime_input_defaults.size() else 0.0


func runtime_input_minimum(slot: int) -> float:
	return _runtime_input_minimums[slot] if slot >= 0 and slot < _runtime_input_minimums.size() else -INF


func runtime_input_maximum(slot: int) -> float:
	return _runtime_input_maximums[slot] if slot >= 0 and slot < _runtime_input_maximums.size() else INF


func target_count() -> int:
	return _target_names.size()


func target_name(slot: int) -> String:
	return _target_names[slot] if slot >= 0 and slot < _target_names.size() else ""


func target_minimum(slot: int) -> float:
	return _target_minimums[slot] if slot >= 0 and slot < _target_minimums.size() else 0.0


func target_has_minimum(slot: int) -> bool:
	return slot >= 0 and slot < _target_has_minimums.size() and _target_has_minimums[slot] == 1


func bindings_for_layer(layer_id: String) -> Array:
	var bindings: Variant = _bindings_by_layer.get(layer_id, [])
	return bindings.duplicate() if bindings is Array else []


func binding_refs_for_layer(layer_id: String) -> Array:
	var bindings: Variant = _bindings_by_layer.get(layer_id, [])
	return bindings if bindings is Array else []


func clamps_for_layer(layer_id: String) -> Array:
	var clamps: Variant = _clamps_by_layer.get(layer_id, [])
	return clamps.duplicate() if clamps is Array else []


func clamp_refs_for_layer(layer_id: String) -> Array:
	var clamps: Variant = _clamps_by_layer.get(layer_id, [])
	return clamps if clamps is Array else []


func filtered_to_reachable_layer_ids(layer_ids: Dictionary) -> RefCounted:
	var retained_bindings: Dictionary = {}
	var retained_clamps: Dictionary = {}
	var used_source_ids: Dictionary = {}
	for layer_id in _bindings_by_layer:
		if not layer_ids.has(layer_id):
			continue
		var bindings: Array = _bindings_by_layer[layer_id]
		retained_bindings[layer_id] = bindings.duplicate()
		for binding in bindings:
			if binding.source_kind() == VfxRuntimeModulationBindingSpecModel.SOURCE_PRESET_SOURCE:
				used_source_ids[binding.source_id()] = true
	for layer_id in _clamps_by_layer:
		if layer_ids.has(layer_id):
			retained_clamps[layer_id] = (_clamps_by_layer[layer_id] as Array).duplicate()
	var slot_by_source_id: Dictionary = {}
	var retained_sources: Array[RefCounted] = []
	for source in _sources:
		if used_source_ids.has(source.source_id()):
			slot_by_source_id[source.source_id()] = retained_sources.size()
			retained_sources.append(source.with_slot(retained_sources.size()))
	for layer_id in retained_bindings:
		var rebound: Array = []
		for binding in retained_bindings[layer_id]:
			if binding.source_kind() == VfxRuntimeModulationBindingSpecModel.SOURCE_PRESET_SOURCE:
				rebound.append(binding.with_source_slot(int(slot_by_source_id[binding.source_id()])))
			else:
				rebound.append(binding)
		retained_bindings[layer_id] = rebound
	return get_script().new(retained_sources, _runtime_input_names, _runtime_input_defaults, _runtime_input_minimums, _runtime_input_maximums, _target_names, _target_minimums, _target_has_minimums, retained_bindings, retained_clamps)


func _copy_layer_map(source: Dictionary) -> Dictionary:
	var copied: Dictionary = {}
	for layer_id in source:
		var values: Variant = source[layer_id]
		copied[layer_id] = values.duplicate() if values is Array else []
	return copied
