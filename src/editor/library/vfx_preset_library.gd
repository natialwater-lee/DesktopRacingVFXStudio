class_name VfxPresetLibrary
extends RefCounted

const VfxPresetLibraryEntryModel := preload("res://src/editor/library/vfx_preset_library_entry.gd")

var _pipeline: VfxPresetPipeline
var _paths: VfxAuthoringPaths
var _entries: Array = []


func _init(pipeline: VfxPresetPipeline, paths: VfxAuthoringPaths) -> void:
	_pipeline = pipeline
	_paths = paths


func scan() -> Array:
	var valid_entries: Array = []
	var invalid_entries: Array = []
	_scan_directory(_paths.preset_root(), valid_entries, invalid_entries)
	valid_entries.sort_custom(func(left, right) -> bool:
		if left.display_name.nocasecmp_to(right.display_name) == 0:
			return left.preset_id.nocasecmp_to(right.preset_id) < 0
		return left.display_name.nocasecmp_to(right.display_name) < 0
	)
	invalid_entries.sort_custom(func(left, right) -> bool:
		return left.source_path.nocasecmp_to(right.source_path) < 0
	)
	_entries = valid_entries + invalid_entries
	return _entries.duplicate()


func filter(query: String, category: String) -> Array:
	var normalized_query := query.strip_edges().to_lower()
	var filtered: Array = []
	for entry in _entries:
		var matches_query: bool = normalized_query.is_empty() or entry.display_name.to_lower().contains(normalized_query) or entry.preset_id.to_lower().contains(normalized_query)
		var matches_category: bool = category.is_empty() or entry.category == category
		if matches_query and matches_category:
			filtered.append(entry)
	return filtered


func _scan_directory(path: String, valid_entries: Array, invalid_entries: Array) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var child_path := "%s/%s" % [path.trim_suffix("/"), name]
			if directory.current_is_dir():
				_scan_directory(child_path, valid_entries, invalid_entries)
			elif name.ends_with(".vfx.json"):
				_append_entry(child_path, valid_entries, invalid_entries)
		name = directory.get_next()
	directory.list_dir_end()


func _append_entry(path: String, valid_entries: Array, invalid_entries: Array) -> void:
	var loaded := _pipeline.load_and_validate(path)
	if loaded.success:
		var document: VfxPresetDocument = loaded.value
		var normalized := document.normalized_data
		valid_entries.append(VfxPresetLibraryEntryModel.new(
			path,
			normalized.get("display_name", ""),
			normalized.get("preset_id", ""),
			normalized.get("category", ""),
			document
		))
		return
	invalid_entries.append(VfxPresetLibraryEntryModel.new(
		path,
		path.get_file().trim_suffix(".vfx.json"),
		"",
		"",
		null,
		loaded.issues
	))
