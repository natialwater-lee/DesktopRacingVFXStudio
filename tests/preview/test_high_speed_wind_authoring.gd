extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")


static func run(tests: TestAssert) -> void:
	_test_wind_texture_is_a_real_transparent_production_asset(tests)
	_test_high_speed_wind_uses_three_irregular_rearward_box_bands(tests)
	_test_miniature_wind_streak_footprints_stay_thin_and_readable(tests)
	_test_rearward_travel_is_visible_at_game_scale(tests)
	_test_longer_lived_wind_streaks_keep_density_below_declared_caps(tests)
	_test_rear_spawn_bands_cover_all_starter_profiles(tests)


static func _test_wind_texture_is_a_real_transparent_production_asset(tests: TestAssert) -> void:
	var result: VfxResult = VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()).resolve("fx.speed_wind_streak")
	var texture: Texture2D = result.value.get("texture") as Texture2D if result.success else null
	var image: Image = texture.get_image() if texture != null else null
	tests.expect_true(
		result.success
		and result.issues.is_empty()
		and result.value.get("source") == "TEXTURE"
		and not result.value.get("is_fallback", true)
		and image != null
		and image.get_size() == Vector2i(64, 128)
		and _has_transparent_pixel(image)
		and _has_visible_pixel(image),
		"High-Speed Wind resolves the supplied 64x128 transparent wind-streak PNG through the Production Preview catalog without fallback"
	)


static func _test_high_speed_wind_uses_three_irregular_rearward_box_bands(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.high_speed_wind.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "High-Speed Wind authoring requires a contract-valid Preset document")
		return
	var data: Dictionary = document_result.value.normalized_data
	var phases: Dictionary = data.get("phases", {})
	var start_layers: Array = phases.get("start", {}).get("layers", [])
	var loop_layers: Array = phases.get("loop", {}).get("layers", [])
	var end_layers: Array = phases.get("end", {}).get("layers", [])
	var loop_by_id := _layers_by_id(loop_layers)
	var all_layers: Array = []
	all_layers.append_array(start_layers)
	all_layers.append_array(loop_layers)
	all_layers.append_array(end_layers)
	var main: Dictionary = loop_by_id.get("loop.main_wind_streaks", {})
	var fine: Dictionary = loop_by_id.get("loop.fine_wind_streaks", {})
	var long: Dictionary = loop_by_id.get("loop.rare_long_streak", {})
	var main_band_at_track_one := _screen_spawn_band_width(main, 0.095, 1.0)
	var fine_band_at_track_one := _screen_spawn_band_width(fine, 0.095, 1.0)
	var long_band_at_track_one := _screen_spawn_band_width(long, 0.095, 1.0)
	var main_band_at_track_eighty_five := _screen_spawn_band_width(main, 0.095, 0.85)
	var fine_band_at_track_eighty_five := _screen_spawn_band_width(fine, 0.095, 0.85)
	var long_band_at_track_eighty_five := _screen_spawn_band_width(long, 0.095, 0.85)
	var all_use_under_vehicle_local := all_layers.all(func(layer: Dictionary) -> bool:
		return layer.get("type") == "PARTICLE" \
			and layer.get("space_mode", "VEHICLE_LOCAL") == "VEHICLE_LOCAL" \
			and layer.get("anchors", ["CENTER"]) == ["CENTER"] \
			and layer.get("render_plane") == "UNDER_VEHICLE" \
			and layer.get("blend_mode") == "ALPHA" \
			and layer.get("parameters", {}).get("sprite_asset_ref") == "fx.speed_wind_streak" \
			and layer.get("parameters", {}).get("emitter", {}).get("shape") == "BOX" \
			and is_zero_approx(float(layer.get("parameters", {}).get("alpha_end", -1.0)))
	)
	tests.expect_true(
		data.get("preset_id") == "driving.high_speed_wind"
		and data.get("category") == "BOOST"
		and data.get("lifecycle", {}).get("mode") == "START_LOOP_END"
		and data.get("default_space_mode") == "VEHICLE_LOCAL"
		and data.get("runtime_inputs") == []
		and start_layers.size() == 2
		and loop_layers.size() == 3
		and end_layers.size() == 2
		and all_use_under_vehicle_local
		and _continuous_wind_matches(main, "CORE", 5.4, 4, 0.42, 430.0, 530.0, 260.0, 197.0, 0.54, Vector2(0.85, 1.12), 6.0, [0.0, 230.0], {"shape": "BOX", "size": [336.0, 50.0]}, [0.48, 1.0])
		and _continuous_wind_matches(fine, "DETAIL", 6.4, 3, 0.34, 460.0, 580.0, 156.0, 119.0, 0.35, Vector2(0.88, 1.16), 8.0, [0.0, 218.0], {"shape": "BOX", "size": [315.0, 42.0]}, [0.47, 1.0])
		and _continuous_wind_matches(long, "EXTRA", 1.5, 1, 0.48, 380.0, 490.0, 328.0, 274.0, 0.29, Vector2(0.92, 1.18), 6.0, [0.0, 238.0], {"shape": "BOX", "size": [347.0, 52.0]}, [0.31, 1.0])
		and _burst_wind_matches(start_layers[0], "CORE", 0.35, 430.0, 530.0, 234.0, 170.0, 0.43, Vector2(0.85, 1.12), 6.0, [0.0, 230.0], {"shape": "BOX", "size": [336.0, 50.0]}, [0.48, 1.0])
		and _burst_wind_matches(start_layers[1], "DETAIL", 0.28, 460.0, 580.0, 151.0, 108.0, 0.30, Vector2(0.88, 1.16), 8.0, [0.0, 218.0], {"shape": "BOX", "size": [315.0, 42.0]}, [0.47, 1.0])
		and _burst_wind_matches(end_layers[0], "CORE", 0.34, 410.0, 510.0, 218.0, 160.0, 0.39, Vector2(0.85, 1.12), 6.0, [0.0, 235.0], {"shape": "BOX", "size": [326.0, 48.0]}, [0.48, 1.0])
		and _burst_wind_matches(end_layers[1], "DETAIL", 0.26, 430.0, 540.0, 141.0, 102.0, 0.27, Vector2(0.88, 1.16), 8.0, [0.0, 223.0], {"shape": "BOX", "size": [305.0, 40.0]}, [0.47, 1.0])
		and is_equal_approx(main_band_at_track_one, 31.92)
		and is_equal_approx(fine_band_at_track_one, 29.925)
		and is_equal_approx(long_band_at_track_one, 32.965)
		and is_equal_approx(main_band_at_track_eighty_five, 27.132)
		and is_equal_approx(fine_band_at_track_eighty_five, 25.43625)
		and is_equal_approx(long_band_at_track_eighty_five, 28.02025),
		"High-Speed Wind applies Pass I's +5% lateral BOX widths while retaining the Pass H silhouette, alpha, rear alignment, motion, and capacity"
	)


