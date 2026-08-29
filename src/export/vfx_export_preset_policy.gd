class_name VfxExportPresetPolicy
extends RefCounted

const DEFAULT_POLICY_PATH := "res://config/vfx_export_preset_policy_v1.json"

var _policy_path: String
var _presets: Dictionary = {}


func _init(policy_path: String = DEFAULT_POLICY_PATH) -> void:
	_policy_path = policy_path


func load() -> VfxResult:
	var file := FileAccess.open(_policy_path, FileAccess.READ)
	if file == null:
		return _failure("export_preset_policy_open", "Export Preset Policy could not be opened.", _policy_path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return _failure("export_preset_policy_parse", "Export Preset Policy must decode to an object.", _policy_path)
	if parsed.get("policy_version") != 1:
		return _failure("export_preset_policy_version", "Export Preset Policy version must be 1.", _policy_path)
	var presets: Variant = parsed.get("presets")
	if not presets is Dictionary:
		return _failure("export_preset_policy_presets", "Export Preset Policy requires a presets object.", _policy_path)
	_presets = presets.duplicate(true)
	return VfxResult.ok(self)


func require_export_allowed(preset_id: String) -> VfxResult:
	var definition: Variant = _presets.get(preset_id)
	if definition == null:
		return VfxResult.ok({"preset_id": preset_id, "export_allowed": true})
	if not definition is Dictionary:
		return _failure("export_preset_definition", "Export Preset policy entry must be an object.", preset_id)
	if definition.get("export_allowed") != true:
		return _failure("studio_only_preset", "Preset is Studio-only and cannot be exported: %s" % preset_id, preset_id)
	return VfxResult.ok(definition.duplicate(true))


func _failure(code: String, message: String, source_path: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EXPORT_VALIDATION", code, message, "", source_path)])
