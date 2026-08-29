extends RefCounted

const VALID_PATH := "res://tests/fixtures/export/coordinate_contract_valid.json"
const MALFORMED_SIZE_PATH := "res://tests/fixtures/export/coordinate_contract_malformed_size.json"
const UNSUPPORTED_ORIGIN_PATH := "res://tests/fixtures/export/coordinate_contract_unsupported_origin.json"
const UNSUPPORTED_FRONT_AXIS_PATH := "res://tests/fixtures/export/coordinate_contract_unsupported_front_axis.json"
const MISSING_PATH := "res://tests/fixtures/export/coordinate_contract_missing.json"
const EXPECTED_RUNTIME_CONTRACT := {
	"vehicle_source_canvas_size_px": [256, 512],
	"origin": "CENTER",
	"front_axis": "-Y"
}


static func run(tests: TestAssert) -> void:
	_test_coordinate_contract_loader_is_fail_closed(tests)
	_test_export_service_blocks_when_coordinate_config_is_missing(tests)


static func _test_coordinate_contract_loader_is_fail_closed(tests: TestAssert) -> void:
	var script := load("res://src/export/vfx_export_coordinate_contract.gd") as Script
	tests.expect_true(script != null and script.can_instantiate(), "Export Coordinate Contract loader is available")
	if script == null or not script.can_instantiate():
		return
	var valid: Variant = script.new(VALID_PATH)
	var loaded: VfxResult = valid.load()
	tests.expect_true(loaded.success and valid.runtime_data() == EXPECTED_RUNTIME_CONTRACT, "valid coordinate config provides the fixed 256x512 center-origin negative-Y runtime contract")
	for invalid_path in [MALFORMED_SIZE_PATH, UNSUPPORTED_ORIGIN_PATH, UNSUPPORTED_FRONT_AXIS_PATH]:
		var invalid: Variant = script.new(invalid_path)
		tests.expect_true(not invalid.load().success, "malformed or unsupported coordinate config is rejected instead of defaulted")


static func _test_export_service_blocks_when_coordinate_config_is_missing(tests: TestAssert) -> void:
	var script := load("res://src/export/vfx_export_coordinate_contract.gd") as Script
	if script == null or not script.can_instantiate():
		tests.expect_true(false, "Missing-coordinate-config service gate requires the Coordinate Contract loader")
		return
	var missing_contract: Variant = script.new(MISSING_PATH)
	var service_script := load("res://src/export/vfx_export_service.gd") as Script
	tests.expect_true(service_script != null and service_script.can_instantiate(), "Export service is available for coordinate-config gating")
	if service_script == null or not service_script.can_instantiate():
		return
	var service: Variant = service_script.callv("new", [null, null, null, null, null, null, null, missing_contract])
	if service == null:
		tests.expect_true(false, "Export service accepts an injected Coordinate Contract for fail-closed validation")
		return
	var result: VfxResult = service.validate_saved_source("res://presets/examples/talent.zero_zone.vfx.json")
	tests.expect_true(not result.success, "missing coordinate config blocks saved-source Export validation")
