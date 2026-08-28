class_name VfxVehiclePreview
extends VBoxContainer

const VfxPreviewSharedStateModel := preload("res://src/preview/vfx_preview_shared_state.gd")
const VfxVehiclePreviewCanvasModel := preload("res://src/preview/vfx_vehicle_preview_canvas.gd")
const VfxVehicleProfileEditSessionModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_edit_session.gd")

var _shared_state: RefCounted = VfxPreviewSharedStateModel.new()
var _profile_session: RefCounted
var _profile_repository: RefCounted
var _profile_documents_by_path: Dictionary = {}
var _edit_zoom := 2.0


func _ready() -> void:
	_configure_canvases()
	_configure_controls()


func set_shared_state(shared_state: RefCounted) -> void:
	_shared_state = shared_state if shared_state != null else VfxPreviewSharedStateModel.new()
	_configure_canvases()
	_rebuild_track_scales()


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
	_rebuild_anchor_controls()
	_request_edit_scroll_center()


func set_profile_edit_session(profile_session: RefCounted) -> void:
	_profile_session = profile_session
	if _profile_session != null:
		_shared_state.set_profile_data(_profile_session.working_copy())
	_rebuild_anchor_controls()
	_request_edit_scroll_center()


func set_profile_repository(profile_repository: RefCounted) -> void:
	_profile_repository = profile_repository


func set_profile_documents(profile_documents: Array) -> void:
	_profile_documents_by_path = {}
	for document in profile_documents:
		if document != null and not str(document.source_path).is_empty():
			_profile_documents_by_path[str(document.source_path)] = document
	if is_node_ready():
		_rebuild_profile_select()


func set_game_scale_contract(game_scale_contract: Dictionary) -> void:
	_shared_state.set_game_scale_contract(game_scale_contract)
	_rebuild_track_scales()


func set_layer_context(layer_context: RefCounted) -> void:
	_shared_state.set_layer_context(layer_context)
	var label := get_node_or_null("PreviewControls/LayerContext") as Label
	if label != null:
		label.text = "No Layer Selected" if layer_context == null else "%s | %s | %s" % [layer_context.layer_id, ", ".join(layer_context.anchor_names()), layer_context.effective_space()]
		label.tooltip_text = label.text


func _process(delta: float) -> void:
	if _shared_state == null:
		return
	var next_time: float = float(_shared_state.motion_time()) + delta
	match _shared_state.motion_mode():
		"ROTATE":
			_shared_state.set_motion("ROTATE", next_time, Vector2.ZERO, fmod(next_time * 45.0, 360.0))
		"SIMPLE_MOTION":
			_shared_state.set_motion("SIMPLE_MOTION", next_time, Vector2(sin(next_time * 0.9) * 160.0, 0.0), 0.0)
		_:
			_shared_state.set_motion("STATIC", next_time, Vector2.ZERO, 0.0)


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
	if edit_canvas != null and not edit_canvas.anchor_selected.is_connected(_on_canvas_anchor_selected):
		edit_canvas.anchor_selected.connect(_on_canvas_anchor_selected)
	if edit_canvas != null and not edit_canvas.anchor_dragged.is_connected(_on_canvas_anchor_dragged):
		edit_canvas.anchor_dragged.connect(_on_canvas_anchor_dragged)


