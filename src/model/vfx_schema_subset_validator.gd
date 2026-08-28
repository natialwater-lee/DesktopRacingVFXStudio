class_name VfxSchemaSubsetValidator
extends RefCounted

var _registry: VfxSchemaRegistry


func _init(registry: VfxSchemaRegistry) -> void:
	_registry = registry


func validate(value: Variant, schema: Dictionary, pointer: String = "", issue_kind: String = "PRESET_VALIDATION") -> Array[VfxIssue]:
	var issues: Array[VfxIssue] = []
	_validate_into(value, schema, pointer, issue_kind, issues)
	return issues


func _validate_into(value: Variant, schema: Dictionary, pointer: String, issue_kind: String, issues: Array[VfxIssue]) -> void:
	if schema.has("$ref"):
		var resolved := _registry.resolve_local_ref(schema["$ref"])
		if not resolved.success:
			for issue in resolved.issues:
				issues.append(VfxIssue.new(issue.kind, issue.code, issue.message, _child_pointer(pointer, "$ref")))
			return
		_validate_into(value, resolved.value, pointer, issue_kind, issues)
		return

	if schema.has("type") and not _matches_type(value, schema["type"]):
		issues.append(VfxIssue.new(issue_kind, "type", "Expected %s." % schema["type"], _type_pointer(pointer)))
		return

	if schema.has("enum") and not schema["enum"].has(value):
		issues.append(VfxIssue.new(issue_kind, "invalid_enum", "Value is not an allowed enum member.", pointer))

	if _is_number(value):
		if schema.has("minimum") and value < schema["minimum"]:
			issues.append(VfxIssue.new(issue_kind, "minimum", "Value is below the minimum.", pointer))
		if schema.has("maximum") and value > schema["maximum"]:
			issues.append(VfxIssue.new(issue_kind, "maximum", "Value is above the maximum.", pointer))

	if value is String and schema.has("pattern"):
		var regex := RegEx.new()
		if regex.compile(schema["pattern"]) != OK:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "invalid_pattern", "Schema pattern cannot be compiled.", pointer))
		elif regex.search(value) == null:
			issues.append(VfxIssue.new(issue_kind, "pattern", "String does not match the required pattern.", pointer))

	if value is Array:
		if schema.has("minItems") and value.size() < schema["minItems"]:
			issues.append(VfxIssue.new(issue_kind, "min_items", "Array has too few items.", pointer))
		if schema.has("maxItems") and value.size() > schema["maxItems"]:
			issues.append(VfxIssue.new(issue_kind, "max_items", "Array has too many items.", pointer))
		if schema.has("items") and schema["items"] is Dictionary:
			for index in value.size():
				_validate_into(value[index], schema["items"], _child_pointer(pointer, str(index)), issue_kind, issues)

	if value is Dictionary:
		var properties: Dictionary = schema.get("properties", {})
		for required_name in schema.get("required", []):
			if not value.has(required_name):
				issues.append(VfxIssue.new(issue_kind, "required", "Required property is missing.", _child_pointer(pointer, required_name)))
		for property_name in value:
			if properties.has(property_name):
				_validate_into(value[property_name], properties[property_name], _child_pointer(pointer, property_name), issue_kind, issues)
			elif schema.get("additionalProperties", true) == false:
				issues.append(VfxIssue.new(issue_kind, "additional_property", "Property is not allowed.", _child_pointer(pointer, property_name)))


func _matches_type(value: Variant, expected_type: String) -> bool:
	match expected_type:
		"object":
			return value is Dictionary
		"array":
			return value is Array
		"string":
			return value is String
		"number":
			return _is_number(value)
		"integer":
			return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_equal_approx(value, round(value)))
		"boolean":
			return typeof(value) == TYPE_BOOL
		"null":
			return value == null
	return false


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _child_pointer(pointer: String, segment: String) -> String:
	var escaped := segment.replace("~", "~0").replace("/", "~1")
	return "/%s" % escaped if pointer.is_empty() else "%s/%s" % [pointer, escaped]


func _type_pointer(pointer: String) -> String:
	return "/type" if pointer.is_empty() else pointer
