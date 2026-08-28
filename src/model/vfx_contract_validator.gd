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
		"PARTICLE_MOTION_RANGE_ORDER":
			_validate_particle_motion_ranges(preset, rule, issues)
		"RUNTIME_INPUT_NAMES":
			_validate_runtime_inputs(preset, rule, issues)
		"EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS":
			_validate_effective_space_anchors(preset, rule, issues)
		"RENDER_PLANE_FOR_EFFECTIVE_SPACE":
			_validate_render_plane(preset, rule, issues)


func _validate_lifecycle_phase_structure(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var lifecycle = _value_at_pointer(preset, rule["lifecycle_path"])
	var phases = _value_at_pointer(preset, rule["phases_path"])
	if not lifecycle is Dictionary or not phases is Dictionary:
		return
	var expected: Array = ["one_shot"] if lifecycle["mode"] == "ONE_SHOT" else ["start", "loop", "end"]
	var actual: Array = phases.keys()
	if actual.size() != expected.size():
		issues.append(VfxIssue.new("PRESET_VALIDATION", "lifecycle_phase_structure", "Lifecycle does not have the required phase stack.", rule["phases_path"]))
		return
	for phase_name in expected:
		if not phases.has(phase_name):
			issues.append(VfxIssue.new("PRESET_VALIDATION", "lifecycle_phase_structure", "Lifecycle is missing phase %s." % phase_name, rule["phases_path"]))
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
		if parameters["emission_mode"] == "BURST":
			if not parameters.has("burst_count") or parameters.has("emission_rate_per_second") or parameters.has("max_particles"):
				issues.append(VfxIssue.new("PRESET_VALIDATION", "burst_emission_fields", "BURST particles require burst_count only.", pointer))
		elif parameters["emission_mode"] == "CONTINUOUS":
			if not parameters.has("emission_rate_per_second") or not parameters.has("max_particles") or parameters.has("burst_count"):
				issues.append(VfxIssue.new("PRESET_VALIDATION", "continuous_emission_fields", "CONTINUOUS particles require rate and authoring capacity.", pointer))


func _validate_particle_emitter(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var required_geometry := {
		"POINT": [],
		"CIRCLE": ["radius"],
		"BOX": ["size"],
		"CONE": ["angle_degrees", "radius"],
		"LINE": ["length"]
	}
	for entry in _particle_entries(preset, rule):
		var parameters: Dictionary = entry["layer"][rule["parameters_field"]]
		var emitter: Dictionary = parameters[rule["emitter_field"]]
		var shape: String = emitter["shape"]
		var pointer: String = "%s/%s/%s" % [entry["pointer"], rule["parameters_field"], rule["emitter_field"]]
		var allowed: Array = ["shape"]
		allowed.append_array(required_geometry[shape])
		var valid := true
		for geometry_name in required_geometry[shape]:
			if not emitter.has(geometry_name):
				valid = false
		for geometry_name in emitter:
			if not allowed.has(geometry_name):
				valid = false
		if not valid:
			issues.append(VfxIssue.new("PRESET_VALIDATION", "emitter_shape_geometry", "Emitter geometry does not match its shape.", pointer))


func _validate_particle_motion_ranges(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	for entry in _particle_entries(preset, rule):
		var parameters: Dictionary = entry["layer"][rule["parameters_field"]]
		for range_definition in rule["ranges"]:
			var minimum_field: String = range_definition["minimum_field"]
			var maximum_field: String = range_definition["maximum_field"]
			if parameters[minimum_field] > parameters[maximum_field]:
				issues.append(VfxIssue.new("PRESET_VALIDATION", "motion_range_order", "Particle minimum cannot exceed maximum.", "%s/%s/%s" % [entry["pointer"], rule["parameters_field"], minimum_field]))


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
			issues.append(VfxIssue.new("PRESET_VALIDATION", "unknown_runtime_input", "Runtime input is not declared by the Schema.", "%s/%d" % [rule["runtime_inputs_path"], index]))


func _validate_effective_space_anchors(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var default_space: String = preset[rule["default_space_field"]]
	for entry in _layer_entries(preset, rule["phases_path"]):
		var layer: Dictionary = entry["layer"]
		var effective_space: String = layer.get(rule["layer_space_field"], default_space)
		var has_anchors := layer.has(rule["anchors_field"])
		if effective_space == "VEHICLE_LOCAL" or effective_space == "VEHICLE_FOLLOW_WORLD_TRAIL":
			if not has_anchors or (layer[rule["anchors_field"]] as Array).is_empty():
				issues.append(VfxIssue.new("PRESET_VALIDATION", "vehicle_anchor_required", "Vehicle Space Mode requires one or more Anchors.", entry["pointer"]))
		elif has_anchors:
			issues.append(VfxIssue.new("PRESET_VALIDATION", "anchor_not_allowed", "World and Screen Space Modes do not accept vehicle Anchors in v1.", "%s/%s" % [entry["pointer"], rule["anchors_field"]]))


func _validate_render_plane(preset: Dictionary, rule: Dictionary, issues: Array[VfxIssue]) -> void:
	var allowed_planes := {
		"VEHICLE_LOCAL": ["UNDER_VEHICLE", "OVER_VEHICLE"],
		"VEHICLE_FOLLOW_WORLD_TRAIL": ["UNDER_VEHICLE", "OVER_VEHICLE"],
		"WORLD_AREA": ["WORLD"],
		"SCREEN_UI": ["SCREEN_UI"]
	}
	var default_space: String = preset[rule["default_space_field"]]
	for entry in _layer_entries(preset, rule["phases_path"]):
		var layer: Dictionary = entry["layer"]
		var effective_space: String = layer.get(rule["layer_space_field"], default_space)
		if not allowed_planes[effective_space].has(layer[rule["render_plane_field"]]):
			issues.append(VfxIssue.new("PRESET_VALIDATION", "render_plane_for_space", "Render plane is not valid for the effective Space Mode.", "%s/%s" % [entry["pointer"], rule["render_plane_field"]]))


func _particle_entries(preset: Dictionary, rule: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in _layer_entries(preset, rule["phases_path"]):
		if entry["layer"]["type"] == rule["particle_type"]:
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
