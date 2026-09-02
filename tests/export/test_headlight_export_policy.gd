extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxExportAssetRegistryModel := preload("res://src/export/vfx_export_asset_registry.gd")
const VfxExportPresetPolicyModel := preload("res://src/export/vfx_export_preset_policy.gd")
const VfxExportPathsModel := preload("res://src/export/vfx_export_paths.gd")
const VfxExportCoordinateContractModel := preload("res://src/export/vfx_export_coordinate_contract.gd")
const VfxExportCompilerModel := preload("res://src/export/vfx_export_compiler.gd")


static func run(tests: TestAssert) -> void:
	_test_modulated_headlights_fail_closed_before_runtime_definition_v1_compilation(tests)


static func _test_modulated_headlights_fail_closed_before_runtime_definition_v1_compilation(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.headlights.vfx.json")
	var compiler_result := _compiler()
	if not document_result.success or not compiler_result.success:
		tests.expect_true(false, "Headlight export compile-only contract requires a valid Preset and configured compiler")
		return
	var compiled: VfxResult = compiler_result.value.compile(document_result.value)
	tests.expect_true(
		not compiled.success and not compiled.issues.is_empty() and compiled.issues[0].code == "modulated_preset_requires_runtime_definition_v2",
		"Modulation-bearing Headlights fail closed before Runtime Definition v1 compilation; Phase B does not write or manually alter the stale static Package"
	)


static func _compiler() -> VfxResult:
	var assets := VfxExportAssetRegistryModel.new()
	var policy := VfxExportPresetPolicyModel.new()
	var coordinate_contract := VfxExportCoordinateContractModel.new()
	var assets_loaded: VfxResult = assets.load()
	var policy_loaded: VfxResult = policy.load()
	var contract_loaded: VfxResult = coordinate_contract.load()
	if not assets_loaded.success:
		return assets_loaded
	if not policy_loaded.success:
		return policy_loaded
	if not contract_loaded.success:
		return contract_loaded
	return VfxResult.ok(VfxExportCompilerModel.new(_registry(), assets, policy, VfxExportPathsModel.new(), null, null, null, coordinate_contract))


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _runtime_layers(runtime: Variant) -> Array:
	var result: Array = []
	if not runtime is Dictionary:
		return result
	for phase in runtime.get("phases", []):
		if phase is Dictionary:
			for layer in phase.get("layers", []):
				if layer is Dictionary:
					result.append(layer)
	return result
