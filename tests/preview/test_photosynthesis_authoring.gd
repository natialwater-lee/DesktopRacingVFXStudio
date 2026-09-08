extends RefCounted

const H = preload("res://tests/preview/test_rotor_lift_downwash_authoring.gd")
const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Builder = preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const Budget = preload("res://tests/performance/test_high_speed_wind_budget.gd")
const Direction = preload("res://src/preview/rendering/vfx_particle_direction.gd")
const PATH = "res://presets/examples/talent.photosynthesis.vfx.json"
const HASHES = ["e56f74c68f8cee0d3339cbc6151656fa971cd6824ad5d58fb7d065306484a58c", "6994e88bd3fdbf48fe65963e458920cabe998b6f12e72bdc14de0fcf46f9943c", "3e252e36e73edca0c5890388ef350694d3cda32873500ded5c56a88390347b45"]
const NAMES = ["solar_streak", "leaf_arc", "absorption_glow"]
const GLOW_TARGET := Vector2(0, -40)
const P5_2_GLOW_CAPTURE_RADIUS := 50.0
# Hand-audited from the supplied 256x384 Solar PNG: its bright bulb is about
# 114 native px ahead of the center along the existing rotation+47-degree head axis.
const SOLAR_HEAD_OFFSET_PER_SIZE := 0.594
const P4_PAIRED_FIRST_BIRTH_SECONDS := {"left": [0.63, 0.63], "right": [0.56, 0.56], "front": [0.50, 0.50]}


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var loaded = Pipeline.new().load_and_validate(PATH)
	t.expect_true(loaded.success, "Photosynthesis P5 preset validates")
	if not loaded.success:
		for issue in loaded.issues:
			print(issue.message, " ", issue.json_pointer)
		return
	var d: Dictionary = loaded.value.normalized_data
	t.expect_true(d.category == "RACE_TALENT" and d.default_space_mode == "VEHICLE_LOCAL" and d.phases.loop.layers.size() == 9, "P5 preserves the nine-entity local Photosynthesis LOOP structure")
	var result = Builder.new(H._registry()).build(d)
	t.expect_true(result.success, "Photosynthesis P5 render plan")
	if not result.success:
		return
	_check_solar(t, d)
	_check_leaf(t, d, result.value)
	_check_glow(t, d)
	_check_start_and_transition(t, d, result.value)
	var compiled = Export.new().validate_saved_source(PATH)
	t.expect_true(compiled.success, "Photosynthesis P5 canonical compile")
	if compiled.success:
		var m = compiled.value.manifest_data()
		t.expect_true(m.runtime_definition.version == 2 and m.package_format_version == 1 and m.asset_dependencies.size() == 3, "P5 remains Runtime Definition v2 with exactly three supplied assets")
		for dep in m.asset_dependencies:
			var index = NAMES.find(str(dep.logical_id).trim_prefix("fx.photosynthesis_"))
			t.expect_true(index >= 0 and dep.sha256 == HASHES[index], "Portable P5 dependencies retain source PNG bytes")


static func _check_assets(t: TestAssert) -> void:
	for i in 3:
		var path = "res://assets/vfx/talent_photosynthesis_%s.png" % NAMES[i]
		var image = Image.new()
		t.expect_true(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK, "Supplied Photosynthesis PNG decodes")
		t.expect_true(image.get_size() == [Vector2i(256, 384), Vector2i(256, 256), Vector2i(256, 256)][i] and image.get_format() == Image.FORMAT_RGBA8, "Supplied Photosynthesis PNG is RGBA at its authored dimensions")
		t.expect_true(FileAccess.get_sha256(path) == HASHES[i] and FileAccess.get_file_as_bytes(path).size() == [72461, 55709, 108350][i], "P5 does not alter supplied Photosynthesis PNG bytes")
		if i == 2:
			t.expect_true(H._alpha_bounds(image) == Rect2i(0, 0, 252, 253), "Replacement absorption glow alpha bounds remain stable")
		var asset = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd").new(preload("res://src/preview/rendering/vfx_preview_asset_registry.gd").new()).resolve("fx.photosynthesis_" + NAMES[i])
		t.expect_true(asset.success and not asset.value.get("is_fallback", true), "Photosynthesis texture resolves through the existing asset registry")


