class_name VfxRuntimeInputsEditor
extends VBoxContainer

signal runtime_inputs_committed(inputs: Array[String])

var _available: Array[String] = []
var _selected: Array[String] = []
var _checkboxes: Dictionary = {}


func set_schema(schema: Dictionary) -> void:
	_available.clear()
	var inputs: Variant = schema.get("x_vfx_runtime_inputs", {})
	if inputs is Dictionary:
		for input_name in inputs:
			if input_name is String:
				_available.append(input_name)
	_selected = _ordered_known_inputs(_selected)
	_rebuild_checkboxes()


func available_inputs() -> Array[String]:
	return _available.duplicate()


func set_selected_inputs(inputs: Array) -> void:
	_selected = _ordered_known_inputs(inputs)
	_sync_checkboxes()


func selected_inputs() -> Array[String]:
	return _selected.duplicate()


func commit_selection(inputs: Array) -> void:
	var selected := _ordered_known_inputs(inputs)
	if selected == _selected:
		_sync_checkboxes()
		return
	_selected = selected
	_sync_checkboxes()
	runtime_inputs_committed.emit(_selected.duplicate())


func _rebuild_checkboxes() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_checkboxes.clear()
	for input_name in _available:
		var check_box := CheckBox.new()
		check_box.name = input_name
		check_box.text = input_name
		check_box.toggled.connect(_on_input_toggled.bind(input_name))
		add_child(check_box)
		_checkboxes[input_name] = check_box
	_sync_checkboxes()


func _sync_checkboxes() -> void:
	for input_name in _checkboxes:
		var check_box := _checkboxes[input_name] as CheckBox
		check_box.set_pressed_no_signal(_selected.has(input_name))


func _on_input_toggled(_pressed: bool, input_name: String) -> void:
	var selection := _selected.duplicate()
	if _checkboxes[input_name].button_pressed:
		if not selection.has(input_name):
			selection.append(input_name)
	else:
		selection.erase(input_name)
	commit_selection(selection)


func _ordered_known_inputs(inputs: Array) -> Array[String]:
	var requested: Dictionary = {}
	for input_name in inputs:
		if input_name is String:
			requested[input_name] = true
	var ordered: Array[String] = []
	for input_name in _available:
		if requested.has(input_name):
			ordered.append(input_name)
	return ordered
