class_name VfxPreviewLayerContextResolver
extends RefCounted

const VfxPreviewLayerContextModel := preload("res://src/preview/vfx_preview_layer_context.gd")

var _registry: RefCounted


func _init(registry: RefCounted) -> void:
	_registry = registry


func resolve(preset: Dictionary, phase_name: String, layer_id: String) -> RefCounted:
	if _registry == null or phase_name.is_empty() or layer_id.is_empty():
		return null
	var root_schema: Dictionary = _registry.schema()
	var anchor_rule: Dictionary = _rule_named(root_schema, "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")
	var render_rule: Dictionary = _rule_named(root_schema, "RENDER_PLANE_FOR_EFFECTIVE_SPACE")
	if anchor_rule.is_empty() or render_rule.is_empty():
		return null
	var layer: Dictionary = _layer_in_phase(preset, phase_name, layer_id, str(render_rule.get("phases_path", "/phases")).trim_prefix("/"))
	if layer.is_empty():
		return null
	var default_space_field: String = str(render_rule.get("default_space_field", ""))
	var layer_space_field: String = str(render_rule.get("layer_space_field", ""))
	var anchors_field: String = str(anchor_rule.get("anchors_field", ""))
	var render_plane_field: String = str(render_rule.get("render_plane_field", ""))
	if default_space_field.is_empty() or layer_space_field.is_empty() or anchors_field.is_empty() or render_plane_field.is_empty():
		return null
	var effective_space: String = str(layer.get(layer_space_field, preset.get(default_space_field, "")))
	var anchors: Array[String] = []
	if anchor_rule.get("vehicle_space_modes", []).has(effective_space):
		var declared_anchors: Variant = layer.get(anchors_field, [])
		if declared_anchors is Array:
			for anchor_value in declared_anchors:
				if anchor_value is String and not anchors.has(anchor_value):
					anchors.append(anchor_value)
	var transform_offset := _transform_offset(layer)
	return VfxPreviewLayerContextModel.new(layer_id, anchors, effective_space, transform_offset, str(layer.get(render_plane_field, "")))


func _layer_in_phase(preset: Dictionary, phase_name: String, layer_id: String, phases_field: String) -> Dictionary:
	var phases: Variant = preset.get(phases_field)
	if not phases is Dictionary:
		return {}
	var phase: Variant = phases.get(phase_name)
	if not phase is Dictionary:
		return {}
	var layers: Variant = phase.get("layers")
	if not layers is Array:
		return {}
	for layer_value in layers:
		if layer_value is Dictionary and str(layer_value.get("id", "")) == layer_id:
			return layer_value
	return {}


func _transform_offset(layer: Dictionary) -> Vector2:
	var transform_value: Variant = layer.get("transform", {})
	if not transform_value is Dictionary:
		return Vector2.ZERO
	var offset_value: Variant = transform_value.get("offset", [])
	if not offset_value is Array or offset_value.size() != 2:
		return Vector2.ZERO
	return Vector2(float(offset_value[0]), float(offset_value[1]))


func _rule_named(root_schema: Dictionary, rule_name: String) -> Dictionary:
	for rule in root_schema.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == rule_name:
			return rule
	return {}
