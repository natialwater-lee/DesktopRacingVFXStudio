class_name VfxSchemaRegistry
extends RefCounted

const VfxSchemaSubsetValidatorModel := preload("res://src/model/vfx_schema_subset_validator.gd")

var _codec: VfxPresetCodec
var _rule_catalog: VfxRuleCatalog
var _schema_data: Dictionary = {}
var _active_schema: Dictionary = {}
var _has_active_schema := false


func _init(codec: VfxPresetCodec, rule_catalog: VfxRuleCatalog) -> void:
	_codec = codec
	_rule_catalog = rule_catalog


func load(path: String) -> VfxResult:
	var decoded := _codec.decode_file(path)
	if not decoded.success:
		return decoded
	return load_data(decoded.value, path)


func load_data(value: Variant, source_path: String = "") -> VfxResult:
	if not value is Dictionary:
		return VfxResult.failure([
			VfxIssue.new("SCHEMA_CONFIGURATION", "schema_root_type", "Schema root must be an object.", "/type", source_path)
		])

	_active_schema = value.duplicate(true)
	_has_active_schema = true
	var issues := _validate_configuration(source_path)
	_has_active_schema = false
	if not issues.is_empty():
		_active_schema = {}
		return VfxResult.failure(issues)

	_schema_data = _active_schema
	_active_schema = {}
	return VfxResult.ok(schema())


func schema() -> Dictionary:
	return _schema_data.duplicate(true)


func resolve_local_ref(reference: String) -> VfxResult:
	if not reference.begins_with("#/$defs/"):
		return VfxResult.failure([
			VfxIssue.new("SCHEMA_CONFIGURATION", "unsupported_ref", "Only local #/$defs/... references are supported.")
		])
	var definition_name := reference.trim_prefix("#/$defs/")
	if definition_name.is_empty() or definition_name.contains("/"):
		return VfxResult.failure([
			VfxIssue.new("SCHEMA_CONFIGURATION", "invalid_ref", "Reference must name one local definition.")
		])
	var current_schema := _active_schema if _has_active_schema else _schema_data
	if not current_schema.has("$defs") or not current_schema["$defs"] is Dictionary or not current_schema["$defs"].has(definition_name):
		return VfxResult.failure([
			VfxIssue.new("SCHEMA_CONFIGURATION", "missing_ref", "Local reference cannot be resolved: %s" % reference)
		])
	return VfxResult.ok(current_schema["$defs"][definition_name])


func _validate_configuration(source_path: String) -> Array[VfxIssue]:
	var issues: Array[VfxIssue] = []
	var required_root_keys := ["type", "properties", "$defs", "x_vfx_layer_types", "x_vfx_runtime_inputs", "x_vfx_rules"]
	for key in required_root_keys:
		if not _active_schema.has(key):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "schema_root_missing", "Schema requires %s." % key, "/%s" % key, source_path))
	if not issues.is_empty():
		return issues

	if not _active_schema["$defs"] is Dictionary:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "defs_type", "$defs must be an object.", "/$defs", source_path))
	if not _active_schema["x_vfx_layer_types"] is Dictionary:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "layer_types_type", "x_vfx_layer_types must be an object.", "/x_vfx_layer_types", source_path))
	if not _active_schema["x_vfx_runtime_inputs"] is Dictionary:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_inputs_type", "x_vfx_runtime_inputs must be an object.", "/x_vfx_runtime_inputs", source_path))
	if not _active_schema["x_vfx_rules"] is Array:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rules_type", "x_vfx_rules must be an array.", "/x_vfx_rules", source_path))
	if not issues.is_empty():
		return issues

	_validate_reference_tree(_active_schema, "", [], issues)
	_validate_patterns(_active_schema, "", issues)
	_validate_rule_configuration(issues)
	_validate_layer_type_configuration(issues)
	_validate_runtime_input_configuration(issues)
	if issues.is_empty():
		_validate_default_compatibility(issues)
	return issues