static func _test_miniature_wind_streak_footprints_stay_thin_and_readable(tests: TestAssert) -> void:
	var texture_result: VfxResult = VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()).resolve("fx.speed_wind_streak")
	var texture: Texture2D = texture_result.value.get("texture") as Texture2D if texture_result.success else null
	var image: Image = texture.get_image() if texture != null else null
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.high_speed_wind.vfx.json")
	if image == null or not document_result.success:
		tests.expect_true(false, "High-Speed Wind footprint calibration requires the supplied streak texture and valid Preset")
		return
	var game_scale := 0.095
	var reduced_track_scale := 0.08075
	var visible_bounds := _visible_alpha_bounds(image)
	var loop_by_id := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []))
	var main: Dictionary = _layer_footprint(visible_bounds, image.get_size(), loop_by_id.get("loop.main_wind_streaks", {}), game_scale)
	var fine: Dictionary = _layer_footprint(visible_bounds, image.get_size(), loop_by_id.get("loop.fine_wind_streaks", {}), game_scale)
	var long: Dictionary = _layer_footprint(visible_bounds, image.get_size(), loop_by_id.get("loop.rare_long_streak", {}), game_scale)
	var reduced_main: Dictionary = _layer_footprint(visible_bounds, image.get_size(), loop_by_id.get("loop.main_wind_streaks", {}), reduced_track_scale)
	var reduced_fine: Dictionary = _layer_footprint(visible_bounds, image.get_size(), loop_by_id.get("loop.fine_wind_streaks", {}), reduced_track_scale)
	var reduced_long: Dictionary = _layer_footprint(visible_bounds, image.get_size(), loop_by_id.get("loop.rare_long_streak", {}), reduced_track_scale)
	tests.expect_true(
		visible_bounds == Vector2i(26, 126)
		and main.length_min >= 41.0 and main.length_max <= 55.0 and main.width_min >= 4.0 and main.width_max <= 5.5
		and fine.length_min >= 25.0 and fine.length_max <= 34.0 and fine.width_min >= 2.4 and fine.width_max <= 3.35
		and long.length_min >= 56.0 and long.length_max <= 73.0 and long.width_min >= 3.5 and long.width_max <= 4.8
		and reduced_main.length_min >= 35.0 and reduced_main.length_max <= 47.0 and reduced_main.width_min >= 3.4 and reduced_main.width_max <= 4.7
		and reduced_fine.length_min >= 21.0 and reduced_fine.length_max <= 29.0 and reduced_fine.width_min >= 2.1 and reduced_fine.width_max <= 2.9
		and reduced_long.length_min >= 47.0 and reduced_long.length_max <= 62.0 and reduced_long.width_min >= 3.0 and reduced_long.width_max <= 4.0,
		"High-Speed Wind extends V2 silhouette length by about 28 percent while retaining Pass F GAME 100% aerodynamic width and alpha"
	)


