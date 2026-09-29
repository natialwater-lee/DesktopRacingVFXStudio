class_name VfxPreviewRenderPlan
extends RefCounted

var _preset_id: String
var _lifecycle_mode: String
var _phase_plans: Array[RefCounted] = []
var _revision: int
var _runtime_modulation_program: RefCounted
var _curve_geometry: Dictionary = {}


func _init(preset_id_value: String, lifecycle_mode_value: String, phase_plan_values: Array, revision_value: int, runtime_modulation_program_value: RefCounted = null) -> void:
	_preset_id = preset_id_value
	_lifecycle_mode = lifecycle_mode_value
	for phase_plan in phase_plan_values:
		if phase_plan is RefCounted:
			_phase_plans.append(phase_plan)
	_revision = revision_value
	_runtime_modulation_program = runtime_modulation_program_value
	var geometry = preload("res://src/preview/curve_flow/vfx_curve_flow_static_geometry.gd")
	for phase in _phase_plans:
		for layer in phase.layer_specs():
			if layer.layer_type() == "CURVE_FLOW" and layer.parameters().profile_version == 2:
				var key: String = geometry.key(layer.parameters())
				if not _curve_geometry.has(key): _curve_geometry[key] = geometry.prepare(layer.parameters())
	_curve_geometry.make_read_only()

func curve_geometry(parameters: Dictionary) -> RefCounted:
	return _curve_geometry.get(preload("res://src/preview/curve_flow/vfx_curve_flow_static_geometry.gd").key(parameters))


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


func runtime_modulation_program() -> RefCounted:
	return _runtime_modulation_program
