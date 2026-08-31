extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")


static func run(tests: TestAssert) -> void:
	_test_booster_textures_are_non_fallback_rgba_flames(tests)
	_test_standard_booster_uses_the_existing_start_loop_end_particle_contract(tests)
	_test_loop_jets_keep_four_independent_rearward_plumes(tests)


static func _test_booster_textures_are_non_fallback_rgba_flames(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var core_result: VfxResult = resolver.resolve("fx.booster_flame_core")
	var tail_result: VfxResult = resolver.resolve("fx.booster_flame_tail")
	var core_texture: Texture2D = core_result.value.get("texture") as Texture2D if core_result.success else null
	var tail_texture: Texture2D = tail_result.value.get("texture") as Texture2D if tail_result.success else null
	var core_image: Image = core_texture.get_image() if core_texture != null else null
	var tail_image: Image = tail_texture.get_image() if tail_texture != null else null
	var core_metrics := _alpha_metrics(core_image)
	var tail_metrics := _alpha_metrics(tail_image)
	tests.expect_true(
		core_result.success
		and tail_result.success
		and core_result.issues.is_empty()
		and tail_result.issues.is_empty()
		and core_result.value.get("source") == "TEXTURE"
		and tail_result.value.get("source") == "TEXTURE"
		and not core_result.value.get("is_fallback", true)
		and not tail_result.value.get("is_fallback", true)
		and core_image != null
		and tail_image != null
		and core_image.get_size() == Vector2i(64, 128)
		and tail_image.get_size() == Vector2i(64, 128)
		and core_metrics == {"alpha_pixels": 2717, "strong_pixels": 980, "bounds": Rect2i(13, 2, 39, 121)}
		and tail_metrics == {"alpha_pixels": 1431, "strong_pixels": 200, "bounds": Rect2i(20, 3, 31, 123)},
		"Standard Booster resolves both approved 64x128 RGBA flame textures without Preview fallback and keeps their specified tall visible alpha footprints"
	)


static func _test_standard_booster_uses_the_existing_start_loop_end_particle_contract(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.standard_boost.vfx.json")
	var data: Dictionary = document_result.value.normalized_data if document_result.success else {}
	var phases: Dictionary = data.get("phases", {})
	var start_layers: Array = phases.get("start", {}).get("layers", [])
	var loop_layers: Array = phases.get("loop", {}).get("layers", [])
	var end_layers: Array = phases.get("end", {}).get("layers", [])
	var all_particle_layers: bool = (start_layers + loop_layers + end_layers).all(func(layer: Dictionary) -> bool: return layer.get("type") == "PARTICLE" and layer.get("space_mode", "VEHICLE_LOCAL") == "VEHICLE_LOCAL")
	tests.expect_true(
		document_result.success
		and data.get("preset_id") == "driving.standard_boost"
		and data.get("category") == "BOOST"
		and data.get("lifecycle", {}).get("mode") == "START_LOOP_END"
		and data.get("default_space_mode") == "VEHICLE_LOCAL"
		and is_equal_approx(float(phases.get("start", {}).get("duration_seconds", 0.0)), 0.10)
		and is_equal_approx(float(phases.get("end", {}).get("duration_seconds", 0.0)), 0.14)
		and start_layers.size() == 4
		and loop_layers.size() == 8
		and end_layers.size() == 2
		and all_particle_layers,
		"Standard Booster validates through Schema v1 using only the existing VEHICLE_LOCAL PARTICLE START_LOOP_END contract"
	)


static func _test_loop_jets_keep_four_independent_rearward_plumes(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.standard_boost.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Standard Booster loop plume recipe requires a valid Preset document")
		return
	var layers: Array = document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", [])
	var jets := _layers_with_prefix(layers, "loop.core_jet_")
	var tails := _layers_with_prefix(layers, "loop.tail_jet_")
	var expected_offsets := [Vector2(-66.0, 317.0), Vector2(-22.0, 322.0), Vector2(22.0, 313.0), Vector2(66.0, 326.0)]
	var expected_rates := [12.0, 13.0, 11.0, 12.5]
	var expected_lifetimes := [0.090, 0.082, 0.098, 0.086]
	var expected_sizes := [112.0, 118.0, 108.0, 122.0]
	var expected_width_scales := [0.60, 0.56, 0.64, 0.58]
	var jets_match := jets.size() == 4
	for index in jets.size():
		var layer: Dictionary = jets[index]
		var parameters: Dictionary = layer.get("parameters", {})
		var offset_values: Array = layer.get("transform", {}).get("offset", [])
		var root_y := float(offset_values[1]) - (62.0 / 64.0) * float(parameters.get("size_start", 0.0)) if offset_values.size() == 2 else -999.0
		jets_match = jets_match \
			and layer.get("id") == "loop.core_jet_%d" % (index + 1) \
			and layer.get("anchors") == ["CENTER"] \
			and layer.get("blend_mode") == "ADDITIVE" \
			and layer.get("render_plane") == "OVER_VEHICLE" \
			and layer.get("parameters", {}).get("sprite_asset_ref") == "fx.booster_flame_core" \
			and parameters.get("emission_mode") == "CONTINUOUS" \
			and parameters.get("emitter") == {"shape": "POINT"} \
			and is_equal_approx(float(parameters.get("direction_degrees", -1.0)), 180.0) \
			and float(parameters.get("spread_degrees", -1.0)) <= 5.0 \
			and int(parameters.get("max_particles", 0)) == 1 \
			and is_equal_approx(float(parameters.get("emission_rate_per_second", 0.0)), expected_rates[index]) \
			and is_equal_approx(float(parameters.get("lifetime_seconds", 0.0)), expected_lifetimes[index]) \
			and is_equal_approx(float(parameters.get("size_start", 0.0)), expected_sizes[index]) \
			and is_zero_approx(float(parameters.get("speed_min", -1.0))) \
			and is_zero_approx(float(parameters.get("speed_max", -1.0))) \
			and Vector2(float(offset_values[0]), float(offset_values[1])) == expected_offsets[index] \
			and is_equal_approx(float(layer.get("transform", {}).get("scale", [0.0, 0.0])[0]), expected_width_scales[index]) \
			and root_y >= 207.0 and root_y <= 209.0
	var expected_tail_offsets := [Vector2(-66.0, 370.0), Vector2(-22.0, 394.0), Vector2(22.0, 351.0), Vector2(66.0, 384.0)]
	var expected_tail_rates := [4.2, 5.0, 3.7, 4.6]
	var expected_tail_lifetimes := [0.16, 0.13, 0.19, 0.15]
	var expected_tail_sizes := [170.0, 195.0, 150.0, 185.0]
	var expected_tail_width_scales := [0.44, 0.40, 0.48, 0.42]
	var tail_parameters_are_distinct: bool = tails.size() == 4
	for index in tails.size():
		var layer: Dictionary = tails[index]
		var parameters: Dictionary = layer.get("parameters", {})
		var offset_values: Array = layer.get("transform", {}).get("offset", [])
		var root_y := float(offset_values[1]) - (61.0 / 64.0) * float(parameters.get("size_start", 0.0)) if offset_values.size() == 2 else -999.0
		tail_parameters_are_distinct = tail_parameters_are_distinct \
			and layer.get("id") == "loop.tail_jet_%d" % (index + 1) \
			and layer.get("parameters", {}).get("sprite_asset_ref") == "fx.booster_flame_tail" \
			and parameters.get("emission_mode") == "CONTINUOUS" \
			and parameters.get("emitter") == {"shape": "POINT"} \
			and int(parameters.get("max_particles", 0)) == 1 \
			and is_equal_approx(float(parameters.get("direction_degrees", -1.0)), 180.0) \
			and is_equal_approx(float(parameters.get("emission_rate_per_second", 0.0)), expected_tail_rates[index]) \
			and is_equal_approx(float(parameters.get("lifetime_seconds", 0.0)), expected_tail_lifetimes[index]) \
			and is_equal_approx(float(parameters.get("size_start", 0.0)), expected_tail_sizes[index]) \
			and is_zero_approx(float(parameters.get("speed_min", -1.0))) \
			and is_zero_approx(float(parameters.get("speed_max", -1.0))) \
			and Vector2(float(offset_values[0]), float(offset_values[1])) == expected_tail_offsets[index] \
			and is_equal_approx(float(layer.get("transform", {}).get("scale", [0.0, 0.0])[0]), expected_tail_width_scales[index]) \
			and root_y >= 207.0 and root_y <= 209.0
	var visible_lengths_match := _visible_lengths_match(expected_sizes, expected_width_scales, expected_tail_sizes, expected_tail_width_scales)
	tests.expect_true(
		jets_match
		and tail_parameters_are_distinct
		and jets[0].get("importance") == "CORE"
		and jets[3].get("importance") == "CORE"
		and jets[1].get("importance") == "DETAIL"
		and jets[2].get("importance") == "DETAIL"
		and tails[0].get("importance") == "DETAIL"
		and tails[3].get("importance") == "DETAIL"
		and tails[1].get("importance") == "EXTRA"
		and tails[2].get("importance") == "EXTRA"
		and visible_lengths_match,
		"Standard Booster keeps four static-root core jets plus four independently gapped tail jets, with 18-22px cores and 26-36px tails at GAME 100%"
	)


static func _layers_with_prefix(layers: Array, prefix: String) -> Array:
	var result: Array = []
	for layer in layers:
		if layer is Dictionary and str(layer.get("id", "")).begins_with(prefix):
			result.append(layer)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id")) < str(right.get("id")))
	return result


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


static func _visible_lengths_match(core_sizes: Array, core_width_scales: Array, tail_sizes: Array, tail_width_scales: Array) -> bool:
	var game_scale := 0.095
	for index in core_sizes.size():
		var core_length := (121.0 / 128.0) * 2.0 * float(core_sizes[index]) * game_scale
		var core_width := (39.0 / 64.0) * float(core_sizes[index]) * float(core_width_scales[index]) * game_scale
		if core_length < 18.0 or core_length > 22.0 or core_width > 4.2:
			return false
	for index in tail_sizes.size():
		var tail_length := (123.0 / 128.0) * 2.0 * float(tail_sizes[index]) * game_scale
		var tail_width := (31.0 / 64.0) * float(tail_sizes[index]) * float(tail_width_scales[index]) * game_scale
		if tail_length < 26.0 or tail_length > 36.0 or tail_width > 4.0:
			return false
	return true
