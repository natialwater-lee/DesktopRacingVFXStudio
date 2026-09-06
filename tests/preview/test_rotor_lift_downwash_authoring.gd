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
const VfxPreviewLodFilterModel := preload("res://src/performance/vfx_preview_lod_filter.gd")
const VfxPerformancePolicyModel := preload("res://src/performance/vfx_performance_policy.gd")

const LEFT_FAN := Vector2(-150.0, 0.0)
const RIGHT_FAN := Vector2(150.0, 0.0)
const CORE_ALPHA_BOUNDS := Rect2i(0, 0, 506, 512)
const SOFT_ALPHA_BOUNDS := Rect2i(0, 0, 512, 512)
const PARTICLE_ALPHA_BOUNDS := Rect2i(11, 0, 44, 55)
const CORE_SOURCE := {"id": "rotor.core.phase", "type": "LINEAR_PHASE", "frequency_hz": 2.4}
const SOFT_SOURCE := {"id": "rotor.soft.phase", "type": "LINEAR_PHASE", "frequency_hz": 1.35}
const LEFT_SOFT_PRESSURE_SOURCE := {"id": "rotor.left_soft.pressure", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 1.1, "phase_degrees": 0.0}
const RIGHT_SOFT_PRESSURE_SOURCE := {"id": "rotor.right_soft.pressure", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 1.1, "phase_degrees": 90.0}
const SOFT_PULSE_MULTIPLIER_MIN := 0.9673913043478261
const SOFT_PULSE_MULTIPLIER_MAX := 1.032608695652174
const SOFT_PULSE_SCALE_MIN := 0.89
const SOFT_PULSE_SCALE_MAX := 0.95


static func run(tests: TestAssert) -> void:
	_test_r3_asset_and_source_contract(tests)
	_test_rotating_sprite_geometry_and_bindings(tests)
	_test_preview_effective_rotations(tests)
	_test_loop_soft_pressure_pulse_and_pivots(tests)
	_test_turbulence_circle_rng_and_cleanup(tests)
	_test_lod_inventory(tests)


