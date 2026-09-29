class_name VfxContractValidator
extends RefCounted

var _registry: VfxSchemaRegistry
var _subset_validator: VfxSchemaSubsetValidator


func _init(registry: VfxSchemaRegistry, subset_validator: VfxSchemaSubsetValidator) -> void:
	_registry = registry
	_subset_validator = subset_validator


func validate(value: Variant) -> VfxResult:
	if not value is Dictionary:
		return VfxResult.failure([
			VfxIssue.new("PRESET_VALIDATION", "type", "Preset root must be an object.", "/type")
		])

	var schema := _registry.schema()
	var structural_issues := _subset_validator.validate(value, schema)
	if not structural_issues.is_empty():
		return VfxResult.failure(structural_issues)

	var semantic_issues: Array[VfxIssue] = []
	for rule in schema.get("x_vfx_rules", []):
		_apply_rule(value, rule, semantic_issues)
	if semantic_issues.is_empty():
		semantic_issues.append_array(preload("res://src/preview/curve_flow/vfx_curve_flow_contract.gd").validate_preset(value))
	return VfxResult.with_issues(value, semantic_issues)


func _apply_rule(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	match rule["name"]:
		"LIFECYCLE_PHASE_STRUCTURE":
			_validate_lifecycle_phase_structure(preset, rule, issues)
		"PRESET_HAS_LAYER":
			_validate_preset_has_layer(preset, rule, issues)
		"UNIQUE_LAYER_IDS_ACROSS_PHASES":
			_validate_unique_layer_ids(preset, rule, issues)
		"TYPE_DISPATCHED_PARAMETER_SCHEMA":
			_validate_type_dispatched_parameters(preset, rule, issues)
		"PARTICLE_EMISSION_CONFIGURATION":
			_validate_particle_emission(preset, rule, issues)
		"PARTICLE_EMITTER_SHAPE":
			_validate_particle_emitter(preset, rule, issues)
		"PARTICLE_MOTION_RANGE_ORDER", "PARTICLE_SIZE_MULTIPLIER_RANGE_ORDER":
			_validate_particle_parameter_ranges(preset, rule, issues)
		"RUNTIME_INPUT_NAMES":
			_validate_runtime_inputs(preset, rule, issues)
		"EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS":
			_validate_effective_space_anchors(preset, rule, issues)
		"RENDER_PLANE_FOR_EFFECTIVE_SPACE":
			_validate_render_plane(preset, rule, issues)
		"RUNTIME_MODULATION_CONFIGURATION":
			_validate_runtime_modulation_configuration(preset, rule, issues)


func _validate_lifecycle_phase_structure(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var lifecycle = _value_at_pointer(preset, rule["lifecycle_path"])
	var phases = _value_at_pointer(preset, rule["phases_path"])
	if not lifecycle is Dictionary or not phases is Dictionary:
		return
	var mode_value = lifecycle.get(rule["mode_field"], null)
	var phase_names_by_mode: Dictionary = rule["phase_names_by_mode"]
	if not phase_names_by_mode.has(mode_value):
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "lifecycle_mode_configuration", "Lifecycle mode has no configured phase stack.", rule["phases_path"]))
		return
	var expected: Array = phase_names_by_mode[mode_value]
	var actual: Array = phases.keys()
	if actual.size() != expected.size():
		issues.append(VfxIssue.new("PRESET_VALIDATION", rule["issue_code"], rule["message"], rule["phases_path"]))
		return
	for phase_name in expected:
		if not phases.has(phase_name):
			issues.append(VfxIssue.new("PRESET_VALIDATION", rule["issue_code"], "%s Missing phase %s." % [rule["message"], phase_name], rule["phases_path"]))
			return


