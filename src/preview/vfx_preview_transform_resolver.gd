class_name VfxPreviewTransformResolver
extends RefCounted


static func reference_draw_size(source_size: Vector2i, effective_game_scale: Vector2, view_zoom: float) -> Vector2:
	return Vector2(float(source_size.x), float(source_size.y)) * effective_game_scale * view_zoom


static func project_source_local(source_local: Vector2, stage_center: Vector2, vehicle_translation: Vector2, vehicle_rotation_degrees: float, effective_game_scale: Vector2, view_zoom: float) -> Vector2:
	var scaled := Vector2(source_local.x * effective_game_scale.x * view_zoom, source_local.y * effective_game_scale.y * view_zoom)
	return stage_center + vehicle_translation + scaled.rotated(deg_to_rad(vehicle_rotation_degrees))


static func inverse_project_source_local(canvas_position: Vector2, stage_center: Vector2, vehicle_translation: Vector2, vehicle_rotation_degrees: float, effective_game_scale: Vector2, view_zoom: float) -> Vector2:
	var rotated_back := (canvas_position - stage_center - vehicle_translation).rotated(-deg_to_rad(vehicle_rotation_degrees))
	return Vector2(rotated_back.x / (effective_game_scale.x * view_zoom), rotated_back.y / (effective_game_scale.y * view_zoom))
