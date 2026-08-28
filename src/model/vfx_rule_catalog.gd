class_name VfxRuleCatalog
extends RefCounted

const _STRING_KEYS_BY_RULE := {
	"LIFECYCLE_PHASE_STRUCTURE": ["lifecycle_path", "phases_path", "mode_field", "issue_code", "message"],
	"PRESET_HAS_LAYER": ["phases_path"],
	"UNIQUE_LAYER_IDS_ACROSS_PHASES": ["phases_path", "id_field"],
	"TYPE_DISPATCHED_PARAMETER_SCHEMA": ["phases_path", "type_field", "parameters_field", "layer_types_path"],
	"PARTICLE_EMISSION_CONFIGURATION": ["phases_path", "particle_type", "parameters_field", "emission_mode_field"],
	"PARTICLE_EMITTER_SHAPE": ["phases_path", "particle_type", "parameters_field", "emitter_field", "shape_field", "issue_code", "message"],
	"PARTICLE_MOTION_RANGE_ORDER": ["phases_path", "particle_type", "parameters_field", "issue_code", "message"],
	"RUNTIME_INPUT_NAMES": ["runtime_inputs_path", "contract_path", "issue_code", "message"],
	"EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS": ["phases_path", "default_space_field", "layer_space_field", "anchors_field", "missing_anchor_issue_code", "missing_anchor_message", "unexpected_anchor_issue_code", "unexpected_anchor_message"],
	"RENDER_PLANE_FOR_EFFECTIVE_SPACE": ["phases_path", "default_space_field", "layer_space_field", "render_plane_field", "layer_schema_ref", "issue_code", "message"]
}

const _COMPLEX_KEYS_BY_RULE := {
	"LIFECYCLE_PHASE_STRUCTURE": ["phase_names_by_mode"],
	"PRESET_HAS_LAYER": [],
	"UNIQUE_LAYER_IDS_ACROSS_PHASES": [],
	"TYPE_DISPATCHED_PARAMETER_SCHEMA": [],
	"PARTICLE_EMISSION_CONFIGURATION": ["mode_requirements"],
	"PARTICLE_EMITTER_SHAPE": ["geometry_by_shape"],
	"PARTICLE_MOTION_RANGE_ORDER": ["ranges"],
	"RUNTIME_INPUT_NAMES": [],
	"EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS": ["vehicle_space_modes"],
	"RENDER_PLANE_FOR_EFFECTIVE_SPACE": ["allowed_planes_by_space"]
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
		"PARTICLE_MOTION_RANGE_ORDER":
			_validate_ranges(rule["ranges"], "%s/ranges" % pointer, issues)
		"EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS":
			_validate_string_array(rule["vehicle_space_modes"], "%s/vehicle_space_modes" % pointer, issues, false)
		"RENDER_PLANE_FOR_EFFECTIVE_SPACE":
			_validate_string_array_map(rule["allowed_planes_by_space"], "%s/allowed_planes_by_space" % pointer, issues)
	return issues


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
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Motion ranges require an array.", pointer))
		return
	for index in value.size():
		var range_pointer := "%s/%d" % [pointer, index]
		var range_definition = value[index]
		if not range_definition is Dictionary:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Each motion range requires an object.", range_pointer))
			continue
		for key in ["minimum_field", "maximum_field"]:
			if not range_definition.has(key) or not range_definition[key] is String or (range_definition.get(key, "") as String).is_empty():
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Motion range requires a non-empty string %s." % key, "%s/%s" % [range_pointer, key]))