static func _test_r3_asset_and_source_contract(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var core := resolver.resolve("fx.rotor_lift_downwash_core")
	var soft := resolver.resolve("fx.rotor_lift_downwash_soft")
	var turbulence := resolver.resolve("fx.rotor_lift_turbulence_particle")
	var core_image: Image = core.value.get("texture").get_image() if core.success and core.value.get("texture") is Texture2D else null
	var soft_image: Image = soft.value.get("texture").get_image() if soft.success and soft.value.get("texture") is Texture2D else null
	var turbulence_image: Image = turbulence.value.get("texture").get_image() if turbulence.success and turbulence.value.get("texture") is Texture2D else null
	var data := _data()
	var phases: Dictionary = data.get("phases", {}) if data.get("phases", {}) is Dictionary else {}
	var expected_sources: Array = [CORE_SOURCE, SOFT_SOURCE, LEFT_SOFT_PRESSURE_SOURCE, RIGHT_SOFT_PRESSURE_SOURCE]
	tests.expect_true(
		core.success and soft.success and turbulence.success and core_image != null and soft_image != null and turbulence_image != null \
		and core_image.get_size() == Vector2i(512, 512) and soft_image.get_size() == Vector2i(512, 512) and turbulence_image.get_size() == Vector2i(64, 64) \
		and _alpha_bounds(core_image) == CORE_ALPHA_BOUNDS and _alpha_bounds(soft_image) == SOFT_ALPHA_BOUNDS and _alpha_bounds(turbulence_image) == PARTICLE_ALPHA_BOUNDS \
		and data.get("preset_id") == "equipment.rotor_lift.downwash" and data.get("category") == "SPECIAL_EQUIPMENT" \
		and data.get("default_space_mode") == "VEHICLE_LOCAL" and data.get("lifecycle", {}).get("mode") == "START_LOOP_END" \
		and data.get("runtime_inputs", []) == [] and data.get("runtime_modulation_sources", []) == expected_sources \
		and _ids(phases.get("start", {}).get("layers", [])) == ["start.left_core_spin", "start.left_soft_spin", "start.right_core_spin", "start.right_soft_spin"] \
		and _ids(phases.get("loop", {}).get("layers", [])) == ["loop.left_core_spin", "loop.left_soft_spin", "loop.right_core_spin", "loop.right_soft_spin", "loop.left_turbulence", "loop.right_turbulence"] \
		and _ids(phases.get("end", {}).get("layers", [])) == ["end.left_core_spin", "end.left_soft_spin", "end.right_core_spin", "end.right_soft_spin"],
		"Rotor Lift R3.1 resolves the three supplied assets, two faster LINEAR_PHASE sources, and two phase-shifted existing SINE pressure sources with four fan-centered rotating sprites in every lifecycle phase"
	)


static func _test_rotating_sprite_geometry_and_bindings(tests: TestAssert) -> void:
	var data := _data()
	var phases: Dictionary = data.get("phases", {}) if data.get("phases", {}) is Dictionary else {}
	var phase_opacity := {
		"start": {"core": 0.30, "soft": 0.14},
		"loop": {"core": 0.48, "soft": 0.24},
		"end": {"core": 0.22, "soft": 0.12}
	}
	var matches := true
	for phase_name in ["start", "loop", "end"]:
		var layers := _by_id(phases.get(phase_name, {}).get("layers", []))
		var opacity: Dictionary = phase_opacity.get(phase_name, {})
		var left_pressure_source: Dictionary = LEFT_SOFT_PRESSURE_SOURCE if phase_name == "loop" else {}
		var right_pressure_source: Dictionary = RIGHT_SOFT_PRESSURE_SOURCE if phase_name == "loop" else {}
		matches = matches \
			and _matches_rotating_sprite(layers.get("%s.left_core_spin" % phase_name, {}), "%s.left_core_spin" % phase_name, LEFT_FAN, 0.80, 0.0, float(opacity.get("core", -1.0)), "CORE", "fx.rotor_lift_downwash_core", CORE_SOURCE, -360.0) \
			and _matches_rotating_sprite(layers.get("%s.left_soft_spin" % phase_name, {}), "%s.left_soft_spin" % phase_name, LEFT_FAN, 0.92, 45.0, float(opacity.get("soft", -1.0)), "DETAIL", "fx.rotor_lift_downwash_soft", SOFT_SOURCE, -360.0, left_pressure_source) \
			and _matches_rotating_sprite(layers.get("%s.right_core_spin" % phase_name, {}), "%s.right_core_spin" % phase_name, RIGHT_FAN, 0.80, 22.5, float(opacity.get("core", -1.0)), "CORE", "fx.rotor_lift_downwash_core", CORE_SOURCE, 360.0) \
			and _matches_rotating_sprite(layers.get("%s.right_soft_spin" % phase_name, {}), "%s.right_soft_spin" % phase_name, RIGHT_FAN, 0.92, 67.5, float(opacity.get("soft", -1.0)), "DETAIL", "fx.rotor_lift_downwash_soft", SOFT_SOURCE, 360.0, right_pressure_source)
	tests.expect_true(matches, "Rotor Lift R3.1 keeps every Core and Soft pivot directly on +/-150, preserves ALPHA and phase opacity, reverses the counter-rotation mappings, and adds LOOP-only phase-shifted Soft scale pressure")


static func _test_preview_effective_rotations(tests: TestAssert) -> void:
	var data := _data()
	var expected := {
		0.0: {"loop.left_core_spin": 0.0, "loop.left_soft_spin": 45.0, "loop.right_core_spin": 22.5, "loop.right_soft_spin": 67.5},
		0.25: {"loop.left_core_spin": -216.0, "loop.left_soft_spin": -76.5, "loop.right_core_spin": 238.5, "loop.right_soft_spin": 189.0},
		0.5: {"loop.left_core_spin": -72.0, "loop.left_soft_spin": -198.0, "loop.right_core_spin": 94.5, "loop.right_soft_spin": 310.5},
		1.0: {"loop.left_core_spin": -144.0, "loop.left_soft_spin": -81.0, "loop.right_core_spin": 166.5, "loop.right_soft_spin": 193.5}
	}
	var plan_result := VfxPreviewRenderPlanBuilderModel.new(_registry()).build(data)
	var matches := plan_result.success
	for preview_time in expected:
		var runtime := _runtime(plan_result.value) if plan_result.success else null
		if runtime == null:
			matches = false
			continue
		runtime.activate_phase("loop", {"preview_time": float(preview_time)})
		runtime.advance(0.0, {"preview_time": float(preview_time)})
		var expected_at_time: Dictionary = expected.get(preview_time, {})
		for layer_id in expected_at_time:
			var packet := _packet_by_layer(runtime.draw_packets(), str(layer_id))
			matches = matches and not packet.is_empty() and is_equal_approx(float(packet.get("geometry_rotation_degrees", INF)), float(expected_at_time.get(layer_id, INF)))
		var left_packet := _packet_by_layer(runtime.draw_packets(), "loop.left_core_spin")
		var right_packet := _packet_by_layer(runtime.draw_packets(), "loop.right_core_spin")
		matches = matches and left_packet.get("position", Vector2.INF).distance_to(LEFT_FAN) <= 0.001 and right_packet.get("position", Vector2.INF).distance_to(RIGHT_FAN) <= 0.001
	tests.expect_true(matches, "Rotor Lift R3.1 Preview evaluates existing LINEAR_PHASE time at 0/.25/.5/1 seconds into reversed 2.4Hz Core and 1.35Hz Soft counter-rotations while both fan pivots stay at their geometric centers")


static func _test_loop_soft_pressure_pulse_and_pivots(tests: TestAssert) -> void:
	var data := _data()
	var expected := {
		0.0: {"left": 0.92, "right": 0.95},
		0.22727272727272727: {"left": 0.95, "right": 0.92},
		0.45454545454545453: {"left": 0.92, "right": 0.89},
		0.6818181818181818: {"left": 0.89, "right": 0.92}
	}
	var plan_result := VfxPreviewRenderPlanBuilderModel.new(_registry()).build(data)
	var matches := plan_result.success
	for preview_time in expected:
		var runtime := _runtime(plan_result.value) if plan_result.success else null
		if runtime == null:
			matches = false
			continue
		runtime.activate_phase("loop", {"preview_time": float(preview_time)})
		runtime.advance(0.0, {"preview_time": float(preview_time)})
		var values: Dictionary = expected.get(preview_time, {})
		var left_packet := _packet_by_layer(runtime.draw_packets(), "loop.left_soft_spin")
		var right_packet := _packet_by_layer(runtime.draw_packets(), "loop.right_soft_spin")
		var left_scale: Vector2 = left_packet.get("geometry_scale", Vector2.INF)
		var right_scale: Vector2 = right_packet.get("geometry_scale", Vector2.INF)
		matches = matches and is_equal_approx(left_scale.x, float(values.get("left", INF))) and is_equal_approx(left_scale.y, float(values.get("left", INF))) \
			and is_equal_approx(right_scale.x, float(values.get("right", INF))) and is_equal_approx(right_scale.y, float(values.get("right", INF))) \
			and left_packet.get("position", Vector2.INF).distance_to(LEFT_FAN) <= 0.001 and right_packet.get("position", Vector2.INF).distance_to(RIGHT_FAN) <= 0.001
	tests.expect_true(matches, "Rotor Lift R3.1 reuses existing SINE scale MULTIPLY for LOOP-only .89-to-.95 Soft pressure with 90-degree left/right phase separation and zero fan-center movement")


static func _test_turbulence_circle_rng_and_cleanup(tests: TestAssert) -> void:
	var data := _data()
	var layers := _by_id(data.get("phases", {}).get("loop", {}).get("layers", []))
	var left: Dictionary = layers.get("loop.left_turbulence", {})
	var right: Dictionary = layers.get("loop.right_turbulence", {})
	var parameters_match := _matches_turbulence(left, "loop.left_turbulence", LEFT_FAN, -360.0, -180.0) and _matches_turbulence(right, "loop.right_turbulence", RIGHT_FAN, 180.0, 360.0)
	var synthetic: Dictionary = data.duplicate(true)
	var synthetic_layers := _by_id(synthetic.get("phases", {}).get("loop", {}).get("layers", []))
	for layer_id in ["loop.left_turbulence", "loop.right_turbulence"]:
		var layer: Dictionary = synthetic_layers.get(layer_id, {})
		layer.get("transform", {})["offset"] = [0.0, 0.0]
		layer.get("parameters", {})["angular_velocity_min_degrees_per_second"] = 0.0
		layer.get("parameters", {})["angular_velocity_max_degrees_per_second"] = 0.0
	var plan_result := VfxPreviewRenderPlanBuilderModel.new(_registry()).build(synthetic)
	var runtime := _runtime(plan_result.value) if plan_result.success else null
	var runtime_match := runtime != null
	if runtime != null:
		runtime.activate_phase("loop", {"preview_time": 0.0})
		runtime.advance(0.15, {"preview_time": 0.15})
		var left_packets := _packets(runtime.draw_packets(), "loop.left_turbulence")
		var right_packets := _packets(runtime.draw_packets(), "loop.right_turbulence")
		var inside_disk: bool = left_packets.size() == 1 and right_packets.size() == 1 and left_packets[0].get("position", Vector2.INF).length() <= 110.001 and right_packets[0].get("position", Vector2.INF).length() <= 110.001
		var independent: bool = inside_disk and not left_packets[0].get("position", Vector2.ZERO).is_equal_approx(right_packets[0].get("position", Vector2.ZERO))
		runtime.stop_phase_sources("loop")
		runtime.advance(0.319, {"preview_time": 0.469})
		var before_expiry := _packets(runtime.draw_packets(), "loop.left_turbulence").size() + _packets(runtime.draw_packets(), "loop.right_turbulence").size()
		runtime.advance(0.002, {"preview_time": 0.471})
		var after_expiry := _packets(runtime.draw_packets(), "loop.left_turbulence").size() + _packets(runtime.draw_packets(), "loop.right_turbulence").size()
		runtime_match = inside_disk and independent and before_expiry == 2 and after_expiry == 0 and not runtime.has_residual()
	tests.expect_true(parameters_match and runtime_match, "Rotor Lift R3.1 uses the existing CIRCLE disk sampler at each fan, full 360-degree spread, turbulence self-rotation reversed with its parent swirl, distinct layer-ID RNG sequences, and .32-second LOOP cleanup")


static func _test_lod_inventory(tests: TestAssert) -> void:
	var data := _data()
	var plan_result := VfxPreviewRenderPlanBuilderModel.new(_registry()).build(data)
	var policy_result := VfxPerformancePolicyModel.new().load(_registry())
	var analyzer_script := load("res://src/performance/vfx_performance_budget_analyzer.gd") as Script
	var expected := {"HIGH": [6, 4, 6], "MEDIUM": [4, 4, 0], "LOW": [2, 2, 0]}
	var matches := plan_result.success and policy_result.success and analyzer_script != null
	for level in expected:
		var filtered: VfxResult = VfxPreviewLodFilterModel.new().filter(plan_result.value, level, policy_result.value) if plan_result.success and policy_result.success else VfxResult.failure([])
		var budget: VfxResult = analyzer_script.new(_registry()).analyze(filtered.value, {"anchors": {"CENTER": [0.0, 0.0]}}, "STEADY_LOOP") if filtered.success and analyzer_script != null else VfxResult.failure([])
		var workload: Variant = budget.value.active_workload() if budget.success else null
		var values: Array = expected[level]
		matches = matches and workload != null and workload.expanded_instance_count() == values[0] and workload.persistent_textured_sprite_instance_count() == values[1] and workload.continuous_particle_capacity() == values[2]
	tests.expect_true(matches, "Rotor Lift R3 authoring LOD is HIGH four rotating sprites plus two turbulence emitters capped at six, MEDIUM four sprites, and LOW two Core sprites")


static func _matches_rotating_sprite(layer: Dictionary, layer_id: String, fan_center: Vector2, scale: float, base_rotation: float, opacity: float, importance: String, asset_id: String, source: Dictionary, output_max: float, pressure_source: Dictionary = {}) -> bool:
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var expected_binding := {
		"id": "%s.rotation" % layer_id,
		"target": "TRANSFORM_ROTATION_DEGREES",
		"operation": "ADD",
		"source": {"type": "PRESET_SOURCE", "source_id": source.get("id")},
		"mapping": {"type": "LINEAR_RANGE", "input_min": 0.0, "input_max": 1.0, "output_min": 0.0, "output_max": output_max}
	}
	var expected_bindings: Array = [expected_binding]
	var expected_clamps: Array = []
	if not pressure_source.is_empty():
		for target in ["TRANSFORM_SCALE_X", "TRANSFORM_SCALE_Y"]:
			expected_bindings.append({
				"id": "%s.pressure.%s" % [layer_id, "scale_x" if target == "TRANSFORM_SCALE_X" else "scale_y"],
				"target": target,
				"operation": "MULTIPLY",
				"source": {"type": "PRESET_SOURCE", "source_id": pressure_source.get("id")},
				"mapping": {"type": "LINEAR_RANGE", "input_min": -1.0, "input_max": 1.0, "output_min": SOFT_PULSE_MULTIPLIER_MIN, "output_max": SOFT_PULSE_MULTIPLIER_MAX}
			})
			expected_clamps.append({"target": target, "min_effective": SOFT_PULSE_SCALE_MIN, "max_effective": SOFT_PULSE_SCALE_MAX})
	return layer.get("id") == layer_id and layer.get("type") == "TEXTURED_SPRITE" and layer.get("importance") == importance and layer.get("blend_mode") == "ALPHA" and layer.get("render_plane") == "UNDER_VEHICLE" and layer.get("anchors") == ["CENTER"] \
		and _vector(transform.get("offset", [])).distance_to(fan_center) <= 0.001 and _vector(transform.get("scale", [])).is_equal_approx(Vector2(scale, scale)) and is_equal_approx(float(transform.get("rotation_degrees", INF)), base_rotation) and _vector(transform.get("modulation_pivot_local", [])).is_zero_approx() \
		and parameters.get("texture_asset_ref") == asset_id and is_equal_approx(float(parameters.get("opacity", -1.0)), opacity) and layer.get("modulation_clamps", []) == expected_clamps and layer.get("modulations", []) == expected_bindings


static func _matches_turbulence(layer: Dictionary, layer_id: String, fan_center: Vector2, angular_min: float, angular_max: float) -> bool:
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	return layer.get("id") == layer_id and layer.get("type") == "PARTICLE" and layer.get("importance") == "EXTRA" and layer.get("blend_mode") == "ALPHA" and layer.get("render_plane") == "UNDER_VEHICLE" and layer.get("anchors") == ["CENTER"] \
		and _vector(transform.get("offset", [])).distance_to(fan_center) <= 0.001 and is_zero_approx(float(transform.get("rotation_degrees", INF))) and _vector(transform.get("scale", [])).is_equal_approx(Vector2.ONE) \
		and parameters.get("sprite_asset_ref") == "fx.rotor_lift_turbulence_particle" and parameters.get("emission_mode") == "CONTINUOUS" and parameters.get("emitter") == {"shape": "CIRCLE", "radius": 110.0} \
		and is_equal_approx(float(parameters.get("lifetime_seconds", -1.0)), 0.32) and is_equal_approx(float(parameters.get("emission_rate_per_second", -1.0)), 7.0) and int(parameters.get("max_particles", -1)) == 3 \
		and is_equal_approx(float(parameters.get("direction_degrees", INF)), 0.0) and is_equal_approx(float(parameters.get("spread_degrees", INF)), 360.0) and is_equal_approx(float(parameters.get("speed_min", -1.0)), 90.0) and is_equal_approx(float(parameters.get("speed_max", -1.0)), 150.0) \
		and is_equal_approx(float(parameters.get("size_start", -1.0)), 18.0) and is_equal_approx(float(parameters.get("size_end", -1.0)), 11.0) and is_equal_approx(float(parameters.get("size_multiplier_min", -1.0)), 0.75) and is_equal_approx(float(parameters.get("size_multiplier_max", -1.0)), 1.15) \
		and is_equal_approx(float(parameters.get("alpha_start", -1.0)), 0.42) and is_zero_approx(float(parameters.get("alpha_end", -1.0))) and is_equal_approx(float(parameters.get("rotation_min_degrees", INF)), 0.0) and is_equal_approx(float(parameters.get("rotation_max_degrees", INF)), 360.0) \
		and is_equal_approx(float(parameters.get("angular_velocity_min_degrees_per_second", INF)), angular_min) and is_equal_approx(float(parameters.get("angular_velocity_max_degrees_per_second", INF)), angular_max) and parameters.get("acceleration") == [0.0, 0.0]


static func _data() -> Dictionary:
	var document := VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.rotor_lift.downwash.vfx.json")
	return document.value.normalized_data if document.success else {}


static func _runtime(plan: RefCounted) -> RefCounted:
	return VfxPreviewRenderRuntimeModel.new(plan, {"anchors": {"CENTER": [0.0, 0.0]}}, _registry(), VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()))


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _by_id(layers: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not layers is Array:
		return result
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result


static func _ids(layers: Variant) -> Array:
	var result: Array = []
	if not layers is Array:
		return result
	for layer in layers:
		if layer is Dictionary:
			result.append(str(layer.get("id", "")))
	return result


static func _packets(packets: Array, layer_id: String) -> Array:
	return packets.filter(func(packet: Variant) -> bool: return packet is Dictionary and packet.get("layer_id") == layer_id)


static func _packet_by_layer(packets: Array, layer_id: String) -> Dictionary:
	for packet in packets:
		if packet is Dictionary and packet.get("layer_id") == layer_id:
			return packet
	return {}


static func _vector(value: Variant) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.INF


static func _alpha_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				minimum.x = mini(minimum.x, x)
				minimum.y = mini(minimum.y, y)
				maximum.x = maxi(maximum.x, x)
				maximum.y = maxi(maximum.y, y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE) if maximum.x >= minimum.x else Rect2i()
