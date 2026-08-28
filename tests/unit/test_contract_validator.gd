extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxSchemaSubsetValidatorModel := preload("res://src/model/vfx_schema_subset_validator.gd")
const VfxPresetNormalizerModel := preload("res://src/model/vfx_preset_normalizer.gd")
const VfxContractValidatorModel := preload("res://src/model/vfx_contract_validator.gd")


static func run(tests: TestAssert) -> void:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	var loaded := registry.load("res://schemas/vfx_schema_v1.json")
	if not loaded.success:
		tests.expect_true(false, "contract validator requires a valid Schema registry")
		return
	var validator := VfxContractValidatorModel.new(registry, VfxSchemaSubsetValidatorModel.new(registry))
	var normalizer := VfxPresetNormalizerModel.new(registry)
	var root_schema: Dictionary = registry.schema()

	var array_result := validator.validate([])
	tests.expect_true(not array_result.success, "array is not a Preset")
	tests.expect_true(array_result.issues[0].json_pointer == "/type", "top-level type error has pointer")

	var valid_result := _validate(normalizer, validator, root_schema, _valid_start_loop_end())
	tests.expect_true(valid_result.success, "valid start-loop-end Preset passes contract")

	var invalid_enum := _valid_start_loop_end()
	invalid_enum["category"] = "INVALID_CATEGORY"
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, invalid_enum), "invalid_enum"), "invalid enum is rejected")

	var unknown_property := _valid_start_loop_end()
	unknown_property["unexpected"] = true
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, unknown_property), "additional_property"), "unknown property is rejected")

	var missing_required := _valid_start_loop_end()
	missing_required.erase("display_name")
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, missing_required), "required"), "missing required field is rejected")

	var duplicate_layer_id := _valid_start_loop_end()
	duplicate_layer_id["phases"]["start"]["layers"].append(_glow_layer("loop.core_glow"))
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, duplicate_layer_id), "duplicate_layer_id"), "Layer id is unique across phases")

	var invalid_start_loop_end := _valid_start_loop_end()
	invalid_start_loop_end["phases"].erase("end")
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, invalid_start_loop_end), "lifecycle_phase_structure"), "START_LOOP_END requires start loop end phases")

	var invalid_one_shot := _valid_start_loop_end()
	invalid_one_shot["lifecycle"]["mode"] = "ONE_SHOT"
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, invalid_one_shot), "lifecycle_phase_structure"), "ONE_SHOT rejects start-loop-end phases")

	var vehicle_without_anchor := _valid_start_loop_end()
	vehicle_without_anchor["phases"]["loop"]["layers"][0].erase("anchors")
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, vehicle_without_anchor), "vehicle_anchor_required"), "vehicle Layer requires Anchor")

	var world_with_anchor := _valid_start_loop_end()
	world_with_anchor["default_space_mode"] = "WORLD_AREA"
	world_with_anchor["phases"]["loop"]["layers"][0]["render_plane"] = "WORLD"
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, world_with_anchor), "anchor_not_allowed"), "world Layer rejects vehicle Anchor")

	var invalid_plane := _valid_start_loop_end()
	invalid_plane["phases"]["loop"]["layers"][0]["render_plane"] = "WORLD"
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, invalid_plane), "render_plane_for_space"), "render plane follows space mode")

	var invalid_continuous := _particle_preset()
	invalid_continuous["phases"]["one_shot"]["layers"][0]["parameters"]["emission_mode"] = "CONTINUOUS"
	invalid_continuous["phases"]["one_shot"]["layers"][0]["parameters"].erase("emission_rate_per_second")
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, invalid_continuous), "continuous_emission_fields"), "continuous Particle requires rate and capacity")

	var invalid_emitter := _particle_preset()
	invalid_emitter["phases"]["one_shot"]["layers"][0]["parameters"]["emitter"] = {"shape": "CIRCLE"}
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, invalid_emitter), "emitter_shape_geometry"), "emitter shape requires matching geometry")

	var unknown_runtime_input := _valid_start_loop_end()
	unknown_runtime_input["runtime_inputs"] = ["not_defined"]
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, unknown_runtime_input), "unknown_runtime_input"), "unknown runtime input is rejected")

	var invalid_asset_ref := _particle_preset()
	invalid_asset_ref["phases"]["one_shot"]["layers"][0]["parameters"]["sprite_asset_ref"] = "C:\\absolute\\path"
	tests.expect_true(_has_code(_validate(normalizer, validator, root_schema, invalid_asset_ref), "pattern"), "logical asset reference rejects paths")


static func _validate(normalizer: VfxPresetNormalizer, validator: VfxContractValidator, root_schema: Dictionary, preset: Dictionary) -> VfxResult:
	var normalized := normalizer.normalize(preset, root_schema)
	if not normalized.success:
		return normalized
	return validator.validate(normalized.value)


static func _has_code(result: VfxResult, code: String) -> bool:
	return result.issues.any(func(issue: VfxIssue) -> bool: return issue.code == code)


static func _valid_start_loop_end() -> Dictionary:
	return {
		"schema_version": 1,
		"preset_id": "talent.contract_test",
		"display_name": "Contract Test",
		"category": "RACE_TALENT",
		"lifecycle": {"mode": "START_LOOP_END"},
		"default_space_mode": "VEHICLE_LOCAL",
		"runtime_inputs": [],
		"phases": {
			"start": {"duration_seconds": 0.1, "layers": []},
			"loop": {"layers": [_glow_layer("loop.core_glow")]},
			"end": {"duration_seconds": 0.1, "layers": []}
		}
	}


static func _particle_preset() -> Dictionary:
	return {
		"schema_version": 1,
		"preset_id": "finish.particle_test",
		"display_name": "Particle Test",
		"category": "FINISH",
		"lifecycle": {"mode": "ONE_SHOT"},
		"default_space_mode": "WORLD_AREA",
		"runtime_inputs": [],
		"phases": {
			"one_shot": {
				"duration_seconds": 0.4,
				"layers": [{
					"id": "one_shot.burst",
					"type": "PARTICLE",
					"importance": "DETAIL",
					"blend_mode": "ADDITIVE",
					"render_plane": "WORLD",
					"parameters": {
						"emission_mode": "BURST",
						"emitter": {"shape": "POINT"},
						"sprite_asset_ref": "fx.energy_shard",
						"burst_count": 4,
						"lifetime_seconds": 0.2
					}
				}]
			}
		}
	}


static func _glow_layer(layer_id: String) -> Dictionary:
	return {
		"id": layer_id,
		"type": "GLOW",
		"importance": "CORE",
		"blend_mode": "ADDITIVE",
		"render_plane": "UNDER_VEHICLE",
		"anchors": ["CENTER"],
		"parameters": {
			"radius": 12.0,
			"opacity": 0.8
		}
	}
