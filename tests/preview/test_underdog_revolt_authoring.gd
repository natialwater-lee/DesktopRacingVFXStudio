extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.underdog_revolt.vfx.json"
const ASSETS := {
	"fx.underdog_revolt_flame_streak": Vector2i(64, 320),
	"fx.underdog_revolt_ember_burst": Vector2i(256, 256),
}


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Underdog Revolt requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	_check_structure(t, d)
	_check_forward_flow(t, d)
	_check_export_plan(t)


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Underdog Revolt resolves its flame streak and ember burst textures without fallback")


static func _check_structure(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var loop: Array = phases.get("loop", {}).get("layers", [])
	var all_layers: Array = []
	all_layers.append_array(phases.get("start", {}).get("layers", []))
	all_layers.append_array(loop)
	var additive_under: bool = all_layers.all(func(layer: Dictionary) -> bool: return layer.get("blend_mode") == "ADDITIVE" and layer.get("render_plane") == "UNDER_VEHICLE")
	var loop_continuous: bool = loop.all(func(layer: Dictionary) -> bool: return layer.get("parameters", {}).get("emission_mode") == "CONTINUOUS")
	t.expect_true(
		d.get("preset_id") == "talent.underdog_revolt" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" and d.get("runtime_inputs", []).is_empty() \
		and phases.get("end", {}).get("layers", []).is_empty() and additive_under and loop_continuous,
		"Underdog Revolt uses additive under-vehicle layers with a length-agnostic LOOP"
	)


static func _check_forward_flow(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var ok := true
	for side in [["l", -1.0], ["r", 1.0]]:
		var layer: Dictionary = loop.get("loop.streak_%s" % side[0], {})
		var p: Dictionary = layer.get("parameters", {})
		var offset: Array = layer.get("transform", {}).get("offset", [0.0, 0.0])
		# Flames flow back → front (0° = forward) beside the car, never wrapped around it.
		ok = ok and is_equal_approx(float(p.get("direction_degrees", -1.0)), 0.0) and float(p.get("speed_min", 0.0)) > 0.0 \
			and float(offset[0]) * side[1] > 120.0 \
			and float(p.get("emission_rate_per_second", 0.0)) * float(p.get("lifetime_seconds", 0.0)) >= 3.0
	var start_duration := float(phases.get("start", {}).get("duration_seconds", 0.0))
	var first_streak := start_duration + 1.0 / float(loop.get("loop.streak_l", {}).get("parameters", {}).get("emission_rate_per_second", 0.001))
	ok = ok and float(start.get("start.streak_l", {}).get("parameters", {}).get("lifetime_seconds", 0.0)) >= first_streak
	t.expect_true(ok, "Underdog Revolt flames flow forward beside the car continuously and START hands over without a gap")


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(
		plan.success and ids == ["fx.furious_overtake_spark", "fx.underdog_revolt_ember_burst", "fx.underdog_revolt_flame_streak"],
		"Underdog Revolt compiles to a package with its two textures and the reused spark"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
