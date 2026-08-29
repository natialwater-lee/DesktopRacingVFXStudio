class_name VfxPerformanceStressStage
extends Control

const VfxPreviewGameScaleModel := preload("res://src/preview/vfx_preview_game_scale.gd")
const VfxStressVehicleSlotModel := preload("res://src/preview/performance/vfx_stress_vehicle_slot.gd")

const GRID_COLUMNS := 5
const GRID_SPACING := Vector2(96.0, 96.0)

var _registry: RefCounted
var _factory: RefCounted
var _asset_resolver: RefCounted
var _vehicles: Array[Node2D] = []
var _vfx_enabled := false


func _init(registry: RefCounted, factory: RefCounted, asset_resolver: RefCounted) -> void:
	_registry = registry
	_factory = factory
	_asset_resolver = asset_resolver


func prepare(scenario: RefCounted, slot_plans: Array, profile_data: Dictionary, game_scale_contract: Dictionary, track_scale: float = 1.0) -> VfxResult:
	_clear_stage()
	if scenario == null or scenario.scope_name() != "VEHICLE_STRESS":
		return VfxResult.failure([VfxIssue.new("PERFORMANCE_CONFIGURATION", "stress_scope", "Phase 4 Stress Stage supports VEHICLE_STRESS only.")])
	var scale_result: VfxResult = VfxPreviewGameScaleModel.effective_scale(game_scale_contract, track_scale)
	if not scale_result.success:
		return scale_result
	var issues: Array[VfxIssue] = []
	for index in scenario.vehicle_count():
		var slot := VfxStressVehicleSlotModel.new(_registry, _factory, _asset_resolver)
		slot.name = "StressVehicle_%02d" % index
		slot.position = _grid_position(index, scenario.vehicle_count())
		add_child(slot)
		issues.append_array(slot.configure(_slot_subset(slot_plans, scenario.slots_per_vehicle()), profile_data, scale_result.value, scenario.workload_type()))
		_vehicles.append(slot)
	custom_minimum_size = _grid_extent(scenario.vehicle_count())
	_vfx_enabled = false
	return VfxResult.with_issues(self, issues)


func set_vfx_enabled(enabled: bool) -> void:
	_vfx_enabled = enabled
	for vehicle in _vehicles:
		var slot: Variant = vehicle
		slot.set_vfx_enabled(enabled)


func reset_workload() -> void:
	set_vfx_enabled(_vfx_enabled)


func advance(delta_seconds: float) -> Dictionary:
	if not _vfx_enabled:
		return _empty_facts()
	var totals := _empty_facts()
	for vehicle in _vehicles:
		var slot: Variant = vehicle
		var facts: Dictionary = slot.advance(delta_seconds)
		for key in totals:
			totals[key] += int(facts.get(key, 0))
	return totals


func vehicle_count() -> int:
	return _vehicles.size()


func runtime_slot_count() -> int:
	var count := 0
	for vehicle in _vehicles:
		var slot: Variant = vehicle
		count += slot.runtime_slot_count()
	return count


func vehicle_scales() -> Array:
	var result: Array = []
	for vehicle in _vehicles:
		var slot: Variant = vehicle
		result.append(slot.effective_game_scale())
	return result


func vehicle_node_ids() -> Array:
	var result: Array = []
	for vehicle in _vehicles:
		result.append(vehicle.get_instance_id())
	return result


func _slot_subset(slot_plans: Array, slots_per_vehicle: int) -> Array:
	var result: Array = []
	for index in mini(slot_plans.size(), slots_per_vehicle):
		result.append(slot_plans[index])
	return result


func _grid_position(index: int, vehicle_count: int) -> Vector2:
	var columns := mini(GRID_COLUMNS, vehicle_count)
	var rows := int(ceil(float(vehicle_count) / float(columns)))
	var column := index % columns
	var row := index / columns
	return Vector2(float(column) * GRID_SPACING.x, float(row) * GRID_SPACING.y) + Vector2(GRID_SPACING.x * float(columns - 1), GRID_SPACING.y * float(rows - 1)) * -0.5


func _grid_extent(vehicle_count: int) -> Vector2:
	var columns := mini(GRID_COLUMNS, maxi(vehicle_count, 1))
	var rows := int(ceil(float(maxi(vehicle_count, 1)) / float(columns)))
	return Vector2(float(columns) * GRID_SPACING.x, float(rows) * GRID_SPACING.y)


func _clear_stage() -> void:
	for vehicle in _vehicles:
		if is_instance_valid(vehicle):
			vehicle.queue_free()
	_vehicles.clear()
	_vfx_enabled = false


func _empty_facts() -> Dictionary:
	return {
		"active_vfx_instances": 0,
		"active_layer_renderers": 0,
		"active_runtime_instances": 0,
		"packet_count": 0,
		"alive_particle_count": 0,
		"active_trail_point_count": 0,
		"active_ring_count": 0
	}
