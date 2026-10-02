extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const SOURCE_PATH = "res://presets/examples/talent.shockwave.vfx.json"
const IMPACT_PATH = "res://presets/examples/talent.shockwave_impact.vfx.json"
const ASSETS := {
	"fx.shockwave_ring": Vector2i(512, 512),
	"fx.shockwave_impact_arc_a": Vector2i(192, 320),
	"fx.shockwave_impact_arc_b": Vector2i(192, 320),
}
# Bright core radius of the ring texture (texels); the wave scale is effect_radius / this.
const RING_REFERENCE_RADIUS := 231.0


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var source: VfxResult = Pipeline.new().load_and_validate(SOURCE_PATH)
	var impact: VfxResult = Pipeline.new().load_and_validate(IMPACT_PATH)
	if not source.success or not impact.success:
		t.expect_true(false, "Shockwave requires valid source and impact Presets")
		return
	_check_source(t, source.value.normalized_data)
	_check_impact(t, impact.value.normalized_data)
	_check_export_plans(t)


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Shockwave resolves its ring and impact lightning textures without fallback")


static func _check_source(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var wave: Dictionary = start.get("start.wave", {})
	# The wave reaches exactly the gameplay radius: scale = effect_radius / ring reference, unclamped.
	var radius_axes := 0
	for binding in wave.get("modulations", []):
		var mapping: Dictionary = binding.get("mapping", {})
		if binding.get("source", {}).get("input") == "effect_radius" and binding.get("operation") == "MULTIPLY":
			if is_equal_approx(float(mapping.get("input_max", 0.0)), RING_REFERENCE_RADIUS) \
				and is_equal_approx(float(mapping.get("output_max", 0.0)), 1.0) \
				and is_equal_approx(float(mapping.get("input_min", -1.0)), 0.0) \
				and is_equal_approx(float(mapping.get("output_min", -1.0)), 0.0):
				radius_axes += 1
	var clamped: bool = wave.get("modulation_clamps", []).any(func(clamp: Dictionary) -> bool: return str(clamp.get("target", "")).begins_with("TRANSFORM_SCALE"))
	# LOOP is length-agnostic (Game owns it): continuous emission only.
	var loop_continuous := loop.values().all(func(layer: Dictionary) -> bool: return layer.get("parameters", {}).get("emission_mode") == "CONTINUOUS")
	t.expect_true(
		d.get("preset_id") == "talent.shockwave" and d.get("runtime_inputs", []) == ["effect_radius"] \
		and wave.get("type") == "TEXTURED_SPRITE" and radius_axes == 2 and not clamped and loop_continuous \
		and float(phases.get("end", {}).get("duration_seconds", 0.0)) > 0.0,
		"Shockwave source wave scales to the supplied gameplay radius without clamps and its LOOP is length-agnostic"
	)


static func _check_impact(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var sparks: Dictionary = loop.get("loop.body_sparks", {})
	var emitter: Dictionary = sparks.get("parameters", {}).get("emitter", {})
	var start_duration := float(phases.get("start", {}).get("duration_seconds", 0.0))
	var first_arc := start_duration + 1.0 / float(loop.get("loop.arc_a", {}).get("parameters", {}).get("emission_rate_per_second", 0.001))
	var sprite_budget := 0
	for layer in loop.values():
		sprite_budget += int(layer.get("parameters", {}).get("max_particles", 0))
	t.expect_true(
		d.get("preset_id") == "talent.shockwave_impact" and d.get("runtime_inputs", []).is_empty() \
		and sparks.get("render_plane") == "OVER_VEHICLE" and emitter.get("shape") == "BOX" \
		and float(start.get("start.hit_arc", {}).get("parameters", {}).get("lifetime_seconds", 0.0)) >= first_arc \
		and sprite_budget <= 7 \
		and loop.values().all(func(layer: Dictionary) -> bool: return layer.get("parameters", {}).get("emission_mode") == "CONTINUOUS"),
		"Shockwave impact wraps the hit car in slow lightning with sparks crackling over the body, light enough for many targets"
	)


static func _check_export_plans(t: TestAssert) -> void:
	var source_plan: VfxResult = Export.new().validate_saved_source(SOURCE_PATH)
	var impact_plan: VfxResult = Export.new().validate_saved_source(IMPACT_PATH)
	var source_manifest: Dictionary = source_plan.value.manifest_data() if source_plan.success else {}
	var impact_manifest: Dictionary = impact_plan.value.manifest_data() if impact_plan.success else {}
	var impact_ids: Array = impact_manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	impact_ids.sort()
	t.expect_true(
		source_plan.success and impact_plan.success \
		and source_manifest.get("requirements", {}).get("runtime_inputs", []) == ["effect_radius"] \
		and int(source_manifest.get("runtime_definition", {}).get("version", 0)) == 2 \
		and impact_ids == ["fx.furious_overtake_spark", "fx.shockwave_impact_arc_a", "fx.shockwave_impact_arc_b"],
		"Shockwave compiles to a Runtime v2 source package with effect_radius and an impact package with its lightning and spark textures"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
