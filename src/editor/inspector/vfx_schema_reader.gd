class_name VfxSchemaReader
extends RefCounted

var _registry: VfxSchemaRegistry


func _init(registry: VfxSchemaRegistry) -> void:
	_registry = registry


func root_schema() -> Dictionary:
	return _registry.schema()


func resolve(schema_or_ref: Dictionary) -> VfxResult:
	var current: Dictionary = schema_or_ref.duplicate(true)
	var visited: Dictionary = {}
	while current.has("$ref"):
		if not current["$ref"] is String:
			return _failure("invalid_ref", "Schema reference must be a string.")
		var reference: String = current["$ref"]
		if visited.has(reference):
			return _failure("ref_cycle", "Schema reference cycle detected.")
		visited[reference] = true
		var resolved: VfxResult = _registry.resolve_local_ref(reference)
		if not resolved.success:
			return resolved
		if not resolved.value is Dictionary:
			return _failure("schema_node_type", "Resolved Schema value must be an object.")
		var referenced: Dictionary = (resolved.value as Dictionary).duplicate(true)
		for key in current:
			if key != "$ref":
				referenced[key] = current[key].duplicate(true) if current[key] is Dictionary or current[key] is Array else current[key]
		current = referenced
	return VfxResult.ok(current)


func property_schema(object_schema: Dictionary, property_name: String) -> VfxResult:
	var object_result := resolve(object_schema)
	if not object_result.success:
		return object_result
	var resolved: Dictionary = object_result.value
	if not resolved.get("properties") is Dictionary or not resolved["properties"].has(property_name):
		return _failure("missing_property", "Schema property is not declared: %s" % property_name)
	var property: Variant = resolved["properties"][property_name]
	if not property is Dictionary:
		return _failure("schema_node_type", "Schema property must be an object.")
	return resolve(property)


func enum_values(schema_or_ref: Dictionary) -> Array:
	var resolved := resolve(schema_or_ref)
	if not resolved.success:
		return []
	var values: Array = []
	for value in (resolved.value as Dictionary).get("enum", []):
		values.append(value)
	return values


func default_value(schema_or_ref: Dictionary) -> Variant:
	var resolved := resolve(schema_or_ref)
	if not resolved.success or not (resolved.value as Dictionary).has("default"):
		return null
	var value: Variant = (resolved.value as Dictionary)["default"]
	return value.duplicate(true) if value is Dictionary or value is Array else value


func layer_schema() -> VfxResult:
	var root := root_schema()
	for rule in root.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == "RENDER_PLANE_FOR_EFFECTIVE_SPACE":
			var reference: Variant = rule.get("layer_schema_ref")
			if reference is String:
				return resolve({"$ref": reference})
	return _failure("layer_schema_unavailable", "Schema Layer definition is unavailable.")


func layer_parameter_schema(layer_type: String) -> VfxResult:
	var type_definition: Variant = root_schema().get("x_vfx_layer_types", {}).get(layer_type)
	if not type_definition is Dictionary or not type_definition.get("parameters_ref") is String:
		return _failure("unknown_layer_type", "Layer Type is not declared by the Schema.")
	return resolve({"$ref": type_definition["parameters_ref"]})


func layer_type_values() -> Array:
	var values: Array = []
	for layer_type in root_schema().get("x_vfx_layer_types", {}):
		values.append(layer_type)
	return values


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("SCHEMA_READER", code, message)])
