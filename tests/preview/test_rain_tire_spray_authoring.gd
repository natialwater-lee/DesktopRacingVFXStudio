extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxParticleDirectionModel := preload("res://src/preview/rendering/vfx_particle_direction.gd")

const GAME_SCALE := 0.095
const TEXTURE_SIZE := Vector2(128.0, 128.0)
const RIGHT_ROOT_REFERENCE_PX := Vector2(2.0, 70.0)
const LEFT_ROOT_REFERENCE_PX := Vector2(126.0, 70.0)
const TEXTURE_CENTER_PX := Vector2(64.0, 64.0)
const WAKE_ROOT_TO_TIP_PX := 124.0
const RIGHT_TARGET_ROOT := Vector2(106.0, 10.0)
const LEFT_TARGET_ROOT := Vector2(-106.0, 10.0)


static func run(tests: TestAssert) -> void:
	_test_wake_assets_are_registered_and_exact_mirrors(tests)
	_test_rain_preset_uses_continuous_two_sheet_wake_contract(tests)
	_test_wake_roots_attach_to_all_profile_side_regions(tests)
	_test_wake_footprints_drift_and_overlap_stay_wet_road_focused(tests)


static func _test_wake_assets_are_registered_and_exact_mirrors(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var right_result: VfxResult = resolver.resolve("fx.rain_tire_wake_right")
	var left_result: VfxResult = resolver.resolve("fx.rain_tire_wake_left")
	var right_image: Image = right_result.value.get("texture").get_image() if right_result.success and right_result.value.get("texture") is Texture2D else null
	var left_image: Image = left_result.value.get("texture").get_image() if left_result.success and left_result.value.get("texture") is Texture2D else null
	tests.expect_true(
		right_result.success and left_result.success \
		and right_result.value.get("source") == "TEXTURE" and left_result.value.get("source") == "TEXTURE" \
		and not right_result.value.get("is_fallback", true) and not left_result.value.get("is_fallback", true) \
		and right_image != null and left_image != null \
		and right_image.get_size() == Vector2i(128, 128) and left_image.get_size() == Vector2i(128, 128) \
		and _alpha_bounds(right_image) == Rect2i(1, 18, 126, 110) \
		and _alpha_bounds(left_image) == Rect2i(1, 18, 126, 110) \
		and _images_are_horizontal_mirrors(right_image, left_image),
		"Rain Tire Wake resolves two non-fallback 128px RGBA assets with exact horizontal RGB-and-alpha mirror parity"
	)


static func _test_rain_preset_uses_continuous_two_sheet_wake_contract(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.rain_tire_spray.vfx.json")
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
			and layer.get("space_mode", "VEHICLE_LOCAL") == "VEHICLE_LOCAL" \
			and layer.get("anchors", ["CENTER"]) == ["CENTER"] \
			and layer.get("blend_mode") == "ALPHA" \
			and layer.get("render_plane") == "UNDER_VEHICLE" \
			and parameters.get("emission_mode") == "CONTINUOUS" \
			and not str(parameters.get("sprite_asset_ref", "")).begins_with("fx.rain_tire_spray")
	)
	var loop_matches: bool = _continuous_matches(loop.get("loop.right_main_wake", {}), "CORE", "fx.rain_tire_wake_right", 1.4, 2, 1.50, 4.0, 9.0, 200.0, 220.0, 0.30, 0.12, Vector2(0.95, 1.12), 150.0, 5.0, 240.0, Vector2(-7.113, -148.417)) \
		and _continuous_matches(loop.get("loop.left_main_wake", {}), "CORE", "fx.rain_tire_wake_left", 1.4, 2, 1.50, 4.0, 9.0, 200.0, 220.0, 0.30, 0.12, Vector2(0.95, 1.12), 210.0, 5.0, 120.0, Vector2(7.113, -148.417))
	var lifecycle_matches: bool = _continuous_matches(start.get("start.right_wake_entry", {}), "CORE", "fx.rain_tire_wake_right", 2.0, 1, 1.20, 3.0, 7.0, 180.0, 200.0, 0.22, 0.10, Vector2(0.95, 1.08), 150.0, 5.0, 240.0, Vector2(4.198, -132.576)) \
		and _continuous_matches(start.get("start.left_wake_entry", {}), "CORE", "fx.rain_tire_wake_left", 2.0, 1, 1.20, 3.0, 7.0, 180.0, 200.0, 0.22, 0.10, Vector2(0.95, 1.08), 210.0, 5.0, 120.0, Vector2(-4.198, -132.576)) \
		and _continuous_matches(end.get("end.right_wake_drain", {}), "CORE", "fx.rain_tire_wake_right", 1.6, 1, 1.10, 2.0, 5.0, 190.0, 170.0, 0.18, 0.0, Vector2(0.95, 1.08), 150.0, 5.0, 240.0, Vector2(-1.457, -140.497)) \
		and _continuous_matches(end.get("end.left_wake_drain", {}), "CORE", "fx.rain_tire_wake_left", 1.6, 1, 1.10, 2.0, 5.0, 190.0, 170.0, 0.18, 0.0, Vector2(0.95, 1.08), 210.0, 5.0, 120.0, Vector2(1.457, -140.497))
	var flip_and_alignment_matches := _symmetric_forward_facing_alignment(loop.get("loop.right_main_wake", {}), loop.get("loop.left_main_wake", {}))
	var right_direction := VfxParticleDirectionModel.from_degrees(150.0)
	var left_direction := VfxParticleDirectionModel.from_degrees(210.0)
	tests.expect_true(
		document_result.success \
		and data.get("preset_id") == "driving.rain_tire_spray" \
		and data.get("category") == "WEATHER" \
		and data.get("lifecycle", {}).get("mode") == "START_LOOP_END" \
		and start_layers.size() == 2 and loop_layers.size() == 2 and end_layers.size() == 2 \
		and shared_contract and loop_matches and lifecycle_matches and flip_and_alignment_matches \
		and right_direction.x > 0.0 and right_direction.y > 0.0 \
		and left_direction.x < 0.0 and left_direction.y > 0.0,
		"Rain Tire Wake uses two continuous mirrored CORE sheets with front-facing narrow tips, a stable brightness floor, and bilateral outward opening"
	)


static func _test_wake_roots_attach_to_all_profile_side_regions(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.rain_tire_spray.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Rain Tire Wake root coverage requires a valid Preset")
		return
	var loop := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []))
	var right_root := _nominal_root_center(loop.get("loop.right_main_wake", {}))
	var left_root := _nominal_root_center(loop.get("loop.left_main_wake", {}))
	var profiles_match := true
	for profile_name in ["formula", "sports", "gt", "hyper"]:
		var profile_result: VfxResult = VfxPresetCodecModel.new().decode_file("res://profiles/vehicles/%s.vehicle_profile.json" % profile_name)
		var anchors: Dictionary = profile_result.value.get("anchors", {}) if profile_result.success else {}
		profiles_match = profiles_match \
			and absf(right_root.x - float(anchors.get("RIGHT_SIDE", [0.0, 0.0])[0])) <= 24.0 \
			and absf(left_root.x - float(anchors.get("LEFT_SIDE", [0.0, 0.0])[0])) <= 24.0 \
			and right_root.y >= 8.0 and right_root.y <= 12.0 \
			and left_root.y >= 8.0 and left_root.y <= 12.0
	var root_drift_safe := _root_variance_drift_px(loop.get("loop.right_main_wake", {})) <= 2.25 \
		and _root_variance_drift_px(loop.get("loop.left_main_wake", {})) <= 2.25
	tests.expect_true(
		profiles_match and root_drift_safe \
		and right_root.distance_to(RIGHT_TARGET_ROOT) <= 0.2 \
		and left_root.distance_to(LEFT_TARGET_ROOT) <= 0.2 \
		and is_equal_approx(right_root.x, -left_root.x) and is_equal_approx(right_root.y, left_root.y),
		"Rain Tire Wake keeps stable bilateral POINT roots in the outer, near-side front region of every vehicle profile"
	)


