extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const VfxPreviewRenderRuntimeModel := preload("res://src/preview/rendering/vfx_preview_render_runtime.gd")
const VfxPreviewRendererFactoryModel := preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewRuntimeInputStateModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd")
const VfxPreviewLodFilterModel := preload("res://src/performance/vfx_preview_lod_filter.gd")
const VfxPerformancePolicyModel := preload("res://src/performance/vfx_performance_policy.gd")

const REAR_CENTER := Vector2(0.0, 220.0)
const LEFT_ROOT := Vector2(-60.0, 255.0)
const RIGHT_ROOT := Vector2(60.0, 255.0)
const CORE_PIVOT := Vector2(0.0, -181.0)
const SOFT_PIVOT := Vector2(-0.5, -183.0)


static func run(tests: TestAssert) -> void:
	_test_dual_static_authoring_and_provisional_roots(tests)
	_test_dual_loop_pulse_roots_and_lod(tests)
	_test_dual_spark_contract_and_cleanup(tests)


static func _test_dual_static_authoring_and_provisional_roots(tests: TestAssert) -> void:
	var document_result: VfxResult = _load_document()
	if not document_result.success:
		tests.expect_true(false, "Dual Super Booster static authoring requires its saved independent Preset source.")
		return
	var data: Dictionary = document_result.value.normalized_data
	var phases: Dictionary = data.get("phases", {})
	var expected := {
		"start": {
			"duration": 0.12,
			"core": [Vector2(0.286, 0.86), 0.92, Vector2(0.0, 190.66)],
			"soft": [Vector2(0.643076923, 1.05), 0.42, Vector2(0.321538462, 227.15)]
		},
		"loop": {
			"duration": -1.0,
			"core": [Vector2(0.33, 1.14), 0.86, Vector2(0.0, 241.34)],
			"soft": [Vector2(0.76, 1.35), 0.55, Vector2(0.38, 282.05)]
		},
		"end": {
			"duration": 0.14,
			"core": [Vector2(0.242, 0.72), 0.42, Vector2(0.0, 165.32)],
			"soft": [Vector2(0.555384615, 0.92), 0.18, Vector2(0.277692308, 203.36)]
		}
	}
	var metadata_matches: bool = data.get("preset_id") == "equipment.super_booster.dual" \
		and data.get("category") == "SPECIAL_EQUIPMENT" and data.get("default_space_mode") == "VEHICLE_LOCAL" \
		and data.get("lifecycle", {}).get("mode") == "START_LOOP_END" and data.get("runtime_inputs", []) == []
	var phase_matches: bool = metadata_matches
	var root_error_max := {"left": 0.0, "right": 0.0}
	for phase_name in expected:
		var phase: Dictionary = phases.get(phase_name, {}) if phases.get(phase_name, {}) is Dictionary else {}
		var expected_phase: Dictionary = expected[phase_name]
		if expected_phase.get("duration", -1.0) >= 0.0:
			phase_matches = phase_matches and is_equal_approx(float(phase.get("duration_seconds", -1.0)), float(expected_phase.get("duration")))
		var layers: Array = phase.get("layers", []) if phase.get("layers", []) is Array else []
		phase_matches = phase_matches and _phase_layer_ids(layers, _expected_ids(phase_name))
		var by_id: Dictionary = _layers_by_id(layers)
		for side in ["left", "right"]:
			var target: Vector2 = LEFT_ROOT if side == "left" else RIGHT_ROOT
			var core: Dictionary = by_id.get("%s.%s_core_%s" % [phase_name, side, "flame" if phase_name == "loop" else ("ignition" if phase_name == "start" else "fade")], {})
			var soft: Dictionary = by_id.get("%s.%s_soft_%s" % [phase_name, side, "flame" if phase_name == "loop" else ("ignition" if phase_name == "start" else "fade")], {})
			var core_expected: Array = expected_phase["core"]
			var soft_expected: Array = expected_phase["soft"]
			var core_offset: Vector2 = Vector2(float(core_expected[2].x) + target.x, core_expected[2].y)
			var soft_offset: Vector2 = Vector2(float(soft_expected[2].x) + target.x, soft_expected[2].y)
			phase_matches = phase_matches and _matches_static_layer(core, "core", core_expected[0], core_expected[1], core_offset, CORE_PIVOT, phase_name == "loop")
			phase_matches = phase_matches and _matches_static_layer(soft, "soft", soft_expected[0], soft_expected[1], soft_offset, SOFT_PIVOT, phase_name == "loop")
			root_error_max[side] = maxf(float(root_error_max[side]), maxf(_attachment_root(core, CORE_PIVOT).distance_to(target), _attachment_root(soft, SOFT_PIVOT).distance_to(target)))
	var sources: Array = data.get("runtime_modulation_sources", []) if data.get("runtime_modulation_sources", []) is Array else []
	var source_matches: bool = sources.size() == 1 and sources[0] is Dictionary and sources[0].get("id") == "flame.pulse" \
		and sources[0].get("type") == "OSCILLATOR" and sources[0].get("wave") == "SINE" and is_equal_approx(float(sources[0].get("frequency_hz", -1.0)), 7.0)
	tests.expect_true(
		phase_matches and source_matches and float(root_error_max["left"]) <= 0.001 and float(root_error_max["right"]) <= 0.001,
		"Dual Super Booster keeps independent full-size P5 geometry at provisional -60/+60 roots after its final twelve-pixel rear shift while sharing one 7Hz flame.pulse source"
	)