func _validate_preset_has_layer(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	if _layer_entries(preset, rule["phases_path"]).is_empty():
		issues.append(VfxIssue.new("PRESET_VALIDATION", "preset_has_no_layers", "Preset must contain at least one Layer.", rule["phases_path"]))


func _validate_unique_layer_ids(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var seen: Dictionary = {}
	for entry in _layer_entries(preset, rule["phases_path"]):
		var layer: Dictionary = entry["layer"]
		var layer_id: String = layer[rule["id_field"]]
		if seen.has(layer_id):
			issues.append(VfxIssue.new("PRESET_VALIDATION", "duplicate_layer_id", "Layer id must be unique across all phases.", "%s/%s" % [entry["pointer"], rule["id_field"]]))
		else:
			seen[layer_id] = true


func _validate_type_dispatched_parameters(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var schema := _registry.schema()
	var type_registry = _value_at_pointer(schema, rule["layer_types_path"])
	if not type_registry is Dictionary:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "layer_types_unavailable", "Layer Type registry is unavailable.", rule["layer_types_path"]))
		return
	for entry in _layer_entries(preset, rule["phases_path"]):
		var layer: Dictionary = entry["layer"]
		var layer_type: String = layer[rule["type_field"]]
		if not type_registry.has(layer_type):
			issues.append(VfxIssue.new("PRESET_VALIDATION", "unknown_layer_type", "Layer Type is not declared by the Schema.", "%s/%s" % [entry["pointer"], rule["type_field"]]))
			continue
		var type_definition: Dictionary = type_registry[layer_type]
		var parameters_schema := _registry.resolve_local_ref(type_definition["parameters_ref"])
		if not parameters_schema.success:
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", parameters_schema.issues[0].code, parameters_schema.issues[0].message, "%s/parameters_ref" % rule["layer_types_path"]))
			continue
		issues.append_array(_subset_validator.validate(layer[rule["parameters_field"]], parameters_schema.value, "%s/%s" % [entry["pointer"], rule["parameters_field"]]))


func _validate_particle_emission(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	for entry in _particle_entries(preset, rule):
		var parameters: Dictionary = entry["layer"][rule["parameters_field"]]
		var pointer: String = "%s/%s" % [entry["pointer"], rule["parameters_field"]]
		var emission_mode = parameters[rule["emission_mode_field"]]
		var mode_requirements: Dictionary = rule["mode_requirements"]
		if not mode_requirements.has(emission_mode):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "emission_mode_configuration", "Emission mode has no configured field requirements.", pointer))
			continue
		var requirements: Dictionary = mode_requirements[emission_mode]
		var valid := true
		for required_field in requirements["required_fields"]:
			if not parameters.has(required_field):
				valid = false
		for forbidden_field in requirements["forbidden_fields"]:
			if parameters.has(forbidden_field):
				valid = false
		if not valid:
			issues.append(VfxIssue.new("PRESET_VALIDATION", requirements["issue_code"], requirements["message"], pointer))


func _validate_particle_emitter(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	for entry in _particle_entries(preset, rule):
		var parameters: Dictionary = entry["layer"][rule["parameters_field"]]
		var emitter: Dictionary = parameters[rule["emitter_field"]]
		var shape = emitter[rule["shape_field"]]
		var pointer: String = "%s/%s/%s" % [entry["pointer"], rule["parameters_field"], rule["emitter_field"]]
		var geometry_by_shape: Dictionary = rule["geometry_by_shape"]
		if not geometry_by_shape.has(shape):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "emitter_shape_configuration", "Emitter shape has no configured geometry.", pointer))
			continue
		var allowed: Array = [rule["shape_field"]]
		allowed.append_array(geometry_by_shape[shape])
		var valid := true
		for geometry_name in geometry_by_shape[shape]:
			if not emitter.has(geometry_name):
				valid = false
		for geometry_name in emitter:
			if not allowed.has(geometry_name):
				valid = false
		if not valid:
			issues.append(VfxIssue.new("PRESET_VALIDATION", rule["issue_code"], rule["message"], pointer))


func _validate_particle_parameter_ranges(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	for entry in _particle_entries(preset, rule):
		var parameters: Dictionary = entry["layer"][rule["parameters_field"]]
		for range_definition in rule["ranges"]:
			var minimum_field: String = range_definition["minimum_field"]
			var maximum_field: String = range_definition["maximum_field"]
			if parameters[minimum_field] > parameters[maximum_field]:
				issues.append(VfxIssue.new("PRESET_VALIDATION", rule["issue_code"], rule["message"], "%s/%s/%s" % [entry["pointer"], rule["parameters_field"], minimum_field]))


func _validate_runtime_inputs(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var contract = _value_at_pointer(_registry.schema(), rule["contract_path"])
	if not contract is Dictionary:
		issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "runtime_inputs_unavailable", "Runtime input contract is unavailable.", rule["contract_path"]))
		return
	var inputs = _value_at_pointer(preset, rule["runtime_inputs_path"])
	if not inputs is Array:
		return
	for index in inputs.size():
		if not contract.has(inputs[index]):
			issues.append(VfxIssue.new("PRESET_VALIDATION", rule["issue_code"], rule["message"], "%s/%d" % [rule["runtime_inputs_path"], index]))