static func _test_wake_footprints_drift_and_overlap_stay_wet_road_focused(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.rain_tire_spray.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Rain Tire Wake footprint checks require a valid Preset")
		return
	var loop := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []))
	var main: Dictionary = loop.get("loop.right_main_wake", {})
	var base_tip := _visible_root_to_tip_px(main, 1.0)
	var reduced_tip := _visible_root_to_tip_px(main, 0.85)
	var variance_tip := _visible_root_to_tip_range_px(main, 1.0)
	var travel := _game_travel_range_px(main)
	tests.expect_true(
		base_tip >= 35.0 and base_tip <= 50.0 \
		and reduced_tip >= 29.0 and reduced_tip <= 43.0 \
		and _range_matches(variance_tip, Vector2(34.971875, 41.23)) \
		and _range_matches(travel, Vector2(0.57, 1.2825)) \
		and is_equal_approx(_ideal_alive(main), 2.1) \
		and _overlap_seconds(main) >= 0.7 \
		and int(main.get("parameters", {}).get("max_particles", 0)) == 2,
		"Rain Tire Wake uses a 35-50px-class persistent semi-transparent sheet with 0.5-1.5px drift and stable capped two-sheet overlap"
	)


static func _continuous_matches(layer: Dictionary, importance: String, asset_id: String, rate: float, cap: int, lifetime: float, speed_min: float, speed_max: float, size_start: float, size_end: float, alpha_start: float, alpha_end: float, variance: Vector2, direction: float, spread: float, rotation: float, offset: Vector2) -> bool:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	return layer.get("importance") == importance \
		and parameters.get("emission_mode") == "CONTINUOUS" \
		and parameters.get("emitter") == {"shape": "POINT"} \
		and parameters.get("sprite_asset_ref") == asset_id \
		and is_equal_approx(float(parameters.get("emission_rate_per_second", 0.0)), rate) \
		and int(parameters.get("max_particles", 0)) == cap \
		and is_equal_approx(float(parameters.get("lifetime_seconds", 0.0)), lifetime) \
		and is_equal_approx(float(parameters.get("speed_min", 0.0)), speed_min) \
		and is_equal_approx(float(parameters.get("speed_max", 0.0)), speed_max) \
		and is_equal_approx(float(parameters.get("size_start", 0.0)), size_start) \
		and is_equal_approx(float(parameters.get("size_end", 0.0)), size_end) \
		and is_equal_approx(float(parameters.get("alpha_start", 0.0)), alpha_start) \
		and is_equal_approx(float(parameters.get("alpha_end", -1.0)), alpha_end) \
		and is_equal_approx(float(parameters.get("size_multiplier_min", 0.0)), variance.x) \
		and is_equal_approx(float(parameters.get("size_multiplier_max", 0.0)), variance.y) \
		and is_equal_approx(float(parameters.get("direction_degrees", 0.0)), direction) \
		and is_equal_approx(float(parameters.get("spread_degrees", 0.0)), spread) \
		and is_equal_approx(float(parameters.get("rotation_min_degrees", 0.0)), rotation) \
		and is_equal_approx(float(parameters.get("rotation_max_degrees", 0.0)), rotation) \
		and _offset_matches(layer.get("transform", {}).get("offset", []), offset)


