extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.furious_overtake.vfx.json"
const ASSETS := {
	"fx.furious_overtake_aura_a": Vector2i(192, 320),
	"fx.furious_overtake_aura_b": Vector2i(192, 320),
	"fx.furious_overtake_rear_beam": Vector2i(64, 256),
	"fx.furious_overtake_spark": Vector2i(32, 32),
}


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Furious Overtake requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	_check_structure(t, d)
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
	t.expect_true(ok, "Furious Overtake resolves its crack auras, rear beam and spark textures without fallback")


static func _check_structure(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var all_layers: Array = []
	all_layers.append_array(phases.get("start", {}).get("layers", []))
	all_layers.append_array(phases.get("loop", {}).get("layers", []))
	var crimson := all_layers.all(func(layer: Dictionary) -> bool:
		var color: Array = layer.get("parameters", {}).get("color_rgba", [])
		# Red-dominant tint keeps the effect apart from the orange booster flame.
		return layer.get("type") == "PARTICLE" and layer.get("blend_mode") == "ADDITIVE" \
			and layer.get("render_plane") == "UNDER_VEHICLE" \
			and color.size() == 4 and float(color[0]) >= 0.99 and float(color[1]) < 0.8 and float(color[2]) < 0.8
	)
	t.expect_true(
		d.get("preset_id") == "talent.furious_overtake" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" and d.get("runtime_inputs", []).is_empty() \
		and phases.get("end", {}).get("layers", []).is_empty() \
		and start.size() == 3 and start.has("start.rage_flash") and start.has("start.crack_burst") and start.has("start.spark_burst") \
		and loop.size() == 4 and loop.has("loop.aura_a") and loop.has("loop.aura_b") and loop.has("loop.rear_beam") and loop.has("loop.sparks") \
		and loop["loop.sparks"].get("importance") == "DETAIL" \
		and crimson,
		"Furious Overtake uses additive crimson crack auras, a rear beam and sparks, with an empty END so early charge-consumed endings drain naturally"
	)


static func _check_start_bridges_into_loop(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start_duration := float(phases.get("start", {}).get("duration_seconds", 0.0))
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var first_aura_delay := 1.0 / float(loop.get("loop.aura_a", {}).get("parameters", {}).get("emission_rate_per_second", 1.0))
	var burst_life := float(start.get("start.crack_burst", {}).get("parameters", {}).get("lifetime_seconds", 0.0))
	var ok := burst_life >= start_duration + first_aura_delay
	for layer_id in ["loop.aura_a", "loop.aura_b"]:
		var p: Dictionary = loop.get(layer_id, {}).get("parameters", {})
		ok = ok and float(p.get("lifetime_seconds", 0.0)) > 1.0 / float(p.get("emission_rate_per_second", 1.0))
	t.expect_true(ok, "Furious Overtake START cracks outlive the first LOOP aura emission and each aura overlaps itself")


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(
		plan.success and ids == ["fx.furious_overtake_aura_a", "fx.furious_overtake_aura_b", "fx.furious_overtake_rear_beam", "fx.furious_overtake_spark"],
		"Furious Overtake compiles to a package that depends only on its four textures"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
