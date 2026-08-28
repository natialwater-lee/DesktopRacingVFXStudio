class_name VfxVehiclePreviewCanvas
extends Control

const VfxPreviewTransformResolverModel := preload("res://src/preview/vfx_preview_transform_resolver.gd")

signal anchor_selected(anchor_name: String)
signal anchor_dragged(anchor_name: String, source_position: Vector2)

var _shared_state: RefCounted
var _view_zoom := 1.0
var _interactive := false
var _reference_texture: Texture2D
var _reference_size := Vector2i.ZERO
var _future_vfx_host: Node2D
var _drag_anchor := ""


func _ready() -> void:
	clip_contents = true
	_future_vfx_host = Node2D.new()
	_future_vfx_host.name = "FutureVfxHost"
	add_child(_future_vfx_host)
	_apply_input_policy()
	_refresh()


func set_shared_state(shared_state: RefCounted) -> void:
	if _shared_state != null and _shared_state.changed.is_connected(_on_state_changed):
		_shared_state.changed.disconnect(_on_state_changed)
	_shared_state = shared_state
	if _shared_state != null and not _shared_state.changed.is_connected(_on_state_changed):
		_shared_state.changed.connect(_on_state_changed)
	_refresh()


func set_view_zoom(view_zoom_value: float) -> void:
	_view_zoom = view_zoom_value
	_refresh()


func view_zoom() -> float:
	return _view_zoom


func set_interactive(interactive: bool) -> void:
	_interactive = interactive
	_apply_input_policy()
	_refresh()


func is_interactive() -> bool:
	return _interactive


