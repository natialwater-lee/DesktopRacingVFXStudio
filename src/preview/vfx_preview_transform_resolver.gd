class_name VfxPreviewTransformResolver
extends RefCounted


static func reference_draw_size(source_size: Vector2i, effective_game_scale: Vector2, view_zoom: float) -> Vector2:
	return Vector2(float(source_size.x), float(source_size.y)) * effective_game_scale * view_zoom


static func edit_content_size(fixed_content_bounds: Vector2, viewport_size: Vector2, padding: float) -> Vector2:
	var padded_bounds := fixed_content_bounds + Vector2.ONE * padding * 2.0
	return Vector2(maxf(padded_bounds.x, viewport_size.x), maxf(padded_bounds.y, viewport_size.y))


static func stage_center(content_size: Vector2) -> Vector2:
	return content_size * 0.5


static func project_source_local(source_local: Vector2, stage_center: Vector2, vehicle_translation_source: Vector2, vehicle_rotation_degrees: float, effective_game_scale: Vector2, view_zoom: float) -> Vector2:
	var scaled := Vector2(source_local.x * effective_game_scale.x * view_zoom, source_local.y * effective_game_scale.y * view_zoom)
	var translation_scaled := Vector2(vehicle_translation_source.x * effective_game_scale.x * view_zoom, vehicle_translation_source.y * effective_game_scale.y * view_zoom)
	return stage_center + translation_scaled + scaled.rotated(deg_to_rad(vehicle_rotation_degrees))


static func inverse_project_source_local(canvas_position: Vector2, stage_center: Vector2, vehicle_translation_source: Vector2, vehicle_rotation_degrees: float, effective_game_scale: Vector2, view_zoom: float) -> Vector2:
	var translation_scaled := Vector2(vehicle_translation_source.x * effective_game_scale.x * view_zoom, vehicle_translation_source.y * effective_game_scale.y * view_zoom)
	var rotated_back := (canvas_position - stage_center - translation_scaled).rotated(-deg_to_rad(vehicle_rotation_degrees))
	return Vector2(rotated_back.x / (effective_game_scale.x * view_zoom), rotated_back.y / (effective_game_scale.y * view_zoom))
