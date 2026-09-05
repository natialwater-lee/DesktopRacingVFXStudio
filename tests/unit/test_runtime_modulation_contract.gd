extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxSchemaSubsetValidatorModel := preload("res://src/model/vfx_schema_subset_validator.gd")
const VfxPresetNormalizerModel := preload("res://src/model/vfx_preset_normalizer.gd")
const VfxContractValidatorModel := preload("res://src/model/vfx_contract_validator.gd")
const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")


static func run(tests: TestAssert) -> void:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	var loaded := registry.load("res://schemas/vfx_schema_v1.json")
	tests.expect_true(loaded.success, "runtime modulation contract requires a valid Schema registry")
	if not loaded.success:
		return

	var valid := _validate(registry, _valid_preset())
	tests.expect_true(valid.success, "valid TEXTURED_SPRITE runtime modulation contract validates")
	if valid.success:
		var normalized: Dictionary = valid.value
		var layer: Dictionary = normalized["phases"]["one_shot"]["layers"][0]
		tests.expect_true(normalized["runtime_modulation_sources"] is Array and normalized["runtime_modulation_sources"].size() == 1, "source table is retained")
		tests.expect_true(layer["modulations"] is Array and layer["modulations"].size() == 1, "Layer bindings are retained")
		tests.expect_true(layer["modulation_clamps"] is Array and layer["modulation_clamps"].size() == 1, "Layer target clamps are retained")
		tests.expect_true(layer["transform"]["modulation_pivot_local"] == [0.0, 0.0], "pivot defaults from Schema")

	var turn_rate_rotation := _valid_preset()
	turn_rate_rotation["runtime_inputs"].append("turn_rate_normalized")
	turn_rate_rotation["phases"]["one_shot"]["layers"][0]["modulations"] = [{
		"id": "rotation.by.turn_rate",
		"target": "TRANSFORM_ROTATION_DEGREES",
		"operation": "ADD",
		"source": {"type": "RUNTIME_INPUT", "input": "turn_rate_normalized"},
		"mapping": {"type": "LINEAR_RANGE", "input_min": -1.0, "input_max": 1.0, "output_min": -12.0, "output_max": 12.0}
	}]
	tests.expect_true(_validate(registry, turn_rate_rotation).success, "declared signed turn-rate input validates for existing TEXTURED_SPRITE rotation ADD modulation")

	var contract: VfxResult = registry.runtime_modulation_contract()
	tests.expect_true(contract.success, "registry exposes the Schema-owned runtime modulation contract")
	if contract.success:
		var target_contracts: Dictionary = contract.value["target_contracts"]
		tests.expect_true(target_contracts["TRANSFORM_SCALE_Y"]["compatible_layer_types"] == ["TEXTURED_SPRITE"], "target compatibility is Schema-owned and TEXTURED_SPRITE-only")
		tests.expect_true(
			target_contracts.has("VISUAL_BEND_OFFSET_X")
				and target_contracts["VISUAL_BEND_OFFSET_X"].get("operation") == "ADD"
				and target_contracts["VISUAL_BEND_OFFSET_X"].get("compatible_layer_types") == ["TEXTURED_SPRITE"]
				and target_contracts["VISUAL_BEND_OFFSET_X"].get("requires_static_field") == "visual_bend"
				and target_contracts["VISUAL_BEND_OFFSET_X"].get("requires_target_clamp") == true,
			"visual bend target is Schema-owned, additive, TEXTURED_SPRITE-only, and requires metadata plus a clamp"
		)

	var valid_bend := _valid_bend_preset()
	var valid_bend_result := _validate(registry, valid_bend)
	tests.expect_true(valid_bend_result.success, "valid TEXTURED_SPRITE visual bend metadata and ADD binding validate")
	if valid_bend_result.success:
		var bend_layer: Dictionary = valid_bend_result.value["phases"]["one_shot"]["layers"][0]
		tests.expect_true(
			bend_layer.get("visual_bend") == {
				"axis": "LOCAL_Y_POSITIVE",
				"start_ratio": 0.333333,
				"curve": "QUADRATIC",
				"span_source_px": 240.0
			},
			"valid visual bend metadata survives normalization and validation"
		)

	var bend_pipeline := VfxPresetPipelineModel.new()
	var bend_document := bend_pipeline.build_document_from_value(_valid_bend_preset(), "res://tests/fixtures/presets/utility.visual_bend_round_trip.vfx.json")
	var bend_serialized: VfxResult = bend_pipeline.serialize_document(bend_document.value) if bend_document.success else VfxResult.failure(bend_document.issues)
	var bend_decoded: VfxResult = VfxPresetCodecModel.new().decode_text(bend_serialized.value, "res://tests/fixtures/presets/utility.visual_bend_round_trip.vfx.json") if bend_serialized.success else VfxResult.failure(bend_serialized.issues)
	var bend_reloaded: VfxResult = bend_pipeline.build_document_from_value(bend_decoded.value, "res://tests/fixtures/presets/utility.visual_bend_round_trip.vfx.json") if bend_decoded.success else VfxResult.failure(bend_decoded.issues)
	var round_trip_layer: Dictionary = bend_reloaded.value.normalized_data["phases"]["one_shot"]["layers"][0] if bend_reloaded.success else {}
	tests.expect_true(
		bend_reloaded.success \
			and round_trip_layer.get("visual_bend") == _valid_bend_preset()["phases"]["one_shot"]["layers"][0]["visual_bend"] \
			and round_trip_layer.get("modulations") == _valid_bend_preset()["phases"]["one_shot"]["layers"][0]["modulations"] \
			and round_trip_layer.get("modulation_clamps") == _valid_bend_preset()["phases"]["one_shot"]["layers"][0]["modulation_clamps"],
		"Visual Bend metadata, binding, and clamp survive Pipeline save/load round-trip"
	)

	var invalid_axis := _valid_bend_preset()
	invalid_axis["phases"]["one_shot"]["layers"][0]["visual_bend"]["axis"] = "LOCAL_X"
	tests.expect_true(not _validate(registry, invalid_axis).success, "unsupported visual bend axis is rejected")

	var invalid_curve := _valid_bend_preset()
	invalid_curve["phases"]["one_shot"]["layers"][0]["visual_bend"]["curve"] = "CUBIC"
	tests.expect_true(not _validate(registry, invalid_curve).success, "unsupported visual bend curve is rejected")

	var negative_ratio := _valid_bend_preset()
	negative_ratio["phases"]["one_shot"]["layers"][0]["visual_bend"]["start_ratio"] = -0.01
	tests.expect_true(not _validate(registry, negative_ratio).success, "negative visual bend start ratio is rejected")

	var terminal_ratio := _valid_bend_preset()
	terminal_ratio["phases"]["one_shot"]["layers"][0]["visual_bend"]["start_ratio"] = 1.0
	tests.expect_true(_has_code(_validate(registry, terminal_ratio), "visual_bend_start_ratio"), "visual bend start ratio of one is rejected")

	var nonfinite_ratio := _valid_bend_preset()
	nonfinite_ratio["phases"]["one_shot"]["layers"][0]["visual_bend"]["start_ratio"] = NAN
	tests.expect_true(_has_code(_validate(registry, nonfinite_ratio), "visual_bend_start_ratio"), "non-finite visual bend start ratio is rejected")

	var zero_span := _valid_bend_preset()
	zero_span["phases"]["one_shot"]["layers"][0]["visual_bend"]["span_source_px"] = 0.0
	tests.expect_true(_has_code(_validate(registry, zero_span), "visual_bend_span_source_px"), "zero visual bend span is rejected")

	var negative_span := _valid_bend_preset()
	negative_span["phases"]["one_shot"]["layers"][0]["visual_bend"]["span_source_px"] = -1.0
	tests.expect_true(not _validate(registry, negative_span).success, "negative visual bend span is rejected")

	var nonfinite_span := _valid_bend_preset()
	nonfinite_span["phases"]["one_shot"]["layers"][0]["visual_bend"]["span_source_px"] = INF
	tests.expect_true(_has_code(_validate(registry, nonfinite_span), "visual_bend_span_source_px"), "non-finite visual bend span is rejected")

	var bend_without_metadata := _valid_bend_preset()
	bend_without_metadata["phases"]["one_shot"]["layers"][0].erase("visual_bend")
	tests.expect_true(_has_code(_validate(registry, bend_without_metadata), "runtime_modulation_target_requires_static_field"), "visual bend target without visual bend metadata is rejected")

	var bend_wrong_operation := _valid_bend_preset()
	bend_wrong_operation["phases"]["one_shot"]["layers"][0]["modulations"][0]["operation"] = "MULTIPLY"
	tests.expect_true(_has_code(_validate(registry, bend_wrong_operation), "runtime_modulation_operation"), "visual bend target rejects non-ADD operation")

	var bend_without_clamp := _valid_bend_preset()
	bend_without_clamp["phases"]["one_shot"]["layers"][0]["modulation_clamps"] = []
	tests.expect_true(_has_code(_validate(registry, bend_without_clamp), "runtime_modulation_target_clamp_required"), "visual bend target requires an explicit target clamp")

	var bend_nonfinite_mapping := _valid_bend_preset()
	bend_nonfinite_mapping["phases"]["one_shot"]["layers"][0]["modulations"][0]["mapping"]["output_max"] = NAN
	tests.expect_true(_has_code(_validate(registry, bend_nonfinite_mapping), "runtime_modulation_mapping_nonfinite"), "visual bend mapping values must be finite")

	var bend_on_glow := _valid_bend_preset()
	bend_on_glow["phases"]["one_shot"]["layers"][0]["type"] = "GLOW"
	bend_on_glow["phases"]["one_shot"]["layers"][0]["parameters"] = _parameters_for("GLOW")
	tests.expect_true(_has_code(_validate(registry, bend_on_glow), "visual_bend_layer_type_incompatible"), "visual bend metadata on a non-TEXTURED_SPRITE Layer is rejected")

	var duplicate_source := _valid_preset()
	duplicate_source["runtime_modulation_sources"].append(duplicate_source["runtime_modulation_sources"][0].duplicate(true))
	tests.expect_true(_has_code(_validate(registry, duplicate_source), "runtime_modulation_duplicate_source_id"), "duplicate source id is rejected")

	var duplicate_binding := _valid_preset()
	duplicate_binding["phases"]["one_shot"]["layers"][0]["modulations"].append(duplicate_binding["phases"]["one_shot"]["layers"][0]["modulations"][0].duplicate(true))
	tests.expect_true(_has_code(_validate(registry, duplicate_binding), "runtime_modulation_duplicate_binding_id"), "duplicate binding id is rejected")

	var duplicate_clamp := _valid_preset()
	duplicate_clamp["phases"]["one_shot"]["layers"][0]["modulation_clamps"].append(duplicate_clamp["phases"]["one_shot"]["layers"][0]["modulation_clamps"][0].duplicate(true))
	tests.expect_true(_has_code(_validate(registry, duplicate_clamp), "runtime_modulation_duplicate_clamp_target"), "duplicate target clamp is rejected")

	var undeclared_input := _valid_preset()
	undeclared_input["phases"]["one_shot"]["layers"][0]["modulations"][0]["source"]["input"] = "intensity"
	tests.expect_true(_has_code(_validate(registry, undeclared_input), "runtime_modulation_input_not_declared"), "binding input must be declared by its Preset")

	var negative_opacity := _valid_preset()
	negative_opacity["phases"]["one_shot"]["layers"][0]["modulations"][0]["target"] = "VISUAL_OPACITY_MULTIPLIER"
	negative_opacity["phases"]["one_shot"]["layers"][0]["modulations"][0]["mapping"]["output_min"] = -0.01
	tests.expect_true(_has_code(_validate(registry, negative_opacity), "runtime_modulation_opacity_multiplier_negative"), "negative visual opacity multiplier is rejected")

	var nonfinite_opacity := _valid_preset()
	nonfinite_opacity["phases"]["one_shot"]["layers"][0]["modulations"][0]["target"] = "VISUAL_OPACITY_MULTIPLIER"
	nonfinite_opacity["phases"]["one_shot"]["layers"][0]["modulations"][0]["mapping"]["output_max"] = NAN
	tests.expect_true(_has_code(_validate(registry, nonfinite_opacity), "runtime_modulation_opacity_multiplier_nonfinite"), "non-finite visual opacity multiplier is rejected")

	var above_one_opacity := _valid_preset()
	above_one_opacity["phases"]["one_shot"]["layers"][0]["modulations"][0]["target"] = "VISUAL_OPACITY_MULTIPLIER"
	above_one_opacity["phases"]["one_shot"]["layers"][0]["modulations"][0]["mapping"]["output_max"] = 1.05
	tests.expect_true(_validate(registry, above_one_opacity).success, "visual opacity multiplier above one remains valid")

	for layer_type in ["PARTICLE", "TRAIL", "RING", "GLOW", "SHIELD"]:
		var incompatible := _valid_preset()
		incompatible["phases"]["one_shot"]["layers"][0]["type"] = layer_type
		incompatible["phases"]["one_shot"]["layers"][0]["parameters"] = _parameters_for(layer_type)
		tests.expect_true(_has_code(_validate(registry, incompatible), "runtime_modulation_target_layer_type_incompatible"), "%s modulation is rejected before Preview Runtime" % layer_type)

	var nonzero_glow_pivot := _valid_preset()
	nonzero_glow_pivot["phases"]["one_shot"]["layers"][0]["type"] = "GLOW"
	nonzero_glow_pivot["phases"]["one_shot"]["layers"][0]["parameters"] = _parameters_for("GLOW")
	nonzero_glow_pivot["phases"]["one_shot"]["layers"][0]["modulations"] = []
	nonzero_glow_pivot["phases"]["one_shot"]["layers"][0]["transform"] = {"offset": [0.0, 0.0], "rotation_degrees": 0.0, "scale": [1.0, 1.0], "modulation_pivot_local": [1.0, 0.0]}
	tests.expect_true(_has_code(_validate(registry, nonzero_glow_pivot), "runtime_modulation_pivot_layer_type_incompatible"), "non-zero pivot remains TEXTURED_SPRITE-only")

	var missing_compatibility_schema := registry.schema()
	_rule_by_name(missing_compatibility_schema, "RUNTIME_MODULATION_CONFIGURATION")["target_contracts"]["TRANSFORM_SCALE_Y"].erase("compatible_layer_types")
	var missing_compatibility_registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	var missing_compatibility := missing_compatibility_registry.load_data(missing_compatibility_schema, "missing_runtime_modulation_compatibility.json")
	tests.expect_true(not missing_compatibility.success and _has_code(missing_compatibility, "runtime_modulation_contract_configuration"), "missing target compatibility is a Schema configuration error")