static func _check_solar(t: TestAssert, d: Dictionary) -> void:
	var layers := H._by_id(d.phases.loop.layers)
	var expected = [
		{"id": "loop.solar_left_upper", "origin": Vector2(-195, -75), "box": [24.0, 108.0], "direction": 100.0, "rotation": -37.0, "rate": 1.3, "importance": "DETAIL"},
		{"id": "loop.solar_left_lower", "origin": Vector2(-195, -15), "box": [24.0, 108.0], "direction": 83.0, "rotation": -54.0, "rate": 1.9, "importance": "DETAIL"},
		{"id": "loop.solar_right_upper", "origin": Vector2(195, -10), "box": [24.0, 108.0], "direction": 279.0, "rotation": 142.0, "rate": 1.5, "importance": "DETAIL"},
		{"id": "loop.solar_right_lower", "origin": Vector2(195, 50), "box": [24.0, 108.0], "direction": 295.0, "rotation": 158.0, "rate": 2.1, "importance": "DETAIL"},
		{"id": "loop.solar_front_left", "origin": Vector2(-5, -240), "box": [120.0, 24.0], "direction": 179.0, "rotation": 42.0, "rate": 1.7, "importance": "CORE"},
		{"id": "loop.solar_front_right", "origin": Vector2(45, -240), "box": [120.0, 24.0], "direction": 193.0, "rotation": 56.0, "rate": 2.3, "importance": "CORE"}
	]
	var rates := 0.0
	for item in expected:
		t.expect_true(layers.has(item.id), "P5 retains every fixed-direction Solar source window")
		if not layers.has(item.id):
			continue
		var layer: Dictionary = layers[item.id]
		var p: Dictionary = layer.parameters
		var aimed: Vector2 = Direction.from_degrees(item.direction)
		var center_seeking: Vector2 = (GLOW_TARGET - (item.origin as Vector2)).normalized()
		t.expect_true(layer.type == "PARTICLE" and layer.importance == item.importance and layer.transform.offset == [item.origin.x, item.origin.y] and layer.transform.rotation_degrees == 0 and layer.render_plane == "OVER_VEHICLE", "P5 retains each narrow Solar source above the vehicle while moving its nominal travel to the Glow")
		t.expect_true(p.sprite_asset_ref == "fx.photosynthesis_solar_streak" and p.emitter.shape == "BOX" and p.emitter.size == item.box and p.direction_degrees == item.direction and p.spread_degrees == 10 and p.rotation_min_degrees == item.rotation - 4 and p.rotation_max_degrees == item.rotation + 4, "P5.2 widens each Solar source window with only a small spread increase while retaining its head-corrected fixed direction")
		t.expect_true(aimed.dot(center_seeking) > 0.999 and p.lifetime_seconds == 0.85 and p.speed_min == 250 and p.speed_max == 280 and p.size_start == 120 and p.size_end == 44 and p.size_multiplier_min == 0.9 and p.size_multiplier_max == 1.08 and p.alpha_start == 0.75 and p.alpha_end == 0, "P5.2 preserves Solar scale, alpha, variance, transit lifetime, speed, and fixed-direction approximation")
		t.expect_true(p.emission_rate_per_second == item.rate and p.max_particles == 2, "P5 retains cap two per source while using unequal rates rather than cap suppression")
		rates += p.emission_rate_per_second
	t.expect_true(is_equal_approx(rates, 10.8), "P5 preserves the P4 total Solar birth rate at 10.8 per second")
	_check_birth_timing(t, d, layers)
	_check_head_arrivals(t, d, layers, expected)


