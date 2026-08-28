class_name VfxAnchorEditor
extends VBoxContainer

signal anchors_committed(anchors: Array)
signal anchors_cleared()

var _anchor_names: Array[String] = []
var _vehicle_space_modes: Array[String] = []
var _selected: Array[String] = []
var _effective_space := ""
var _checkboxes: Dictionary = {}


func set_schema(schema: Dictionary) -> void:
	_anchor_names.clear()
	_vehicle_space_modes.clear()
	var anchor_definition: Variant = schema.get("$defs", {}).get("anchor", {})
	if anchor_definition is Dictionary:
		for anchor_value in anchor_definition.get("enum", []):
			if anchor_value is String:
				_anchor_names.append(anchor_value)
	var anchor_rule := _rule_named(schema, "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")
	for space_mode in anchor_rule.get("vehicle_space_modes", []):
		if space_mode is String:
			_vehicle_space_modes.append(space_mode)
	_selected = _known_anchors(_selected)
	_rebuild_checkboxes()
	_apply_space_state()


func set_effective_space(effective_space: String) -> void:
	_effective_space = effective_space
	_apply_space_state()


func set_selected_anchors(anchors: Array) -> void:
	_selected = _known_anchors(anchors)
	_sync_checkboxes()


func selected_anchors() -> Array:
	return _selected.duplicate()


func commit_selection(anchors: Array) -> void:
	if not _vehicle_space_modes.has(_effective_space):
		return
	var selected := _known_anchors(anchors)
	if selected.is_empty() or selected == _selected:
		_sync_checkboxes()
		return
	_selected = selected
	_sync_checkboxes()
	anchors_committed.emit(_selected.duplicate())


func _rebuild_checkboxes() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_checkboxes.clear()
	for anchor_name in _anchor_names:
		var check_box := CheckBox.new()
		check_box.name = anchor_name
		check_box.text = anchor_name
		check_box.toggled.connect(_on_anchor_toggled.bind(anchor_name))
		add_child(check_box)
		_checkboxes[anchor_name] = check_box
	_sync_checkboxes()


func _apply_space_state() -> void:
	var is_vehicle_space := _vehicle_space_modes.has(_effective_space)
	visible = is_vehicle_space
	for check_box_variant in _checkboxes.values():
		var check_box := check_box_variant as CheckBox
		check_box.disabled = not is_vehicle_space
	if not is_vehicle_space:
		_selected.clear()
		_sync_checkboxes()


func _sync_checkboxes() -> void:
	for anchor_name in _checkboxes:
		var check_box := _checkboxes[anchor_name] as CheckBox
		check_box.set_pressed_no_signal(_selected.has(anchor_name))


func _on_anchor_toggled(_pressed: bool, anchor_name: String) -> void:
	var selection := _selected.duplicate()
	if _checkboxes[anchor_name].button_pressed:
		if not selection.has(anchor_name):
			selection.append(anchor_name)
	else:
		selection.erase(anchor_name)
	commit_selection(selection)


func _known_anchors(anchors: Array) -> Array[String]:
	var known: Array[String] = []
	for anchor_variant in anchors:
		if anchor_variant is String and _anchor_names.has(anchor_variant) and not known.has(anchor_variant):
			known.append(anchor_variant)
	return known


func _rule_named(schema: Dictionary, rule_name: String) -> Dictionary:
	for rule in schema.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == rule_name:
			return rule
	return {}