func _configure_controls() -> void:
	var profile_select := _profile_select()
	if profile_select != null and not profile_select.item_selected.is_connected(_on_profile_select_changed):
		profile_select.item_selected.connect(_on_profile_select_changed)
	var background_select := get_node_or_null("PreviewControls/DisplayRow/BackgroundSelect") as OptionButton
	if background_select != null and background_select.item_count == 0:
		for mode in ["DARK", "LIGHT", "TRACK_GRAY"]:
			background_select.add_item(mode)
		background_select.item_selected.connect(func(index: int) -> void: _shared_state.set_background_mode(background_select.get_item_text(index)))
	var zoom_select := get_node_or_null("PreviewControls/DisplayRow/EditZoomSelect") as OptionButton
	if zoom_select != null and zoom_select.item_count == 0:
		zoom_select.add_item("EDIT 200%")
		zoom_select.set_item_metadata(0, 2.0)
		zoom_select.add_item("EDIT 400%")
		zoom_select.set_item_metadata(1, 4.0)
		zoom_select.item_selected.connect(func(index: int) -> void: set_edit_zoom(float(zoom_select.get_item_metadata(index))))
	var motion_select := get_node_or_null("PreviewControls/DisplayRow/MotionSelect") as OptionButton
	if motion_select != null and motion_select.item_count == 0:
		for mode in ["STATIC", "ROTATE", "SIMPLE_MOTION"]:
			motion_select.add_item(mode)
		motion_select.item_selected.connect(func(index: int) -> void: _shared_state.set_motion(motion_select.get_item_text(index), 0.0, Vector2.ZERO, 0.0))
	var show_anchors := get_node_or_null("PreviewControls/DisplayRow/ShowAnchors") as CheckBox
	if show_anchors != null and not show_anchors.toggled.is_connected(_on_show_anchors_toggled):
		show_anchors.button_pressed = _shared_state.show_anchors()
		show_anchors.toggled.connect(_on_show_anchors_toggled)
	var anchor_select := _anchor_select()
	if anchor_select != null and not anchor_select.item_selected.is_connected(_on_anchor_select_changed):
		anchor_select.item_selected.connect(_on_anchor_select_changed)
	var anchor_x := _anchor_x()
	var anchor_y := _anchor_y()
	if anchor_x != null and not anchor_x.value_changed.is_connected(_on_anchor_numeric_changed):
		anchor_x.value_changed.connect(_on_anchor_numeric_changed)
	if anchor_y != null and not anchor_y.value_changed.is_connected(_on_anchor_numeric_changed):
		anchor_y.value_changed.connect(_on_anchor_numeric_changed)
	var save_button := get_node_or_null("PreviewControls/ProfileEditRow/SaveProfile") as Button
	if save_button != null and not save_button.pressed.is_connected(_on_save_profile_pressed):
		save_button.pressed.connect(_on_save_profile_pressed)
	var revert_button := get_node_or_null("PreviewControls/ProfileEditRow/RevertProfile") as Button
	if revert_button != null and not revert_button.pressed.is_connected(_on_revert_profile_pressed):
		revert_button.pressed.connect(_on_revert_profile_pressed)
	_rebuild_track_scales()
	_rebuild_profile_select()
	_rebuild_anchor_controls()


func _rebuild_track_scales() -> void:
	var track_select := get_node_or_null("PreviewControls/DisplayRow/TrackScaleSelect") as OptionButton
	if track_select == null:
		return
	track_select.clear()
	var track_scales: Variant = _shared_state.game_scale_contract().get("track_scales", [])
	if track_scales is Array:
		for track_scale in track_scales:
			track_select.add_item("%.2f - Default" % float(track_scale) if is_equal_approx(float(track_scale), 1.0) else "%.2f" % float(track_scale))
			track_select.set_item_metadata(track_select.item_count - 1, float(track_scale))
	if not track_select.item_selected.is_connected(_on_track_scale_changed):
		track_select.item_selected.connect(_on_track_scale_changed)


func _rebuild_anchor_controls() -> void:
	var anchor_select := _anchor_select()
	if anchor_select == null:
		return
	var previous: String = str(anchor_select.get_selected_metadata()) if anchor_select.selected >= 0 else ""
	anchor_select.clear()
	if _profile_session == null:
		_set_profile_controls_enabled(false)
		return
	var anchors: Variant = _profile_session.working_copy().get("anchors")
	if not anchors is Dictionary:
		_set_profile_controls_enabled(false)
		return
	for anchor_name in anchors:
		anchor_select.add_item(str(anchor_name))
		anchor_select.set_item_metadata(anchor_select.item_count - 1, str(anchor_name))
	var selected_anchor: String = previous if anchors.has(previous) else str(anchors.keys()[0]) if not anchors.is_empty() else ""
	_select_profile_anchor(selected_anchor)
	_set_profile_controls_enabled(not selected_anchor.is_empty())


func _rebuild_profile_select() -> void:
	var profile_select := _profile_select()
	if profile_select == null:
		return
	var selected_path: String = _profile_session.source_path() if _profile_session != null else ""
	profile_select.clear()
	var paths: Array = _profile_documents_by_path.keys()
	paths.sort()
	for profile_path_variant in paths:
		var profile_path: String = str(profile_path_variant)
		var document: RefCounted = _profile_documents_by_path[profile_path]
		var data: Dictionary = document.data()
		profile_select.add_item("%s (%s)" % [str(data.get("display_name", "Vehicle")), str(data.get("category", ""))])
		profile_select.set_item_metadata(profile_select.item_count - 1, profile_path)
	if profile_select.item_count == 0:
		profile_select.disabled = true
		return
	profile_select.disabled = false
	var target_path: String = selected_path if _profile_documents_by_path.has(selected_path) else str(profile_select.get_item_metadata(0))
	_select_profile_path(target_path)


func _on_profile_select_changed(index: int) -> void:
	var profile_select := _profile_select()
	if profile_select != null:
		_select_profile_path(str(profile_select.get_item_metadata(index)))


func _select_profile_path(profile_path: String) -> void:
	if not _profile_documents_by_path.has(profile_path) or _profile_repository == null:
		return
	if _profile_session != null and _profile_session.source_path() != profile_path and _profile_session.is_dirty():
		_select_profile_option(_profile_session.source_path())
		return
	if _profile_session == null or _profile_session.source_path() != profile_path:
		_profile_session = VfxVehicleProfileEditSessionModel.new(_profile_repository)
		_profile_session.open_document(_profile_documents_by_path[profile_path])
	_shared_state.set_profile_data(_profile_session.working_copy())
	_select_profile_option(profile_path)
	_rebuild_anchor_controls()
	_request_edit_scroll_center()


