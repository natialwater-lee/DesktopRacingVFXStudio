extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.drift_master.vfx.json"
const ASSETS := {
	"fx.drift_master_neon_tail": Vector2i(256, 512),
	"fx.drift_master_tail_haze": Vector2i(256, 512),
	"fx.drift_master_drift_smoke": Vector2i(256, 256),
}


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Drift Master requires a valid Preset: %s" % str(result.errors))
		return
	var d: Dictionary = result.value.normalized_data
	var phases: Dictionary = d.get("phases", {})
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	t.expect_true(
		d.get("preset_id") == "talent.drift_master" and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" \
		and d.get("runtime_inputs", []) == ["turn_rate_normalized", "drift_active"] and loop.size() == 6,
		"Drift Master declares turn_rate + drift_active and keeps LOOP to six sprites"
	)
	var ok := true
	for s in ["l", "r"]:
		for id in ["loop.tail_" + s, "loop.haze_" + s]:
			var layer: Dictionary = loop.get(id, {})
			# Bend + swing follow the corner just driven: a right turn shifts the tail end to +x (negative rotation about
			# the head). Full scale at |turn| 0.1, the measured corner p90 (0.2 is almost never reached in a race).
			var bend: Array = layer.get("modulations", []).filter(func(m: Dictionary) -> bool: return m.get("target") == "VISUAL_BEND_OFFSET_X")
			var swing: Array = layer.get("modulations", []).filter(func(m: Dictionary) -> bool: return m.get("target") == "TRANSFORM_ROTATION_DEGREES")
			ok = ok and layer.has("visual_bend") and bend.size() == 1 and float(bend[0]["mapping"]["output_max"]) > 0.0 \
				and is_equal_approx(float(bend[0]["mapping"]["input_max"]), 0.1) \
				and swing.size() == 1 and float(swing[0]["mapping"]["output_max"]) < 0.0 and is_equal_approx(float(swing[0]["mapping"]["input_max"]), 0.1)
		var smoke: Dictionary = loop.get("loop.smoke_" + s, {})
		var hidden: Array = smoke.get("modulations", []).filter(func(m: Dictionary) -> bool: return m["source"].get("input") == "drift_active" and m.get("target") == "VISUAL_OPACITY_MULTIPLIER")
		ok = ok and smoke.get("blend_mode") == "ALPHA" and hidden.size() == 1 and float(hidden[0]["mapping"]["output_min"]) == 0.0
	t.expect_true(ok, "Drift Master tails bend with the corner and drift smoke only shows with drift_active")
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(plan.success and ids == ["fx.drift_master_drift_smoke", "fx.drift_master_neon_tail", "fx.drift_master_tail_haze"],
		"Drift Master compiles to a package with its three textures")


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Drift Master resolves its neon tail, tail haze and drift smoke textures without fallback")


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
