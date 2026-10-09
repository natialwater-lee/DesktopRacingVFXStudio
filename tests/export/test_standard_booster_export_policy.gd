extends RefCounted

const VfxExportAssetRegistryModel := preload("res://src/export/vfx_export_asset_registry.gd")


static func run(tests: TestAssert) -> void:
	var registry := VfxExportAssetRegistryModel.new()
	var loaded: VfxResult = registry.load()
	var jet_result: VfxResult = registry.resolve_exportable("fx.booster_jet") if loaded.success else VfxResult.failure(loaded.issues)
	var flare_result: VfxResult = registry.resolve_exportable("fx.booster_nozzle_flare") if loaded.success else VfxResult.failure(loaded.issues)
	tests.expect_true(
		loaded.success
		and jet_result.success
		and flare_result.success
		and jet_result.value.get("export_policy") == "EXPORTABLE"
		and flare_result.value.get("export_policy") == "EXPORTABLE"
		and jet_result.value.get("kind") == "TEXTURE_PNG"
		and flare_result.value.get("kind") == "TEXTURE_PNG"
		and jet_result.value.get("source_path") == "res://assets/vfx/booster_jet.png"
		and flare_result.value.get("source_path") == "res://assets/vfx/booster_nozzle_flare.png"
		and jet_result.value.get("package_file_name") == "booster_jet.png"
		and flare_result.value.get("package_file_name") == "booster_nozzle_flare.png",
		"Standard Booster v2 jet and nozzle flare art are explicitly allow-listed as exportable PNGs under the existing fail-closed Export Asset Policy"
	)
