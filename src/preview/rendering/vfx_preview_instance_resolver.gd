class_name VfxPreviewInstanceResolver
extends RefCounted

const VfxPreviewRenderInstanceSpecModel := preload("res://src/preview/rendering/vfx_preview_render_instance_spec.gd")

var _registry: RefCounted


func _init(registry: RefCounted) -> void:
	_registry = registry


func resolve(plan: RefCounted, profile_data: Dictionary) -> VfxResult:
	if plan == null or _registry == null:
		return VfxResult.failure([VfxIssue.new("PREVIEW_CONFIGURATION", "preview_instance_input", "Preview instance resolution requires a Plan and Schema Registry.")])
	var anchor_rule := _rule_named(_registry.schema(), "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")
	var vehicle_spaces: Array = anchor_rule.get("vehicle_space_modes", [])
	var profile_anchors: Dictionary = profile_data.get("anchors", {}) if profile_data.get("anchors", {}) is Dictionary else {}
	var instances: Array[RefCounted] = []
	var issues: Array[VfxIssue] = []
	for phase_plan in plan.phase_plans():
		for layer_spec in phase_plan.layer_specs():
			if vehicle_spaces.has(layer_spec.effective_space()):
				for anchor_index in layer_spec.anchor_names().size():
					var anchor_name: String = layer_spec.anchor_names()[anchor_index]
					var coordinate: Variant = profile_anchors.get(anchor_name)
					if not coordinate is Array or coordinate.size() != 2:
						issues.append(VfxIssue.new("PREVIEW_CONFIGURATION", "preview_anchor_missing", "Vehicle Profile is missing Preview Anchor %s." % anchor_name, "", "", -1, -1, "WARNING"))
						continue
					instances.append(VfxPreviewRenderInstanceSpecModel.new(phase_plan.phase_name(), layer_spec, anchor_name, Vector2(float(coordinate[0]), float(coordinate[1])), anchor_index))
			else:
				instances.append(VfxPreviewRenderInstanceSpecModel.new(phase_plan.phase_name(), layer_spec))
	return VfxResult.with_issues(instances, issues)


func _rule_named(schema: Dictionary, rule_name: String) -> Dictionary:
	for rule in schema.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == rule_name:
			return rule
	return {}
