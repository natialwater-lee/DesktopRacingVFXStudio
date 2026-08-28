class_name VfxSchemaInspectorFactory
extends RefCounted

class SchemaField:
	extends VBoxContainer

	signal field_committed(json_pointer_suffix: String, value: Variant)


var _reader: VfxSchemaReader


func _init(reader: VfxSchemaReader) -> void:
	_reader = reader


func build_fields(schema: Dictionary, value: Dictionary) -> Array[Control]:
	var resolved_result := _reader.resolve(schema)
	if not resolved_result.success:
		return [_configuration_diagnostic("Schema object could not be resolved.")]
	var resolved: Dictionary = resolved_result.value
	if resolved.get("type") != "object" or not resolved.get("properties") is Dictionary:
		return [_configuration_diagnostic("Schema Inspector root must be an object.")]
	return _build_object_fields(resolved, value, "")


func control_kind_for(schema: Dictionary) -> String:
	var resolved_result := _reader.resolve(schema)
	if not resolved_result.success:
		return "Diagnostic"
	var resolved: Dictionary = resolved_result.value
	if resolved.get("enum") is Array:
		return "OptionButton"
	match resolved.get("type"):
		"number", "integer":
			return "SpinBox"
		"boolean":
			return "CheckBox"
		"string":
			return "LineEdit"
		"object":
			return "Object"
		"array":
			if _is_fixed_number_array(resolved, 2):
				return "Vector2"
			if _is_fixed_number_array(resolved, 4):
				return "RGBA"
	return "Diagnostic"


func _build_object_fields(schema: Dictionary, value: Dictionary, pointer_prefix: String) -> Array[Control]:
	var fields: Array[Control] = []
	var properties: Dictionary = schema.get("properties", {})
	for property_name_variant in _visible_property_names(schema, value):
		var property_name: String = property_name_variant
		var property_schema_variant: Variant = properties.get(property_name)
		if not property_schema_variant is Dictionary:
			fields.append(_named_configuration_diagnostic(property_name, "Schema property must be an object."))
			continue
		var pointer := "%s/%s" % [pointer_prefix, _escape_pointer_segment(property_name)]
		var property_value: Variant = value.get(property_name, _initial_value(property_schema_variant))
		fields.append(_build_field(property_name, pointer, property_schema_variant, property_value))
	return fields


func _build_field(property_name: String, pointer: String, schema: Dictionary, value: Variant) -> Control:
	var field := SchemaField.new()
	field.name = property_name
	var resolved_result := _reader.resolve(schema)
	if not resolved_result.success:
		_add_field_title(field, property_name)
		_add_diagnostic_label(field, "Schema property could not be resolved.")
		return field
	var resolved: Dictionary = resolved_result.value
	match control_kind_for(resolved):
		"OptionButton":
			_add_field_title(field, property_name)
			var select := OptionButton.new()
			select.name = "Input"
			for option in resolved.get("enum", []):
				select.add_item(str(option))
			_select_text(select, str(value))
			select.item_selected.connect(_on_enum_selected.bind(field, pointer, select))
			field.add_child(select)
		"SpinBox":
			_add_field_title(field, property_name)
			var spin := _number_input(resolved, value)
			spin.name = "Input"
			spin.get_line_edit().focus_exited.connect(_on_number_focus_exited.bind(field, pointer, spin, resolved.get("type") == "integer"))
			field.add_child(spin)
		"CheckBox":
			var check := CheckBox.new()
			check.name = "Input"
			check.text = property_name.capitalize()
			check.button_pressed = bool(value)
			check.toggled.connect(_on_bool_toggled.bind(field, pointer))
			field.add_child(check)
		"LineEdit":
			_add_field_title(field, property_name)
			var edit := LineEdit.new()
			edit.name = "Input"
			edit.text = str(value)
			edit.focus_exited.connect(_on_string_focus_exited.bind(field, pointer, edit))
			field.add_child(edit)
		"Vector2", "RGBA":
			_add_field_title(field, property_name)
			_add_number_array(field, pointer, resolved, value)
		"Object":
			_add_field_title(field, property_name)
			var group := VBoxContainer.new()
			group.name = "Fields"
			field.add_child(group)
			var object_value: Dictionary = value if value is Dictionary else {}
			for nested_field in _build_object_fields(resolved, object_value, pointer):
				nested_field.field_committed.connect(_relay_nested_commit.bind(field))
				group.add_child(nested_field)
		_:
			_add_field_title(field, property_name)
			_add_diagnostic_label(field, "Unsupported Schema node for the v1 Inspector.")
	return field


func _visible_property_names(schema: Dictionary, value: Dictionary) -> Array:
	var properties: Dictionary = schema.get("properties", {})
	var names: Array = properties.keys()
	var root_schema := _reader.root_schema()
	var emission_rule := _rule_named(root_schema, "PARTICLE_EMISSION_CONFIGURATION")
	var emitter_rule := _rule_named(root_schema, "PARTICLE_EMITTER_SHAPE")
	var configured_emitter_field: Variant = emitter_rule.get("emitter_field")
	if not emission_rule.is_empty() and configured_emitter_field is String and properties.has(emission_rule.get("emission_mode_field")) and properties.has(configured_emitter_field):
		var mode_field: String = emission_rule["emission_mode_field"]
		var mode: Variant = value.get(mode_field, _initial_value(properties[mode_field]))
		var mode_requirements: Dictionary = emission_rule.get("mode_requirements", {})
		if mode_requirements.has(mode):
			var controlled_fields: Array = []
			for configured_requirements_variant in mode_requirements.values():
				if configured_requirements_variant is Dictionary:
					for key in ["required_fields", "forbidden_fields"]:
						for configured_field in configured_requirements_variant.get(key, []):
							if not controlled_fields.has(configured_field):
								controlled_fields.append(configured_field)
			var visible_fields: Array = mode_requirements[mode].get("required_fields", [])
			for controlled_field in controlled_fields:
				if not visible_fields.has(controlled_field):
					names.erase(controlled_field)
	if not emitter_rule.is_empty() and properties.has(emitter_rule.get("shape_field")):
		var shape_field: String = emitter_rule["shape_field"]
		var shape: Variant = value.get(shape_field, _initial_value(properties[shape_field]))
		var geometry_by_shape: Dictionary = emitter_rule.get("geometry_by_shape", {})
		if geometry_by_shape.has(shape):
			var geometry_fields: Array = []
			for configured_geometry_variant in geometry_by_shape.values():
				for configured_field in configured_geometry_variant:
					if not geometry_fields.has(configured_field):
						geometry_fields.append(configured_field)
			for geometry_field in geometry_fields:
				if not geometry_by_shape[shape].has(geometry_field):
					names.erase(geometry_field)
	return names