func get_future_vfx_host() -> Node2D:
	return _future_vfx_host


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _background_color())
	if _reference_texture == null or _reference_size == Vector2i.ZERO or _shared_state == null:
		return
	var scale_result: VfxResult = _shared_state.effective_game_scale()
	if not scale_result.success:
		return
	var draw_size: Vector2 = VfxPreviewTransformResolverModel.reference_draw_size(_reference_size, scale_result.value, _view_zoom)
	var draw_center: Vector2 = _vehicle_stage_position(scale_result.value)
	var draw_transform := Transform2D(deg_to_rad(_shared_state.vehicle_rotation_degrees()), draw_center)
	draw_set_transform_matrix(draw_transform)
	draw_texture_rect(_reference_texture, Rect2(-draw_size * 0.5, draw_size), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_anchor_overlay(scale_result.value)


func resolved_layer_anchor_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var context: RefCounted = _layer_context()
	if context == null:
		return positions
	for anchor_name in context.anchor_names():
		var position: Variant = _project_anchor(str(anchor_name), Vector2.ZERO)
		if position != null:
			positions.append(position)
	return positions


func ghost_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var context: RefCounted = _layer_context()
	if context == null or context.effective_space() != "VEHICLE_LOCAL":
		return positions
	for anchor_name in context.anchor_names():
		var position: Variant = _project_anchor(str(anchor_name), context.transform_offset())
		if position != null:
			positions.append(position)
	return positions


func visible_ghost_positions() -> Array[Vector2]:
	return ghost_positions() if _interactive else []


func visible_anchor_labels() -> Array[String]:
	var labels: Array[String] = []
	if not _interactive or _shared_state == null or not _shared_state.show_anchors():
		return labels
	var anchors: Variant = _shared_state.profile_data().get("anchors")
	if anchors is Dictionary:
		for anchor_name in anchors:
			labels.append(str(anchor_name))
	return labels


func snapped_source_position(canvas_position: Vector2) -> Vector2:
	if _shared_state == null:
		return Vector2.ZERO
	var scale_result: VfxResult = _shared_state.effective_game_scale()
	if not scale_result.success:
		return Vector2.ZERO
	var source_position: Variant = VfxPreviewTransformResolverModel.inverse_project_source_local(canvas_position, size * 0.5, _shared_state.vehicle_translation_source(), _shared_state.vehicle_rotation_degrees(), scale_result.value, _view_zoom)
	return Vector2(round(source_position.x), round(source_position.y))


func _gui_input(event: InputEvent) -> void:
	if not _interactive or _shared_state == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_anchor = _nearest_anchor_name(event.position)
			if not _drag_anchor.is_empty():
				_shared_state.set_selected_profile_anchor(_drag_anchor)
				anchor_selected.emit(_drag_anchor)
		else:
			_drag_anchor = ""
	elif event is InputEventMouseMotion and not _drag_anchor.is_empty() and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		anchor_dragged.emit(_drag_anchor, snapped_source_position(event.position))


func _on_state_changed() -> void:
	_refresh()


func _refresh() -> void:
	_load_reference_texture()
	_update_future_vfx_host()
	_update_edit_content_size()
	queue_redraw()


func _load_reference_texture() -> void:
	_reference_texture = null
	_reference_size = Vector2i.ZERO
	if _shared_state == null:
		return
	var profile_data: Dictionary = _shared_state.profile_data()
	var reference_image: Variant = profile_data.get("reference_image")
	if not reference_image is Dictionary:
		return
	var reference_path: String = str(reference_image.get("path", ""))
	var loaded: Resource = load(reference_path) if not reference_path.is_empty() else null
	if loaded is Texture2D:
		_reference_texture = loaded
		_reference_size = Vector2i(_reference_texture.get_width(), _reference_texture.get_height())
	elif reference_image.get("expected_source_size_px") is Array and reference_image["expected_source_size_px"].size() == 2:
		_reference_size = Vector2i(int(reference_image["expected_source_size_px"][0]), int(reference_image["expected_source_size_px"][1]))


func _update_future_vfx_host() -> void:
	if _future_vfx_host == null or _shared_state == null:
		return
	var scale_result: VfxResult = _shared_state.effective_game_scale()
	if not scale_result.success:
		return
	_future_vfx_host.position = _vehicle_stage_position(scale_result.value)
	_future_vfx_host.rotation = deg_to_rad(_shared_state.vehicle_rotation_degrees())
	_future_vfx_host.scale = scale_result.value * _view_zoom


func _update_edit_content_size() -> void:
	if not _interactive or _shared_state == null or _reference_size == Vector2i.ZERO:
		return
	var scale_result: VfxResult = _shared_state.effective_game_scale()
	if not scale_result.success:
		return
	var draw_size: Vector2 = VfxPreviewTransformResolverModel.reference_draw_size(_reference_size, scale_result.value, _view_zoom)
	custom_minimum_size = Vector2(maxf(160.0, draw_size.x + 32.0), maxf(160.0, draw_size.y + 32.0))


func _apply_input_policy() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if _interactive else Control.MOUSE_FILTER_IGNORE


func _draw_anchor_overlay(scale: Vector2) -> void:
	if _shared_state == null:
		return
	var ghost_color := Color("ff66cf")
	for ghost_position in visible_ghost_positions():
		draw_rect(Rect2(ghost_position - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), ghost_color, false, 1.5)
	var layer_positions := resolved_layer_anchor_positions()
	if _interactive and _shared_state.show_anchors():
		var anchors: Variant = _shared_state.profile_data().get("anchors")
		if anchors is Dictionary:
			for anchor_name in anchors:
				var position: Variant = _project_anchor(str(anchor_name), Vector2.ZERO)
				if position == null:
					continue
				var is_layer_anchor := _layer_anchor_names().has(str(anchor_name))
				var is_selected: bool = _shared_state.selected_profile_anchor() == str(anchor_name)
				var marker_color := Color("ffaf4f") if is_selected else Color("55d6ff") if is_layer_anchor else Color("b8c1cd")
				draw_circle(position, 3.0, marker_color)
				draw_string(ThemeDB.fallback_font, position + Vector2(5, -3), _short_label(str(anchor_name)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, marker_color)
	else:
		for position in layer_positions:
			draw_circle(position, 1.5, Color("55d6ff"))


func _layer_anchor_names() -> Array[String]:
	var names: Array[String] = []
	var context: RefCounted = _layer_context()
	if context != null:
		names = context.anchor_names()
	return names


func _layer_context() -> RefCounted:
	return _shared_state.layer_context() if _shared_state != null else null


func _project_anchor(anchor_name: String, additional_offset: Vector2) -> Variant:
	var source_position: Variant = _anchor_source_position(anchor_name)
	if source_position == null or _shared_state == null:
		return null
	var scale_result: VfxResult = _shared_state.effective_game_scale()
	if not scale_result.success:
		return null
	return VfxPreviewTransformResolverModel.project_source_local(source_position + additional_offset, size * 0.5, _shared_state.vehicle_translation_source(), _shared_state.vehicle_rotation_degrees(), scale_result.value, _view_zoom)


func _anchor_source_position(anchor_name: String) -> Variant:
	if _shared_state == null:
		return null
	var anchors: Variant = _shared_state.profile_data().get("anchors")
	if not anchors is Dictionary or not anchors.has(anchor_name):
		return null
	var coordinate: Variant = anchors[anchor_name]
	if not coordinate is Array or coordinate.size() != 2:
		return null
	return Vector2(float(coordinate[0]), float(coordinate[1]))


func _nearest_anchor_name(canvas_position: Vector2) -> String:
	var nearest_name := ""
	var nearest_distance := 10.0
	for anchor_name in visible_anchor_labels():
		var anchor_position: Variant = _project_anchor(anchor_name, Vector2.ZERO)
		if anchor_position == null:
			continue
		var distance := canvas_position.distance_to(anchor_position)
		if distance <= nearest_distance:
			nearest_name = anchor_name
			nearest_distance = distance
	return nearest_name


func _vehicle_stage_position(scale: Vector2) -> Vector2:
	return VfxPreviewTransformResolverModel.project_source_local(Vector2.ZERO, size * 0.5, _shared_state.vehicle_translation_source(), _shared_state.vehicle_rotation_degrees(), scale, _view_zoom) if _shared_state != null else size * 0.5


func _short_label(anchor_name: String) -> String:
	var segments := anchor_name.split("_")
	var short_label := ""
	for segment in segments:
		short_label += segment.left(1)
	return short_label


func _background_color() -> Color:
	if _shared_state == null:
		return Color("20242c")
	match _shared_state.background_mode():
		"LIGHT":
			return Color("e6e9ef")
		"TRACK_GRAY":
			return Color("555b63")
	return Color("20242c")
