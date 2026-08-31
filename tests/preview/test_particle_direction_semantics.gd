extends RefCounted

const VfxPreviewLayerSpecModel := preload("res://src/preview/rendering/vfx_preview_layer_spec.gd")
const VfxPreviewRenderInstanceSpecModel := preload("res://src/preview/rendering/vfx_preview_render_instance_spec.gd")
const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")

const DIRECTION_HELPER_PATH := "res://src/preview/rendering/vfx_particle_direction.gd"
const PARTICLE_RENDERER_PATH := "res://src/preview/rendering/vfx_particle_layer_renderer.gd"


static func run(tests: TestAssert) -> void:
	_test_cardinal_directions_use_vehicle_local_front_axis(tests)
	_test_intermediate_direction_uses_vehicle_local_angle(tests)
	_test_particle_spread_zero_uses_canonical_forward(tests)
	_test_particle_full_spread_keeps_a_deterministic_rotated_distribution(tests)
	_test_compatibility_migrations_preserve_existing_particle_intent(tests)


static func _test_cardinal_directions_use_vehicle_local_front_axis(tests: TestAssert) -> void:
	var helper_script := load(DIRECTION_HELPER_PATH) as Script
	tests.expect_true(helper_script != null, "Particle direction helper exists so the Preview cannot silently keep a +X angle basis")
	if helper_script == null:
		return
	var directions := {
		0.0: Vector2(0.0, -1.0),
		90.0: Vector2(1.0, 0.0),
		180.0: Vector2(0.0, 1.0),
		270.0: Vector2(-1.0, 0.0),
	}
	var all_match := true
	for degrees in directions:
		var actual: Vector2 = helper_script.call("from_degrees", float(degrees))
		all_match = all_match and actual.is_equal_approx(directions[degrees])
	tests.expect_true(all_match, "Particle cardinal angles use 0=-Y front, 90=+X, 180=+Y, and 270=-X in source-local coordinates")


static func _test_intermediate_direction_uses_vehicle_local_angle(tests: TestAssert) -> void:
	var helper_script := load(DIRECTION_HELPER_PATH) as Script
	if helper_script == null:
		tests.expect_true(false, "Particle intermediate direction test requires the canonical helper")
		return
	var actual: Vector2 = helper_script.call("from_degrees", 45.0)
	var expected := Vector2(0.70710678, -0.70710678)
	tests.expect_true(actual.is_equal_approx(expected), "Particle 45 degree direction stays halfway between vehicle-front and right")


static func _test_particle_spread_zero_uses_canonical_forward(tests: TestAssert) -> void:
	var renderer_script := load(PARTICLE_RENDERER_PATH) as Script
	if renderer_script == null:
		tests.expect_true(false, "Particle Preview Renderer is required for zero-spread direction routing")
		return
	var renderer = renderer_script.new(_instance({
		"direction_degrees": 0.0,
		"spread_degrees": 0.0,
		"speed_min": 10.0,
		"speed_max": 10.0,
	}, {}), {})
	renderer.restart(_frame())
	renderer.advance(0.5, _frame())
	var packets: Array = renderer.draw_packets()
	var position: Vector2 = packets[0].get("position", Vector2.ZERO) if not packets.is_empty() else Vector2.ZERO
	tests.expect_true(packets.size() == 1 and position.is_equal_approx(Vector2(0.0, -5.0)), "Particle Preview routes zero-spread direction 0 through the canonical vehicle-front vector")


static func _test_particle_full_spread_keeps_a_deterministic_rotated_distribution(tests: TestAssert) -> void:
	var renderer_script := load(PARTICLE_RENDERER_PATH) as Script
	if renderer_script == null:
		tests.expect_true(false, "Particle Preview Renderer is required for full-spread direction routing")
		return
	var parameters := {
		"direction_degrees": 0.0,
		"spread_degrees": 360.0,
		"burst_count": 3,
		"speed_min": 10.0,
		"speed_max": 10.0,
	}
	var forward_renderer = renderer_script.new(_instance(parameters, {}), {})
	forward_renderer.restart(_frame())
	forward_renderer.advance(0.5, _frame())
	var forward_packets: Array = forward_renderer.draw_packets()
	forward_renderer.restart(_frame())
	forward_renderer.advance(0.5, _frame())
	var restarted_packets: Array = forward_renderer.draw_packets()
	var reverse_parameters: Dictionary = parameters.duplicate(true)
	reverse_parameters["direction_degrees"] = 180.0
	var reverse_renderer = renderer_script.new(_instance(reverse_parameters, {}), {})
	reverse_renderer.restart(_frame())
	reverse_renderer.advance(0.5, _frame())
	var reverse_packets: Array = reverse_renderer.draw_packets()
	var positions_are_opposite := forward_packets.size() == reverse_packets.size()
	for index in mini(forward_packets.size(), reverse_packets.size()):
		var forward_position: Vector2 = forward_packets[index].get("position", Vector2.ZERO)
		var reverse_position: Vector2 = reverse_packets[index].get("position", Vector2.ZERO)
		positions_are_opposite = positions_are_opposite and (forward_position + reverse_position).is_zero_approx()
	tests.expect_true(forward_packets == restarted_packets and positions_are_opposite, "Particle full-spread sampling remains fixed-seed deterministic and rotates by 180 degrees when its declared axis rotates by 180 degrees")


