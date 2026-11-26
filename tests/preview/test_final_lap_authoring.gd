extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.final_lap.vfx.json"
const ASSETS := {
	"fx.final_lap_flag_body_l": Vector2i(352, 768),
	"fx.final_lap_flag_body_r": Vector2i(352, 768),
	"fx.final_lap_flag_sheen_l": Vector2i(352, 768),
	"fx.final_lap_flag_sheen_r": Vector2i(352, 768),
	"fx.final_lap_flag_spill": Vector2i(256, 384),
	"fx.final_lap_flag_piece": Vector2i(96, 96),
	"fx.final_lap_finish_line": Vector2i(512, 160),
	"fx.final_lap_charge_ring": Vector2i(512, 512),
	"fx.final_lap_charge_flash": Vector2i(256, 256),
}


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Final Lap requires a valid Preset: %s" % str(result.errors))
		return
	var d: Dictionary = result.value.normalized_data
	var phases: Dictionary = d.get("phases", {})
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var sprites := loop.values().filter(func(l: Dictionary) -> bool: return l.get("type") == "TEXTURED_SPRITE")
	t.expect_true(
		d.get("preset_id") == "talent.final_lap" and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" \
		and d.get("runtime_inputs", []) == ["turn_rate_normalized", "boost_active"] and sprites.size() == 5 \
		and loop.has("loop.pieces_l") and loop.has("loop.pieces_r"),
		"Final Lap declares turn_rate + boost_active and keeps LOOP to five sprites plus two scrap emitters"
	)
	var ok := true
	for s in ["l", "r"]:
		for part in ["body", "sheen"]:
			var layer: Dictionary = loop.get("loop.%s_%s" % [part, s], {})
			var targets: Array = layer.get("modulations", []).map(func(m: Dictionary) -> String: return str(m.get("target")))
			var boost: Array = layer.get("modulations", []).filter(func(m: Dictionary) -> bool: return m["source"].get("input") == "boost_active" and m.get("target") == "TRANSFORM_SCALE_Y")
			# Never frozen: sway + ripple are visible in Studio; bend flutter + corner trail in Game.
			ok = ok and layer.has("visual_bend") and targets.has("TRANSFORM_ROTATION_DEGREES") and targets.has("TRANSFORM_SCALE_X") \
				and targets.count("VISUAL_BEND_OFFSET_X") == 3 and boost.size() == 1 and float(boost[0]["mapping"]["output_max"]) > 1.0
	t.expect_true(ok, "Final Lap ribbons always move (sway, ripple, bend flutter) and stretch with boost_active")
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	var expected: Array = ASSETS.keys()
	expected.sort()
	t.expect_true(plan.success and ids == expected, "Final Lap compiles to a package with its nine textures")


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Final Lap resolves its ribbon, scrap, finish line and charge textures without fallback")


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
