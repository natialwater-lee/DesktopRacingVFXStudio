extends SceneTree

const TestAssertHelper := preload("res://tests/support/test_assert.gd")
const ExportContractAndAssetTests := preload("res://tests/export/test_export_contract_and_assets.gd")
const ExportCompilerAndWriterTests := preload("res://tests/export/test_export_compiler_and_writer.gd")
const StandardBoosterExportPolicyTests := preload("res://tests/export/test_standard_booster_export_policy.gd")
const HighSpeedWindExportPolicyTests := preload("res://tests/export/test_high_speed_wind_export_policy.gd")
const RainTireSprayExportPolicyTests := preload("res://tests/export/test_rain_tire_spray_export_policy.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tests := TestAssertHelper.new()
	ExportContractAndAssetTests.run(tests)
	ExportCompilerAndWriterTests.run_compile_only(tests)
	StandardBoosterExportPolicyTests.run(tests)
	HighSpeedWindExportPolicyTests.run(tests)
	RainTireSprayExportPolicyTests.run(tests)
	print("EXPORT_CONTRACT_TEST_ASSERTIONS=%d FAILURES=%d" % [tests.assertion_count(), tests.failure_count()])
	quit(1 if tests.failure_count() > 0 else 0)
