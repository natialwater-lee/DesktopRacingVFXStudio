class_name VfxVehiclePreviewCanvas
extends Control

const VfxPreviewTransformResolverModel := preload("res://src/preview/vfx_preview_transform_resolver.gd")

var _shared_state: RefCounted
var _view_zoom := 1.0
var _interactive := false
var _reference_texture: Texture2D
var _reference_size := Vector2i.ZERO
var _future_vfx_host: Node2D


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
	var draw_center: Vector2 = size * 0.5 + _shared_state.vehicle_translation()
	var draw_transform := Transform2D(deg_to_rad(_shared_state.vehicle_rotation_degrees()), draw_center)
	draw_set_transform_matrix(draw_transform)
	draw_texture_rect(_reference_texture, Rect2(-draw_size * 0.5, draw_size), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


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
	_future_vfx_host.position = size * 0.5 + _shared_state.vehicle_translation()
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


func _background_color() -> Color:
	if _shared_state == null:
		return Color("20242c")
	match _shared_state.background_mode():
		"LIGHT":
			return Color("e6e9ef")
		"TRACK_GRAY":
			return Color("555b63")
	return Color("20242c")
