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

const REAR_CENTER := Vector2(0.0, 220.0)
const PRESET_LOCAL_REAR_OFFSET := Vector2(0.0, 15.0)
const NOZZLE_ROOT := Vector2(0.0, 235.0)
const CORE_PIVOT := Vector2(0.0, -181.0)
const SOFT_PIVOT := Vector2(-0.5, -183.0)
const CORE_ALPHA_BOUNDS := Rect2i(16, 3, 208, 373)
const SOFT_ALPHA_BOUNDS := Rect2i(0, 4, 253, 380)


static func run(tests: TestAssert) -> void:
	_test_assets_and_single_nozzle_contract(tests)
	_test_all_phase_attachment_roots_and_game_footprint(tests)
	_test_loop_motion_preserves_attachment_and_lod(tests)


static func _test_assets_and_single_nozzle_contract(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var core_result: VfxResult = resolver.resolve("fx.super_booster_flame_core")
	var soft_result: VfxResult = resolver.resolve("fx.super_booster_flame_soft")
	var core_image: Image = core_result.value.get("texture").get_image() if core_result.success and core_result.value.get("texture") is Texture2D else null
	var soft_image: Image = soft_result.value.get("texture").get_image() if soft_result.success and soft_result.value.get("texture") is Texture2D else null
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.super_booster.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Super Booster single-nozzle contract requires a valid saved Preset")
		return
	var data: Dictionary = document_result.value.normalized_data
	var phases: Dictionary = data.get("phases", {})
	var static_matches: bool = data.get("preset_id") == "equipment.super_booster" \
		and data.get("category") == "SPECIAL_EQUIPMENT" and data.get("default_space_mode") == "VEHICLE_LOCAL" \
		and data.get("lifecycle", {}).get("mode") == "START_LOOP_END" and data.get("runtime_inputs", []) == [] \
		and _phase_layer_ids(phases.get("start", {}).get("layers", []), ["start.core_ignition", "start.soft_ignition"]) \
		and _phase_layer_ids(phases.get("loop", {}).get("layers", []), ["loop.core_flame", "loop.soft_flame"]) \
		and _phase_layer_ids(phases.get("end", {}).get("layers", []), ["end.core_fade", "end.soft_fade"])
	tests.expect_true(
		core_result.success and soft_result.success and core_image != null and soft_image != null \
		and core_image.get_size() == Vector2i(256, 384) and soft_image.get_size() == Vector2i(256, 384) \
		and _alpha_bounds(core_image) == CORE_ALPHA_BOUNDS and _alpha_bounds(soft_image) == SOFT_ALPHA_BOUNDS \
		and static_matches,
		"Super Booster registers the two supplied transparent 256x384 flame textures and defines one SPECIAL_EQUIPMENT single-nozzle START_LOOP_END Preset"
	)


static func _test_all_phase_attachment_roots_and_game_footprint(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.super_booster.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Super Booster attachment checks require a valid saved Preset")
		return
	var phase_expectations := {
		"start": {"core": [Vector2(0.26, 0.86), Vector2(0.0, 170.66), 0.92], "soft": [Vector2(0.558461538, 1.05), Vector2(0.279230769, 207.15), 0.42]},
		"loop": {"core": [Vector2(0.30, 1.14), Vector2(0.0, 221.34), 0.86], "soft": [Vector2(0.66, 1.35), Vector2(0.33, 262.05), 0.55]},
		"end": {"core": [Vector2(0.22, 0.72), Vector2(0.0, 145.32), 0.42], "soft": [Vector2(0.482307692, 0.92), Vector2(0.241153846, 183.36), 0.18]}
	}
	var root_error_max := 0.0
	var matches := true
	for phase_name in phase_expectations:
		var layers := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get(phase_name, {}).get("layers", []))
		for family in ["core", "soft"]:
			var layer: Dictionary = layers.get("%s.%s_%s" % [phase_name, family, "flame" if phase_name == "loop" else "ignition" if phase_name == "start" else "fade"], {})
			var expected: Array = phase_expectations[phase_name][family]
			var pivot := CORE_PIVOT if family == "core" else SOFT_PIVOT
			matches = matches and _matches_static_layer(layer, family, expected[0], expected[1], float(expected[2]), pivot)
			root_error_max = maxf(root_error_max, _attachment_root(layer, pivot).distance_to(NOZZLE_ROOT))
	var loop_layers := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []))
	var core_footprint := _game_footprint(CORE_ALPHA_BOUNDS, loop_layers.get("loop.core_flame", {}), 1.0)
	var soft_footprint := _game_footprint(SOFT_ALPHA_BOUNDS, loop_layers.get("loop.soft_flame", {}), 1.0)
	var soft_footprint_track_085 := _game_footprint(SOFT_ALPHA_BOUNDS, loop_layers.get("loop.soft_flame", {}), 0.85)
	tests.expect_true(
		matches and root_error_max <= 0.001 \
		and core_footprint.y >= 40.0 and core_footprint.y <= 41.0 and soft_footprint.y >= 48.0 and soft_footprint.y <= 49.0 \
		and soft_footprint.x >= 15.8 and soft_footprint.x <= 16.0 \
		and soft_footprint_track_085.x >= 13.4 and soft_footprint_track_085.x <= 13.6 \
		and soft_footprint_track_085.y >= 41.3 and soft_footprint_track_085.y <= 41.5,
		"Every Super Booster phase rebaselines its Core and proportional-width Soft geometry to the provisional rear nozzle root while retaining its original plume length"
	)


