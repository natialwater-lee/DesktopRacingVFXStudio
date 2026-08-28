class_name VfxNewPresetDialog
extends ConfirmationDialog

signal preset_requested(preset_id: String, display_name: String, category: String, lifecycle_mode: String, default_space_mode: String)

var _category_options: Array[String] = []
var _lifecycle_options: Array[String] = []
var _default_space_options: Array[String] = []
var _preset_id_edit: LineEdit
var _display_name_edit: LineEdit
var _category_select: OptionButton
var _lifecycle_select: OptionButton
var _default_space_select: OptionButton


func set_schema(schema: Dictionary) -> void:
	_category_options = _enum_values(schema, schema.get("properties", {}).get("category", {}))
	var lifecycle := _resolve(schema, schema.get("properties", {}).get("lifecycle", {}))
	_lifecycle_options = _enum_values(schema, lifecycle.get("properties", {}).get("mode", {}))
	_default_space_options = _enum_values(schema, schema.get("properties", {}).get("default_space_mode", {}))
	if _category_select != null:
		_populate_controls()


func category_options() -> Array[String]:
	return _category_options.duplicate()


func lifecycle_options() -> Array[String]:
	return _lifecycle_options.duplicate()


func default_space_options() -> Array[String]:
	return _default_space_options.duplicate()


func request_preset(preset_id: String, display_name: String, category: String, lifecycle_mode: String, default_space_mode: String) -> void:
	if _category_options.has(category) and _lifecycle_options.has(lifecycle_mode) and _default_space_options.has(default_space_mode):
		preset_requested.emit(preset_id, display_name, category, lifecycle_mode, default_space_mode)


func _ready() -> void:
	_ensure_controls()


func _ensure_controls() -> void:
	if _category_select != null:
		return
	var body := VBoxContainer.new()
	body.name = "Body"
	add_child(body)
	_preset_id_edit = _add_text_field(body, "PresetId", "Preset ID")
	_display_name_edit = _add_text_field(body, "DisplayName", "Display Name")
	_category_select = _add_option_field(body, "Category", "Category")
	_lifecycle_select = _add_option_field(body, "Lifecycle", "Lifecycle")
	_default_space_select = _add_option_field(body, "DefaultSpace", "Default Space")
	confirmed.connect(_emit_preset_request)
	_populate_controls()


func _add_text_field(parent: VBoxContainer, node_name: String, placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.name = node_name
	field.placeholder_text = placeholder
	parent.add_child(field)
	return field


func _add_option_field(parent: VBoxContainer, node_name: String, label_text: String) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var select := OptionButton.new()
	select.name = node_name
	parent.add_child(select)
	return select


func _populate_controls() -> void:
	_populate_option(_category_select, _category_options)
	_populate_option(_lifecycle_select, _lifecycle_options)
	_populate_option(_default_space_select, _default_space_options)


func _populate_option(select: OptionButton, options: Array[String]) -> void:
	select.clear()
	for option in options:
		select.add_item(option)
	if not options.is_empty():
		select.select(0)


func _emit_preset_request() -> void:
	request_preset(
		_preset_id_edit.text,
		_display_name_edit.text,
		_selected_text(_category_select),
		_selected_text(_lifecycle_select),
		_selected_text(_default_space_select)
	)


func _selected_text(select: OptionButton) -> String:
	return select.get_item_text(select.selected) if select.selected >= 0 else ""


func _resolve(root_schema: Dictionary, schema_or_ref: Dictionary) -> Dictionary:
	var current := schema_or_ref
	while current.has("$ref"):
		var reference: String = current["$ref"]
		if not reference.begins_with("#/$defs/"):
			return {}
		var definition_name := reference.trim_prefix("#/$defs/")
		if not root_schema.get("$defs", {}).has(definition_name):
			return {}
		current = root_schema["$defs"][definition_name]
	return current


func _enum_values(root_schema: Dictionary, schema_or_ref: Dictionary) -> Array[String]:
	var resolved := _resolve(root_schema, schema_or_ref)
	var values: Array[String] = []
	for value in resolved.get("enum", []):
		if value is String:
			values.append(value)
	return values