static func _check_birth_timing(t: TestAssert, d: Dictionary, layers: Dictionary) -> void:
	var pairs = {"left": ["loop.solar_left_upper", "loop.solar_left_lower"], "right": ["loop.solar_right_upper", "loop.solar_right_lower"], "front": ["loop.solar_front_left", "loop.solar_front_right"]}
	var expected_first = {"left": [0.77, 0.53], "right": [0.67, 0.48], "front": [0.59, 0.44]}
	var p5_first: Dictionary = {}
	for side in pairs:
		var pair: Array = pairs[side]
		var observed := [_first_birth_seconds(d, layers[pair[0]]), _first_birth_seconds(d, layers[pair[1]])]
		p5_first[side] = observed
		var p4: Array = P4_PAIRED_FIRST_BIRTH_SECONDS[side]
		var expected: Array = expected_first[side]
		t.expect_true(is_equal_approx(float(observed[0]), float(expected[0])) and is_equal_approx(float(observed[1]), float(expected[1])) and is_equal_approx(float(p4[0]), float(p4[1])) and absf(float(observed[0]) - float(observed[1])) >= 0.14, "P5 real accumulator simulation separates the %s pair's first births instead of P4's repeated same-tick start" % side)
	print("PHOTO_P5_BIRTHS p4=", P4_PAIRED_FIRST_BIRTH_SECONDS, " p5=", p5_first)


static func _check_head_arrivals(t: TestAssert, d: Dictionary, layers: Dictionary, expected: Array) -> void:
	for item in expected:
		var sample := _closest_head_sample(d, layers[item.id])
		t.expect_true(not sample.is_empty() and float(sample.distance) <= P5_2_GLOW_CAPTURE_RADIUS and float(sample.alpha) >= 0.15 and float(sample.size) >= 50.0 and float(sample.exit_alpha) <= 0.16, "P5.2 %s stays inside the central 150px Glow capture region despite its widened source window" % item.id)
		if not sample.is_empty():
			print("PHOTO_P5_HEAD ", item.id, " distance=", sample.distance, " alpha=", sample.alpha, " size=", sample.size, " age=", sample.age, " exit_alpha=", sample.exit_alpha)


static func _check_leaf(t: TestAssert, d: Dictionary, plan: RefCounted) -> void:
	for time in [0.0, 0.3125, 0.9375]:
		var rt = H._runtime(plan)
		rt.activate_phase("loop", {"preview_time": time})
		rt.advance(0, {"preview_time": time})
		var left = H._packet_by_layer(rt.draw_packets(), "loop.leaf_left")
		var right = H._packet_by_layer(rt.draw_packets(), "loop.leaf_right")
		var expected_alpha = {0.0: [0.40, 0.40], 0.3125: [0.52, 0.28], 0.9375: [0.28, 0.52]}[time]
		t.expect_true(is_equal_approx(left.alpha, expected_alpha[0]) and is_equal_approx(right.alpha, expected_alpha[1]), "P5 preserves the existing .28-to-.52 Leaf SINE visibility range")
		t.expect_true(left.position == Vector2(-125, 0) and right.position == Vector2(125, 0) and left.geometry_scale == Vector2(1.30, 1.30) and right.geometry_rotation_degrees == 180, "P5.1 aligns the two open Leaf arcs vertically without changing their scale or rotation")
	var leaves := H._by_id(d.phases.loop.layers)
	for id in ["loop.leaf_left", "loop.leaf_right"]:
		var leaf: Dictionary = leaves[id]
		t.expect_true(leaf.parameters.opacity == 0.4 and leaf.modulations[0].mapping.output_min == 0.7 and leaf.modulations[0].mapping.output_max == 1.3 and leaf.modulation_clamps[0].min_effective == 0.7 and leaf.modulation_clamps[0].max_effective == 1.3, "P5 retains Leaf scale, opacity, existing SINE, and clamp family")


