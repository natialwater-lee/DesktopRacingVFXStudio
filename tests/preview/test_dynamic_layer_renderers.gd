extends RefCounted

const VfxPreviewLayerSpecModel := preload("res://src/preview/rendering/vfx_preview_layer_spec.gd")
const VfxPreviewRenderInstanceSpecModel := preload("res://src/preview/rendering/vfx_preview_render_instance_spec.gd")


static func run(tests: TestAssert) -> void:
	_test_particle_burst_and_restart_are_deterministic(tests)
	_test_particle_continuous_capacity_is_declared_cap(tests)
	_test_particle_emitter_shapes_stay_in_declared_geometry(tests)
	_test_follow_world_trail_captures_then_drains(tests)


static func _test_particle_burst_and_restart_are_deterministic(tests: TestAssert) -> void:
	var renderer_script := load("res://src/preview/rendering/vfx_particle_layer_renderer.gd") as Script
	tests.expect_true(renderer_script != null, "Particle Preview Renderer script is available")
	if renderer_script == null:
		return
	var renderer = renderer_script.new(_instance("PARTICLE", {"emission_mode": "BURST", "emitter": {"shape": "CIRCLE", "radius": 5.0}, "sprite_asset_ref": "fx.energy_shard", "burst_count": 3, "lifetime_seconds": 1.0, "speed_min": 0.0, "speed_max": 0.0}), {})
	renderer.restart(_frame())
	var first_packets: Array = renderer.draw_packets()
	renderer.restart(_frame())
	var restarted_packets: Array = renderer.draw_packets()
	tests.expect_true(first_packets.size() == 3, "Particle BURST creates exactly its declared burst_count")
	tests.expect_true(first_packets == restarted_packets, "Particle Restart uses the same stable seed for the same phase, Layer, Anchor, and generation")


static func _test_particle_continuous_capacity_is_declared_cap(tests: TestAssert) -> void:
	var renderer_script := load("res://src/preview/rendering/vfx_particle_layer_renderer.gd") as Script
	if renderer_script == null:
		tests.expect_true(false, "Particle capacity test requires the Particle Renderer")
		return
	var renderer = renderer_script.new(_instance("PARTICLE", {"emission_mode": "CONTINUOUS", "emitter": {"shape": "POINT"}, "sprite_asset_ref": "fx.energy_shard", "emission_rate_per_second": 8.0, "max_particles": 2, "lifetime_seconds": 2.0, "speed_min": 0.0, "speed_max": 0.0}), {})
	renderer.restart(_frame())
	renderer.advance(1.0, _frame())
	tests.expect_true(renderer.draw_packets().size() == 2, "Particle CONTINUOUS honors max_particles authoring capacity even when its accumulator requests more")


static func _test_particle_emitter_shapes_stay_in_declared_geometry(tests: TestAssert) -> void:
	var renderer_script := load("res://src/preview/rendering/vfx_particle_layer_renderer.gd") as Script
	if renderer_script == null:
		tests.expect_true(false, "Emitter geometry test requires the Particle Renderer")
		return
	var expected := {
		"POINT": func(position: Vector2) -> bool: return position == Vector2.ZERO,
		"CIRCLE": func(position: Vector2) -> bool: return position.length() <= 4.0,
		"BOX": func(position: Vector2) -> bool: return abs(position.x) <= 3.0 and abs(position.y) <= 2.0,
		"CONE": func(position: Vector2) -> bool: return position.length() <= 4.0 and abs(rad_to_deg(position.angle())) <= 30.0,
		"LINE": func(position: Vector2) -> bool: return abs(position.x) <= 3.0 and is_zero_approx(position.y)
	}
	var emitters := {
		"POINT": {"shape": "POINT"},
		"CIRCLE": {"shape": "CIRCLE", "radius": 4.0},
		"BOX": {"shape": "BOX", "size": [6.0, 4.0]},
		"CONE": {"shape": "CONE", "radius": 4.0, "angle_degrees": 60.0},
		"LINE": {"shape": "LINE", "length": 6.0}
	}
	for shape_name in emitters:
		var renderer = renderer_script.new(_instance("PARTICLE", {"emission_mode": "BURST", "emitter": emitters[shape_name], "sprite_asset_ref": "fx.energy_shard", "burst_count": 1, "lifetime_seconds": 1.0, "speed_min": 0.0, "speed_max": 0.0}), {})
		renderer.restart(_frame())
		var packets: Array = renderer.draw_packets()
		var position: Vector2 = packets[0].get("position", Vector2(999.0, 999.0)) if not packets.is_empty() else Vector2(999.0, 999.0)
		tests.expect_true(expected[shape_name].call(position), "Particle %s sampling remains inside its Schema emitter geometry" % shape_name)


static func _test_follow_world_trail_captures_then_drains(tests: TestAssert) -> void:
	var renderer_script := load("res://src/preview/rendering/vfx_trail_layer_renderer.gd") as Script
	tests.expect_true(renderer_script != null, "Trail Preview Renderer script is available")
	if renderer_script == null:
		return
	var renderer = renderer_script.new(_instance("TRAIL", {"texture_asset_ref": "fx.trail_streak", "width_start": 3.0, "width_end": 1.0, "max_points": 2, "lifetime_seconds": 1.0}, "VEHICLE_FOLLOW_WORLD_TRAIL"), {})
	renderer.restart(_frame(0.0))
	renderer.advance(0.25, _frame(10.0))
	var points: Array = renderer.draw_packets()[0].get("points", []) if not renderer.draw_packets().is_empty() else []
	tests.expect_true(points.size() == 2 and points[0] == Vector2.ZERO and points[1] == Vector2(10.0, 0.0), "Follow-world Trail records canonical world samples instead of moving its old point with the vehicle")
	renderer.stop_emission()
	renderer.advance(0.5, _frame(20.0))
	tests.expect_true(renderer.draw_packets()[0].get("points", []).size() == 2, "Trail source stop prevents new samples while existing samples remain within declared lifetime")
	renderer.advance(0.6, _frame(20.0))
	tests.expect_true(not renderer.has_residual(), "Trail removes all points only after declared lifetime expires")


static func _instance(layer_type: String, parameters: Dictionary, space: String = "VEHICLE_LOCAL") -> RefCounted:
	var spec := VfxPreviewLayerSpecModel.new("test.dynamic", layer_type, "CORE", "ADDITIVE", "OVER_VEHICLE", space, ["CENTER"] if space.begins_with("VEHICLE") else [], {"offset": [0.0, 0.0], "rotation_degrees": 0.0, "scale": [1.0, 1.0]}, parameters, true, 0, 0)
	return VfxPreviewRenderInstanceSpecModel.new("loop", spec, "CENTER", Vector2.ZERO, 0)


static func _frame(translation_x: float = 0.0) -> Dictionary:
	return {"vehicle_translation_source": [translation_x, 0.0], "vehicle_rotation_degrees": 0.0, "effective_game_scale": [1.0, 1.0], "playback_generation": 1}
