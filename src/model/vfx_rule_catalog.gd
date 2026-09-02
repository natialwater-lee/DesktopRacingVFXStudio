class_name VfxRuleCatalog
extends RefCounted

const _STRING_KEYS_BY_RULE := {
	"LIFECYCLE_PHASE_STRUCTURE": ["lifecycle_path", "phases_path", "mode_field", "issue_code", "message"],
	"PRESET_HAS_LAYER": ["phases_path"],
	"UNIQUE_LAYER_IDS_ACROSS_PHASES": ["phases_path", "id_field"],
	"TYPE_DISPATCHED_PARAMETER_SCHEMA": ["phases_path", "type_field", "parameters_field", "layer_types_path"],
	"PARTICLE_EMISSION_CONFIGURATION": ["phases_path", "particle_type", "type_field", "parameters_field", "emission_mode_field"],
	"PARTICLE_EMITTER_SHAPE": ["phases_path", "particle_type", "type_field", "parameters_field", "emitter_field", "shape_field", "issue_code", "message"],
	"PARTICLE_MOTION_RANGE_ORDER": ["phases_path", "particle_type", "type_field", "parameters_field", "issue_code", "message"],
	"PARTICLE_SIZE_MULTIPLIER_RANGE_ORDER": ["phases_path", "particle_type", "type_field", "parameters_field", "issue_code", "message"],
	"RUNTIME_INPUT_NAMES": ["runtime_inputs_path", "contract_path", "issue_code", "message"],
	"EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS": ["phases_path", "default_space_field", "layer_space_field", "anchors_field", "missing_anchor_issue_code", "missing_anchor_message", "unexpected_anchor_issue_code", "unexpected_anchor_message"],
	"RENDER_PLANE_FOR_EFFECTIVE_SPACE": ["phases_path", "default_space_field", "layer_space_field", "render_plane_field", "layer_schema_ref", "issue_code", "message"],
	"RUNTIME_MODULATION_CONFIGURATION": ["phases_path", "runtime_inputs_path", "runtime_input_contract_path", "sources_field", "layers_field", "bindings_field", "clamps_field", "transform_field", "pivot_field", "layer_type_field", "source_id_field", "binding_id_field", "target_field", "operation_field", "source_field", "source_type_field", "input_field", "source_id_reference_field", "wave_field", "frequency_field", "phase_field", "mapping_field", "mapping_type_field", "input_min_field", "input_max_field", "output_min_field", "output_max_field", "minimum_effective_field", "maximum_effective_field"]
}

const _COMPLEX_KEYS_BY_RULE := {
	"LIFECYCLE_PHASE_STRUCTURE": ["phase_names_by_mode"],
	"PRESET_HAS_LAYER": [],
	"UNIQUE_LAYER_IDS_ACROSS_PHASES": [],
	"TYPE_DISPATCHED_PARAMETER_SCHEMA": [],
	"PARTICLE_EMISSION_CONFIGURATION": ["mode_requirements"],
	"PARTICLE_EMITTER_SHAPE": ["geometry_by_shape"],
	"PARTICLE_MOTION_RANGE_ORDER": ["ranges"],
	"PARTICLE_SIZE_MULTIPLIER_RANGE_ORDER": ["ranges"],
	"RUNTIME_INPUT_NAMES": [],
	"EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS": ["vehicle_space_modes"],
	"RENDER_PLANE_FOR_EFFECTIVE_SPACE": ["allowed_planes_by_space"],
	"RUNTIME_MODULATION_CONFIGURATION": ["source_types", "binding_source_types", "mapping_types", "target_contracts", "pivot_compatible_layer_types"]
}


func supports(name: String) -> bool:
	return _STRING_KEYS_BY_RULE.has(name)


