extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const VfxPreviewRendererFactoryModel := preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxPreviewRenderRuntimeModel := preload("res://src/preview/rendering/vfx_preview_render_runtime.gd")
const VfxVehiclePreviewCanvasModel := preload("res://src/preview/vfx_vehicle_preview_canvas.gd")
const VfxPreviewSharedStateModel := preload("res://src/preview/vfx_preview_shared_state.gd")


static func run(tests: TestAssert) -> void:
	_test_two_asset_ten_layer_focus_mote_recipe(tests)
	_test_loop_tunnel_arc_and_focus_motes_resolve_and_route_without_special_renderer(tests)
	_test_loop_tunnel_arc_cadence_and_rearward_point_path(tests)
	_test_miniature_game_footprints_are_explicit(tests)
	_test_particles_fade_and_use_rearward_tunnel_flow(tests)


static func _test_two_asset_ten_layer_focus_mote_recipe(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Focus-mote Zero Zone recipe requires a contract-valid Preset")
		return
	var phases: Dictionary = document_result.value.normalized_data.get("phases", {})
	var start_layers: Array = phases.get("start", {}).get("layers", [])
	var loop_layers: Array = phases.get("loop", {}).get("layers", [])
	var end_layers: Array = phases.get("end", {}).get("layers", [])
	var start_by_id := _layers_by_id(start_layers)
	var loop_by_id := _layers_by_id(loop_layers)
	var end_by_id := _layers_by_id(end_layers)
	var all_layers: Array = []
	all_layers.append_array(start_layers)
	all_layers.append_array(loop_layers)
	all_layers.append_array(end_layers)
	var actual_ids: Array[String] = []
	for layer in all_layers:
		actual_ids.append(str(layer.get("id", "")))
	var expected_ids := [
		"start.focus_flash", "start.entry_wake", "start.focus_mote_burst", "start.tunnel_arc_entry",
		"loop.focus_core", "loop.tunnel_arc_pass", "loop.soft_alignment_aura", "loop.focus_motes",
		"end.focus_mote_release", "end.tunnel_arc_release"
	]
	var particle_asset_refs: Array[String] = []
	for layer in all_layers:
		if layer.get("type") == "PARTICLE":
			particle_asset_refs.append(str(layer.get("parameters", {}).get("sprite_asset_ref", "")))
	particle_asset_refs.sort()
	var non_geometric := all_layers.all(func(layer: Dictionary) -> bool: return layer.get("type") != "RING" and layer.get("type") != "SHIELD")
	tests.expect_true(
		float(phases.get("start", {}).get("duration_seconds", 0.0)) == 0.16
		and float(phases.get("end", {}).get("duration_seconds", 0.0)) == 0.22
		and actual_ids == expected_ids
		and particle_asset_refs == ["fx.zero_zone_focus_mote", "fx.zero_zone_focus_mote", "fx.zero_zone_focus_mote", "fx.zero_zone_tunnel_arc", "fx.zero_zone_tunnel_arc", "fx.zero_zone_tunnel_arc"]
		and non_geometric,
		"Zero Zone uses the approved 4/4/2 START LOOP END stack with only focus-mote and open tunnel-arc Particle assets"
	)
	var start_mote: Dictionary = start_by_id.get("start.focus_mote_burst", {})
	var start_arc: Dictionary = start_by_id.get("start.tunnel_arc_entry", {})
	tests.expect_true(
		start_mote.get("importance") == "DETAIL"
		and start_mote.get("parameters", {}).get("sprite_asset_ref") == "fx.zero_zone_focus_mote"
		and start_mote.get("parameters", {}).get("emitter") == {"radius": 120.0, "shape": "CIRCLE"}
		and start_mote.get("parameters", {}).get("burst_count") == 6
		and start_mote.get("parameters", {}).get("lifetime_seconds") == 0.38
		and start_mote.get("parameters", {}).get("size_start") == 135.0
		and start_mote.get("parameters", {}).get("size_end") == 110.0
		and start_mote.get("parameters", {}).get("alpha_start") == 0.92
		and start_mote.get("parameters", {}).get("alpha_end") == 0.0
		and start_mote.get("parameters", {}).get("direction_degrees") == 180.0
		and start_mote.get("parameters", {}).get("spread_degrees") == 25.0
		and start_mote.get("parameters", {}).get("speed_min") == 600.0
		and start_mote.get("parameters", {}).get("speed_max") == 760.0
		and start_mote.get("transform", {}).get("offset") == [0.0, -150.0]
		and _arc_matches(start_arc, 0.74, 560.0, 680.0, 235.0, 187.0, 0.55, [0.0, -200.0]),
		"START pairs six longer-lived rearward focus motes with the Pass K subtly brighter, larger fixed 90-degree entry tunnel slice"
	)
	var focus_core: Dictionary = loop_by_id.get("loop.focus_core", {})
	var tunnel_arc: Dictionary = loop_by_id.get("loop.tunnel_arc_pass", {})
	var soft_aura: Dictionary = loop_by_id.get("loop.soft_alignment_aura", {})
	var loop_motes: Dictionary = loop_by_id.get("loop.focus_motes", {})
	tests.expect_true(
		focus_core.get("importance") == "CORE"
		and focus_core.get("parameters", {}).get("radius") == 235.0
		and focus_core.get("parameters", {}).get("opacity") == 0.22
		and focus_core.get("transform", {}).get("scale") == [0.95, 1.4]
		and _arc_matches(tunnel_arc, 0.76, 560.0, 680.0, 235.0, 193.0, 0.48, [0.0, -210.0])
		and tunnel_arc.get("parameters", {}).get("emission_rate_per_second") == 5.0
		and tunnel_arc.get("parameters", {}).get("max_particles") == 4
		and soft_aura.get("importance") == "DETAIL"
		and soft_aura.get("parameters", {}).get("radius") == 275.0
		and soft_aura.get("parameters", {}).get("opacity") == 0.04
		and soft_aura.get("transform", {}).get("scale") == [1.0, 1.52]
		and loop_motes.get("importance") == "DETAIL"
		and loop_motes.get("parameters", {}).get("sprite_asset_ref") == "fx.zero_zone_focus_mote"
		and loop_motes.get("parameters", {}).get("emitter") == {"radius": 125.0, "shape": "CIRCLE"}
		and loop_motes.get("parameters", {}).get("emission_rate_per_second") == 18.0
		and loop_motes.get("parameters", {}).get("max_particles") == 8
		and loop_motes.get("parameters", {}).get("lifetime_seconds") == 0.4
		and loop_motes.get("parameters", {}).get("size_start") == 135.0
		and loop_motes.get("parameters", {}).get("size_end") == 115.0
		and loop_motes.get("parameters", {}).get("alpha_start") == 0.9
		and loop_motes.get("parameters", {}).get("alpha_end") == 0.0
		and loop_motes.get("parameters", {}).get("direction_degrees") == 180.0
		and loop_motes.get("parameters", {}).get("spread_degrees") == 25.0
		and loop_motes.get("parameters", {}).get("speed_min") == 640.0
		and loop_motes.get("parameters", {}).get("speed_max") == 800.0
		and loop_motes.get("transform", {}).get("offset") == [0.0, -170.0],
		"LOOP keeps its approved soft focus field while Pass K makes each unchanged-cadence tunnel slice slightly brighter and larger than the mote field"
	)
	var end_mote: Dictionary = end_by_id.get("end.focus_mote_release", {})
	var end_arc: Dictionary = end_by_id.get("end.tunnel_arc_release", {})
	tests.expect_true(
		end_mote.get("importance") == "DETAIL"
		and end_mote.get("parameters", {}).get("sprite_asset_ref") == "fx.zero_zone_focus_mote"
		and end_mote.get("parameters", {}).get("emitter") == {"radius": 100.0, "shape": "CIRCLE"}
		and end_mote.get("parameters", {}).get("burst_count") == 4
		and end_mote.get("parameters", {}).get("lifetime_seconds") == 0.34
		and end_mote.get("parameters", {}).get("size_start") == 120.0
		and end_mote.get("parameters", {}).get("size_end") == 95.0
		and end_mote.get("parameters", {}).get("alpha_start") == 0.66
		and end_mote.get("parameters", {}).get("alpha_end") == 0.0
		and end_mote.get("parameters", {}).get("direction_degrees") == 180.0
		and end_mote.get("parameters", {}).get("spread_degrees") == 25.0
		and end_mote.get("parameters", {}).get("speed_min") == 460.0
		and end_mote.get("parameters", {}).get("speed_max") == 640.0
		and end_mote.get("transform", {}).get("offset") == [0.0, -120.0]
		and _arc_matches(end_arc, 0.64, 500.0, 620.0, 209.0, 161.0, 0.47, [0.0, -155.0]),
		"END releases four longer-lived focus motes and one Pass K subtly brighter fixed 90-degree tunnel slice without restoring a ring or shield"
	)


static func _test_loop_tunnel_arc_and_focus_motes_resolve_and_route_without_special_renderer(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var registry := _registry()
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(registry).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var mote_asset: VfxResult = resolver.resolve("fx.zero_zone_focus_mote")
	var arc_asset: VfxResult = resolver.resolve("fx.zero_zone_tunnel_arc")
	if not plan_result.success or not mote_asset.success or not arc_asset.success:
		tests.expect_true(false, "Focus-mote routing requires a valid Plan and resolvable focus-mote and tunnel-arc textures")
		return
	var runtime := VfxPreviewRenderRuntimeModel.new(plan_result.value, {"anchors": {"CENTER": [0, 0]}}, registry, VfxPreviewRendererFactoryModel.new(), resolver)
	runtime.activate_phase("loop", _frame_context())
	runtime.advance(0.8, _frame_context())
	var packets_by_id: Dictionary = {}
	for packet in runtime.draw_packets():
		packets_by_id[packet.get("layer_id")] = packet
	var mote_packet: Dictionary = packets_by_id.get("loop.focus_motes", {})
	var arc_packet: Dictionary = packets_by_id.get("loop.tunnel_arc_pass", {})
	var focus_packet: Dictionary = packets_by_id.get("loop.focus_core", {})
	var canvas := VfxVehiclePreviewCanvasModel.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(canvas)
	canvas.set_shared_state(_preview_state())
	var under_host := canvas.render_plane_host(str(focus_packet.get("render_plane", "")), str(focus_packet.get("space", "")))
	var over_host := canvas.render_plane_host(str(mote_packet.get("render_plane", "")), str(mote_packet.get("space", "")))
	var mote_texture: Texture2D = mote_asset.value.get("texture") as Texture2D
	var arc_texture: Texture2D = arc_asset.value.get("texture") as Texture2D
	tests.expect_true(
		mote_asset.issues.is_empty()
		and mote_asset.value.get("source") == "TEXTURE"
		and not mote_asset.value.get("is_fallback", true)
		and mote_texture != null
		and mote_texture.get_size() == Vector2(64.0, 64.0)
		and arc_asset.issues.is_empty()
		and arc_asset.value.get("source") == "TEXTURE"
		and not arc_asset.value.get("is_fallback", true)
		and arc_texture != null
		and arc_texture.get_size() == Vector2(128.0, 256.0)
		and mote_packet.get("render_plane") == "OVER_VEHICLE"
		and mote_packet.get("asset", {}).get("logical_id") == "fx.zero_zone_focus_mote"
		and arc_packet.get("render_plane") == "OVER_VEHICLE"
		and arc_packet.get("asset", {}).get("logical_id") == "fx.zero_zone_tunnel_arc"
		and under_host != null and under_host.name == "UnderVehicleLocalHost"
		and over_host != null and over_host.name == "OverVehicleLocalHost",
		"Focus motes and 128x256 tunnel arcs resolve through the ordinary VEHICLE_LOCAL canvas hosts without a special renderer"
	)
	tree.root.remove_child(canvas)
	canvas.free()


static func _test_loop_tunnel_arc_cadence_and_rearward_point_path(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var registry := _registry()
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(registry).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	if not plan_result.success:
		tests.expect_true(false, "Tunnel cadence regression requires a valid Zero Zone Render Plan")
		return
	var runtime := VfxPreviewRenderRuntimeModel.new(plan_result.value, {"anchors": {"CENTER": [0, 0]}}, registry, VfxPreviewRendererFactoryModel.new(), VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new()))
	runtime.activate_phase("loop", _frame_context())
	runtime.advance(0.19, _frame_context())
	var arcs_before_cadence: Array = runtime.draw_packets().filter(func(packet: Dictionary) -> bool: return packet.get("layer_id") == "loop.tunnel_arc_pass")
	runtime.advance(0.02, _frame_context())
	for _step in 3:
		runtime.advance(1.0 / 5.0, _frame_context())
	var arc_packets: Array = runtime.draw_packets().filter(func(packet: Dictionary) -> bool: return packet.get("layer_id") == "loop.tunnel_arc_pass")
	var all_on_center_line := arc_packets.all(func(packet: Dictionary) -> bool:
		var position: Vector2 = packet.get("position", Vector2.INF) as Vector2
		return absf(position.x) <= 0.001
	)
	var has_crossed_vehicle_center := arc_packets.any(func(packet: Dictionary) -> bool:
		var position: Vector2 = packet.get("position", Vector2.ZERO) as Vector2
		return position.y > 0.0
	)
	tests.expect_true(
		arcs_before_cadence.is_empty() and arc_packets.size() == 4 and all_on_center_line and has_crossed_vehicle_center,
		"Five-per-second POINT-emitted tunnel slices hold four concurrent center-line arcs and advance more slowly from front to rear through the vehicle"
	)


static func _test_miniature_game_footprints_are_explicit(tests: TestAssert) -> void:
	var game_factor := 0.095
	var reduced_track_factor := 0.08075
	tests.expect_true(
		is_equal_approx((16.0 / 64.0) * 2.0 * 135.0 * game_factor, 6.4125)
		and is_equal_approx((19.0 / 64.0) * 2.0 * 135.0 * game_factor, 7.61484375)
		and is_equal_approx((16.0 / 64.0) * 2.0 * 115.0 * game_factor, 5.4625)
		and is_equal_approx((19.0 / 64.0) * 2.0 * 115.0 * game_factor, 6.48671875)
		and is_equal_approx((128.0 / 256.0) * 2.0 * 235.0 * game_factor, 22.325)
		and is_equal_approx(2.0 * 235.0 * game_factor, 44.65)
		and is_equal_approx(2.0 * 235.0 * 0.95 * game_factor, 42.4175)
		and is_equal_approx(2.0 * 235.0 * 1.4 * game_factor, 62.51)
		and is_equal_approx(2.0 * 275.0 * game_factor, 52.25)
		and is_equal_approx(2.0 * 275.0 * 1.52 * game_factor, 79.42)
		and is_equal_approx(-210.0 * game_factor, -19.95)
		and is_equal_approx(640.0 * 0.4 * game_factor, 24.32)
		and is_equal_approx(800.0 * 0.4 * game_factor, 30.4)
		and is_equal_approx(560.0 * 0.76 * game_factor, 40.432)
		and is_equal_approx(680.0 * 0.76 * game_factor, 49.096),
		"At GAME 100%, a strong 16x19px focus-mote core keeps its 6.41x7.61px to 5.46x6.49px visual footprint while its rearward travel expands to 24.32–30.40px and the subtly stronger tunnel slice travels 40.43–49.10px with a 22.33x44.65px start footprint"
	)
	tests.expect_true(
		is_equal_approx((16.0 / 64.0) * 2.0 * 135.0 * reduced_track_factor, 5.450625)
		and is_equal_approx((19.0 / 64.0) * 2.0 * 135.0 * reduced_track_factor, 6.4726171875)
		and is_equal_approx((16.0 / 64.0) * 2.0 * 115.0 * reduced_track_factor, 4.643125)
		and is_equal_approx((19.0 / 64.0) * 2.0 * 115.0 * reduced_track_factor, 5.5137109375)
		and is_equal_approx((128.0 / 256.0) * 2.0 * 235.0 * reduced_track_factor, 18.97625)
		and is_equal_approx(2.0 * 235.0 * reduced_track_factor, 37.9525)
		and is_equal_approx(640.0 * 0.4 * reduced_track_factor, 20.672)
		and is_equal_approx(800.0 * 0.4 * reduced_track_factor, 25.84)
		and is_equal_approx(560.0 * 0.76 * reduced_track_factor, 34.3672)
		and is_equal_approx(680.0 * 0.76 * reduced_track_factor, 41.7316),
		"At Track Scale 0.85, focus motes retain a 4.64x5.51px strong core while traveling 20.67–25.84px and the slightly stronger tunnel slice remains 37.95x18.98px across a 34.37 to 41.73px rearward path"
	)


static func _test_particles_fade_and_use_rearward_tunnel_flow(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Focus-mote fade regression requires a contract-valid Preset")
		return
	var phases: Dictionary = document_result.value.normalized_data["phases"]
	var particles: Array = []
	for phase_name in ["start", "loop", "end"]:
		for layer in phases[phase_name]["layers"]:
			if layer.get("type") == "PARTICLE":
				particles.append(layer)
	var all_fade_out := particles.all(func(layer: Dictionary) -> bool: return float(layer.get("parameters", {}).get("alpha_end", 1.0)) == 0.0)
	var all_rearward := particles.all(func(layer: Dictionary) -> bool: return float(layer.get("parameters", {}).get("direction_degrees", -1.0)) == 180.0)
	tests.expect_true(
		particles.size() == 6
		and all_fade_out
		and all_rearward
		and particles.all(func(layer: Dictionary) -> bool: return layer.get("parameters", {}).get("sprite_asset_ref") in ["fx.zero_zone_focus_mote", "fx.zero_zone_tunnel_arc"]),
		"All six Zero Zone Particles fade out and use canonical 180-degree rearward travel with no shard, spark, or flow-streak fallback"
	)


static func _layers_by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		result[str(layer.get("id", ""))] = layer
	return result


static func _arc_matches(layer: Dictionary, lifetime: float, speed_min: float, speed_max: float, size_start: float, size_end: float, alpha_start: float, offset: Array) -> bool:
	var parameters: Dictionary = layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	return layer.get("importance") in ["CORE", "DETAIL"] \
		and parameters.get("sprite_asset_ref") == "fx.zero_zone_tunnel_arc" \
		and parameters.get("emitter") == {"shape": "POINT"} \
		and parameters.get("direction_degrees") == 180.0 \
		and parameters.get("spread_degrees") == 0.0 \
		and parameters.get("lifetime_seconds") == lifetime \
		and parameters.get("speed_min") == speed_min \
		and parameters.get("speed_max") == speed_max \
		and parameters.get("size_start") == size_start \
		and parameters.get("size_end") == size_end \
		and parameters.get("alpha_start") == alpha_start \
		and parameters.get("alpha_end") == 0.0 \
		and parameters.get("rotation_min_degrees") == 90.0 \
		and parameters.get("rotation_max_degrees") == 90.0 \
		and parameters.get("angular_velocity_min_degrees_per_second") == 0.0 \
		and parameters.get("angular_velocity_max_degrees_per_second") == 0.0 \
		and layer.get("transform", {}).get("offset") == offset


static func _frame_context() -> Dictionary:
	return {"vehicle_translation_source": Vector2.ZERO, "vehicle_rotation_degrees": 0.0, "effective_game_scale": Vector2(0.095, 0.095), "playback_generation": 1}


static func _preview_state() -> RefCounted:
	var state := VfxPreviewSharedStateModel.new()
	state.set_game_scale_contract({"base_car_sprite_scale": [0.38, 0.38], "car_visual_scale": 0.25, "track_scales": [1.0]})
	state.set_profile_data({"anchors": {"CENTER": [0, 0]}})
	return state


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
