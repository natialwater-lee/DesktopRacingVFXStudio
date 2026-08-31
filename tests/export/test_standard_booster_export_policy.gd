extends RefCounted

const VfxExportAssetRegistryModel := preload("res://src/export/vfx_export_asset_registry.gd")


static func run(tests: TestAssert) -> void:
	var registry := VfxExportAssetRegistryModel.new()
	var loaded: VfxResult = registry.load()
	var core_result: VfxResult = registry.resolve_exportable("fx.booster_flame_core") if loaded.success else VfxResult.failure(loaded.issues)
	var tail_result: VfxResult = registry.resolve_exportable("fx.booster_flame_tail") if loaded.success else VfxResult.failure(loaded.issues)
	tests.expect_true(
		loaded.success
		and core_result.success
		and tail_result.success
		and core_result.value.get("export_policy") == "EXPORTABLE"
		and tail_result.value.get("export_policy") == "EXPORTABLE"
		and core_result.value.get("kind") == "TEXTURE_PNG"
		and tail_result.value.get("kind") == "TEXTURE_PNG"
		and core_result.value.get("source_path") == "res://assets/vfx/booster_flame_core.png"
		and tail_result.value.get("source_path") == "res://assets/vfx/booster_flame_tail.png"
		and core_result.value.get("package_file_name") == "booster_flame_core.png"
		and tail_result.value.get("package_file_name") == "booster_flame_tail.png",
		"Standard Booster flame art is explicitly allow-listed as exportable PNGs under the existing fail-closed Export Asset Policy"
	)
