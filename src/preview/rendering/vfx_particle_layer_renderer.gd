class_name VfxParticleLayerRenderer
extends "res://src/preview/rendering/vfx_preview_layer_renderer.gd"

const VfxParticleDirectionModel := preload("res://src/preview/rendering/vfx_particle_direction.gd")

var _particles: Array[Dictionary] = []
var _emission_accumulator := 0.0
var _random := RandomNumberGenerator.new()


func restart(frame_context: Dictionary) -> void:
	super.restart(frame_context)
	_particles.clear()
	_emission_accumulator = 0.0
	_random.seed = _stable_seed(frame_context)
	var parameters := _parameters()
	if parameters.get("emission_mode") == "BURST":
		for _index in int(parameters.get("burst_count", 0)):
			_spawn_particle(frame_context)
	_refresh_packets(frame_context)


func advance(delta_seconds: float, frame_context: Dictionary) -> void:
	_update_particles(delta_seconds)
	if _source_active and _parameters().get("emission_mode") == "CONTINUOUS":
		_emission_accumulator += delta_seconds * float(_parameters().get("emission_rate_per_second", 0.0))
		while _emission_accumulator >= 1.0 and _particles.size() < int(_parameters().get("max_particles", 0)):
			_spawn_particle(frame_context)
			_emission_accumulator -= 1.0
		if _particles.size() >= int(_parameters().get("max_particles", 0)):
			_emission_accumulator = minf(_emission_accumulator, 1.0)
	_refresh_packets(frame_context)


func has_residual() -> bool:
	return not _particles.is_empty()


func clear() -> void:
	super.clear()
	_particles.clear()
	_emission_accumulator = 0.0


func _update_particles(delta_seconds: float) -> void:
	var lifetime_seconds: float = float(_parameters().get("lifetime_seconds", 0.001))
	var surviving: Array[Dictionary] = []
	for particle in _particles:
		var age: float = float(particle.get("age", 0.0)) + delta_seconds
		if age >= lifetime_seconds:
			continue
		var velocity: Vector2 = particle.get("velocity", Vector2.ZERO)
		var acceleration: Vector2 = particle.get("acceleration", Vector2.ZERO)
		particle["position"] = particle.get("position", Vector2.ZERO) + velocity * delta_seconds + acceleration * (0.5 * delta_seconds * delta_seconds)
		particle["velocity"] = velocity + acceleration * delta_seconds
		particle["rotation_degrees"] = float(particle.get("rotation_degrees", 0.0)) + float(particle.get("angular_velocity_degrees", 0.0)) * delta_seconds
		particle["age"] = age
		surviving.append(particle)
	_particles = surviving


func _spawn_particle(frame_context: Dictionary) -> void:
	var parameters := _parameters()
	var emitter: Dictionary = parameters.get("emitter", {}) if parameters.get("emitter", {}) is Dictionary else {}
	var emitter_offset := _sample_emitter(emitter)
	var direction_degrees: float = float(parameters.get("direction_degrees", 0.0)) + _random.randf_range(-float(parameters.get("spread_degrees", 0.0)) * 0.5, float(parameters.get("spread_degrees", 0.0)) * 0.5)
	var source_velocity := VfxParticleDirectionModel.from_degrees(direction_degrees) * _random.randf_range(float(parameters.get("speed_min", 0.0)), float(parameters.get("speed_max", 0.0)))
	var source_acceleration := _vector2_from(parameters.get("acceleration", [0.0, 0.0]))
	var position := VfxPreviewCoordinateResolverModel.canonical_origin(_instance, frame_context) + VfxPreviewCoordinateResolverModel.canonical_vector(_instance, emitter_offset, frame_context)
	var rotation_degrees: float = _random.randf_range(float(parameters.get("rotation_min_degrees", 0.0)), float(parameters.get("rotation_max_degrees", 0.0))) + float(_instance.layer_spec().transform().get("rotation_degrees", 0.0))
	if _instance.layer_spec().effective_space() == "VEHICLE_FOLLOW_WORLD_TRAIL":
		rotation_degrees += float(frame_context.get("vehicle_rotation_degrees", 0.0))
	_particles.append({
		"position": position,
		"velocity": VfxPreviewCoordinateResolverModel.canonical_vector(_instance, source_velocity, frame_context),
		"acceleration": VfxPreviewCoordinateResolverModel.canonical_vector(_instance, source_acceleration, frame_context),
		"rotation_degrees": rotation_degrees,
		"angular_velocity_degrees": _random.randf_range(float(parameters.get("angular_velocity_min_degrees_per_second", 0.0)), float(parameters.get("angular_velocity_max_degrees_per_second", 0.0))),
		"age": 0.0
	})


func _sample_emitter(emitter: Dictionary) -> Vector2:
	match emitter.get("shape", "POINT"):
		"CIRCLE":
			return Vector2.RIGHT.rotated(_random.randf_range(0.0, TAU)) * sqrt(_random.randf()) * float(emitter.get("radius", 0.0))
		"BOX":
			var size := _vector2_from(emitter.get("size", [0.0, 0.0]))
			return Vector2(_random.randf_range(-size.x * 0.5, size.x * 0.5), _random.randf_range(-size.y * 0.5, size.y * 0.5))
		"CONE":
			var half_angle: float = deg_to_rad(float(emitter.get("angle_degrees", 0.0)) * 0.5)
			return Vector2.RIGHT.rotated(_random.randf_range(-half_angle, half_angle)) * sqrt(_random.randf()) * float(emitter.get("radius", 0.0))
		"LINE":
			return Vector2(_random.randf_range(-float(emitter.get("length", 0.0)) * 0.5, float(emitter.get("length", 0.0)) * 0.5), 0.0)
	return Vector2.ZERO


func _refresh_packets(frame_context: Dictionary) -> void:
	_packets.clear()
	var parameters := _parameters()
	var lifetime_seconds: float = float(parameters.get("lifetime_seconds", 0.001))
	for particle in _particles:
		var packet := _packet_base(frame_context)
		var age_ratio: float = clampf(float(particle.get("age", 0.0)) / lifetime_seconds, 0.0, 1.0)
		packet["position"] = particle.get("position", Vector2.ZERO)
		packet["size"] = lerpf(float(parameters.get("size_start", 1.0)), float(parameters.get("size_end", 1.0)), age_ratio)
		packet["rotation_degrees"] = float(particle.get("rotation_degrees", 0.0))
		packet["color_rgba"] = parameters.get("color_rgba", [1.0, 1.0, 1.0, 1.0]).duplicate()
		packet["alpha"] = lerpf(float(parameters["alpha_start"]), float(parameters["alpha_end"]), age_ratio)
		_packets.append(packet)


func _stable_seed(frame_context: Dictionary) -> int:
	var key := "%s|%s|%d|%d" % [_instance.phase_name(), _instance.layer_spec().layer_id(), _instance.anchor_index(), int(frame_context.get("playback_generation", 0))]
	var seed := 17
	for index in key.length():
		seed = int((seed * 31 + key.unicode_at(index)) % 2147483647)
	return seed


func _vector2_from(value: Variant) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