func validate_configuration(rule: Dictionary, pointer: String) -> Array[VfxIssue]:
	var issues: Array[VfxIssue] = []
	if not rule.has("name") or not rule["name"] is String:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_name_missing", "Rule requires a string name.", pointer))
		return issues

	var rule_name: String = rule["name"]
	if not supports(rule_name):
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "unknown_rule", "Unsupported x_vfx_rule: %s" % rule_name, "%s/name" % pointer))
		return issues

	var allowed_keys: Array = ["name"]
	allowed_keys.append_array(_STRING_KEYS_BY_RULE[rule_name])
	allowed_keys.append_array(_COMPLEX_KEYS_BY_RULE[rule_name])
	for key in rule:
		if not allowed_keys.has(key):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_additional_property", "Rule property is not supported.", "%s/%s" % [pointer, key]))

	for key in _STRING_KEYS_BY_RULE[rule_name]:
		_validate_required_string(rule, key, pointer, issues)
	for key in _COMPLEX_KEYS_BY_RULE[rule_name]:
		if not rule.has(key):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_missing", "Rule %s requires %s." % [rule_name, key], pointer))

	if not issues.is_empty():
		return issues

	match rule_name:
		"LIFECYCLE_PHASE_STRUCTURE":
			_validate_string_array_map(rule["phase_names_by_mode"], "%s/phase_names_by_mode" % pointer, issues)
		"PARTICLE_EMISSION_CONFIGURATION":
			_validate_emission_requirements(rule["mode_requirements"], "%s/mode_requirements" % pointer, issues)
		"PARTICLE_EMITTER_SHAPE":
			_validate_string_array_map(rule["geometry_by_shape"], "%s/geometry_by_shape" % pointer, issues)
		"PARTICLE_MOTION_RANGE_ORDER", "PARTICLE_SIZE_MULTIPLIER_RANGE_ORDER":
			_validate_ranges(rule["ranges"], "%s/ranges" % pointer, issues)
		"EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS":
			_validate_string_array(rule["vehicle_space_modes"], "%s/vehicle_space_modes" % pointer, issues, false)
		"RENDER_PLANE_FOR_EFFECTIVE_SPACE":
			_validate_string_array_map(rule["allowed_planes_by_space"], "%s/allowed_planes_by_space" % pointer, issues)
		"RUNTIME_MODULATION_CONFIGURATION":
			_validate_runtime_modulation_configuration(rule, pointer, issues)
	return issues


func _validate_runtime_modulation_configuration(rule: Dictionary, pointer: String, issues: Array[VfxIssue]) -> void:
	_validate_string_array(rule["binding_source_types"], "%s/binding_source_types" % pointer, issues, false)
	_validate_string_array(rule["mapping_types"], "%s/mapping_types" % pointer, issues, false)
	_validate_string_array(rule["pivot_compatible_layer_types"], "%s/pivot_compatible_layer_types" % pointer, issues, false)

	var source_types = rule["source_types"]
	if not source_types is Dictionary or source_types.is_empty():
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_modulation_contract_configuration", "Runtime Modulation source_types must be a non-empty object.", "%s/source_types" % pointer))
	else:
		for source_type in source_types:
			var source_pointer := "%s/source_types/%s" % [pointer, source_type]
			var source_definition = source_types[source_type]
			if not source_type is String or (source_type as String).is_empty() or not source_definition is Dictionary:
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_modulation_contract_configuration", "Runtime Modulation source type requires an object definition.", source_pointer))
				continue
			if not source_definition.has("waves") or not source_definition.has("output_min") or not source_definition.has("output_max"):
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_modulation_contract_configuration", "Runtime Modulation source type requires waves and output bounds.", source_pointer))
				continue
			_validate_string_array(source_definition["waves"], "%s/waves" % source_pointer, issues, false)
			if not _is_finite_number(source_definition["output_min"]) or not _is_finite_number(source_definition["output_max"]) or source_definition["output_min"] > source_definition["output_max"]:
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_modulation_contract_configuration", "Runtime Modulation source output bounds must be finite and ordered.", source_pointer))

	var target_contracts = rule["target_contracts"]
	if not target_contracts is Dictionary or target_contracts.is_empty():
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_modulation_contract_configuration", "Runtime Modulation target_contracts must be a non-empty object.", "%s/target_contracts" % pointer))
		return
	for target in target_contracts:
		var target_pointer := "%s/target_contracts/%s" % [pointer, target]
		var target_definition = target_contracts[target]
		if not target is String or (target as String).is_empty() or not target_definition is Dictionary:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_modulation_contract_configuration", "Runtime Modulation target requires an object definition.", target_pointer))
			continue
		for key in target_definition:
			if not ["operation", "compatible_layer_types", "minimum_effective", "maximum_effective"].has(key):
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_modulation_contract_configuration", "Runtime Modulation target configuration contains an unsupported property.", "%s/%s" % [target_pointer, key]))
		if not target_definition.get("operation") is String or str(target_definition.get("operation", "")).is_empty():
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_modulation_contract_configuration", "Runtime Modulation target requires a non-empty operation.", "%s/operation" % target_pointer))
		if not target_definition.has("compatible_layer_types"):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_modulation_contract_configuration", "Runtime Modulation target requires compatible_layer_types.", target_pointer))
		else:
			_validate_string_array(target_definition["compatible_layer_types"], "%s/compatible_layer_types" % target_pointer, issues, false)
		for bound_key in ["minimum_effective", "maximum_effective"]:
			if target_definition.has(bound_key) and not _is_finite_number(target_definition[bound_key]):
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_modulation_contract_configuration", "Runtime Modulation target bounds must be finite numbers.", "%s/%s" % [target_pointer, bound_key]))
		if target_definition.has("minimum_effective") and target_definition.has("maximum_effective") and target_definition["minimum_effective"] > target_definition["maximum_effective"]:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_modulation_contract_configuration", "Runtime Modulation target minimum cannot exceed maximum.", target_pointer))


