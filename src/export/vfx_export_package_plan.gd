class_name VfxExportPackagePlan
extends RefCounted

var _package_id: String
var _final_package_path: String
var _staging_root: String
var _backup_root: String
var _source_text: String
var _runtime_text: String
var _runtime_definition_version: int
var _runtime_definition_path: String
var _manifest_data: Dictionary
var _manifest_text: String
var _text_files: Dictionary
var _files: Array[Dictionary]
var _asset_copies: Array[Dictionary]


func _init(package_id_value: String, final_package_path_value: String, staging_root_value: String = "", backup_root_value: String = "", source_text_value: String = "", runtime_text_value: String = "", manifest_value: Dictionary = {}, manifest_text_value: String = "", text_file_values: Dictionary = {}, file_values: Array = [], asset_copy_values: Array = [], runtime_definition_version_value: int = 1, runtime_definition_path_value: String = "runtime/vfx_runtime_definition_v1.json") -> void:
	_package_id = package_id_value
	_final_package_path = final_package_path_value
	_staging_root = staging_root_value
	_backup_root = backup_root_value
	_source_text = source_text_value
	_runtime_text = runtime_text_value
	_runtime_definition_version = runtime_definition_version_value
	_runtime_definition_path = runtime_definition_path_value
	_manifest_data = manifest_value.duplicate(true)
	_manifest_text = manifest_text_value
	_text_files = text_file_values.duplicate(true)
	for file_value in file_values:
		if file_value is Dictionary:
			_files.append(file_value.duplicate(true))
	for asset_copy in asset_copy_values:
		if asset_copy is Dictionary:
			_asset_copies.append(asset_copy.duplicate(true))


func package_id() -> String:
	return _package_id


func final_package_path() -> String:
	return _final_package_path


func staging_root() -> String:
	return _staging_root


func backup_root() -> String:
	return _backup_root


func source_text() -> String:
	return _source_text


func runtime_text() -> String:
	return _runtime_text


func runtime_definition_version() -> int:
	return _runtime_definition_version


func runtime_definition_path() -> String:
	return _runtime_definition_path


func manifest_data() -> Dictionary:
	return _manifest_data.duplicate(true)


func manifest_text() -> String:
	return _manifest_text


func text_files() -> Dictionary:
	return _text_files.duplicate(true)


func files() -> Array[Dictionary]:
	return _files.duplicate(true)


func asset_copies() -> Array[Dictionary]:
	return _asset_copies.duplicate(true)
