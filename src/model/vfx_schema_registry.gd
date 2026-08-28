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

	_validate_schema_node(_active_schema, "", issues, true)
	for input_name in _active_schema["x_vfx_runtime_inputs"]:
		_validate_schema_node(_active_schema["x_vfx_runtime_inputs"][input_name], "/x_vfx_runtime_inputs/%s" % input_name, issues)
	_validate_reference_tree(_active_schema, "", [], issues)
	_validate_rule_configuration(issues)
	_validate_layer_type_configuration(issues)
	_validate_runtime_input_configuration(issues)
	if issues.is_empty():
		_validate_rule_contract_coverage(issues)
	if issues.is_empty():
		_validate_default_compatibility(issues)
	return issues


func _validate_schema_node(node: Variant, pointer: String, issues: Array[VfxIssue], is_root: bool = false) -> void:
	if not node is Dictionary:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "schema_node_type", "Schema node must be an object.", pointer))
		return

	var allowed_keywords: Array = ["type", "properties", "required", "enum", "default", "minimum", "maximum", "minItems", "maxItems", "items", "additionalProperties", "pattern", "$defs", "$ref"]
	if is_root:
		allowed_keywords.append_array(["schema_id", "schema_version", "x_vfx_layer_types", "x_vfx_runtime_inputs", "x_vfx_rules"])
	for key in node:
		if not allowed_keywords.has(key):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "unsupported_schema_keyword", "Schema keyword is not supported by the v1 subset.", _pointer(pointer, str(key))))

	if node.has("type"):
		var allowed_types := ["object", "array", "string", "number", "integer", "boolean", "null"]
		if not node["type"] is String or not allowed_types.has(node["type"]):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "schema_type_value", "Schema type must be a supported type name.", _pointer(pointer, "type")))

	if node.has("properties"):
		if not node["properties"] is Dictionary:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "properties_type", "properties must be an object.", _pointer(pointer, "properties")))
		else:
			for property_name in node["properties"]:
				_validate_schema_node(node["properties"][property_name], _pointer(_pointer(pointer, "properties"), str(property_name)), issues)

	if node.has("required"):
		_validate_schema_string_array(node["required"], _pointer(pointer, "required"), issues)
	if node.has("enum") and not node["enum"] is Array:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "enum_type", "enum must be an array.", _pointer(pointer, "enum")))
	_validate_number_keyword(node, "minimum", pointer, issues)
	_validate_number_keyword(node, "maximum", pointer, issues)
	_validate_non_negative_integer_keyword(node, "minItems", pointer, issues)
	_validate_non_negative_integer_keyword(node, "maxItems", pointer, issues)
	if node.has("minimum") and node.has("maximum") and _is_number(node["minimum"]) and _is_number(node["maximum"]) and node["minimum"] > node["maximum"]:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "numeric_range_order", "minimum cannot exceed maximum.", pointer))
	if node.has("minItems") and node.has("maxItems") and _is_integer(node["minItems"]) and _is_integer(node["maxItems"]) and node["minItems"] > node["maxItems"]:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "item_range_order", "minItems cannot exceed maxItems.", pointer))

	if node.has("items"):
		if not node["items"] is Dictionary:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "items_type", "items must be a Schema object.", _pointer(pointer, "items")))
		else:
			_validate_schema_node(node["items"], _pointer(pointer, "items"), issues)
	if node.has("additionalProperties") and not node["additionalProperties"] is bool:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "additional_properties_type", "additionalProperties must be a boolean.", _pointer(pointer, "additionalProperties")))
	if node.has("pattern"):
		if not node["pattern"] is String:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "pattern_type", "pattern must be a string.", _pointer(pointer, "pattern")))
		else:
			var regex := RegEx.new()
			if regex.compile(node["pattern"]) != OK:
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "invalid_pattern", "Schema pattern cannot be compiled.", _pointer(pointer, "pattern")))
	if node.has("$defs"):
		if not node["$defs"] is Dictionary:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "defs_type", "$defs must be an object.", _pointer(pointer, "$defs")))
		else:
			for definition_name in node["$defs"]:
				_validate_schema_node(node["$defs"][definition_name], _pointer(_pointer(pointer, "$defs"), str(definition_name)), issues)
	if node.has("$ref") and not node["$ref"] is String:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "ref_type", "$ref must be a string.", _pointer(pointer, "$ref")))


func _validate_schema_string_array(value: Variant, pointer: String, issues: Array[VfxIssue]) -> void:
	if not value is Array:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "array_type", "Schema keyword must be an array.", pointer))
		return
	for index in value.size():
		if not value[index] is String:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "array_item_type", "Schema array entries must be strings.", "%s/%d" % [pointer, index]))


