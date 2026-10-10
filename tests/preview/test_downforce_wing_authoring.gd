extends RefCounted

const Pipeline := preload("res://src/app/vfx_preset_pipeline.gd")
const Builder := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const RotorTests := preload("res://tests/preview/test_rotor_lift_downwash_authoring.gd")
const WindBudget := preload("res://tests/performance/test_high_speed_wind_budget.gd")
const ExportService := preload("res://src/export/vfx_export_service.gd")
const PATH := "res://presets/examples/equipment.downforce_wing.wind_streak.vfx.json"


static func run(tests: TestAssert) -> void:
	var loaded := Pipeline.new().load_and_validate(PATH)
	tests.expect_true(loaded.success, "Downforce Wing must have a valid standalone production preset")
	if not loaded.success:
		return
	var data: Dictionary = loaded.value.normalized_data
	var loop: Array = data.phases.loop.layers
	var start: Array = data.phases.start.layers
	var end: Array = data.phases["end"].layers
	tests.expect_true(data.category == "SPECIAL_EQUIPMENT" and data.default_space_mode == "VEHICLE_LOCAL" and data.lifecycle.mode == "START_LOOP_END", "Wing keeps the equipment lifecycle and vehicle-local contract")
	tests.expect_true(data.runtime_inputs == ["turn_rate_normalized", "speed_normalized"], "Wing declares only the turn and speed inputs")
	tests.expect_true(loop.size() == 6 and start.size() == 6 and end.size() == 2, "Wing has 6 LOOP sprites, 6 START copies and 2 END tails")
	if loop.size() != 6 or end.size() != 2:
		return
	var textures := {}
	for layer in loop:
		tests.expect_true(layer.type == "TEXTURED_SPRITE" and layer.render_plane == "UNDER_VEHICLE" and layer.blend_mode == "ALPHA", "Wing LOOP layers are under-vehicle alpha sprites: %s" % layer.id)
		textures[layer.parameters.texture_asset_ref] = true
		var turn_targets := []
		for modulation in layer.modulations:
			if modulation.source.get("input", "") == "turn_rate_normalized":
				turn_targets.append(modulation.target)
				tests.expect_true(modulation.mapping.input_min == -0.2 and modulation.mapping.input_max == 0.2, "Turn bindings use the practical +-0.2 range: %s" % modulation.id)
		tests.expect_true(turn_targets.has("TRANSFORM_ROTATION_DEGREES"), "Every wing layer swings with the turn: %s" % layer.id)
	tests.expect_true(textures.has("fx.downforce_tip_streak_a") and textures.has("fx.downforce_tip_streak_b") and textures.has("fx.speed_wind_flow_a"), "Wing uses the two tip streak textures and the existing wind flow line")
	var tips := loop.filter(func(layer: Dictionary) -> bool: return str(layer.id).begins_with("loop.tip_a"))
	tests.expect_true(tips.size() == 2 and absf(float(tips[0].transform.offset[0])) > 280.0 and tips[0].importance == "CORE", "Tip streamers sit at the wing tips and are CORE")
	var plan := Builder.new(WindBudget._registry()).build(data)
	tests.expect_true(plan.success, "Wing render plan compiles")
	if not plan.success:
		return
	var runtime := RotorTests._runtime(plan.value)
	runtime.activate_phase("loop", {"preview_time": 0.0})
	runtime.advance(0.4, {"preview_time": 0.4})
	tests.expect_true(runtime.draw_packets().size() == 6, "All six LOOP sprites draw")
	runtime.stop_phase_sources("loop")
	runtime.activate_phase("end", {"preview_time": 0.4})
	runtime.advance(0.5, {"preview_time": 0.9})
	tests.expect_true(runtime.draw_packets().is_empty(), "End tails drain within 0.5 seconds")
	var policy := WindBudget._policy_result()
	var lod_filter = load("res://src/performance/vfx_preview_lod_filter.gd").new()
	var analyzer = load("res://src/performance/vfx_performance_budget_analyzer.gd").new(WindBudget._registry())
	for level in ["HIGH", "MEDIUM", "LOW"]:
		var filtered = lod_filter.filter(plan.value, level, policy.value)
		var budget = analyzer.analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP")
		var count: int = budget.value.active_workload().expanded_instance_count()
		tests.expect_true(count == (2 if level == "LOW" else 6), "Wing LOD keeps %d sprites: %s" % [2 if level == "LOW" else 6, level])
	var compiled := ExportService.new().validate_saved_source(PATH)
	tests.expect_true(compiled.success, "Wing compiles without invoking the package writer")
	if compiled.success:
		tests.expect_true(compiled.value.manifest_data().asset_dependencies.size() == 3, "Wing package depends on exactly three textures")
