class_name VfxExportAssetRegistry
extends RefCounted

const DEFAULT_POLICY_PATH := "res://config/vfx_export_asset_policy_v1.json"

var _policy_path: String
var _assets: Dictionary = {}


func _init(policy_path: String = DEFAULT_POLICY_PATH) -> void:
	_policy_path = policy_path


func load() -> VfxResult:
	var file := FileAccess.open(_policy_path, FileAccess.READ)
	if file == null:
		return _failure("export_asset_policy_open", "Export Asset Policy could not be opened.", _policy_path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return _failure("export_asset_policy_parse", "Export Asset Policy must decode to an object.", _policy_path)
	if parsed.get("policy_version") != 1:
		return _failure("export_asset_policy_version", "Export Asset Policy version must be 1.", _policy_path)
	var assets: Variant = parsed.get("assets")
	if not assets is Dictionary:
		return _failure("export_asset_policy_assets", "Export Asset Policy requires an assets object.", _policy_path)
	_assets = assets.duplicate(true)
	return VfxResult.ok(self)


func resolve_exportable(logical_id: String) -> VfxResult:
	if not _assets.has(logical_id):
		return _failure("export_asset_unregistered", "Logical asset is not registered for Production Export: %s" % logical_id, logical_id)
	var definition: Variant = _assets.get(logical_id)
	if not definition is Dictionary:
		return _failure("export_asset_definition", "Export Asset definition must be an object: %s" % logical_id, logical_id)
	if definition.get("export_policy") != "EXPORTABLE":
		return _failure("export_asset_not_allowed", "Logical asset is not exportable: %s" % logical_id, logical_id)
	if definition.get("kind") != "TEXTURE_PNG":
		return _failure("export_asset_kind", "Phase 5 exports only TEXTURE_PNG assets: %s" % logical_id, logical_id)
	var source_path := str(definition.get("source_path", ""))
	var package_file_name := str(definition.get("package_file_name", ""))
	if not _is_allowed_source_path(source_path):
		return _failure("export_asset_source_path", "Export asset source path is not an allowed Studio PNG: %s" % logical_id, source_path)
	if not _is_safe_file_name(package_file_name):
		return _failure("export_asset_file_name", "Export asset file name is unsafe: %s" % logical_id, package_file_name)
	if not FileAccess.file_exists(source_path):
		return _failure("export_asset_missing", "Export asset file is missing: %s" % logical_id, source_path)
	var image := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	if image == null or image.is_empty():
		return _failure("export_asset_unreadable", "Export asset PNG cannot be loaded: %s" % logical_id, source_path)
	return VfxResult.ok(definition.duplicate(true))


func _is_allowed_source_path(path: String) -> bool:
	return path.begins_with("res://assets/vfx/") and path.ends_with(".png") and not path.contains("..") and not path.contains("tests/")


func _is_safe_file_name(file_name: String) -> bool:
	return not file_name.is_empty() and file_name == file_name.get_file() and file_name.ends_with(".png") and not file_name.contains("\\") and not file_name.contains(":")


func _failure(code: String, message: String, source_path: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EXPORT_ASSET", code, message, "", source_path)])