func _validate_number_keyword(node: Dictionary, keyword: String, pointer: String, issues: Array[VfxIssue]) -> void:
	if node.has(keyword) and not _is_number(node[keyword]):
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "numeric_keyword_type", "%s must be a number." % keyword, _pointer(pointer, keyword)))


func _validate_non_negative_integer_keyword(node: Dictionary, keyword: String, pointer: String, issues: Array[VfxIssue]) -> void:
	if node.has(keyword) and (not _is_integer(node[keyword]) or node[keyword] < 0):
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "item_keyword_type", "%s must be a non-negative integer." % keyword, _pointer(pointer, keyword)))


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _is_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_equal_approx(value, round(value)))


func _validate_rule_contract_coverage(issues: Array[VfxIssue]) -> void:
	for index in _active_schema["x_vfx_rules"].size():
		var rule: Dictionary = _active_schema["x_vfx_rules"][index]
		var pointer := "/x_vfx_rules/%d" % index
		match rule["name"]:
			"LIFECYCLE_PHASE_STRUCTURE":
				_validate_lifecycle_rule_coverage(rule, pointer, issues)
			"PARTICLE_EMISSION_CONFIGURATION":
				_validate_emission_rule_coverage(rule, pointer, issues)
			"PARTICLE_EMITTER_SHAPE":
				_validate_emitter_rule_coverage(rule, pointer, issues)
			"PARTICLE_MOTION_RANGE_ORDER":
				_validate_motion_rule_coverage(rule, pointer, issues)
			"EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS":
				_validate_anchor_rule_coverage(rule, pointer, issues)
			"RENDER_PLANE_FOR_EFFECTIVE_SPACE":
				_validate_render_plane_rule_coverage(rule, pointer, issues)


func _validate_lifecycle_rule_coverage(rule: Dictionary, pointer: String, issues: Array[VfxIssue]) -> void:
	var lifecycle_schema := _schema_at_preset_path(rule["lifecycle_path"], pointer, issues)
	var mode_schema := _schema_property(lifecycle_schema, rule["mode_field"], "%s/mode_field" % pointer, issues)
	var modes := _schema_enum(mode_schema, "%s/phase_names_by_mode" % pointer, issues)
	_validate_enum_mapping(rule["phase_names_by_mode"], modes, "%s/phase_names_by_mode" % pointer, issues)


func _validate_emission_rule_coverage(rule: Dictionary, pointer: String, issues: Array[VfxIssue]) -> void:
	var parameters_schema := _particle_parameters_schema(rule, pointer, issues)
	var emission_schema := _schema_property(parameters_schema, rule["emission_mode_field"], "%s/emission_mode_field" % pointer, issues)
	var modes := _schema_enum(emission_schema, "%s/mode_requirements" % pointer, issues)
	var requirements: Dictionary = rule["mode_requirements"]
	_validate_enum_mapping(requirements, modes, "%s/mode_requirements" % pointer, issues)
	for mode_name in requirements:
		var mode_requirement: Dictionary = requirements[mode_name]
		_validate_property_fields(parameters_schema, mode_requirement["required_fields"], "%s/mode_requirements/%s/required_fields" % [pointer, mode_name], issues)
		_validate_property_fields(parameters_schema, mode_requirement["forbidden_fields"], "%s/mode_requirements/%s/forbidden_fields" % [pointer, mode_name], issues)


func _validate_emitter_rule_coverage(rule: Dictionary, pointer: String, issues: Array[VfxIssue]) -> void:
	var parameters_schema := _particle_parameters_schema(rule, pointer, issues)
	var emitter_schema := _schema_property(parameters_schema, rule["emitter_field"], "%s/emitter_field" % pointer, issues)
	var shape_schema := _schema_property(emitter_schema, rule["shape_field"], "%s/shape_field" % pointer, issues)
	var shapes := _schema_enum(shape_schema, "%s/geometry_by_shape" % pointer, issues)
	var geometry_by_shape: Dictionary = rule["geometry_by_shape"]
	_validate_enum_mapping(geometry_by_shape, shapes, "%s/geometry_by_shape" % pointer, issues)
	for shape_name in geometry_by_shape:
		_validate_property_fields(emitter_schema, geometry_by_shape[shape_name], "%s/geometry_by_shape/%s" % [pointer, shape_name], issues)


func _validate_motion_rule_coverage(rule: Dictionary, pointer: String, issues: Array[VfxIssue]) -> void:
	var parameters_schema := _particle_parameters_schema(rule, pointer, issues)
	for index in rule["ranges"].size():
		var range_definition: Dictionary = rule["ranges"][index]
		_validate_property_fields(parameters_schema, [range_definition["minimum_field"], range_definition["maximum_field"]], "%s/ranges/%d" % [pointer, index], issues)


