class_name VfxPreviewAssetRegistry
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://assets/preview/vfx_preview_asset_catalog_v1.json"

var _catalog: Dictionary = {}


func _init(catalog_path: String = DEFAULT_CATALOG_PATH) -> void:
	_load_catalog(catalog_path)


func asset_definition(logical_id: String) -> Dictionary:
	var assets: Variant = _catalog.get("assets", {})
	var definition: Variant = assets.get(logical_id) if assets is Dictionary else null
	return definition.duplicate(true) if definition is Dictionary else {}


func _load_catalog(catalog_path: String) -> void:
	var file := FileAccess.open(catalog_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_catalog = parsed.duplicate(true)
