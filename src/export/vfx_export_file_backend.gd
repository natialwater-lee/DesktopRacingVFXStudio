class_name VfxExportFileBackend
extends RefCounted


func make_directory(path: String) -> int:
	return DirAccess.make_dir_recursive_absolute(_absolute(path))


func directory_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(_absolute(path))


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func write_text(path: String, text: String) -> int:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	var write_error := file.get_error()
	file.close()
	return write_error


func copy_file(source_path: String, destination_path: String) -> int:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return FileAccess.get_open_error()
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		var open_error := FileAccess.get_open_error()
		source.close()
		return open_error
	destination.store_buffer(source.get_buffer(source.get_length()))
	var write_error := destination.get_error()
	destination.close()
	source.close()
	return write_error


func rename_path(from_path: String, to_path: String) -> int:
	return DirAccess.rename_absolute(_absolute(from_path), _absolute(to_path))


func remove_tree(path: String) -> int:
	var absolute := _absolute(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return OK
	var directory := DirAccess.open(absolute)
	if directory == null:
		return DirAccess.get_open_error()
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var child := "%s/%s" % [absolute, name]
			var remove_error := remove_tree(child) if directory.current_is_dir() else DirAccess.remove_absolute(child)
			if remove_error != OK:
				directory.list_dir_end()
				return remove_error
		name = directory.get_next()
	directory.list_dir_end()
	return DirAccess.remove_absolute(absolute)


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)