static func _test_rearward_travel_is_visible_at_game_scale(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.high_speed_wind.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "High-Speed Wind travel calibration requires a valid Preset")
		return
	var layers := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []))
	var main := _travel_distance(layers.get("loop.main_wind_streaks", {}), 0.095)
	var fine := _travel_distance(layers.get("loop.fine_wind_streaks", {}), 0.095)
	var long := _travel_distance(layers.get("loop.rare_long_streak", {}), 0.095)
	var reduced_main := _travel_distance(layers.get("loop.main_wind_streaks", {}), 0.08075)
	var reduced_fine := _travel_distance(layers.get("loop.fine_wind_streaks", {}), 0.08075)
	var reduced_long := _travel_distance(layers.get("loop.rare_long_streak", {}), 0.08075)
	tests.expect_true(
		main.x >= 17.15 and main.x <= 17.20 and main.y >= 21.10 and main.y <= 21.20
		and fine.x >= 14.85 and fine.x <= 14.90 and fine.y >= 18.70 and fine.y <= 18.75
		and long.x >= 17.30 and long.x <= 17.35 and long.y >= 22.30 and long.y <= 22.40
		and reduced_main.x >= 14.55 and reduced_main.x <= 14.60 and reduced_main.y >= 17.95 and reduced_main.y <= 18.00
		and reduced_fine.x >= 12.60 and reduced_fine.x <= 12.65 and reduced_fine.y >= 15.90 and reduced_fine.y <= 15.95
		and reduced_long.x >= 14.70 and reduced_long.x <= 14.75 and reduced_long.y >= 18.95 and reduced_long.y <= 19.00,
		"High-Speed Wind preserves Pass G rearward travel while longer lifetime makes each streak slower to follow at GAME 100%"
	)


static func _test_longer_lived_wind_streaks_keep_density_below_declared_caps(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.high_speed_wind.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "High-Speed Wind temporal-density calibration requires a valid Preset")
		return
	var layers := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []))
	var main := _expected_average_alive(layers.get("loop.main_wind_streaks", {}))
	var fine := _expected_average_alive(layers.get("loop.fine_wind_streaks", {}))
	var long := _expected_average_alive(layers.get("loop.rare_long_streak", {}))
	tests.expect_true(
		is_equal_approx(main, 2.268)
		and is_equal_approx(fine, 2.176)
		and is_equal_approx(long, 0.72)
		and main < 4.0 and fine < 3.0 and long < 1.0,
		"High-Speed Wind lowers emission rates as it lengthens lifetimes, keeping expected alive Main/Fine/Long counts at 2.268/2.176/0.720 below the unchanged 4/3/1 caps"
	)


