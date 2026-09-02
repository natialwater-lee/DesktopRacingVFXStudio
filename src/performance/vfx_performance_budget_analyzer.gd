class_name VfxPerformanceBudgetAnalyzer
extends RefCounted

const VfxPreviewInstanceResolverModel := preload("res://src/preview/rendering/vfx_preview_instance_resolver.gd")
const VfxAuthoringBudgetModel := preload("res://src/performance/vfx_authoring_budget.gd")
const VfxWorkloadBudgetModel := preload("res://src/performance/vfx_workload_budget.gd")
const VfxPresetPerformanceBudgetModel := preload("res://src/performance/vfx_preset_performance_budget.gd")

var _registry: RefCounted


func _init(registry: RefCounted) -> void:
	_registry = registry


func analyze(plan: RefCounted, profile_data: Dictionary, workload_type: String) -> VfxResult:
	if plan == null:
		return _failure("performance_budget_plan", "Performance Budget requires a Render Plan.")
	var phases := _workload_phases(plan, workload_type)
	if phases.is_empty():
		return _failure("performance_budget_workload", "Workload %s is incompatible with this Plan lifecycle." % workload_type)
	var resolved: VfxResult = VfxPreviewInstanceResolverModel.new(_registry).resolve(plan, profile_data)
	if not resolved.success:
		return resolved
	var authoring_values := _new_values()
	authoring_values["source_layer_count"] = plan.phase_layer_count()
	authoring_values["included_layer_count"] = plan.phase_layer_count()
	for phase in plan.phase_plans():
		for layer in phase.layer_specs():
			if layer.is_enabled():
				authoring_values["enabled_layer_count"] += 1
	for instance in resolved.value:
		_accumulate_instance(authoring_values, instance)
	var workload_values := _new_values()
	for instance in resolved.value:
		if phases.has(instance.phase_name()) and instance.layer_spec().is_enabled():
			_accumulate_instance(workload_values, instance)
	var authoring := VfxAuthoringBudgetModel.new(authoring_values)
	var workload := VfxWorkloadBudgetModel.new(workload_type, workload_values)
	return VfxResult.with_issues(VfxPresetPerformanceBudgetModel.new(authoring, workload, workload_type), resolved.issues)


func _workload_phases(plan: RefCounted, workload_type: String) -> Array[String]:
	if workload_type == "STEADY_LOOP" and plan.lifecycle_mode() == "START_LOOP_END" and plan.phase_named("loop") != null:
		return ["loop"]
	if workload_type == "REPEATED_ONE_SHOT" and plan.lifecycle_mode() == "ONE_SHOT" and plan.phase_named("one_shot") != null:
		return ["one_shot"]
	return []


func _new_values() -> Dictionary:
	return {
		"source_layer_count": 0,
		"enabled_layer_count": 0,
		"included_layer_count": 0,
		"expanded_instance_count": 0,
		"particle_layer_count": 0,
		"continuous_particle_capacity": 0,
		"burst_particle_maximum": 0,
		"trail_instance_count": 0,
		"trail_max_point_capacity": 0,
		"ring_layer_count": 0,
		"ring_active_potential": 0,
		"glow_instance_count": 0,
		"persistent_textured_sprite_instance_count": 0,
		"shield_instance_count": 0,
		"texture_asset_ids": [],
		"texture_backed_renderer_instance_count": 0,
		"transparent_renderer_instance_count": 0,
		"render_plane_instance_counts": {}
	}


func _accumulate_instance(values: Dictionary, instance: RefCounted) -> void:
	var layer: RefCounted = instance.layer_spec()
	var parameters: Dictionary = layer.parameters()
	values["expanded_instance_count"] += 1
	values["transparent_renderer_instance_count"] += 1
	var plane: String = layer.render_plane()
	values["render_plane_instance_counts"][plane] = int(values["render_plane_instance_counts"].get(plane, 0)) + 1
	match layer.layer_type():
		"PARTICLE":
			values["particle_layer_count"] += 1
			if parameters.get("emission_mode") == "CONTINUOUS":
				values["continuous_particle_capacity"] += int(parameters.get("max_particles", 0))
			elif parameters.get("emission_mode") == "BURST":
				values["burst_particle_maximum"] += int(parameters.get("burst_count", 0))
		"TRAIL":
			values["trail_instance_count"] += 1
			values["trail_max_point_capacity"] += int(parameters.get("max_points", 0))
		"RING":
			values["ring_layer_count"] += 1
			values["ring_active_potential"] += _ring_potential(parameters)
		"GLOW":
			values["glow_instance_count"] += 1
		"TEXTURED_SPRITE":
			values["persistent_textured_sprite_instance_count"] += 1
		"SHIELD":
			values["shield_instance_count"] += 1
	var asset_id := _asset_id(parameters)
	if not asset_id.is_empty():
		values["texture_backed_renderer_instance_count"] += 1
		if not values["texture_asset_ids"].has(asset_id):
			values["texture_asset_ids"].append(asset_id)


func _ring_potential(parameters: Dictionary) -> int:
	var repeat_interval := float(parameters.get("repeat_interval_seconds", 0.0))
	if repeat_interval <= 0.0:
		return 1
	return maxi(1, int(ceil(float(parameters.get("duration_seconds", 0.0)) / repeat_interval)))


func _asset_id(parameters: Dictionary) -> String:
	if parameters.has("sprite_asset_ref"):
		return str(parameters.get("sprite_asset_ref"))
	if parameters.has("texture_asset_ref"):
		return str(parameters.get("texture_asset_ref"))
	return ""


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("PERFORMANCE_CONFIGURATION", code, message)])
