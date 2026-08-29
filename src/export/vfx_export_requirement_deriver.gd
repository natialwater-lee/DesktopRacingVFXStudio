class_name VfxExportRequirementDeriver
extends RefCounted

var _registry: RefCounted


func _init(registry: RefCounted) -> void:
	_registry = registry


func derive(document: VfxPresetDocument) -> VfxResult:
	if document == null or _registry == null:
		return _failure("export_requirement_input", "Export requirement derivation requires a document and loaded Schema Registry.")
	var schema: Dictionary = _registry.schema()
	var lifecycle_rule := _rule_named(schema, "LIFECYCLE_PHASE_STRUCTURE")
	var anchor_rule := _rule_named(schema, "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")
	var input_rule := _rule_named(schema, "RUNTIME_INPUT_NAMES")
	var parameters_rule := _rule_named(schema, "TYPE_DISPATCHED_PARAMETER_SCHEMA")
	if lifecycle_rule.is_empty() or anchor_rule.is_empty() or input_rule.is_empty() or parameters_rule.is_empty():
		return _failure("export_requirement_schema", "Export requirement derivation requires lifecycle, anchor, input, and parameter Schema rules.")
	var data := document.normalized_data
	var phase_names := _phase_names(data, lifecycle_rule)
	if phase_names.is_empty():
		return _failure("export_requirement_lifecycle", "Normalized document does not have a configured lifecycle phase stack.")
	var importance_order: Array = schema.get("$defs", {}).get("importance", {}).get("enum", [])
	var anchor_order: Array = schema.get("$defs", {}).get("anchor", {}).get("enum", [])
	if importance_order.is_empty() or anchor_order.is_empty():
		return _failure("export_requirement_enums", "Export requirement derivation requires Schema Anchor and Importance enums.")
	var enabled_anchor_set: Dictionary = {}
	var logical_assets: Dictionary = {}
	var importance_counts: Dictionary = {}
	for importance in importance_order:
		importance_counts[str(importance)] = 0
	for phase_name in phase_names:
		var phase: Variant = data.get("phases", {}).get(phase_name, {})
		var layers: Variant = phase.get("layers", []) if phase is Dictionary else []
		if not layers is Array:
			return _failure("export_requirement_layers", "Configured lifecycle phase requires a Layer array.")
		for layer_value in layers:
			if not layer_value is Dictionary:
				return _failure("export_requirement_layer", "Normalized lifecycle Layer must be an object.")
			var layer: Dictionary = layer_value
			var importance := str(layer.get("importance", ""))
			if importance_counts.has(importance):
				importance_counts[importance] = int(importance_counts[importance]) + 1
			var effective_space := str(layer.get(str(anchor_rule.get("layer_space_field", "")), data.get(str(anchor_rule.get("default_space_field", "")), "")))
			if bool(layer.get("enabled", true)) and (anchor_rule.get("vehicle_space_modes", []) as Array).has(effective_space):
				for anchor in layer.get(str(anchor_rule.get("anchors_field", "")), []):
					enabled_anchor_set[str(anchor)] = true
			_collect_layer_assets(layer, schema, parameters_rule, logical_assets)
	var anchors: Array[String] = []
	for anchor in anchor_order:
		if enabled_anchor_set.has(str(anchor)):
			anchors.append(str(anchor))
	var runtime_inputs := _runtime_inputs(data, schema, input_rule)
	if not runtime_inputs.success:
		return runtime_inputs
	var asset_ids: Array[String] = []
	for logical_id in logical_assets:
		asset_ids.append(str(logical_id))
	asset_ids.sort()
	return VfxResult.ok({
		"required_vehicle_anchors": anchors,
		"runtime_input_names": runtime_inputs.value["names"],
		"runtime_inputs": runtime_inputs.value["contracts"],
		"importance_summary": importance_counts,
		"asset_logical_ids": asset_ids
	})


func _phase_names(data: Dictionary, lifecycle_rule: Dictionary) -> Array[String]:
	var lifecycle: Variant = _value_at_pointer(data, str(lifecycle_rule.get("lifecycle_path", "")))
	if not lifecycle is Dictionary:
		return []
	var mode: Variant = lifecycle.get(str(lifecycle_rule.get("mode_field", "")))
	var names: Variant = lifecycle_rule.get("phase_names_by_mode", {}).get(mode, [])
	var result: Array[String] = []
	if names is Array:
		for name in names:
			result.append(str(name))
	return result


