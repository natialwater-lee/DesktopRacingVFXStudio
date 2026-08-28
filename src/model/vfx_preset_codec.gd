class_name VfxPresetCodec
extends RefCounted


func decode_text(text: String, source_path: String = "") -> VfxResult:
	var parser := JSON.new()
	var parse_status := parser.parse(text)
	if parse_status != OK:
		return VfxResult.failure([
			VfxIssue.new(
				"JSON_PARSE",
				"invalid_json",
				parser.get_error_message(),
				"",
				source_path,
				parser.get_error_line(),
				-1
			)
		])
	return VfxResult.ok(parser.data)


func decode_file(path: String) -> VfxResult:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return VfxResult.failure([
			VfxIssue.new(
				"FILE_IO",
				"read_failed",
				error_string(FileAccess.get_open_error()),
				"",
				path
			)
		])
	var result := decode_text(file.get_as_text(), path)
	file.close()
	return result


func encode(value: Variant) -> VfxResult:
	return VfxResult.ok(JSON.stringify(value, "  ", true))


func write_file(path: String, value: Variant) -> VfxResult:
	var encoded := encode(value)
	if not encoded.success:
		return encoded
	return write_text_file(path, encoded.value)


func write_text_file(path: String, text: String) -> VfxResult:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return VfxResult.failure([
			VfxIssue.new(
				"FILE_IO",
				"write_failed",
				error_string(FileAccess.get_open_error()),
				"",
				path
			)
		])
	file.store_string(text)
	file.close()
	return VfxResult.ok(text)
