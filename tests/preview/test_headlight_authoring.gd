extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const VfxPreviewRenderRuntimeModel := preload("res://src/preview/rendering/vfx_preview_render_runtime.gd")
const VfxPreviewRendererFactoryModel := preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd")
const VfxPreviewRuntimeInputStateModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd")
const VfxPreviewLodFilterModel := preload("res://src/performance/vfx_preview_lod_filter.gd")
const VfxPerformancePolicyModel := preload("res://src/performance/vfx_performance_policy.gd")

const LEFT_ROOT := Vector2(-44.0, -176.0)
const RIGHT_ROOT := Vector2(44.0, -176.0)
const ROOT_ALPHA_THRESHOLD := 0.1
const SOFT_TEXTURE_CENTER := Vector2(64.0, 64.0)
const CORE_TEXTURE_CENTER := Vector2(64.0, 96.0)
const SOFT_ALPHA_BOUNDS := Rect2i(7, 0, 117, 121)
const CORE_ALPHA_BOUNDS := Rect2i(15, 25, 98, 164)
const SOFT_VISIBLE_ROOT := Vector2(63.5, 113.0)
const CORE_VISIBLE_ROOT := Vector2(63.5, 185.0)
const LOOP_IDS := ["loop.left_soft_beam", "loop.right_soft_beam", "loop.left_core_beam", "loop.right_core_beam"]
const START_IDS := ["start.left_soft_beam", "start.right_soft_beam", "start.left_core_beam", "start.right_core_beam"]
const END_IDS := ["end.left_soft_beam", "end.right_soft_beam", "end.left_core_beam", "end.right_core_beam"]


static func run(tests: TestAssert) -> void:
	_test_headlight_assets_and_static_phase_contract(tests)
	_test_headlight_visible_roots_and_game_footprints(tests)
	_test_headlight_runtime_modulation_authoring(tests)
	_test_headlight_runtime_modulation_preview_behavior(tests)


static func _test_headlight_assets_and_static_phase_contract(tests: TestAssert) -> void:
	var assets := _resolved_assets()
	var core_image: Image = assets.get("core", {}).get("texture").get_image() if assets.get("core", {}).get("texture") is Texture2D else null
	var soft_image: Image = assets.get("soft", {}).get("texture").get_image() if assets.get("soft", {}).get("texture") is Texture2D else null
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.headlights.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Headlight static authoring requires a valid driving.headlights Preset")
		return
	var data: Dictionary = document_result.value.normalized_data
	var phases: Dictionary = data.get("phases", {})
	var start_layers: Array = phases.get("start", {}).get("layers", [])
	var loop_layers: Array = phases.get("loop", {}).get("layers", [])
	var end_layers: Array = phases.get("end", {}).get("layers", [])
	var loop := _layers_by_id(loop_layers)
	var phase_shapes_match := _layer_ids(start_layers) == START_IDS and _layer_ids(loop_layers) == LOOP_IDS and _layer_ids(end_layers) == END_IDS
	var loop_contract_matches := _matches_beam(loop.get("loop.left_soft_beam", {}), "fx.headlight_beam_soft", "DETAIL", "ALPHA", 355.0, Vector2(2.8, 3.65), Vector2(-58.193132, -354.291440), 0.11) \
		and _matches_beam(loop.get("loop.right_soft_beam", {}), "fx.headlight_beam_soft", "DETAIL", "ALPHA", 5.0, Vector2(2.8, 3.65), Vector2(60.982477, -354.047404), 0.11) \
		and _matches_beam(loop.get("loop.left_core_beam", {}), "fx.headlight_beam_core", "CORE", "ADDITIVE", 355.0, Vector2(1.55, 1.6), Vector2(-55.638927, -317.925671), 0.36) \
		and _matches_beam(loop.get("loop.right_core_beam", {}), "fx.headlight_beam_core", "CORE", "ADDITIVE", 5.0, Vector2(1.55, 1.6), Vector2(57.183029, -317.790579), 0.36)
	var lifecycle_matches := _phase_uses_loop_geometry(start_layers, loop, {"soft": 0.078571, "core": 0.276}) and _phase_uses_loop_geometry(end_layers, loop, {"soft": 0.066786, "core": 0.252})
	tests.expect_true(
		assets.get("core", {}).get("source") == "TEXTURE" and assets.get("soft", {}).get("source") == "TEXTURE" \
		and core_image != null and soft_image != null \
		and core_image.get_size() == Vector2i(128, 192) and soft_image.get_size() == Vector2i(128, 128) \
		and _alpha_bounds(core_image) == CORE_ALPHA_BOUNDS and _alpha_bounds(soft_image) == SOFT_ALPHA_BOUNDS \
		and _visible_root(core_image) == CORE_VISIBLE_ROOT and _visible_root(soft_image) == SOFT_VISIBLE_ROOT \
		and data.get("preset_id") == "driving.headlights" and data.get("category") == "UTILITY" \
		and data.get("lifecycle", {}).get("mode") == "START_LOOP_END" and data.get("default_space_mode") == "VEHICLE_LOCAL" and data.get("runtime_inputs") == ["speed_normalized", "longitudinal_load"] \
		and phase_shapes_match and loop_contract_matches and lifecycle_matches,
		"Headlight baseline preserves the registered 128x192 core and 128x128 soft RGBA assets in exactly four persistent beams per phase with stable LOOP IDs and no particle authoring"
	)


