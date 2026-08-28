class_name VfxRuleCatalog
extends RefCounted

const _REQUIRED_KEYS := {
	"LIFECYCLE_PHASE_STRUCTURE": ["lifecycle_path", "phases_path"],
	"PRESET_HAS_LAYER": ["phases_path"],
	"UNIQUE_LAYER_IDS_ACROSS_PHASES": ["phases_path", "id_field"],
	"TYPE_DISPATCHED_PARAMETER_SCHEMA": ["phases_path", "type_field", "parameters_field", "layer_types_path"],
	"PARTICLE_EMISSION_CONFIGURATION": ["phases_path", "particle_type", "parameters_field"],
	"PARTICLE_EMITTER_SHAPE": ["phases_path", "particle_type", "parameters_field", "emitter_field"],
	"PARTICLE_MOTION_RANGE_ORDER": ["phases_path", "particle_type", "parameters_field", "ranges"],
	"RUNTIME_INPUT_NAMES": ["runtime_inputs_path", "contract_path"],
	"EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS": ["phases_path", "default_space_field", "layer_space_field", "anchors_field"],
	"RENDER_PLANE_FOR_EFFECTIVE_SPACE": ["phases_path", "default_space_field", "layer_space_field", "render_plane_field"]
}


func supports(name: String) -> bool:
	return _REQUIRED_KEYS.has(name)


func validate_configuration(rule: Dictionary, pointer: String) -> Array[VfxIssue]:
	var issues: Array[VfxIssue] = []
	if not rule.has("name") or not rule["name"] is String:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_name_missing", "Rule requires a string name.", pointer))
		return issues

	var rule_name: String = rule["name"]
	if not supports(rule_name):
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "unknown_rule", "Unsupported x_vfx_rule: %s" % rule_name, "%s/name" % pointer))
		return issues

	for key in _REQUIRED_KEYS[rule_name]:
		if not rule.has(key):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_missing", "Rule %s requires %s." % [rule_name, key], pointer))
			continue
		if key == "ranges":
			if not rule[key] is Array:
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Rule %s requires an array for %s." % [rule_name, key], "%s/%s" % [pointer, key]))
			continue
		if not rule[key] is String:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_configuration_type", "Rule %s requires a string for %s." % [rule_name, key], "%s/%s" % [pointer, key]))
	return issues
