class_name VfxLayerFactory
extends RefCounted

const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")

var _registry: VfxSchemaRegistry
var _skeleton_factory


func _init(registry: VfxSchemaRegistry) -> void:
	_registry = registry
	_skeleton_factory = VfxPresetSkeletonFactoryModel.new(registry)


func create(layer_type: String, phase_name: String, preset: Dictionary) -> VfxResult:
	var root_schema := _registry.schema()
	var type_definition: Dictionary = root_schema.get("x_vfx_layer_types", {}).get(layer_type, {})
	if type_definition.is_empty():
		return _failure("unknown_layer_type", "Layer Type is not declared by the Schema.")
	if not preset.get("phases") is Dictionary or not preset["phases"].has(phase_name):
		return _failure("unknown_phase", "Layer phase is not present in the Preset.")
	var layer_schema := _layer_schema(root_schema)
	if layer_schema.is_empty():
		return _failure("layer_schema_unavailable", "Schema Layer definition is unavailable.")
	var common := _materialize_layer_common(layer_schema, layer_type, preset)
	if not common.success:
		return common
	var parameters_schema := _registry.resolve_local_ref(type_definition.get("parameters_ref", ""))
	if not parameters_schema.success:
		return parameters_schema
	var parameters := _materialize_parameters(layer_type, parameters_schema.value, root_schema)
	if not parameters.success:
		return parameters
	var layer: Dictionary = common.value
	layer["id"] = _next_id(phase_name, layer_type, preset)
	layer["type"] = layer_type
	layer["parameters"] = parameters.value
	return VfxResult.ok(layer)


func duplicate(phase_name: String, source_layer: Dictionary, preset: Dictionary) -> VfxResult:
	if not preset.get("phases") is Dictionary or not preset["phases"].has(phase_name):
		return _failure("unknown_phase", "Layer phase is not present in the Preset.")
	if not source_layer.has("type") or not source_layer["type"] is String:
		return _failure("source_layer_type_missing", "Source Layer must declare a Layer Type.")
	var copy: Dictionary = source_layer.duplicate(true)
	copy["id"] = _next_id(phase_name, source_layer["type"], preset)
	return VfxResult.ok(copy)


func _materialize_layer_common(layer_schema: Dictionary, layer_type: String, preset: Dictionary) -> VfxResult:
	var common := _materialize_object(layer_schema, ["id", "type", "parameters"])
	if not common.success:
		return common
	var layer: Dictionary = common.value
	var render_rule := _rule_named(_registry.schema(), "RENDER_PLANE_FOR_EFFECTIVE_SPACE")
	var anchor_rule := _rule_named(_registry.schema(), "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")
	if render_rule.is_empty() or anchor_rule.is_empty():
		return _failure("space_rule_unavailable", "Schema Space Mode rules are unavailable.")
	var effective_space: String = preset.get(render_rule["default_space_field"], "")
	var allowed_planes: Array = render_rule.get("allowed_planes_by_space", {}).get(effective_space, [])
	if allowed_planes.is_empty():
		return _failure("render_plane_unavailable", "Schema has no render plane for the effective Space Mode.")
	layer[render_rule["render_plane_field"]] = allowed_planes[0]
	if anchor_rule.get("vehicle_space_modes", []).has(effective_space):
		var center_anchor := _center_anchor()
		if not center_anchor.success:
			return center_anchor
		layer[anchor_rule["anchors_field"]] = [center_anchor.value]
	return VfxResult.ok(layer)


func _materialize_parameters(layer_type: String, parameters_schema: Dictionary, root_schema: Dictionary) -> VfxResult:
	var parameters := _materialize_object(parameters_schema, [])
	if not parameters.success:
		return parameters
	var values: Dictionary = parameters.value
	var properties: Dictionary = parameters_schema.get("properties", {})
	for required_name_variant in parameters_schema.get("required", []):
		var required_name: String = required_name_variant
		if _requires_placeholder_asset(layer_type, required_name):
			values[required_name] = "fx.placeholder"
		elif values.has(required_name):
			continue
		else:
			var initial_value: VfxResult = _skeleton_factory._required_initial_value(properties.get(required_name, {}))
			if not initial_value.success:
				return initial_value
			values[required_name] = initial_value.value
	var semantic_result := _materialize_rule_required_parameters(layer_type, values, properties, root_schema)
	if not semantic_result.success:
		return semantic_result
	return _skeleton_factory._normalize_value(values, parameters_schema)