func _validate_reference_tree(value: Variant, pointer: String, active_references: Array[String], issues: Array[VfxIssue]) -> void:
	if value is Dictionary:
		if value.has("$ref"):
			if not value["$ref"] is String:
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "ref_type", "$ref must be a string.", _pointer(pointer, "$ref")))
			else:
				var reference: String = value["$ref"]
				var resolved := resolve_local_ref(reference)
				if not resolved.success:
					issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", resolved.issues[0].code, resolved.issues[0].message, _pointer(pointer, "$ref")))
				elif active_references.has(reference):
					issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "ref_cycle", "Local reference cycle detected: %s" % reference, _pointer(pointer, "$ref")))
				else:
					active_references.append(reference)
					_validate_reference_tree(resolved.value, _pointer(pointer, "$ref"), active_references, issues)
					active_references.pop_back()
		for key in value:
			if key != "$ref" and key != "default":
				_validate_reference_tree(value[key], _pointer(pointer, str(key)), active_references, issues)
	elif value is Array:
		for index in value.size():
			_validate_reference_tree(value[index], _pointer(pointer, str(index)), active_references, issues)


func _validate_patterns(value: Variant, pointer: String, issues: Array[VfxIssue]) -> void:
	if value is Dictionary:
		if value.has("pattern"):
			if not value["pattern"] is String:
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "pattern_type", "pattern must be a string.", _pointer(pointer, "pattern")))
			else:
				var regex := RegEx.new()
				if regex.compile(value["pattern"]) != OK:
					issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "invalid_pattern", "Schema pattern cannot be compiled.", _pointer(pointer, "pattern")))
		for key in value:
			if key != "default":
				_validate_patterns(value[key], _pointer(pointer, str(key)), issues)
	elif value is Array:
		for index in value.size():
			_validate_patterns(value[index], _pointer(pointer, str(index)), issues)


func _validate_rule_configuration(issues: Array[VfxIssue]) -> void:
	for index in _active_schema["x_vfx_rules"].size():
		var rule = _active_schema["x_vfx_rules"][index]
		var pointer := "/x_vfx_rules/%d" % index
		if not rule is Dictionary:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_type", "Each x_vfx_rule must be an object.", pointer))
			continue
		issues.append_array(_rule_catalog.validate_configuration(rule, pointer))


func _validate_layer_type_configuration(issues: Array[VfxIssue]) -> void:
	for layer_type in _active_schema["x_vfx_layer_types"]:
		var pointer := "/x_vfx_layer_types/%s" % layer_type
		var definition = _active_schema["x_vfx_layer_types"][layer_type]
		if not definition is Dictionary or not definition.has("parameters_ref") or not definition["parameters_ref"] is String:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "layer_type_configuration", "Layer Type requires a string parameters_ref.", pointer))
			continue
		var resolved := resolve_local_ref(definition["parameters_ref"])
		if not resolved.success:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", resolved.issues[0].code, resolved.issues[0].message, _pointer(pointer, "parameters_ref")))


func _validate_runtime_input_configuration(issues: Array[VfxIssue]) -> void:
	for input_name in _active_schema["x_vfx_runtime_inputs"]:
		var pointer := "/x_vfx_runtime_inputs/%s" % input_name
		var definition = _active_schema["x_vfx_runtime_inputs"][input_name]
		if not definition is Dictionary or (not definition.has("type") and not definition.has("$ref")):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_input_configuration", "Runtime input requires type or local $ref.", pointer))


func _validate_default_compatibility(issues: Array[VfxIssue]) -> void:
	var validator := VfxSchemaSubsetValidatorModel.new(self)
	_validate_defaults_in_value(_active_schema, "", validator, issues)


func _validate_defaults_in_value(value: Variant, pointer: String, validator: VfxSchemaSubsetValidator, issues: Array[VfxIssue]) -> void:
	if value is Dictionary:
		if value.has("default"):
			issues.append_array(validator.validate(value["default"], value, _pointer(pointer, "default"), "SCHEMA_CONFIGURATION"))
		for key in value:
			if key != "default":
				_validate_defaults_in_value(value[key], _pointer(pointer, str(key)), validator, issues)
	elif value is Array:
		for index in value.size():
			_validate_defaults_in_value(value[index], _pointer(pointer, str(index)), validator, issues)


func _pointer(pointer: String, segment: String) -> String:
	var escaped := segment.replace("~", "~0").replace("/", "~1")
	return "/%s" % escaped if pointer.is_empty() else "%s/%s" % [pointer, escaped]
