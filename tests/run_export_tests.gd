extends SceneTree

const TestAssertHelper := preload("res://tests/support/test_assert.gd")
const ExportContractAndAssetTests := preload("res://tests/export/test_export_contract_and_assets.gd")
const ExportCompilerAndWriterTests := preload("res://tests/export/test_export_compiler_and_writer.gd")
const ExportUiTests := preload("res://tests/export/test_export_ui.gd")
const ExportPackageAcceptanceTests := preload("res://tests/export/test_export_package_acceptance.gd")
const ExportCoordinateContractTests := preload("res://tests/export/test_export_coordinate_contract.gd")
const RotorLiftDownwashExportPolicyTests := preload("res://tests/export/test_rotor_lift_downwash_export_policy.gd")
const RuntimeModulationExportGuardTests := preload("res://tests/export/test_runtime_modulation_export_guard.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tests := TestAssertHelper.new()
	_run_suite(ExportContractAndAssetTests, tests, "Export contract and asset tests")
	_run_suite(ExportCompilerAndWriterTests, tests, "Export compiler and writer tests")
	_run_suite(ExportUiTests, tests, "Export UI tests")
	_run_suite(ExportCoordinateContractTests, tests, "Export coordinate contract tests")
	_run_suite(ExportPackageAcceptanceTests, tests, "Export Package acceptance tests")
	_run_suite(RotorLiftDownwashExportPolicyTests, tests, "Rotor Lift Downwash export-policy tests")
	_run_suite(RuntimeModulationExportGuardTests, tests, "Runtime Modulation export guard tests")
	print("EXPORT_TEST_ASSERTIONS=%d FAILURES=%d" % [tests.assertion_count(), tests.failure_count()])
	quit(1 if tests.failure_count() > 0 else 0)


func _run_suite(suite: Variant, tests: TestAssert, suite_name: String) -> void:
	if suite == null or not suite.has_method("run"):
		tests.expect_true(false, "%s failed to load or expose run()." % suite_name)
		return
	suite.call("run", tests)
