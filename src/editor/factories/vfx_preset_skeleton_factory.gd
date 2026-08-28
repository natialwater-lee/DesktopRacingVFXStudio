class_name VfxPresetSkeletonFactory
extends RefCounted

var _registry: VfxSchemaRegistry


func _init(registry: VfxSchemaRegistry) -> void:
	_registry = registry


func create(preset_id: String, display_name: String, category: String, lifecycle_mode: String, default_space_mode: String) -> VfxResult:
	var root_schema := _registry.schema()
	if root_schema.is_empty():
		return _failure("schema_unavailable", "A loaded VFX Schema is required to create a Preset Skeleton.")
	for field_name in ["preset_id", "display_name", "category", "default_space_mode"]:
		var field_result := _validate_root_value(root_schema, field_name, {
			"preset_id": preset_id,
			"display_name": display_name,
			"category": category,
			"default_space_mode": default_space_mode
		}[field_name])
		if not field_result.success:
			return field_result
	var phase_stack := create_phase_stack(lifecycle_mode)
	if not phase_stack.success:
		return phase_stack
	var schema_version := _schema_version(root_schema)
	if not schema_version.success:
		return schema_version
	return VfxResult.ok({
		"schema_version": schema_version.value,
		"preset_id": preset_id,
		"display_name": display_name,
		"category": category,
		"lifecycle": {"mode": lifecycle_mode},
		"default_space_mode": default_space_mode,
		"runtime_inputs": [],
		"phases": phase_stack.value
	})


func create_phase_stack(lifecycle_mode: String) -> VfxResult:
	var root_schema := _registry.schema()
	var lifecycle_rule := _rule_named(root_schema, "LIFECYCLE_PHASE_STRUCTURE")
	if lifecycle_rule.is_empty():
		return _failure("lifecycle_rule_unavailable", "Schema does not define LIFECYCLE_PHASE_STRUCTURE.")
	var phase_names_by_mode: Dictionary = lifecycle_rule.get("phase_names_by_mode", {})
	if not phase_names_by_mode.has(lifecycle_mode):
		return _failure("unknown_lifecycle_mode", "Lifecycle mode is not configured by the Schema.")
	var phases_schema_result := _resolve_schema(_schema_at_path(root_schema, lifecycle_rule["phases_path"]))
	if not phases_schema_result.success:
		return phases_schema_result
	var phases_schema: Dictionary = phases_schema_result.value
	if phases_schema.is_empty():
		return _failure("phases_schema_unavailable", "Lifecycle phases Schema is unavailable.")
	var phases: Dictionary = {}
	for phase_name_variant in phase_names_by_mode[lifecycle_mode]:
		var phase_name: String = phase_name_variant
		if not phases_schema.get("properties", {}).has(phase_name):
			return _failure("phase_schema_unavailable", "Configured lifecycle phase has no Schema definition.")
		var resolved_phase := _resolve_schema(phases_schema["properties"][phase_name])
		if not resolved_phase.success:
			return resolved_phase
		var phase: Dictionary = {"layers": []}
		for required_name_variant in resolved_phase.value.get("required", []):
			var required_name: String = required_name_variant
			if required_name == "layers":
				continue
			var required_schema: Dictionary = resolved_phase.value.get("properties", {}).get(required_name, {})
			var initial_value := _required_initial_value(required_schema)
			if not initial_value.success:
				return initial_value
			phase[required_name] = initial_value.value
		phases[phase_name] = phase
	return VfxResult.ok(phases)


func _schema_version(root_schema: Dictionary) -> VfxResult:
	var version_schema: Dictionary = root_schema.get("properties", {}).get("schema_version", {})
	var resolved_version := _resolve_schema(version_schema)
	if not resolved_version.success:
		return resolved_version
	if not resolved_version.value.get("enum", []) is Array or resolved_version.value["enum"].is_empty():
		return _failure("schema_version_unavailable", "Schema version must be selected from a Schema enum.")
	return VfxResult.ok(resolved_version.value["enum"][0])


