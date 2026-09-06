class_name VfxRuntimeModulationProgramBuilder
extends RefCounted

const VfxRuntimeModulationSourceSpecModel := preload("res://src/preview/runtime_modulation/vfx_runtime_modulation_source_spec.gd")
const VfxRuntimeModulationBindingSpecModel := preload("res://src/preview/runtime_modulation/vfx_runtime_modulation_binding_spec.gd")
const VfxRuntimeModulationClampSpecModel := preload("res://src/preview/runtime_modulation/vfx_runtime_modulation_clamp_spec.gd")
const VfxRuntimeModulationProgramModel := preload("res://src/preview/runtime_modulation/vfx_runtime_modulation_program.gd")

var _registry: RefCounted


func _init(registry: RefCounted) -> void:
	_registry = registry


func build(normalized_data: Dictionary, _layer_ids_by_phase: Dictionary = {}) -> VfxResult:
	if _registry == null:
		return _failure("runtime_modulation_registry_missing", "Runtime Modulation compilation requires a Schema Registry.")
	var contract_result: VfxResult = _registry.runtime_modulation_contract()
	if not contract_result.success:
		return VfxResult.failure(contract_result.issues)
	var contract: Dictionary = contract_result.value
	var target_contracts: Dictionary = contract["target_contracts"]
	var target_names: Array[String] = []
	var target_slots: Dictionary = {}
	var target_minimums := PackedFloat64Array()
	var target_has_minimums := PackedByteArray()
	for target_name_value in target_contracts:
		var target_name := str(target_name_value)
		target_slots[target_name] = target_names.size()
		target_names.append(target_name)
		var target_contract: Dictionary = target_contracts[target_name]
		target_has_minimums.append(1 if target_contract.has("minimum_effective") else 0)
		target_minimums.append(float(target_contract.get("minimum_effective", 0.0)))

	var used_inputs: Dictionary = _used_runtime_inputs(normalized_data, contract)
	var input_schema: Dictionary = _value_at_pointer(_registry.schema(), str(contract["runtime_input_contract_path"]))
	var input_names: Array[String] = []
	var input_slots: Dictionary = {}
	var input_defaults := PackedFloat64Array()
	var input_minimums := PackedFloat64Array()
	var input_maximums := PackedFloat64Array()
	for input_name_value in normalized_data.get(str(contract["runtime_inputs_path"]).trim_prefix("/"), []):
		var input_name := str(input_name_value)
		if not used_inputs.has(input_name):
			continue
		var definition: Dictionary = input_schema.get(input_name, {})
		input_slots[input_name] = input_names.size()
		input_names.append(input_name)
		input_defaults.append(float(definition.get("default", 0.0)))
		input_minimums.append(float(definition.get("minimum", -INF)))
		input_maximums.append(float(definition.get("maximum", INF)))

	var source_slots: Dictionary = {}
	var sources: Array[RefCounted] = []
	for source_value in normalized_data.get(str(contract["sources_field"]), []):
		if not source_value is Dictionary:
			continue
		var source: Dictionary = source_value
		var source_id := str(source["id"])
		var source_kind := _source_kind_for_type(str(source[contract["source_type_field"]]))
		if source_kind < 0:
			return _failure("runtime_modulation_source_type", "Runtime Modulation source type is not compiled by the Preview program.")
		source_slots[source_id] = sources.size()
		var phase_radians := deg_to_rad(float(source[contract["phase_field"]])) if source_kind == VfxRuntimeModulationSourceSpecModel.SOURCE_OSCILLATOR_SINE else 0.0
		sources.append(VfxRuntimeModulationSourceSpecModel.new(sources.size(), source_id, source_kind, float(source[contract["frequency_field"]]), phase_radians))

	var bindings_by_layer: Dictionary = {}
	var clamps_by_layer: Dictionary = {}
	var phases: Dictionary = _value_at_pointer(normalized_data, str(contract["phases_path"]))
	for phase_name in phases:
		var phase: Variant = phases[phase_name]
		if not phase is Dictionary:
			continue
		for layer_value in phase.get(str(contract["layers_field"]), []):
			if not layer_value is Dictionary:
				continue
			var layer: Dictionary = layer_value
			var layer_id := str(layer["id"])
			var bindings: Array = []
			for binding_value in layer.get(str(contract["bindings_field"]), []):
				if binding_value is Dictionary:
					bindings.append(_compile_binding(layer_id, binding_value, contract, target_slots, input_slots, source_slots))
			bindings_by_layer[layer_id] = bindings
			var clamps: Array = []
			for clamp_value in layer.get(str(contract["clamps_field"]), []):
				if clamp_value is Dictionary:
					var clamp: Dictionary = clamp_value
					var has_minimum := clamp.has(str(contract["minimum_effective_field"]))
					var has_maximum := clamp.has(str(contract["maximum_effective_field"]))
					clamps.append(VfxRuntimeModulationClampSpecModel.new(layer_id, int(target_slots[str(clamp[contract["target_field"]])]), has_minimum, float(clamp.get(str(contract["minimum_effective_field"]), 0.0)), has_maximum, float(clamp.get(str(contract["maximum_effective_field"]), 0.0))))
			clamps_by_layer[layer_id] = clamps
	return VfxResult.ok(VfxRuntimeModulationProgramModel.new(sources, input_names, input_defaults, input_minimums, input_maximums, target_names, target_minimums, target_has_minimums, bindings_by_layer, clamps_by_layer))


