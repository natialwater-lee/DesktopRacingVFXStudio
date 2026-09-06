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
	var baseline := Pipeline.new().load_and_validate("res://presets/examples/driving.high_speed_wind.vfx.json")
	var layers: Array = data.phases.loop.layers
	tests.expect_true(data.category == "SPECIAL_EQUIPMENT" and data.default_space_mode == "VEHICLE_LOCAL" and data.lifecycle.mode == "START_LOOP_END", "Wing uses the common equipment lifecycle and vehicle-local contract")
	tests.expect_true(layers.size() == 4 and data.phases.start.layers.size() == 2 and data.phases.end.layers.is_empty(), "Wing has two entry accents, four LOOP emitters and no new END emission")
	if layers.size() != 4:
		return
	for index in 4:
		var layer: Dictionary = layers[index]
		var main := index % 2 == 0
		var reference: Dictionary = baseline.value.normalized_data.phases.loop.layers[index % 2]
		var p: Dictionary = layer.parameters
		for key in ["size_start", "size_end", "size_multiplier_min", "size_multiplier_max", "speed_min", "speed_max", "lifetime_seconds", "spread_degrees", "direction_degrees", "rotation_min_degrees", "rotation_max_degrees", "color_rgba"]:
			tests.expect_true(p[key] == reference.parameters[key], "Wing preserves wind motion/shape family: %s %s" % [layer.id, key])
		tests.expect_true(layer.transform.scale == reference.transform.scale and layer.blend_mode == "ALPHA" and layer.render_plane == "UNDER_VEHICLE" and layer.anchors == ["CENTER"], "Wind remains thin, under vehicle, without bend")
		tests.expect_true(p.sprite_asset_ref == "fx.speed_wind_streak" and not layer.has("visual_bend") and layer.get("modulations", []).is_empty(), "Reuse the wind asset and straight particle path only")
		var side := -1.0 if index < 2 else 1.0
		tests.expect_true(layer.transform.offset == [side * 220.0, 300.0 if main else 235.0] and p.emitter.shape == "BOX" and p.emitter.size == [100.0, 36.0], "Spawn bands stay behind the left/right wing instead of the vehicle center")
		tests.expect_true(p.emission_rate_per_second == (4.5 if main else 3.5) and p.max_particles == (3 if main else 2) and is_equal_approx(p.alpha_start, 0.58 if main else 0.38), "Wing slightly increases density/contrast without increasing line size")
	var plan := Builder.new(WindBudget._registry()).build(data)
	tests.expect_true(plan.success, "Wing render plan compiles")
	if not plan.success:
		return
	var runtime := RotorTests._runtime(plan.value)
	runtime.activate_phase("loop", {"preview_time": 0.0})
	runtime.advance(0.3, {"preview_time": 0.3})
	var packets: Array = runtime.draw_packets()
	tests.expect_true(packets.size() == 4, "All four narrow wind bands emit at their own configured rate")
	var positions: Dictionary = {}
	for packet in packets:
		positions[packet.layer_id] = packet.position
	if positions.has("loop.left_main") and positions.has("loop.right_main"):
		var left: Vector2 = positions["loop.left_main"] - Vector2(-220, 300)
		var right: Vector2 = positions["loop.right_main"] - Vector2(220, 300)
		tests.expect_true(not left.is_equal_approx(right), "Distinct layer IDs produce independent left/right random patterns")
	runtime.stop_phase_sources("loop")
	runtime.activate_phase("end", {"preview_time": 0.3})
	runtime.advance(0.421, {"preview_time": 0.721})
	tests.expect_true(runtime.draw_packets().is_empty() and not runtime.has_residual(), "End stops emission and drains every wind particle within .42 seconds")
	var policy := WindBudget._policy_result()
	var lod_filter = load("res://src/performance/vfx_preview_lod_filter.gd").new()
	var analyzer = load("res://src/performance/vfx_performance_budget_analyzer.gd").new(WindBudget._registry())
	for level in ["HIGH", "MEDIUM", "LOW"]:
		var filtered = lod_filter.filter(plan.value, level, policy.value)
		var budget = analyzer.analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP")
		var workload = budget.value.active_workload()
		tests.expect_true(workload.expanded_instance_count() == (2 if level == "LOW" else 4) and workload.continuous_particle_capacity() == (6 if level == "LOW" else 10), "Wing LOD budget: %s" % level)
	var compiled := ExportService.new().validate_saved_source(PATH)
	tests.expect_true(compiled.success, "Wing compiles without invoking the package writer")
	if compiled.success:
		var dependencies: Array = compiled.value.manifest_data().asset_dependencies
		tests.expect_true(dependencies.size() == 1 and dependencies[0].logical_id == "fx.speed_wind_streak", "Four emitters deduplicate to one existing wind texture dependency")
