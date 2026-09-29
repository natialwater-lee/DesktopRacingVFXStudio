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
	_test_snow_chunk_texture_is_allow_listed_for_production_export(tests)
	_test_snow_tire_spray_compiles_without_invoking_package_writer(tests)


static func _test_snow_chunk_texture_is_allow_listed_for_production_export(tests: TestAssert) -> void:
	var registry := VfxExportAssetRegistryModel.new()
	var loaded: VfxResult = registry.load()
	var chunk: VfxResult = registry.resolve_exportable("fx.weather_snow_chunk") if loaded.success else VfxResult.failure(loaded.issues)
	tests.expect_true(
		loaded.success
		and chunk.success
		and chunk.value.get("export_policy") == "EXPORTABLE"
		and chunk.value.get("kind") == "TEXTURE_PNG"
		and chunk.value.get("source_path") == "res://assets/vfx/weather_snow_chunk.png"
		and chunk.value.get("package_file_name") == "weather_snow_chunk.png",
		"Snow Tire Roost explicitly allow-lists the snow chunk production PNG asset"
	)


static func _test_snow_tire_spray_compiles_without_invoking_package_writer(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.snow_tire_spray.vfx.json")
	var compiler_result := _compiler()
	if not document_result.success or not compiler_result.success:
		tests.expect_true(false, "Snow Tire Roost export compile-only test requires a valid Preset and configured compiler")
		return
	var compiled: VfxResult = compiler_result.value.compile(document_result.value)
	var manifest: Dictionary = compiled.value.manifest_data() if compiled.success else {}
	var dependencies: Array = manifest.get("asset_dependencies", [])
	var logical_ids := dependencies.map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	var paths := dependencies.map(func(dependency: Dictionary) -> String: return str(dependency.get("package_path", "")))
	tests.expect_true(
		compiled.success
		and logical_ids == ["fx.weather_snow_chunk"]
		and paths == ["assets/weather_snow_chunk.png"]
		and int(manifest.get("runtime_definition", {}).get("version", 0)) == 1,
		"Snow Tire Roost compile-only output is a Runtime v1 package that depends only on the snow chunk PNG, without calling the Package writer"
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
