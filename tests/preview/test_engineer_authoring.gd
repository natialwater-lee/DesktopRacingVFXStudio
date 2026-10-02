extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.engineer.vfx.json"
const ASSETS := {
	"fx.engineer_scan_line": Vector2i(256, 64),
	"fx.engineer_corner_bracket": Vector2i(128, 128),
	"fx.engineer_nozzle_ring": Vector2i(64, 64),
}
const CORNERS := ["fl", "fr", "rr", "rl"]
# Standard boost jet roots; nozzle rings must sit on them.
const JET_X := [-66.0, -22.0, 22.0, 66.0]


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Engineer requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	_check_structure(t, d)
	_check_scan(t, d)
	_check_nozzles(t, d)
	_check_export_plan(t)


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Engineer resolves its scan line, corner bracket and nozzle ring textures without fallback")


static func _check_structure(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var finish := _by_id(phases.get("end", {}).get("layers", []))
	var ok := true
	# Same bracket position/rotation through START, LOOP and the END fade-out.
	for corner in CORNERS:
		var a: Dictionary = start.get("start.bracket_%s" % corner, {})
		var b: Dictionary = loop.get("loop.bracket_%s" % corner, {})
		var c: Dictionary = finish.get("end.bracket_%s" % corner, {})
		ok = ok and a.get("type") == "TEXTURED_SPRITE" and b.get("type") == "TEXTURED_SPRITE" and c.get("type") == "PARTICLE" \
			and a.get("transform", {}).get("offset") == b.get("transform", {}).get("offset") \
			and b.get("transform", {}).get("offset") == c.get("transform", {}).get("offset") \
			and is_equal_approx(float(a.get("transform", {}).get("rotation_degrees", -1.0)), float(c.get("parameters", {}).get("rotation_min_degrees", -2.0)))
	t.expect_true(
		d.get("preset_id") == "talent.engineer" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" and d.get("runtime_inputs", []) == ["boost_active"] \
		and start.size() == 5 and loop.size() == 9 and finish.size() == 4 and ok,
		"Engineer keeps four corner brackets in place from START through the END fade-out"
	)


static func _check_scan(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var sources := {}
	for source in d.get("runtime_modulation_sources", []):
		sources[str(source.get("id", ""))] = source
	var start_duration := float(phases.get("start", {}).get("duration_seconds", 0.0))
	var sweep: Dictionary = sources.get("scan.sweep", {})
	# The LOOP scanner must be at the tail (sine peak) when START hands over, where the START sweep ends.
	var at_handover := sin(TAU * float(sweep.get("frequency_hz", 0.0)) * start_duration + deg_to_rad(float(sweep.get("phase_degrees", 0.0))))
	var ok := true
	for layer in [start.get("start.scan", {}), loop.get("loop.scan", {})]:
		var mods: Array = layer.get("modulations", [])
		var scale: Array = layer.get("transform", {}).get("scale", [1.0, 1.0])
		ok = ok and layer.get("render_plane") == "OVER_VEHICLE" and layer.get("type") == "TEXTURED_SPRITE" \
			and float(scale[1]) > float(scale[0]) and mods.size() == 1 and mods[0].get("target") == "TRANSFORM_OFFSET_Y"
	t.expect_true(ok and at_handover > 0.99, "Engineer scan line is a thick over-vehicle sweep that hands over from START to the LOOP scanner at the tail")


static func _check_nozzles(t: TestAssert, d: Dictionary) -> void:
	var loop := _by_id(d.get("phases", {}).get("loop", {}).get("layers", []))
	var ok := true
	for index in JET_X.size():
		var layer: Dictionary = loop.get("loop.nozzle_%d" % (index + 1), {})
		var opacity_on_boost := false
		for binding in layer.get("modulations", []):
			if binding.get("source", {}).get("input") == "boost_active" and binding.get("target") == "VISUAL_OPACITY_MULTIPLIER":
				opacity_on_boost = is_equal_approx(float(binding.get("mapping", {}).get("output_min", -1.0)), 0.0)
		ok = ok and opacity_on_boost and is_equal_approx(float(layer.get("transform", {}).get("offset", [0.0, 0.0])[0]), JET_X[index])
	t.expect_true(ok, "Engineer nozzle rings sit on the four standard boost jets and stay hidden without boost")


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(
		plan.success and ids == ["fx.engineer_corner_bracket", "fx.engineer_nozzle_ring", "fx.engineer_scan_line"] \
		and manifest.get("requirements", {}).get("runtime_inputs", []) == ["boost_active"] \
		and int(manifest.get("runtime_definition", {}).get("version", 0)) == 2,
		"Engineer compiles to a Runtime v2 package with its three textures and the boost_active input"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
