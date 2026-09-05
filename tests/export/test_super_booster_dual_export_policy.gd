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
	var runtime_inputs: Array = runtime.get("runtime_inputs", []) if runtime is Dictionary else []
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
		and _vector_matches(left_core.get("transform", {}).get("offset", []), Vector2(-60.0, 265.34)) \
		and _vector_matches(right_core.get("transform", {}).get("offset", []), Vector2(60.0, 265.34)) \
		and _vector_matches(left_soft.get("transform", {}).get("offset", []), Vector2(-59.62, 306.05)) \
		and _vector_matches(right_soft.get("transform", {}).get("offset", []), Vector2(60.38, 306.05)) \
		and _vector_matches(left_spark.get("transform", {}).get("offset", []), Vector2(-60.0, 319.0)) \
		and _vector_matches(right_spark.get("transform", {}).get("offset", []), Vector2(60.0, 319.0))
	var turn_contract_matches := _turn_bend_contract_matches(runtime)
	tests.expect_true(
		first.success and second.success and first.value.runtime_text() == second.value.runtime_text() \
		and runtime is Dictionary and runtime.get("preset", {}).get("preset_id") == "equipment.super_booster.dual" and runtime.get("runtime_definition_version") == 2 \
		and manifest.get("runtime_definition", {}).get("version") == 2 and manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json" \
		and runtime_inputs == [{"name": "turn_rate_normalized", "value_type": "number", "default": 0.0, "minimum": -1.0, "maximum": 1.0}] \
		and manifest.get("requirements", {}).get("runtime_inputs", []) == ["turn_rate_normalized"] \
		and runtime_sources.size() == 1 and runtime_sources[0].get("id") == "flame.pulse" \
		and logical_ids == ["fx.super_booster_flame_core", "fx.super_booster_flame_soft", "fx.super_booster_spark_blue"] \
		and paths == ["assets/super_booster_flame_core.png", "assets/super_booster_flame_soft.png", "assets/super_booster_spark_blue.png"] \
		and geometry_matches and turn_contract_matches and not logical_ids.has("fx.energy_spark") and not first.value.runtime_text().contains("res://"),
		"Dual Super Booster compile-only export preserves the saturated 0.20 shared turn-rate bend contract at widened rear-shifted roots while deduplicating Core, Soft, and blue-spark PNG dependencies"
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


static func _turn_bend_contract_matches(runtime: Variant) -> bool:
	var matches := true
	for phase_name in ["start", "loop", "end"]:
		var suffix := "flame" if phase_name == "loop" else "ignition" if phase_name == "start" else "fade"
		for side in ["left", "right"]:
			matches = matches and _runtime_turn_layer_matches(_runtime_layer(runtime, phase_name, "%s.%s_core_%s" % [phase_name, side, suffix]), "%s.%s_core.turn.bend" % [phase_name, side], -102.0904551776, 102.0904551776) \
				and _runtime_turn_layer_matches(_runtime_layer(runtime, phase_name, "%s.%s_soft_%s" % [phase_name, side, suffix]), "%s.%s_soft.turn.bend" % [phase_name, side], -178.5185009320, 178.5185009320)
	return matches


static func _runtime_turn_layer_matches(layer: Dictionary, binding_id: String, output_min: float, output_max: float) -> bool:
	var span := 365.0 if binding_id.contains("core") else 375.0
	if layer.get("visual_bend") != {"axis": "LOCAL_Y_POSITIVE", "start_ratio": 0.333333333, "curve": "QUADRATIC", "span_source_px": span}:
		return false
	var bindings: Array = layer.get("modulations", []) if layer.get("modulations", []) is Array else []
	if bindings.any(func(b: Dictionary) -> bool: return b.get("target") == "TRANSFORM_ROTATION_DEGREES"):
		return false
	var matches := 0
	for binding_value in bindings:
		if not binding_value is Dictionary or str(binding_value.get("id", "")) != binding_id:
			continue
		var binding: Dictionary = binding_value
		var source: Dictionary = binding.get("source", {}) if binding.get("source", {}) is Dictionary else {}
		var mapping: Dictionary = binding.get("mapping", {}) if binding.get("mapping", {}) is Dictionary else {}
		if binding.get("target") == "VISUAL_BEND_OFFSET_X" and binding.get("operation") == "ADD" \
			and source == {"type": "RUNTIME_INPUT", "input": "turn_rate_normalized"} and mapping.get("type") == "LINEAR_RANGE" \
			and is_equal_approx(float(mapping.get("input_min", INF)), -0.20) and is_equal_approx(float(mapping.get("input_max", INF)), 0.20) \
			and is_equal_approx(float(mapping.get("output_min", INF)), output_min) and is_equal_approx(float(mapping.get("output_max", INF)), output_max):
			matches += 1
	var clamps: Array = layer.get("modulation_clamps", []) if layer.get("modulation_clamps", []) is Array else []
	var rotation_clamps: Array = clamps.filter(func(clamp: Variant) -> bool: return clamp is Dictionary and clamp.get("target") == "VISUAL_BEND_OFFSET_X")
	return matches == 1 and rotation_clamps.size() == 1 \
		and is_equal_approx(float(rotation_clamps[0].get("min_effective", INF)), output_min) \
		and is_equal_approx(float(rotation_clamps[0].get("max_effective", INF)), output_max)


static func _vector_matches(value: Variant, expected: Vector2) -> bool:
	return value is Array and value.size() == 2 and is_equal_approx(float(value[0]), expected.x) and is_equal_approx(float(value[1]), expected.y)
