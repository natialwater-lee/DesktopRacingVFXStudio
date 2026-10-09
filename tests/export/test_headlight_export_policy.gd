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
	_test_modulated_headlights_select_runtime_definition_v2(tests)
	_test_headlight_runtime_v2_preserves_portable_modulation_semantics(tests)
	_test_headlight_runtime_v2_preserves_final_readability_authoring(tests)


static func _test_modulated_headlights_select_runtime_definition_v2(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.headlights.vfx.json")
	var compiler_result := _compiler()
	if not document_result.success or not compiler_result.success:
		tests.expect_true(false, "Headlight export compile-only contract requires a valid Preset and configured compiler")
		return
	var compiled: VfxResult = compiler_result.value.compile(document_result.value)
	var plan: Variant = compiled.value if compiled.success else null
	var runtime: Variant = JSON.parse_string(compiled.value.runtime_text()) if compiled.success else null
	var manifest: Dictionary = compiled.value.manifest_data() if compiled.success else {}
	tests.expect_true(
		compiled.success and runtime is Dictionary and runtime.get("runtime_definition_version") == 2 \
		and manifest.get("runtime_definition", {}).get("version") == 2 \
		and manifest.get("runtime_definition", {}).get("path") == "runtime/vfx_runtime_definition_v2.json",
		"Modulation-bearing Headlights compile only to Runtime Definition v2; Package Format v1 points at the selected v2 runtime artifact"
	)
	tests.expect_true(
		plan != null and plan.has_method("runtime_definition_version") and plan.has_method("runtime_definition_path") \
		and plan.runtime_definition_version() == 2 and plan.runtime_definition_path() == "runtime/vfx_runtime_definition_v2.json" \
		and plan.text_files().has(plan.runtime_definition_path()),
		"Export Package Plan carries the compiler-selected v2 runtime version and relative path for the generic writer"
	)


static func _test_headlight_runtime_v2_preserves_portable_modulation_semantics(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.headlights.vfx.json")
	var compiler_result := _compiler()
	if not document_result.success or not compiler_result.success:
		tests.expect_true(false, "Headlight Runtime v2 semantic test requires a valid Preset and configured compiler")
		return
	var first: VfxResult = compiler_result.value.compile(document_result.value)
	var second: VfxResult = compiler_result.value.compile(document_result.value)
	var runtime: Variant = JSON.parse_string(first.value.runtime_text()) if first.success else null
	var manifest: Dictionary = first.value.manifest_data() if first.success else {}
	var source: Dictionary = document_result.value.normalized_data
	var expected_inputs := ["longitudinal_load"]
	tests.expect_true(
		first.success and second.success and first.value.runtime_text() == second.value.runtime_text() and first.value.manifest_text() == second.value.manifest_text(),
		"Runtime Definition v2 and its Manifest are byte-deterministic for the same saved modulated Headlight source"
	)
	tests.expect_true(
		runtime is Dictionary and runtime.get("runtime_modulation_sources") == source.get("runtime_modulation_sources") \
		and _runtime_input_names(runtime.get("runtime_inputs", [])) == expected_inputs \
		and manifest.get("requirements", {}).get("runtime_inputs") == expected_inputs,
		"Runtime Definition v2 and Manifest retain the declared portable modulation source and required Runtime Input inventory"
	)
	var semantic_match := runtime is Dictionary
	for phase_value in source.get("phases", {}).values():
		if not phase_value is Dictionary:
			semantic_match = false
			break
		for source_layer_value in phase_value.get("layers", []):
			if not source_layer_value is Dictionary:
				semantic_match = false
				break
			var source_layer: Dictionary = source_layer_value
			var runtime_layer := _runtime_layer_named(runtime, str(source_layer.get("id", "")))
			semantic_match = semantic_match and not runtime_layer.is_empty() \
				and runtime_layer.get("modulations") == source_layer.get("modulations") \
				and runtime_layer.get("modulation_clamps") == source_layer.get("modulation_clamps") \
				and runtime_layer.get("transform", {}).get("modulation_pivot_local") == source_layer.get("transform", {}).get("modulation_pivot_local")
	tests.expect_true(semantic_match, "Every Headlight runtime Layer preserves source-authored modulation bindings, target clamps, and local pivot declaratively")
	var purity_terms := ["res://", "C:\\", "DesktopRacingVFXStudio", "DesktopIdleRacing", "preview_time", "SpeedNormalizedSlider", "LongitudinalLoadSlider", "TurnRateSlider", "effective_state", "runtime_input_slot", "target_slot", "source_slot", "packet", "Studio Stress", "Preview Frame Time"]
	var pure := first.success
	for term in purity_terms:
		pure = pure and not first.value.runtime_text().contains(str(term))
	tests.expect_true(pure, "Runtime Definition v2 excludes Studio/session paths, compiled slots, packets, and performance state")


static func _test_headlight_runtime_v2_preserves_final_readability_authoring(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.headlights.vfx.json")
	var compiler_result := _compiler()
	if not document_result.success or not compiler_result.success:
		tests.expect_true(false, "Headlight final readability export requires a valid saved Preset and configured compiler")
		return
	var compiled: VfxResult = compiler_result.value.compile(document_result.value)
	var runtime: Variant = JSON.parse_string(compiled.value.runtime_text()) if compiled.success else null
	var matches := compiled.success and runtime is Dictionary
	for phase_name in document_result.value.normalized_data.get("phases", {}):
		var phase_value: Variant = document_result.value.normalized_data.get("phases", {}).get(phase_name)
		if not phase_value is Dictionary:
			matches = false
			continue
		for source_layer_value in phase_value.get("layers", []):
			if not source_layer_value is Dictionary:
				matches = false
				continue
			var source_layer: Dictionary = source_layer_value
			var runtime_layer := _runtime_layer_named(runtime, str(source_layer.get("id", "")))
			var is_soft := str(source_layer.get("id", "")).contains("soft")
			var transform: Dictionary = runtime_layer.get("transform", {}) if runtime_layer.get("transform", {}) is Dictionary else {}
			var source_transform: Dictionary = source_layer.get("transform", {})
			# Headlights v2 beams are uniform-scale ADDITIVE sprites (soft 2.4, core 2.0); the compiler must carry the authored offset untouched.
			matches = matches and _vector_matches(transform.get("scale", []), Vector2(2.4, 2.4) if is_soft else Vector2(2.0, 2.0)) \
				and _vector_matches(transform.get("offset", []), Vector2(float(source_transform.get("offset", [0, 0])[0]), float(source_transform.get("offset", [0, 0])[1]))) \
				and runtime_layer.get("blend_mode") == ("ALPHA" if is_soft else "ADDITIVE") \
				and _longitudinal_mapping_matches(runtime_layer.get("modulations", [])) \
				and _scale_y_clamp_matches(runtime_layer.get("modulation_clamps", []), is_soft, phase_name == "start")
	tests.expect_true(matches, "Runtime Definition v2 preserves the Headlights v2 uniform ADDITIVE beam geometry, authored bilateral offsets, longitudinal Scale Y response, and non-contacting safety clamps (START allows its ignition dip)")


static func _longitudinal_mapping_matches(modulations_value: Variant) -> bool:
	if not modulations_value is Array:
		return false
	for modulation_value in modulations_value:
		if not modulation_value is Dictionary:
			continue
		var modulation: Dictionary = modulation_value
		var source: Dictionary = modulation.get("source", {}) if modulation.get("source", {}) is Dictionary else {}
		var mapping: Dictionary = modulation.get("mapping", {}) if modulation.get("mapping", {}) is Dictionary else {}
		if modulation.get("target") == "TRANSFORM_SCALE_Y" and source.get("type") == "RUNTIME_INPUT" and source.get("input") == "longitudinal_load":
			return is_equal_approx(float(mapping.get("input_min", INF)), -1.0) \
				and is_equal_approx(float(mapping.get("input_max", INF)), 1.0) \
				and is_equal_approx(float(mapping.get("output_min", INF)), 0.85) \
				and is_equal_approx(float(mapping.get("output_max", INF)), 1.15)
	return false


static func _scale_y_clamp_matches(clamps_value: Variant, is_soft: bool, is_start: bool) -> bool:
	if not clamps_value is Array or clamps_value.size() != 1 or not clamps_value[0] is Dictionary:
		return false
	var clamp: Dictionary = clamps_value[0]
	var base := 2.4 if is_soft else 2.0
	var expected := Vector2(base * (0.50 if is_start else 0.75), base * 1.25)
	return clamp.get("target") == "TRANSFORM_SCALE_Y" \
		and absf(float(clamp.get("min_effective", INF)) - expected.x) <= 0.001 \
		and absf(float(clamp.get("max_effective", INF)) - expected.y) <= 0.001


static func _vector_matches(value: Variant, expected: Vector2) -> bool:
	return value is Array and value.size() == 2 \
		and is_equal_approx(float(value[0]), expected.x) and is_equal_approx(float(value[1]), expected.y)


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


static func _runtime_layers(runtime: Variant) -> Array:
	var result: Array = []
	if not runtime is Dictionary:
		return result
	for phase in runtime.get("phases", []):
		if phase is Dictionary:
			for layer in phase.get("layers", []):
				if layer is Dictionary:
					result.append(layer)
	return result


static func _runtime_input_names(inputs: Variant) -> Array[String]:
	var result: Array[String] = []
	if inputs is Array:
		for input_value in inputs:
			if input_value is Dictionary:
				result.append(str(input_value.get("name", "")))
	return result


static func _runtime_layer_named(runtime: Variant, layer_id: String) -> Dictionary:
	for layer_value in _runtime_layers(runtime):
		if layer_value is Dictionary and layer_value.get("id") == layer_id:
			return layer_value
	return {}
