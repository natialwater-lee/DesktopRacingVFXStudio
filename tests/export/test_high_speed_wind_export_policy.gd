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
	_test_wind_texture_is_allow_listed_for_production_export(tests)
	_test_high_speed_wind_compiles_without_invoking_package_writer(tests)


static func _test_wind_texture_is_allow_listed_for_production_export(tests: TestAssert) -> void:
	var registry := VfxExportAssetRegistryModel.new()
	var loaded: VfxResult = registry.load()
	var all_exportable := loaded.success
	for texture in ["speed_wind_streak", "speed_wind_streak_b", "speed_wind_flow_a", "speed_wind_flow_b"]:
		var asset: VfxResult = registry.resolve_exportable("fx." + texture) if loaded.success else VfxResult.failure(loaded.issues)
		all_exportable = all_exportable \
			and asset.success \
			and asset.value.get("export_policy") == "EXPORTABLE" \
			and asset.value.get("kind") == "TEXTURE_PNG" \
			and asset.value.get("source_path") == "res://assets/vfx/%s.png" % texture \
			and asset.value.get("package_file_name") == "%s.png" % texture
	tests.expect_true(all_exportable, "High-Speed Wind rear streak, streak variant, and both flank flow textures are explicitly allow-listed as exportable production PNGs")


static func _test_high_speed_wind_compiles_without_invoking_package_writer(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.high_speed_wind.vfx.json")
	var compiler_result := _compiler()
	if not document_result.success or not compiler_result.success:
		tests.expect_true(false, "High-Speed Wind export compile-only test requires a valid Preset and configured compiler")
		return
	var compiled: VfxResult = compiler_result.value.compile(document_result.value)
	var dependencies: Array = compiled.value.manifest_data().get("asset_dependencies", []) if compiled.success else []
	var package_paths_by_id: Dictionary = {}
	var all_png := true
	for dependency in dependencies:
		package_paths_by_id[str(dependency.get("logical_id", ""))] = str(dependency.get("package_path", ""))
		all_png = all_png and dependency.get("kind") == "TEXTURE_PNG"
	tests.expect_true(
		compiled.success
		and dependencies.size() == 4
		and all_png
		and package_paths_by_id == {
			"fx.speed_wind_streak": "assets/speed_wind_streak.png",
			"fx.speed_wind_streak_b": "assets/speed_wind_streak_b.png",
			"fx.speed_wind_flow_a": "assets/speed_wind_flow_a.png",
			"fx.speed_wind_flow_b": "assets/speed_wind_flow_b.png"
		},
		"High-Speed Wind compile-only output derives the four safe wind PNG dependencies (rear streak, streak variant, two flank flows) without calling the Package writer"
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
