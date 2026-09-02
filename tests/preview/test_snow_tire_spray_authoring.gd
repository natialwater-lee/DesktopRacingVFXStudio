extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxParticleDirectionModel := preload("res://src/preview/rendering/vfx_particle_direction.gd")

const GAME_SCALE := 0.095
const TEXTURE_SIZE := Vector2(125.0, 125.0)
const BOX_SIZE := Vector2(18.0, 26.0)
const FRONT_RIGHT := Vector2(40.0, -124.0)
const REAR_RIGHT := Vector2(41.0, 117.0)
const FRONT_LEFT := Vector2(-40.0, -124.0)
const REAR_LEFT := Vector2(-41.0, 117.0)
const VARIANCE := Vector2(0.95, 1.10)
const LOOP_IDS := ["loop.front_right_mist", "loop.rear_right_mist", "loop.front_left_mist", "loop.rear_left_mist"]
const START_IDS := ["start.front_right_mist_entry", "start.rear_right_mist_entry", "start.front_left_mist_entry", "start.rear_left_mist_entry"]
const END_IDS := ["end.front_right_mist_dissipate", "end.rear_right_mist_dissipate", "end.front_left_mist_dissipate", "end.rear_left_mist_dissipate"]


static func run(tests: TestAssert) -> void:
	_test_snow_assets_are_registered_rgba_mirrors(tests)
	_test_snow_swapped_mirror_assets_flip_vertical_alpha_orientation(tests)
	_test_snow_preset_uses_four_persistent_wheel_mists(tests)
	_test_snow_deep_tucked_roots_keep_symmetric_front_and_rear_families(tests)
	_test_snow_footprint_travel_and_overlap_stay_mist_focused(tests)


