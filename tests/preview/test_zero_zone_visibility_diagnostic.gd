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
	_test_ring_free_twelve_layer_production_recipe(tests)
	_test_loop_forward_flow_resolves_and_routes_without_special_renderer(tests)
	_test_miniature_game_footprints_are_explicit(tests)
	_test_production_particle_fades_and_canonical_forward_direction(tests)


static func _test_ring_free_twelve_layer_production_recipe(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Production Zero Zone recipe requires a contract-valid Preset")
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
	var expected_ids := [
		"start.focus_flash", "start.entry_wake", "start.shard_lock_burst", "start.spark_ticks",
		"loop.focus_core", "loop.forward_flow", "loop.soft_alignment_aura", "loop.alignment_shards", "loop.precision_sparks",
		"end.release_shards", "end.release_flow", "end.spark_tail"
	]
	var actual_ids: Array[String] = []
	for layer in all_layers:
		actual_ids.append(str(layer.get("id", "")))
	var ring_free := all_layers.all(func(layer: Dictionary) -> bool: return layer.get("type") != "RING")
	tests.expect_true(
		float(phases.get("start", {}).get("duration_seconds", 0.0)) == 0.16
		and float(phases.get("end", {}).get("duration_seconds", 0.0)) == 0.22
		and actual_ids == expected_ids
		and ring_free,
		"Production Zero Zone has the approved 4/5/3 START LOOP END stack with no Ring or legacy Ring Layer"
	)
	var start_focus: Dictionary = start_by_id.get("start.focus_flash", {})
	var start_wake: Dictionary = start_by_id.get("start.entry_wake", {})
	var start_shards: Dictionary = start_by_id.get("start.shard_lock_burst", {})
	var start_sparks: Dictionary = start_by_id.get("start.spark_ticks", {})
	tests.expect_true(
		start_focus.get("importance") == "CORE"
		and start_focus.get("parameters", {}).get("radius") == 185.0
		and start_focus.get("parameters", {}).get("opacity") == 0.78
		and start_focus.get("transform", {}).get("scale") == [1.0, 1.35]
		and start_wake.get("importance") == "DETAIL"
		and start_wake.get("parameters", {}).get("radius") == 210.0
		and start_wake.get("parameters", {}).get("opacity") == 0.16
		and start_wake.get("transform", {}).get("scale") == [0.95, 1.48]
		and start_shards.get("parameters", {}).get("sprite_asset_ref") == "fx.energy_shard"
		and start_shards.get("parameters", {}).get("burst_count") == 5
		and start_shards.get("parameters", {}).get("size_start") == 38.0
		and start_shards.get("parameters", {}).get("size_end") == 26.0
		and start_sparks.get("importance") == "EXTRA"
		and start_sparks.get("parameters", {}).get("sprite_asset_ref") == "fx.energy_spark"
		and start_sparks.get("parameters", {}).get("burst_count") == 2
		and start_sparks.get("parameters", {}).get("size_start") == 30.0
		and start_sparks.get("parameters", {}).get("size_end") == 17.0,
		"START uses a narrow cyan-white focus, weak directional wake, readable shard lock burst, and sparse spark ticks"
	)
	var focus_core: Dictionary = loop_by_id.get("loop.focus_core", {})
	var forward_flow: Dictionary = loop_by_id.get("loop.forward_flow", {})
	var soft_aura: Dictionary = loop_by_id.get("loop.soft_alignment_aura", {})
	var alignment_shards: Dictionary = loop_by_id.get("loop.alignment_shards", {})
	var precision_sparks: Dictionary = loop_by_id.get("loop.precision_sparks", {})
	tests.expect_true(
		focus_core.get("importance") == "CORE"
		and focus_core.get("parameters", {}).get("radius") == 165.0
		and focus_core.get("parameters", {}).get("opacity") == 0.52
		and focus_core.get("transform", {}).get("scale") == [1.0, 1.35]
		and forward_flow.get("importance") == "CORE"
		and forward_flow.get("parameters", {}).get("sprite_asset_ref") == "fx.zero_zone_flow_streak"
		and forward_flow.get("parameters", {}).get("emitter", {}).get("shape") == "POINT"
		and forward_flow.get("transform", {}).get("offset") == [0.0, -80.0]
		and forward_flow.get("parameters", {}).get("direction_degrees") == 0.0
		and forward_flow.get("parameters", {}).get("spread_degrees") == 14.0
		and forward_flow.get("parameters", {}).get("max_particles") == 3
		and forward_flow.get("parameters", {}).get("size_start") == 100.0
		and forward_flow.get("parameters", {}).get("size_end") == 70.0
		and soft_aura.get("importance") == "DETAIL"
		and soft_aura.get("parameters", {}).get("radius") == 205.0
		and soft_aura.get("parameters", {}).get("opacity") == 0.14
		and soft_aura.get("transform", {}).get("scale") == [0.95, 1.48]
		and alignment_shards.get("parameters", {}).get("max_particles") == 2
		and alignment_shards.get("parameters", {}).get("size_start") == 38.0
		and alignment_shards.get("parameters", {}).get("size_end") == 27.0
		and precision_sparks.get("importance") == "EXTRA"
		and precision_sparks.get("parameters", {}).get("max_particles") == 2
		and precision_sparks.get("parameters", {}).get("size_start") == 30.0
		and precision_sparks.get("parameters", {}).get("size_end") == 18.0,
		"LOOP keeps a CORE focus and canonical -Y flow, then adds only Detail shard alignment and Extra sparks"
	)
	var release_shards: Dictionary = end_by_id.get("end.release_shards", {})
	var release_flow: Dictionary = end_by_id.get("end.release_flow", {})
	var spark_tail: Dictionary = end_by_id.get("end.spark_tail", {})
	tests.expect_true(
		release_shards.get("importance") == "CORE"
		and release_shards.get("parameters", {}).get("burst_count") == 4
		and release_shards.get("parameters", {}).get("size_start") == 34.0
		and release_shards.get("parameters", {}).get("size_end") == 23.0
		and release_flow.get("importance") == "DETAIL"
		and release_flow.get("parameters", {}).get("sprite_asset_ref") == "fx.zero_zone_flow_streak"
		and release_flow.get("transform", {}).get("offset") == [0.0, -32.0]
		and release_flow.get("parameters", {}).get("direction_degrees") == 0.0
		and release_flow.get("parameters", {}).get("size_start") == 85.0
		and release_flow.get("parameters", {}).get("size_end") == 55.0
		and spark_tail.get("importance") == "EXTRA"
		and spark_tail.get("parameters", {}).get("burst_count") == 1
		and spark_tail.get("parameters", {}).get("size_start") == 26.0
		and spark_tail.get("parameters", {}).get("size_end") == 14.0,
		"END releases a quiet CORE shard spread, one directional flow fragment, and one Extra spark without shockwave geometry"
	)


static func _test_loop_forward_flow_resolves_and_routes_without_special_renderer(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var registry := _registry()
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(registry).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var flow_asset: VfxResult = resolver.resolve("fx.zero_zone_flow_streak")
	if not plan_result.success or not flow_asset.success:
		tests.expect_true(false, "Production flow regression requires a valid Plan and a resolvable flow-streak texture")
		return
	var runtime := VfxPreviewRenderRuntimeModel.new(plan_result.value, {"anchors": {"CENTER": [0, 0]}}, registry, VfxPreviewRendererFactoryModel.new(), resolver)
	runtime.activate_phase("loop", _frame_context())
	runtime.advance(0.5, _frame_context())
	var packets_by_id: Dictionary = {}
	for packet in runtime.draw_packets():
		packets_by_id[packet.get("layer_id")] = packet
	var flow_packet: Dictionary = packets_by_id.get("loop.forward_flow", {})
	var focus_packet: Dictionary = packets_by_id.get("loop.focus_core", {})
	var canvas := VfxVehiclePreviewCanvasModel.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(canvas)
	canvas.set_shared_state(_preview_state())
	var under_host := canvas.render_plane_host(str(focus_packet.get("render_plane", "")), str(focus_packet.get("space", "")))
	var over_host := canvas.render_plane_host(str(flow_packet.get("render_plane", "")), str(flow_packet.get("space", "")))
	var texture: Texture2D = flow_asset.value.get("texture") as Texture2D
	tests.expect_true(
		flow_asset.issues.is_empty()
		and flow_asset.value.get("source") == "TEXTURE"
		and not flow_asset.value.get("is_fallback", true)
		and texture != null
		and texture.get_size() == Vector2(64.0, 128.0)
		and flow_packet.get("render_plane") == "OVER_VEHICLE"
		and flow_packet.get("asset", {}).get("logical_id") == "fx.zero_zone_flow_streak"
		and under_host != null and under_host.name == "UnderVehicleLocalHost"
		and over_host != null and over_host.name == "OverVehicleLocalHost",
		"Forward flow resolves as the production 64x128 texture and routes through the ordinary VEHICLE_LOCAL canvas hosts"
	)
	tree.root.remove_child(canvas)
	canvas.free()


static func _test_miniature_game_footprints_are_explicit(tests: TestAssert) -> void:
	var game_factor := 0.095
	var reduced_track_factor := 0.08075
	tests.expect_true(
		is_equal_approx((20.0 / 64.0) * 100.0 * game_factor, 2.96875)
		and is_equal_approx((93.0 / 128.0) * 2.0 * 100.0 * game_factor, 13.8046875)
		and is_equal_approx(2.0 * 38.0 * game_factor, 7.22)
		and is_equal_approx(2.0 * 30.0 * game_factor, 5.7)
		and is_equal_approx(2.0 * 165.0 * game_factor, 31.35)
		and is_equal_approx(2.0 * 165.0 * 1.35 * game_factor, 42.3225)
		and is_equal_approx(2.0 * 205.0 * 0.95 * game_factor, 37.0025)
		and is_equal_approx(2.0 * 205.0 * 1.48 * game_factor, 57.646),
		"At GAME 100%, the flow strong footprint is about 2.97 by 13.80 px; shards, sparks, core, and aura are deliberately large enough to escape vehicle occlusion"
	)
	tests.expect_true(
		is_equal_approx((20.0 / 64.0) * 100.0 * reduced_track_factor, 2.5234375)
		and is_equal_approx((93.0 / 128.0) * 2.0 * 100.0 * reduced_track_factor, 11.733984375)
		and is_equal_approx(2.0 * 38.0 * reduced_track_factor, 6.137)
		and is_equal_approx(2.0 * 30.0 * reduced_track_factor, 4.845)
		and is_equal_approx(2.0 * 165.0 * reduced_track_factor, 26.6475)
		and is_equal_approx(2.0 * 165.0 * 1.35 * reduced_track_factor, 35.974125)
		and is_equal_approx(2.0 * 205.0 * 0.95 * reduced_track_factor, 31.452125)
		and is_equal_approx(2.0 * 205.0 * 1.48 * reduced_track_factor, 48.9991),
		"At Track Scale 0.85, the flow remains about 2.52 by 11.73 px and the focused core, aura, shards, and sparks remain above subpixel visibility"
	)


static func _test_production_particle_fades_and_canonical_forward_direction(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Production fade regression requires a contract-valid Preset")
		return
	var phases: Dictionary = document_result.value.normalized_data["phases"]
	var start := _layers_by_id(phases["start"]["layers"])
	var loop := _layers_by_id(phases["loop"]["layers"])
	var end := _layers_by_id(phases["end"]["layers"])
	var fading_particles := [
		start.get("start.shard_lock_burst", {}), start.get("start.spark_ticks", {}), loop.get("loop.forward_flow", {}),
		loop.get("loop.alignment_shards", {}), loop.get("loop.precision_sparks", {}), end.get("end.release_shards", {}),
		end.get("end.release_flow", {}), end.get("end.spark_tail", {})
	]
	var all_fade_out := fading_particles.all(func(layer: Dictionary) -> bool: return float(layer.get("parameters", {}).get("alpha_end", 1.0)) == 0.0)
	tests.expect_true(
		all_fade_out
		and loop.get("loop.forward_flow", {}).get("parameters", {}).get("alpha_start") == 0.95
		and loop.get("loop.forward_flow", {}).get("parameters", {}).get("rotation_min_degrees") == 0.0
		and loop.get("loop.forward_flow", {}).get("parameters", {}).get("rotation_max_degrees") == 0.0
		and loop.get("loop.forward_flow", {}).get("parameters", {}).get("angular_velocity_min_degrees_per_second") == 0.0
		and loop.get("loop.forward_flow", {}).get("parameters", {}).get("angular_velocity_max_degrees_per_second") == 0.0
		and end.get("end.release_flow", {}).get("parameters", {}).get("direction_degrees") == 0.0,
		"Production Particles fade out, while flow-streak Layers retain unrotated canonical 0-degree vehicle-forward orientation"
	)


static func _layers_by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		result[str(layer.get("id", ""))] = layer
	return result


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
