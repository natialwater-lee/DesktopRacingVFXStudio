class_name VfxVehiclePreview
extends VBoxContainer

const VfxPreviewSharedStateModel := preload("res://src/preview/vfx_preview_shared_state.gd")
const VfxVehiclePreviewCanvasModel := preload("res://src/preview/vfx_vehicle_preview_canvas.gd")
const VfxVehicleProfileEditSessionModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_edit_session.gd")
const VfxPreviewRendererFactoryModel := preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxPreviewRenderRuntimeModel := preload("res://src/preview/rendering/vfx_preview_render_runtime.gd")
const VfxPreviewPlaybackControllerModel := preload("res://src/preview/rendering/vfx_preview_playback_controller.gd")
const VfxPreviewCanvasRenderHostModel := preload("res://src/preview/rendering/vfx_preview_canvas_render_host.gd")

var _shared_state: RefCounted = VfxPreviewSharedStateModel.new()
var _profile_session: RefCounted
var _profile_repository: RefCounted
var _profile_documents_by_path: Dictionary = {}
var _edit_zoom := 2.0
var _schema_registry: RefCounted
var _active_render_plan: RefCounted
var _render_runtime: RefCounted
var _playback: RefCounted
var _renderer_factory: RefCounted
var _asset_resolver: RefCounted
var _render_hosts: Dictionary = {}
var _preview_status := "PREVIEW — NO VALID PLAN"
var _preview_phase := ""


func _ready() -> void:
	_configure_canvases()
	_configure_controls()
	_configure_render_hosts()
	_update_preview_status_label()
	_rebuild_render_runtime()


func set_shared_state(shared_state: RefCounted) -> void:
	_shared_state = shared_state if shared_state != null else VfxPreviewSharedStateModel.new()
	_configure_canvases()
	_rebuild_track_scales()
	_rebuild_render_runtime()


func shared_state() -> RefCounted:
	return _shared_state


func set_edit_zoom(edit_zoom: float) -> void:
	if is_equal_approx(edit_zoom, 2.0) or is_equal_approx(edit_zoom, 4.0):
		_edit_zoom = edit_zoom
		var edit_canvas: Control = _edit_canvas()
		if edit_canvas != null:
			edit_canvas.set_view_zoom(_edit_zoom)
		_rebuild_render_runtime()


func edit_zoom() -> float:
	return _edit_zoom


func set_profile_data(profile_data: Dictionary) -> void:
	_shared_state.set_profile_data(profile_data)
	_rebuild_anchor_controls()
	_request_edit_scroll_center()
	_rebuild_render_runtime()


func set_profile_edit_session(profile_session: RefCounted) -> void:
	_profile_session = profile_session
	if _profile_session != null:
		_shared_state.set_profile_data(_profile_session.working_copy())
	_rebuild_anchor_controls()
	_request_edit_scroll_center()
	_rebuild_render_runtime()


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
	_rebuild_render_runtime()


func set_schema_registry(schema_registry: RefCounted) -> void:
	_schema_registry = schema_registry
	_rebuild_render_runtime()


func set_preview_phase(phase_name: String) -> void:
	_preview_phase = phase_name
	if _playback != null and not _auto_playback_enabled():
		_playback.set_manual_phase(_preview_phase)
		_present_render_packets()


func apply_render_plan(render_plan: RefCounted) -> void:
	if render_plan == null:
		return
	_active_render_plan = render_plan
	_preview_status = "PREVIEW READY"
	_rebuild_render_runtime()


func active_render_plan() -> RefCounted:
	return _active_render_plan


func set_preview_validation_state(issues: Array) -> void:
	var has_error := false
	for issue in issues:
		if issue is VfxIssue and issue.severity != "WARNING":
			has_error = true
			break
	if has_error:
		_preview_status = "PREVIEW STALE — VALIDATION ERROR" if _active_render_plan != null else "PREVIEW — VALIDATION ERROR"
		if _active_render_plan == null:
			_clear_render_hosts()
	else:
		_preview_status = "PREVIEW READY" if _active_render_plan != null else "PREVIEW — NO VALID PLAN"
	_update_preview_status_label()


func preview_status_text() -> String:
	return _preview_status


func set_layer_context(layer_context: RefCounted) -> void:
	_shared_state.set_layer_context(layer_context)
	var label := get_node_or_null("PreviewControls/LayerContext") as Label
	if label != null:
		label.text = "No Layer Selected" if layer_context == null else "%s | %s | %s" % [layer_context.layer_id, ", ".join(layer_context.anchor_names()), layer_context.effective_space()]
		label.tooltip_text = label.text