static func _test_rear_spawn_bands_cover_all_starter_profiles(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.high_speed_wind.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "High-Speed Wind rear-band coverage requires a valid Preset")
		return
	var layers := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []))
	var profile_paths := [
		"res://profiles/vehicles/formula.vehicle_profile.json",
		"res://profiles/vehicles/sports.vehicle_profile.json",
		"res://profiles/vehicles/gt.vehicle_profile.json",
		"res://profiles/vehicles/hyper.vehicle_profile.json"
	]
	var all_rear_centers_covered := true
	for path in profile_paths:
		var profile_result: VfxResult = VfxPresetCodecModel.new().decode_file(path)
		var rear: Variant = profile_result.value.get("anchors", {}).get("REAR_CENTER") if profile_result.success else null
		for layer in layers.values():
			all_rear_centers_covered = all_rear_centers_covered and _box_covers_rear_center(layer, rear)
	tests.expect_true(
		all_rear_centers_covered,
		"Each LOOP BOX band spans the REAR_CENTER anchors of Formula, Sports, GT, and Hyper without introducing category-specific offsets"
	)


static func _continuous_wind_matches(layer: Dictionary, importance: String, rate: float, capacity: int, lifetime: float, speed_min: float, speed_max: float, size_start: float, size_end: float, alpha_start: float, multiplier_range: Vector2, spread: float, offset: Array, emitter: Dictionary, scale: Array) -> bool:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	return layer.get("importance") == importance \
		and parameters.get("emission_mode") == "CONTINUOUS" \
		and parameters.get("emitter") == emitter \
		and parameters.get("sprite_asset_ref") == "fx.speed_wind_streak" \
		and is_equal_approx(float(parameters.get("emission_rate_per_second", 0.0)), rate) \
		and int(parameters.get("max_particles", 0)) == capacity \
		and is_equal_approx(float(parameters.get("lifetime_seconds", 0.0)), lifetime) \
		and is_equal_approx(float(parameters.get("direction_degrees", -1.0)), 180.0) \
		and is_equal_approx(float(parameters.get("spread_degrees", -1.0)), spread) \
		and is_equal_approx(float(parameters.get("speed_min", 0.0)), speed_min) \
		and is_equal_approx(float(parameters.get("speed_max", 0.0)), speed_max) \
		and is_equal_approx(float(parameters.get("size_start", 0.0)), size_start) \
		and is_equal_approx(float(parameters.get("size_end", 0.0)), size_end) \
		and is_equal_approx(float(parameters.get("size_multiplier_min", 0.0)), multiplier_range.x) \
		and is_equal_approx(float(parameters.get("size_multiplier_max", 0.0)), multiplier_range.y) \
		and is_equal_approx(float(parameters.get("alpha_start", 0.0)), alpha_start) \
		and is_zero_approx(float(parameters.get("alpha_end", -1.0))) \
		and is_equal_approx(float(parameters.get("rotation_min_degrees", -1.0)), 0.0) \
		and is_equal_approx(float(parameters.get("rotation_max_degrees", -1.0)), 0.0) \
		and layer.get("transform", {}).get("offset") == offset \
		and layer.get("transform", {}).get("rotation_degrees") == 0.0 \
		and layer.get("transform", {}).get("scale") == scale


static func _burst_wind_matches(layer: Dictionary, importance: String, lifetime: float, speed_min: float, speed_max: float, size_start: float, size_end: float, alpha_start: float, multiplier_range: Vector2, spread: float, offset: Array, emitter: Dictionary, scale: Array) -> bool:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	return layer.get("importance") == importance \
		and parameters.get("emission_mode") == "BURST" \
		and parameters.get("emitter") == emitter \
		and parameters.get("sprite_asset_ref") == "fx.speed_wind_streak" \
		and int(parameters.get("burst_count", 0)) == 1 \
		and is_equal_approx(float(parameters.get("lifetime_seconds", 0.0)), lifetime) \
		and is_equal_approx(float(parameters.get("direction_degrees", -1.0)), 180.0) \
		and is_equal_approx(float(parameters.get("spread_degrees", -1.0)), spread) \
		and is_equal_approx(float(parameters.get("speed_min", 0.0)), speed_min) \
		and is_equal_approx(float(parameters.get("speed_max", 0.0)), speed_max) \
		and is_equal_approx(float(parameters.get("size_start", 0.0)), size_start) \
		and is_equal_approx(float(parameters.get("size_end", 0.0)), size_end) \
		and is_equal_approx(float(parameters.get("size_multiplier_min", 0.0)), multiplier_range.x) \
		and is_equal_approx(float(parameters.get("size_multiplier_max", 0.0)), multiplier_range.y) \
		and is_equal_approx(float(parameters.get("alpha_start", 0.0)), alpha_start) \
		and is_zero_approx(float(parameters.get("alpha_end", -1.0))) \
		and is_equal_approx(float(parameters.get("rotation_min_degrees", -1.0)), 0.0) \
		and is_equal_approx(float(parameters.get("rotation_max_degrees", -1.0)), 0.0) \
		and layer.get("transform", {}).get("offset") == offset \
		and layer.get("transform", {}).get("rotation_degrees") == 0.0 \
		and layer.get("transform", {}).get("scale") == scale