static func _test_dual_loop_pulse_roots_and_lod(tests: TestAssert) -> void:
	var document_result: VfxResult = _load_document()
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	var policy_result: VfxResult = VfxPerformancePolicyModel.new().load(_registry())
	if not plan_result.success or not policy_result.success:
		tests.expect_true(false, "Dual Super Booster loop root regression requires a valid saved Preset, Render Plan, and performance policy.")
		return
	var root_errors := {"left": 0.0, "right": 0.0}
	var finite_packets := true
	for preview_time in [0.0, 1.0 / 28.0, 3.0 / 28.0]:
		var runtime := _runtime_for(plan_result.value, preview_time)
		if runtime == null:
			finite_packets = false
			continue
		for packet_value in runtime.draw_packets():
			if not packet_value is Dictionary:
				finite_packets = false
				continue
			var packet: Dictionary = packet_value
			var layer_id := str(packet.get("layer_id", ""))
			if not layer_id.contains("core_flame") and not layer_id.contains("soft_flame"):
				continue
			var side := "left" if layer_id.contains(".left_") else "right" if layer_id.contains(".right_") else ""
			if side.is_empty():
				finite_packets = false
				continue
			var pivot := CORE_PIVOT if layer_id.contains("core_flame") else SOFT_PIVOT
			var scale: Vector2 = packet.get("geometry_scale", Vector2.ZERO)
			var root: Vector2 = packet.get("position", Vector2.ZERO) + Vector2(pivot.x * scale.x, pivot.y * scale.y).rotated(deg_to_rad(float(packet.get("geometry_rotation_degrees", 0.0))))
			root_errors[side] = maxf(float(root_errors[side]), root.distance_to(LEFT_ROOT if side == "left" else RIGHT_ROOT))
			finite_packets = finite_packets and is_finite(scale.x) and is_finite(scale.y) and float(packet.get("alpha", -1.0)) >= 0.0
	var lod_matches := true
	for lod_level in ["HIGH", "MEDIUM", "LOW"]:
		var filtered: VfxResult = VfxPreviewLodFilterModel.new().filter(plan_result.value, lod_level, policy_result.value)
		var runtime := _runtime_for(filtered.value, 0.0) if filtered.success else null
		var expected_renderers := 6 if lod_level == "HIGH" else 4 if lod_level == "MEDIUM" else 2
		var expected_bindings := 12 if lod_level != "LOW" else 6
		lod_matches = lod_matches and runtime != null and runtime.active_renderer_count() == expected_renderers and runtime.active_runtime_modulation_binding_count() == expected_bindings
	tests.expect_true(
		finite_packets and float(root_errors["left"]) <= 0.001 and float(root_errors["right"]) <= 0.001 and lod_matches,
		"Dual Super Booster preserves its widened -60/+60 provisional roots through shared-pulse -1/0/+1 extrema and authoring LOD keeps 6/4/2 renderers with 12/12/6 modulation bindings"
	)


