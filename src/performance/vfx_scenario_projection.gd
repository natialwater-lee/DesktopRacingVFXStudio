class_name VfxScenarioProjection
extends RefCounted

var _values: Dictionary = {}
var _scenario: RefCounted


func _init(values: Dictionary = {}, scenario: RefCounted = null) -> void:
	_values = values.duplicate(true)
	_scenario = scenario


func project(slot_budgets: Array, scenario: RefCounted) -> RefCounted:
	var per_vehicle := _new_values()
	for budget in slot_budgets:
		if budget == null:
			continue
		for key in per_vehicle.keys():
			per_vehicle[key] += _value_for_budget(budget, key)
	var projected := _new_values()
	var multiplier: int = scenario.vehicle_count() if scenario != null else 0
	for key in projected.keys():
		projected[key] = per_vehicle[key] * multiplier
	var result: Variant = get_script().new()
	result._values = projected.duplicate(true)
	result._scenario = scenario
	return result


func expanded_instance_count() -> int:
	return int(_values.get("expanded_runtime_instances", 0))


func continuous_particle_capacity() -> int:
	return int(_values.get("continuous_particle_capacity", 0))


func particle_workload_envelope() -> int:
	return int(_values.get("particle_workload_envelope", 0))


func trail_max_point_capacity() -> int:
	return int(_values.get("trail_point_capacity", 0))


func transparent_renderer_instance_count() -> int:
	return int(_values.get("transparent_renderer_instances", 0))


func scenario() -> RefCounted:
	return _scenario


func _new_values() -> Dictionary:
	return {
		"expanded_runtime_instances": 0,
		"continuous_particle_capacity": 0,
		"particle_workload_envelope": 0,
		"trail_point_capacity": 0,
		"transparent_renderer_instances": 0
	}


func _value_for_budget(budget: RefCounted, key: String) -> int:
	match key:
		"expanded_runtime_instances":
			return budget.expanded_instance_count()
		"continuous_particle_capacity":
			return budget.continuous_particle_capacity()
		"particle_workload_envelope":
			return budget.particle_workload_envelope()
		"trail_point_capacity":
			return budget.trail_max_point_capacity()
		"transparent_renderer_instances":
			return budget.transparent_renderer_instance_count()
	return 0
