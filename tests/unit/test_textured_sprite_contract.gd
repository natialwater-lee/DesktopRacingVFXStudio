extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxSchemaSubsetValidatorModel := preload("res://src/model/vfx_schema_subset_validator.gd")
const VfxPresetNormalizerModel := preload("res://src/model/vfx_preset_normalizer.gd")
const VfxContractValidatorModel := preload("res://src/model/vfx_contract_validator.gd")


static func run(tests: TestAssert) -> void:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	var loaded: VfxResult = registry.load("res://schemas/vfx_schema_v1.json")
	if not loaded.success:
		tests.expect_true(false, "TEXTURED_SPRITE contract test requires the Schema Registry")
		return
	var normalizer := VfxPresetNormalizerModel.new(registry)
	var validator := VfxContractValidatorModel.new(registry, VfxSchemaSubsetValidatorModel.new(registry))
	var valid := _validate(normalizer, validator, registry.schema(), _preset())
	tests.expect_true(valid.success, "TEXTURED_SPRITE accepts one static logical texture with normalized opacity and common transform")
	var missing_texture := _preset()
	missing_texture["phases"]["loop"]["layers"][0]["parameters"].erase("texture_asset_ref")
	tests.expect_true(_has_code(_validate(normalizer, validator, registry.schema(), missing_texture), "required"), "TEXTURED_SPRITE rejects a missing texture_asset_ref instead of falling back to an implicit asset")
	var invalid_opacity := _preset()
	invalid_opacity["phases"]["loop"]["layers"][0]["parameters"]["opacity"] = 1.01
	tests.expect_true(_has_code(_validate(normalizer, validator, registry.schema(), invalid_opacity), "maximum"), "TEXTURED_SPRITE opacity remains within the shared zero-through-one alpha contract")
	var invalid_transform := _preset()
	invalid_transform["phases"]["loop"]["layers"][0]["transform"]["scale"] = [0.0, 1.0]
	tests.expect_true(_has_code(_validate(normalizer, validator, registry.schema(), invalid_transform), "minimum"), "TEXTURED_SPRITE uses the common non-zero transform scale validation")
	var types: Dictionary = registry.schema().get("x_vfx_layer_types", {})
	var existing_types_unchanged := true
	for layer_type in ["PARTICLE", "TRAIL", "RING", "GLOW", "SHIELD"]:
		existing_types_unchanged = existing_types_unchanged and types.has(layer_type)
	tests.expect_true(types.has("TEXTURED_SPRITE") and existing_types_unchanged, "TEXTURED_SPRITE is additive to the existing five Schema v1 Layer Types")


static func preset_data() -> Dictionary:
	return _preset()


static func _validate(normalizer: VfxPresetNormalizer, validator: VfxContractValidator, root_schema: Dictionary, preset: Dictionary) -> VfxResult:
	var normalized: VfxResult = normalizer.normalize(preset, root_schema)
	return validator.validate(normalized.value) if normalized.success else normalized


static func _has_code(result: VfxResult, code: String) -> bool:
	return result.issues.any(func(issue: VfxIssue) -> bool: return issue.code == code)


static func _preset() -> Dictionary:
	return {
		"schema_version": 1,
		"preset_id": "special.textured_sprite_fixture",
		"display_name": "Textured Sprite Fixture",
		"category": "SPECIAL_EQUIPMENT",
		"lifecycle": {"mode": "START_LOOP_END"},
		"default_space_mode": "VEHICLE_LOCAL",
		"runtime_inputs": [],
		"phases": {
			"start": {"duration_seconds": 0.1, "layers": []},
			"loop": {"layers": [{
				"id": "loop.static_texture",
				"type": "TEXTURED_SPRITE",
				"importance": "CORE",
				"blend_mode": "ALPHA",
				"render_plane": "UNDER_VEHICLE",
				"anchors": ["CENTER"],
				"transform": {"offset": [12.0, -18.0], "rotation_degrees": 30.0, "scale": [1.5, 0.75]},
				"parameters": {"texture_asset_ref": "fx.headlight_beam_core", "opacity": 0.65}
			}]},
			"end": {"duration_seconds": 0.1, "layers": []}
		}
	}
