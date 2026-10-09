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

const TEXTURE_IDS := [
	"fx.super_booster_jet_single", "fx.super_booster_jet_twin", "fx.super_booster_envelope", "fx.super_booster_flare",
	"fx.super_booster_charge_ring", "fx.super_booster_shock_arc", "fx.super_booster_bolt", "fx.super_booster_core_gold"
]
# preset id -> logical texture ids its Package must carry
const DEPENDENCIES := {
	"equipment.super_booster": ["fx.super_booster_bolt", "fx.super_booster_charge_ring", "fx.super_booster_envelope", "fx.super_booster_flare", "fx.super_booster_jet_single", "fx.super_booster_shock_arc"],
	"equipment.super_booster.dual": ["fx.super_booster_bolt", "fx.super_booster_charge_ring", "fx.super_booster_envelope", "fx.super_booster_flare", "fx.super_booster_jet_twin", "fx.super_booster_shock_arc"],
	"equipment.super_booster.mk4": ["fx.super_booster_bolt", "fx.super_booster_charge_ring", "fx.super_booster_core_gold", "fx.super_booster_envelope", "fx.super_booster_flare", "fx.super_booster_jet_twin", "fx.super_booster_shock_arc"]
}


static func run(tests: TestAssert) -> void:
	_test_textures_are_explicitly_exportable(tests)
	for preset_id in DEPENDENCIES:
		_test_compiles_to_runtime_definition_v2_without_writer(tests, preset_id)


static func _test_textures_are_explicitly_exportable(tests: TestAssert) -> void:
	var registry := VfxExportAssetRegistryModel.new()
	var loaded: VfxResult = registry.load()
	var matches: bool = loaded.success
	for logical_id in TEXTURE_IDS:
		var resolved: VfxResult = registry.resolve_exportable(logical_id) if loaded.success else VfxResult.failure(loaded.issues)
		var file_name: String = str(logical_id).trim_prefix("fx.")
		matches = matches and resolved.success and resolved.value.get("export_policy") == "EXPORTABLE" and resolved.value.get("kind") == "TEXTURE_PNG" \
			and resolved.value.get("source_path") == "res://assets/vfx/%s.png" % file_name \
			and resolved.value.get("package_file_name") == "%s.png" % file_name
	tests.expect_true(matches, "Super Booster v2 resolves its eight approved PNGs as explicitly exportable TEXTURE_PNG assets")


static func _test_compiles_to_runtime_definition_v2_without_writer(tests: TestAssert, preset_id: String) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/%s.vfx.json" % preset_id)
	var compiler_result := _compiler()
	if not document_result.success or not compiler_result.success:
		tests.expect_true(false, "%s export compile-only test requires a valid saved Preset and configured compiler" % preset_id)
		return
	var first: VfxResult = compiler_result.value.compile(document_result.value)
	var second: VfxResult = compiler_result.value.compile(document_result.value)
	var runtime: Variant = JSON.parse_string(first.value.runtime_text()) if first.success else null
	var manifest: Dictionary = first.value.manifest_data() if first.success else {}
	var dependencies: Array = manifest.get("asset_dependencies", [])
	var logical_ids := dependencies.map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	logical_ids.sort()
	var package_paths_ok: bool = dependencies.all(func(dependency: Dictionary) -> bool:
		return str(dependency.get("package_path", "")) == "assets/%s.png" % str(dependency.get("logical_id", "")).trim_prefix("fx."))
	var runtime_inputs: Array = runtime.get("runtime_inputs", []) if runtime is Dictionary else []
	var sources: Array = runtime.get("runtime_modulation_sources", []) if runtime is Dictionary else []
	var clock_ok := false
	for source in sources:
		clock_ok = clock_ok or (source.get("id") == "time.clock" and source.get("type") == "LINEAR_PHASE" and is_equal_approx(float(source.get("frequency_hz", 0.0)), 0.05))
	var bend_layers := 0
	var bend_ok := true
	if runtime is Dictionary:
		for phase_value in runtime.get("phases", []):
			for layer_value in phase_value.get("layers", []):
				if layer_value.has("visual_bend"):
					bend_layers += 1
					bend_ok = bend_ok and layer_value["visual_bend"].get("axis") == "LOCAL_Y_POSITIVE" and layer_value.get("modulation_clamps", []).size() == 1
	tests.expect_true(
		first.success and second.success and first.value.runtime_text() == second.value.runtime_text() \
		and runtime is Dictionary and runtime.get("runtime_definition_version") == 2 \
		and manifest.get("runtime_definition", {}).get("version") == 2 \
		and manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json" \
		and runtime_inputs == [{"name": "turn_rate_normalized", "value_type": "number", "default": 0.0, "minimum": -1.0, "maximum": 1.0}] \
		and manifest.get("requirements", {}).get("runtime_inputs", []) == ["turn_rate_normalized"] \
		and clock_ok and logical_ids == DEPENDENCIES[preset_id] and package_paths_ok \
		and bend_layers > 0 and bend_ok and not first.value.runtime_text().contains("res://"),
		"%s compile-only output is deterministic Runtime Definition v2 with the one-shot clock source, bendable flame layers and exactly its own texture dependencies" % preset_id
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
