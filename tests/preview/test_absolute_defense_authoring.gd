extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.absolute_defense.vfx.json"
const ASSETS := {
	"fx.absolute_defense_curtain_l_a": Vector2i(192, 408),
	"fx.absolute_defense_curtain_l_b": Vector2i(192, 408),
	"fx.absolute_defense_curtain_r_a": Vector2i(192, 408),
	"fx.absolute_defense_curtain_r_b": Vector2i(192, 408),
	"fx.absolute_defense_rear_front": Vector2i(512, 246),
}
# Largest car edge (source px); walls stand just outside it.
const CAR_HALF_WIDTH := 115.0


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Absolute Defense requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	_check_structure(t, d)
	_check_wall_flow(t, d)
	_check_impact(t, d)
	_check_hum(t, d)
	_check_export_plan(t)


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Absolute Defense resolves its side wall and rear shield curtain and rear front textures without fallback")


static func _check_structure(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var finish := _by_id(phases.get("end", {}).get("layers", []))
	var walls_outside := true
	for side in ["l", "r"]:
		for layer in [loop.get("loop.wall_%s_a" % side, {}), loop.get("loop.wall_%s_b" % side, {}), finish.get("end.wall_%s" % side, {})]:
			walls_outside = walls_outside and absf(float(layer.get("transform", {}).get("offset", [0.0, 0.0])[0])) > CAR_HALF_WIDTH
	var all_layers: Array = []
	for phase in [start, loop, finish]:
		all_layers.append_array(phase.values())
	var under := all_layers.all(func(layer: Dictionary) -> bool: return layer.get("render_plane") == "UNDER_VEHICLE" and layer.get("blend_mode") == "ADDITIVE")
	t.expect_true(
		d.get("preset_id") == "talent.absolute_defense" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" and d.get("runtime_inputs", []) == ["defense_impact"] \
		and start.size() == 3 and loop.size() == 5 and finish.size() == 3 and walls_outside and under,
		"Absolute Defense raises walls outside the car and a rear shield, then fades them out in END"
	)


static func _check_wall_flow(t: TestAssert, d: Dictionary) -> void:
	var loop := _by_id(d.get("phases", {}).get("loop", {}).get("layers", []))
	var ok := true
	for side in ["l", "r"]:
		var a: Array = _preset_source_modulations(loop.get("loop.wall_%s_a" % side, {}))
		var b: Array = _preset_source_modulations(loop.get("loop.wall_%s_b" % side, {}))
		# B is the exact inverse of A on the same oscillator, so the pair cross-fades.
		ok = ok and a.size() == 1 and b.size() == 1 \
			and a[0].get("source") == b[0].get("source") \
			and is_equal_approx(float(a[0].get("mapping", {}).get("output_min", 0.0)), float(b[0].get("mapping", {}).get("output_max", 1.0))) \
			and is_equal_approx(float(a[0].get("mapping", {}).get("output_max", 0.0)), float(b[0].get("mapping", {}).get("output_min", 1.0)))
	t.expect_true(ok, "Absolute Defense side walls A/B cross-fade on one oscillator so the pattern flows")


static func _check_impact(t: TestAssert, d: Dictionary) -> void:
	var loop := _by_id(d.get("phases", {}).get("loop", {}).get("layers", []))
	var shield: Dictionary = loop.get("loop.shield", {})
	var targets := _impact_targets(shield)
	var glow: Dictionary = targets.get("VISUAL_OPACITY_MULTIPLIER", {})
	var grow_y: Dictionary = targets.get("TRANSFORM_SCALE_Y", {})
	t.expect_true(
		targets.size() == 3 and is_equal_approx(float(glow.get("output_min", 0.0)), 1.0) and float(glow.get("output_max", 0.0)) > 1.5 \
		and float(grow_y.get("output_max", 0.0)) > 1.5 and float(shield.get("transform", {}).get("modulation_pivot_local", [0.0, 0.0])[1]) < 0.0,
		"Absolute Defense rear shield flashes and swells backwards when defense_impact spikes, unchanged at rest"
	)
	var curtains_react := true
	for side in ["l", "r"]:
		for variant in ["a", "b"]:
			var curtain: Dictionary = loop.get("loop.wall_%s_%s" % [side, variant], {})
			var curtain_targets := _impact_targets(curtain)
			var pivot_x := float(curtain.get("transform", {}).get("modulation_pivot_local", [0.0, 0.0])[0])
			var offset_x := float(curtain.get("transform", {}).get("offset", [0.0, 0.0])[0])
			# Pivot on the car side so the swell pushes the curtain outward.
			curtains_react = curtains_react and curtain_targets.size() == 2 \
				and float(curtain_targets.get("VISUAL_OPACITY_MULTIPLIER", {}).get("output_max", 0.0)) > 1.5 \
				and float(curtain_targets.get("TRANSFORM_SCALE_X", {}).get("output_max", 0.0)) > 1.0 \
				and signf(pivot_x) == -signf(offset_x)
	t.expect_true(curtains_react, "Absolute Defense side curtains brighten and swell outward together with the rear shield on defense_impact")


static func _impact_targets(layer: Dictionary) -> Dictionary:
	var targets := {}
	for binding in layer.get("modulations", []):
		if binding.get("source", {}).get("input") == "defense_impact":
			targets[str(binding.get("target", ""))] = binding.get("mapping", {})
	return targets


static func _preset_source_modulations(layer: Dictionary) -> Array:
	return layer.get("modulations", []).filter(func(binding: Dictionary) -> bool: return binding.get("source", {}).get("type") == "PRESET_SOURCE" and binding.get("target") == "VISUAL_OPACITY_MULTIPLIER")


static func _check_hum(t: TestAssert, d: Dictionary) -> void:
	var loop := _by_id(d.get("phases", {}).get("loop", {}).get("layers", []))
	var ok := true
	for id in ["loop.wall_l_a", "loop.wall_l_b", "loop.wall_r_a", "loop.wall_r_b", "loop.shield"]:
		var layer: Dictionary = loop.get(id, {})
		var axis := "TRANSFORM_OFFSET_Y" if id == "loop.shield" else "TRANSFORM_OFFSET_X"
		var hum: Array = layer.get("modulations", []).filter(func(binding: Dictionary) -> bool: return binding.get("source", {}).get("source_id") == "shield.hum")
		var outward := float(layer.get("transform", {}).get("offset", [0.0, 0.0])[0 if axis == "TRANSFORM_OFFSET_X" else 1])
		# All parts breathe on one oscillator: positive phase pushes every part away from the car.
		ok = ok and hum.size() == 1 and hum[0].get("target") == axis and hum[0].get("operation") == "ADD" \
			and signf(float(hum[0].get("mapping", {}).get("output_max", 0.0))) == signf(outward)
	t.expect_true(ok, "Absolute Defense curtains and rear front breathe outward together on one hum oscillator")


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	var expected: Array = ASSETS.keys()
	expected.sort()
	t.expect_true(
		plan.success and ids == expected \
		and manifest.get("requirements", {}).get("runtime_inputs", []) == ["defense_impact"] \
		and int(manifest.get("runtime_definition", {}).get("version", 0)) == 2,
		"Absolute Defense compiles to a Runtime v2 package with its five textures and the defense_impact input"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
