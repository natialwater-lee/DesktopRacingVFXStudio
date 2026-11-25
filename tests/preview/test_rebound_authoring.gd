extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.rebound.vfx.json"
const ASSETS := {
	"fx.rebound_rim_glow": Vector2i(64, 128),
	"fx.rebound_grip_rail": Vector2i(32, 512),
	"fx.rebound_contact_mist": Vector2i(128, 128),
}
# Shared rear-wheel contacts (front wheel positions differ per car and are not used).
const REAR_WHEEL := Vector2(84.0, 160.0)


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Rebound requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var end := _by_id(phases.get("end", {}).get("layers", []))
	t.expect_true(
		d.get("preset_id") == "talent.rebound" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" and d.get("runtime_inputs", []).is_empty() \
		and start.size() == 8 and loop.size() == 10 and end.size() == 6,
		"Rebound runs START / length-agnostic LOOP / END without runtime inputs"
	)
	var ok := true
	for side in [["l", -1.0], ["r", 1.0]]:
		for layer in [start.get("start.rim_%s" % side[0], {}), loop.get("loop.rim_%s" % side[0], {})]:
			var offset: Array = layer.get("transform", {}).get("offset", [0.0, 0.0])
			ok = ok and layer.get("type") == "TEXTURED_SPRITE" and layer.get("render_plane") == "OVER_VEHICLE" \
				and is_equal_approx(float(offset[0]), side[1] * REAR_WHEEL.x) and is_equal_approx(float(offset[1]), REAR_WHEEL.y)
		var mist: Dictionary = loop.get("loop.mist_%s" % side[0], {}).get("parameters", {})
		# Moving puffs pop in at full alpha, so LOOP keeps several faint ones overlapping.
		ok = ok and mist.get("emission_mode") == "CONTINUOUS" and float(mist.get("alpha_start", 1.0)) <= 0.7 \
			and float(mist.get("emission_rate_per_second", 0.0)) * float(mist.get("lifetime_seconds", 0.0)) >= 3.0
	t.expect_true(ok, "Rebound keeps the rim glow over the shared rear-wheel contacts and a steady energy flow behind them")
	_check_export_plan(t)


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Rebound resolves its rim glow, grip rail and contact mist textures without fallback")


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(
		plan.success and ids == ["fx.rebound_contact_mist", "fx.rebound_grip_rail", "fx.rebound_rim_glow"],
		"Rebound compiles to a package with its three textures"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