static func _check_glow(t: TestAssert, d: Dictionary) -> void:
	var layers = H._by_id(d.phases.loop.layers)
	t.expect_true(layers.has("loop.absorption_glow"), "Central compression layer exists")
	if not layers.has("loop.absorption_glow"):
		return
	var glow: Dictionary = layers["loop.absorption_glow"]
	var p: Dictionary = glow.parameters
	t.expect_true(glow.type == "PARTICLE" and glow.importance == "CORE" and glow.blend_mode == "ALPHA" and glow.render_plane == "OVER_VEHICLE" and glow.sort_order == 1 and glow.transform.offset == [0.0, -40.0], "P5 preserves central Glow plane, order, and position")
	t.expect_true(p.sprite_asset_ref == "fx.photosynthesis_absorption_glow" and p.emitter.shape == "POINT" and p.speed_min == 0 and p.speed_max == 0 and p.max_particles == 1 and p.emission_rate_per_second == 2.4 and p.lifetime_seconds == 0.4, "P5 does not increase independent Glow cadence or cap")
	t.expect_true(p.size_start == 150 and p.size_end == 55 and p.alpha_start == 0.65 and p.alpha_end == 0 and p.size_multiplier_min == 1 and p.size_multiplier_max == 1, "P5 keeps Glow size and alpha exactly at P4 values")
	t.expect_true(p.rotation_min_degrees == 0 and p.rotation_max_degrees == 0 and p.angular_velocity_min_degrees_per_second == 0 and p.angular_velocity_max_degrees_per_second == 0, "P5 adds no Glow swirl or angular randomness")


static func _check_start_and_transition(t: TestAssert, d: Dictionary, plan: RefCounted) -> void:
	t.expect_true(H._ids(d.phases.start.layers) == ["start.leaf_left", "start.leaf_right", "start.solar_front", "start.absorption_glow"] and H._ids(d.phases.end.layers) == ["end.leaf_left", "end.leaf_right"], "P5 replaces the paired START front burst with one intentional Solar arrival and keeps END emission-free")
	var start_layers := H._by_id(d.phases.start.layers)
	var solar: Dictionary = start_layers.get("start.solar_front", {})
	var p: Dictionary = solar.get("parameters", {}) if solar.get("parameters", {}) is Dictionary else {}
	t.expect_true(not solar.is_empty() and solar.get("transform", {}).get("offset", []) == [-5.0, -240.0] and p.get("emitter", {}).get("size", []) == [60.0, 24.0] and p.get("direction_degrees") == 179 and p.get("lifetime_seconds") == 0.85 and p.get("speed_min") == 250 and p.get("speed_max") == 280 and p.get("burst_count") == 1, "P5 START uses the selected single natural front source with the shortened arrival profile")
	for phase_name in ["start", "loop", "end"]:
		var phase_layers := H._by_id(d.phases[phase_name].layers)
		t.expect_true(phase_layers["%s.leaf_left" % phase_name].transform.offset == [-125.0, 0.0] and phase_layers["%s.leaf_right" % phase_name].transform.offset == [125.0, 0.0], "P5.1 Leaf placement stays vertically aligned through %s" % phase_name)
	var filter = preload("res://src/performance/vfx_preview_lod_filter.gd").new()
	for level in ["HIGH", "MEDIUM", "LOW"]:
		var filtered = filter.filter(plan, level, Budget._policy_result().value)
		var analysis = preload("res://src/performance/vfx_performance_budget_analyzer.gd").new(H._registry()).analyze(filtered.value, {"anchors": {"CENTER": [0, 0]}}, "STEADY_LOOP")
		var workload = analysis.value.active_workload()
		var expected_entities = 5 if level == "LOW" else 9
		var expected_cap = 5 if level == "LOW" else 13
		t.expect_true(workload.expanded_instance_count() == expected_entities and workload.persistent_textured_sprite_instance_count() == 2 and workload.continuous_particle_capacity() == expected_cap, "P5 keeps %s LOD entity and capacity inventory unchanged" % level)
	var rt = H._runtime(plan)
	rt.activate_phase("start", {})
	t.expect_true(rt.draw_packets().size() == 4, "P5 START produces two Leaf arcs, one Solar arrival, and one Glow burst")
	rt.advance(0.32, {})
	rt.stop_phase_sources("start")
	rt.activate_phase("loop", {})
	var peak = 0
	for tick in 220:
		rt.advance(0.01, {})
		var particles = rt.draw_packets().filter(func(packet): return packet.has("size")).size()
		peak = maxi(peak, particles)
		t.expect_true(particles <= 15, "P5 single START residual plus LOOP caps never exceeds fifteen particles")
	rt.stop_phase_sources("loop")
	rt.activate_phase("end", {})
	rt.advance(0.3, {})
	rt.stop_phase_sources("end")
	rt.advance(0.851, {})
	t.expect_true(not rt.has_residual() and rt.draw_packets().is_empty(), "P5 END drains all Solar and Glow residuals within the .85-second Solar lifetime")
	t.expect_true(peak >= 8 and peak <= 15, "P5 real transition simulation remains visibly populated without restoring P4's longer-tail peak")
	print("PHOTO_P5_TRANSITION observed_particle_peak=", peak, " conservative_cap=15")


