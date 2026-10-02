extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.sandwich_escape.vfx.json"
const ASSETS := {
	"fx.sandwich_escape_chevron": Vector2i(128, 96),
	"fx.sandwich_escape_path": Vector2i(48, 192),
	"fx.sandwich_escape_thrust": Vector2i(96, 192),
}
# Mid-pack cars sit close behind the next car, so forward arrows stop within about one car length.
const MAX_FORWARD_TRAVEL := 480.0
# START follow layer -> LOOP layer it hands over to.
const BRIDGES := {
	"start.chevron_follow": "loop.chevrons",
}


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Sandwich Escape requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	_check_structure(t, d)
	_check_forward_reach(t, d)
	_check_start_bridges_into_loop(t, d)
	_check_export_plan(t)


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Sandwich Escape resolves its chevron, path and thrust textures without fallback")


static func _check_structure(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var all_layers: Array = []
	all_layers.append_array(start.values())
	all_layers.append_array(loop.values())
	var additive := all_layers.all(func(layer: Dictionary) -> bool:
		return layer.get("type") == "PARTICLE" and layer.get("blend_mode") == "ADDITIVE" \
			and layer.get("render_plane") == "UNDER_VEHICLE"
	)
	# Arrows and paths fire forward from the nose; the one-shot thrust sits behind the rear end.
	var sides := all_layers.all(func(layer: Dictionary) -> bool:
		var asset := str(layer.get("parameters", {}).get("sprite_asset_ref", ""))
		var offset_y := float(layer.get("transform", {}).get("offset", [0.0, 0.0])[1])
		var direction := float(layer.get("parameters", {}).get("direction_degrees", -1.0))
		if asset == "fx.sandwich_escape_thrust":
			return offset_y > 235.0 and is_equal_approx(direction, 180.0)
		return offset_y < 0.0 and is_equal_approx(direction, 0.0)
	)
	t.expect_true(
		d.get("preset_id") == "talent.sandwich_escape" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" and d.get("runtime_inputs", []).is_empty() \
		and phases.get("end", {}).get("layers", []).is_empty() \
		and start.size() == 3 and start.has("start.thrust") \
		and start.has("start.chevron") and start.has("start.chevron_follow") \
		and loop.size() == 3 and loop.has("loop.chevrons") and loop.has("loop.path_left") \
		and loop.has("loop.path_right") \
		# The LOOP rear thrust was removed after the in-game review (too thin to read).
		and loop.values().all(func(layer: Dictionary) -> bool: return str(layer.get("parameters", {}).get("sprite_asset_ref", "")) != "fx.sandwich_escape_thrust") \
		and additive and sides,
		"Sandwich Escape fires additive gold chevrons and paths forward, keeps the rear thrust to START only, and an empty END drains naturally"
	)


static func _check_forward_reach(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var ok := true
	for phase in ["start", "loop"]:
		for layer in phases.get(phase, {}).get("layers", []):
			var p: Dictionary = layer.get("parameters", {})
			if str(p.get("sprite_asset_ref", "")) == "fx.sandwich_escape_thrust":
				continue
			ok = ok and float(p.get("speed_max", 0.0)) * float(p.get("lifetime_seconds", 0.0)) <= MAX_FORWARD_TRAVEL
	t.expect_true(ok, "Sandwich Escape arrows and paths stay within about one car length ahead of the nose")


static func _check_start_bridges_into_loop(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start_duration := float(phases.get("start", {}).get("duration_seconds", 0.0))
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var ok := true
	for follow_id in BRIDGES:
		var follow: Dictionary = start.get(follow_id, {}).get("parameters", {})
		var target: Dictionary = loop.get(BRIDGES[follow_id], {}).get("parameters", {})
		var follow_first := 1.0 / float(follow.get("emission_rate_per_second", 0.001))
		var loop_first := start_duration + 1.0 / float(target.get("emission_rate_per_second", 0.001))
		# The START follow layer emits inside START and is still visible when LOOP emits its first particle.
		ok = ok and follow.get("emission_mode") == "CONTINUOUS" and follow_first < start_duration \
			and follow_first + float(follow.get("lifetime_seconds", 0.0)) >= loop_first
	for layer in loop.values():
		var p: Dictionary = layer.get("parameters", {})
		ok = ok and float(p.get("lifetime_seconds", 0.0)) > 1.0 / float(p.get("emission_rate_per_second", 0.001))
	t.expect_true(ok, "Sandwich Escape START arrows hand over to LOOP without a gap and every LOOP layer overlaps itself")


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(
		plan.success and ids == ["fx.sandwich_escape_chevron", "fx.sandwich_escape_path", "fx.sandwich_escape_thrust"],
		"Sandwich Escape compiles to a package that depends only on its three textures"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