static func _nominal_root_center(layer: Dictionary) -> Vector2:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	var offset_values: Array = transform.get("offset", []) if transform.get("offset", []) is Array else []
	if offset_values.size() != 2:
		return Vector2.ZERO
	var sprite_scale := 2.0 * float(parameters.get("size_start", 0.0)) / TEXTURE_SIZE.x
	var root_vector := (_root_reference_px(parameters) - TEXTURE_CENTER_PX) * sprite_scale
	return Vector2(float(offset_values[0]), float(offset_values[1])) + root_vector.rotated(deg_to_rad(float(parameters.get("rotation_min_degrees", 0.0))))


static func _root_variance_drift_px(layer: Dictionary) -> float:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var sprite_scale := 2.0 * float(parameters.get("size_start", 0.0)) / TEXTURE_SIZE.x
	var root_distance := (_root_reference_px(parameters) - TEXTURE_CENTER_PX).length() * sprite_scale
	var variance := maxf(absf(float(parameters.get("size_multiplier_min", 1.0)) - 1.0), absf(float(parameters.get("size_multiplier_max", 1.0)) - 1.0))
	return root_distance * variance * GAME_SCALE


static func _visible_root_to_tip_px(layer: Dictionary, track_scale: float) -> float:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	return (WAKE_ROOT_TO_TIP_PX / TEXTURE_SIZE.x) * 2.0 * float(parameters.get("size_start", 0.0)) * GAME_SCALE * track_scale


static func _visible_root_to_tip_range_px(layer: Dictionary, track_scale: float) -> Vector2:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var base := _visible_root_to_tip_px(layer, track_scale)
	return Vector2(base * float(parameters.get("size_multiplier_min", 1.0)), base * float(parameters.get("size_multiplier_max", 1.0)))


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


static func _symmetric_forward_facing_alignment(right_layer: Dictionary, left_layer: Dictionary) -> bool:
	var right_parameters: Dictionary = right_layer.get("parameters", {}) if right_layer.get("parameters", {}) is Dictionary else {}
	var left_parameters: Dictionary = left_layer.get("parameters", {}) if left_layer.get("parameters", {}) is Dictionary else {}
	var right_rotation := float(right_parameters.get("rotation_min_degrees", 0.0))
	var left_rotation := float(left_parameters.get("rotation_min_degrees", 0.0))
	return is_equal_approx(right_rotation, 240.0) \
		and is_equal_approx(left_rotation, 120.0) \
		and is_equal_approx(right_rotation + left_rotation, 360.0) \
		and is_equal_approx(right_rotation - 60.0, 180.0) \
		and is_equal_approx(left_rotation - 300.0, -180.0)


static func _root_reference_px(parameters: Dictionary) -> Vector2:
	return LEFT_ROOT_REFERENCE_PX if parameters.get("sprite_asset_ref") == "fx.rain_tire_wake_left" else RIGHT_ROOT_REFERENCE_PX


static func _distance_to_anchor(point: Vector2, anchors: Dictionary, anchor_name: String) -> float:
	var values: Array = anchors.get(anchor_name, []) if anchors.get(anchor_name, []) is Array else []
	return point.distance_to(Vector2(float(values[0]), float(values[1]))) if values.size() == 2 else INF


static func _offset_matches(raw_offset: Variant, expected: Vector2) -> bool:
	if not raw_offset is Array or raw_offset.size() != 2:
		return false
	return is_equal_approx(float(raw_offset[0]), expected.x) and is_equal_approx(float(raw_offset[1]), expected.y)


static func _range_matches(actual: Vector2, expected: Vector2) -> bool:
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)


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
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE) if maximum.x >= minimum.x and maximum.y >= minimum.y else Rect2i()


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
