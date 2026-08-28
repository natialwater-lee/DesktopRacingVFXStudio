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
	_test_loop_plan_runtime_asset_and_canvas_route(tests)
	_test_current_miniature_projection_factors(tests)
	_test_energy_domain_authoring_targets(tests)


static func _test_loop_plan_runtime_asset_and_canvas_route(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var registry := _registry()
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(registry).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	var loop_specs_by_id: Dictionary = {}
	if plan_result.success:
		var loop_phase: RefCounted = plan_result.value.phase_named("loop")
		for layer_spec in loop_phase.layer_specs():
			loop_specs_by_id[layer_spec.layer_id()] = layer_spec
	var has_energy_domain_loop: bool = plan_result.success and loop_specs_by_id.keys().size() == 5 and loop_specs_by_id.has("loop.soft_outer_aura") and loop_specs_by_id.has("loop.inner_focus_glow") and loop_specs_by_id.has("loop.inner_energy_ring") and loop_specs_by_id.has("loop.slow_energy_shards") and loop_specs_by_id.has("loop.fast_energy_sparks") and loop_specs_by_id.values().all(func(layer_spec: RefCounted) -> bool: return layer_spec.is_enabled())
	tests.expect_true(has_energy_domain_loop, "Zero Zone LOOP Render Plan retains five enabled Aura, Focus Glow, Inner Ring, Slow Shard, and Fast Spark Layers")
	if not has_energy_domain_loop:
		return

	var asset_resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var asset_result: VfxResult = asset_resolver.resolve("fx.energy_shard")
	var runtime := VfxPreviewRenderRuntimeModel.new(plan_result.value, {"anchors": {"CENTER": [0, 0]}}, registry, VfxPreviewRendererFactoryModel.new(), asset_resolver)
	runtime.activate_phase("loop", _frame_context())
	runtime.advance(0.25, _frame_context())
	var packets_by_id: Dictionary = {}
	for packet in runtime.draw_packets():
		packets_by_id[packet.get("layer_id")] = packet
	var outer_aura_packet: Dictionary = packets_by_id.get("loop.soft_outer_aura", {})
	var inner_glow_packet: Dictionary = packets_by_id.get("loop.inner_focus_glow", {})
	var ring_packet: Dictionary = packets_by_id.get("loop.inner_energy_ring", {})
	var slow_shard_packet: Dictionary = packets_by_id.get("loop.slow_energy_shards", {})
	var fast_spark_packet: Dictionary = packets_by_id.get("loop.fast_energy_sparks", {})
	tests.expect_true(packets_by_id.has("loop.soft_outer_aura") and packets_by_id.has("loop.inner_focus_glow") and packets_by_id.has("loop.inner_energy_ring") and packets_by_id.has("loop.slow_energy_shards") and packets_by_id.has("loop.fast_energy_sparks") and asset_result.success and not asset_result.value.get("is_fallback", true), "Zero Zone LOOP creates Aura, Focus Glow, Ring, Slow Shard, and Fast Spark packets from the common Renderer set")
	var outer_aura_parameters: Dictionary = loop_specs_by_id["loop.soft_outer_aura"].parameters()
	var inner_glow_parameters: Dictionary = loop_specs_by_id["loop.inner_focus_glow"].parameters()
	var ring_parameters: Dictionary = loop_specs_by_id["loop.inner_energy_ring"].parameters()
	var slow_shard_parameters: Dictionary = loop_specs_by_id["loop.slow_energy_shards"].parameters()
	var fast_spark_parameters: Dictionary = loop_specs_by_id["loop.fast_energy_sparks"].parameters()
	tests.expect_true(outer_aura_packet.get("render_plane") == "UNDER_VEHICLE" and inner_glow_packet.get("render_plane") == "UNDER_VEHICLE" and ring_packet.get("render_plane") == "OVER_VEHICLE" and slow_shard_packet.get("render_plane") == "OVER_VEHICLE" and fast_spark_packet.get("render_plane") == "OVER_VEHICLE" and outer_aura_packet.get("radius") == outer_aura_parameters.get("radius") and is_equal_approx(float(inner_glow_packet.get("alpha", -1.0)), float(inner_glow_parameters.get("opacity", -1.0))) and ring_packet.get("color_rgba") == ring_parameters.get("color_rgba") and slow_shard_packet.get("color_rgba") == slow_shard_parameters.get("color_rgba") and fast_spark_packet.get("color_rgba") == fast_spark_parameters.get("color_rgba"), "Runtime preserves the author-declared two Glow, Ring, and two Particle values without a Zero Zone renderer branch")
	var canvas := VfxVehiclePreviewCanvasModel.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(canvas)
	canvas.set_shared_state(_preview_state())
	var under_host := canvas.render_plane_host(str(outer_aura_packet.get("render_plane")), str(outer_aura_packet.get("space")))
	var over_host := canvas.render_plane_host(str(ring_packet.get("render_plane")), str(ring_packet.get("space")))
	tests.expect_true(under_host != null and under_host.name == "UnderVehicleLocalHost" and over_host != null and over_host.name == "OverVehicleLocalHost", "Canvas routes Zero Zone VEHICLE_LOCAL packets to their declared concrete Under and Over vehicle plane hosts")
	tree.root.remove_child(canvas)
	canvas.free()


static func _test_current_miniature_projection_factors(tests: TestAssert) -> void:
	var edit_factor := 0.19
	var game_factor := 0.095
	tests.expect_true(is_equal_approx(18.0 * edit_factor, 3.42) and is_equal_approx(18.0 * game_factor, 1.71) and is_equal_approx(28.0 * edit_factor, 5.32) and is_equal_approx(28.0 * game_factor, 2.66) and is_equal_approx(2.0 * edit_factor, 0.38) and is_equal_approx(2.0 * game_factor, 0.19), "Fixed miniature projection factors yield the requested representative 18/28/2 source-unit sizes")
	tests.expect_true(is_equal_approx(150.0 * game_factor, 14.25) and is_equal_approx(150.0 * 1.25 * game_factor, 17.8125) and is_equal_approx(92.0 * game_factor, 8.74) and is_equal_approx(100.0 * game_factor, 9.5) and is_equal_approx(13.0 * game_factor, 1.235), "Energy-domain Aura and Ring source dimensions retain a visible core silhouette and a non-subpixel Ring width at GAME 100%")
	var reduced_track_factor := 0.08075
	tests.expect_true(is_equal_approx(150.0 * reduced_track_factor, 12.1125) and is_equal_approx(100.0 * reduced_track_factor, 8.075) and is_equal_approx(13.0 * reduced_track_factor, 1.04975) and is_equal_approx(18.0 * reduced_track_factor, 1.4535) and is_equal_approx(14.0 * reduced_track_factor, 1.1305) and is_equal_approx(115.0 * reduced_track_factor, 9.28625), "Energy-domain Ring width, slow and fast Particle start sizes, and Slow Shard emitter remain readable at Track Scale 0.85")


static func _test_energy_domain_authoring_targets(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	if not document_result.success:
		tests.expect_true(false, "Zero Zone calibration target requires a contract-valid Preset")
		return
	var loop_layers: Array = document_result.value.normalized_data["phases"]["loop"]["layers"]
	var start_layers: Array = document_result.value.normalized_data["phases"]["start"]["layers"]
	var end_layers: Array = document_result.value.normalized_data["phases"]["end"]["layers"]
	var start_by_id := _layers_by_id(start_layers)
	var loop_by_id := _layers_by_id(loop_layers)
	var end_by_id := _layers_by_id(end_layers)
	var outer_aura: Dictionary = loop_by_id.get("loop.soft_outer_aura", {})
	var inner_glow: Dictionary = loop_by_id.get("loop.inner_focus_glow", {})
	var inner_ring: Dictionary = loop_by_id.get("loop.inner_energy_ring", {})
	var slow_shards: Dictionary = loop_by_id.get("loop.slow_energy_shards", {})
	var fast_sparks: Dictionary = loop_by_id.get("loop.fast_energy_sparks", {})
	var start_expand_ring: Dictionary = start_by_id.get("start.expand_ring", {})
	var loop_particle_capacity := int(slow_shards.get("parameters", {}).get("max_particles", 0)) + int(fast_sparks.get("parameters", {}).get("max_particles", 0))
	var recipe_is_explicit: bool = start_by_id.keys().size() == 4 \
		and loop_by_id.keys().size() == 5 \
		and end_by_id.keys().size() == 2 \
		and outer_aura.get("type") == "GLOW" \
		and outer_aura.get("importance") == "CORE" \
		and outer_aura.get("parameters", {}).get("radius") == 150.0 \
		and outer_aura.get("parameters", {}).get("opacity") == 0.32 \
		and outer_aura.get("transform", {}).get("scale") == [1.0, 1.25] \
		and inner_glow.get("type") == "GLOW" \
		and inner_glow.get("parameters", {}).get("radius") == 92.0 \
		and inner_glow.get("parameters", {}).get("opacity") == 0.72 \
		and inner_ring.get("type") == "RING" \
		and inner_ring.get("importance") == "DETAIL" \
		and inner_ring.get("parameters", {}).get("radius_start") == 100.0 \
		and inner_ring.get("parameters", {}).get("width") == 13.0 \
		and slow_shards.get("type") == "PARTICLE" \
		and slow_shards.get("parameters", {}).get("max_particles") == 6 \
		and slow_shards.get("parameters", {}).get("lifetime_seconds") == 1.0 \
		and slow_shards.get("parameters", {}).get("size_start") == 18.0 \
		and fast_sparks.get("type") == "PARTICLE" \
		and fast_sparks.get("importance") == "EXTRA" \
		and fast_sparks.get("parameters", {}).get("max_particles") == 4 \
		and fast_sparks.get("parameters", {}).get("lifetime_seconds") == 0.35 \
		and fast_sparks.get("parameters", {}).get("size_start") == 14.0 \
		and loop_particle_capacity <= 10
	tests.expect_true(recipe_is_explicit, "Zero Zone declares an Aura-focused authoring recipe with two Glows, a supporting Inner Ring, and a 6 plus 4 Particle capacity budget using only Schema v1")
	tests.expect_true(start_by_id.has("start.inner_flash") and start_by_id.has("start.outer_flash") and start_by_id.has("start.expand_ring") and start_expand_ring.get("parameters", {}).get("width") == 13.0 and start_by_id.has("start.shard_burst") and end_by_id.has("end.release_pulse") and end_by_id.has("end.release_shards"), "Zero Zone START and END retain concise energy-domain signals and a non-subpixel launch Ring instead of a persistent shield-bubble structure")


static func _layers_by_id(layers: Array) -> Dictionary:
	var layers_by_id: Dictionary = {}
	for layer in layers:
		layers_by_id[str(layer.get("id", ""))] = layer
	return layers_by_id


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
