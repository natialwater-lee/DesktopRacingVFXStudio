class_name VfxPreviewPhasePlan
extends RefCounted

var _phase_name: String
var _duration_seconds: Variant
var _layer_specs: Array[RefCounted] = []


func _init(phase_name_value: String, duration_seconds_value: Variant, layer_spec_values: Array) -> void:
	_phase_name = phase_name_value
	_duration_seconds = duration_seconds_value
	for layer_spec in layer_spec_values:
		if layer_spec is RefCounted:
			_layer_specs.append(layer_spec)


func phase_name() -> String:
	return _phase_name


func has_duration() -> bool:
	return _duration_seconds != null


func duration_seconds() -> float:
	return float(_duration_seconds) if _duration_seconds != null else 0.0


func layer_specs() -> Array[RefCounted]:
	return _layer_specs.duplicate()
