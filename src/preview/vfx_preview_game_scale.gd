class_name VfxPreviewGameScale
extends RefCounted


static func effective_scale(config: Dictionary, track_scale: float) -> VfxResult:
	if not (config.get("base_car_sprite_scale") is Array) or not (config.get("track_scales") is Array):
		return VfxResult.failure([VfxIssue.new("PREVIEW_SCALE", "PREVIEW_SCALE_CONFIG", "Preview game scale contract is incomplete.")])
	var base_values: Array = config["base_car_sprite_scale"]
	if base_values.size() != 2 or not _is_number(base_values[0]) or not _is_number(base_values[1]) or not _is_number(config.get("car_visual_scale")):
		return VfxResult.failure([VfxIssue.new("PREVIEW_SCALE", "PREVIEW_SCALE_CONFIG", "Preview game scale values must be numeric.")])
	if not _track_scale_allowed(config["track_scales"], track_scale):
		return VfxResult.failure([VfxIssue.new("PREVIEW_SCALE", "PREVIEW_TRACK_SCALE", "Selected Track Scale is not declared by the Preview contract.")])
	return VfxResult.ok(Vector2(float(base_values[0]), float(base_values[1])) * float(config["car_visual_scale"]) * track_scale)


static func _track_scale_allowed(track_scales: Array, track_scale: float) -> bool:
	for allowed in track_scales:
		if _is_number(allowed) and is_equal_approx(float(allowed), track_scale):
			return true
	return false


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
