class_name VfxWorkloadBudget
extends "res://src/performance/vfx_authoring_budget.gd"

var _workload_type: String


func _init(workload_type: String = "", values: Dictionary = {}) -> void:
	super(values)
	_workload_type = workload_type


func workload_type() -> String:
	return _workload_type