func _select_profile_option(profile_path: String) -> void:
	var profile_select := _profile_select()
	if profile_select == null:
		return
	for index in profile_select.item_count:
		if str(profile_select.get_item_metadata(index)) == profile_path:
			profile_select.select(index)
			return


func _on_track_scale_changed(index: int) -> void:
	var track_select := get_node_or_null("PreviewControls/DisplayRow/TrackScaleSelect") as OptionButton
	if track_select != null:
		_shared_state.set_track_scale(float(track_select.get_item_metadata(index)))


func _on_show_anchors_toggled(show_anchors: bool) -> void:
	_shared_state.set_show_anchors(show_anchors)


func _on_anchor_select_changed(index: int) -> void:
	var anchor_select := _anchor_select()
	if anchor_select != null:
		_select_profile_anchor(str(anchor_select.get_item_metadata(index)))


func _on_canvas_anchor_selected(anchor_name: String) -> void:
	_select_profile_anchor(anchor_name)


func _on_canvas_anchor_dragged(anchor_name: String, source_position: Vector2) -> void:
	if _profile_session != null and _profile_session.set_anchor(anchor_name, source_position):
		_shared_state.set_profile_data(_profile_session.working_copy())
		_select_profile_anchor(anchor_name)


func _on_anchor_numeric_changed(_value: float) -> void:
	if _profile_session == null:
		return
	var anchor_name: String = _selected_anchor_name()
	var anchor_x := _anchor_x()
	var anchor_y := _anchor_y()
	if anchor_name.is_empty() or anchor_x == null or anchor_y == null:
		return
	if _profile_session.set_anchor(anchor_name, Vector2(anchor_x.value, anchor_y.value)):
		_shared_state.set_profile_data(_profile_session.working_copy())


func _on_save_profile_pressed() -> void:
	if _profile_session != null:
		_profile_session.save()
		_shared_state.set_profile_data(_profile_session.working_copy())


func _on_revert_profile_pressed() -> void:
	if _profile_session != null:
		_profile_session.revert()
		_shared_state.set_profile_data(_profile_session.working_copy())
		_rebuild_anchor_controls()


func _select_profile_anchor(anchor_name: String) -> void:
	if anchor_name.is_empty() or _profile_session == null:
		return
	var anchors: Variant = _profile_session.working_copy().get("anchors")
	if not anchors is Dictionary or not anchors.has(anchor_name):
		return
	var anchor_select: OptionButton = _anchor_select()
	for index in anchor_select.item_count:
		if str(anchor_select.get_item_metadata(index)) == anchor_name:
			anchor_select.select(index)
			break
	var coordinate: Array = anchors[anchor_name]
	_anchor_x().set_value_no_signal(float(coordinate[0]))
	_anchor_y().set_value_no_signal(float(coordinate[1]))
	_shared_state.set_selected_profile_anchor(anchor_name)


func _selected_anchor_name() -> String:
	var anchor_select := _anchor_select()
	return str(anchor_select.get_selected_metadata()) if anchor_select != null and anchor_select.selected >= 0 else ""


func _set_profile_controls_enabled(enabled: bool) -> void:
	for control in [_anchor_select(), _anchor_x(), _anchor_y(), get_node_or_null("PreviewControls/ProfileEditRow/SaveProfile"), get_node_or_null("PreviewControls/ProfileEditRow/RevertProfile")]:
		if control is SpinBox:
			control.editable = enabled
		elif control is OptionButton or control is BaseButton:
			control.disabled = not enabled


func _anchor_select() -> OptionButton:
	return get_node_or_null("PreviewControls/ProfileEditRow/AnchorSelect") as OptionButton


func _profile_select() -> OptionButton:
	return get_node_or_null("PreviewControls/DisplayRow/ProfileSelect") as OptionButton


func _anchor_x() -> SpinBox:
	return get_node_or_null("PreviewControls/ProfileEditRow/AnchorX") as SpinBox


func _anchor_y() -> SpinBox:
	return get_node_or_null("PreviewControls/ProfileEditRow/AnchorY") as SpinBox


func _edit_canvas() -> Control:
	return get_node_or_null("PreviewSurface/EditScroll/EditCanvas") as Control


func _request_edit_scroll_center() -> void:
	var edit_canvas: Control = _edit_canvas()
	if edit_canvas != null:
		edit_canvas.request_scroll_center()


func _game_canvas() -> Control:
	return get_node_or_null("PreviewSurface/GameSizeInset/GameInsetContents/GameCanvas") as Control
