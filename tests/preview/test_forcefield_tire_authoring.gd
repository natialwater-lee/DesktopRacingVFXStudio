extends RefCounted

const Pipeline := preload("res://src/app/vfx_preset_pipeline.gd")
const Builder := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const Helpers := preload("res://tests/preview/test_rotor_lift_downwash_authoring.gd")
const Budget := preload("res://tests/performance/test_high_speed_wind_budget.gd")
const ExportService := preload("res://src/export/vfx_export_service.gd")
const PATH := "res://presets/examples/equipment.forcefield_tire.overcurrent.vfx.json"
const OFFSETS := [[-170.0,-125.0],[170.0,-125.0],[-170.0,140.0],[170.0,140.0]]
const WHEELS := ["fl","fr","rl","rr"]
const RATES := [0.75,0.9,1.05,0.8]

static func run(tests: TestAssert) -> void:
	var names := ["forcefield_tire_overcurrent_strip", "forcefield_tire_spark_burst"]
	var hashes := ["447bd4203c16668f2383afeee1669b259f36d706dc0cae2d3df0c1c60009b134","197b0ff2b2e2e0dfa379e9179916aded86d38e872b3f15a535c0584757ff1cdc"]
	for i in 2:
		var path := "res://assets/vfx/%s.png" % names[i]
		tests.expect_true(FileAccess.get_sha256(path) == hashes[i] and FileAccess.get_file_as_bytes(path).size() == [217496,71455][i], "Supplied PNG bytes remain unchanged")
		var resolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd").new(preload("res://src/preview/rendering/vfx_preview_asset_registry.gd").new())
		var asset = resolver.resolve("fx." + names[i])
		tests.expect_true(asset.success and not asset.value.get("is_fallback", true), "Production asset resolves without fallback: " + names[i])
	var loaded := Pipeline.new().load_and_validate(PATH)
	tests.expect_true(loaded.success, "Forcefield Tire standalone preset validates")
	if not loaded.success:
		return
	var data: Dictionary = loaded.value.normalized_data
	tests.expect_true(data.category == "SPECIAL_EQUIPMENT" and data.default_space_mode == "VEHICLE_LOCAL" and data.lifecycle.mode == "START_LOOP_END", "Equipment lifecycle and coordinate contract")
	tests.expect_true(data.phases.loop.layers.size() == 8 and data.phases.start.layers.size() == 4 and data.phases.end.layers.size() == 4, "Only LOOP emits sparks")
	var layers: Dictionary = Helpers._by_id(data.phases.loop.layers)
	for i in 4:
		var strip: Dictionary = layers.get("loop.%s_strip" % WHEELS[i], {})
		var spark: Dictionary = layers.get("loop.%s_spark" % WHEELS[i], {})
		tests.expect_true(not strip.is_empty() and not spark.is_empty(), "Each wheel has a strip and spark")
		if strip.is_empty() or spark.is_empty():
			return
		for layer in [strip,spark]:
			tests.expect_true(layer.transform.offset == OFFSETS[i] and layer.anchors == ["CENTER"] and layer.render_plane == "OVER_VEHICLE" and layer.blend_mode == "ALPHA", "Four wheel-local neutral overlays")
		tests.expect_true(strip.transform.scale == [0.28,0.28] and is_equal_approx(strip.parameters.opacity,0.22) and strip.importance == "CORE", "Subdued persistent strip survives every LOD")
		var p: Dictionary = spark.parameters
		tests.expect_true(spark.importance == "EXTRA" and p.sprite_asset_ref == "fx.forcefield_tire_spark_burst" and p.max_particles == 1 and is_equal_approx(p.emission_rate_per_second,RATES[i]) and is_equal_approx(p.lifetime_seconds,0.18), "Intermittent one-particle wheel budget")
		tests.expect_true(p.size_start == 32 and p.size_end == 18 and p.size_multiplier_min == 0.8 and p.size_multiplier_max == 1.1 and p.alpha_start == 0.55 and p.alpha_end == 0 and p.emitter.size == [12.0,20.0] and p.speed_min == 0 and p.speed_max == 12, "Small localized discharge instead of an explosion")
	var plan := Builder.new(Budget._registry()).build(data)
	tests.expect_true(plan.success, "Preview plan builds")
	if not plan.success:
		return
	for time in [0.0,0.25,0.5,0.75]:
		var runtime := Helpers._runtime(plan.value)
		runtime.activate_phase("loop", {"preview_time":time})
		runtime.advance(0, {"preview_time":time})
		var expected: Array = {0.0:[0.22,0.28,0.22,0.16],0.25:[0.28,0.22,0.16,0.22],0.5:[0.22,0.16,0.22,0.28],0.75:[0.16,0.22,0.28,0.22]}[time]
		for i in 4:
			var packet: Dictionary = Helpers._packet_by_layer(runtime.draw_packets(),"loop.%s_strip" % WHEELS[i])
			tests.expect_true(not packet.is_empty() and absf(packet.get("alpha", -1.0)-expected[i]) < 0.00001 and packet.position.distance_to(Vector2(OFFSETS[i][0],OFFSETS[i][1])) < 0.001, "Phase-shifted strip stays at its wheel, alpha .16-.28")
	var runtime := Helpers._runtime(plan.value)
	runtime.activate_phase("loop", {"preview_time":0.0})
	for tick in 200:
		runtime.advance(0.01, {"preview_time":(tick+1)*0.01})
		tests.expect_true(runtime.draw_packets().size() <= 8, "Four strips plus at most four live sparks")
	runtime.stop_phase_sources("loop")
	runtime.advance(0.181, {"preview_time":2.181})
	tests.expect_true(runtime.draw_packets().is_empty() and not runtime.has_residual(), "Stopped LOOP leaves no spark after its lifetime")
	var policy := Budget._policy_result()
	var filter = load("res://src/performance/vfx_preview_lod_filter.gd").new()
	var analyzer = load("res://src/performance/vfx_performance_budget_analyzer.gd").new(Budget._registry())
	for level in ["HIGH","MEDIUM","LOW"]:
		var filtered = filter.filter(plan.value,level,policy.value)
		var result = analyzer.analyze(filtered.value,{"anchors":{"CENTER":[0,0]}},"STEADY_LOOP")
		var workload = result.value.active_workload()
		tests.expect_true(workload.expanded_instance_count() == (8 if level == "HIGH" else 4) and workload.persistent_textured_sprite_instance_count() == 4 and workload.continuous_particle_capacity() == (4 if level == "HIGH" else 0), "Symmetric low-cost LOD " + level)
	var compiled := ExportService.new().validate_saved_source(PATH)
	tests.expect_true(compiled.success, "Canonical compile-only succeeds")
	if compiled.success:
		var manifest: Dictionary = compiled.value.manifest_data()
		tests.expect_true(manifest.runtime_definition.version == 2 and manifest.package_format_version == 1 and manifest.asset_dependencies.size() == 2, "Runtime v2 and exactly two portable asset dependencies")
		for dependency in manifest.asset_dependencies:
			var index: int = names.find(str(dependency.logical_id).trim_prefix("fx."))
			tests.expect_true(index >= 0 and dependency.sha256 == hashes[index], "Export preserves asset identity")