static func _validate(registry: VfxSchemaRegistry, preset: Dictionary) -> VfxResult:
	var normalizer := VfxPresetNormalizerModel.new(registry)
	var normalized := normalizer.normalize(preset, registry.schema())
	if not normalized.success:
		return normalized
	return VfxContractValidatorModel.new(registry, VfxSchemaSubsetValidatorModel.new(registry)).validate(normalized.value)


static func _has_code(result: VfxResult, code: String) -> bool:
	return result.issues.any(func(issue: VfxIssue) -> bool: return issue.code == code)


static func _rule_by_name(schema: Dictionary, rule_name: String) -> Dictionary:
	for rule in schema["x_vfx_rules"]:
		if rule["name"] == rule_name:
			return rule
	return {}


static func _valid_preset() -> Dictionary:
	return {
		"schema_version": 1,
		"preset_id": "utility.runtime_modulation_contract",
		"display_name": "Runtime Modulation Contract",
		"category": "UTILITY",
		"lifecycle": {"mode": "ONE_SHOT"},
		"default_space_mode": "VEHICLE_LOCAL",
		"runtime_inputs": ["speed_normalized", "longitudinal_load"],
		"runtime_modulation_sources": [{
			"id": "road.motion",
			"type": "OSCILLATOR",
			"wave": "SINE",
			"frequency_hz": 0.5,
			"phase_degrees": 0.0
		}],
		"phases": {
			"one_shot": {
				"duration_seconds": 0.25,
				"layers": [{
					"id": "one_shot.sprite",
					"type": "TEXTURED_SPRITE",
					"importance": "CORE",
					"blend_mode": "ALPHA",
					"render_plane": "UNDER_VEHICLE",
					"anchors": ["CENTER"],
					"parameters": {"texture_asset_ref": "fx.headlight_beam_soft"},
					"modulations": [{
						"id": "scale.by.speed",
						"target": "TRANSFORM_SCALE_Y",
						"operation": "MULTIPLY",
						"source": {"type": "RUNTIME_INPUT", "input": "speed_normalized"},
						"mapping": {"type": "LINEAR_RANGE", "input_min": 0.0, "input_max": 1.0, "output_min": 1.0, "output_max": 1.06}
					}],
					"modulation_clamps": [{"target": "TRANSFORM_SCALE_Y", "min_effective": 0.5, "max_effective": 2.0}]
				}]
			}
		}
	}


