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

# Fan hubs of the Game equipment sprite: 256px frame x (512 / 256) x runtime scale 1.25.
const LEFT_FAN := Vector2(-187.5, 0.0)
const RIGHT_FAN := Vector2(187.5, 0.0)
const EXPECTED_SOURCES := [
	["rotor.burst.phase", 2.85714285714286]
]


static func run(tests: TestAssert) -> void:
	_test_r10_assets_and_structure(tests)
	_test_fan_hub_geometry_without_rotation(tests)
	_test_ring_emitter_flow_is_continuous(tests)
	_test_start_blast_fades_by_phase_end(tests)
	_test_lod_inventory(tests)


static func _test_r10_assets_and_structure(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var sizes := {"fx.rotor_lift_air_ring": Vector2(512, 512), "fx.rotor_lift_mist_puff": Vector2(128, 128)}
	var assets_match := true
	for asset_id in sizes:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") if resolved.success else null
		assets_match = assets_match and texture != null and texture.get_size() == sizes[asset_id]
	var data := _data()
	var phases: Dictionary = data.get("phases", {})
	var sources: Array = data.get("runtime_modulation_sources", [])
	var sources_match := sources.size() == EXPECTED_SOURCES.size()
	for index in (EXPECTED_SOURCES.size() if sources_match else 0):
		var source: Dictionary = sources[index]
		sources_match = sources_match and source.get("id") == EXPECTED_SOURCES[index][0] and source.get("type") == "LINEAR_PHASE" and is_equal_approx(float(source.get("frequency_hz")), float(EXPECTED_SOURCES[index][1]))
	tests.expect_true(
		assets_match and sources_match \
		and data.get("preset_id") == "equipment.rotor_lift.downwash" and data.get("category") == "SPECIAL_EQUIPMENT" \
		and data.get("default_space_mode") == "VEHICLE_LOCAL" and data.get("lifecycle", {}).get("mode") == "START_LOOP_END" and data.get("runtime_inputs", []) == [] \
		and is_equal_approx(float(phases.get("start", {}).get("duration_seconds", 0.0)), 0.35) and is_equal_approx(float(phases.get("end", {}).get("duration_seconds", 0.0)), 0.2) \
		and _ids(phases.get("start", {}).get("layers", [])) == ["start.left_blast", "start.right_blast", "start.left_mist", "start.right_mist"] \
		and _ids(phases.get("loop", {}).get("layers", [])) == ["loop.left_rings", "loop.right_rings", "loop.left_mist", "loop.right_mist"] \
		and _ids(phases.get("end", {}).get("layers", [])) == [],
		"Rotor Lift R10 uses the air ring and mist puff PNGs: START ring blast + mist burst, LOOP ring emitters + mist, empty END (LOOP particles drain naturally)"
	)


static func _test_fan_hub_geometry_without_rotation(tests: TestAssert) -> void:
	var phases: Dictionary = _data().get("phases", {})
	var matches := true
	for phase_name in ["start", "loop", "end"]:
		for layer in phases.get(phase_name, {}).get("layers", []):
			var fan := LEFT_FAN if str(layer.get("id")).contains(".left_") else RIGHT_FAN
			matches = matches and _vector(layer.get("transform", {}).get("offset")) == fan \
				and layer.get("render_plane") == "UNDER_VEHICLE" and layer.get("blend_mode") == "ALPHA" and layer.get("anchors") == ["CENTER"]
			for modulation in layer.get("modulations", []):
				matches = matches and modulation.get("target") != "TRANSFORM_ROTATION_DEGREES"
	tests.expect_true(matches, "Every Rotor Lift R10 layer sits on its Game fan hub (+/-187.5) under the vehicle, and no layer rotates (the equipment frames show the fan spin)")


# Rings are particles: an even emission interval keeps several rings in flight at all times.
static func _test_ring_emitter_flow_is_continuous(tests: TestAssert) -> void:
	var loop_layers: Array = _data().get("phases", {}).get("loop", {}).get("layers", [])
	var parameters: Dictionary = {}
	for layer in loop_layers:
		if layer.get("id") == "loop.left_rings":
			parameters = layer.get("parameters", {})
	var params_match: bool = parameters.get("sprite_asset_ref") == "fx.rotor_lift_air_ring" and parameters.get("emission_mode") == "CONTINUOUS" 		and is_equal_approx(float(parameters.get("emission_rate_per_second", 0.0)), 7.0) and is_equal_approx(float(parameters.get("lifetime_seconds", 0.0)), 0.45) 		and is_equal_approx(float(parameters.get("size_start", 0.0)), 107.0) and is_equal_approx(float(parameters.get("size_end", 0.0)), 309.0) 		and is_equal_approx(float(parameters.get("speed_max", -1.0)), 0.0) and parameters.get("emitter", {}).get("shape") == "POINT"
	var plan_result := VfxPreviewRenderPlanBuilderModel.new(_registry()).build(_data())
	var runtime := _runtime(plan_result.value) if plan_result.success else null
	var minimum_in_flight := 99
	if runtime != null:
		var preview_time := 0.0
		runtime.activate_phase("loop", {"preview_time": preview_time})
		for tick in 90:
			preview_time += 1.0 / 60.0
			runtime.advance(1.0 / 60.0, {"preview_time": preview_time})
			if tick >= 40:
				minimum_in_flight = mini(minimum_in_flight, _packets(runtime.draw_packets(), "loop.left_rings").size())
	tests.expect_true(params_match and runtime != null and minimum_in_flight >= 3, "LOOP ring emitter releases a 215 -> 618 px air ring every 1/7 s with 0.45 s life, so at least three rings are always in flight (got %d)" % minimum_in_flight)


static func _test_start_blast_fades_by_phase_end(tests: TestAssert) -> void:
	var plan_result := VfxPreviewRenderPlanBuilderModel.new(_registry()).build(_data())
	var matches := plan_result.success
	for sample in [[0.0, 0.42, 0.9], [0.175, 0.76, 0.45]]:
		var runtime := _runtime(plan_result.value) if plan_result.success else null
		if runtime == null:
			matches = false
			continue
		runtime.activate_phase("start", {"preview_time": float(sample[0])})
		runtime.advance(0.0, {"preview_time": float(sample[0])})
		var packet := _packet_by_layer(runtime.draw_packets(), "start.right_blast")
		var scale: Variant = packet.get("geometry_scale", Vector2.INF)
		matches = matches and not packet.is_empty() and scale is Vector2 and is_equal_approx(scale.x, float(sample[1])) and is_equal_approx(float(packet.get("alpha", -1.0)), float(sample[2]))
	tests.expect_true(matches, "START air ring blast grows 0.42 -> 1.1 and fades linearly to zero over the 0.35 s START")


static func _test_lod_inventory(tests: TestAssert) -> void:
	var plan_result := VfxPreviewRenderPlanBuilderModel.new(_registry()).build(_data())
	var policy_result := VfxPerformancePolicyModel.new().load(_registry())
	var expected := {"HIGH": 4, "MEDIUM": 2, "LOW": 2}
	var matches := plan_result.success and policy_result.success
	for level in expected:
		var filtered: VfxResult = VfxPreviewLodFilterModel.new().filter(plan_result.value, level, policy_result.value) if matches else VfxResult.failure([])
		var loop_plan: RefCounted = filtered.value.phase_named("loop") if filtered.success else null
		matches = matches and loop_plan != null and loop_plan.layer_specs().size() == expected[level]
	tests.expect_true(matches, "Rotor Lift LOOP keeps 4 layers at HIGH and only the two CORE ring emitters at MEDIUM and LOW")


static func _data() -> Dictionary:
	var document := VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/equipment.rotor_lift.downwash.vfx.json")
	return document.value.normalized_data if document.success else {}


static func _runtime(plan: RefCounted) -> RefCounted:
	return VfxPreviewRenderRuntimeModel.new(plan, {"anchors": {"CENTER": [0.0, 0.0]}}, _registry(), VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()))


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _ids(layers: Variant) -> Array:
	var result: Array = []
	if not layers is Array:
		return result
	for layer in layers:
		if layer is Dictionary:
			result.append(str(layer.get("id", "")))
	return result


static func _packet_by_layer(packets: Array, layer_id: String) -> Dictionary:
	for packet in packets:
		if packet is Dictionary and packet.get("layer_id") == layer_id:
			return packet
	return {}


static func _vector(value: Variant) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.INF


static func _packets(packets: Array, layer_id: String) -> Array:
	return packets.filter(func(packet: Variant) -> bool: return packet is Dictionary and packet.get("layer_id") == layer_id)
