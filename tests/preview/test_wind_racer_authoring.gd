extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const Direction = preload("res://src/preview/rendering/vfx_particle_direction.gd")
const PATH = "res://presets/examples/talent.wind_racer.vfx.json"
const ASSETS := {
	"fx.wind_racer_flow_a": Vector2i(192, 320),
	"fx.wind_racer_flow_b": Vector2i(192, 320),
	"fx.wind_racer_tail": Vector2i(128, 192),
}


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Wind Racer requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	_check_structure(t, d)
	_check_continuous_flow(t, d)
	_check_export_plan(t)


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Wind Racer resolves the two airflow bundles and the tail texture without fallback")


static func _check_structure(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var all_layers: Array = []
	all_layers.append_array(phases.get("start", {}).get("layers", []))
	all_layers.append_array(phases.get("loop", {}).get("layers", []))
	var shared := all_layers.all(func(layer: Dictionary) -> bool:
		var p: Dictionary = layer.get("parameters", {})
		var color: Array = p.get("color_rgba", [])
		return layer.get("type") == "PARTICLE" and layer.get("blend_mode") == "ADDITIVE" \
			and layer.get("render_plane") == "UNDER_VEHICLE" \
			and layer.get("space_mode", "VEHICLE_LOCAL") == "VEHICLE_LOCAL" \
			and Direction.from_degrees(float(p.get("direction_degrees", 0.0))).y > 0.99 \
			and color.size() == 4 and float(color[2]) > float(color[0])
	)
	t.expect_true(
		d.get("preset_id") == "talent.wind_racer" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" and d.get("runtime_inputs", []).is_empty() \
		and phases.get("end", {}).get("layers", []).is_empty() \
		and start.size() == 2 and start.has("start.gust_a") and start.has("start.gust_b") \
		and loop.size() == 3 and loop.has("loop.flow_a") and loop.has("loop.flow_b") and loop.has("loop.tail") \
		and shared,
		"Wind Racer uses additive pale-blue airflow particles that all flow rearward, with no underglow and an empty END"
	)


static func _check_continuous_flow(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start_duration := float(phases.get("start", {}).get("duration_seconds", 0.0))
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var ok := true
	for layer_id in ["loop.flow_a", "loop.flow_b"]:
		var p: Dictionary = loop.get(layer_id, {}).get("parameters", {})
		var rate := float(p.get("emission_rate_per_second", 0.0))
		var life := float(p.get("lifetime_seconds", 0.0))
		# At least ~3 bundles overlap, so each pop-in is a small share of the total.
		ok = ok and rate * life >= 3.0 and int(p.get("max_particles", 0)) >= int(ceil(rate * life)) \
			and float(p.get("alpha_start", 1.0)) <= 0.5
	# START gusts must outlive START plus the first LOOP emission delay.
	var first_loop_delay := 1.0 / float(loop.get("loop.flow_a", {}).get("parameters", {}).get("emission_rate_per_second", 1.0))
	for layer_id in ["start.gust_a", "start.gust_b"]:
		ok = ok and float(start.get(layer_id, {}).get("parameters", {}).get("lifetime_seconds", 0.0)) >= start_duration + first_loop_delay
	t.expect_true(ok, "Wind Racer overlaps several faint airflow bundles and bridges START into LOOP without a gap")


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(
		plan.success and ids == ["fx.wind_racer_flow_a", "fx.wind_racer_flow_b", "fx.wind_racer_tail"],
		"Wind Racer compiles to a package that depends only on its three textures"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