func _validate_effective_space_anchors(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var default_space: String = preset[rule["default_space_field"]]
	var vehicle_space_modes: Array = rule["vehicle_space_modes"]
	for entry in _layer_entries(preset, rule["phases_path"]):
		var layer: Dictionary = entry["layer"]
		var effective_space: String = layer.get(rule["layer_space_field"], default_space)
		var has_anchors := layer.has(rule["anchors_field"])
		if vehicle_space_modes.has(effective_space):
			if not has_anchors or (layer[rule["anchors_field"]] as Array).is_empty():
				issues.append(VfxIssue.new("PRESET_VALIDATION", rule["missing_anchor_issue_code"], rule["missing_anchor_message"], entry["pointer"]))
		elif has_anchors:
			issues.append(VfxIssue.new("PRESET_VALIDATION", rule["unexpected_anchor_issue_code"], rule["unexpected_anchor_message"], "%s/%s" % [entry["pointer"], rule["anchors_field"]]))


func _validate_render_plane(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var default_space: String = preset[rule["default_space_field"]]
	var allowed_planes_by_space: Dictionary = rule["allowed_planes_by_space"]
	for entry in _layer_entries(preset, rule["phases_path"]):
		var layer: Dictionary = entry["layer"]
		var effective_space: String = layer.get(rule["layer_space_field"], default_space)
		if not allowed_planes_by_space.has(effective_space):
			issues.append(VfxIssue.new("SCHEMA_CONFIGURATION", "render_plane_configuration", "Space Mode has no configured render planes.", entry["pointer"]))
		elif not allowed_planes_by_space[effective_space].has(layer[rule["render_plane_field"]]):
			issues.append(VfxIssue.new("PRESET_VALIDATION", rule["issue_code"], rule["message"], "%s/%s" % [entry["pointer"], rule["render_plane_field"]]))


func _validate_runtime_modulation_configuration(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var sources_value: Variant = preset.get(rule["sources_field"], [])
	if not sources_value is Array:
		return
	var source_ids: Dictionary = {}
	for source_index in sources_value.size():
		var source: Dictionary = sources_value[source_index]
		var source_pointer := "/%s/%d" % [rule["sources_field"], source_index]
		var source_id := str(source.get(rule["source_id_field"], ""))
		if source_ids.has(source_id):
			issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_duplicate_source_id", "Runtime Modulation source ids must be unique.", "%s/%s" % [source_pointer, rule["source_id_field"]]))
		else:
			source_ids[source_id] = true
		_validate_modulation_source(source, source_pointer, rule, issues)

	var declared_inputs: Dictionary = {}
	for input_name in preset.get(rule["runtime_inputs_path"].trim_prefix("/"), []):
		declared_inputs[str(input_name)] = true
	var runtime_input_contract: Variant = _value_at_pointer(_registry.schema(), rule["runtime_input_contract_path"])
	for entry in _layer_entries(preset, rule["phases_path"]):
		var layer: Dictionary = entry["layer"]
		var layer_pointer: String = entry["pointer"]
		var layer_type := str(layer.get(rule["layer_type_field"], ""))
		_validate_modulation_pivot(layer, layer_pointer, layer_type, rule, issues)
		_validate_visual_bend(layer, layer_pointer, layer_type, rule, issues)
		var binding_ids: Dictionary = {}
		var bindings: Variant = layer.get(rule["bindings_field"], [])
		if bindings is Array:
			for binding_index in bindings.size():
				var binding: Dictionary = bindings[binding_index]
				var binding_pointer := "%s/%s/%d" % [layer_pointer, rule["bindings_field"], binding_index]
				var binding_id := str(binding.get(rule["binding_id_field"], ""))
				if binding_ids.has(binding_id):
					issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_duplicate_binding_id", "Runtime Modulation binding ids must be unique per Layer.", "%s/%s" % [binding_pointer, rule["binding_id_field"]]))
				else:
					binding_ids[binding_id] = true
				_validate_modulation_binding(binding, binding_pointer, layer_type, declared_inputs, source_ids, runtime_input_contract, rule, issues)
		var clamp_targets: Dictionary = {}
		var clamps: Variant = layer.get(rule["clamps_field"], [])
		if clamps is Array:
			for clamp_index in clamps.size():
				var clamp: Dictionary = clamps[clamp_index]
				var clamp_pointer := "%s/%s/%d" % [layer_pointer, rule["clamps_field"], clamp_index]
				var target := str(clamp.get(rule["target_field"], ""))
				if clamp_targets.has(target):
					issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_duplicate_clamp_target", "Runtime Modulation clamp targets must be unique per Layer.", "%s/%s" % [clamp_pointer, rule["target_field"]]))
				else:
					clamp_targets[target] = true
				_validate_modulation_clamp(clamp, clamp_pointer, rule, issues)
		_validate_modulation_target_requirements(layer, layer_pointer, bindings, clamp_targets, rule, issues)


func _validate_modulation_source(source: Dictionary, pointer: String, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var source_type := str(source.get(rule["source_type_field"], ""))
	var source_types: Dictionary = rule["source_types"]
	if not source_types.has(source_type):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_source_type", "Runtime Modulation source type is not configured.", "%s/%s" % [pointer, rule["source_type_field"]]))
		return
	var source_contract: Dictionary = source_types[source_type]
	var requires_wave: bool = source_contract.get("requires_wave", false)
	var requires_phase: bool = source_contract.get("requires_phase", false)
	var requires_positive_frequency: bool = source_contract.get("requires_positive_frequency", false)
	if requires_wave and (not source_contract.get("waves", []).has(source.get(rule["wave_field"]))):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_wave", "Runtime Modulation source wave is not configured.", "%s/%s" % [pointer, rule["wave_field"]]))
	if not requires_wave and source.has(rule["wave_field"]):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_source_field", "Runtime Modulation source type does not support wave.", "%s/%s" % [pointer, rule["wave_field"]]))
	var frequency: Variant = source.get(rule["frequency_field"])
	if not _is_finite_number(frequency) or (requires_positive_frequency and float(frequency) <= 0.0) or (not requires_positive_frequency and float(frequency) < 0.0):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_frequency", "Runtime Modulation frequency must be finite and positive when required by its source type.", "%s/%s" % [pointer, rule["frequency_field"]]))
	if requires_phase and not _is_finite_number(source.get(rule["phase_field"])):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_phase", "Runtime Modulation phase must be finite.", "%s/%s" % [pointer, rule["phase_field"]]))
	if not requires_phase and source.has(rule["phase_field"]):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_source_field", "Runtime Modulation source type does not support phase_degrees.", "%s/%s" % [pointer, rule["phase_field"]]))


func _validate_modulation_binding(binding: Dictionary, pointer: String, layer_type: String, declared_inputs: Dictionary, source_ids: Dictionary, runtime_input_contract: Variant, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var target := str(binding.get(rule["target_field"], ""))
	var target_contracts: Dictionary = rule["target_contracts"]
	if not target_contracts.has(target):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_target", "Runtime Modulation target is not configured.", "%s/%s" % [pointer, rule["target_field"]]))
		return
	var target_contract: Dictionary = target_contracts[target]
	if not target_contract["compatible_layer_types"].has(layer_type):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_target_layer_type_incompatible", "Runtime Modulation target is not supported by this Layer Type.", "%s/%s" % [pointer, rule["target_field"]]))
	if binding.get(rule["operation_field"]) != target_contract["operation"]:
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_operation", "Runtime Modulation operation does not match the configured target.", "%s/%s" % [pointer, rule["operation_field"]]))
	var source: Dictionary = binding.get(rule["source_field"], {})
	var binding_source_type := str(source.get(rule["source_type_field"], ""))
	if not rule["binding_source_types"].has(binding_source_type):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_binding_source_type", "Runtime Modulation binding source type is not configured.", "%s/%s/%s" % [pointer, rule["source_field"], rule["source_type_field"]]))
	elif binding_source_type == "RUNTIME_INPUT":
		var input_name := str(source.get(rule["input_field"], ""))
		if not declared_inputs.has(input_name):
			issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_input_not_declared", "Runtime Modulation input must be declared by the Preset.", "%s/%s/%s" % [pointer, rule["source_field"], rule["input_field"]]))
		elif not _runtime_input_is_number(runtime_input_contract, input_name):
			issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_input_not_number", "Runtime Modulation input must have a numeric Schema contract.", "%s/%s/%s" % [pointer, rule["source_field"], rule["input_field"]]))
	elif binding_source_type == "PRESET_SOURCE":
		var source_id := str(source.get(rule["source_id_reference_field"], ""))
		if not source_ids.has(source_id):
			issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_source_not_found", "Runtime Modulation binding source must exist in the Preset source table.", "%s/%s/%s" % [pointer, rule["source_field"], rule["source_id_reference_field"]]))
	_validate_modulation_mapping(binding.get(rule["mapping_field"], {}), "%s/%s" % [pointer, rule["mapping_field"]], target, rule, issues)


func _validate_modulation_mapping(mapping: Dictionary, pointer: String, target: String, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	if not rule["mapping_types"].has(mapping.get(rule["mapping_type_field"])):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_mapping_type", "Runtime Modulation mapping type is not configured.", "%s/%s" % [pointer, rule["mapping_type_field"]]))
	var input_min: Variant = mapping.get(rule["input_min_field"])
	var input_max: Variant = mapping.get(rule["input_max_field"])
	var output_min: Variant = mapping.get(rule["output_min_field"])
	var output_max: Variant = mapping.get(rule["output_max_field"])
	if not _is_finite_number(input_min) or not _is_finite_number(input_max) or not _is_finite_number(output_min) or not _is_finite_number(output_max):
		var code := "runtime_modulation_opacity_multiplier_nonfinite" if target == "VISUAL_OPACITY_MULTIPLIER" else "runtime_modulation_mapping_nonfinite"
		issues.append(VfxIssue.new("PRESET_VALIDATION", code, "Runtime Modulation mapping values must be finite.", pointer))
		return
	if float(input_min) >= float(input_max):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_mapping_range", "Runtime Modulation mapping input minimum must be less than maximum.", pointer))
	if target == "VISUAL_OPACITY_MULTIPLIER" and (float(output_min) < 0.0 or float(output_max) < 0.0):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_opacity_multiplier_negative", "Visual opacity multiplier output must be non-negative.", pointer))


func _validate_modulation_clamp(clamp: Dictionary, pointer: String, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var target := str(clamp.get(rule["target_field"], ""))
	if not rule["target_contracts"].has(target):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_clamp_target", "Runtime Modulation clamp target is not configured.", "%s/%s" % [pointer, rule["target_field"]]))
		return
	var minimum: Variant = clamp.get(rule["minimum_effective_field"])
	var maximum: Variant = clamp.get(rule["maximum_effective_field"])
	if minimum == null and maximum == null:
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_clamp_empty", "Runtime Modulation clamp requires a minimum or maximum.", pointer))
		return
	if (minimum != null and not _is_finite_number(minimum)) or (maximum != null and not _is_finite_number(maximum)):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_clamp_nonfinite", "Runtime Modulation clamp bounds must be finite.", pointer))
	elif minimum != null and maximum != null and float(minimum) > float(maximum):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_clamp_order", "Runtime Modulation clamp minimum cannot exceed maximum.", pointer))


func _validate_modulation_pivot(layer: Dictionary, layer_pointer: String, layer_type: String, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var transform: Dictionary = layer.get(rule["transform_field"], {})
	var pivot: Variant = transform.get(rule["pivot_field"], [0.0, 0.0])
	if not pivot is Array or pivot.size() != 2 or not _is_finite_number(pivot[0]) or not _is_finite_number(pivot[1]):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_pivot_nonfinite", "Runtime Modulation pivot must be two finite numbers.", "%s/%s/%s" % [layer_pointer, rule["transform_field"], rule["pivot_field"]]))
		return
	if (not is_zero_approx(float(pivot[0])) or not is_zero_approx(float(pivot[1]))) and not rule["pivot_compatible_layer_types"].has(layer_type):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_pivot_layer_type_incompatible", "Non-zero Runtime Modulation pivot is not supported by this Layer Type.", "%s/%s/%s" % [layer_pointer, rule["transform_field"], rule["pivot_field"]]))


func _validate_visual_bend(layer: Dictionary, layer_pointer: String, layer_type: String, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var bend_field: String = rule["visual_bend_field"]
	if not layer.has(bend_field):
		return
	var bend: Variant = layer[bend_field]
	if not bend is Dictionary:
		return
	if not rule["visual_bend_compatible_layer_types"].has(layer_type):
		issues.append(VfxIssue.new("PRESET_VALIDATION", "visual_bend_layer_type_incompatible", "Visual Bend is supported only by configured Layer Types.", "%s/%s" % [layer_pointer, bend_field]))
		return
	var axis: Variant = bend.get(rule["visual_bend_axis_field"])
	var curve: Variant = bend.get(rule["visual_bend_curve_field"])
	if not axis is String or axis.is_empty():
		issues.append(VfxIssue.new("PRESET_VALIDATION", "visual_bend_axis", "Visual Bend axis must be configured.", "%s/%s/%s" % [layer_pointer, bend_field, rule["visual_bend_axis_field"]]))
	if not curve is String or curve.is_empty():
		issues.append(VfxIssue.new("PRESET_VALIDATION", "visual_bend_curve", "Visual Bend curve must be configured.", "%s/%s/%s" % [layer_pointer, bend_field, rule["visual_bend_curve_field"]]))
	var start_ratio: Variant = bend.get(rule["visual_bend_start_ratio_field"])
	if not _is_finite_number(start_ratio) or float(start_ratio) < 0.0 or float(start_ratio) >= 1.0:
		issues.append(VfxIssue.new("PRESET_VALIDATION", "visual_bend_start_ratio", "Visual Bend start_ratio must be finite and within [0, 1).", "%s/%s/%s" % [layer_pointer, bend_field, rule["visual_bend_start_ratio_field"]]))
	var span_source_px: Variant = bend.get(rule["visual_bend_span_source_px_field"])
	if not _is_finite_number(span_source_px) or float(span_source_px) <= 0.0:
		issues.append(VfxIssue.new("PRESET_VALIDATION", "visual_bend_span_source_px", "Visual Bend span_source_px must be finite and greater than zero.", "%s/%s/%s" % [layer_pointer, bend_field, rule["visual_bend_span_source_px_field"]]))


func _validate_modulation_target_requirements(layer: Dictionary, layer_pointer: String, bindings: Variant, clamp_targets: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	if not bindings is Array:
		return
	for binding_index in bindings.size():
		var binding: Variant = bindings[binding_index]
		if not binding is Dictionary:
			continue
		var target := str(binding.get(rule["target_field"], ""))
		var target_contracts: Dictionary = rule["target_contracts"]
		if not target_contracts.has(target):
			continue
		var target_contract: Dictionary = target_contracts[target]
		var binding_pointer := "%s/%s/%d" % [layer_pointer, rule["bindings_field"], binding_index]
		if target_contract.has("requires_static_field") and not layer.has(str(target_contract["requires_static_field"])):
			issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_target_requires_static_field", "Runtime Modulation target requires its configured static Layer metadata.", "%s/%s" % [binding_pointer, rule["target_field"]]))
		if target_contract.get("requires_target_clamp", false) and not clamp_targets.has(target):
			issues.append(VfxIssue.new("PRESET_VALIDATION", "runtime_modulation_target_clamp_required", "Runtime Modulation target requires an explicit target clamp.", "%s/%s" % [binding_pointer, rule["target_field"]]))


func _runtime_input_is_number(contract: Variant, input_name: String) -> bool:
	if not contract is Dictionary or not contract.has(input_name):
		return false
	var schema: Dictionary = contract[input_name]
	while schema.has("$ref"):
		var resolved := _registry.resolve_local_ref(schema["$ref"])
		if not resolved.success:
			return false
		schema = resolved.value
	return schema.get("type") == "number"


func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


func _particle_entries(preset: Dictionary, rule: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in _layer_entries(preset, rule["phases_path"]):
		if entry["layer"][rule["type_field"]] == rule["particle_type"]:
			entries.append(entry)
	return entries


func _layer_entries(preset: Dictionary, phases_path: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var phases = _value_at_pointer(preset, phases_path)
	if not phases is Dictionary:
		return entries
	for phase_name in phases:
		var phase = phases[phase_name]
		if not phase is Dictionary or not phase.get("layers") is Array:
			continue
		for index in phase["layers"].size():
			var layer = phase["layers"][index]
			if layer is Dictionary:
				entries.append({
					"layer": layer,
					"pointer": "%s/%s/layers/%d" % [phases_path, phase_name, index]
				})
	return entries


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