func _validate_root_value(root_schema: Dictionary, field_name: String, value: Variant) -> VfxResult:
	if not root_schema.get("properties", {}).has(field_name):
		return _failure("root_field_unavailable", "Schema does not declare required Preset field %s." % field_name)
	var issues := VfxSchemaSubsetValidator.new(_registry).validate(value, root_schema["properties"][field_name])
	if not issues.is_empty():
		return VfxResult.failure(issues)
	return VfxResult.ok(value)


func _required_initial_value(schema: Dictionary) -> VfxResult:
	# Factory-only UX values fill required fields with no Schema default. They deliberately
	# derive from the active Schema rather than duplicating enum, default, or range tables.
	var resolved := _resolve_schema(schema)
	if not resolved.success:
		return resolved
	var node: Dictionary = resolved.value
	if node.has("default"):
		return _normalize_value(node["default"], node)
	if node.has("enum") and node["enum"] is Array and not node["enum"].is_empty():
		return VfxResult.ok(node["enum"][0])
	match node.get("type", ""):
		"number", "integer":
			return VfxResult.ok(node.get("minimum", 0))
		"boolean":
			return VfxResult.ok(false)
		"string":
			return VfxResult.ok("")
		"array":
			return VfxResult.ok([])
		"object":
			return _materialize_object(node)
	return _failure("required_initial_value_unavailable", "Required Schema field has no factory initial value.")


func _materialize_object(schema: Dictionary) -> VfxResult:
	var materialized: Dictionary = {}
	var properties: Dictionary = schema.get("properties", {})
	var required: Array = schema.get("required", [])
	for property_name_variant in properties:
		var property_name: String = property_name_variant
		var property_schema: Dictionary = properties[property_name]
		if property_schema.has("default"):
			var default_value := _normalize_value(property_schema["default"], property_schema)
			if not default_value.success:
				return default_value
			materialized[property_name] = default_value.value
		elif required.has(property_name):
			var required_value := _required_initial_value(property_schema)
			if not required_value.success:
				return required_value
			materialized[property_name] = required_value.value
	return VfxResult.ok(materialized)


func _normalize_value(value: Variant, schema: Dictionary) -> VfxResult:
	var resolved := _resolve_schema(schema)
	if not resolved.success:
		return resolved
	var node: Dictionary = resolved.value
	if value is Dictionary:
		var normalized: Dictionary = value.duplicate(true)
		for property_name_variant in node.get("properties", {}):
			var property_name: String = property_name_variant
			var property_schema: Dictionary = node["properties"][property_name]
			if normalized.has(property_name):
				var child := _normalize_value(normalized[property_name], property_schema)
				if not child.success:
					return child
				normalized[property_name] = child.value
			elif property_schema.has("default"):
				var default_child := _normalize_value(property_schema["default"], property_schema)
				if not default_child.success:
					return default_child
				normalized[property_name] = default_child.value
		return VfxResult.ok(normalized)
	if value is Array:
		var normalized_items: Array = []
		var item_schema: Variant = node.get("items", null)
		for item in value:
			if item_schema is Dictionary:
				var normalized_item := _normalize_value(item, item_schema)
				if not normalized_item.success:
					return normalized_item
				normalized_items.append(normalized_item.value)
			else:
				normalized_items.append(item.duplicate(true) if item is Dictionary or item is Array else item)
		return VfxResult.ok(normalized_items)
	return VfxResult.ok(value)


func _resolve_schema(schema: Dictionary) -> VfxResult:
	var current: Dictionary = schema
	while current.has("$ref"):
		var resolved := _registry.resolve_local_ref(current["$ref"])
		if not resolved.success:
			return resolved
		current = resolved.value
	return VfxResult.ok(current)


func _schema_at_path(root_schema: Dictionary, path: String) -> Dictionary:
	var current: Variant = root_schema
	for segment in path.trim_prefix("/").split("/"):
		var key := segment.replace("~1", "/").replace("~0", "~")
		if not current is Dictionary:
			return {}
		if current.get("properties", {}).has(key):
			current = current["properties"][key]
		elif current.has(key):
			current = current[key]
		else:
			return {}
	return current if current is Dictionary else {}


func _rule_named(root_schema: Dictionary, name: String) -> Dictionary:
	for rule in root_schema.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == name:
			return rule
	return {}


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("FACTORY", code, message)])
