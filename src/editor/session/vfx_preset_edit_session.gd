class_name VfxPresetEditSession
extends RefCounted

var _dirty_tracker: RefCounted
var _source_path := ""
var _working_data: Dictionary = {}
var _saved_baseline: Dictionary = {}


func _init(dirty_tracker: RefCounted) -> void:
	_dirty_tracker = dirty_tracker


func begin_new(initial_data: Dictionary) -> void:
	_source_path = ""
	_working_data = initial_data.duplicate(true)
	_saved_baseline = initial_data.duplicate(true)


func open_document(document: RefCounted) -> void:
	_source_path = document.source_path
	_working_data = document.normalized_data.duplicate(true)
	_saved_baseline = document.normalized_data.duplicate(true)


func working_copy() -> Dictionary:
	return _working_data.duplicate(true)


func replace_working_data(next_data: Dictionary) -> void:
	_working_data = next_data.duplicate(true)


func source_path() -> String:
	return _source_path


func mark_saved(document: RefCounted) -> void:
	_source_path = document.source_path
	_working_data = document.normalized_data.duplicate(true)
	_saved_baseline = document.normalized_data.duplicate(true)


func is_dirty() -> bool:
	return _source_path.is_empty() or _dirty_tracker.is_dirty(_working_data, _saved_baseline)