static func _test_loop_motion_preserves_attachment_and_lod(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.super_booster.vfx.json")
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	var policy_result: VfxResult = VfxPerformancePolicyModel.new().load(_registry())
	if not plan_result.success or not policy_result.success:
		tests.expect_true(false, "Super Booster loop motion checks require a compiled Plan and Performance Policy")
		return
	var root_error_max := 0.0
	var normal_sweep_range_violations := 0
	var dynamics_match := true
	for preview_time in [1.0 / 28.0, 0.0, 3.0 / 28.0]:
		var runtime := _runtime_for(plan_result.value, preview_time)
		if runtime == null:
			dynamics_match = false
			continue
		for packet_value in runtime.draw_packets():
			if not packet_value is Dictionary:
				dynamics_match = false
				continue
			var packet: Dictionary = packet_value
			var is_core := str(packet.get("layer_id", "")).contains("core")
			var pivot := CORE_PIVOT if is_core else SOFT_PIVOT
			var scale: Vector2 = packet.get("geometry_scale", Vector2.ZERO)
			var root: Vector2 = packet.get("position", Vector2.ZERO) + Vector2(pivot.x * scale.x, pivot.y * scale.y).rotated(deg_to_rad(float(packet.get("geometry_rotation_degrees", 0.0))))
			root_error_max = maxf(root_error_max, root.distance_to(NOZZLE_ROOT))
			var min_scale := Vector2(0.293, 1.08) if is_core else Vector2(0.6402, 1.269)
			var max_scale := Vector2(0.307, 1.20) if is_core else Vector2(0.6798, 1.431)
			if scale.x < min_scale.x - 0.0001 or scale.x > max_scale.x + 0.0001 or scale.y < min_scale.y - 0.0001 or scale.y > max_scale.y + 0.0001:
				normal_sweep_range_violations += 1
			dynamics_match = dynamics_match and is_finite(scale.x) and is_finite(scale.y) and float(packet.get("alpha", -1.0)) >= 0.0
	var lod_matches := true
	for lod_level in ["HIGH", "MEDIUM", "LOW"]:
		var filtered: VfxResult = VfxPreviewLodFilterModel.new().filter(plan_result.value, lod_level, policy_result.value)
		var runtime := _runtime_for(filtered.value, 0.0) if filtered.success else null
		var expected_renderers := 1 if lod_level == "LOW" else 2
		var expected_bindings := 3 if lod_level == "LOW" else 6
		lod_matches = lod_matches and runtime != null and runtime.active_renderer_count() == expected_renderers \
			and runtime.active_runtime_modulation_binding_count() == expected_bindings and runtime.modulation_sample_count_last_tick() == 1
	tests.expect_true(
		dynamics_match and root_error_max <= 0.001 and normal_sweep_range_violations == 0 and lod_matches,
		"Super Booster uses one shared 7Hz loop source for subtle finite Core and Soft pulses without root drift, offset modulation, particles, or Soft at LOW LOD"
	)


static func _matches_static_layer(layer: Dictionary, family: String, scale: Vector2, offset: Vector2, opacity: float, pivot: Vector2) -> bool:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	return layer.get("type") == "TEXTURED_SPRITE" and layer.get("importance") == ("CORE" if family == "core" else "DETAIL") \
		and layer.get("blend_mode") == ("ADDITIVE" if family == "core" else "ALPHA") and layer.get("render_plane") == "UNDER_VEHICLE" \
		and layer.get("anchors") == ["REAR_CENTER"] and parameters.get("texture_asset_ref") == ("fx.super_booster_flame_core" if family == "core" else "fx.super_booster_flame_soft") \
		and is_equal_approx(float(parameters.get("opacity", -1.0)), opacity) and _vector_matches(transform.get("scale", []), scale) \
		and _vector_matches(transform.get("offset", []), offset) and _vector_matches(transform.get("modulation_pivot_local", []), pivot)


static func _attachment_root(layer: Dictionary, pivot: Vector2) -> Vector2:
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	var offset := _vector(transform.get("offset", []))
	var scale := _vector(transform.get("scale", []))
	return REAR_CENTER + offset + Vector2(pivot.x * scale.x, pivot.y * scale.y).rotated(deg_to_rad(float(transform.get("rotation_degrees", 0.0))))


static func _runtime_for(plan: RefCounted, preview_time: float) -> RefCounted:
	if plan == null or plan.runtime_modulation_program() == null:
		return null
	var runtime := VfxPreviewRenderRuntimeModel.new(plan, {"anchors": {"REAR_CENTER": [0.0, 220.0]}}, _registry(), VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()))
	runtime.set_runtime_input_state(VfxPreviewRuntimeInputStateModel.new(plan.runtime_modulation_program()))
	runtime.activate_phase("loop", {"preview_time": preview_time})
	runtime.advance(0.0, {"preview_time": preview_time})
	return runtime


static func _game_footprint(bounds: Rect2i, layer: Dictionary, track_scale: float) -> Vector2:
	var scale := _vector(layer.get("transform", {}).get("scale", []))
	return Vector2(float(bounds.size.x) * scale.x, float(bounds.size.y) * scale.y) * 0.095 * track_scale


static func _alpha_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


static func _phase_layer_ids(layers: Array, expected: Array) -> bool:
	return layers.map(func(layer: Dictionary) -> String: return str(layer.get("id", "")) if layer is Dictionary else "") == expected


static func _layers_by_id(layers: Array) -> Dictionary:
	var result := {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _vector(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() == 2 else Vector2.INF


static func _vector_matches(value: Variant, expected: Vector2) -> bool:
	var actual := _vector(value)
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)