static func _valid_bend_preset() -> Dictionary:
	var preset := _valid_preset()
	preset["runtime_inputs"] = ["turn_rate_normalized"]
	preset["runtime_modulation_sources"] = []
	var layer: Dictionary = preset["phases"]["one_shot"]["layers"][0]
	layer["transform"] = {
		"offset": [0.0, 0.0],
		"rotation_degrees": 0.0,
		"scale": [1.0, 1.0],
		"modulation_pivot_local": [0.0, 40.0]
	}
	layer["visual_bend"] = {
		"axis": "LOCAL_Y_POSITIVE",
		"start_ratio": 0.333333,
		"curve": "QUADRATIC",
		"span_source_px": 240.0
	}
	layer["modulations"] = [{
		"id": "bend.by.turn_rate",
		"target": "VISUAL_BEND_OFFSET_X",
		"operation": "ADD",
		"source": {"type": "RUNTIME_INPUT", "input": "turn_rate_normalized"},
		"mapping": {
			"type": "LINEAR_RANGE",
			"input_min": -0.2,
			"input_max": 0.2,
			"output_min": 60.0,
			"output_max": -60.0
		}
	}]
	layer["modulation_clamps"] = [{
		"target": "VISUAL_BEND_OFFSET_X",
		"min_effective": -60.0,
		"max_effective": 60.0
	}]
	return preset


static func _parameters_for(layer_type: String) -> Dictionary:
	match layer_type:
		"PARTICLE":
			return {"emission_mode": "BURST", "emitter": {"shape": "POINT"}, "sprite_asset_ref": "fx.energy_shard", "burst_count": 1, "lifetime_seconds": 0.2}
		"TRAIL":
			return {"texture_asset_ref": "fx.energy_shard", "width_start": 1.0, "width_end": 0.0, "max_points": 2, "lifetime_seconds": 0.2}
		"RING":
			return {"radius_start": 1.0, "radius_end": 2.0, "width": 1.0, "duration_seconds": 0.2}
		"GLOW":
			return {"radius": 4.0, "opacity": 0.5}
		"SHIELD":
			return {"radius": 4.0, "arc_degrees": 90.0, "thickness": 1.0, "opacity": 0.5}
	return {}
