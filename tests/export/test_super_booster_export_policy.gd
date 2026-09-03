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
	_test_flame_textures_are_explicitly_exportable(tests)
	_test_super_booster_compiles_to_runtime_definition_v2_without_writer(tests)


static func _test_flame_textures_are_explicitly_exportable(tests: TestAssert) -> void:
	var registry := VfxExportAssetRegistryModel.new()
	var loaded: VfxResult = registry.load()
	var core: VfxResult = registry.resolve_exportable("fx.super_booster_flame_core") if loaded.success else VfxResult.failure(loaded.issues)
	var soft: VfxResult = registry.resolve_exportable("fx.super_booster_flame_soft") if loaded.success else VfxResult.failure(loaded.issues)
	tests.expect_true(
		loaded.success and core.success and soft.success \
		and core.value.get("export_policy") == "EXPORTABLE" and soft.value.get("export_policy") == "EXPORTABLE" \
		and core.value.get("kind") == "TEXTURE_PNG" and soft.value.get("kind") == "TEXTURE_PNG" \
		and core.value.get("source_path") == "res://assets/vfx/fx.super_booster_flame_core.png" \
		and soft.value.get("source_path") == "res://assets/vfx/fx.super_booster_flame_soft.png" \
		and core.value.get("package_file_name") == "super_booster_flame_core.png" \
		and soft.value.get("package_file_name") == "super_booster_flame_soft.png",
		"Super Booster explicitly allow-lists the supplied Core and Soft flame PNGs for portable production export"
	)


static func _test_super_booster_compiles_to_runtime_definition_v2_without_writer(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.super_booster.vfx.json")
	var compiler_result := _compiler()
	if not document_result.success or not compiler_result.success:
		tests.expect_true(false, "Super Booster export compile-only test requires a valid saved Preset and configured compiler")
		return
	var first: VfxResult = compiler_result.value.compile(document_result.value)
	var second: VfxResult = compiler_result.value.compile(document_result.value)
	var runtime: Variant = JSON.parse_string(first.value.runtime_text()) if first.success else null
	var manifest: Dictionary = first.value.manifest_data() if first.success else {}
	var dependencies: Array = manifest.get("asset_dependencies", [])
	var logical_ids := dependencies.map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	var paths := dependencies.map(func(dependency: Dictionary) -> String: return str(dependency.get("package_path", "")))
	var runtime_sources: Array = runtime.get("runtime_modulation_sources", []) if runtime is Dictionary else []
	tests.expect_true(
		first.success and second.success and first.value.runtime_text() == second.value.runtime_text() \
		and runtime is Dictionary and runtime.get("runtime_definition_version") == 2 \
		and manifest.get("runtime_definition", {}).get("version") == 2 \
		and manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json" \
		and runtime.get("runtime_inputs", []) == [] \
		and runtime_sources.size() == 1 and runtime_sources[0].get("id") == "flame.pulse" \
		and logical_ids == ["fx.super_booster_flame_core", "fx.super_booster_flame_soft"] \
		and paths == ["assets/super_booster_flame_core.png", "assets/super_booster_flame_soft.png"] \
		and not first.value.runtime_text().contains("res://"),
		"Super Booster compile-only output deterministically selects Runtime Definition v2, keeps its pulse source portable, needs no Runtime Inputs, and inventories only its two texture assets"
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
