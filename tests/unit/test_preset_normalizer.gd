extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPresetNormalizerModel := preload("res://src/model/vfx_preset_normalizer.gd")


static func run(tests: TestAssert) -> void:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	var loaded := registry.load("res://schemas/vfx_schema_v1.json")
	if not loaded.success:
		tests.expect_true(false, "normalizer requires a valid Schema registry")
		return

	var layer_ref := registry.resolve_local_ref("#/$defs/layer")
	var layer_schema: Dictionary = layer_ref.value
	var raw := {
		"id": "loop.core_glow",
		"type": "GLOW",
		"importance": "CORE",
		"blend_mode": "ADDITIVE",
		"render_plane": "UNDER_VEHICLE",
		"parameters": {
			"radius": 12.0,
			"opacity": 0.8
		}
	}
	var normalizer := VfxPresetNormalizerModel.new(registry)
	var result := normalizer.normalize(raw, layer_schema)
	tests.expect_true(result.success, "normalizer produces a value")
	var normalized: Dictionary = result.value
	tests.expect_true(normalized["sort_order"] == 0, "Layer sort order default is applied")
	tests.expect_true(normalized["enabled"] == true, "Layer enabled default is applied")
	tests.expect_true(normalized["transform"]["scale"] == [1.0, 1.0], "nested transform defaults apply")
	tests.expect_true(normalized["parameters"]["color_rgba"] == [1.0, 1.0, 1.0, 1.0], "type-dispatched Layer defaults apply")
	tests.expect_true(not raw.has("sort_order"), "normalizer does not mutate raw Layer")
	tests.expect_true(not raw["parameters"].has("color_rgba"), "normalizer does not mutate raw parameters")

	var particle_raw := {
		"id": "loop.shards",
		"type": "PARTICLE",
		"importance": "DETAIL",
		"blend_mode": "ADDITIVE",
		"render_plane": "OVER_VEHICLE",
		"parameters": {
			"emission_mode": "BURST",
			"emitter": {"shape": "POINT"},
			"sprite_asset_ref": "fx.energy_shard",
			"burst_count": 3,
			"lifetime_seconds": 0.2
		}
	}
	var particle_result := normalizer.normalize(particle_raw, layer_schema)
	tests.expect_true(particle_result.value["parameters"]["spread_degrees"] == 0.0, "Particle Motion defaults are schema driven")
	tests.expect_true(not particle_raw["parameters"].has("spread_degrees"), "Particle raw data remains unchanged")