func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


func _validate_required_string(rule: Dictionary, key: String, pointer: String, issues: Array[VfxIssue]) -> void:
	if not rule.has(key):
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_missing", "Rule %s requires %s." % [rule["name"], key], pointer))
	elif not rule[key] is String or (rule[key] as String).is_empty():
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Rule %s requires a non-empty string for %s." % [rule["name"], key], "%s/%s" % [pointer, key]))


func _validate_string_array_map(value: Variant, pointer: String, issues: Array[VfxIssue]) -> void:
	if not value is Dictionary or value.is_empty():
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Rule configuration requires a non-empty object.", pointer))
		return
	for key in value:
		if not key is String or key.is_empty():
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Rule configuration keys must be non-empty strings.", pointer))
			continue
		_validate_string_array(value[key], "%s/%s" % [pointer, key], issues, true)


func _validate_string_array(value: Variant, pointer: String, issues: Array[VfxIssue], allow_empty: bool) -> void:
	if not value is Array or ((value as Array).is_empty() and not allow_empty):
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Rule configuration requires an array of strings.", pointer))
		return
	for index in value.size():
		if not value[index] is String or (value[index] as String).is_empty():
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Rule configuration array entries must be non-empty strings.", "%s/%d" % [pointer, index]))


func _validate_emission_requirements(value: Variant, pointer: String, issues: Array[VfxIssue]) -> void:
	if not value is Dictionary or value.is_empty():
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Emission requirements require a non-empty object.", pointer))
		return
	for mode_name in value:
		var mode_pointer := "%s/%s" % [pointer, mode_name]
		var requirement = value[mode_name]
		if not mode_name is String or mode_name.is_empty() or not requirement is Dictionary:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Each emission mode requires an object configuration.", mode_pointer))
			continue
		for key in ["required_fields", "forbidden_fields"]:
			if not requirement.has(key):
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_missing", "Emission mode requires %s." % key, mode_pointer))
			else:
				_validate_string_array(requirement[key], "%s/%s" % [mode_pointer, key], issues, true)
		for key in ["issue_code", "message"]:
			if not requirement.has(key) or not requirement[key] is String or (requirement.get(key, "") as String).is_empty():
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Emission mode requires a non-empty string %s." % key, "%s/%s" % [mode_pointer, key]))


func _validate_ranges(value: Variant, pointer: String, issues: Array[VfxIssue]) -> void:
	if not value is Array:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Particle ranges require an array.", pointer))
		return
	for index in value.size():
		var range_pointer := "%s/%d" % [pointer, index]
		var range_definition = value[index]
		if not range_definition is Dictionary:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Each Particle range requires an object.", range_pointer))
			continue
		for key in ["minimum_field", "maximum_field"]:
			if not range_definition.has(key) or not range_definition[key] is String or (range_definition.get(key, "") as String).is_empty():
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Particle range requires a non-empty string %s." % key, "%s/%s" % [range_pointer, key]))