static func _test_snow_assets_are_registered_rgba_mirrors(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var right_result: VfxResult = resolver.resolve("fx.snow_tire_mist_right")
	var left_result: VfxResult = resolver.resolve("fx.snow_tire_mist_left")
	var right_image: Image = right_result.value.get("texture").get_image() if right_result.success and right_result.value.get("texture") is Texture2D else null
	var left_image: Image = left_result.value.get("texture").get_image() if left_result.success and left_result.value.get("texture") is Texture2D else null
	tests.expect_true(
		right_result.success and left_result.success \
		and right_result.value.get("source") == "TEXTURE" and left_result.value.get("source") == "TEXTURE" \
		and not right_result.value.get("is_fallback", true) and not left_result.value.get("is_fallback", true) \
		and right_image != null and left_image != null \
		and right_image.get_size() == Vector2i(125, 125) and left_image.get_size() == Vector2i(125, 125) \
		and _alpha_bounds(right_image) == Rect2i(2, 11, 120, 98) \
		and _alpha_bounds(left_image) == Rect2i(3, 11, 120, 98) \
		and _images_are_horizontal_mirrors(right_image, left_image),
		"Snow Tire Mist resolves two non-fallback 125px RGBA textures with exact horizontal RGB-and-alpha mirror parity"
	)


static func _test_snow_swapped_mirror_assets_flip_vertical_alpha_orientation(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var right_result: VfxResult = resolver.resolve("fx.snow_tire_mist_right")
	var left_result: VfxResult = resolver.resolve("fx.snow_tire_mist_left")
	var right_image: Image = right_result.value.get("texture").get_image() if right_result.success and right_result.value.get("texture") is Texture2D else null
	var left_image: Image = left_result.value.get("texture").get_image() if left_result.success and left_result.value.get("texture") is Texture2D else null
	var original_right := _alpha_centroid(right_image)
	var original_left := _alpha_centroid(left_image)
	var right_after_swap_and_rotation := _rotated_180_alpha_centroid(left_image)
	var left_after_swap_and_rotation := _rotated_180_alpha_centroid(right_image)
	var midpoint_y := 62.0
	tests.expect_true(
		right_result.success and left_result.success \
		and original_right.y > midpoint_y and original_left.y > midpoint_y \
		and right_after_swap_and_rotation.y < midpoint_y and left_after_swap_and_rotation.y < midpoint_y \
		and is_equal_approx(right_after_swap_and_rotation.y, 124.0 - original_left.y) \
		and is_equal_approx(left_after_swap_and_rotation.y, 124.0 - original_right.y),
		"Snow Tire Mist swap plus 180-degree rotation flips the mirrored texture alpha body vertically while preserving the bilateral pair"
	)


static func _test_snow_preset_uses_four_persistent_wheel_mists(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.snow_tire_spray.vfx.json")
	var data: Dictionary = document_result.value.normalized_data if document_result.success else {}
	var phases: Dictionary = data.get("phases", {})
	var start_layers: Array = phases.get("start", {}).get("layers", [])
	var loop_layers: Array = phases.get("loop", {}).get("layers", [])
	var end_layers: Array = phases.get("end", {}).get("layers", [])
	var start := _layers_by_id(start_layers)
	var loop := _layers_by_id(loop_layers)
	var end := _layers_by_id(end_layers)
	var all_layers: Array = []
	all_layers.append_array(start_layers)
	all_layers.append_array(loop_layers)
	all_layers.append_array(end_layers)
	var shared_contract := all_layers.all(func(layer: Dictionary) -> bool:
		var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
		return layer.get("type") == "PARTICLE" \
			and layer.get("importance") == "CORE" \
			and layer.get("space_mode", "VEHICLE_LOCAL") == "VEHICLE_LOCAL" \
			and layer.get("anchors", ["CENTER"]) == ["CENTER"] \
			and layer.get("blend_mode") == "ALPHA" \
			and layer.get("render_plane") == "UNDER_VEHICLE" \
			and parameters.get("emission_mode") == "CONTINUOUS" \
			and _box_matches(parameters.get("emitter", {}), BOX_SIZE)
	)
	var loop_matches := _mist_matches(loop.get("loop.front_right_mist", {}), "fx.snow_tire_mist_left", 1.75, 2, 1.2, 80.0, 140.0, 120.0, 120.0, 0.24, 0.11, 148.0, 190.0, FRONT_RIGHT) \
		and _mist_matches(loop.get("loop.rear_right_mist", {}), "fx.snow_tire_mist_left", 1.75, 2, 1.2, 80.0, 140.0, 120.0, 120.0, 0.24, 0.11, 148.0, 190.0, REAR_RIGHT) \
		and _mist_matches(loop.get("loop.front_left_mist", {}), "fx.snow_tire_mist_right", 1.75, 2, 1.2, 80.0, 140.0, 120.0, 120.0, 0.24, 0.11, 212.0, 170.0, FRONT_LEFT) \
		and _mist_matches(loop.get("loop.rear_left_mist", {}), "fx.snow_tire_mist_right", 1.75, 2, 1.2, 80.0, 140.0, 120.0, 120.0, 0.24, 0.11, 212.0, 170.0, REAR_LEFT)
	var lifecycle_matches := _mist_matches(start.get("start.front_right_mist_entry", {}), "fx.snow_tire_mist_left", 1.77, 1, 0.95, 80.0, 140.0, 115.0, 140.0, 0.19, 0.09, 148.0, 190.0, FRONT_RIGHT) \
		and _mist_matches(start.get("start.rear_right_mist_entry", {}), "fx.snow_tire_mist_left", 1.77, 1, 0.95, 80.0, 140.0, 115.0, 140.0, 0.19, 0.09, 148.0, 190.0, REAR_RIGHT) \
		and _mist_matches(start.get("start.front_left_mist_entry", {}), "fx.snow_tire_mist_right", 1.77, 1, 0.95, 80.0, 140.0, 115.0, 140.0, 0.19, 0.09, 212.0, 170.0, FRONT_LEFT) \
		and _mist_matches(start.get("start.rear_left_mist_entry", {}), "fx.snow_tire_mist_right", 1.77, 1, 0.95, 80.0, 140.0, 115.0, 140.0, 0.19, 0.09, 212.0, 170.0, REAR_LEFT) \
		and _mist_matches(end.get("end.front_right_mist_dissipate", {}), "fx.snow_tire_mist_left", 1.53, 1, 1.1, 80.0, 140.0, 120.0, 150.0, 0.17, 0.0, 148.0, 190.0, FRONT_RIGHT) \
		and _mist_matches(end.get("end.rear_right_mist_dissipate", {}), "fx.snow_tire_mist_left", 1.53, 1, 1.1, 80.0, 140.0, 120.0, 150.0, 0.17, 0.0, 148.0, 190.0, REAR_RIGHT) \
		and _mist_matches(end.get("end.front_left_mist_dissipate", {}), "fx.snow_tire_mist_right", 1.53, 1, 1.1, 80.0, 140.0, 120.0, 150.0, 0.17, 0.0, 212.0, 170.0, FRONT_LEFT) \
		and _mist_matches(end.get("end.rear_left_mist_dissipate", {}), "fx.snow_tire_mist_right", 1.53, 1, 1.1, 80.0, 140.0, 120.0, 150.0, 0.17, 0.0, 212.0, 170.0, REAR_LEFT)
	var right_direction := VfxParticleDirectionModel.from_degrees(148.0)
	var left_direction := VfxParticleDirectionModel.from_degrees(212.0)
	tests.expect_true(
		document_result.success \
		and data.get("preset_id") == "driving.snow_tire_spray" \
		and data.get("category") == "WEATHER" \
		and data.get("lifecycle", {}).get("mode") == "START_LOOP_END" \
		and _layer_ids(start_layers) == START_IDS and _layer_ids(loop_layers) == LOOP_IDS and _layer_ids(end_layers) == END_IDS \
		and _layer_ids_are_unique(all_layers) \
		and is_equal_approx(190.0 + 170.0, 360.0) \
		and shared_contract and loop_matches and lifecycle_matches \
		and right_direction.x > 0.0 and right_direction.y > 0.0 \
		and left_direction.x < 0.0 and left_direction.y > 0.0,
		"Snow Tire Mist uses four independently seeded small-BOX wheel plumes with swapped assets, 180-degree texture flips, and persistent side-plus-rearward powder drift"
	)


static func _test_snow_deep_tucked_roots_keep_symmetric_front_and_rear_families(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.snow_tire_spray.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Snow Tire Mist wheel coverage requires a valid Preset")
		return
	var loop := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []))
	var expected_positions := {"TIRE_FL": FRONT_LEFT, "TIRE_FR": FRONT_RIGHT, "TIRE_RL": REAR_LEFT, "TIRE_RR": REAR_RIGHT}
	var actual_positions := {
		"TIRE_FL": _layer_offset(loop.get("loop.front_left_mist", {})),
		"TIRE_FR": _layer_offset(loop.get("loop.front_right_mist", {})),
		"TIRE_RL": _layer_offset(loop.get("loop.rear_left_mist", {})),
		"TIRE_RR": _layer_offset(loop.get("loop.rear_right_mist", {}))
	}
	var structure_matches := true
	for anchor_name in expected_positions:
		structure_matches = structure_matches and actual_positions.get(anchor_name, Vector2.INF).is_equal_approx(expected_positions[anchor_name])
	tests.expect_true(
		structure_matches \
		and is_equal_approx(FRONT_RIGHT.x, -FRONT_LEFT.x) and is_equal_approx(REAR_RIGHT.x, -REAR_LEFT.x) \
		and is_equal_approx(FRONT_RIGHT.y, FRONT_LEFT.y) and is_equal_approx(REAR_RIGHT.y, REAR_LEFT.y) \
		and absf(FRONT_RIGHT.x) < 60.0 and absf(FRONT_LEFT.x) < 60.0 \
		and absf(REAR_RIGHT.x) < 61.0 and absf(REAR_LEFT.x) < 61.0,
		"Snow Tire Mist deeply tucks symmetric front and rear root families for intentional UNDER_VEHICLE concealment; profile anchor distance remains a diagnostic"
	)


static func _test_snow_footprint_travel_and_overlap_stay_mist_focused(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.snow_tire_spray.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Snow Tire Mist footprint checks require a valid Preset")
		return
	var phases: Dictionary = document_result.value.normalized_data.get("phases", {})
	var loop := _layers_by_id(phases.get("loop", {}).get("layers", []))
	var start := _layers_by_id(phases.get("start", {}).get("layers", []))
	var end := _layers_by_id(phases.get("end", {}).get("layers", []))
	var main: Dictionary = loop.get("loop.front_right_mist", {})
	var start_main: Dictionary = start.get("start.front_right_mist_entry", {})
	var end_main: Dictionary = end.get("end.front_right_mist_dissipate", {})
	var asset_result: VfxResult = VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()).resolve("fx.snow_tire_mist_left")
	var mist_image: Image = asset_result.value.get("texture").get_image() if asset_result.success and asset_result.value.get("texture") is Texture2D else null
	var outward_start := _visible_range(main, 120.0, 120.0, 1.0)
	var outward_end := _visible_range(main, 120.0, 120.0, 1.0)
	var thickness_start := _visible_range(main, 98.0, 120.0, 1.0)
	var travel := _game_travel_range_px(main)
	var travel_track_085 := travel * 0.85
	var start_travel := _game_travel_range_px(start_main)
	var end_travel := _game_travel_range_px(end_main)
	var direction := VfxParticleDirectionModel.from_degrees(float(main.get("parameters", {}).get("direction_degrees", 0.0)))
	var lateral_travel := travel * absf(direction.x)
	var rearward_travel := travel * direction.y
	var lateral_travel_track_085 := lateral_travel * 0.85
	var rearward_travel_track_085 := rearward_travel * 0.85
	var lateral_reduction := 1.0 - absf(direction.x) / 0.656059029
	var pass_l_outer_edge_source := _maximum_outer_visual_extent_source_px(main, mist_image, REAR_RIGHT, 150.0)
	var pass_m_outer_edge_source := _maximum_outer_visual_extent_source_px(main, mist_image, REAR_RIGHT, float(main.get("parameters", {}).get("size_end", 0.0)))
	var visible_edge_reduction_source := pass_l_outer_edge_source - pass_m_outer_edge_source
	var visible_edge_reduction_game := visible_edge_reduction_source * GAME_SCALE
	tests.expect_true(
		_range_matches(outward_start, Vector2(20.7936, 24.0768)) \
		and _range_matches(outward_end, Vector2(20.7936, 24.0768)) \
		and thickness_start.x >= 16.9 and thickness_start.y <= 19.7 \
		and _range_matches(travel, Vector2(9.12, 15.96)) \
		and _range_matches(travel_track_085, Vector2(7.752, 13.566)) \
		and _range_matches(start_travel, Vector2(7.22, 12.635)) \
		and _range_matches(end_travel, Vector2(8.36, 14.63)) \
		and _range_matches(lateral_travel, Vector2(4.832864, 8.457511)) \
		and _range_matches(rearward_travel, Vector2(7.734199, 13.534848)) \
		and _range_matches(lateral_travel_track_085, Vector2(4.107934, 7.188885)) \
		and _range_matches(rearward_travel_track_085, Vector2(6.574069, 11.504620)) \
		and is_equal_approx(absf(direction.x), 0.529919264) and is_equal_approx(direction.y, 0.848048096) \
		and lateral_reduction > 0.19 and lateral_reduction < 0.21 \
		and is_equal_approx(_ideal_alive(main), 2.1) \
		and is_equal_approx(_ideal_alive(start_main), 1.6815) and is_equal_approx(_ideal_alive(end_main), 1.683) \
		and is_equal_approx(_overlap_seconds(main), 0.6285714) \
		and int(main.get("parameters", {}).get("max_particles", 0)) == 2 \
		and is_equal_approx(pass_l_outer_edge_source, 340.58637662405) \
		and is_equal_approx(pass_m_outer_edge_source, 305.38424619734) \
		and is_equal_approx(visible_edge_reduction_source, 35.20213042671) \
		and is_equal_approx(visible_edge_reduction_game, 3.34420239054) \
		and is_equal_approx(pass_l_outer_edge_source * GAME_SCALE * 0.85, 27.50234991239) \
		and is_equal_approx(pass_m_outer_edge_source * GAME_SCALE * 0.85, 24.65977788044) \
		and visible_edge_reduction_source / pass_l_outer_edge_source > 0.10 \
		and visible_edge_reduction_source / pass_l_outer_edge_source < 0.11,
		"Snow Tire Mist clamps old-particle alpha support so its true worst-case visible outer edge moves inward while center travel and density remain unchanged"
	)


static func _mist_matches(layer: Dictionary, asset_id: String, rate: float, cap: int, lifetime: float, speed_min: float, speed_max: float, size_start: float, size_end: float, alpha_start: float, alpha_end: float, direction: float, rotation: float, offset: Vector2) -> bool:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	return parameters.get("sprite_asset_ref") == asset_id \
		and is_equal_approx(float(parameters.get("emission_rate_per_second", 0.0)), rate) \
		and int(parameters.get("max_particles", 0)) == cap \
		and is_equal_approx(float(parameters.get("lifetime_seconds", 0.0)), lifetime) \
		and is_equal_approx(float(parameters.get("speed_min", 0.0)), speed_min) \
		and is_equal_approx(float(parameters.get("speed_max", 0.0)), speed_max) \
		and is_equal_approx(float(parameters.get("size_start", 0.0)), size_start) \
		and is_equal_approx(float(parameters.get("size_end", 0.0)), size_end) \
		and is_equal_approx(float(parameters.get("alpha_start", 0.0)), alpha_start) \
		and is_equal_approx(float(parameters.get("alpha_end", -1.0)), alpha_end) \
		and is_equal_approx(float(parameters.get("size_multiplier_min", 0.0)), VARIANCE.x) \
		and is_equal_approx(float(parameters.get("size_multiplier_max", 0.0)), VARIANCE.y) \
		and is_equal_approx(float(parameters.get("direction_degrees", 0.0)), direction) \
		and is_equal_approx(float(parameters.get("spread_degrees", 0.0)), 22.0) \
		and is_equal_approx(float(parameters.get("rotation_min_degrees", 0.0)), rotation) \
		and is_equal_approx(float(parameters.get("rotation_max_degrees", 0.0)), rotation) \
		and _box_matches(parameters.get("emitter", {}), BOX_SIZE) \
		and _offset_matches(layer.get("transform", {}).get("offset", []), offset)


static func _layer_offset(layer: Dictionary) -> Vector2:
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	var offset_values: Array = transform.get("offset", []) if transform.get("offset", []) is Array else []
	return Vector2(float(offset_values[0]), float(offset_values[1])) if offset_values.size() == 2 else Vector2.INF


static func _layer_ids(layers: Array) -> Array:
	var result: Array = []
	for layer in layers:
		result.append(str(layer.get("id", "")) if layer is Dictionary else "")
	return result


static func _layer_ids_are_unique(layers: Array) -> bool:
	var seen := {}
	for layer_id in _layer_ids(layers):
		if seen.has(layer_id):
			return false
		seen[layer_id] = true
	return true


static func _anchor_point(anchors: Dictionary, anchor_name: String) -> Vector2:
	var values: Array = anchors.get(anchor_name, []) if anchors.get(anchor_name, []) is Array else []
	return Vector2(float(values[0]), float(values[1])) if values.size() == 2 else Vector2.INF


static func _visible_range(layer: Dictionary, alpha_extent_px: float, size: float, track_scale: float) -> Vector2:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var base := alpha_extent_px / TEXTURE_SIZE.x * 2.0 * size * GAME_SCALE * track_scale
	return Vector2(base * float(parameters.get("size_multiplier_min", 1.0)), base * float(parameters.get("size_multiplier_max", 1.0)))


static func _maximum_outer_visual_extent_source_px(layer: Dictionary, image: Image, root: Vector2, size: float) -> float:
	if image == null:
		return INF
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var alpha_bounds := _alpha_bounds(image)
	var pixel_scale := 2.0 * size * float(parameters.get("size_multiplier_max", 1.0)) / float(maxi(image.get_width(), image.get_height()))
	var rotation := deg_to_rad(float(parameters.get("rotation_max_degrees", 0.0)))
	var outer_alpha_x := -INF
	for corner in [alpha_bounds.position, Vector2i(alpha_bounds.end.x, alpha_bounds.position.y), Vector2i(alpha_bounds.position.x, alpha_bounds.end.y), alpha_bounds.end]:
		var centered := Vector2(float(corner.x) - float(image.get_width()) * 0.5, float(corner.y) - float(image.get_height()) * 0.5) * pixel_scale
		outer_alpha_x = maxf(outer_alpha_x, centered.rotated(rotation).x)
	var emitter: Dictionary = parameters.get("emitter", {}) if parameters.get("emitter", {}) is Dictionary else {}
	var emitter_size: Array = emitter.get("size", []) if emitter.get("size", []) is Array else []
	var emitter_outer_x := float(emitter_size[0]) * 0.5 if emitter.get("shape") == "BOX" and emitter_size.size() == 2 else 0.0
	var direction_outer_x := -INF
	var direction_center := float(parameters.get("direction_degrees", 0.0))
	var half_spread := float(parameters.get("spread_degrees", 0.0)) * 0.5
	for degrees in [direction_center - half_spread, direction_center + half_spread]:
		direction_outer_x = maxf(direction_outer_x, VfxParticleDirectionModel.from_degrees(degrees).x)
	var center_outer_x := root.x + emitter_outer_x + float(parameters.get("speed_max", 0.0)) * float(parameters.get("lifetime_seconds", 0.0)) * direction_outer_x
	return center_outer_x + outer_alpha_x


static func _game_travel_range_px(layer: Dictionary) -> Vector2:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var lifetime := float(parameters.get("lifetime_seconds", 0.0))
	return Vector2(float(parameters.get("speed_min", 0.0)) * lifetime * GAME_SCALE, float(parameters.get("speed_max", 0.0)) * lifetime * GAME_SCALE)


static func _ideal_alive(layer: Dictionary) -> float:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	return float(parameters.get("emission_rate_per_second", 0.0)) * float(parameters.get("lifetime_seconds", 0.0))


static func _overlap_seconds(layer: Dictionary) -> float:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var rate := float(parameters.get("emission_rate_per_second", 0.0))
	return float(parameters.get("lifetime_seconds", 0.0)) - 1.0 / rate if rate > 0.0 else 0.0


static func _box_matches(emitter: Variant, expected_size: Vector2) -> bool:
	if not emitter is Dictionary:
		return false
	var size_values: Array = emitter.get("size", []) if emitter.get("size", []) is Array else []
	return emitter.get("shape") == "BOX" \
		and size_values.size() == 2 \
		and is_equal_approx(float(size_values[0]), expected_size.x) \
		and is_equal_approx(float(size_values[1]), expected_size.y)


static func _offset_matches(raw_offset: Variant, expected: Vector2) -> bool:
	return raw_offset is Array and raw_offset.size() == 2 \
		and is_equal_approx(float(raw_offset[0]), expected.x) \
		and is_equal_approx(float(raw_offset[1]), expected.y)


static func _alpha_bounds(image: Image) -> Rect2i:
	if image == null:
		return Rect2i()
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE) if maximum.x >= minimum.x else Rect2i()


static func _alpha_centroid(image: Image) -> Vector2:
	if image == null:
		return Vector2.INF
	var total_alpha := 0.0
	var weighted_position := Vector2.ZERO
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			total_alpha += alpha
			weighted_position += Vector2(x, y) * alpha
	return weighted_position / total_alpha if total_alpha > 0.0 else Vector2.INF


static func _rotated_180_alpha_centroid(image: Image) -> Vector2:
	var centroid := _alpha_centroid(image)
	return Vector2(float(image.get_width() - 1), float(image.get_height() - 1)) - centroid if image != null and centroid.is_finite() else Vector2.INF


static func _images_are_horizontal_mirrors(right: Image, left: Image) -> bool:
	if right == null or left == null or right.get_size() != left.get_size():
		return false
	for y in right.get_height():
		for x in right.get_width():
			if right.get_pixel(x, y) != left.get_pixel(right.get_width() - 1 - x, y):
				return false
	return true


static func _layers_by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result


static func _range_matches(actual: Vector2, expected: Vector2) -> bool:
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)
