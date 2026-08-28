class_name VfxPreviewRenderPlan
extends RefCounted

var _preset_id: String
var _lifecycle_mode: String
var _phase_plans: Array[RefCounted] = []
var _revision: int


func _init(preset_id_value: String, lifecycle_mode_value: String, phase_plan_values: Array, revision_value: int) -> void:
	_preset_id = preset_id_value
	_lifecycle_mode = lifecycle_mode_value
	for phase_plan in phase_plan_values:
		if phase_plan is RefCounted:
			_phase_plans.append(phase_plan)
	_revision = revision_value


func preset_id() -> String:
	return _preset_id


func lifecycle_mode() -> String:
	return _lifecycle_mode


func revision() -> int:
	return _revision


func phase_plans() -> Array[RefCounted]:
	return _phase_plans.duplicate()


func phase_named(phase_name: String) -> RefCounted:
	for phase_plan in _phase_plans:
		if phase_plan.phase_name() == phase_name:
			return phase_plan
	return null


func phase_layer_count() -> int:
	var count := 0
	for phase_plan in _phase_plans:
		count += phase_plan.layer_specs().size()
	return count
