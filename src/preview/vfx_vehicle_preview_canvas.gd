class_name VfxVehiclePreviewCanvas
extends Control

const VfxPreviewTransformResolverModel := preload("res://src/preview/vfx_preview_transform_resolver.gd")
const VfxPreviewPlaneHostsModel := preload("res://src/preview/rendering/vfx_preview_plane_hosts.gd")
const EDIT_CONTENT_PADDING := 24.0

signal anchor_selected(anchor_name: String)
signal anchor_dragged(anchor_name: String, source_position: Vector2)

var _shared_state: RefCounted
var _view_zoom := 1.0
var _interactive := false
var _reference_texture: Texture2D
var _reference_size := Vector2i.ZERO
var _future_vfx_host: Node2D
var _plane_hosts: Dictionary = {}
var _drag_anchor := ""
var _scroll_center_queued := false


func _ready() -> void:
	clip_contents = true
	_future_vfx_host = Node2D.new()
	_future_vfx_host.name = "FutureVfxHost"
	add_child(_future_vfx_host)
	_plane_hosts = VfxPreviewPlaneHostsModel.ensure(self, _future_vfx_host)
	_apply_input_policy()
	_connect_edit_viewport()
	_refresh()


func set_shared_state(shared_state: RefCounted) -> void:
	if _shared_state != null and _shared_state.changed.is_connected(_on_state_changed):
		_shared_state.changed.disconnect(_on_state_changed)
	_shared_state = shared_state
	if _shared_state != null and not _shared_state.changed.is_connected(_on_state_changed):
		_shared_state.changed.connect(_on_state_changed)
	_refresh()
	_request_scroll_center()


func set_view_zoom(view_zoom_value: float) -> void:
	_view_zoom = view_zoom_value
	_refresh()
	_request_scroll_center()


func view_zoom() -> float:
	return _view_zoom


func set_interactive(interactive: bool) -> void:
	_interactive = interactive
	_apply_input_policy()
	_connect_edit_viewport()
	_refresh()
	_request_scroll_center()


func is_interactive() -> bool:
	return _interactive


func get_future_vfx_host() -> Node2D:
	return _future_vfx_host


func shared_state() -> RefCounted:
	return _shared_state


func render_plane_host(render_plane: String, effective_space: String) -> Node2D:
	if effective_space == "VEHICLE_FOLLOW_WORLD_TRAIL":
		return _plane_hosts.get("under_follow_world") if render_plane == "UNDER_VEHICLE" else _plane_hosts.get("over_follow_world")
	match render_plane:
		"UNDER_VEHICLE":
			return _plane_hosts.get("under_local")
		"OVER_VEHICLE":
			return _plane_hosts.get("over_local")
		"WORLD":
			return _plane_hosts.get("world")
	return null


func reference_size() -> Vector2i:
	return _reference_size


func set_equipment_visual(texture: Texture2D, equipment_position: Vector2, equipment_scale: float, over_vehicle: bool) -> void:
	var vehicle_art: Node = _plane_hosts.get("vehicle_art")
	if vehicle_art != null and vehicle_art.has_method("set_equipment"):
		vehicle_art.set_equipment(texture, equipment_position, equipment_scale, over_vehicle)


func project_anchor_position(anchor_name: String, additional_offset: Vector2 = Vector2.ZERO) -> Variant:
	return _project_anchor(anchor_name, additional_offset)


func layer_anchor_names() -> Array[String]:
	return _layer_anchor_names()


func request_scroll_center() -> void:
	_request_scroll_center()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh()
		_request_scroll_center()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _background_color())


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
	var source_position: Variant = VfxPreviewTransformResolverModel.inverse_project_source_local(canvas_position, _stage_center(), _shared_state.vehicle_translation_source(), _shared_state.vehicle_rotation_degrees(), scale_result.value, _view_zoom)
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


func _on_edit_viewport_resized() -> void:
	_refresh()
	_request_scroll_center()


func _refresh() -> void:
	_load_reference_texture()
	_update_future_vfx_host()
	_update_edit_content_size()
	var overlay: Node = _plane_hosts.get("overlay")
	if overlay != null and overlay.has_method("refresh"):
		overlay.refresh()
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
	var stage_root := _plane_hosts.get("stage_root") as Node2D
	if stage_root != null:
		stage_root.position = _stage_center()
		stage_root.scale = Vector2.ONE * _view_zoom
	_future_vfx_host.position = Vector2(_shared_state.vehicle_translation_source().x * scale_result.value.x, _shared_state.vehicle_translation_source().y * scale_result.value.y)
	_future_vfx_host.rotation = deg_to_rad(_shared_state.vehicle_rotation_degrees())
	_future_vfx_host.scale = scale_result.value
	var vehicle_art: Node = _plane_hosts.get("vehicle_art")
	if vehicle_art != null and vehicle_art.has_method("set_reference"):
		vehicle_art.set_reference(_reference_texture, _reference_size)


