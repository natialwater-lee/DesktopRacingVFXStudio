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
	var spark: VfxResult = registry.resolve_exportable("fx.super_booster_spark_blue") if loaded.success else VfxResult.failure(loaded.issues)
	tests.expect_true(
		loaded.success and core.success and soft.success and spark.success \
		and core.value.get("export_policy") == "EXPORTABLE" and soft.value.get("export_policy") == "EXPORTABLE" and spark.value.get("export_policy") == "EXPORTABLE" \
		and core.value.get("kind") == "TEXTURE_PNG" and soft.value.get("kind") == "TEXTURE_PNG" and spark.value.get("kind") == "TEXTURE_PNG" \
		and core.value.get("source_path") == "res://assets/vfx/fx.super_booster_flame_core.png" \
		and soft.value.get("source_path") == "res://assets/vfx/fx.super_booster_flame_soft.png" \
		and spark.value.get("source_path") == "res://assets/vfx/super_booster_spark_blue.png" \
		and core.value.get("package_file_name") == "super_booster_flame_core.png" \
		and soft.value.get("package_file_name") == "super_booster_flame_soft.png" \
		and spark.value.get("package_file_name") == "super_booster_spark_blue.png",
		"Super Booster resolves its dedicated exportable blue-spark PNG alongside the supplied Core and Soft flame PNGs"
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
	var runtime_inputs: Array = runtime.get("runtime_inputs", []) if runtime is Dictionary else []
	var loop_core: Dictionary = _runtime_layer(runtime, "loop", "loop.core_flame")
	var loop_soft: Dictionary = _runtime_layer(runtime, "loop", "loop.soft_flame")
	var loop_spark: Dictionary = _runtime_layer(runtime, "loop", "loop.energy_spark_accent")
	var geometry_matches: bool = _vector_matches(loop_core.get("transform", {}).get("scale", []), Vector2(0.3795, 1.311)) \
		and _vector_matches(loop_core.get("transform", {}).get("offset", []), Vector2(0.0, 272.291)) \
		and _vector_matches(loop_soft.get("transform", {}).get("scale", []), Vector2(0.874, 1.5525)) \
		and _vector_matches(loop_soft.get("transform", {}).get("offset", []), Vector2(0.437, 319.1075)) \
		and _vector_matches(loop_spark.get("transform", {}).get("offset", []), Vector2(0.0, 295.0))
	var turn_contract_matches := _turn_rotation_contract_matches(runtime)
	tests.expect_true(
		first.success and second.success and first.value.runtime_text() == second.value.runtime_text() \
		and runtime is Dictionary and runtime.get("runtime_definition_version") == 2 \
		and manifest.get("runtime_definition", {}).get("version") == 2 \
		and manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json" \
		and runtime_inputs == [{"name": "turn_rate_normalized", "value_type": "number", "default": 0.0, "minimum": -1.0, "maximum": 1.0}] \
		and manifest.get("requirements", {}).get("runtime_inputs", []) == ["turn_rate_normalized"] \
		and runtime_sources.size() == 1 and runtime_sources[0].get("id") == "flame.pulse" \
		and logical_ids == ["fx.super_booster_flame_core", "fx.super_booster_flame_soft", "fx.super_booster_spark_blue"] \
		and paths == ["assets/super_booster_flame_core.png", "assets/super_booster_flame_soft.png", "assets/super_booster_spark_blue.png"] \
		and geometry_matches and turn_contract_matches and not first.value.runtime_text().contains("res://"),
		"Super Booster compile-only output deterministically carries the saturated 0.20 signed turn-rate rotation contract, existing pulse source, and three texture dependencies into Runtime Definition v2"
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


static func _turn_rotation_contract_matches(runtime: Variant) -> bool:
	var matches := true
	for phase_name in ["start", "loop", "end"]:
		var suffix := "flame" if phase_name == "loop" else "ignition" if phase_name == "start" else "fade"
		matches = matches and _runtime_turn_layer_matches(_runtime_layer(runtime, phase_name, "%s.core_%s" % [phase_name, suffix]), "%s.core.turn.rotation" % phase_name, 3.0, -3.0) \
			and _runtime_turn_layer_matches(_runtime_layer(runtime, phase_name, "%s.soft_%s" % [phase_name, suffix]), "%s.soft.turn.rotation" % phase_name, 6.0, -6.0)
	return matches


static func _runtime_turn_layer_matches(layer: Dictionary, binding_id: String, output_min: float, output_max: float) -> bool:
	var bindings: Array = layer.get("modulations", []) if layer.get("modulations", []) is Array else []
	var matches := 0
	for binding_value in bindings:
		if not binding_value is Dictionary or str(binding_value.get("id", "")) != binding_id:
			continue
		var binding: Dictionary = binding_value
		var source: Dictionary = binding.get("source", {}) if binding.get("source", {}) is Dictionary else {}
		var mapping: Dictionary = binding.get("mapping", {}) if binding.get("mapping", {}) is Dictionary else {}
		if binding.get("target") == "TRANSFORM_ROTATION_DEGREES" and binding.get("operation") == "ADD" \
			and source == {"type": "RUNTIME_INPUT", "input": "turn_rate_normalized"} and mapping.get("type") == "LINEAR_RANGE" \
			and is_equal_approx(float(mapping.get("input_min", INF)), -0.20) and is_equal_approx(float(mapping.get("input_max", INF)), 0.20) \
			and is_equal_approx(float(mapping.get("output_min", INF)), output_min) and is_equal_approx(float(mapping.get("output_max", INF)), output_max):
			matches += 1
	var clamps: Array = layer.get("modulation_clamps", []) if layer.get("modulation_clamps", []) is Array else []
	var rotation_clamps: Array = clamps.filter(func(clamp: Variant) -> bool: return clamp is Dictionary and clamp.get("target") == "TRANSFORM_ROTATION_DEGREES")
	return matches == 1 and rotation_clamps.size() == 1 \
		and is_equal_approx(float(rotation_clamps[0].get("min_effective", INF)), output_max) \
		and is_equal_approx(float(rotation_clamps[0].get("max_effective", INF)), output_min)


static func _vector_matches(value: Variant, expected: Vector2) -> bool:
	return value is Array and value.size() == 2 and is_equal_approx(float(value[0]), expected.x) and is_equal_approx(float(value[1]), expected.y)
