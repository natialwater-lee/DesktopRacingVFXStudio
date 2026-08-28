class_name VfxAuthoringPaths
extends RefCounted

const PRESET_ROOT := "res://presets/"


func preset_root() -> String:
	return PRESET_ROOT


func contains_preset_path(path: String) -> bool:
	return normalize_authoring_path(path).begins_with(PRESET_ROOT)


func default_save_path(preset_id: String) -> String:
	return "%s%s.vfx.json" % [PRESET_ROOT, preset_id]


func normalize_authoring_path(path: String) -> String:
	return path.replace("\\", "/").simplify_path()
