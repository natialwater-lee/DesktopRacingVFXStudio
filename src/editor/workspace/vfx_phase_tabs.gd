class_name VfxPhaseTabs
extends TabContainer

signal phase_selected(phase_name: String)
signal duration_commit_requested(phase_name: String, duration_seconds: float)

var _phase_names: Array[String] = []
var _duration_schemas: Dictionary = {}
var _duration_edit_start: Dictionary = {}
var _duration_last_committed: Dictionary = {}
var _phase_data: Dictionary = {}
var _selected_phase_name := ""
var _rebuilding_duration_controls := false


func _ready() -> void:
	if not tab_changed.is_connected(_on_tab_changed):
		tab_changed.connect(_on_tab_changed)


func set_preset(preset: Dictionary) -> void:
	_rebuilding_duration_controls = true
	_phase_data = preset.get("phases", {}).duplicate(true) if preset.get("phases") is Dictionary else {}
	_phase_names.clear()
	for phase_name_variant in _phase_data:
		_phase_names.append(str(phase_name_variant))
	_rebuild_tabs()
	_duration_edit_start.clear()
	_duration_last_committed.clear()
	_rebuilding_duration_controls = false
	if not _phase_names.has(_selected_phase_name):
		_selected_phase_name = _phase_names[0] if not _phase_names.is_empty() else ""
	_select_current_tab()


func select_phase(phase_name: String) -> void:
	if not _phase_names.has(phase_name):
		return
	if _selected_phase_name == phase_name:
		_select_current_tab()
		return
	_selected_phase_name = phase_name
	_select_current_tab()
	phase_selected.emit(_selected_phase_name)


func set_duration_schemas(schemas: Dictionary) -> void:
	_duration_schemas = schemas.duplicate(true)
	_rebuild_tabs()


func visible_phase_names() -> Array[String]:
	return _phase_names.duplicate()


func selected_phase_name() -> String:
	return _selected_phase_name


func phase_has_duration(phase_name: String) -> bool:
	return _duration_schemas.has(phase_name)


func _rebuild_tabs() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for phase_name in _phase_names:
		var phase_page := VBoxContainer.new()
		phase_page.name = phase_name.capitalize()
		var title := Label.new()
		title.text = phase_name.capitalize()
		phase_page.add_child(title)
		if phase_has_duration(phase_name):
			var duration := SpinBox.new()
			duration.name = "DurationSeconds"
			duration.focus_mode = Control.FOCUS_ALL
			var duration_schema: Dictionary = _duration_schemas[phase_name]
			duration.min_value = float(duration_schema["minimum"]) if duration_schema.has("minimum") else -INF
			duration.max_value = float(duration_schema["maximum"]) if duration_schema.has("maximum") else INF
			duration.step = 0.001
			duration.value = float(_phase_data[phase_name].get("duration_seconds", 0.0))
			duration.focus_entered.connect(_on_duration_focus_entered.bind(phase_name, duration))
			duration.focus_exited.connect(_on_duration_focus_exited.bind(phase_name, duration))
			var duration_line_edit := duration.get_line_edit()
			duration_line_edit.focus_entered.connect(_on_duration_focus_entered.bind(phase_name, duration))
			duration_line_edit.focus_exited.connect(_on_duration_focus_exited.bind(phase_name, duration))
			duration_line_edit.text_submitted.connect(_on_duration_submitted.bind(phase_name, duration))
			phase_page.add_child(duration)
		add_child(phase_page)


func _select_current_tab() -> void:
	var index := _phase_names.find(_selected_phase_name)
	if index >= 0:
		current_tab = index


func _on_tab_changed(index: int) -> void:
	if index < 0 or index >= _phase_names.size():
		return
	var next_phase := _phase_names[index]
	if next_phase == _selected_phase_name:
		return
	_selected_phase_name = next_phase
	phase_selected.emit(_selected_phase_name)


func _on_duration_focus_entered(phase_name: String, duration: SpinBox) -> void:
	if _rebuilding_duration_controls or not duration.is_inside_tree():
		return
	if not _duration_edit_start.has(phase_name):
		_duration_edit_start[phase_name] = duration.value


func _on_duration_focus_exited(phase_name: String, duration: SpinBox) -> void:
	_commit_duration_if_changed(phase_name, duration)


func _on_duration_submitted(_text: String, phase_name: String, duration: SpinBox) -> void:
	_commit_duration_if_changed(phase_name, duration)
	if duration.is_inside_tree():
		duration.get_line_edit().grab_focus()


func _commit_duration_if_changed(phase_name: String, duration: SpinBox) -> void:
	if _rebuilding_duration_controls or not duration.is_inside_tree() or not phase_has_duration(phase_name):
		return
	var initial := float(_duration_edit_start.get(phase_name, _phase_data.get(phase_name, {}).get("duration_seconds", duration.value)))
	_duration_edit_start.erase(phase_name)
	if is_equal_approx(initial, duration.value):
		return
	if _duration_last_committed.has(phase_name) and is_equal_approx(float(_duration_last_committed[phase_name]), duration.value):
		return
	duration_commit_requested.emit(phase_name, duration.value)
	_duration_last_committed[phase_name] = duration.value
