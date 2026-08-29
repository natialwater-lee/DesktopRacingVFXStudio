class_name VfxExportHasher
extends RefCounted


func metadata_for_text(text: String) -> VfxResult:
	return metadata_for_bytes(text.to_utf8_buffer())


func metadata_for_file(path: String) -> VfxResult:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("export_hash_read", "Package file cannot be read for SHA-256: %s" % path, path)
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return metadata_for_bytes(bytes)


func metadata_for_bytes(bytes: PackedByteArray) -> VfxResult:
	var context := HashingContext.new()
	var started := context.start(HashingContext.HASH_SHA256)
	if started != OK:
		return _failure("export_hash_start", "SHA-256 hashing could not start.", "")
	var updated := context.update(bytes)
	if updated != OK:
		return _failure("export_hash_update", "SHA-256 hashing could not update.", "")
	return VfxResult.ok({"sha256": context.finish().hex_encode(), "byte_size": bytes.size()})


func _failure(code: String, message: String, source_path: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EXPORT_IO", code, message, "", source_path)])