func _update_edit_content_size() -> void:
	if not _interactive or _shared_state == null or _reference_size == Vector2i.ZERO:
		return
	var scale_result: VfxResult = _shared_state.effective_game_scale()
	if not scale_result.success:
		return
	var fixed_bounds: Vector2 = _edit_fixed_content_bounds(scale_result.value)
	custom_minimum_size = VfxPreviewTransformResolverModel.edit_content_size(fixed_bounds, _edit_viewport_size(), EDIT_CONTENT_PADDING)


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
	return VfxPreviewTransformResolverModel.project_source_local(source_position + additional_offset, _stage_center(), _shared_state.vehicle_translation_source(), _shared_state.vehicle_rotation_degrees(), scale_result.value, _view_zoom)


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
	return VfxPreviewTransformResolverModel.project_source_local(Vector2.ZERO, _stage_center(), _shared_state.vehicle_translation_source(), _shared_state.vehicle_rotation_degrees(), scale, _view_zoom) if _shared_state != null else _stage_center()


func _stage_center() -> Vector2:
	return VfxPreviewTransformResolverModel.stage_center(size)


func _edit_fixed_content_bounds(scale: Vector2) -> Vector2:
	var draw_size: Vector2 = VfxPreviewTransformResolverModel.reference_draw_size(_reference_size, scale, _view_zoom)
	var rotation_radians := deg_to_rad(_shared_state.vehicle_rotation_degrees()) if _shared_state != null else 0.0
	var half_size := draw_size * 0.5
	var max_extent := Vector2(abs(cos(rotation_radians)) * half_size.x + abs(sin(rotation_radians)) * half_size.y, abs(sin(rotation_radians)) * half_size.x + abs(cos(rotation_radians)) * half_size.y)
	var anchors: Variant = _shared_state.profile_data().get("anchors") if _shared_state != null else {}
	if anchors is Dictionary:
		for anchor_name in anchors:
			var source_position: Variant = _anchor_source_position(str(anchor_name))
			if source_position != null:
				max_extent = _expanded_extent(max_extent, source_position, scale, rotation_radians)
	var context: RefCounted = _layer_context()
	if context != null and context.effective_space() == "VEHICLE_LOCAL":
		for anchor_name in context.anchor_names():
			var ghost_source_position: Variant = _anchor_source_position(anchor_name)
			if ghost_source_position != null:
				max_extent = _expanded_extent(max_extent, ghost_source_position + context.transform_offset(), scale, rotation_radians)
	return max_extent * 2.0


func _expanded_extent(current_extent: Vector2, source_position: Vector2, scale: Vector2, rotation_radians: float) -> Vector2:
	var scaled_position := Vector2(source_position.x * scale.x * _view_zoom, source_position.y * scale.y * _view_zoom).rotated(rotation_radians)
	return Vector2(maxf(current_extent.x, abs(scaled_position.x)), maxf(current_extent.y, abs(scaled_position.y)))


func _edit_viewport_size() -> Vector2:
	var scroll := get_parent() as ScrollContainer
	return scroll.size if scroll != null else size


func _connect_edit_viewport() -> void:
	if not _interactive:
		return
	var scroll := get_parent() as ScrollContainer
	if scroll != null and not scroll.resized.is_connected(_on_edit_viewport_resized):
		scroll.resized.connect(_on_edit_viewport_resized)


func _request_scroll_center() -> void:
	if not _interactive or not is_inside_tree() or _scroll_center_queued:
		return
	_scroll_center_queued = true
	call_deferred("_center_edit_scroll")


func _center_edit_scroll() -> void:
	_scroll_center_queued = false
	var scroll := get_parent() as ScrollContainer
	if scroll == null:
		return
	var stage := _stage_center()
	scroll.scroll_horizontal = maxi(0, int(round(stage.x - scroll.size.x * 0.5)))
	scroll.scroll_vertical = maxi(0, int(round(stage.y - scroll.size.y * 0.5)))


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