static func _test_dual_spark_contract_and_cleanup(tests: TestAssert) -> void:
	var document_result: VfxResult = _load_document()
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(_registry()).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	if not plan_result.success:
		tests.expect_true(false, "Dual Super Booster spark regression requires a compiled Render Plan.")
		return
	var layers := _layers_by_id(document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []))
	var left: Dictionary = layers.get("loop.left_energy_spark_accent", {})
	var right: Dictionary = layers.get("loop.right_energy_spark_accent", {})
	var left_parameters: Dictionary = left.get("parameters", {}) if left.get("parameters", {}) is Dictionary else {}
	var right_parameters: Dictionary = right.get("parameters", {}) if right.get("parameters", {}) is Dictionary else {}
	var left_transform: Dictionary = left.get("transform", {}) if left.get("transform", {}) is Dictionary else {}
	var right_transform: Dictionary = right.get("transform", {}) if right.get("transform", {}) is Dictionary else {}
	var particle_matches := _matches_spark(left, left_parameters, left_transform, -60.0, 295.0) and _matches_spark(right, right_parameters, right_transform, 60.0, 295.0)
	var runtime := _runtime_for(plan_result.value, 0.0)
	if runtime == null:
		tests.expect_true(false, "Dual Super Booster spark cleanup regression requires an active Preview Runtime.")
		return
	runtime.advance(0.20, {"preview_time": 0.20})
	var spawned: Array = runtime.draw_packets().filter(func(packet: Variant) -> bool: return packet is Dictionary and str(packet.get("layer_id", "")).contains("energy_spark_accent"))
	var spawned_in_boxes: bool = spawned.all(func(packet: Dictionary) -> bool:
		var position: Vector2 = packet.get("position", Vector2.INF)
		return position.y >= 425.0 and position.y <= 605.0 and (position.x >= -155.0 and position.x <= 35.0 or position.x >= -35.0 and position.x <= 155.0)
	)
	runtime.stop_phase_sources("loop")
	runtime.advance(0.159, {"preview_time": 0.359})
	var before_expiry: Array = runtime.draw_packets().filter(func(packet: Variant) -> bool: return packet is Dictionary and str(packet.get("layer_id", "")).contains("energy_spark_accent"))
	runtime.advance(0.002, {"preview_time": 0.361})
	var after_expiry: Array = runtime.draw_packets().filter(func(packet: Variant) -> bool: return packet is Dictionary and str(packet.get("layer_id", "")).contains("energy_spark_accent"))
	tests.expect_true(
		particle_matches and spawned.size() == 8 and spawned_in_boxes and before_expiry.size() == 8 and after_expiry.is_empty() and not runtime.has_residual(),
		"Dual Super Booster preserves its P5 spark contract per nozzle while moving both mid-tail boxes with the widened and rear-shifted provisional roots"
	)


static func _matches_static_layer(layer: Dictionary, family: String, scale: Vector2, opacity: float, offset: Vector2, pivot: Vector2, loop: bool) -> bool:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	var transform: Dictionary = layer.get("transform", {}) if layer.get("transform", {}) is Dictionary else {}
	var expected_modulation_count := 3 if loop else 0
	return layer.get("type") == "TEXTURED_SPRITE" and layer.get("importance") == ("CORE" if family == "core" else "DETAIL") \
		and layer.get("blend_mode") == ("ADDITIVE" if family == "core" else "ALPHA") and layer.get("render_plane") == "UNDER_VEHICLE" \
		and layer.get("anchors") == ["REAR_CENTER"] and parameters.get("texture_asset_ref") == ("fx.super_booster_flame_core" if family == "core" else "fx.super_booster_flame_soft") \
		and is_equal_approx(float(parameters.get("opacity", -1.0)), opacity) and _vector_matches(transform.get("scale", []), scale) \
		and _vector_matches(transform.get("offset", []), offset) and _vector_matches(transform.get("modulation_pivot_local", []), pivot) \
		and (layer.get("modulations", []) as Array).size() == expected_modulation_count


