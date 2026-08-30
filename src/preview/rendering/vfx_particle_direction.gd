class_name VfxParticleDirection
extends RefCounted


static func from_degrees(direction_degrees: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(direction_degrees - 90.0))
