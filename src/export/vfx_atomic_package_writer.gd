class_name VfxAtomicPackageWriter
extends RefCounted

const VfxExportFileBackendModel := preload("res://src/export/vfx_export_file_backend.gd")
const VfxExportHasherModel := preload("res://src/export/vfx_export_hasher.gd")
const VfxExportPathsModel := preload("res://src/export/vfx_export_paths.gd")
const VfxExportPackagePlanModel := preload("res://src/export/vfx_export_package_plan.gd")

var _backend: RefCounted
var _hasher: RefCounted
var _paths: RefCounted


func _init(backend: RefCounted = null, hasher: RefCounted = null, paths: RefCounted = null) -> void:
	_backend = backend if backend != null else VfxExportFileBackendModel.new()
	_hasher = hasher if hasher != null else VfxExportHasherModel.new()
	_paths = paths if paths != null else VfxExportPathsModel.new()


func write(plan: RefCounted, mode: String = "FAIL_IF_EXISTS") -> VfxResult:
	if plan == null or (mode != "FAIL_IF_EXISTS" and mode != "REPLACE_EXISTING"):
		return _failure("export_writer_input", "Atomic Export Writer requires a plan and supported write mode.", "")
	var final_path: String = str(plan.final_package_path())
	if _backend.directory_exists(final_path) and mode == "FAIL_IF_EXISTS":
		return _failure("export_package_exists", "Package already exists and replacement was not approved.", final_path)
	var token := "%d_%d" % [Time.get_ticks_usec(), randi()]
	var staging_path := "%s%s/" % [plan.staging_root(), token]
	var backup_path := "%s%s/" % [plan.backup_root(), token]
	var staged: VfxResult = _write_and_verify_staging(plan, staging_path)
	if not staged.success:
		_backend.remove_tree(staging_path)
		return staged
	var had_existing: bool = _backend.directory_exists(final_path)
	if had_existing:
		var backup_parent_error: int = _backend.make_directory(_parent_directory(backup_path))
		if backup_parent_error != OK:
			_backend.remove_tree(staging_path)
			return _failure("export_backup_directory", "Export backup directory could not be created.", backup_path)
		var backup_error: int = _backend.rename_path(final_path, backup_path)
		if backup_error != OK:
			_backend.remove_tree(staging_path)
			return _failure("export_backup_rename", "Existing Package could not be moved to backup.", final_path)
	var final_parent_error: int = _backend.make_directory(_parent_directory(final_path))
	if final_parent_error != OK:
		return _restore_after_final_failure(staging_path, backup_path, final_path, had_existing, "Export final Package directory could not be created.")
	var final_error: int = _backend.rename_path(staging_path, final_path)
	if final_error != OK:
		return _restore_after_final_failure(staging_path, backup_path, final_path, had_existing, "Staging Package could not be moved into final destination.")
	if had_existing:
		var cleanup_error: int = _backend.remove_tree(backup_path)
		if cleanup_error != OK:
			return VfxResult.with_issues(final_path, [VfxIssue.new("EXPORT_IO", "export_backup_cleanup", "Package replacement succeeded but backup cleanup failed.", "", backup_path, -1, -1, "WARNING")])
	return VfxResult.ok(final_path)


func _write_and_verify_staging(plan: RefCounted, staging_path: String) -> VfxResult:
	var directory_error: int = _backend.make_directory(staging_path)
	if directory_error != OK:
		return _failure("export_staging_directory", "Export staging directory could not be created.", staging_path)
	for package_path in plan.text_files():
		if not _paths.is_safe_package_relative_path(str(package_path)):
			return _failure("export_package_path", "Package text path is unsafe.", str(package_path))
		var target_path: String = "%s%s" % [staging_path, package_path]
		var parent_error: int = _backend.make_directory(target_path.get_base_dir())
		if parent_error != OK:
			return _failure("export_staging_parent", "Package text parent directory could not be created.", target_path)
		var write_error: int = _backend.write_text(target_path, str(plan.text_files()[package_path]))
		if write_error != OK:
			return _failure("export_staging_write", "Package text file could not be written.", target_path)
	for asset_copy in plan.asset_copies():
		var package_path: String = str(asset_copy.get("package_path", ""))
		if not _paths.is_safe_package_relative_path(package_path):
			return _failure("export_package_path", "Package asset path is unsafe.", package_path)
		var target_path: String = "%s%s" % [staging_path, package_path]
		var parent_error: int = _backend.make_directory(target_path.get_base_dir())
		if parent_error != OK:
			return _failure("export_staging_parent", "Package asset parent directory could not be created.", target_path)
		var copy_error: int = _backend.copy_file(str(asset_copy.get("source_path", "")), target_path)
		if copy_error != OK:
			return _failure("export_staging_copy", "Package asset could not be copied.", target_path)
	return _verify_staging_files(plan, staging_path)


func _verify_staging_files(plan: RefCounted, staging_path: String) -> VfxResult:
	for file_entry in plan.files():
		var package_path: String = str(file_entry.get("path", ""))
		if not _paths.is_safe_package_relative_path(package_path):
			return _failure("export_package_path", "Manifest file path is unsafe.", package_path)
		var staged_path: String = "%s%s" % [staging_path, package_path]
		if not _backend.file_exists(staged_path):
			return _failure("export_staging_missing", "Manifest-listed staging file is missing.", staged_path)
		var metadata: VfxResult = _hasher.metadata_for_file(staged_path)
		if not metadata.success:
			return metadata
		if metadata.value["sha256"] != file_entry.get("sha256") or metadata.value["byte_size"] != file_entry.get("byte_size"):
			return _failure("export_staging_checksum", "Staging file bytes do not match compiled SHA-256 metadata.", staged_path)
	return VfxResult.ok(staging_path)


func _restore_after_final_failure(staging_path: String, backup_path: String, final_path: String, had_existing: bool, message: String) -> VfxResult:
	_backend.remove_tree(staging_path)
	if not had_existing:
		return _failure("export_final_rename", message, final_path)
	var restored: int = _backend.rename_path(backup_path, final_path)
	if restored != OK:
		return VfxResult.failure([
			VfxIssue.new("EXPORT_IO", "export_final_rename", message, "", final_path),
			VfxIssue.new("EXPORT_IO", "export_backup_restore", "Existing Package backup could not be restored after final rename failure.", "", backup_path)
		])
	return _failure("export_final_rename", message, final_path)


func _failure(code: String, message: String, source_path: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EXPORT_IO", code, message, "", source_path)])


func _parent_directory(path: String) -> String:
	return path.trim_suffix("/").get_base_dir()
