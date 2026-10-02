extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.snow_boarder.vfx.json"
const ASSETS := {
	"fx.snow_boarder_frost_trail": Vector2i(32, 128),
	"fx.snow_boarder_ice_glint": Vector2i(32, 32),
	"fx.snow_boarder_powder_fan": Vector2i(128, 160),
}
# Shared rear-wheel contact x (source px) used by the weather wake and Rain Surfer trails.
const REAR_WHEEL_X := 84.0


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Snow Boarder requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	_check_structure(t, d)
	_check_loop_continuity(t, d)
	_check_export_plan(t)


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Snow Boarder resolves its frost trail, ice glint and powder fan textures without fallback")


static func _check_structure(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	# Snow powder must read as white snow on a dark track, so it uses ALPHA; light layers stay ADDITIVE.
	var powder_alpha := ["start.powder_left", "start.powder_right"].all(func(layer_id: String) -> bool:
		return start.get(layer_id, {}).get("blend_mode") == "ALPHA"
	)
	# No underglow (keeps it apart from Rain Surfer): every LOOP layer is a world trail at a rear wheel.
	var rear_wheel_trails := loop.values().all(func(layer: Dictionary) -> bool:
		var offset: Array = layer.get("transform", {}).get("offset", [0.0, 0.0])
		return layer.get("type") == "PARTICLE" and layer.get("blend_mode") == "ADDITIVE" \
			and layer.get("space_mode") == "VEHICLE_FOLLOW_WORLD_TRAIL" \
			and is_equal_approx(absf(float(offset[0])), REAR_WHEEL_X) and float(offset[1]) > 0.0
	)
	t.expect_true(
		d.get("preset_id") == "talent.snow_boarder" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" and d.get("runtime_inputs", []).is_empty() \
		and phases.get("end", {}).get("layers", []).is_empty() \
		and start.size() == 3 and start.has("start.glints") and powder_alpha \
		and loop.size() == 2 and loop.has("loop.trail_left") and loop.has("loop.trail_right") \
		and rear_wheel_trails,
		"Snow Boarder bursts ALPHA powder from the rear wheels, then leaves additive frost trails at the rear wheels with no underglow"
	)


static func _check_loop_continuity(t: TestAssert, d: Dictionary) -> void:
	var loop := _by_id(d.get("phases", {}).get("loop", {}).get("layers", []))
	var ok := true
	for layer_id in ["loop.trail_left", "loop.trail_right"]:
		var p: Dictionary = loop.get(layer_id, {}).get("parameters", {})
		# Several overlapping segments per trail so the world line reads as continuous.
		ok = ok and float(p.get("emission_rate_per_second", 0.0)) * float(p.get("lifetime_seconds", 0.0)) >= 3.0
	t.expect_true(ok, "Snow Boarder frost trails overlap into a continuous line")


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(
		plan.success and ids == ["fx.snow_boarder_frost_trail", "fx.snow_boarder_ice_glint", "fx.snow_boarder_powder_fan"],
		"Snow Boarder compiles to a package that depends only on its three textures"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