static func _first_birth_seconds(d: Dictionary, layer: Dictionary) -> float:
	var isolated = d.duplicate(true)
	isolated.phases.loop.layers = [layer]
	var built = Builder.new(H._registry()).build(isolated)
	if not built.success:
		return -1.0
	var rt = H._runtime(built.value)
	rt.activate_phase("loop", {})
	for tick in 120:
		rt.advance(0.01, {})
		if not H._packet_by_layer(rt.draw_packets(), str(layer.id)).is_empty():
			return float(tick + 1) * 0.01
	return -1.0


static func _closest_head_sample(d: Dictionary, layer: Dictionary) -> Dictionary:
	var isolated = d.duplicate(true)
	isolated.phases.loop.layers = [layer]
	var built = Builder.new(H._registry()).build(isolated)
	if not built.success:
		return {}
	var rt = H._runtime(built.value)
	rt.activate_phase("loop", {})
	var source_stopped := false
	var elapsed := 0.0
	var birth_seconds := -1.0
	var travel_axis := Vector2.ZERO
	var exit_alpha := 0.0
	var closest := {"distance": INF, "alpha": 0.0, "size": 0.0, "age": -1.0, "exit_alpha": 0.0}
	for _tick in 220:
		rt.advance(0.01, {})
		elapsed += 0.01
		var packet = H._packet_by_layer(rt.draw_packets(), str(layer.id))
		if packet.is_empty():
			continue
		if not source_stopped:
			rt.stop_phase_sources("loop")
			source_stopped = true
		var head_axis := Vector2.RIGHT.rotated(deg_to_rad(float(packet.rotation_degrees) + 47.0))
		var head_position: Vector2 = packet.position + head_axis * (SOLAR_HEAD_OFFSET_PER_SIZE * float(packet.size))
		if birth_seconds < 0.0:
			birth_seconds = elapsed
			travel_axis = (GLOW_TARGET - head_position).normalized()
		if travel_axis != Vector2.ZERO and (head_position - GLOW_TARGET).dot(travel_axis) >= 20.0:
			exit_alpha = maxf(exit_alpha, float(packet.alpha))
		var distance := head_position.distance_to(GLOW_TARGET)
		if distance < float(closest.distance):
			closest = {"distance": distance, "alpha": float(packet.alpha), "size": float(packet.size), "age": elapsed - birth_seconds, "exit_alpha": exit_alpha}
	closest.exit_alpha = exit_alpha
	return closest if source_stopped else {}
