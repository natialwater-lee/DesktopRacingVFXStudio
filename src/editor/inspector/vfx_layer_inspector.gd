class_name VfxLayerInspector
extends VBoxContainer

signal layer_field_commit(json_pointer: String, value: Variant)
signal space_override_changed(mode_or_inherit: String)
signal layer_type_change_requested(target_type: String)

const INHERIT_DEFAULT := "INHERIT_DEFAULT"
const VfxSchemaInspectorFactoryModel := preload("res://src/editor/inspector/vfx_schema_inspector_factory.gd")

var _reader: VfxSchemaReader
var _layer: Dictionary = {}
var _layer_schema: Dictionary = {}
var _id_edit: LineEdit
var _importance: OptionButton
var _blend_mode: OptionButton
var _render_plane: OptionButton
var _sort_order: SpinBox
var _enabled: CheckBox
var _space_mode: OptionButton
var _type: OptionButton
var _offset_x: SpinBox
var _offset_y: SpinBox
var _rotation: SpinBox
var _scale_x: SpinBox
var _scale_y: SpinBox
var _parameter_fields: VBoxContainer
var _schema_inspector_factory: RefCounted


func set_schema_reader(reader: VfxSchemaReader) -> void:
	_reader = reader
	_schema_inspector_factory = VfxSchemaInspectorFactoryModel.new(reader)
	var layer_result := _reader.layer_schema()
	_layer_schema = layer_result.value if layer_result.success else {}
	_ensure_controls()
	_refresh_controls()


func set_layer(layer: Dictionary) -> void:
	_layer = layer.duplicate(true)
	_ensure_controls()
	_refresh_controls()


func apply_space_override(layer: Dictionary, mode_or_inherit: String) -> Dictionary:
	var next := layer.duplicate(true)
	if mode_or_inherit == INHERIT_DEFAULT:
		next.erase("space_mode")
	else:
		next["space_mode"] = mode_or_inherit
	return next


func create_numeric_control(node_name: String, schema_or_ref: Dictionary) -> SpinBox:
	var control := SpinBox.new()
	control.name = node_name
	var schema := _reader.resolve(schema_or_ref)
	if schema.success:
		var resolved: Dictionary = schema.value
		control.min_value = float(resolved["minimum"]) if resolved.has("minimum") else -INF
		control.max_value = float(resolved["maximum"]) if resolved.has("maximum") else INF
	return control


func _ready() -> void:
	_ensure_controls()
	_refresh_controls()


func _ensure_controls() -> void:
	if _reader == null or _layer_schema.is_empty() or _id_edit != null:
		return
	_add_label("Layer ID")
	_id_edit = LineEdit.new()
	_id_edit.name = "LayerId"
	_id_edit.focus_exited.connect(_on_id_focus_exited)
	add_child(_id_edit)
	_importance = _add_schema_enum("Importance", "importance", "/importance")
	_blend_mode = _add_schema_enum("BlendMode", "blend_mode", "/blend_mode")
	_render_plane = _add_schema_enum("RenderPlane", "render_plane", "/render_plane")
	_add_label("Sort Order")
	_sort_order = create_numeric_control("SortOrder", _property("sort_order").value)
	_sort_order.get_line_edit().focus_exited.connect(_on_sort_focus_exited)
	add_child(_sort_order)
	_add_label("Enabled")
	_enabled = CheckBox.new()
	_enabled.name = "Enabled"
	_enabled.toggled.connect(_on_enabled_toggled)
	add_child(_enabled)
	_add_label("Space Mode")
	_space_mode = OptionButton.new()
	_space_mode.name = "SpaceMode"
	_space_mode.add_item("INHERIT DEFAULT")
	for value in _reader.enum_values(_property("space_mode").value):
		_space_mode.add_item(str(value))
	_space_mode.item_selected.connect(_on_space_mode_selected)
	add_child(_space_mode)
	_add_label("Layer Type")
	_type = OptionButton.new()
	_type.name = "LayerType"
	for layer_type in _reader.layer_type_values():
		_type.add_item(str(layer_type))
	_type.item_selected.connect(_on_type_selected)
	add_child(_type)
	_append_transform_controls()
	_add_label("Parameters")
	_parameter_fields = VBoxContainer.new()
	_parameter_fields.name = "Parameters"
	add_child(_parameter_fields)


func _append_transform_controls() -> void:
	var transform_result := _property("transform")
	if not transform_result.success:
		return
	var transform_schema: Dictionary = transform_result.value
	var offset_result := _reader.property_schema(transform_schema, "offset")
	var offset_schema: Dictionary = offset_result.value if offset_result.success else {}
	var item_schema: Dictionary = offset_schema.get("items", {})
	_add_label("Offset X")
	_offset_x = create_numeric_control("OffsetX", item_schema)
	_offset_x.get_line_edit().focus_exited.connect(_on_transform_focus_exited.bind(["offset", 0], _offset_x))
	add_child(_offset_x)
	_add_label("Offset Y")
	_offset_y = create_numeric_control("OffsetY", item_schema)
	_offset_y.get_line_edit().focus_exited.connect(_on_transform_focus_exited.bind(["offset", 1], _offset_y))
	add_child(_offset_y)
	_add_label("Rotation Degrees")
	_rotation = create_numeric_control("RotationDegrees", _reader.property_schema(transform_schema, "rotation_degrees").value)
	_rotation.get_line_edit().focus_exited.connect(_on_transform_focus_exited.bind(["rotation_degrees"], _rotation))
	add_child(_rotation)
	var scale_result := _reader.property_schema(transform_schema, "scale")
	var scale_schema: Dictionary = scale_result.value if scale_result.success else {}
	var scale_item_schema: Dictionary = scale_schema.get("items", {})
	_add_label("Scale X")
	_scale_x = create_numeric_control("ScaleX", scale_item_schema)
	_scale_x.get_line_edit().focus_exited.connect(_on_transform_focus_exited.bind(["scale", 0], _scale_x))
	add_child(_scale_x)
	_add_label("Scale Y")
	_scale_y = create_numeric_control("ScaleY", scale_item_schema)
	_scale_y.get_line_edit().focus_exited.connect(_on_transform_focus_exited.bind(["scale", 1], _scale_y))
	add_child(_scale_y)


