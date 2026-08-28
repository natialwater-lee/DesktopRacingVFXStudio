class_name VfxLayerStack
extends PanelContainer

signal layer_selected(layer_id: String)
signal add_layer_requested(layer_type: String)
signal delete_layer_requested(layer_id: String)
signal duplicate_layer_requested(layer_id: String)
signal move_layer_requested(layer_id: String, direction: int)
signal layer_enabled_requested(layer_id: String, enabled: bool)

var _layer_factory: RefCounted
var _phase_name := ""
var _layers: Array = []
var _available_layer_types: Array[String] = []


func _init(layer_factory: RefCounted = null) -> void:
	_layer_factory = layer_factory


func set_layer_factory(layer_factory: RefCounted) -> void:
	_layer_factory = layer_factory


func set_available_layer_types(layer_types: Array) -> void:
	_available_layer_types.clear()
	for layer_type_variant in layer_types:
		_available_layer_types.append(str(layer_type_variant))
	_rebuild_rows()


func set_phase(preset: Dictionary, phase_name: String) -> void:
	_phase_name = phase_name if preset.get("phases") is Dictionary and preset["phases"].has(phase_name) else ""
	_layers = preset["phases"][_phase_name].get("layers", []).duplicate(true) if not _phase_name.is_empty() else []
	_rebuild_rows()


func add_layer(preset: Dictionary, phase_name: String, layer_type: String) -> Dictionary:
	return add_layer_with_factory(_layer_factory, preset, phase_name, layer_type)


static func add_layer_with_factory(layer_factory: RefCounted, preset: Dictionary, phase_name: String, layer_type: String) -> Dictionary:
	var next := preset.duplicate(true)
	if layer_factory == null or not _has_phase(next, phase_name):
		return next
	var created: VfxResult = layer_factory.create(layer_type, phase_name, preset)
	if created.success:
		next["phases"][phase_name]["layers"].append(created.value.duplicate(true))
	return next


func delete_layer(preset: Dictionary, phase_name: String, layer_id: String) -> Dictionary:
	return delete_layer_in_phase(preset, phase_name, layer_id)


static func delete_layer_in_phase(preset: Dictionary, phase_name: String, layer_id: String) -> Dictionary:
	var next := preset.duplicate(true)
	if not _has_phase(next, phase_name):
		return next
	var layers: Array = next["phases"][phase_name].get("layers", [])
	for index in layers.size():
		if layers[index] is Dictionary and layers[index].get("id") == layer_id:
			layers.remove_at(index)
			break
	return next


func duplicate_layer(preset: Dictionary, phase_name: String, layer_id: String) -> Dictionary:
	return duplicate_layer_with_factory(_layer_factory, preset, phase_name, layer_id)


static func duplicate_layer_with_factory(layer_factory: RefCounted, preset: Dictionary, phase_name: String, layer_id: String) -> Dictionary:
	var next := preset.duplicate(true)
	if layer_factory == null or not _has_phase(next, phase_name):
		return next
	for layer in preset["phases"][phase_name].get("layers", []):
		if layer is Dictionary and layer.get("id") == layer_id:
			var duplicated: VfxResult = layer_factory.duplicate(phase_name, layer, preset)
			if duplicated.success:
				next["phases"][phase_name]["layers"].append(duplicated.value.duplicate(true))
			break
	return next


func move_layer(preset: Dictionary, phase_name: String, layer_index: int, direction: int) -> Dictionary:
	return move_layer_in_phase(preset, phase_name, layer_index, direction)


static func move_layer_in_phase(preset: Dictionary, phase_name: String, layer_index: int, direction: int) -> Dictionary:
	var next := preset.duplicate(true)
	if not _has_phase(next, phase_name):
		return next
	var layers: Array = next["phases"][phase_name].get("layers", [])
	if layer_index < 0 or layer_index >= layers.size():
		return next
	var target_index := clampi(layer_index + direction, 0, layers.size() - 1)
	if target_index != layer_index:
		var moved = layers.pop_at(layer_index)
		layers.insert(target_index, moved)
	return next


func set_layer_enabled(preset: Dictionary, phase_name: String, layer_id: String, enabled: bool) -> Dictionary:
	return set_layer_enabled_in_phase(preset, phase_name, layer_id, enabled)


static func set_layer_enabled_in_phase(preset: Dictionary, phase_name: String, layer_id: String, enabled: bool) -> Dictionary:
	var next := preset.duplicate(true)
	if not _has_phase(next, phase_name):
		return next
	for layer in next["phases"][phase_name].get("layers", []):
		if layer is Dictionary and layer.get("id") == layer_id:
			layer["enabled"] = enabled
			break
	return next


func request_add_layer(layer_type: String) -> void:
	add_layer_requested.emit(layer_type)


static func _has_phase(preset: Dictionary, phase_name: String) -> bool:
	return preset.get("phases") is Dictionary and preset["phases"].has(phase_name) and preset["phases"][phase_name] is Dictionary


func _rebuild_rows() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	add_child(rows)
	_append_add_controls(rows)
	for layer in _layers:
		if layer is Dictionary:
			_append_layer_row(rows, layer)


func _append_layer_row(rows: VBoxContainer, layer: Dictionary) -> void:
	var layer_id: String = layer.get("id", "")
	var row := HBoxContainer.new()
	var select_button := Button.new()
	select_button.text = layer_id
	select_button.pressed.connect(func() -> void: layer_selected.emit(layer_id))
	row.add_child(select_button)
	var enabled := CheckBox.new()
	enabled.button_pressed = layer.get("enabled", false)
	enabled.toggled.connect(func(value: bool) -> void: layer_enabled_requested.emit(layer_id, value))
	row.add_child(enabled)
	var duplicate := Button.new()
	duplicate.text = "Duplicate"
	duplicate.pressed.connect(func() -> void: duplicate_layer_requested.emit(layer_id))
	row.add_child(duplicate)
	var up := Button.new()
	up.text = "Up"
	up.pressed.connect(func() -> void: move_layer_requested.emit(layer_id, -1))
	row.add_child(up)
	var down := Button.new()
	down.text = "Down"
	down.pressed.connect(func() -> void: move_layer_requested.emit(layer_id, 1))
	row.add_child(down)
	var delete := Button.new()
	delete.text = "Delete"
	delete.pressed.connect(func() -> void: delete_layer_requested.emit(layer_id))
	row.add_child(delete)
	rows.add_child(row)


func _append_add_controls(rows: VBoxContainer) -> void:
	var controls := HBoxContainer.new()
	controls.name = "AddControls"
	var type_selector := OptionButton.new()
	type_selector.name = "LayerTypeSelector"
	for layer_type in _available_layer_types:
		type_selector.add_item(layer_type)
	if not _available_layer_types.is_empty():
		type_selector.select(0)
	type_selector.disabled = _available_layer_types.is_empty()
	controls.add_child(type_selector)
	var add_button := Button.new()
	add_button.name = "AddLayerButton"
	add_button.text = "Add Layer"
	add_button.disabled = _phase_name.is_empty() or _available_layer_types.is_empty()
	add_button.pressed.connect(_on_add_pressed.bind(type_selector))
	controls.add_child(add_button)
	rows.add_child(controls)


func _on_add_pressed(type_selector: OptionButton) -> void:
	if type_selector.selected >= 0:
		add_layer_requested.emit(type_selector.get_item_text(type_selector.selected))