func _process(delta: float) -> void:
	if _shared_state == null:
		return
	if _playback != null and _playback.is_advancing():
		_playback.advance(delta, _frame_context())
		_apply_motion_at_time(_playback.simulation_time())
		_present_render_packets()
	elif _playback == null:
		_apply_motion_at_time(float(_shared_state.motion_time()) + delta)
	_layout_screen_ui_hosts()


func _apply_motion_at_time(next_time: float) -> void:
	match _shared_state.motion_mode():
		"ROTATE":
			_shared_state.set_motion("ROTATE", next_time, Vector2.ZERO, fmod(next_time * 45.0, 360.0))
		"SIMPLE_MOTION":
			_shared_state.set_motion("SIMPLE_MOTION", next_time, Vector2(sin(next_time * 0.9) * 160.0, 0.0), 0.0)
		_:
			_shared_state.set_motion("STATIC", next_time, Vector2.ZERO, 0.0)


func _frame_context() -> Dictionary:
	var scale_result: VfxResult = _shared_state.effective_game_scale()
	var scale: Vector2 = scale_result.value if scale_result.success else Vector2.ONE
	return {
		"vehicle_translation_source": _shared_state.vehicle_translation_source(),
		"vehicle_rotation_degrees": _shared_state.vehicle_rotation_degrees(),
		"effective_game_scale": scale
	}


func _configure_render_hosts() -> void:
	if not is_node_ready():
		return
	for canvas_name in ["EDIT", "GAME"]:
		var canvas: Control = _edit_canvas() if canvas_name == "EDIT" else _game_canvas()
		if canvas == null:
			continue
		_ensure_screen_ui_host(canvas_name, canvas)
	_layout_screen_ui_hosts()


func _ensure_screen_ui_host(canvas_name: String, canvas: Control) -> Node2D:
	var key := "%s:SCREEN_UI" % canvas_name
	var existing := _render_hosts.get(key) as Node2D
	if existing != null:
		return existing
	var parent: Node = canvas
	if canvas_name == "EDIT":
		parent = get_node_or_null("PreviewSurface")
	var screen_host := Node2D.new()
	screen_host.name = "%sScreenUiPlaneHost" % canvas_name.capitalize()
	screen_host.z_index = 100
	parent.add_child(screen_host)
	_render_hosts[key] = screen_host
	return screen_host


func _layout_screen_ui_hosts() -> void:
	for canvas_name in ["EDIT", "GAME"]:
		var canvas: Control = _edit_canvas() if canvas_name == "EDIT" else _game_canvas()
		var screen_host := _render_hosts.get("%s:SCREEN_UI" % canvas_name) as Node2D
		if canvas == null or screen_host == null:
			continue
		if canvas_name == "EDIT":
			var scroll := canvas.get_parent() as ScrollContainer
			screen_host.position = scroll.position + scroll.size * 0.5 if scroll != null else canvas.position + canvas.size * 0.5
		else:
			screen_host.position = canvas.position + canvas.size * 0.5


func _rebuild_render_runtime() -> void:
	if not is_node_ready():
		return
	_clear_render_hosts()
	_render_runtime = null
	_playback = null
	if _active_render_plan == null or _schema_registry == null:
		_update_preview_status_label()
		return
	_renderer_factory = VfxPreviewRendererFactoryModel.new()
	var configuration: VfxResult = _renderer_factory.validate_configuration(_schema_registry)
	if not configuration.success:
		_preview_status = "PREVIEW — CONFIGURATION ERROR"
		_update_preview_status_label()
		return
	_asset_resolver = VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	_render_runtime = VfxPreviewRenderRuntimeModel.new(_active_render_plan, _shared_state.profile_data(), _schema_registry, _renderer_factory, _asset_resolver)
	_playback = VfxPreviewPlaybackControllerModel.new(_active_render_plan, _render_runtime)
	_playback.set_auto_playback(_auto_playback_enabled())
	if not _auto_playback_enabled():
		_playback.set_manual_phase(_preview_phase)
	_playback.restart(_frame_context())
	if not _render_runtime.issues().is_empty():
		_preview_status = "PREVIEW WARNING — ASSET FALLBACK"
	_update_preview_status_label()
	_present_render_packets()


