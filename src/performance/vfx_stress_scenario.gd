class_name VfxStressScenario
extends RefCounted

var _scenario_id: String
var _vehicle_count: int
var _slots_per_vehicle: int
var _scope: String
var _workload_type: String


func _init(scenario_id: String, vehicle_count: int, slots_per_vehicle: int, scope: String, workload_type: String) -> void:
	_scenario_id = scenario_id
	_vehicle_count = vehicle_count
	_slots_per_vehicle = slots_per_vehicle
	_scope = scope
	_workload_type = workload_type


func scenario_id() -> String:
	return _scenario_id


func vehicle_count() -> int:
	return _vehicle_count


func slots_per_vehicle() -> int:
	return _slots_per_vehicle


func scope_name() -> String:
	return _scope


func workload_type() -> String:
	return _workload_type
