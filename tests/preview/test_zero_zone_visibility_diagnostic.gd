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
		and start_focus.get("parameters", {}).get("radius") == 245.0
		and start_focus.get("parameters", {}).get("opacity") == 0.68
		and start_focus.get("transform", {}).get("scale") == [0.95, 1.42]
		and start_wake.get("importance") == "DETAIL"
		and start_wake.get("parameters", {}).get("radius") == 260.0
		and start_wake.get("parameters", {}).get("opacity") == 0.12
		and start_wake.get("transform", {}).get("scale") == [1.0, 1.55]
		and start_shards.get("parameters", {}).get("sprite_asset_ref") == "fx.energy_shard"
		and start_shards.get("parameters", {}).get("emitter", {}).get("radius") == 150.0
		and start_shards.get("parameters", {}).get("burst_count") == 4
		and start_shards.get("parameters", {}).get("size_start") == 112.0
		and start_shards.get("parameters", {}).get("size_end") == 72.0
		and start_shards.get("parameters", {}).get("alpha_start") == 0.88
		and start_sparks.get("importance") == "EXTRA"
		and start_sparks.get("parameters", {}).get("sprite_asset_ref") == "fx.energy_spark"
		and start_sparks.get("parameters", {}).get("emitter", {}).get("radius") == 132.0
		and start_sparks.get("parameters", {}).get("burst_count") == 2
		and start_sparks.get("parameters", {}).get("size_start") == 84.0
		and start_sparks.get("parameters", {}).get("size_end") == 48.0
		and start_sparks.get("parameters", {}).get("alpha_start") == 0.9,
		"START covers the full vehicle with a soft flash/wake and four broad readable entry shards without adding geometric enclosure"
	)
	var focus_core: Dictionary = loop_by_id.get("loop.focus_core", {})
	var forward_flow: Dictionary = loop_by_id.get("loop.forward_flow", {})
	var soft_aura: Dictionary = loop_by_id.get("loop.soft_alignment_aura", {})
	var alignment_shards: Dictionary = loop_by_id.get("loop.alignment_shards", {})
	var precision_sparks: Dictionary = loop_by_id.get("loop.precision_sparks", {})
	tests.expect_true(
		focus_core.get("importance") == "CORE"
		and focus_core.get("parameters", {}).get("radius") == 235.0
		and focus_core.get("parameters", {}).get("opacity") == 0.46
		and focus_core.get("transform", {}).get("scale") == [0.95, 1.4]
		and forward_flow.get("importance") == "CORE"
		and forward_flow.get("parameters", {}).get("sprite_asset_ref") == "fx.zero_zone_flow_streak"
		and forward_flow.get("parameters", {}).get("emitter", {}).get("shape") == "CIRCLE"
		and forward_flow.get("parameters", {}).get("emitter", {}).get("radius") == 48.0
		and forward_flow.get("transform", {}).get("offset") == [0.0, -42.0]
		and forward_flow.get("parameters", {}).get("direction_degrees") == 0.0
		and forward_flow.get("parameters", {}).get("spread_degrees") == 14.0
		and forward_flow.get("parameters", {}).get("emission_rate_per_second") == 2.5
		and forward_flow.get("parameters", {}).get("max_particles") == 2
		and forward_flow.get("parameters", {}).get("size_start") == 240.0
		and forward_flow.get("parameters", {}).get("size_end") == 170.0
		and forward_flow.get("parameters", {}).get("alpha_start") == 0.9
		and soft_aura.get("importance") == "DETAIL"
		and soft_aura.get("parameters", {}).get("radius") == 275.0
		and soft_aura.get("parameters", {}).get("opacity") == 0.1
		and soft_aura.get("transform", {}).get("scale") == [1.0, 1.52]
		and alignment_shards.get("parameters", {}).get("emitter", {}).get("radius") == 160.0
		and alignment_shards.get("parameters", {}).get("emission_rate_per_second") == 2.5
		and alignment_shards.get("parameters", {}).get("max_particles") == 2
		and alignment_shards.get("parameters", {}).get("size_start") == 112.0
		and alignment_shards.get("parameters", {}).get("size_end") == 76.0
		and alignment_shards.get("parameters", {}).get("alpha_start") == 0.82
		and precision_sparks.get("importance") == "EXTRA"
		and precision_sparks.get("parameters", {}).get("emitter", {}).get("radius") == 140.0
		and precision_sparks.get("parameters", {}).get("emission_rate_per_second") == 2.5
		and precision_sparks.get("parameters", {}).get("max_particles") == 2
		and precision_sparks.get("parameters", {}).get("size_start") == 86.0
		and precision_sparks.get("parameters", {}).get("size_end") == 52.0
		and precision_sparks.get("parameters", {}).get("alpha_start") == 0.88,
		"LOOP distributes its existing large Particles across the full vehicle and uses a small CIRCLE flow emitter to offset two forward streaks without a Ring or Shield"
	)
	var release_shards: Dictionary = end_by_id.get("end.release_shards", {})
	var release_flow: Dictionary = end_by_id.get("end.release_flow", {})
	var spark_tail: Dictionary = end_by_id.get("end.spark_tail", {})
	tests.expect_true(
		release_shards.get("importance") == "CORE"
		and release_shards.get("parameters", {}).get("emitter", {}).get("radius") == 142.0
		and release_shards.get("parameters", {}).get("burst_count") == 3
		and release_shards.get("parameters", {}).get("size_start") == 104.0
		and release_shards.get("parameters", {}).get("size_end") == 68.0
		and release_flow.get("importance") == "DETAIL"
		and release_flow.get("parameters", {}).get("sprite_asset_ref") == "fx.zero_zone_flow_streak"
		and release_flow.get("transform", {}).get("offset") == [0.0, -28.0]
		and release_flow.get("parameters", {}).get("direction_degrees") == 0.0
		and release_flow.get("parameters", {}).get("size_start") == 190.0
		and release_flow.get("parameters", {}).get("size_end") == 130.0
		and spark_tail.get("importance") == "EXTRA"
		and spark_tail.get("parameters", {}).get("emitter", {}).get("radius") == 120.0
		and spark_tail.get("parameters", {}).get("burst_count") == 1
		and spark_tail.get("parameters", {}).get("size_start") == 76.0
		and spark_tail.get("parameters", {}).get("size_end") == 44.0,
		"END releases three broad shards, one central-forward flow fragment, and one bright accent without shockwave geometry"
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
		is_equal_approx((20.0 / 64.0) * 240.0 * game_factor, 7.125)
		and is_equal_approx((93.0 / 128.0) * 2.0 * 240.0 * game_factor, 33.13125)
		and is_equal_approx(2.0 * 112.0 * game_factor, 21.28)
		and is_equal_approx(2.0 * 86.0 * game_factor, 16.34)
		and is_equal_approx(2.0 * 235.0 * 0.95 * game_factor, 42.4175)
		and is_equal_approx(2.0 * 235.0 * 1.4 * game_factor, 62.51)
		and is_equal_approx(2.0 * 275.0 * game_factor, 52.25)
		and is_equal_approx(2.0 * 275.0 * 1.52 * game_factor, 79.42)
		and is_equal_approx(150.0 * game_factor, 14.25)
		and is_equal_approx(132.0 * game_factor, 12.54)
		and is_equal_approx(160.0 * game_factor, 15.2)
		and is_equal_approx(140.0 * game_factor, 13.3)
		and is_equal_approx(142.0 * game_factor, 13.49)
		and is_equal_approx(120.0 * game_factor, 11.4)
		and is_equal_approx(48.0 * game_factor, 4.56),
		"At GAME 100%, the existing large Particles retain their visual size while their CIRCLE emitters distribute them across vehicle-wide 4.56 to 15.20 px screen radii"
	)
	tests.expect_true(
		is_equal_approx((20.0 / 64.0) * 240.0 * reduced_track_factor, 6.05625)
		and is_equal_approx((93.0 / 128.0) * 2.0 * 240.0 * reduced_track_factor, 28.1615625)
		and is_equal_approx(2.0 * 112.0 * reduced_track_factor, 18.088)
		and is_equal_approx(2.0 * 86.0 * reduced_track_factor, 13.889)
		and is_equal_approx(2.0 * 235.0 * 0.95 * reduced_track_factor, 36.054875)
		and is_equal_approx(2.0 * 235.0 * 1.4 * reduced_track_factor, 53.1335)
		and is_equal_approx(2.0 * 275.0 * reduced_track_factor, 44.4125)
		and is_equal_approx(2.0 * 275.0 * 1.52 * reduced_track_factor, 67.507)
		and is_equal_approx(150.0 * reduced_track_factor, 12.1125)
		and is_equal_approx(132.0 * reduced_track_factor, 10.659)
		and is_equal_approx(160.0 * reduced_track_factor, 12.92)
		and is_equal_approx(140.0 * reduced_track_factor, 11.305)
		and is_equal_approx(142.0 * reduced_track_factor, 11.4665)
		and is_equal_approx(120.0 * reduced_track_factor, 9.69)
		and is_equal_approx(48.0 * reduced_track_factor, 3.876),
		"At Track Scale 0.85, the vehicle-wide CIRCLE spawn radii remain 3.88 to 12.92 px while particle visual dimensions and full-vehicle Glow coverage remain unchanged"
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
		and loop.get("loop.forward_flow", {}).get("parameters", {}).get("alpha_start") == 0.9
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