func _materialize_rule_required_parameters(layer_type: String, values: Dictionary, properties: Dictionary, root_schema: Dictionary) -> VfxResult:
	var emission_rule := _rule_named(root_schema, "PARTICLE_EMISSION_CONFIGURATION")
	if not emission_rule.is_empty() and emission_rule.get("particle_type") == layer_type:
		var mode_field: String = emission_rule["emission_mode_field"]
		var requirements: Dictionary = emission_rule.get("mode_requirements", {}).get(values.get(mode_field), {})
		for required_name_variant in requirements.get("required_fields", []):
			var required_name: String = required_name_variant
			if not values.has(required_name):
				var initial_value: VfxResult = _skeleton_factory._required_initial_value(properties.get(required_name, {}))
				if not initial_value.success:
					return initial_value
				values[required_name] = initial_value.value
		var emitter_rule := _rule_named(root_schema, "PARTICLE_EMITTER_SHAPE")
		if not emitter_rule.is_empty():
			var emitter: Dictionary = values.get(emitter_rule["emitter_field"], {})
			var shape: Variant = emitter.get(emitter_rule["shape_field"], null)
			for geometry_name_variant in emitter_rule.get("geometry_by_shape", {}).get(shape, []):
				var geometry_name: String = geometry_name_variant
				if not emitter.has(geometry_name):
					var emitter_schema_result: VfxResult = _skeleton_factory._resolve_schema(properties[emitter_rule["emitter_field"]])
					if not emitter_schema_result.success:
						return emitter_schema_result
					var geometry_value: VfxResult = _skeleton_factory._required_initial_value(emitter_schema_result.value.get("properties", {}).get(geometry_name, {}))
					if not geometry_value.success:
						return geometry_value
					emitter[geometry_name] = geometry_value.value
			values[emitter_rule["emitter_field"]] = emitter
	return VfxResult.ok(values)


func _materialize_object(schema: Dictionary, excluded_fields: Array) -> VfxResult:
	var values: Dictionary = {}
	var properties: Dictionary = schema.get("properties", {})
	var required: Array = schema.get("required", [])
	for property_name_variant in properties:
		var property_name: String = property_name_variant
		if excluded_fields.has(property_name):
			continue
		var property_schema: Dictionary = properties[property_name]
		if property_schema.has("default"):
			var default_value: VfxResult = _skeleton_factory._normalize_value(property_schema["default"], property_schema)
			if not default_value.success:
				return default_value
			values[property_name] = default_value.value
		elif required.has(property_name):
			var required_value: VfxResult = _skeleton_factory._required_initial_value(property_schema)
			if not required_value.success:
				return required_value
			values[property_name] = required_value.value
	return VfxResult.ok(values)


func _layer_schema(root_schema: Dictionary) -> Dictionary:
	var render_rule := _rule_named(root_schema, "RENDER_PLANE_FOR_EFFECTIVE_SPACE")
	if render_rule.is_empty():
		return {}
	var resolved := _registry.resolve_local_ref(render_rule.get("layer_schema_ref", ""))
	return resolved.value if resolved.success and resolved.value is Dictionary else {}


func _center_anchor() -> VfxResult:
	var anchor_schema := _registry.resolve_local_ref("#/$defs/anchor")
	if not anchor_schema.success:
		return anchor_schema
	if not anchor_schema.value.get("enum", []).has("CENTER"):
		return _failure("center_anchor_unavailable", "Schema Anchor enum does not contain CENTER.")
	return VfxResult.ok("CENTER")


func _next_id(phase_name: String, layer_type: String, preset: Dictionary) -> String:
	var base_id := "%s.%s" % [phase_name.to_lower(), layer_type.to_lower()]
	var ids: Dictionary = {}
	for scanned_phase in preset.get("phases", {}).values():
		if scanned_phase is Dictionary:
			for layer in scanned_phase.get("layers", []):
				if layer is Dictionary and layer.get("id") is String:
					ids[layer["id"]] = true
	if not ids.has(base_id):
		return base_id
	var suffix := 2
	while ids.has("%s_%d" % [base_id, suffix]):
		suffix += 1
	return "%s_%d" % [base_id, suffix]


func _requires_placeholder_asset(layer_type: String, field_name: String) -> bool:
	return ["PARTICLE", "TRAIL", "SHIELD"].has(layer_type) and field_name.ends_with("_asset_ref")


func _rule_named(root_schema: Dictionary, name: String) -> Dictionary:
	for rule in root_schema.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == name:
			return rule
	return {}


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("FACTORY", code, message)])
