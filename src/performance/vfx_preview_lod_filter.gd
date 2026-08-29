class_name VfxPreviewLodFilter
extends RefCounted

const VfxPreviewRenderPlanModel := preload("res://src/preview/rendering/vfx_preview_render_plan.gd")
const VfxPreviewPhasePlanModel := preload("res://src/preview/rendering/vfx_preview_phase_plan.gd")


func filter(plan: RefCounted, lod_level: String, policy: RefCounted) -> VfxResult:
	if plan == null or policy == null:
		return _failure("preview_lod_input", "LOD filtering requires a Render Plan and Performance Policy.")
	var included: Array[String] = policy.lod_importances(lod_level)
	if included.is_empty():
		return _failure("preview_lod_unknown", "LOD level %s is not configured by the Performance Policy." % lod_level)
	var phases: Array[RefCounted] = []
	for phase in plan.phase_plans():
		var layer_specs: Array[RefCounted] = []
		for layer_spec in phase.layer_specs():
			if included.has(layer_spec.importance()):
				layer_specs.append(layer_spec)
		phases.append(VfxPreviewPhasePlanModel.new(phase.phase_name(), phase.duration_seconds() if phase.has_duration() else null, layer_specs))
	return VfxResult.ok(VfxPreviewRenderPlanModel.new(plan.preset_id(), plan.lifecycle_mode(), phases, plan.revision()))


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("PERFORMANCE_CONFIGURATION", code, message)])
