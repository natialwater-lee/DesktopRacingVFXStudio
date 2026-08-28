class_name VfxPreviewCoordinateResolver
extends RefCounted


static func canonical_origin(instance: RefCounted, frame_context: Dictionary) -> Vector2:
	var layer_spec: RefCounted = instance.layer_spec()
	var offset := _vector2_from(layer_spec.transform().get("offset", [0.0, 0.0]))
	var source_origin: Vector2 = instance.anchor_source_position() + offset
	match layer_spec.effective_space():
		"VEHICLE_FOLLOW_WORLD_TRAIL":
			return vehicle_source_to_world(source_origin, frame_context)
		"WORLD_AREA", "SCREEN_UI":
			return offset
		_:
			return source_origin


static func vehicle_source_to_world(source_position: Vector2, frame_context: Dictionary) -> Vector2:
	var translation := _vector2_from(frame_context.get("vehicle_translation_source", [0.0, 0.0]))
	var scale := _vector2_from(frame_context.get("effective_game_scale", [1.0, 1.0]))
	var rotation_degrees: float = float(frame_context.get("vehicle_rotation_degrees", 0.0))
	var scaled_source := Vector2(source_position.x * scale.x, source_position.y * scale.y)
	var scaled_translation := Vector2(translation.x * scale.x, translation.y * scale.y)
	return scaled_translation + scaled_source.rotated(deg_to_rad(rotation_degrees))


static func canonical_vector(instance: RefCounted, source_vector: Vector2, frame_context: Dictionary) -> Vector2:
	var layer_spec: RefCounted = instance.layer_spec()
	var transformed := layer_vector(layer_spec.transform(), source_vector)
	if layer_spec.effective_space() != "VEHICLE_FOLLOW_WORLD_TRAIL":
		return transformed
	var scale := _vector2_from(frame_context.get("effective_game_scale", [1.0, 1.0]))
	var rotation_degrees: float = float(frame_context.get("vehicle_rotation_degrees", 0.0))
	return Vector2(transformed.x * scale.x, transformed.y * scale.y).rotated(deg_to_rad(rotation_degrees))


static func geometry_scale(instance: RefCounted, frame_context: Dictionary) -> Vector2:
	var layer_scale := _vector2_from(instance.layer_spec().transform().get("scale", [1.0, 1.0]))
	if instance.layer_spec().effective_space() != "VEHICLE_FOLLOW_WORLD_TRAIL":
		return layer_scale
	var effective_scale := _vector2_from(frame_context.get("effective_game_scale", [1.0, 1.0]))
	return Vector2(layer_scale.x * effective_scale.x, layer_scale.y * effective_scale.y)


static func geometry_rotation_degrees(instance: RefCounted, frame_context: Dictionary) -> float:
	var layer_rotation := float(instance.layer_spec().transform().get("rotation_degrees", 0.0))
	return layer_rotation + float(frame_context.get("vehicle_rotation_degrees", 0.0)) if instance.layer_spec().effective_space() == "VEHICLE_FOLLOW_WORLD_TRAIL" else layer_rotation


static func layer_vector(transform: Dictionary, source_vector: Vector2) -> Vector2:
	var scale := _vector2_from(transform.get("scale", [1.0, 1.0]))
	var rotation_degrees: float = float(transform.get("rotation_degrees", 0.0))
	return Vector2(source_vector.x * scale.x, source_vector.y * scale.y).rotated(deg_to_rad(rotation_degrees))


static func _vector2_from(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
