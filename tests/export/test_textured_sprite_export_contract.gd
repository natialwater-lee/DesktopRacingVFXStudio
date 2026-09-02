extends RefCounted

const TexturedSpriteContractTests := preload("res://tests/unit/test_textured_sprite_contract.gd")
const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxExportAssetRegistryModel := preload("res://src/export/vfx_export_asset_registry.gd")
const VfxExportPresetPolicyModel := preload("res://src/export/vfx_export_preset_policy.gd")
const VfxExportPathsModel := preload("res://src/export/vfx_export_paths.gd")
const VfxExportCoordinateContractModel := preload("res://src/export/vfx_export_coordinate_contract.gd")
const VfxExportCompilerModel := preload("res://src/export/vfx_export_compiler.gd")
const VfxExportRequirementDeriverModel := preload("res://src/export/vfx_export_requirement_deriver.gd")


static func run(tests: TestAssert) -> void:
	_test_headlight_assets_are_explicit_exportable_pngs(tests)
	_test_generic_textured_sprite_compiles_and_inventories_its_texture(tests)
	_test_generic_textured_sprite_rejects_missing_or_non_exportable_assets(tests)


static func _test_headlight_assets_are_explicit_exportable_pngs(tests: TestAssert) -> void:
	var registry := VfxExportAssetRegistryModel.new()
	var loaded: VfxResult = registry.load()
	var core: VfxResult = registry.resolve_exportable("fx.headlight_beam_core") if loaded.success else VfxResult.failure(loaded.issues)
	var soft: VfxResult = registry.resolve_exportable("fx.headlight_beam_soft") if loaded.success else VfxResult.failure(loaded.issues)
	tests.expect_true(loaded.success and core.success and soft.success and core.value.get("kind") == "TEXTURE_PNG" and soft.value.get("kind") == "TEXTURE_PNG" and core.value.get("package_file_name") == "headlight_beam_core.png" and soft.value.get("package_file_name") == "headlight_beam_soft.png", "Headlight art has explicit generic Production PNG policy entries rather than an implicit Preview-to-Export fallback")


static func _test_generic_textured_sprite_compiles_and_inventories_its_texture(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().build_document_from_value(TexturedSpriteContractTests.preset_data())
	var compiler_result: VfxResult = _compiler()
	if not document_result.success or not compiler_result.success:
		tests.expect_true(false, "TEXTURED_SPRITE export test requires a valid generic document and configured compiler")
		return
	var derived: VfxResult = VfxExportRequirementDeriverModel.new(_registry()).derive(document_result.value)
	var compiled: VfxResult = compiler_result.value.compile(document_result.value)
	var runtime: Variant = JSON.parse_string(compiled.value.runtime_text()) if compiled.success else null
	var dependencies: Array = compiled.value.manifest_data().get("asset_dependencies", []) if compiled.success else []
	var files: Array = compiled.value.files() if compiled.success else []
	var runtime_layer: Dictionary = _runtime_layer(runtime, "loop", "loop.static_texture")
	tests.expect_true(derived.success and derived.value.get("asset_logical_ids") == ["fx.headlight_beam_core"], "Schema-driven Export requirement derivation discovers TEXTURED_SPRITE texture_asset_ref")
	tests.expect_true(compiled.success and runtime_layer.get("type") == "TEXTURED_SPRITE" and runtime_layer.get("parameters") == {"texture_asset_ref": "fx.headlight_beam_core", "opacity": 0.65} and not JSON.stringify(runtime).contains("res://"), "Runtime Definition compile carries generic static texture data without a Studio path or renderer-specific conversion")
	tests.expect_true(dependencies.size() == 1 and dependencies[0].get("logical_id") == "fx.headlight_beam_core" and dependencies[0].get("package_path") == "assets/headlight_beam_core.png" and files.any(func(entry: Dictionary) -> bool: return entry.get("path") == "assets/headlight_beam_core.png"), "Compile-only Manifest inventory includes the one generic textured-sprite PNG dependency")


static func _test_generic_textured_sprite_rejects_missing_or_non_exportable_assets(tests: TestAssert) -> void:
	var compiler_result: VfxResult = _compiler()
	var preview_only_data := TexturedSpriteContractTests.preset_data()
	preview_only_data["phases"]["loop"]["layers"][0]["parameters"]["texture_asset_ref"] = "fx.preview_texture_fixture"
	var missing_data := TexturedSpriteContractTests.preset_data()
	missing_data["phases"]["loop"]["layers"][0]["parameters"]["texture_asset_ref"] = "fx.unregistered_texture"
	var pipeline := VfxPresetPipelineModel.new()
	var preview_only_document: VfxResult = pipeline.build_document_from_value(preview_only_data)
	var missing_document: VfxResult = pipeline.build_document_from_value(missing_data)
	var preview_only_compile: VfxResult = compiler_result.value.compile(preview_only_document.value) if compiler_result.success and preview_only_document.success else VfxResult.failure([])
	var missing_compile: VfxResult = compiler_result.value.compile(missing_document.value) if compiler_result.success and missing_document.success else VfxResult.failure([])
	tests.expect_true(not preview_only_compile.success and _has_code(preview_only_compile, "export_asset_not_allowed") and not missing_compile.success and _has_code(missing_compile, "export_asset_unregistered"), "Generic TEXTURED_SPRITE Export rejects both Preview-only and unregistered texture assets fail-closed")


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


static func _runtime_layer(runtime: Variant, phase_name: String, layer_id: String) -> Dictionary:
	if not runtime is Dictionary:
		return {}
	for phase in runtime.get("phases", []):
		if phase is Dictionary and phase.get("name") == phase_name:
			for layer in phase.get("layers", []):
				if layer is Dictionary and layer.get("id") == layer_id:
					return layer
	return {}


static func _has_code(result: VfxResult, code: String) -> bool:
	return result.issues.any(func(issue: VfxIssue) -> bool: return issue.code == code)
