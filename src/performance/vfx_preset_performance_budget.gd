class_name VfxPresetPerformanceBudget
extends RefCounted

var _authoring_inventory: RefCounted
var _active_workload: RefCounted
var _workload_type: String


func _init(authoring_inventory: RefCounted, active_workload: RefCounted, workload_type: String) -> void:
	_authoring_inventory = authoring_inventory
	_active_workload = active_workload
	_workload_type = workload_type


func authoring_inventory() -> RefCounted:
	return _authoring_inventory


func active_workload() -> RefCounted:
	return _active_workload


func workload_type() -> String:
	return _workload_type