func _add_number_array(field: SchemaField, pointer: String, schema: Dictionary, value: Variant) -> void:
	var row := HBoxContainer.new()
	row.name = "Input"
	field.add_child(row)
	var item_result := _reader.resolve(schema.get("items", {}))
	var item_schema: Dictionary = item_result.value if item_result.success else {}
	var count := int(schema.get("minItems", 0))
	var labels := ["X", "Y"] if count == 2 else ["R", "G", "B", "A"]
	var source_values: Array = value if value is Array else []
	var components: Array[SpinBox] = []
	for index in count:
		var component_value: Variant = source_values[index] if index < source_values.size() else _initial_value(item_schema)
		var component := _number_input(item_schema, component_value)
		component.name = labels[index]
		row.add_child(component)
		components.append(component)
	for component in components:
		component.get_line_edit().focus_exited.connect(_on_array_focus_exited.bind(field, pointer, components))


func _number_input(schema: Dictionary, value: Variant) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = float(schema["minimum"]) if schema.has("minimum") else -INF
	spin.max_value = float(schema["maximum"]) if schema.has("maximum") else INF
	spin.step = 1.0 if schema.get("type") == "integer" else 0.001
	spin.tooltip_text = "Minimum: %s\nMaximum: %s" % [str(schema["minimum"]) if schema.has("minimum") else "unbounded", str(schema["maximum"]) if schema.has("maximum") else "unbounded"]
	spin.value = float(value) if value is int or value is float else float(schema.get("minimum", 0.0))
	return spin


func _initial_value(schema: Dictionary) -> Variant:
	var resolved_result := _reader.resolve(schema)
	if not resolved_result.success:
		return null
	var resolved: Dictionary = resolved_result.value
	if resolved.has("default"):
		return _duplicate_value(resolved["default"])
	if resolved.get("enum") is Array and not resolved["enum"].is_empty():
		return _duplicate_value(resolved["enum"][0])
	match resolved.get("type"):
		"number", "integer":
			return resolved.get("minimum", 0)
		"boolean":
			return false
		"string":
			return ""
		"object":
			return {}
		"array":
			var values: Array = []
			for _index in int(resolved.get("minItems", 0)):
				values.append(_initial_value(resolved.get("items", {})))
			return values
	return null


func _is_fixed_number_array(schema: Dictionary, length: int) -> bool:
	if schema.get("minItems") != length or schema.get("maxItems") != length:
		return false
	var item_result := _reader.resolve(schema.get("items", {}))
	return item_result.success and item_result.value.get("type") == "number"


func _configuration_diagnostic(message: String) -> SchemaField:
	return _named_configuration_diagnostic("Configuration", message)


func _named_configuration_diagnostic(field_name: String, message: String) -> SchemaField:
	var field := SchemaField.new()
	field.name = field_name
	_add_field_title(field, field_name)
	_add_diagnostic_label(field, message)
	return field


func _add_field_title(field: SchemaField, property_name: String) -> void:
	var label := Label.new()
	label.name = "Title"
	label.text = property_name.capitalize()
	field.add_child(label)


func _add_diagnostic_label(field: SchemaField, message: String) -> void:
	var diagnostic := Label.new()
	diagnostic.name = "ConfigurationDiagnostic"
	diagnostic.text = message
	field.add_child(diagnostic)


func _on_enum_selected(index: int, field: SchemaField, pointer: String, select: OptionButton) -> void:
	if index >= 0:
		field.field_committed.emit(pointer, select.get_item_text(index))


func _on_number_focus_exited(field: SchemaField, pointer: String, spin: SpinBox, is_integer: bool) -> void:
	field.field_committed.emit(pointer, int(spin.value) if is_integer else spin.value)


func _on_bool_toggled(value: bool, field: SchemaField, pointer: String) -> void:
	field.field_committed.emit(pointer, value)


func _on_string_focus_exited(field: SchemaField, pointer: String, edit: LineEdit) -> void:
	field.field_committed.emit(pointer, edit.text)


func _on_array_focus_exited(field: SchemaField, pointer: String, components: Array[SpinBox]) -> void:
	var values: Array = []
	for component in components:
		values.append(component.value)
	field.field_committed.emit(pointer, values)


func _relay_nested_commit(pointer: String, value: Variant, field: SchemaField) -> void:
	field.field_committed.emit(pointer, value)


func _select_text(select: OptionButton, value: String) -> void:
	for index in select.item_count:
		if select.get_item_text(index) == value:
			select.select(index)
			return


func _rule_named(root_schema: Dictionary, rule_name: String) -> Dictionary:
	for rule in root_schema.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == rule_name:
			return rule
	return {}


func _escape_pointer_segment(value: String) -> String:
	return value.replace("~", "~0").replace("/", "~1")


func _duplicate_value(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
