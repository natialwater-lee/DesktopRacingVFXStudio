extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.photosynthesis.vfx.json"
const ASSETS := {
	"fx.photosynthesis_energy_aura_a": Vector2i(192, 320),
	"fx.photosynthesis_energy_aura_b": Vector2i(192, 320),
	"fx.photosynthesis_sun_rays": Vector2i(192, 192),
}


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Photosynthesis rework requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	_check_structure(t, d)
	_check_aura_alternation(t, d)
	_check_export_plan(t)


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Photosynthesis resolves the two energy aura variants and the sun rays texture without fallback")


static func _check_structure(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var all_layers: Array = []
	all_layers.append_array(phases.get("start", {}).get("layers", []))
	all_layers.append_array(phases.get("loop", {}).get("layers", []))
	var additive_local := all_layers.all(func(layer: Dictionary) -> bool:
		return layer.get("blend_mode") == "ADDITIVE" \
			and layer.get("space_mode", "VEHICLE_LOCAL") == "VEHICLE_LOCAL" \
			and layer.get("anchors", ["CENTER"]) == ["CENTER"]
	)
	t.expect_true(
		d.get("preset_id") == "talent.photosynthesis" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" \
		and d.get("runtime_inputs", []).is_empty() \
		and is_equal_approx(float(phases.get("start", {}).get("duration_seconds", 0.0)), 0.6) \
		and is_equal_approx(float(phases.get("end", {}).get("duration_seconds", 0.0)), 0.4) \
		and phases.get("end", {}).get("layers", []).is_empty() \
		and start.size() == 3 and start.has("start.sun_pool") and start.has("start.sun_rays") and start.has("start.green_release") \
		and start["start.sun_pool"].get("type") == "GLOW" and is_zero_approx(float(start["start.sun_pool"].get("parameters", {}).get("pulse_hz", 1.0))) \
		and loop.size() == 3 and loop.has("loop.energy_aura_a") and loop.has("loop.energy_aura_b") and loop.has("loop.sun_charge") \
		and loop["loop.sun_charge"].get("importance") == "DETAIL" and loop["loop.sun_charge"].get("render_plane") == "OVER_VEHICLE" \
		and additive_local,
		"Photosynthesis uses an additive gold convergence START, two aura variants plus a periodic sun charge in LOOP, and an empty END that lets the aura drain"
	)


static func _check_aura_alternation(t: TestAssert, d: Dictionary) -> void:
	var loop := _by_id(d.get("phases", {}).get("loop", {}).get("layers", []))
	var a: Dictionary = loop.get("loop.energy_aura_a", {}).get("parameters", {})
	var b: Dictionary = loop.get("loop.energy_aura_b", {}).get("parameters", {})
	var ok := true
	for entry in [[loop.get("loop.energy_aura_a", {}), a, "fx.photosynthesis_energy_aura_a"], [loop.get("loop.energy_aura_b", {}), b, "fx.photosynthesis_energy_aura_b"]]:
		var layer: Dictionary = entry[0]
		var p: Dictionary = entry[1]
		var rate := float(p.get("emission_rate_per_second", 0.0))
		ok = ok and layer.get("type") == "PARTICLE" and layer.get("importance") == "CORE" and layer.get("render_plane") == "UNDER_VEHICLE" \
			and p.get("sprite_asset_ref") == entry[2] and p.get("emission_mode") == "CONTINUOUS" \
			and int(p.get("max_particles", 0)) == 2 \
			and is_zero_approx(float(p.get("speed_max", 1.0))) \
			and rate > 0.0 and float(p.get("lifetime_seconds", 0.0)) > 1.0 / rate \
			and float(p.get("size_end", 0.0)) > float(p.get("size_start", 0.0)) \
			and is_zero_approx(float(p.get("alpha_end", 1.0)))
	t.expect_true(
		ok and not is_equal_approx(float(a.get("emission_rate_per_second", 0.0)), float(b.get("emission_rate_per_second", 0.0))),
		"Photosynthesis aura variants overlap themselves (lifetime > interval) and use different cadences so the arcs keep shifting"
	)


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(
		plan.success and int(manifest.get("runtime_definition", {}).get("version", 0)) == 1 \
		and ids == ["fx.photosynthesis_energy_aura_a", "fx.photosynthesis_energy_aura_b", "fx.photosynthesis_sun_rays"],
		"Photosynthesis compiles to a Runtime v1 package that depends only on the two aura variants and the sun rays"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
