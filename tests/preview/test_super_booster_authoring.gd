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
const PRESET_LOCAL_REAR_OFFSET := Vector2(0.0, 35.0)
const NOZZLE_ROOT := Vector2(0.0, 255.0)
const CORE_PIVOT := Vector2(0.0, -181.0)
const SOFT_PIVOT := Vector2(-0.5, -183.0)
const CORE_ALPHA_BOUNDS := Rect2i(16, 3, 208, 373)
const SOFT_ALPHA_BOUNDS := Rect2i(0, 4, 253, 380)
const SPARK_ALPHA_BOUNDS := Rect2i(11, 5, 46, 53)


static func run(tests: TestAssert) -> void:
	_test_assets_and_single_nozzle_contract(tests)
	_test_all_phase_attachment_roots_and_game_footprint(tests)
	_test_loop_energy_spark_contract_and_cleanup(tests)
	_test_loop_motion_preserves_attachment_and_lod(tests)
	_test_turn_rate_rotation_preserves_attachment_across_all_phases(tests)


static func _test_assets_and_single_nozzle_contract(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var core_result: VfxResult = resolver.resolve("fx.super_booster_flame_core")
	var soft_result: VfxResult = resolver.resolve("fx.super_booster_flame_soft")
	var spark_result: VfxResult = resolver.resolve("fx.super_booster_spark_blue")
	var core_image: Image = core_result.value.get("texture").get_image() if core_result.success and core_result.value.get("texture") is Texture2D else null
	var soft_image: Image = soft_result.value.get("texture").get_image() if soft_result.success and soft_result.value.get("texture") is Texture2D else null
	var spark_image: Image = spark_result.value.get("texture").get_image() if spark_result.success and spark_result.value.get("texture") is Texture2D else null
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.super_booster.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Super Booster single-nozzle contract requires a valid saved Preset")
		return
	var data: Dictionary = document_result.value.normalized_data
	var phases: Dictionary = data.get("phases", {})
	var static_matches: bool = data.get("preset_id") == "equipment.super_booster" \
		and data.get("category") == "SPECIAL_EQUIPMENT" and data.get("default_space_mode") == "VEHICLE_LOCAL" \
		and data.get("lifecycle", {}).get("mode") == "START_LOOP_END" and data.get("runtime_inputs", []) == ["turn_rate_normalized"] \
		and NOZZLE_ROOT == REAR_CENTER + PRESET_LOCAL_REAR_OFFSET \
		and _phase_layer_ids(phases.get("start", {}).get("layers", []), ["start.core_ignition", "start.soft_ignition"]) \
		and _phase_layer_ids(phases.get("loop", {}).get("layers", []), ["loop.core_flame", "loop.soft_flame", "loop.energy_spark_accent"]) \
		and _phase_layer_ids(phases.get("end", {}).get("layers", []), ["end.core_fade", "end.soft_fade"])
	tests.expect_true(
		core_result.success and soft_result.success and spark_result.success and core_image != null and soft_image != null and spark_image != null \
		and core_image.get_size() == Vector2i(256, 384) and soft_image.get_size() == Vector2i(256, 384) \
		and spark_image.get_size() == Vector2i(64, 64) \
		and _alpha_bounds(core_image) == CORE_ALPHA_BOUNDS and _alpha_bounds(soft_image) == SOFT_ALPHA_BOUNDS and _alpha_bounds(spark_image) == SPARK_ALPHA_BOUNDS \
		and static_matches,
		"Super Booster resolves its dedicated transparent blue-spark texture alongside the supplied flame textures in one SPECIAL_EQUIPMENT single-nozzle START_LOOP_END Preset"
	)


static func _test_all_phase_attachment_roots_and_game_footprint(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.super_booster.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Super Booster attachment checks require a valid saved Preset")
		return
	var phase_expectations := {
		"start": {"core": [Vector2(0.3289, 0.989), Vector2(0.0, 214.009), 0.92], "soft": [Vector2(0.739538461, 1.2075), Vector2(0.369769231, 255.9725), 0.42]},
		"loop": {"core": [Vector2(0.3795, 1.311), Vector2(0.0, 272.291), 0.86], "soft": [Vector2(0.874, 1.5525), Vector2(0.437, 319.1075), 0.55]},
		"end": {"core": [Vector2(0.2783, 0.828), Vector2(0.0, 184.868), 0.42], "soft": [Vector2(0.638692307, 1.058), Vector2(0.319346154, 228.614), 0.18]}
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
		and core_footprint.x >= 7.49 and core_footprint.x <= 7.51 and core_footprint.y >= 46.44 and core_footprint.y <= 46.47 \
		and soft_footprint.y >= 56.03 and soft_footprint.y <= 56.06 and soft_footprint.x >= 20.99 and soft_footprint.x <= 21.02 \
		and soft_footprint_track_085.x >= 17.84 and soft_footprint_track_085.x <= 17.87 \
		and soft_footprint_track_085.y >= 47.62 and soft_footprint_track_085.y <= 47.66,
		"Every Super Booster phase places its provisional rear nozzle root at the final twelve-source-pixel rear shift while the Single Core and Soft retain root attachment at a uniform 15-percent scale-up"
	)


static func _test_loop_energy_spark_contract_and_cleanup(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.super_booster.vfx.json")
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	if not document_result.success or not plan_result.success:
		tests.expect_true(false, "Super Booster energy-spark regression requires a valid saved Preset and compiled Render Plan")
		return
	var loop_layers := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []))
	var spark: Dictionary = loop_layers.get("loop.energy_spark_accent", {})
	var parameters: Dictionary = spark.get("parameters", {}) if spark.get("parameters", {}) is Dictionary else {}
	var transform: Dictionary = spark.get("transform", {}) if spark.get("transform", {}) is Dictionary else {}
	var game_start_min := _particle_game_footprint(SPARK_ALPHA_BOUNDS, Vector2i(64, 64), 28.0, 0.75, 1.0)
	var game_start_max := _particle_game_footprint(SPARK_ALPHA_BOUNDS, Vector2i(64, 64), 28.0, 1.15, 1.0)
	var game_start_track_085_min := _particle_game_footprint(SPARK_ALPHA_BOUNDS, Vector2i(64, 64), 28.0, 0.75, 0.85)
	var game_start_track_085_max := _particle_game_footprint(SPARK_ALPHA_BOUNDS, Vector2i(64, 64), 28.0, 1.15, 0.85)
	var runtime := _runtime_for(plan_result.value, "loop", 0.0, 0.0)
	if runtime == null:
		tests.expect_true(false, "Super Booster energy-spark cleanup regression requires an active Preview Runtime")
		return
	runtime.advance(0.20, {"preview_time": 0.20})
	var spawned := _packets_for_layer(runtime.draw_packets(), "loop.energy_spark_accent")
	var starts_inside_mid_tail_box := spawned.all(func(packet: Dictionary) -> bool:
		var position: Vector2 = packet.get("position", Vector2.INF)
		return position.x >= -95.0 and position.x <= 95.0 and position.y >= 425.0 and position.y <= 605.0
	)
	runtime.stop_phase_sources("loop")
	runtime.advance(0.159, {"preview_time": 0.359})
	var before_expiry := _packets_for_layer(runtime.draw_packets(), "loop.energy_spark_accent")
	runtime.advance(0.002, {"preview_time": 0.361})
	var after_expiry := _packets_for_layer(runtime.draw_packets(), "loop.energy_spark_accent")
	var authored_contract: bool = spark.get("type") == "PARTICLE" and spark.get("importance") == "EXTRA" \
		and spark.get("blend_mode") == "ADDITIVE" and spark.get("render_plane") == "UNDER_VEHICLE" \
		and spark.get("anchors") == ["REAR_CENTER"] and _vector_matches(transform.get("offset", []), Vector2(0.0, 295.0)) \
		and _vector_matches(transform.get("scale", []), Vector2.ONE) and is_zero_approx(float(transform.get("rotation_degrees", -1.0))) \
		and parameters.get("emission_mode") == "CONTINUOUS" and parameters.get("emitter") == {"shape": "BOX", "size": [190.0, 180.0]} \
		and parameters.get("sprite_asset_ref") == "fx.super_booster_spark_blue" and is_equal_approx(float(parameters.get("emission_rate_per_second", -1.0)), 20.0) \
		and int(parameters.get("max_particles", -1)) == 6 and is_equal_approx(float(parameters.get("lifetime_seconds", -1.0)), 0.16) \
		and is_equal_approx(float(parameters.get("direction_degrees", -1.0)), 180.0) and is_equal_approx(float(parameters.get("spread_degrees", -1.0)), 60.0) \
		and is_equal_approx(float(parameters.get("speed_min", -1.0)), 500.0) and is_equal_approx(float(parameters.get("speed_max", -1.0)), 700.0) \
		and is_equal_approx(float(parameters.get("size_start", -1.0)), 28.0) and is_equal_approx(float(parameters.get("size_end", -1.0)), 19.6) \
		and is_equal_approx(float(parameters.get("size_multiplier_min", -1.0)), 0.75) and is_equal_approx(float(parameters.get("size_multiplier_max", -1.0)), 1.15) \
		and is_equal_approx(float(parameters.get("alpha_start", -1.0)), 0.85) and is_zero_approx(float(parameters.get("alpha_end", -1.0))) \
		and is_zero_approx(float(parameters.get("rotation_min_degrees", -1.0))) and is_equal_approx(float(parameters.get("rotation_max_degrees", -1.0)), 360.0) \
		and is_zero_approx(float(parameters.get("angular_velocity_min_degrees_per_second", -1.0))) and is_zero_approx(float(parameters.get("angular_velocity_max_degrees_per_second", -1.0)))
	tests.expect_true(
		authored_contract and spawned.size() == 4 and starts_inside_mid_tail_box and before_expiry.size() == 4 and after_expiry.is_empty() and not runtime.has_residual() \
		and game_start_min.y >= 3.30 and game_start_min.y <= 3.31 and game_start_max.y >= 5.06 and game_start_max.y <= 5.07 \
		and game_start_track_085_min.y >= 2.80 and game_start_track_085_min.y <= 2.81 and game_start_track_085_max.y >= 4.30 and game_start_track_085_max.y <= 4.31,
		"Super Booster keeps one LOOP-only EXTRA additive blue-spark accent at the same 0.16-second budget while a wider mid-tail BOX and 60-degree spread make its 3.3-5.1px GAME 100% fragments more visible outside the plume"
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
		var runtime := _runtime_for(plan_result.value, "loop", preview_time, 0.0)
		if runtime == null:
			dynamics_match = false
			continue
		for packet_value in runtime.draw_packets():
			if not packet_value is Dictionary:
				dynamics_match = false
				continue
			var packet: Dictionary = packet_value
			var layer_id := str(packet.get("layer_id", ""))
			if layer_id not in ["loop.core_flame", "loop.soft_flame"]:
				continue
			var is_core := layer_id == "loop.core_flame"
			var pivot := CORE_PIVOT if is_core else SOFT_PIVOT
			var scale: Vector2 = packet.get("geometry_scale", Vector2.ZERO)
			var root: Vector2 = packet.get("position", Vector2.ZERO) + Vector2(pivot.x * scale.x, pivot.y * scale.y).rotated(deg_to_rad(float(packet.get("geometry_rotation_degrees", 0.0))))
			root_error_max = maxf(root_error_max, root.distance_to(NOZZLE_ROOT))
			var min_scale := Vector2(0.37191, 1.24545) if is_core else Vector2(0.84778, 1.45935)
			var max_scale := Vector2(0.38709, 1.37655) if is_core else Vector2(0.90022, 1.64565)
			if scale.x < min_scale.x - 0.0001 or scale.x > max_scale.x + 0.0001 or scale.y < min_scale.y - 0.0001 or scale.y > max_scale.y + 0.0001:
				normal_sweep_range_violations += 1
			dynamics_match = dynamics_match and is_finite(scale.x) and is_finite(scale.y) and float(packet.get("alpha", -1.0)) >= 0.0
	var lod_matches := true
	for lod_level in ["HIGH", "MEDIUM", "LOW"]:
		var filtered: VfxResult = VfxPreviewLodFilterModel.new().filter(plan_result.value, lod_level, policy_result.value)
		var runtime := _runtime_for(filtered.value, "loop", 0.0, 0.0) if filtered.success else null
		var expected_renderers := 1 if lod_level == "LOW" else 3 if lod_level == "HIGH" else 2
		var expected_bindings := 4 if lod_level == "LOW" else 8
		lod_matches = lod_matches and runtime != null and runtime.active_renderer_count() == expected_renderers \
			and runtime.active_runtime_modulation_binding_count() == expected_bindings and runtime.modulation_sample_count_last_tick() == 1
	tests.expect_true(
		dynamics_match and root_error_max <= 0.001 and normal_sweep_range_violations == 0 and lod_matches,
		"Super Booster keeps the shared 7Hz Core/Soft pulse and its active LOOP turn bindings without root drift while HIGH alone adds the unmodulated EXTRA spark accent"
	)


static func _test_turn_rate_rotation_preserves_attachment_across_all_phases(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.super_booster.vfx.json")
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	if not plan_result.success:
		tests.expect_true(false, "Super Booster turn-response regression requires a valid saved Preset and compiled Render Plan")
		return
	var expected_turn_samples := [
		{"value": -1.0, "core": 3.0, "soft": 6.0},
		{"value": -0.20, "core": 3.0, "soft": 6.0},
		{"value": -0.10, "core": 1.5, "soft": 3.0},
		{"value": 0.0, "core": 0.0, "soft": 0.0},
		{"value": 0.10, "core": -1.5, "soft": -3.0},
		{"value": 0.20, "core": -3.0, "soft": -6.0},
		{"value": 1.0, "core": -3.0, "soft": -6.0}
	]
	var root_error_max := 0.0
	var mappings_match := true
	for phase_name in ["start", "loop", "end"]:
		for preview_time in [0.0, 1.0 / 28.0, 3.0 / 28.0]:
			for sample_value in expected_turn_samples:
				var sample: Dictionary = sample_value
				var runtime := _runtime_for(plan_result.value, phase_name, preview_time, float(sample["value"]))
				var flame_packets := _packets_for_layer(runtime.draw_packets(), _flame_layer_id(phase_name, "core")) if runtime != null else []
				flame_packets.append_array(_packets_for_layer(runtime.draw_packets(), _flame_layer_id(phase_name, "soft"))) if runtime != null else null
				mappings_match = mappings_match and flame_packets.size() == 2
				for packet_value in flame_packets:
					if not packet_value is Dictionary:
						mappings_match = false
						continue
					var packet: Dictionary = packet_value
					var is_core := str(packet.get("layer_id", "")) == _flame_layer_id(phase_name, "core")
					var pivot := CORE_PIVOT if is_core else SOFT_PIVOT
					var expected_rotation := float(sample["core"] if is_core else sample["soft"])
					var scale: Vector2 = packet.get("geometry_scale", Vector2.ZERO)
					var root: Vector2 = packet.get("position", Vector2.ZERO) + Vector2(pivot.x * scale.x, pivot.y * scale.y).rotated(deg_to_rad(float(packet.get("geometry_rotation_degrees", 0.0))))
					root_error_max = maxf(root_error_max, root.distance_to(NOZZLE_ROOT))
					mappings_match = mappings_match and is_equal_approx(float(packet.get("geometry_rotation_degrees", INF)), expected_rotation)
	var source: Dictionary = document_result.value.normalized_data
	var turn_bindings_match := true
	for phase_name in ["start", "loop", "end"]:
		var layers := _layers_by_id(source.get("phases", {}).get(phase_name, {}).get("layers", []))
		turn_bindings_match = turn_bindings_match and _matches_turn_binding(layers.get(_flame_layer_id(phase_name, "core"), {}), "%s.core.turn.rotation" % phase_name, 3.0, -3.0) \
			and _matches_turn_binding(layers.get(_flame_layer_id(phase_name, "soft"), {}), "%s.soft.turn.rotation" % phase_name, 6.0, -6.0)
	var loop_layers := _layers_by_id(source.get("phases", {}).get("loop", {}).get("layers", []))
	var spark_modulations: Array = loop_layers.get("loop.energy_spark_accent", {}).get("modulations", []) if loop_layers.get("loop.energy_spark_accent", {}) is Dictionary else []
	tests.expect_true(
		mappings_match and turn_bindings_match and spark_modulations.is_empty() and root_error_max <= 0.001,
		"Super Booster maps signed turn rate to 3/6-degree Core/Soft counter-rotation across START, LOOP, and END without pivot-root drift or Spark modulation"
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


static func _runtime_for(plan: RefCounted, phase_name: String, preview_time: float, turn_rate: float) -> RefCounted:
	if plan == null or plan.runtime_modulation_program() == null:
		return null
	var runtime := VfxPreviewRenderRuntimeModel.new(plan, {"anchors": {"REAR_CENTER": [0.0, 220.0]}}, _registry(), VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()))
	var input_state := VfxPreviewRuntimeInputStateModel.new(plan.runtime_modulation_program())
	if not input_state.set_named_value(plan.runtime_modulation_program(), "turn_rate_normalized", turn_rate):
		return null
	runtime.set_runtime_input_state(input_state)
	runtime.activate_phase(phase_name, {"preview_time": preview_time})
	runtime.advance(0.0, {"preview_time": preview_time})
	return runtime


static func _flame_layer_id(phase_name: String, family: String) -> String:
	var suffix := "flame" if phase_name == "loop" else "ignition" if phase_name == "start" else "fade"
	return "%s.%s_%s" % [phase_name, family, suffix]


static func _matches_turn_binding(layer: Dictionary, binding_id: String, output_min: float, output_max: float) -> bool:
	var bindings: Array = layer.get("modulations", []) if layer.get("modulations", []) is Array else []
	var match_count := 0
	for binding_value in bindings:
		if not binding_value is Dictionary or str(binding_value.get("id", "")) != binding_id:
			continue
		var binding: Dictionary = binding_value
		var source: Dictionary = binding.get("source", {}) if binding.get("source", {}) is Dictionary else {}
		var mapping: Dictionary = binding.get("mapping", {}) if binding.get("mapping", {}) is Dictionary else {}
		if binding.get("target") == "TRANSFORM_ROTATION_DEGREES" and binding.get("operation") == "ADD" \
			and source == {"type": "RUNTIME_INPUT", "input": "turn_rate_normalized"} and mapping.get("type") == "LINEAR_RANGE" \
			and is_equal_approx(float(mapping.get("input_min", INF)), -0.20) and is_equal_approx(float(mapping.get("input_max", INF)), 0.20) \
			and is_equal_approx(float(mapping.get("output_min", INF)), output_min) and is_equal_approx(float(mapping.get("output_max", INF)), output_max):
			match_count += 1
	var clamps: Array = layer.get("modulation_clamps", []) if layer.get("modulation_clamps", []) is Array else []
	var rotation_clamps: Array = clamps.filter(func(clamp: Variant) -> bool: return clamp is Dictionary and clamp.get("target") == "TRANSFORM_ROTATION_DEGREES")
	return match_count == 1 and rotation_clamps.size() == 1 and is_equal_approx(float(rotation_clamps[0].get("min_effective", INF)), output_max) \
		and is_equal_approx(float(rotation_clamps[0].get("max_effective", INF)), output_min)


static func _game_footprint(bounds: Rect2i, layer: Dictionary, track_scale: float) -> Vector2:
	var scale := _vector(layer.get("transform", {}).get("scale", []))
	return Vector2(float(bounds.size.x) * scale.x, float(bounds.size.y) * scale.y) * 0.095 * track_scale


static func _particle_game_footprint(bounds: Rect2i, texture_size: Vector2i, particle_size: float, multiplier: float, track_scale: float) -> Vector2:
	var texture_extent := maxf(float(texture_size.x), float(texture_size.y))
	return Vector2(float(bounds.size.x), float(bounds.size.y)) / texture_extent * (2.0 * particle_size * multiplier * 0.095 * track_scale)


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


static func _packets_for_layer(packets: Array, layer_id: String) -> Array:
	return packets.filter(func(packet: Variant) -> bool: return packet is Dictionary and packet.get("layer_id") == layer_id)


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
