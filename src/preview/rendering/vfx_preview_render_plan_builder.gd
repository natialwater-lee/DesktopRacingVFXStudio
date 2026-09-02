class_name VfxPreviewRenderPlanBuilder
extends RefCounted

const VfxPreviewRenderPlanModel := preload("res://src/preview/rendering/vfx_preview_render_plan.gd")
const VfxPreviewPhasePlanModel := preload("res://src/preview/rendering/vfx_preview_phase_plan.gd")
const VfxPreviewLayerSpecModel := preload("res://src/preview/rendering/vfx_preview_layer_spec.gd")
const VfxRuntimeModulationProgramBuilderModel := preload("res://src/preview/runtime_modulation/vfx_runtime_modulation_program_builder.gd")

var _registry: RefCounted
var _next_revision := 1


func _init(registry: RefCounted) -> void:
	_registry = registry


func build(normalized_data: Dictionary) -> VfxResult:
	if _registry == null:
		return _failure("preview_registry_missing", "Preview Render Plan requires a loaded Schema Registry.")
	var schema: Dictionary = _registry.schema()
	var lifecycle_rule := _rule_named(schema, "LIFECYCLE_PHASE_STRUCTURE")
	var anchor_rule := _rule_named(schema, "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")
	var render_rule := _rule_named(schema, "RENDER_PLANE_FOR_EFFECTIVE_SPACE")
	if lifecycle_rule.is_empty() or anchor_rule.is_empty() or render_rule.is_empty():
		return _failure("preview_rule_missing", "Preview Render Plan requires the lifecycle, anchor, and render-plane Schema rules.")
	var lifecycle_path: String = str(lifecycle_rule.get("lifecycle_path", "")).trim_prefix("/")
	var phases_path: String = str(lifecycle_rule.get("phases_path", "")).trim_prefix("/")
	var mode_field: String = str(lifecycle_rule.get("mode_field", ""))
	var lifecycle: Variant = normalized_data.get(lifecycle_path)
	var phases: Variant = normalized_data.get(phases_path)
	if not lifecycle is Dictionary or not phases is Dictionary or mode_field.is_empty():
		return _failure("preview_document_shape", "A valid Preview document requires lifecycle and phase objects.")
	var lifecycle_mode: String = str(lifecycle.get(mode_field, ""))
	var phase_names: Variant = lifecycle_rule.get("phase_names_by_mode", {}).get(lifecycle_mode, [])
	if not phase_names is Array:
		return _failure("preview_lifecycle_mode", "Lifecycle mode is not mapped to Preview phases by Schema.")
	var default_space_field: String = str(render_rule.get("default_space_field", ""))
	var layer_space_field: String = str(render_rule.get("layer_space_field", ""))
	var anchors_field: String = str(anchor_rule.get("anchors_field", ""))
	var render_plane_field: String = str(render_rule.get("render_plane_field", ""))
	var vehicle_spaces: Array = anchor_rule.get("vehicle_space_modes", [])
	var phase_plans: Array[RefCounted] = []
	for phase_name_value in phase_names:
		var phase_name := str(phase_name_value)
		var phase: Variant = phases.get(phase_name)
		if not phase is Dictionary:
			return _failure("preview_phase_missing", "Valid Preview document is missing phase %s." % phase_name)
		var layer_values: Variant = phase.get("layers")
		if not layer_values is Array:
			return _failure("preview_layers_missing", "Preview phase %s has no Layer array." % phase_name)
		var layer_specs: Array[RefCounted] = []
		for index in layer_values.size():
			var layer: Variant = layer_values[index]
			if not layer is Dictionary:
				return _failure("preview_layer_shape", "Preview Layer must be an object.")
			var effective_space: String = str(layer.get(layer_space_field, normalized_data.get(default_space_field, "")))
			var anchors: Array = layer.get(anchors_field, []) if vehicle_spaces.has(effective_space) else []
			var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
			var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
			layer_specs.append(VfxPreviewLayerSpecModel.new(
				str(layer.get("id", "")),
				str(layer.get("type", "")),
				str(layer.get("importance", "")),
				str(layer.get("blend_mode", "")),
				str(layer.get(render_plane_field, "")),
				effective_space,
				anchors,
				transform,
				parameters,
				bool(layer.get("enabled", true)),
				int(layer.get("sort_order", 0)),
				index
			))
		phase_plans.append(VfxPreviewPhasePlanModel.new(phase_name, phase.get("duration_seconds"), layer_specs))
	var modulation_result: VfxResult = VfxRuntimeModulationProgramBuilderModel.new(_registry).build(normalized_data)
	if not modulation_result.success:
		return VfxResult.failure(modulation_result.issues)
	var plan := VfxPreviewRenderPlanModel.new(str(normalized_data.get("preset_id", "")), lifecycle_mode, phase_plans, _next_revision, modulation_result.value)
	_next_revision += 1
	return VfxResult.ok(plan)


func _rule_named(schema: Dictionary, rule_name: String) -> Dictionary:
	for rule in schema.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == rule_name:
			return rule.duplicate(true)
	return {}


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("PREVIEW_CONFIGURATION", code, message)])