func _compile_binding(layer_id: String, binding_value: Dictionary, contract: Dictionary, target_slots: Dictionary, input_slots: Dictionary, source_slots: Dictionary) -> RefCounted:
	var source: Dictionary = binding_value[contract["source_field"]]
	var source_type := str(source[contract["source_type_field"]])
	var is_runtime_input := source_type == "RUNTIME_INPUT"
	var source_id := str(source.get(contract["input_field"], "")) if is_runtime_input else str(source.get(contract["source_id_reference_field"], ""))
	var source_slot := int(input_slots[source_id]) if is_runtime_input else int(source_slots[source_id])
	var mapping: Dictionary = binding_value[contract["mapping_field"]]
	var target_name := str(binding_value[contract["target_field"]])
	var target_contract: Dictionary = contract["target_contracts"][target_name]
	var operation_slot := 0 if target_contract["operation"] == "ADD" else 1
	return VfxRuntimeModulationBindingSpecModel.new(layer_id, VfxRuntimeModulationBindingSpecModel.SOURCE_RUNTIME_INPUT if is_runtime_input else VfxRuntimeModulationBindingSpecModel.SOURCE_PRESET_SOURCE, source_slot, source_id, int(target_slots[target_name]), operation_slot, float(mapping[contract["input_min_field"]]), float(mapping[contract["input_max_field"]]), float(mapping[contract["output_min_field"]]), float(mapping[contract["output_max_field"]]))


func _source_kind_for_type(source_type: String) -> int:
	match source_type:
		"OSCILLATOR":
			return VfxRuntimeModulationSourceSpecModel.SOURCE_OSCILLATOR_SINE
		"LINEAR_PHASE":
			return VfxRuntimeModulationSourceSpecModel.SOURCE_LINEAR_PHASE
	return -1


func _used_runtime_inputs(data: Dictionary, contract: Dictionary) -> Dictionary:
	var used: Dictionary = {}
	var phases: Dictionary = _value_at_pointer(data, str(contract["phases_path"]))
	for phase in phases.values():
		if not phase is Dictionary:
			continue
		for layer in phase.get(str(contract["layers_field"]), []):
			if not layer is Dictionary:
				continue
			for binding in layer.get(str(contract["bindings_field"]), []):
				if binding is Dictionary and binding[contract["source_field"]].get(contract["source_type_field"]) == "RUNTIME_INPUT":
					used[str(binding[contract["source_field"]].get(contract["input_field"], ""))] = true
	return used


func _value_at_pointer(value: Dictionary, pointer: String) -> Dictionary:
	var current: Variant = value
	for segment in pointer.trim_prefix("/").split("/", false):
		if not current is Dictionary or not current.has(segment):
			return {}
		current = current[segment]
	return current if current is Dictionary else {}


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("PREVIEW_CONFIGURATION", code, message)])
