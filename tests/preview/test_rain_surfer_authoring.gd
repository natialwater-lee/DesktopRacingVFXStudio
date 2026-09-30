extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.rain_surfer.vfx.json"
# Shared rear-wheel contact x (source px) used by the Game tire marks and weather wake.
const REAR_CONTACT_X := 84.0
const ASSETS := {
	"fx.rain_surfer_splash_wing": Vector2i(160, 128),
	"fx.rain_surfer_neon_a": Vector2i(192, 320),
	"fx.rain_surfer_neon_b": Vector2i(192, 320),
	"fx.rain_surfer_light_trail": Vector2i(32, 128),
}


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Rain Surfer requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	_check_structure(t, d)
	_check_world_trails(t, d)
	_check_export_plan(t)


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Rain Surfer resolves the splash, two neon variants and the light trail texture without fallback")


static func _check_structure(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var all_layers: Array = []
	all_layers.append_array(phases.get("start", {}).get("layers", []))
	all_layers.append_array(phases.get("loop", {}).get("layers", []))
	var shared := all_layers.all(func(layer: Dictionary) -> bool:
		return layer.get("type") == "PARTICLE" and layer.get("blend_mode") == "ADDITIVE" \
			and layer.get("render_plane") == "UNDER_VEHICLE" and layer.get("anchors", ["CENTER"]) == ["CENTER"]
	)
	var neon_a: Dictionary = loop.get("loop.neon_a", {}).get("parameters", {})
	var neon_b: Dictionary = loop.get("loop.neon_b", {}).get("parameters", {})
	t.expect_true(
		d.get("preset_id") == "talent.rain_surfer" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" and d.get("runtime_inputs", []).is_empty() \
		and is_equal_approx(float(phases.get("start", {}).get("duration_seconds", 0.0)), 0.6) \
		and is_equal_approx(float(phases.get("end", {}).get("duration_seconds", 0.0)), 0.4) \
		and phases.get("end", {}).get("layers", []).is_empty() \
		and start.size() == 2 and start.has("start.bow_splash") and start.has("start.neon_on") \
		and start["start.bow_splash"].get("parameters", {}).get("emission_mode") == "BURST" \
		and loop.size() == 4 and loop.has("loop.neon_a") and loop.has("loop.neon_b") and loop.has("loop.trail_left") and loop.has("loop.trail_right") \
		and neon_a.get("sprite_asset_ref") == "fx.rain_surfer_neon_a" and neon_b.get("sprite_asset_ref") == "fx.rain_surfer_neon_b" \
		and not is_equal_approx(float(neon_a.get("emission_rate_per_second", 0.0)), float(neon_b.get("emission_rate_per_second", 0.0))) \
		and shared,
		"Rain Surfer uses a one-shot bow splash, two alternating neon variants and two wheel light trails, all additive under the vehicle, with an empty END"
	)


static func _check_world_trails(t: TestAssert, d: Dictionary) -> void:
	var loop := _by_id(d.get("phases", {}).get("loop", {}).get("layers", []))
	var ok := true
	for entry in [["loop.trail_left", -REAR_CONTACT_X], ["loop.trail_right", REAR_CONTACT_X]]:
		var layer: Dictionary = loop.get(entry[0], {})
		var p: Dictionary = layer.get("parameters", {})
		var offset: Array = layer.get("transform", {}).get("offset", [])
		var rate := float(p.get("emission_rate_per_second", 0.0))
		ok = ok and layer.get("space_mode") == "VEHICLE_FOLLOW_WORLD_TRAIL" \
			and p.get("sprite_asset_ref") == "fx.rain_surfer_light_trail" and p.get("emission_mode") == "CONTINUOUS" \
			and offset.size() == 2 and is_equal_approx(float(offset[0]), entry[1]) \
			and is_zero_approx(float(p.get("speed_max", 1.0))) \
			and is_zero_approx(float(p.get("rotation_min_degrees", 1.0))) and is_zero_approx(float(p.get("rotation_max_degrees", 1.0))) \
			and rate > 0.0 and float(p.get("lifetime_seconds", 0.0)) > 3.0 / rate \
			and int(p.get("max_particles", 0)) >= int(ceil(rate * float(p.get("lifetime_seconds", 0.0))))
	var neon_local: bool = loop.get("loop.neon_a", {}).get("space_mode", "VEHICLE_LOCAL") == "VEHICLE_LOCAL"
	t.expect_true(ok and neon_local, "Rain Surfer wheel light trails stay in the world at the shared rear contact with enough overlapping segments, while the neon follows the vehicle")


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(
		plan.success and ids == ["fx.rain_surfer_light_trail", "fx.rain_surfer_neon_a", "fx.rain_surfer_neon_b", "fx.rain_surfer_splash_wing"],
		"Rain Surfer compiles to a package that depends only on its four textures"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