static func _test_headlight_visible_roots_and_game_footprints(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.headlights.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Headlight root and footprint checks require a valid driving.headlights Preset")
		return
	var loop := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []))
	var left_soft: Dictionary = loop.get("loop.left_soft_beam", {})
	var right_soft: Dictionary = loop.get("loop.right_soft_beam", {})
	var left_core: Dictionary = loop.get("loop.left_core_beam", {})
	var right_core: Dictionary = loop.get("loop.right_core_beam", {})
	var left_soft_root := _visible_root_source(left_soft, SOFT_VISIBLE_ROOT, SOFT_TEXTURE_CENTER)
	var right_soft_root := _visible_root_source(right_soft, SOFT_VISIBLE_ROOT, SOFT_TEXTURE_CENTER)
	var left_core_root := _visible_root_source(left_core, CORE_VISIBLE_ROOT, CORE_TEXTURE_CENTER)
	var right_core_root := _visible_root_source(right_core, CORE_VISIBLE_ROOT, CORE_TEXTURE_CENTER)
	var soft_100 := _game_footprint(SOFT_ALPHA_BOUNDS, left_soft, 1.0)
	var soft_085 := _game_footprint(SOFT_ALPHA_BOUNDS, left_soft, 0.85)
	var core_100 := _game_footprint(CORE_ALPHA_BOUNDS, left_core, 1.0)
	var core_085 := _game_footprint(CORE_ALPHA_BOUNDS, left_core, 0.85)
	var profiles_match := true
	for profile_name in ["formula", "sports", "gt", "hyper"]:
		var profile_result: VfxResult = VfxPresetCodecModel.new().decode_file("res://profiles/vehicles/%s.vehicle_profile.json" % profile_name)
		var anchors: Dictionary = profile_result.value.get("anchors", {}) if profile_result.success else {}
		var front: Vector2 = _anchor(anchors, "FRONT")
		var left_side: Vector2 = _anchor(anchors, "LEFT_SIDE")
		var right_side: Vector2 = _anchor(anchors, "RIGHT_SIDE")
		profiles_match = profiles_match and profile_result.success \
			and LEFT_ROOT.y > front.y and LEFT_ROOT.y < -170.0 \
			and RIGHT_ROOT.y > front.y and RIGHT_ROOT.y < -170.0 \
			and LEFT_ROOT.x > left_side.x and RIGHT_ROOT.x < right_side.x
	tests.expect_true(
		left_soft_root.distance_to(LEFT_ROOT) <= 0.001 and left_core_root.distance_to(LEFT_ROOT) <= 0.001 \
		and right_soft_root.distance_to(RIGHT_ROOT) <= 0.001 and right_core_root.distance_to(RIGHT_ROOT) <= 0.001 \
		and is_equal_approx(LEFT_ROOT.x, -RIGHT_ROOT.x) and is_equal_approx(LEFT_ROOT.y, RIGHT_ROOT.y) \
		and is_equal_approx(float(left_soft.get("transform", {}).get("rotation_degrees", 0.0)) + float(right_soft.get("transform", {}).get("rotation_degrees", 0.0)), 360.0) \
		and soft_100.y >= 44.0 and soft_100.y <= 45.0 and soft_100.x >= 34.2 and soft_100.x <= 35.2 \
		and soft_085.y >= 37.3 and soft_085.y <= 38.3 and soft_085.x >= 29.0 and soft_085.x <= 30.0 \
		and core_100.y >= 25.5 and core_100.y <= 26.6 and core_100.x >= 16.0 and core_100.x <= 17.1 \
		and core_085.y >= 21.7 and core_085.y <= 22.7 and core_085.x >= 13.5 and core_085.x <= 14.6 \
		and profiles_match,
		"Headlight soft and core visible roots align to one bilateral front-lamp pair while the rebaselined 128px assets retain bounded GAME footprints"
	)


