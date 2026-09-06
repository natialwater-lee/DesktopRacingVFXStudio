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
	_test_rotating_preset_compiles_to_v2_with_exact_dependencies(tests)


static func _test_assets_are_exportable(tests: TestAssert) -> void:
	var registry := VfxExportAssetRegistryModel.new()
	var loaded := registry.load()
	var core := registry.resolve_exportable("fx.rotor_lift_downwash_core") if loaded.success else VfxResult.failure(loaded.issues)
	var soft := registry.resolve_exportable("fx.rotor_lift_downwash_soft") if loaded.success else VfxResult.failure(loaded.issues)
	var particle := registry.resolve_exportable("fx.rotor_lift_turbulence_particle") if loaded.success else VfxResult.failure(loaded.issues)
	tests.expect_true(loaded.success and core.success and soft.success and particle.success and core.value.get("source_path") == "res://assets/vfx/rotor_lift_downwash_core.png" and soft.value.get("source_path") == "res://assets/vfx/rotor_lift_downwash_soft.png" and particle.value.get("source_path") == "res://assets/vfx/rotor_lift_turbulence_particle.png" and core.value.get("package_file_name") == "rotor_lift_downwash_core.png" and soft.value.get("package_file_name") == "rotor_lift_downwash_soft.png" and particle.value.get("package_file_name") == "rotor_lift_turbulence_particle.png", "Rotor Lift registers its three user-supplied PNGs as explicit portable export dependencies")


static func _test_rotating_preset_compiles_to_v2_with_exact_dependencies(tests: TestAssert) -> void:
	var document := VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.rotor_lift.downwash.vfx.json")
	var compiler := _compiler()
	var first: VfxResult = compiler.value.compile(document.value) if document.success and compiler.success else VfxResult.failure([])
	var second: VfxResult = compiler.value.compile(document.value) if document.success and compiler.success else VfxResult.failure([])
	var runtime: Variant = JSON.parse_string(first.value.runtime_text()) if first.success else null
	var manifest: Dictionary = first.value.manifest_data() if first.success else {}
	var dependencies: Array = manifest.get("asset_dependencies", []) if manifest.get("asset_dependencies", []) is Array else []
	var ids := dependencies.map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	var expected_sources: Array = [
		{"id": "rotor.core.phase", "type": "LINEAR_PHASE", "frequency_hz": 2.4},
		{"id": "rotor.soft.phase", "type": "LINEAR_PHASE", "frequency_hz": 1.35},
		{"id": "rotor.left_soft.pressure", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 1.1, "phase_degrees": 0.0},
		{"id": "rotor.right_soft.pressure", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 1.1, "phase_degrees": 90.0}
	]
	var loop_layers := _phase_layers(runtime, "loop") if runtime is Dictionary else []
	var loop_ids := loop_layers.map(func(layer: Dictionary) -> String: return str(layer.get("id", "")))
	var core_is_persistent := loop_ids.has("loop.left_core_spin") and loop_ids.has("loop.right_core_spin") and not loop_ids.has("loop.left_core_pressure_sheet") and not loop_ids.has("loop.right_core_pressure_sheet")
	tests.expect_true(first.success and second.success and first.value.runtime_text() == second.value.runtime_text() and runtime is Dictionary and runtime.get("runtime_definition_version") == 2 and manifest.get("package_format_version") == 1 and manifest.get("runtime_definition", {}).get("version") == 2 and manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json" and ids == ["fx.rotor_lift_downwash_core", "fx.rotor_lift_downwash_soft", "fx.rotor_lift_turbulence_particle"] and not JSON.stringify(runtime).contains("res://") and runtime.get("runtime_inputs") == [] and runtime.get("runtime_modulation_sources") == expected_sources and core_is_persistent and not JSON.stringify(runtime).contains("vfx_runtime_definition_v1"), "Rotor Lift R3.1 deterministically compiles to Runtime Definition v2 with faster reversed LINEAR_PHASE and portable phase-shifted SINE sources, persistent Core sprites, Package Format v1, and only its three PNG dependencies")


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
