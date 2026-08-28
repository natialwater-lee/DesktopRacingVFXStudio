class_name VfxVehiclePreview
extends VBoxContainer

const VfxPreviewSharedStateModel := preload("res://src/preview/vfx_preview_shared_state.gd")
const VfxVehiclePreviewCanvasModel := preload("res://src/preview/vfx_vehicle_preview_canvas.gd")

var _shared_state: RefCounted = VfxPreviewSharedStateModel.new()
var _edit_zoom := 2.0


func _ready() -> void:
	_configure_canvases()


func set_shared_state(shared_state: RefCounted) -> void:
	_shared_state = shared_state if shared_state != null else VfxPreviewSharedStateModel.new()
	_configure_canvases()


func shared_state() -> RefCounted:
	return _shared_state


func set_edit_zoom(edit_zoom: float) -> void:
	if is_equal_approx(edit_zoom, 2.0) or is_equal_approx(edit_zoom, 4.0):
		_edit_zoom = edit_zoom
		var edit_canvas: Control = _edit_canvas()
		if edit_canvas != null:
			edit_canvas.set_view_zoom(_edit_zoom)


func edit_zoom() -> float:
	return _edit_zoom


func set_profile_data(profile_data: Dictionary) -> void:
	_shared_state.set_profile_data(profile_data)


func get_future_vfx_host(canvas_name: String) -> Node2D:
	var canvas: Control = _edit_canvas() if canvas_name == "EDIT" else _game_canvas() if canvas_name == "GAME" else null
	return canvas.get_future_vfx_host() if canvas != null else null


func _configure_canvases() -> void:
	var edit_canvas: Control = _edit_canvas()
	var game_canvas: Control = _game_canvas()
	if edit_canvas != null:
		edit_canvas.set_interactive(true)
		edit_canvas.set_view_zoom(_edit_zoom)
		edit_canvas.set_shared_state(_shared_state)
	if game_canvas != null:
		game_canvas.set_interactive(false)
		game_canvas.set_view_zoom(1.0)
		game_canvas.set_shared_state(_shared_state)


func _edit_canvas() -> Control:
	return get_node_or_null("PreviewSurface/EditScroll/EditCanvas") as Control


func _game_canvas() -> Control:
	return get_node_or_null("PreviewSurface/GameSizeInset/GameInsetContents/GameCanvas") as Control