static func _travel_distance(layer: Dictionary, game_scale: float) -> Vector2:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var lifetime := float(parameters.get("lifetime_seconds", 0.0))
	return Vector2(float(parameters.get("speed_min", 0.0)) * lifetime * game_scale, float(parameters.get("speed_max", 0.0)) * lifetime * game_scale)


static func _expected_average_alive(layer: Dictionary) -> float:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	return float(parameters.get("emission_rate_per_second", 0.0)) * float(parameters.get("lifetime_seconds", 0.0))


static func _screen_spawn_band_width(layer: Dictionary, game_scale: float, track_scale: float) -> float:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var emitter: Dictionary = parameters.get("emitter", {}) if parameters.get("emitter", {}) is Dictionary else {}
	var size: Array = emitter.get("size", []) if emitter.get("size", []) is Array else []
	return float(size[0]) * game_scale * track_scale if size.size() == 2 else 0.0


static func _box_covers_rear_center(layer: Variant, rear_center: Variant) -> bool:
	if not layer is Dictionary or not rear_center is Array or rear_center.size() != 2:
		return false
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var emitter: Dictionary = parameters.get("emitter", {}) if parameters.get("emitter", {}) is Dictionary else {}
	var offset: Variant = transform.get("offset", [])
	var size: Variant = emitter.get("size", [])
	if not offset is Array or offset.size() != 2 or not size is Array or size.size() != 2:
		return false
	var rear := Vector2(float(rear_center[0]), float(rear_center[1]))
	var center := Vector2(float(offset[0]), float(offset[1]))
	var half_size := Vector2(float(size[0]), float(size[1])) * 0.5
	return absf(rear.x - center.x) <= half_size.x and absf(rear.y - center.y) <= half_size.y


static func _footprint(visible_bounds: Vector2i, native_size: Vector2i, size_start: float, width_scale: float, multiplier_range: Vector2, game_scale: float) -> Dictionary:
	var longest_dimension := float(maxi(native_size.x, native_size.y))
	var base_length := (float(visible_bounds.y) / longest_dimension) * 2.0 * size_start * game_scale
	var base_width := (float(visible_bounds.x) / longest_dimension) * 2.0 * size_start * width_scale * game_scale
	return {
		"length_min": base_length * multiplier_range.x,
		"length_max": base_length * multiplier_range.y,
		"width_min": base_width * multiplier_range.x,
		"width_max": base_width * multiplier_range.y
	}


static func _layer_footprint(visible_bounds: Vector2i, native_size: Vector2i, layer: Dictionary, game_scale: float) -> Dictionary:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	var scale: Array = transform.get("scale", []) if transform.get("scale", []) is Array else []
	return _footprint(
		visible_bounds,
		native_size,
		float(parameters.get("size_start", 0.0)),
		float(scale[0]) if not scale.is_empty() else 0.0,
		Vector2(float(parameters.get("size_multiplier_min", 0.0)), float(parameters.get("size_multiplier_max", 0.0))),
		game_scale
	)


static func _visible_alpha_bounds(image: Image) -> Vector2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	return maximum - minimum + Vector2i.ONE if maximum.x >= minimum.x and maximum.y >= minimum.y else Vector2i.ZERO


static func _layers_by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result


static func _has_transparent_pixel(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 1.0:
				return true
	return false


static func _has_visible_pixel(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				return true
	return false
