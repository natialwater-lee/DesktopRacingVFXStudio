class_name VfxPhaseTabs
extends TabContainer

signal phase_selected(phase_name: String)

const DURATION_PHASE_NAMES := ["one_shot", "start", "end"]

var _phase_names: Array[String] = []
var _phase_data: Dictionary = {}
var _selected_phase_name := ""


func _ready() -> void:
	if not tab_changed.is_connected(_on_tab_changed):
		tab_changed.connect(_on_tab_changed)


func set_preset(preset: Dictionary) -> void:
	_phase_data = preset.get("phases", {}).duplicate(true) if preset.get("phases") is Dictionary else {}
	_phase_names.clear()
	for phase_name_variant in _phase_data:
		_phase_names.append(str(phase_name_variant))
	_rebuild_tabs()
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


func visible_phase_names() -> Array[String]:
	return _phase_names.duplicate()


func selected_phase_name() -> String:
	return _selected_phase_name


func phase_has_duration(phase_name: String) -> bool:
	return DURATION_PHASE_NAMES.has(phase_name)


func _rebuild_tabs() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	for phase_name in _phase_names:
		var phase_page := VBoxContainer.new()
		phase_page.name = phase_name.capitalize()
		var title := Label.new()
		title.text = phase_name.capitalize()
		phase_page.add_child(title)
		if phase_has_duration(phase_name):
			var duration := SpinBox.new()
			duration.name = "DurationSeconds"
			duration.min_value = 0.001
			duration.step = 0.001
			duration.value = float(_phase_data[phase_name].get("duration_seconds", 0.001))
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