func _present_render_packets() -> void:
	if _render_runtime == null:
		return
	var packets: Array = _render_runtime.draw_packets()
	var routed: Dictionary = {}
	for packet in packets:
		if not packet is Dictionary:
			continue
		for canvas_name in ["EDIT", "GAME"]:
			var host: Variant = _render_host_for_packet(canvas_name, packet)
			if host == null:
				continue
			var key := str(host.get_instance_id())
			if not routed.has(key):
				routed[key] = {"host": host, "packets": []}
			routed[key]["packets"].append(packet)
	for host_entry in _render_hosts.values():
		if host_entry is Node and host_entry.has_method("clear_packets"):
			host_entry.clear_packets()
	for route in routed.values():
		var host: Variant = route["host"]
		host.apply_packets(route["packets"])


func _render_host_for_packet(canvas_name: String, packet: Dictionary) -> Node2D:
	var render_plane := str(packet.get("render_plane", ""))
	var effective_space := str(packet.get("space", ""))
	var parent: Node2D
	if render_plane == "SCREEN_UI":
		parent = _ensure_screen_ui_host(canvas_name, _edit_canvas() if canvas_name == "EDIT" else _game_canvas())
	else:
		var canvas: VfxVehiclePreviewCanvas = _edit_canvas() if canvas_name == "EDIT" else _game_canvas()
		parent = canvas.render_plane_host(render_plane, effective_space) if canvas != null else null
	if parent == null:
		return null
	var blend_mode := str(packet.get("blend_mode", "ALPHA"))
	var key := "%s:%s:%s" % [canvas_name, parent.get_path(), blend_mode]
	var host := _render_hosts.get(key) as Node2D
	if host == null:
		host = VfxPreviewCanvasRenderHostModel.new()
		host.name = "RenderHost_%s" % blend_mode
		host.set_blend_mode(blend_mode)
		parent.add_child(host)
		_render_hosts[key] = host
	return host


func _clear_render_hosts() -> void:
	for host in _render_hosts.values():
		if host is Node and host.has_method("clear_packets"):
			host.clear_packets()


func _auto_playback_enabled() -> bool:
	var toggle := get_node_or_null("PreviewControls/PlaybackRow/AutoPlayback") as CheckBox
	return toggle == null or toggle.button_pressed


func _update_preview_status_label() -> void:
	var label := get_node_or_null("PreviewControls/PlaybackRow/PreviewStatus") as Label
	if label != null:
		label.text = _preview_status
		label.tooltip_text = _preview_status


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
	var play_button := get_node_or_null("PreviewControls/PlaybackRow/PlayButton") as Button
	if play_button != null and not play_button.pressed.is_connected(_on_play_preview_pressed):
		play_button.pressed.connect(_on_play_preview_pressed)
	var pause_button := get_node_or_null("PreviewControls/PlaybackRow/PauseButton") as Button
	if pause_button != null and not pause_button.pressed.is_connected(_on_pause_preview_pressed):
		pause_button.pressed.connect(_on_pause_preview_pressed)
	var restart_button := get_node_or_null("PreviewControls/PlaybackRow/RestartButton") as Button
	if restart_button != null and not restart_button.pressed.is_connected(_on_restart_preview_pressed):
		restart_button.pressed.connect(_on_restart_preview_pressed)
	var auto_playback := get_node_or_null("PreviewControls/PlaybackRow/AutoPlayback") as CheckBox
	if auto_playback != null and not auto_playback.toggled.is_connected(_on_auto_playback_toggled):
		auto_playback.toggled.connect(_on_auto_playback_toggled)
	_rebuild_track_scales()
	_rebuild_profile_select()
	_rebuild_anchor_controls()


func _on_play_preview_pressed() -> void:
	if _playback != null:
		_playback.play(_frame_context())


func _on_pause_preview_pressed() -> void:
	if _playback != null:
		_playback.pause()


func _on_restart_preview_pressed() -> void:
	if _playback != null:
		_playback.restart(_frame_context())
		_present_render_packets()


func _on_auto_playback_toggled(enabled: bool) -> void:
	if _playback == null:
		return
	_playback.set_auto_playback(enabled)
	if not enabled:
		_playback.set_manual_phase(_preview_phase)
	else:
		_playback.restart(_frame_context())
	_present_render_packets()


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
	_rebuild_render_runtime()


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
		_rebuild_render_runtime()


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
		_rebuild_render_runtime()


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
		_rebuild_render_runtime()


func _on_save_profile_pressed() -> void:
	if _profile_session != null:
		_profile_session.save()
		_shared_state.set_profile_data(_profile_session.working_copy())
		_rebuild_render_runtime()


func _on_revert_profile_pressed() -> void:
	if _profile_session != null:
		_profile_session.revert()
		_shared_state.set_profile_data(_profile_session.working_copy())
		_rebuild_anchor_controls()
		_rebuild_render_runtime()


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
