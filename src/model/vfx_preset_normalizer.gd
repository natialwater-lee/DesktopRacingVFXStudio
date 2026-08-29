class_name VfxPresetNormalizer
extends RefCounted

var _registry: VfxSchemaRegistry


func _init(registry: VfxSchemaRegistry) -> void:
	_registry = registry


func normalize(raw_value: Variant, schema: Dictionary) -> VfxResult:
	return _normalize_value(raw_value, schema)


func _normalize_value(value: Variant, schema: Dictionary) -> VfxResult:
	if schema.has("$ref"):
		var resolved := _registry.resolve_local_ref(schema["$ref"])
		if not resolved.success:
			return _normalization_failure(resolved.issues[0])
		return _normalize_value(value, resolved.value)

	if value is Dictionary:
		var normalized: Dictionary = {}
		for key in value:
			normalized[key] = _deep_copy(value[key])
		var properties: Dictionary = schema.get("properties", {})
		for property_name in properties:
			var property_schema = properties[property_name]
			if not property_schema is Dictionary:
				continue
			if normalized.has(property_name):
				var property_result := _normalize_value(normalized[property_name], property_schema)
				if not property_result.success:
					return property_result
				normalized[property_name] = property_result.value
			else:
				var default_schema_result := _default_schema(property_schema)
				if not default_schema_result.success:
					return default_schema_result
				var default_schema: Dictionary = default_schema_result.value
				if not default_schema.has("default"):
					continue
				var default_result := _normalize_value(_deep_copy(default_schema["default"]), property_schema)
				if not default_result.success:
					return default_result
				normalized[property_name] = default_result.value

		var dynamic_result := _normalize_type_dispatched_parameters(normalized, schema)
		if not dynamic_result.success:
			return dynamic_result
		return VfxResult.ok(normalized)

	if value is Array:
		var normalized_items: Array = []
		var item_schema = schema.get("items", null)
		for item in value:
			if item_schema is Dictionary:
				var item_result := _normalize_value(item, item_schema)
				if not item_result.success:
					return item_result
				normalized_items.append(item_result.value)
			else:
				normalized_items.append(_deep_copy(item))
		return VfxResult.ok(normalized_items)

	return VfxResult.ok(_deep_copy(value))


func _normalize_type_dispatched_parameters(normalized: Dictionary, schema: Dictionary) -> VfxResult:
	var properties: Dictionary = schema.get("properties", {})
	if not properties.has("type") or not properties.has("parameters"):
		return VfxResult.ok(normalized)
	if not normalized.get("type") is String or not normalized.get("parameters") is Dictionary:
		return VfxResult.ok(normalized)

	var root_schema := _registry.schema()
	var type_registry: Dictionary = root_schema.get("x_vfx_layer_types", {})
	var layer_type: String = normalized["type"]
	if not type_registry.has(layer_type):
		return VfxResult.ok(normalized)
	var type_definition = type_registry[layer_type]
	if not type_definition is Dictionary or not type_definition.has("parameters_ref"):
		return VfxResult.failure([
			VfxIssue.new("NORMALIZATION", "layer_type_configuration", "Layer Type configuration is unavailable.")
		])
	var parameters_schema := _registry.resolve_local_ref(type_definition["parameters_ref"])
	if not parameters_schema.success:
		return _normalization_failure(parameters_schema.issues[0])
	var parameters_result := _normalize_value(normalized["parameters"], parameters_schema.value)
	if not parameters_result.success:
		return parameters_result
	normalized["parameters"] = parameters_result.value
	return VfxResult.ok(normalized)


func _default_schema(property_schema: Dictionary) -> VfxResult:
	if property_schema.has("default"):
		return VfxResult.ok(property_schema)
	if not property_schema.has("$ref"):
		return VfxResult.ok(property_schema)
	var resolved := _registry.resolve_local_ref(property_schema["$ref"])
	if not resolved.success:
		return _normalization_failure(resolved.issues[0])
	return VfxResult.ok(resolved.value)


func _normalization_failure(issue: VfxIssue) -> VfxResult:
	return VfxResult.failure([
		VfxIssue.new("NORMALIZATION", issue.code, issue.message, issue.json_pointer, issue.source_path, issue.line, issue.column)
	])


func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
