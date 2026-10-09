extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")

const PRESET_PATH := "res://presets/examples/driving.standard_boost.vfx.json"
const JET_X := [-66.0, -22.0, 22.0, 66.0]
const ROOT_Y := 208.0
const PIVOT := [0.0, -178.0]


static func run(tests: TestAssert) -> void:
	_test_booster_textures_are_non_fallback_rgba_jet_and_flare(tests)
	_test_standard_booster_v2_structure_and_constant_thrust(tests)
	_test_jet_roots_stay_on_the_shared_nozzle_line_and_start_hands_over_to_loop(tests)
	_test_loop_jets_flicker_continuously_with_distinct_small_oscillations(tests)
	_test_start_spools_up_and_flares_decay_to_the_loop_nozzle_level(tests)
	_test_end_particles_keep_the_jet_root_fixed_while_the_jet_shortens(tests)
	_test_lod_importance_keeps_four_jets_on_low(tests)


static func _test_booster_textures_are_non_fallback_rgba_jet_and_flare(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var jet_result: VfxResult = resolver.resolve("fx.booster_jet")
	var flare_result: VfxResult = resolver.resolve("fx.booster_nozzle_flare")
	var jet_texture: Texture2D = jet_result.value.get("texture") as Texture2D if jet_result.success else null
	var flare_texture: Texture2D = flare_result.value.get("texture") as Texture2D if flare_result.success else null
	var jet_image: Image = jet_texture.get_image() if jet_texture != null else null
	var flare_image: Image = flare_texture.get_image() if flare_texture != null else null
	var jet_metrics := _alpha_metrics(jet_image)
	var flare_metrics := _alpha_metrics(flare_image)
	tests.expect_true(
		jet_result.success
		and flare_result.success
		and jet_result.issues.is_empty()
		and flare_result.issues.is_empty()
		and not jet_result.value.get("is_fallback", true)
		and not flare_result.value.get("is_fallback", true)
		and jet_image != null
		and flare_image != null
		and jet_image.get_size() == Vector2i(96, 384)
		and flare_image.get_size() == Vector2i(128, 128)
		and jet_metrics == {"alpha_pixels": 12239, "strong_pixels": 3756, "bounds": Rect2i(19, 14, 58, 342)}
		and flare_metrics == {"alpha_pixels": 9622, "strong_pixels": 2093, "bounds": Rect2i(7, 6, 114, 114)},
		"Standard Booster v2 resolves the approved 96x384 jet and 128x128 nozzle flare RGBA textures without Preview fallback and keeps their measured alpha footprints (jet root at y=14, nothing above it)"
	)


static func _test_standard_booster_v2_structure_and_constant_thrust(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate(PRESET_PATH)
	var data: Dictionary = document_result.value.normalized_data if document_result.success else {}
	var phases: Dictionary = data.get("phases", {})
	var start_layers: Array = phases.get("start", {}).get("layers", [])
	var loop_layers: Array = phases.get("loop", {}).get("layers", [])
	var end_layers: Array = phases.get("end", {}).get("layers", [])
	var all_layers: Array = start_layers + loop_layers + end_layers
	var sprite_phases_ok: bool = (start_layers + loop_layers).all(func(layer: Dictionary) -> bool: return layer.get("type") == "TEXTURED_SPRITE")
	var end_particles_ok: bool = end_layers.all(func(layer: Dictionary) -> bool: return layer.get("type") == "PARTICLE" and layer.get("parameters", {}).get("emission_mode") == "BURST")
	var routing_ok: bool = all_layers.all(func(layer: Dictionary) -> bool: return layer.get("render_plane") == "UNDER_VEHICLE" and layer.get("blend_mode") == "ADDITIVE" and layer.get("space_mode", "VEHICLE_LOCAL") == "VEHICLE_LOCAL" and layer.get("anchors") == ["CENTER"])
	var textures_ok: bool = all_layers.all(func(layer: Dictionary) -> bool:
		var parameters: Dictionary = layer.get("parameters", {})
		var reference: String = str(parameters.get("texture_asset_ref", parameters.get("sprite_asset_ref", "")))
		return reference == "fx.booster_jet" or reference == "fx.booster_nozzle_flare")
	var no_runtime_input_binding := true
	for layer in start_layers + loop_layers:
		for binding in layer.get("modulations", []):
			if binding.get("source", {}).get("type") != "PRESET_SOURCE":
				no_runtime_input_binding = false
	tests.expect_true(
		document_result.success
		and data.get("preset_id") == "driving.standard_boost"
		and data.get("category") == "BOOST"
		and data.get("lifecycle", {}).get("mode") == "START_LOOP_END"
		and data.get("default_space_mode") == "VEHICLE_LOCAL"
		and is_equal_approx(float(phases.get("start", {}).get("duration_seconds", 0.0)), 0.16)
		and is_equal_approx(float(phases.get("end", {}).get("duration_seconds", 0.0)), 0.16)
		and start_layers.size() == 8
		and loop_layers.size() == 8
		and end_layers.size() == 8
		and sprite_phases_ok
		and end_particles_ok
		and routing_ok
		and textures_ok
		and data.get("runtime_inputs") == ["intensity"]
		and no_runtime_input_binding,
		"Standard Booster v2 is an eight-Layer-per-Phase START_LOOP_END VEHICLE_LOCAL UNDER_VEHICLE ADDITIVE Preset: persistent sprites in START and LOOP, particle bursts in END, only the new textures, and no modulation bound to a Runtime Input (constant thrust, not speed-linked); intensity stays declared because the Game controller supplies it"
	)


static func _test_jet_roots_stay_on_the_shared_nozzle_line_and_start_hands_over_to_loop(tests: TestAssert) -> void:
	var phases := _phases()
	if phases.is_empty():
		tests.expect_true(false, "Standard Booster v2 jet alignment requires a valid Preset document")
		return
	var matches := true
	for phase_name in ["start", "loop"]:
		var jets := _layers_with_prefix(phases[phase_name].get("layers", []), "%s.jet_" % phase_name)
		matches = matches and jets.size() == 4
		for index in jets.size():
			var layer: Dictionary = jets[index]
			var transform: Dictionary = layer.get("transform", {})
			var offset: Array = transform.get("offset", [])
			var scale: Array = transform.get("scale", [])
			var root_y := float(offset[1]) + float(PIVOT[1]) * float(scale[1]) if offset.size() == 2 and scale.size() == 2 else -999.0
			matches = matches \
				and layer.get("importance") == "CORE" \
				and layer.get("parameters", {}).get("texture_asset_ref") == "fx.booster_jet" \
				and is_equal_approx(float(offset[0]), float(JET_X[index])) \
				and absf(root_y - ROOT_Y) < 0.5 \
				and transform.get("modulation_pivot_local") == PIVOT \
				and float(scale[1]) >= 0.55 and float(scale[1]) <= 0.65 \
				and float(scale[0]) >= 1.25 and float(scale[0]) <= 1.6
	var start_jets := _layers_with_prefix(phases["start"].get("layers", []), "start.jet_")
	var loop_jets := _layers_with_prefix(phases["loop"].get("layers", []), "loop.jet_")
	for index in mini(start_jets.size(), loop_jets.size()):
		matches = matches \
			and start_jets[index].get("transform", {}).get("offset") == loop_jets[index].get("transform", {}).get("offset") \
			and start_jets[index].get("transform", {}).get("scale") == loop_jets[index].get("transform", {}).get("scale") \
			and is_equal_approx(float(start_jets[index].get("parameters", {}).get("opacity")), float(loop_jets[index].get("parameters", {}).get("opacity")))
	tests.expect_true(matches, "Standard Booster v2 keeps all START and LOOP jets at x -66/-22/22/66 with the texture root pinned to y=208 (Engineer nozzle rings and Energy Conversion depend on it) and hands START over to LOOP with identical base transform and opacity")


static func _test_loop_jets_flicker_continuously_with_distinct_small_oscillations(tests: TestAssert) -> void:
	var data := _data()
	if data.is_empty():
		tests.expect_true(false, "Standard Booster v2 dynamics check requires a valid Preset document")
		return
	var sources_by_id := {}
	for source in data.get("runtime_modulation_sources", []):
		sources_by_id[source.get("id")] = source
	var jets := _layers_with_prefix(data.phases.loop.layers, "loop.jet_")
	var frequencies := {}
	var matches := jets.size() == 4
	for layer in jets:
		var length_min := 1.0
		var length_max := 1.0
		var kinds := {}
		for binding in layer.get("modulations", []):
			var source: Dictionary = sources_by_id.get(binding.get("source", {}).get("source_id"), {})
			var mapping: Dictionary = binding.get("mapping", {})
			var target := str(binding.get("target"))
			matches = matches \
				and ((source.get("type") == "OSCILLATOR" and is_equal_approx(float(mapping.get("input_min")), -1.0) and is_equal_approx(float(mapping.get("input_max")), 1.0)) or (source.get("type") == "LINEAR_PHASE" and is_equal_approx(float(mapping.get("input_min")), 0.0) and is_equal_approx(float(mapping.get("input_max")), 1.0))) \
				and float(source.get("frequency_hz", 0.0)) >= 2.0 and float(source.get("frequency_hz", 0.0)) <= 22.0
			frequencies[snappedf(float(source.get("frequency_hz", 0.0)), 0.01)] = true
			kinds[target] = true
			if target == "TRANSFORM_SCALE_Y":
				length_min *= minf(float(mapping.get("output_min")), float(mapping.get("output_max")))
				length_max *= maxf(float(mapping.get("output_min")), float(mapping.get("output_max")))
		var scale_y := float(layer.get("transform", {}).get("scale", [1.0, 1.0])[1])
		var reach_max := (ROOT_Y + 340.0 * scale_y * length_max - 256.0) * 0.09025
		var reach_min := (ROOT_Y + 340.0 * scale_y * length_min - 256.0) * 0.09025
		# Design cap: the longest moment stays within about 2/3 of the first draft (15px behind the rear); the shortest still shows a stub.
		matches = matches \
			and kinds.has("TRANSFORM_SCALE_Y") and kinds.has("TRANSFORM_SCALE_X") and kinds.has("TRANSFORM_ROTATION_DEGREES") and kinds.has("VISUAL_OPACITY_MULTIPLIER") \
			and length_max / length_min >= 1.8 \
			and reach_max <= 15.5 and reach_max >= 13.0 \
			and reach_min >= 4.0 and reach_min <= 8.0
	var nozzles := _layers_with_prefix(data.phases.loop.layers, "loop.nozzle_")
	matches = matches and nozzles.size() == 4
	for index in nozzles.size():
		var layer: Dictionary = nozzles[index]
		matches = matches \
			and layer.get("parameters", {}).get("texture_asset_ref") == "fx.booster_nozzle_flare" \
			and is_equal_approx(float(layer.get("parameters", {}).get("opacity")), 0.5) \
			and _scale_is(layer, 0.55, 0.55) \
			and is_equal_approx(float(layer.get("transform", {}).get("offset", [0.0, 0.0])[0]), float(JET_X[index]))
	tests.expect_true(matches and frequencies.size() >= 10, "Standard Booster v2 LOOP jets are persistent sprites whose length (two layered sawtooth phases that snap up and decay, 1.8x+ swing, longest reach about 14-15px behind the rear), width, sway (+-4 degrees) and opacity all move through 2-22 Hz oscillators with distinct frequencies per jet, and the four nozzle flares share the jet opacity oscillators")


static func _test_start_spools_up_and_flares_decay_to_the_loop_nozzle_level(tests: TestAssert) -> void:
	var data := _data()
	if data.is_empty():
		tests.expect_true(false, "Standard Booster v2 START check requires a valid Preset document")
		return
	var spool: Dictionary = {}
	for source in data.get("runtime_modulation_sources", []):
		if source.get("id") == "start.spool":
			spool = source
	var matches: bool = spool.get("type") == "LINEAR_PHASE" and is_equal_approx(float(spool.get("frequency_hz", 0.0)), 1.0 / 0.16)
	var start_layers: Array = data.phases.start.layers
	for layer in _layers_with_prefix(start_layers, "start.jet_"):
		var outputs := _binding_outputs(layer)
		matches = matches \
			and outputs.get("TRANSFORM_SCALE_Y") == [0.35, 1.0] \
			and outputs.get("TRANSFORM_SCALE_X") == [0.8, 1.0] \
			and outputs.get("VISUAL_OPACITY_MULTIPLIER") == [0.6, 1.0]
	var flares := _layers_with_prefix(start_layers, "start.flare_")
	matches = matches and flares.size() == 4
	for layer in flares:
		var outputs := _binding_outputs(layer)
		matches = matches \
			and outputs.get("TRANSFORM_SCALE_X") == [2.4, 1.0] \
			and outputs.get("TRANSFORM_SCALE_Y") == [2.4, 1.0] \
			and outputs.get("VISUAL_OPACITY_MULTIPLIER") == [2.8, 1.0] \
			and _scale_is(layer, 0.55, 0.55) \
			and is_equal_approx(float(layer.get("parameters", {}).get("opacity")), 0.5)
	tests.expect_true(matches, "Standard Booster v2 START runs one 1/0.16 Hz LINEAR_PHASE spool: jets grow from 35% length / 80% width / 60% opacity to the LOOP values, and the nozzle flares start 2.4x larger and 2.8x brighter and settle on the LOOP nozzle size and opacity so there is no dark gap")


static func _test_end_particles_keep_the_jet_root_fixed_while_the_jet_shortens(tests: TestAssert) -> void:
	var data := _data()
	if data.is_empty():
		tests.expect_true(false, "Standard Booster v2 END check requires a valid Preset document")
		return
	var jets := _layers_with_prefix(data.phases.end.layers, "end.jet_")
	var loop_jets := _layers_with_prefix(data.phases.loop.layers, "loop.jet_")
	var matches := jets.size() == 4
	for index in jets.size():
		var layer: Dictionary = jets[index]
		var parameters: Dictionary = layer.get("parameters", {})
		var life := float(parameters.get("lifetime_seconds", 0.0))
		var size_start := float(parameters.get("size_start", 0.0))
		var size_end := float(parameters.get("size_end", 0.0))
		var centre_y := float(layer.get("transform", {}).get("offset", [0.0, 0.0])[1])
		# Particle size is half the texture long side, so the sprite is (2 x size) tall and the root sits 178/384 of that above its centre.
		var root_factor := 2.0 * 178.0 / 384.0
		var root_start := centre_y - root_factor * size_start
		var forward_travel := float(parameters.get("speed_min", 0.0)) * life
		var root_end := (centre_y - forward_travel) - root_factor * size_end
		matches = matches \
			and parameters.get("sprite_asset_ref") == "fx.booster_jet" \
			and loop_jets.size() == 4 \
			and absf(2.0 * size_start - 384.0 * float(loop_jets[index].get("transform", {}).get("scale", [1.0, 1.0])[1])) < 0.5 \
			and absf(size_start * 0.5 * float(layer.get("transform", {}).get("scale", [1.0, 1.0])[0]) - 96.0 * float(loop_jets[index].get("transform", {}).get("scale", [1.0, 1.0])[0])) < 0.5 \
			and is_equal_approx(float(parameters.get("direction_degrees", -1.0)), 0.0) \
			and is_equal_approx(float(parameters.get("speed_min", 0.0)), float(parameters.get("speed_max", -1.0))) \
			and is_equal_approx(life, 0.16) \
			and size_end > 0.0 and size_end / size_start >= 0.4 and size_end / size_start <= 0.5 \
			and absf(root_start - ROOT_Y) < 0.5 \
			and absf(root_end - ROOT_Y) < 0.5 \
			and float(parameters.get("alpha_start", 0.0)) > 0.0 and is_zero_approx(float(parameters.get("alpha_end", -1.0)))
	var nozzles := _layers_with_prefix(data.phases.end.layers, "end.nozzle_")
	matches = matches and nozzles.size() == 4
	for layer in nozzles:
		var parameters: Dictionary = layer.get("parameters", {})
		matches = matches \
			and parameters.get("sprite_asset_ref") == "fx.booster_nozzle_flare" \
			and is_equal_approx(float(parameters.get("alpha_start", 0.0)), 0.5) \
			and is_zero_approx(float(parameters.get("alpha_end", -1.0))) \
			and float(parameters.get("lifetime_seconds", 1.0)) <= 0.12
	tests.expect_true(matches, "Standard Booster v2 END jets are BURST particles that move forward by exactly the amount the texture root would otherwise drop, so the root stays on y=208 while the jet shrinks to 45% and fades, followed by short nozzle flare fades")


static func _test_lod_importance_keeps_four_jets_on_low(tests: TestAssert) -> void:
	var data := _data()
	if data.is_empty():
		tests.expect_true(false, "Standard Booster v2 LOD importance check requires a valid Preset document")
		return
	var counts := {"CORE": 0, "DETAIL": 0, "EXTRA": 0}
	for layer in data.phases.loop.layers:
		counts[str(layer.get("importance"))] += 1
	var jets_core: bool = _layers_with_prefix(data.phases.loop.layers, "loop.jet_").all(func(layer: Dictionary) -> bool: return layer.get("importance") == "CORE")
	var nozzles := _layers_with_prefix(data.phases.loop.layers, "loop.nozzle_")
	var outer_detail: bool = nozzles.size() == 4 and nozzles[0].get("importance") == "DETAIL" and nozzles[3].get("importance") == "DETAIL"
	var inner_extra: bool = nozzles.size() == 4 and nozzles[1].get("importance") == "EXTRA" and nozzles[2].get("importance") == "EXTRA"
	tests.expect_true(jets_core and outer_detail and inner_extra and counts == {"CORE": 4, "DETAIL": 2, "EXTRA": 2}, "Standard Booster v2 LOOP importance is four CORE jets, two DETAIL outer nozzle flares and two EXTRA inner nozzle flares, so LOW keeps the four jets and MEDIUM adds the outer flares")


static func _data() -> Dictionary:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate(PRESET_PATH)
	return document_result.value.normalized_data if document_result.success else {}


static func _phases() -> Dictionary:
	return _data().get("phases", {})


static func _layers_with_prefix(layers: Array, prefix: String) -> Array:
	var result: Array = []
	for layer in layers:
		if layer is Dictionary and str(layer.get("id", "")).begins_with(prefix):
			result.append(layer)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id")) < str(right.get("id")))
	return result


static func _scale_is(layer: Dictionary, x: float, y: float) -> bool:
	var scale: Array = layer.get("transform", {}).get("scale", [])
	return scale.size() == 2 and absf(float(scale[0]) - x) < 0.0001 and absf(float(scale[1]) - y) < 0.0001


static func _binding_outputs(layer: Dictionary) -> Dictionary:
	var outputs := {}
	for binding in layer.get("modulations", []):
		var mapping: Dictionary = binding.get("mapping", {})
		outputs[str(binding.get("target"))] = [float(mapping.get("output_min")), float(mapping.get("output_max"))]
	return outputs


static func _alpha_metrics(image: Image) -> Dictionary:
	if image == null:
		return {}
	var alpha_pixels := 0
	var strong_pixels := 0
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.0:
				alpha_pixels += 1
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
				var luma: float = 0.2126 * color.r * 255.0 + 0.7152 * color.g * 255.0 + 0.0722 * color.b * 255.0
				if color.a >= 0.5 and luma >= 160.0:
					strong_pixels += 1
	return {
		"alpha_pixels": alpha_pixels,
		"strong_pixels": strong_pixels,
		"bounds": Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	}
