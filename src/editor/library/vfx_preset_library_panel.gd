class_name VfxPresetLibraryPanel
extends VBoxContainer

signal filter_changed(query: String, category: String)
signal preset_open_requested(entry: RefCounted)
signal invalid_entry_selected(entry: RefCounted)

var _entries: Array = []


func _ready() -> void:
	var search := get_node_or_null("Search") as LineEdit
	var category_filter := get_node_or_null("CategoryFilter") as OptionButton
	if search != null and not search.text_changed.is_connected(_on_search_text_changed):
		search.text_changed.connect(_on_search_text_changed)
	if category_filter != null and not category_filter.item_selected.is_connected(_on_category_selected):
		category_filter.item_selected.connect(_on_category_selected)


func set_categories(categories: Array) -> void:
	var category_filter := get_node_or_null("CategoryFilter") as OptionButton
	if category_filter == null:
		return
	category_filter.clear()
	category_filter.add_item("All Categories")
	category_filter.set_item_metadata(0, "")
	for category_variant in categories:
		var category := str(category_variant)
		category_filter.add_item(category)
		category_filter.set_item_metadata(category_filter.item_count - 1, category)
	category_filter.select(0)


func set_entries(entries: Array) -> void:
	_entries = entries.duplicate()
	_rebuild_rows()


func current_query() -> String:
	var search := get_node_or_null("Search") as LineEdit
	return search.text if search != null else ""


func current_category() -> String:
	var category_filter := get_node_or_null("CategoryFilter") as OptionButton
	if category_filter == null or category_filter.selected < 0:
		return ""
	return str(category_filter.get_item_metadata(category_filter.selected))


func _on_search_text_changed(_text: String) -> void:
	filter_changed.emit(current_query(), current_category())


func _on_category_selected(_index: int) -> void:
	filter_changed.emit(current_query(), current_category())


func _rebuild_rows() -> void:
	var rows := get_node_or_null("RowsScroll/Rows") as VBoxContainer
	if rows == null:
		return
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for entry in _entries:
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.clip_text = true
		if entry.is_openable():
			row.text = "%s | %s | %s" % [entry.display_name, entry.preset_id, entry.category]
			row.tooltip_text = row.text
			row.pressed.connect(func() -> void: preset_open_requested.emit(entry))
		else:
			var issue_code: String = str(entry.issues[0].code) if not entry.issues.is_empty() else "invalid"
			row.text = "Invalid | %s | %s" % [entry.source_path, issue_code]
			row.tooltip_text = row.text
			row.pressed.connect(func() -> void: invalid_entry_selected.emit(entry))
		rows.add_child(row)