func _runtime_inputs(data: Dictionary, schema: Dictionary, input_rule: Dictionary) -> VfxResult:
	var values: Variant = _value_at_pointer(data, str(input_rule.get("runtime_inputs_path", "")))
	var contract: Variant = _value_at_pointer(schema, str(input_rule.get("contract_path", "")))
	if not values is Array or not contract is Dictionary:
		return _failure("export_runtime_inputs", "Export runtime inputs require the Schema contract and normalized Preset declaration.")
	var names: Array[String] = []
	var contracts: Array[Dictionary] = []
	for input_value in values:
		var input_name := str(input_value)
		var definition: Variant = contract.get(input_name)
		if not definition is Dictionary:
			return _failure("export_runtime_input_unknown", "Runtime input is unavailable from Schema: %s" % input_name)
		var resolved := _resolve_schema(definition)
		if not resolved.success:
			return resolved
		var runtime_contract := {"name": input_name, "value_type": _runtime_value_type(definition, resolved.value)}
		for keyword in ["default", "minimum", "maximum", "pattern"]:
			if resolved.value.has(keyword):
				runtime_contract[keyword] = resolved.value[keyword].duplicate(true) if resolved.value[keyword] is Dictionary or resolved.value[keyword] is Array else resolved.value[keyword]
		names.append(input_name)
		contracts.append(runtime_contract)
	return VfxResult.ok({"names": names, "contracts": contracts})


func _collect_layer_assets(layer: Dictionary, schema: Dictionary, parameters_rule: Dictionary, logical_assets: Dictionary) -> void:
	var type_registry: Variant = _value_at_pointer(schema, str(parameters_rule.get("layer_types_path", "")))
	if not type_registry is Dictionary:
		return
	var logical_type := str(layer.get(str(parameters_rule.get("type_field", "")), ""))
	var type_definition: Variant = type_registry.get(logical_type)
	if not type_definition is Dictionary:
		return
	var parameter_schema_result := _resolve_schema({"$ref": type_definition.get("parameters_ref", "")})
	if not parameter_schema_result.success:
		return
	var parameters: Variant = layer.get(str(parameters_rule.get("parameters_field", "")), {})
	if not parameters is Dictionary:
		return
	for field_name in parameter_schema_result.value.get("properties", {}):
		if not str(field_name).ends_with("_asset_ref") or not parameters.has(field_name):
			continue
		var field_schema: Variant = parameter_schema_result.value["properties"][field_name]
		if field_schema is Dictionary and _is_logical_id_schema(field_schema):
			logical_assets[str(parameters[field_name])] = true


func _is_logical_id_schema(schema: Dictionary) -> bool:
	var resolved := _resolve_schema(schema)
	if not resolved.success:
		return false
	var logical_id: VfxResult = _registry.resolve_local_ref("#/$defs/logical_id")
	return logical_id.success and resolved.value == logical_id.value


func _resolve_schema(schema: Dictionary) -> VfxResult:
	if schema.has("$ref"):
		return _registry.resolve_local_ref(str(schema["$ref"]))
	return VfxResult.ok(schema.duplicate(true))


func _runtime_value_type(original_schema: Dictionary, resolved_schema: Dictionary) -> String:
	if original_schema.get("$ref") == "#/$defs/logical_id":
		return "logical_id"
	match resolved_schema.get("type", ""):
		"array":
			var items: Variant = resolved_schema.get("items", {})
			if resolved_schema.get("minItems") == 2 and resolved_schema.get("maxItems") == 2 and items is Dictionary and items.get("type") == "number":
				return "vector2"
			return "array"
		"integer":
			return "integer"
		"number":
			return "number"
		"boolean":
			return "boolean"
		_:
			return "string"


func _rule_named(schema: Dictionary, name: String) -> Dictionary:
	for rule in schema.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == name:
			return rule
	return {}


func _value_at_pointer(root: Variant, pointer: String) -> Variant:
	if pointer.is_empty() or pointer == "/":
		return root
	var current: Variant = root
	for segment in pointer.trim_prefix("/").split("/"):
		var key := segment.replace("~1", "/").replace("~0", "~")
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return null
	return current


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EXPORT_VALIDATION", code, message)])
