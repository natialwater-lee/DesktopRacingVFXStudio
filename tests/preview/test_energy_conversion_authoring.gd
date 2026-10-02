extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.energy_conversion.vfx.json"
const ASSETS := {
	"fx.energy_conversion_swirl": Vector2i(320, 320),
	"fx.energy_conversion_rear_arc_a": Vector2i(256, 192),
	"fx.energy_conversion_rear_arc_b": Vector2i(256, 192),
	"fx.energy_conversion_release": Vector2i(96, 256),
}
const REAR_END_Y := 235.0


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Energy Conversion requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	_check_structure(t, d)
	_check_boost_release(t, d)
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
	t.expect_true(ok, "Energy Conversion resolves its swirl, rear arc and release textures without fallback")


static func _check_structure(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var all_layers: Array = []
	all_layers.append_array(start.values())
	all_layers.append_array(loop.values())
	var additive_under := all_layers.all(func(layer: Dictionary) -> bool:
		return layer.get("blend_mode") == "ADDITIVE" and layer.get("render_plane") == "UNDER_VEHICLE"
	)
	# The swirl spins and shrinks into the car (absorption).
	var swirl: Dictionary = start.get("start.swirl", {}).get("parameters", {})
	var absorbs := float(swirl.get("size_end", 1.0)) < float(swirl.get("size_start", 0.0)) \
		and absf(float(swirl.get("angular_velocity_min_degrees_per_second", 0.0))) > 0.0
	# Rear arcs stay on the rear half of the car, nudged left to centre the off-centre textures.
	var rear_arcs := ["loop.arc_a", "loop.arc_b", "start.arc_entry"].all(func(layer_id: String) -> bool:
		var layer: Dictionary = loop.get(layer_id, start.get(layer_id, {}))
		var offset: Array = layer.get("transform", {}).get("offset", [0.0, 0.0])
		return float(offset[1]) > 0.0 and float(offset[0]) < 0.0
	)
	t.expect_true(
		d.get("preset_id") == "talent.energy_conversion" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" and d.get("runtime_inputs", []) == ["boost_active"] \
		and phases.get("end", {}).get("layers", []).is_empty() \
		and start.size() == 3 and loop.size() == 3 and not loop.has("loop.release_trickle") \
		and additive_under and absorbs and rear_arcs,
		"Energy Conversion absorbs with a shrinking swirl, keeps blue arcs on the rear, shows teal only while boosting and declares only boost_active"
	)


static func _check_boost_release(t: TestAssert, d: Dictionary) -> void:
	var loop := _by_id(d.get("phases", {}).get("loop", {}).get("layers", []))
	var layer: Dictionary = loop.get("loop.boost_release", {})
	var transform: Dictionary = layer.get("transform", {})
	var scale: Array = transform.get("scale", [1.0, 1.0])
	var pivot: Array = transform.get("modulation_pivot_local", [0.0, 0.0])
	var root_y := float(transform.get("offset", [0.0, 0.0])[1]) + float(pivot[1])
	var targets := {}
	for binding in layer.get("modulations", []):
		var source: Dictionary = binding.get("source", {})
		if source.get("type") == "RUNTIME_INPUT" and source.get("input") == "boost_active":
			targets[str(binding.get("target", ""))] = binding.get("mapping", {})
	var opacity: Dictionary = targets.get("VISUAL_OPACITY_MULTIPLIER", {})
	t.expect_true(
		layer.get("type") == "TEXTURED_SPRITE" and targets.size() == 3 \
		and is_equal_approx(float(opacity.get("output_min", -1.0)), 0.0) and is_equal_approx(float(opacity.get("output_max", -1.0)), 1.0) \
		and targets.has("TRANSFORM_SCALE_Y") and targets.has("TRANSFORM_SCALE_X") \
		and absf(root_y - REAR_END_Y) < 1.0 and float(scale[0]) > 1.0,
		"Energy Conversion boost release is hidden without boost, grows from the rear end while boost_active rises"
	)


static func _check_start_bridges_into_loop(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start_duration := float(phases.get("start", {}).get("duration_seconds", 0.0))
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var arc_first := start_duration + 1.0 / float(loop.get("loop.arc_a", {}).get("parameters", {}).get("emission_rate_per_second", 0.001))
	var ok := float(start.get("start.arc_entry", {}).get("parameters", {}).get("lifetime_seconds", 0.0)) >= arc_first
	for layer_id in ["loop.arc_a", "loop.arc_b"]:
		var p: Dictionary = loop.get(layer_id, {}).get("parameters", {})
		ok = ok and float(p.get("lifetime_seconds", 0.0)) > 1.0 / float(p.get("emission_rate_per_second", 0.001))
	t.expect_true(ok, "Energy Conversion START arcs outlast the first LOOP arc emission and LOOP arcs overlap themselves")


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(
		plan.success and ids == ["fx.energy_conversion_rear_arc_a", "fx.energy_conversion_rear_arc_b", "fx.energy_conversion_release", "fx.energy_conversion_swirl"] \
		and manifest.get("requirements", {}).get("runtime_inputs", []) == ["boost_active"] \
		and int(manifest.get("runtime_definition", {}).get("version", 0)) == 2,
		"Energy Conversion compiles to a Runtime v2 package with its four textures and the boost_active input"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
