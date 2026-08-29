class_name VfxAuthoringBudget
extends RefCounted

var _values: Dictionary


func _init(values: Dictionary = {}) -> void:
	_values = values.duplicate(true)


func source_layer_count() -> int:
	return int(_values.get("source_layer_count", 0))


func enabled_layer_count() -> int:
	return int(_values.get("enabled_layer_count", 0))


func included_layer_count() -> int:
	return int(_values.get("included_layer_count", 0))


func expanded_instance_count() -> int:
	return int(_values.get("expanded_instance_count", 0))


func particle_layer_count() -> int:
	return int(_values.get("particle_layer_count", 0))


func continuous_particle_capacity() -> int:
	return int(_values.get("continuous_particle_capacity", 0))


func burst_particle_maximum() -> int:
	return int(_values.get("burst_particle_maximum", 0))


func particle_workload_envelope() -> int:
	return continuous_particle_capacity() + burst_particle_maximum()


func trail_instance_count() -> int:
	return int(_values.get("trail_instance_count", 0))


func trail_max_point_capacity() -> int:
	return int(_values.get("trail_max_point_capacity", 0))


func ring_layer_count() -> int:
	return int(_values.get("ring_layer_count", 0))


func ring_active_potential() -> int:
	return int(_values.get("ring_active_potential", 0))


func glow_instance_count() -> int:
	return int(_values.get("glow_instance_count", 0))


func shield_instance_count() -> int:
	return int(_values.get("shield_instance_count", 0))


func texture_asset_ids() -> Array[String]:
	var result: Array[String] = []
	for value in _values.get("texture_asset_ids", []):
		result.append(str(value))
	return result


func texture_backed_renderer_instance_count() -> int:
	return int(_values.get("texture_backed_renderer_instance_count", 0))


func transparent_renderer_instance_count() -> int:
	return int(_values.get("transparent_renderer_instance_count", 0))


func render_plane_instance_counts() -> Dictionary:
	return _values.get("render_plane_instance_counts", {}).duplicate(true)
