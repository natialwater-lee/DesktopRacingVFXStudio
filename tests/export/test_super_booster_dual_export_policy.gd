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
	_test_dual_compiles_to_one_v2_runtime_and_three_deduplicated_assets(tests)


static func _test_dual_compiles_to_one_v2_runtime_and_three_deduplicated_assets(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.super_booster.dual.vfx.json")
	var compiler_result := _compiler()
	if not document_result.success or not compiler_result.success:
		tests.expect_true(false, "Dual Super Booster export compile-only regression requires its saved Preset and configured compiler.")
		return
	var first: VfxResult = compiler_result.value.compile(document_result.value)
	var second: VfxResult = compiler_result.value.compile(document_result.value)
	var runtime: Variant = JSON.parse_string(first.value.runtime_text()) if first.success else null
	var manifest: Dictionary = first.value.manifest_data() if first.success else {}
	var dependencies: Array = manifest.get("asset_dependencies", [])
	var logical_ids := dependencies.map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	var paths := dependencies.map(func(dependency: Dictionary) -> String: return str(dependency.get("package_path", "")))
	var runtime_sources: Array = runtime.get("runtime_modulation_sources", []) if runtime is Dictionary else []
	var left_core: Dictionary = _runtime_layer(runtime, "loop", "loop.left_core_flame")
	var right_core: Dictionary = _runtime_layer(runtime, "loop", "loop.right_core_flame")
	var left_soft: Dictionary = _runtime_layer(runtime, "loop", "loop.left_soft_flame")
	var right_soft: Dictionary = _runtime_layer(runtime, "loop", "loop.right_soft_flame")
	var left_spark: Dictionary = _runtime_layer(runtime, "loop", "loop.left_energy_spark_accent")
	var right_spark: Dictionary = _runtime_layer(runtime, "loop", "loop.right_energy_spark_accent")
	var geometry_matches: bool = _vector_matches(left_core.get("transform", {}).get("scale", []), Vector2(0.33, 1.14)) \
		and _vector_matches(right_core.get("transform", {}).get("scale", []), Vector2(0.33, 1.14)) \
		and _vector_matches(left_soft.get("transform", {}).get("scale", []), Vector2(0.76, 1.35)) \
		and _vector_matches(right_soft.get("transform", {}).get("scale", []), Vector2(0.76, 1.35)) \
		and _vector_matches(left_core.get("transform", {}).get("offset", []), Vector2(-60.0, 241.34)) \
		and _vector_matches(right_core.get("transform", {}).get("offset", []), Vector2(60.0, 241.34)) \
		and _vector_matches(left_soft.get("transform", {}).get("offset", []), Vector2(-59.62, 282.05)) \
		and _vector_matches(right_soft.get("transform", {}).get("offset", []), Vector2(60.38, 282.05)) \
		and _vector_matches(left_spark.get("transform", {}).get("offset", []), Vector2(-60.0, 295.0)) \
		and _vector_matches(right_spark.get("transform", {}).get("offset", []), Vector2(60.0, 295.0))
	tests.expect_true(
		first.success and second.success and first.value.runtime_text() == second.value.runtime_text() \
		and runtime is Dictionary and runtime.get("preset", {}).get("preset_id") == "equipment.super_booster.dual" and runtime.get("runtime_definition_version") == 2 \
		and manifest.get("runtime_definition", {}).get("version") == 2 and manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json" \
		and runtime_sources.size() == 1 and runtime_sources[0].get("id") == "flame.pulse" \
		and logical_ids == ["fx.super_booster_flame_core", "fx.super_booster_flame_soft", "fx.super_booster_spark_blue"] \
		and paths == ["assets/super_booster_flame_core.png", "assets/super_booster_flame_soft.png", "assets/super_booster_spark_blue.png"] \
		and geometry_matches and not logical_ids.has("fx.energy_spark") and not first.value.runtime_text().contains("res://"),
		"Dual Super Booster compile-only export deterministically carries its full-size geometry to widened and rear-shifted roots while deduplicating Core, Soft, and blue-spark PNG dependencies"
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


static func _runtime_layer(runtime: Variant, phase_name: String, layer_id: String) -> Dictionary:
	if not runtime is Dictionary:
		return {}
	var phases: Array = runtime.get("phases", []) if runtime.get("phases", []) is Array else []
	for phase_value in phases:
		if not phase_value is Dictionary or str(phase_value.get("name", "")) != phase_name:
			continue
		var layers: Array = phase_value.get("layers", []) if phase_value.get("layers", []) is Array else []
		for layer_value in layers:
			if layer_value is Dictionary and str(layer_value.get("id", "")) == layer_id:
				return layer_value
	return {}


static func _vector_matches(value: Variant, expected: Vector2) -> bool:
	return value is Array and value.size() == 2 and is_equal_approx(float(value[0]), expected.x) and is_equal_approx(float(value[1]), expected.y)