static func _matches_spark(layer: Dictionary, parameters: Dictionary, transform: Dictionary, expected_x: float, expected_y: float) -> bool:
	return layer.get("type") == "PARTICLE" and layer.get("importance") == "EXTRA" and layer.get("blend_mode") == "ADDITIVE" \
		and layer.get("render_plane") == "UNDER_VEHICLE" and layer.get("anchors") == ["REAR_CENTER"] \
		and _vector_matches(transform.get("offset", []), Vector2(expected_x, expected_y)) and _vector_matches(transform.get("scale", []), Vector2.ONE) \
		and parameters.get("sprite_asset_ref") == "fx.super_booster_spark_blue" and parameters.get("emission_mode") == "CONTINUOUS" \
		and parameters.get("emitter") == {"shape": "BOX", "size": [190.0, 180.0]} and is_equal_approx(float(parameters.get("emission_rate_per_second", -1.0)), 20.0) \
		and int(parameters.get("max_particles", -1)) == 6 and is_equal_approx(float(parameters.get("lifetime_seconds", -1.0)), 0.16) \
		and is_equal_approx(float(parameters.get("size_start", -1.0)), 28.0) and is_equal_approx(float(parameters.get("size_end", -1.0)), 19.6) \
		and is_equal_approx(float(parameters.get("size_multiplier_min", -1.0)), 0.75) and is_equal_approx(float(parameters.get("size_multiplier_max", -1.0)), 1.15) \
		and is_equal_approx(float(parameters.get("direction_degrees", -1.0)), 180.0) and is_equal_approx(float(parameters.get("spread_degrees", -1.0)), 60.0) \
		and is_equal_approx(float(parameters.get("speed_min", -1.0)), 500.0) and is_equal_approx(float(parameters.get("speed_max", -1.0)), 700.0) \
		and is_equal_approx(float(parameters.get("alpha_start", -1.0)), 0.85) and is_zero_approx(float(parameters.get("alpha_end", -1.0))) \
		and is_zero_approx(float(parameters.get("rotation_min_degrees", -1.0))) and is_equal_approx(float(parameters.get("rotation_max_degrees", -1.0)), 360.0) \
		and is_zero_approx(float(parameters.get("angular_velocity_min_degrees_per_second", -1.0))) and is_zero_approx(float(parameters.get("angular_velocity_max_degrees_per_second", -1.0)))


static func _expected_ids(phase_name: String) -> Array:
	var suffix := "flame" if phase_name == "loop" else "ignition" if phase_name == "start" else "fade"
	var ids := ["%s.left_core_%s" % [phase_name, suffix], "%s.left_soft_%s" % [phase_name, suffix]]
	if phase_name == "loop":
		ids.append("loop.left_energy_spark_accent")
	ids.append("%s.right_core_%s" % [phase_name, suffix])
	ids.append("%s.right_soft_%s" % [phase_name, suffix])
	if phase_name == "loop":
		ids.append("loop.right_energy_spark_accent")
	return ids


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


static func _load_document() -> VfxResult:
	return VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.super_booster.dual.vfx.json")


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _phase_layer_ids(layers: Array, expected: Array) -> bool:
	return layers.map(func(layer: Dictionary) -> String: return str(layer.get("id", "")) if layer is Dictionary else "") == expected


static func _layers_by_id(layers: Array) -> Dictionary:
	var result := {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result


static func _vector(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() == 2 else Vector2.INF


static func _vector_matches(value: Variant, expected: Vector2) -> bool:
	var actual := _vector(value)
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)