static func _test_compatibility_migrations_preserve_existing_particle_intent(tests: TestAssert) -> void:
	var pipeline := VfxPresetPipelineModel.new()
	var finish_result: VfxResult = pipeline.load_and_validate("res://presets/examples/finish.confetti_world.vfx.json")
	var showcase_result: VfxResult = pipeline.load_and_validate("res://presets/examples/utility.renderer_showcase.vfx.json")
	var zero_result: VfxResult = pipeline.load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	if not finish_result.success or not showcase_result.success or not zero_result.success:
		tests.expect_true(false, "Particle direction migration regression requires all three existing Presets to remain contract-valid")
		return
	var finish_parameters: Dictionary = _layer_parameters(finish_result.value.normalized_data, "one_shot", "one_shot.confetti_burst")
	var showcase_parameters: Dictionary = _layer_parameters(showcase_result.value.normalized_data, "loop", "loop.energy_particles")
	var zero_particle_parameters: Dictionary = {}
	for phase_name in ["start", "loop", "end"]:
		for layer in zero_result.value.normalized_data.get("phases", {}).get(phase_name, {}).get("layers", []):
			if layer.get("type") == "PARTICLE":
				zero_particle_parameters[layer.get("id", "")] = layer.get("parameters", {})
	var helper_script := load(DIRECTION_HELPER_PATH) as Script
	var finish_launch_is_upward := helper_script != null and (helper_script.call("from_degrees", float(finish_parameters.get("direction_degrees", -1.0))) as Vector2).is_equal_approx(Vector2.UP)
	var expected_zero_directions := {
		"start.focus_mote_burst": [180.0, 25.0], "start.tunnel_arc_entry": [180.0, 0.0],
		"loop.tunnel_arc_pass": [180.0, 0.0], "loop.focus_motes": [180.0, 25.0],
		"end.focus_mote_release": [180.0, 25.0], "end.tunnel_arc_release": [180.0, 0.0]
	}
	var zero_uses_canonical_authoring := zero_particle_parameters.size() == expected_zero_directions.size()
	for layer_id in expected_zero_directions:
		var parameters: Dictionary = zero_particle_parameters.get(layer_id, {})
		var expected: Array = expected_zero_directions[layer_id]
		zero_uses_canonical_authoring = zero_uses_canonical_authoring \
			and float(parameters.get("direction_degrees", -1.0)) == expected[0] \
			and float(parameters.get("spread_degrees", -1.0)) == expected[1]
	tests.expect_true(
		float(finish_parameters.get("direction_degrees", -1.0)) == 0.0
		and float(finish_parameters.get("spread_degrees", -1.0)) == 80.0
		and finish_parameters.get("acceleration", []) == [0.0, 36.0]
		and finish_launch_is_upward,
		"Finish Confetti migrates only 270 to canonical 0 so its -Y launch and +Y fall intent stays intact"
	)
	tests.expect_true(
		float(showcase_parameters.get("direction_degrees", -1.0)) == 0.0
		and float(showcase_parameters.get("spread_degrees", -1.0)) == 50.0,
		"Renderer Showcase migrates only 270 to canonical 0 so its initial -Y Preview direction remains intact"
	)
	tests.expect_true(zero_uses_canonical_authoring, "Production Zero Zone uses canonical 180 degrees for every focus mote and fixed open tunnel arc so all focus flow travels rearward")


static func _layer_parameters(normalized_preset: Dictionary, phase_name: String, layer_id: String) -> Dictionary:
	var phase: Dictionary = normalized_preset.get("phases", {}).get(phase_name, {})
	for layer in phase.get("layers", []):
		if layer is Dictionary and layer.get("id", "") == layer_id:
			return layer.get("parameters", {}) if layer.get("parameters", {}) is Dictionary else {}
	return {}


static func _instance(parameter_overrides: Dictionary, layer_overrides: Dictionary) -> RefCounted:
	var parameters := {
		"emission_mode": "BURST",
		"emitter": {"shape": "POINT"},
		"sprite_asset_ref": "fx.energy_shard",
		"burst_count": 1,
		"lifetime_seconds": 1.0,
		"direction_degrees": 0.0,
		"spread_degrees": 0.0,
		"speed_min": 0.0,
		"speed_max": 0.0,
		"rotation_min_degrees": 0.0,
		"rotation_max_degrees": 0.0,
		"angular_velocity_min_degrees_per_second": 0.0,
		"angular_velocity_max_degrees_per_second": 0.0,
		"size_start": 1.0,
		"size_end": 1.0,
		"alpha_start": 1.0,
		"alpha_end": 1.0,
		"acceleration": [0.0, 0.0],
		"color_rgba": [1.0, 1.0, 1.0, 1.0],
	}
	for key in parameter_overrides:
		parameters[key] = parameter_overrides[key]
	var transform := {"offset": [0.0, 0.0], "rotation_degrees": 0.0, "scale": [1.0, 1.0]}
	for key in layer_overrides:
		transform[key] = layer_overrides[key]
	var spec := VfxPreviewLayerSpecModel.new("test.direction", "PARTICLE", "CORE", "ADDITIVE", "OVER_VEHICLE", "VEHICLE_LOCAL", ["CENTER"], transform, parameters, true, 0, 0)
	return VfxPreviewRenderInstanceSpecModel.new("loop", spec, "CENTER", Vector2.ZERO, 0)


static func _frame() -> Dictionary:
	return {"vehicle_translation_source": [0.0, 0.0], "vehicle_rotation_degrees": 0.0, "effective_game_scale": [1.0, 1.0], "playback_generation": 1}
