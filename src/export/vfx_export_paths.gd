class_name VfxExportPaths
extends RefCounted

const PACKAGE_ROOT := "res://exports/packages/"
const STAGING_ROOT := "res://exports/.staging/"
const BACKUP_ROOT := "res://exports/.backup/"

var _package_root: String
var _staging_root: String
var _backup_root: String


func _init(package_root: String = PACKAGE_ROOT, staging_root: String = STAGING_ROOT, backup_root: String = BACKUP_ROOT) -> void:
	_package_root = _with_trailing_slash(package_root)
	_staging_root = _with_trailing_slash(staging_root)
	_backup_root = _with_trailing_slash(backup_root)


func package_path_for(preset_id: String) -> VfxResult:
	if not _is_safe_package_id(preset_id):
		return _failure("unsafe_package_id", "Preset ID is not safe for a Package directory.", preset_id)
	return VfxResult.ok("%s%s/" % [_package_root, preset_id])


func staging_root() -> String:
	return _staging_root


func backup_root() -> String:
	return _backup_root


func is_safe_package_relative_path(path: String) -> bool:
	if path.is_empty() or path != path.replace("\\", "/"):
		return false
	if path.begins_with("/") or path.contains(":") or path.contains("://"):
		return false
	var segments := path.split("/", false)
	if segments.is_empty():
		return false
	for segment in segments:
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	return true


func is_allowed_role_path(path: String, role_root: String) -> bool:
	return is_safe_package_relative_path(path) and path.begins_with(role_root)


func _is_safe_package_id(preset_id: String) -> bool:
	if preset_id.is_empty() or preset_id.begins_with("."):
		return false
	if preset_id.contains("/") or preset_id.contains("\\") or preset_id.contains(":"):
		return false
	if preset_id.contains(".."):
		return false
	return true


func _with_trailing_slash(path: String) -> String:
	return path if path.ends_with("/") else "%s/" % path


func _failure(code: String, message: String, value: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EXPORT_VALIDATION", code, message, "", value)])
