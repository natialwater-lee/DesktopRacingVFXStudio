class_name VfxExportCoordinateContract
extends RefCounted

const DEFAULT_CONFIG_PATH := "res://config/vfx_export_coordinate_contract_v1.json"
const SUPPORTED_CONTRACT_VERSION := 1
const SUPPORTED_CANVAS_SIZE := Vector2i(256, 512)
const SUPPORTED_ORIGIN := "CENTER"
const SUPPORTED_FRONT_AXIS := "-Y"

var _config_path: String
var _runtime_data: Dictionary = {}


func _init(config_path: String = DEFAULT_CONFIG_PATH) -> void:
	_config_path = config_path


func load() -> VfxResult:
	var file := FileAccess.open(_config_path, FileAccess.READ)
	if file == null:
		return _failure("export_coordinate_contract_open", "Export Coordinate Contract could not be opened.")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return _failure("export_coordinate_contract_parse", "Export Coordinate Contract must decode to an object.")
	var validation: VfxResult = _validate(parsed)
	if not validation.success:
		return validation
	_runtime_data = {
		"vehicle_source_canvas_size_px": [int(parsed["vehicle_source_canvas_size_px"][0]), int(parsed["vehicle_source_canvas_size_px"][1])],
		"origin": str(parsed["origin"]),
		"front_axis": str(parsed["front_axis"])
	}
	return VfxResult.ok(self)


func runtime_data() -> Dictionary:
	return _runtime_data.duplicate(true)


func _validate(parsed: Dictionary) -> VfxResult:
	if parsed.get("contract_version") != SUPPORTED_CONTRACT_VERSION:
		return _failure("export_coordinate_contract_version", "Export Coordinate Contract version is unsupported.")
	var size_value: Variant = parsed.get("vehicle_source_canvas_size_px")
	if not size_value is Array or size_value.size() != 2 or not _is_positive_number(size_value[0]) or not _is_positive_number(size_value[1]):
		return _failure("export_coordinate_contract_size", "Vehicle source canvas size must contain exactly two positive numbers.")
	var size := Vector2i(int(size_value[0]), int(size_value[1]))
	if size != SUPPORTED_CANVAS_SIZE:
		return _failure("export_coordinate_contract_size", "Vehicle source canvas size is unsupported by Runtime Definition v1.")
	if parsed.get("origin") != SUPPORTED_ORIGIN:
		return _failure("export_coordinate_contract_origin", "Vehicle source coordinate origin is unsupported by Runtime Definition v1.")
	if parsed.get("front_axis") != SUPPORTED_FRONT_AXIS:
		return _failure("export_coordinate_contract_front_axis", "Vehicle source front axis is unsupported by Runtime Definition v1.")
	return VfxResult.ok(parsed)


func _is_positive_number(value: Variant) -> bool:
	return (value is int or value is float) and float(value) > 0.0


func _failure(code: String, message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EXPORT_CONFIG", code, message, "", _config_path)])
