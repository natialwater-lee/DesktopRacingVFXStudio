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
	_test_snow_mist_textures_are_allow_listed_for_production_export(tests)
	_test_snow_tire_spray_compiles_without_invoking_package_writer(tests)


static func _test_snow_mist_textures_are_allow_listed_for_production_export(tests: TestAssert) -> void:
	var registry := VfxExportAssetRegistryModel.new()
	var loaded: VfxResult = registry.load()
	var right: VfxResult = registry.resolve_exportable("fx.snow_tire_mist_right") if loaded.success else VfxResult.failure(loaded.issues)
	var left: VfxResult = registry.resolve_exportable("fx.snow_tire_mist_left") if loaded.success else VfxResult.failure(loaded.issues)
	tests.expect_true(
		loaded.success \
		and right.success and left.success \
		and right.value.get("export_policy") == "EXPORTABLE" and left.value.get("export_policy") == "EXPORTABLE" \
		and right.value.get("kind") == "TEXTURE_PNG" and left.value.get("kind") == "TEXTURE_PNG" \
		and right.value.get("source_path") == "res://assets/vfx/snow_tire_mist_right.png" \
		and left.value.get("source_path") == "res://assets/vfx/snow_tire_mist_left.png" \
		and right.value.get("package_file_name") == "snow_tire_mist_right.png" \
		and left.value.get("package_file_name") == "snow_tire_mist_left.png",
		"Snow Tire Mist explicitly allow-lists its mirrored side-specific production PNG assets"
	)


static func _test_snow_tire_spray_compiles_without_invoking_package_writer(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.snow_tire_spray.vfx.json")
	var compiler_result := _compiler()
	if not document_result.success or not compiler_result.success:
		tests.expect_true(false, "Snow Tire Mist export compile-only test requires a valid Preset and configured compiler")
		return
	var compiled: VfxResult = compiler_result.value.compile(document_result.value)
	var dependencies: Array = compiled.value.manifest_data().get("asset_dependencies", []) if compiled.success else []
	var logical_ids := dependencies.map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	var paths := dependencies.map(func(dependency: Dictionary) -> String: return str(dependency.get("package_path", "")))
	tests.expect_true(
		compiled.success \
		and logical_ids == ["fx.snow_tire_mist_left", "fx.snow_tire_mist_right"] \
		and paths == ["assets/snow_tire_mist_left.png", "assets/snow_tire_mist_right.png"],
		"Snow Tire Mist compile-only output derives only its safe mirrored powder-mist PNG dependencies without calling the Package writer"
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