static func _test_headlight_runtime_modulation_authoring(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.headlights.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Headlight Runtime Modulation authoring requires a valid production Preset")
		return
	var data: Dictionary = document_result.value.normalized_data
	var source_matches: bool = data.get("runtime_modulation_sources") == [{
		"id": "road.motion",
		"type": "OSCILLATOR",
		"wave": "SINE",
		"frequency_hz": 1.0,
		"phase_degrees": 0.0
	}]
	var all_layers_match := true
	for phase_name in ["start", "loop", "end"]:
		for layer in data.get("phases", {}).get(phase_name, {}).get("layers", []):
			if not layer is Dictionary:
				all_layers_match = false
				continue
			var layer_id := str(layer.get("id", ""))
			var is_soft := layer_id.contains("soft")
			var transform: Dictionary = layer.get("transform", {})
			var expected_pivot := Vector2(-0.5, 49.0) if is_soft else Vector2(-0.5, 89.0)
			all_layers_match = all_layers_match and _vector_matches(transform.get("modulation_pivot_local", []), expected_pivot) \
				and _modulation_set_matches(layer.get("modulations", []), is_soft) \
				and _scale_y_clamp_matches(layer.get("modulation_clamps", []), is_soft)
	tests.expect_true(
		source_matches and all_layers_match,
		"All twelve Headlight beam Layers declare one shared 1Hz road source, attachment pivots, scale/rotation mappings, Soft-only speed opacity, and non-contacting Scale Y safety clamps"
	)


static func _test_headlight_runtime_modulation_preview_behavior(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/driving.headlights.vfx.json")
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	var policy_result: VfxResult = VfxPerformancePolicyModel.new().load(_registry())
	if not plan_result.success or not policy_result.success:
		tests.expect_true(false, "Headlight Runtime Modulation Preview checks require a compiled Plan and Performance Policy")
		return
	var root_error_max := 0.0
	var dynamic_matches := true
	for speed in [0.0, 1.0]:
		for load_value in [-1.0, 0.0, 1.0]:
			for preview_time in [0.0, 0.25, 0.75]:
				var sampled_road := sin(TAU * preview_time)
				var runtime := _runtime_for(plan_result.value, speed, load_value, preview_time)
				if runtime == null:
					dynamic_matches = false
					continue
				var expected_factor: float = (1.0 + 0.05 * speed) * lerpf(0.94, 1.06, (load_value + 1.0) * 0.5) * lerpf(0.99, 1.01, (sampled_road + 1.0) * 0.5)
				for packet_value in runtime.draw_packets():
					if not packet_value is Dictionary:
						dynamic_matches = false
						continue
					var packet: Dictionary = packet_value
					var layer_id := str(packet.get("layer_id", ""))
					var is_soft := layer_id.contains("soft")
					var pivot := Vector2(-0.5, 49.0) if is_soft else Vector2(-0.5, 89.0)
					var scale: Vector2 = packet.get("geometry_scale", Vector2.ZERO)
					var rotation := float(packet.get("geometry_rotation_degrees", 0.0))
					var position: Vector2 = packet.get("position", Vector2.ZERO)
					var actual_root := position + Vector2(pivot.x * scale.x, pivot.y * scale.y).rotated(deg_to_rad(rotation))
					var expected_root := LEFT_ROOT if layer_id.contains("left") else RIGHT_ROOT
					root_error_max = maxf(root_error_max, actual_root.distance_to(expected_root))
					var base_scale_y := 3.65 if is_soft else 1.6
					var expected_alpha: float = (0.11 * (1.0 + 0.05 * speed)) if is_soft else 0.36
					dynamic_matches = dynamic_matches and is_equal_approx(scale.y, base_scale_y * expected_factor) \
						and is_equal_approx(float(packet.get("alpha", 0.0)), expected_alpha)
	var lod_matches := true
	for lod_level in ["HIGH", "MEDIUM", "LOW"]:
		var filtered: VfxResult = VfxPreviewLodFilterModel.new().filter(plan_result.value, lod_level, policy_result.value)
		var runtime := _runtime_for(filtered.value, 1.0, 0.0, 0.25) if filtered.success else null
		var expected_bindings := 8 if lod_level == "LOW" else 18
		var expected_renderers := 2 if lod_level == "LOW" else 4
		lod_matches = lod_matches and runtime != null \
			and runtime.active_renderer_count() == expected_renderers \
			and runtime.active_runtime_modulation_binding_count() == expected_bindings \
			and runtime.modulation_sample_count_last_tick() == 1
	tests.expect_true(
		dynamic_matches and root_error_max <= 0.001 and lod_matches,
		"Headlight speed/load/road mappings preserve all four bilateral lamp roots within 0.001 source px, sample one shared oscillator, and prune Soft bindings at LOW LOD"
	)


static func _modulation_set_matches(bindings_value: Variant, is_soft: bool) -> bool:
	if not bindings_value is Array:
		return false
	var expected: Array[Dictionary] = [
		_expected_mapping("TRANSFORM_SCALE_Y", "RUNTIME_INPUT", "speed_normalized", 0.0, 1.0, 1.0, 1.05),
		_expected_mapping("TRANSFORM_SCALE_Y", "RUNTIME_INPUT", "longitudinal_load", -1.0, 1.0, 0.94, 1.06),
		_expected_mapping("TRANSFORM_SCALE_Y", "PRESET_SOURCE", "road.motion", -1.0, 1.0, 0.99, 1.01),
		_expected_mapping("TRANSFORM_ROTATION_DEGREES", "PRESET_SOURCE", "road.motion", -1.0, 1.0, -0.2, 0.2)
	]
	if is_soft:
		expected.append(_expected_mapping("VISUAL_OPACITY_MULTIPLIER", "RUNTIME_INPUT", "speed_normalized", 0.0, 1.0, 1.0, 1.05))
	if bindings_value.size() != expected.size():
		return false
	for expected_binding in expected:
		var found := false
		for binding_value in bindings_value:
			if binding_value is Dictionary and _mapping_matches(binding_value, expected_binding):
				found = true
				break
		if not found:
			return false
	return true


static func _expected_mapping(target: String, source_type: String, source_value: String, input_min: float, input_max: float, output_min: float, output_max: float) -> Dictionary:
	return {
		"target": target,
		"source_type": source_type,
		"source_value": source_value,
		"input_min": input_min,
		"input_max": input_max,
		"output_min": output_min,
		"output_max": output_max
	}


static func _mapping_matches(binding: Dictionary, expected: Dictionary) -> bool:
	var source: Dictionary = binding.get("source", {}) if binding.get("source", {}) is Dictionary else {}
	var mapping: Dictionary = binding.get("mapping", {}) if binding.get("mapping", {}) is Dictionary else {}
	var source_type := str(expected.get("source_type", ""))
	var expected_source_value := str(expected.get("source_value", ""))
	var actual_source_value := str(source.get("input", "")) if source_type == "RUNTIME_INPUT" else str(source.get("source_id", ""))
	return binding.get("target") == expected.get("target") \
		and binding.get("operation") == ("ADD" if binding.get("target") == "TRANSFORM_ROTATION_DEGREES" else "MULTIPLY") \
		and source.get("type") == source_type and actual_source_value == expected_source_value \
		and mapping.get("type") == "LINEAR_RANGE" \
		and is_equal_approx(float(mapping.get("input_min", INF)), float(expected.get("input_min", -INF))) \
		and is_equal_approx(float(mapping.get("input_max", INF)), float(expected.get("input_max", -INF))) \
		and is_equal_approx(float(mapping.get("output_min", INF)), float(expected.get("output_min", -INF))) \
		and is_equal_approx(float(mapping.get("output_max", INF)), float(expected.get("output_max", -INF)))


static func _scale_y_clamp_matches(clamps_value: Variant, is_soft: bool) -> bool:
	if not clamps_value is Array or clamps_value.size() != 1 or not clamps_value[0] is Dictionary:
		return false
	var clamp: Dictionary = clamps_value[0]
	var expected_min := 3.39 if is_soft else 1.48
	var expected_max := 4.12 if is_soft else 1.81
	return clamp.get("target") == "TRANSFORM_SCALE_Y" \
		and is_equal_approx(float(clamp.get("min_effective", INF)), expected_min) \
		and is_equal_approx(float(clamp.get("max_effective", INF)), expected_max)


static func _runtime_for(plan: RefCounted, speed: float, load_value: float, preview_time: float) -> RefCounted:
	if plan == null or plan.runtime_modulation_program() == null:
		return null
	var runtime := VfxPreviewRenderRuntimeModel.new(plan, {"anchors": {"CENTER": [0.0, 0.0]}}, _registry(), VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()))
	var inputs := VfxPreviewRuntimeInputStateModel.new(plan.runtime_modulation_program())
	inputs.set_named_value(plan.runtime_modulation_program(), "speed_normalized", speed)
	inputs.set_named_value(plan.runtime_modulation_program(), "longitudinal_load", load_value)
	runtime.set_runtime_input_state(inputs)
	runtime.activate_phase("loop", {"preview_time": preview_time})
	runtime.advance(0.0, {"preview_time": preview_time})
	return runtime


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _resolved_assets() -> Dictionary:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var core: VfxResult = resolver.resolve("fx.headlight_beam_core")
	var soft: VfxResult = resolver.resolve("fx.headlight_beam_soft")
	return {"core": core.value if core.success else {}, "soft": soft.value if soft.success else {}}


static func _matches_beam(layer: Dictionary, asset_id: String, importance: String, blend_mode: String, rotation: float, scale: Vector2, offset: Vector2, opacity: float) -> bool:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	return layer.get("type") == "TEXTURED_SPRITE" \
		and layer.get("importance") == importance and layer.get("blend_mode") == blend_mode and layer.get("render_plane") == "UNDER_VEHICLE" \
		and layer.get("space_mode", "VEHICLE_LOCAL") == "VEHICLE_LOCAL" and layer.get("anchors", ["CENTER"]) == ["CENTER"] \
		and parameters == {"texture_asset_ref": asset_id, "opacity": opacity} \
		and is_equal_approx(float(transform.get("rotation_degrees", 0.0)), rotation) \
		and _vector_matches(transform.get("scale", []), scale) and _vector_matches(transform.get("offset", []), offset)


static func _phase_uses_loop_geometry(phase_layers: Array, loop: Dictionary, opacities: Dictionary) -> bool:
	for layer in phase_layers:
		if not layer is Dictionary:
			return false
		var phase_id := str(layer.get("id", ""))
		var loop_id := "loop." + phase_id.trim_prefix("start.").trim_prefix("end.")
		var loop_layer: Dictionary = loop.get(loop_id, {})
		var expected_opacity: float = float(opacities.get("soft" if phase_id.contains("soft") else "core", -1.0))
		var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
		if loop_layer.is_empty() or layer.get("type") != "TEXTURED_SPRITE" or layer.get("importance") != loop_layer.get("importance") \
			or layer.get("blend_mode") != loop_layer.get("blend_mode") or layer.get("render_plane") != "UNDER_VEHICLE" \
			or layer.get("anchors", ["CENTER"]) != ["CENTER"] or layer.get("transform") != loop_layer.get("transform") \
			or parameters.get("texture_asset_ref") != loop_layer.get("parameters", {}).get("texture_asset_ref") \
			or not is_equal_approx(float(parameters.get("opacity", -1.0)), expected_opacity):
			return false
	return true


static func _visible_root_source(layer: Dictionary, visible_root_px: Vector2, texture_center: Vector2) -> Vector2:
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	var offset := _vector(transform.get("offset", []))
	var scale := _vector(transform.get("scale", []))
	var local := Vector2((visible_root_px.x - texture_center.x) * scale.x, (visible_root_px.y - texture_center.y) * scale.y)
	return offset + local.rotated(deg_to_rad(float(transform.get("rotation_degrees", 0.0))))


static func _game_footprint(alpha_bounds: Rect2i, layer: Dictionary, track_scale: float) -> Vector2:
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	var scale := _vector(transform.get("scale", []))
	var radians := deg_to_rad(float(transform.get("rotation_degrees", 0.0)))
	var width := float(alpha_bounds.size.x) * scale.x
	var height := float(alpha_bounds.size.y) * scale.y
	var cosine := absf(cos(radians))
	var sine := absf(sin(radians))
	return Vector2(cosine * width + sine * height, sine * width + cosine * height) * 0.095 * track_scale


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


static func _visible_root(image: Image) -> Vector2:
	if image == null:
		return Vector2.INF
	var root_y := -1
	var x_sum := 0.0
	var x_count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < ROOT_ALPHA_THRESHOLD:
				continue
			if y > root_y:
				root_y = y
				x_sum = float(x)
				x_count = 1
			elif y == root_y:
				x_sum += float(x)
				x_count += 1
	return Vector2(x_sum / float(x_count), float(root_y)) if x_count > 0 else Vector2.INF


static func _layers_by_id(layers: Array) -> Dictionary:
	var result := {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result


static func _layer_ids(layers: Array) -> Array:
	return layers.map(func(layer: Dictionary) -> String: return str(layer.get("id", "")) if layer is Dictionary else "")


static func _anchor(anchors: Dictionary, name: String) -> Vector2:
	return _vector(anchors.get(name, []))


static func _vector(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() == 2 else Vector2.INF


static func _vector_matches(value: Variant, expected: Vector2) -> bool:
	var actual := _vector(value)
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)
