class_name VfxPresetInspector
extends VBoxContainer

signal preset_field_commit(json_pointer: String, value: Variant)
signal lifecycle_change_requested(target_mode: String)

var _reader: VfxSchemaReader
var _preset: Dictionary = {}
var _preset_id: LineEdit
var _display_name: LineEdit
var _category: OptionButton
var _lifecycle: OptionButton
var _default_space: OptionButton
var _runtime_inputs_editor

const VfxRuntimeInputsEditorModel := preload("res://src/editor/inspector/vfx_runtime_inputs_editor.gd")

signal runtime_inputs_committed(inputs: Array[String])


func set_schema_reader(reader: VfxSchemaReader) -> void:
	_reader = reader
	_ensure_controls()
	if _runtime_inputs_editor != null:
		_runtime_inputs_editor.set_schema(_reader.root_schema())
	_refresh_controls()


func set_preset(preset: Dictionary) -> void:
	_preset = preset.duplicate(true)
	_ensure_controls()
	_refresh_controls()


func focus_json_pointer(json_pointer: String) -> bool:
	var control := _find_control_by_pointer(self, json_pointer)
	if control == null or not control.is_inside_tree():
		return false
	if control is SpinBox:
		(control as SpinBox).get_line_edit().grab_focus()
	else:
		control.grab_focus()
	return control.has_focus() or (control is SpinBox and (control as SpinBox).get_line_edit().has_focus())


func _ready() -> void:
	_ensure_controls()
	_refresh_controls()


func _ensure_controls() -> void:
	if _reader == null or _preset_id != null:
		return
	_add_label("Preset ID")
	_preset_id = _add_text_control("PresetId", "/preset_id")
	_add_label("Display Name")
	_display_name = _add_text_control("DisplayName", "/display_name")
	_add_label("Category")
	_category = _add_enum_control("Category", _reader.property_schema(_reader.root_schema(), "category"), "/category")
	_add_label("Lifecycle")
	var lifecycle := _reader.property_schema(_reader.root_schema(), "lifecycle")
	var mode_schema := _reader.property_schema(lifecycle.value, "mode") if lifecycle.success else VfxResult.failure([])
	_lifecycle = _add_enum_control("Lifecycle", mode_schema, "/lifecycle/mode", true)
	_add_label("Default Space")
	_default_space = _add_enum_control("DefaultSpace", _reader.property_schema(_reader.root_schema(), "default_space_mode"), "/default_space_mode")
	_add_label("Runtime Inputs")
	_runtime_inputs_editor = VfxRuntimeInputsEditorModel.new()
	_runtime_inputs_editor.name = "RuntimeInputs"
	_runtime_inputs_editor.set_meta("vfx_json_pointer", "/runtime_inputs")
	_runtime_inputs_editor.runtime_inputs_committed.connect(func(inputs: Array[String]) -> void: runtime_inputs_committed.emit(inputs))
	add_child(_runtime_inputs_editor)


func _refresh_controls() -> void:
	if _preset_id == null:
		return
	_preset_id.text = str(_preset.get("preset_id", ""))
	_display_name.text = str(_preset.get("display_name", ""))
	_select_text(_category, str(_preset.get("category", "")))
	var lifecycle: Dictionary = _preset.get("lifecycle", {})
	_select_text(_lifecycle, str(lifecycle.get("mode", "")))
	_select_text(_default_space, str(_preset.get("default_space_mode", "")))
	_runtime_inputs_editor.set_selected_inputs(_preset.get("runtime_inputs", []))


func _add_label(text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	add_child(label)


func _add_text_control(node_name: String, pointer: String) -> LineEdit:
	var control := LineEdit.new()
	control.name = node_name
	control.set_meta("vfx_json_pointer", pointer)
	control.focus_exited.connect(_on_text_focus_exited.bind(pointer, control))
	add_child(control)
	return control


func _add_enum_control(node_name: String, schema_result: VfxResult, pointer: String, lifecycle: bool = false) -> OptionButton:
	var control := OptionButton.new()
	control.name = node_name
	control.set_meta("vfx_json_pointer", pointer)
	if schema_result.success:
		for value in _reader.enum_values(schema_result.value):
			control.add_item(str(value))
	if lifecycle:
		control.item_selected.connect(_on_lifecycle_selected)
	else:
		control.item_selected.connect(_on_enum_selected.bind(pointer, control))
	add_child(control)
	return control


func _on_text_focus_exited(pointer: String, control: LineEdit) -> void:
	var key := pointer.trim_prefix("/")
	if _preset.get(key) != control.text:
		preset_field_commit.emit(pointer, control.text)


func _on_enum_selected(index: int, pointer: String, control: OptionButton) -> void:
	if index >= 0:
		preset_field_commit.emit(pointer, control.get_item_text(index))


func _on_lifecycle_selected(index: int) -> void:
	if index >= 0:
		lifecycle_change_requested.emit(_lifecycle.get_item_text(index))


func _find_control_by_pointer(parent: Node, json_pointer: String) -> Control:
	for child in parent.get_children():
		if child is Control and child.has_meta("vfx_json_pointer") and str(child.get_meta("vfx_json_pointer")) == json_pointer:
			return child
		var nested := _find_control_by_pointer(child, json_pointer)
		if nested != null:
			return nested
	return null


func _select_text(control: OptionButton, value: String) -> void:
	if control == null:
		return
	for item_index in control.item_count:
		if control.get_item_text(item_index) == value:
			control.select(item_index)
			return