func _validate_anchor_rule_coverage(rule: Dictionary, pointer: String, issues: Array[VfxIssue]) -> void:
	var space_schema := _schema_property(_active_schema, rule["default_space_field"], "%s/default_space_field" % pointer, issues)
	var space_modes := _schema_enum(space_schema, "%s/vehicle_space_modes" % pointer, issues)
	for space_mode in rule["vehicle_space_modes"]:
		if not space_modes.has(space_mode):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_contract_configuration", "Vehicle Space Mode is not declared by the Schema.", "%s/vehicle_space_modes" % pointer))


func _validate_render_plane_rule_coverage(rule: Dictionary, pointer: String, issues: Array[VfxIssue]) -> void:
	var space_schema := _schema_property(_active_schema, rule["default_space_field"], "%s/default_space_field" % pointer, issues)
	var space_modes := _schema_enum(space_schema, "%s/allowed_planes_by_space" % pointer, issues)
	var allowed_planes_by_space: Dictionary = rule["allowed_planes_by_space"]
	_validate_enum_mapping(allowed_planes_by_space, space_modes, "%s/allowed_planes_by_space" % pointer, issues)
	var layer_result := resolve_local_ref(rule["layer_schema_ref"])
	if not layer_result.success:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", layer_result.issues[0].code, layer_result.issues[0].message, "%s/layer_schema_ref" % pointer))
		return
	var render_plane_schema := _schema_property(layer_result.value, rule["render_plane_field"], "%s/render_plane_field" % pointer, issues)
	var render_planes := _schema_enum(render_plane_schema, "%s/allowed_planes_by_space" % pointer, issues)
	for space_mode in allowed_planes_by_space:
		for render_plane in allowed_planes_by_space[space_mode]:
			if not render_planes.has(render_plane):
				issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_contract_configuration", "Render plane is not declared by the Schema.", "%s/allowed_planes_by_space/%s" % [pointer, space_mode]))


func _particle_parameters_schema(rule: Dictionary, pointer: String, issues: Array[VfxIssue]) -> Dictionary:
	var type_registry: Dictionary = _active_schema["x_vfx_layer_types"]
	if not type_registry.has(rule["particle_type"]):
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_contract_configuration", "Particle Type is not declared by x_vfx_layer_types.", "%s/particle_type" % pointer))
		return {}
	var parameters_result := resolve_local_ref(type_registry[rule["particle_type"]]["parameters_ref"])
	if not parameters_result.success:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", parameters_result.issues[0].code, parameters_result.issues[0].message, "%s/particle_type" % pointer))
		return {}
	return parameters_result.value


func _schema_at_preset_path(path: String, pointer: String, issues: Array[VfxIssue]) -> Dictionary:
	var current: Dictionary = _active_schema
	for segment in path.trim_prefix("/").split("/"):
		current = _schema_property(current, segment.replace("~1", "/").replace("~0", "~"), pointer, issues)
		if current.is_empty():
			return {}
	return current


func _schema_property(schema: Dictionary, property_name: String, pointer: String, issues: Array[VfxIssue]) -> Dictionary:
	var resolved := _resolve_schema_node(schema, pointer, issues)
	if resolved.is_empty():
		return {}
	if not resolved.has("properties") or not resolved["properties"].has(property_name):
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_contract_configuration", "Rule field does not resolve to a declared Schema property.", pointer))
		return {}
	return _resolve_schema_node(resolved["properties"][property_name], pointer, issues)


func _resolve_schema_node(schema: Dictionary, pointer: String, issues: Array[VfxIssue]) -> Dictionary:
	var current := schema
	while current.has("$ref"):
		var resolved := resolve_local_ref(current["$ref"])
		if not resolved.success:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", resolved.issues[0].code, resolved.issues[0].message, pointer))
			return {}
		current = resolved.value
	return current


func _schema_enum(schema: Dictionary, pointer: String, issues: Array[VfxIssue]) -> Array:
	var resolved := _resolve_schema_node(schema, pointer, issues)
	if not resolved.has("enum") or not resolved["enum"] is Array:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_contract_configuration", "Rule field does not resolve to an enum Schema property.", pointer))
		return []
	return resolved["enum"]


func _validate_enum_mapping(mapping: Dictionary, enum_values: Array, pointer: String, issues: Array[VfxIssue]) -> void:
	for enum_value in enum_values:
		if not mapping.has(enum_value):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_contract_configuration", "Rule configuration is missing an enum value.", pointer))
	for configured_value in mapping:
		if not enum_values.has(configured_value):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_contract_configuration", "Rule configuration contains an undeclared enum value.", pointer))


func _validate_property_fields(schema: Dictionary, fields: Array, pointer: String, issues: Array[VfxIssue]) -> void:
	var resolved := _resolve_schema_node(schema, pointer, issues)
	if resolved.is_empty():
		return
	for field_name in fields:
		if not resolved.has("properties") or not resolved["properties"].has(field_name):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "rule_contract_configuration", "Rule configuration references an undeclared Schema property.", pointer))


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
