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
	_test_assets_are_exportable(tests)
	_test_preset_compiles_to_v2_with_exact_dependencies(tests)


static func _test_assets_are_exportable(tests: TestAssert) -> void:
	var registry := VfxExportAssetRegistryModel.new()
	var loaded := registry.load()
	var matches := loaded.success
	for name in ["air_ring", "mist_puff"]:
		var resolved: VfxResult = registry.resolve_exportable("fx.rotor_lift_%s" % name) if loaded.success else VfxResult.failure(loaded.issues)
		matches = matches and resolved.success and resolved.value.get("source_path") == "res://assets/vfx/rotor_lift_%s.png" % name and resolved.value.get("package_file_name") == "rotor_lift_%s.png" % name
	tests.expect_true(matches, "Rotor Lift registers its two R5 PNGs (air ring, mist puff) as explicit portable export dependencies")


static func _test_preset_compiles_to_v2_with_exact_dependencies(tests: TestAssert) -> void:
	var document := VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.rotor_lift.downwash.vfx.json")
	var compiler := _compiler()
	var first: VfxResult = compiler.value.compile(document.value) if document.success and compiler.success else VfxResult.failure([])
	var second: VfxResult = compiler.value.compile(document.value) if document.success and compiler.success else VfxResult.failure([])
	var runtime: Variant = JSON.parse_string(first.value.runtime_text()) if first.success else null
	var manifest: Dictionary = first.value.manifest_data() if first.success else {}
	var dependencies: Array = manifest.get("asset_dependencies", []) if manifest.get("asset_dependencies", []) is Array else []
	var ids := dependencies.map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	var sources: Array = runtime.get("runtime_modulation_sources", []) if runtime is Dictionary else []
	var source_ids := sources.map(func(source: Dictionary) -> String: return str(source.get("id", "")) if source.get("type") == "LINEAR_PHASE" and not source.has("phase_degrees") else "")
	var loop_ids := (_phase_layers(runtime, "loop") if runtime is Dictionary else []).map(func(layer: Dictionary) -> String: return str(layer.get("id", "")))
	tests.expect_true(first.success and second.success and first.value.runtime_text() == second.value.runtime_text() and runtime is Dictionary and runtime.get("runtime_definition_version") == 2 and manifest.get("package_format_version") == 1 and manifest.get("runtime_definition", {}).get("version") == 2 and manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json" and ids == ["fx.rotor_lift_air_ring", "fx.rotor_lift_mist_puff"] and not JSON.stringify(runtime).contains("res://") and runtime.get("runtime_inputs") == [] and source_ids == ["rotor.burst.phase"] and loop_ids.has("loop.left_rings") and loop_ids.has("loop.right_mist") and not JSON.stringify(runtime).contains("vfx_runtime_definition_v1"), "Rotor Lift R5 deterministically compiles to Runtime Definition v2 with Game-portable LINEAR_PHASE sources (no phase offset), Package Format v1, and only its two R5 PNG dependencies")


static func _phase_layers(runtime: Dictionary, phase_name: String) -> Array:
	var phases: Variant = runtime.get("phases", [])
	if not phases is Array:
		return []
	for phase in phases:
		if phase is Dictionary and phase.get("name") == phase_name:
			var layers: Variant = phase.get("layers", [])
			return layers if layers is Array else []
	return []


static func _compiler() -> VfxResult:
	var assets := VfxExportAssetRegistryModel.new()
	var policy := VfxExportPresetPolicyModel.new()
	var coordinate_contract := VfxExportCoordinateContractModel.new()
	var assets_loaded := assets.load()
	var policy_loaded := policy.load()
	var contract_loaded := coordinate_contract.load()
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