func _refresh_controls() -> void:
	if _id_edit == null:
		return
	_id_edit.text = str(_layer.get("id", ""))
	_select_text(_importance, str(_layer.get("importance", "")))
	_select_text(_blend_mode, str(_layer.get("blend_mode", "")))
	_select_text(_render_plane, str(_layer.get("render_plane", "")))
	_sort_order.value = float(_layer.get("sort_order", _reader.default_value(_property("sort_order").value)))
	_enabled.button_pressed = bool(_layer.get("enabled", _reader.default_value(_property("enabled").value)))
	_select_text(_space_mode, str(_layer.get("space_mode", "INHERIT DEFAULT")))
	_select_text(_type, str(_layer.get("type", "")))
	var default_transform: Dictionary = _reader.default_value(_property("transform").value)
	var transform: Dictionary = _layer.get("transform", default_transform)
	var offset: Array = transform.get("offset", [])
	var scale: Array = transform.get("scale", [])
	var default_offset: Array = default_transform["offset"]
	var default_scale: Array = default_transform["scale"]
	_offset_x.value = float(offset[0]) if offset.size() > 0 else float(default_offset[0])
	_offset_y.value = float(offset[1]) if offset.size() > 1 else float(default_offset[1])
	_rotation.value = float(transform.get("rotation_degrees", default_transform["rotation_degrees"]))
	_scale_x.value = float(scale[0]) if scale.size() > 0 else float(default_scale[0])
	_scale_y.value = float(scale[1]) if scale.size() > 1 else float(default_scale[1])
	_rebuild_parameter_fields()


func _rebuild_parameter_fields() -> void:
	if _parameter_fields == null or _schema_inspector_factory == null:
		return
	for child in _parameter_fields.get_children():
		_parameter_fields.remove_child(child)
		child.queue_free()
	var layer_type: Variant = _layer.get("type")
	if not layer_type is String or layer_type.is_empty():
		return
	var schema_result := _reader.layer_parameter_schema(layer_type)
	var fields: Array[Control]
	if schema_result.success:
		var parameters: Dictionary = _layer.get("parameters", {}) if _layer.get("parameters") is Dictionary else {}
		fields = _schema_inspector_factory.build_fields(schema_result.value, parameters)
	else:
		fields = _schema_inspector_factory.build_fields({}, {})
	for field in fields:
		field.field_committed.connect(_on_parameter_field_committed)
		_parameter_fields.add_child(field)


func _add_schema_enum(node_name: String, property_name: String, pointer: String) -> OptionButton:
	_add_label(property_name.capitalize())
	var control := OptionButton.new()
	control.name = node_name
	for value in _reader.enum_values(_property(property_name).value):
		control.add_item(str(value))
	control.item_selected.connect(_on_enum_selected.bind(pointer, control))
	add_child(control)
	return control


func _property(property_name: String) -> VfxResult:
	return _reader.property_schema(_layer_schema, property_name)


func _add_label(text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	add_child(label)


func _on_id_focus_exited() -> void:
	if _layer.get("id") != _id_edit.text:
		layer_field_commit.emit("/id", _id_edit.text)


func _on_enum_selected(pointer: String, control: OptionButton, index: int) -> void:
	if index >= 0:
		layer_field_commit.emit(pointer, control.get_item_text(index))


func _on_sort_focus_exited() -> void:
	if _layer.get("sort_order") != int(_sort_order.value):
		layer_field_commit.emit("/sort_order", int(_sort_order.value))


func _on_enabled_toggled(value: bool) -> void:
	if _layer.get("enabled") != value:
		layer_field_commit.emit("/enabled", value)


func _on_space_mode_selected(index: int) -> void:
	if index < 0:
		return
	var selected := INHERIT_DEFAULT if index == 0 else _space_mode.get_item_text(index)
	if (selected == INHERIT_DEFAULT) != not _layer.has("space_mode") or selected != _layer.get("space_mode"):
		space_override_changed.emit(selected)


func _on_type_selected(index: int) -> void:
	if index >= 0 and _type.get_item_text(index) != _layer.get("type"):
		var target_type := _type.get_item_text(index)
		_select_text(_type, str(_layer.get("type", "")))
		layer_type_change_requested.emit(target_type)


func _on_parameter_field_committed(json_pointer_suffix: String, value: Variant) -> void:
	layer_field_commit.emit("/parameters%s" % json_pointer_suffix, value)


func _on_transform_focus_exited(path: Array, control: SpinBox) -> void:
	var transform: Dictionary = _layer.get("transform", _reader.default_value(_property("transform").value)).duplicate(true)
	if path.size() == 1:
		if transform.get(path[0]) == control.value:
			return
		transform[path[0]] = control.value
	else:
		var values: Array = transform.get(path[0], []).duplicate()
		if values.size() <= int(path[1]):
			return
		if values[int(path[1])] == control.value:
			return
		values[int(path[1])] = control.value
		transform[path[0]] = values
	layer_field_commit.emit("/transform", transform)


func _select_text(control: OptionButton, value: String) -> void:
	for index in control.item_count:
		if control.get_item_text(index) == value:
			control.select(index)
			return
