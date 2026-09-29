extends RefCounted
const PATH := "res://tests/fixtures/compatibility/curve_flow_f1.vfx.json"
const Pipeline := preload("res://src/app/vfx_preset_pipeline.gd")
static func run(t: TestAssert) -> void:
	var loaded = Pipeline.new().load_and_validate(PATH)
	t.expect_true(loaded.success, "F candidate validates as formal CURVE_FLOW")
	if not loaded.success:
		for issue in loaded.issues: print(issue.code, ": ", issue.message)
		return
	var raw: Dictionary = loaded.value.raw_data
	for field in ["speed", "interval", "length", "half_width"]:
		var invalid := raw.duplicate(true)
		invalid.phases.loop.layers[0].parameters[field] = 0
		t.expect_true(not Pipeline.new().build_document_from_value(invalid).success, "Reject zero " + field)
	for field in ["speed", "brightness", "texture_phase"]:
		var invalid := raw.duplicate(true)
		invalid.phases.loop.layers[0].parameters[field] = NAN
		t.expect_true(not Pipeline.new().build_document_from_value(invalid).success, "Reject NaN " + field)
	for mutation in ["profile", "join", "end", "degenerate"]:
		var invalid := raw.duplicate(true)
		var p: Dictionary = invalid.phases.loop.layers[0].parameters
		match mutation:
			"profile": p.profile_version = 3
			"join": p.curves[1][0][0] += 1
			"degenerate": p.curves[0][1] = p.curves[0][0].duplicate()
			"end": invalid.phases.end.layers = invalid.phases.loop.layers; invalid.phases.loop.layers = []
		t.expect_true(not Pipeline.new().build_document_from_value(invalid).success, "Reject invalid " + mutation)
	var support = preload("res://tests/preview/test_rotor_lift_downwash_authoring.gd")
	var registry = support._registry()
	var resolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd").new(null)
	t.expect_true(not resolver._resolve_texture_asset("required", {"texture_path":"res://assets/vfx/nonexistent_curve_flow.png", "import_as_resource":true}).success, "Missing required resource fails without fallback")
	var factory = preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd").new()
	t.expect_true(factory.validate_configuration(registry).success, "Factory covers formal schema")
	var built = preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd").new(registry).build(loaded.value.normalized_data)
	t.expect_true(built.success, "Normal editor preview plan builds")
	if not built.success: return
	var runtime = support._runtime(built.value)
	var playback = preload("res://src/preview/rendering/vfx_preview_playback_controller.gd").new(built.value, runtime)
	playback.play()
	t.expect_true(playback.active_phase_name() == "loop" and runtime.active_renderer_count() == 8, "Empty START activates eight lanes immediately")

	for tick in 90: runtime.advance(1.0/60.0,{})
	var packets: Array = runtime.draw_packets()
	t.expect_true(packets.size()==8,"F1 renders native and procedural lanes")
	for i in packets.size():
		var flow = packets[i].curve_flow
		var lane: Dictionary = flow.lanes[0]
		t.expect_true(flow.time > 1.49 and flow.time < 1.51 and flow.segments.size()<=lane.cap,"F1 analytic time/cap")
		for segment in flow.segments:
			t.expect_true(absf(segment.head-(1.5-segment.born)*lane.speed)<.001,"Distance based head at fixed time")
		var mesh_host = preload("res://src/preview/curve_flow/vfx_curve_flow_mesh.gd").new()
		mesh_host.evaluator=flow; mesh_host.configure(packets[i].asset.texture); mesh_host.refresh()
		t.expect_true(mesh_host._mesh.get_surface_count()==1,"F1 moving segment mesh remains supported")
		var arrays: Array = mesh_host._mesh.surface_get_arrays(0)
		t.expect_true(not arrays[Mesh.ARRAY_VERTEX].is_empty() and arrays[Mesh.ARRAY_VERTEX].size()==arrays[Mesh.ARRAY_TEX_UV].size(),"F1 geometry carries per-vertex UV")
		mesh_host.free()
	runtime.stop_phase_sources("loop"); runtime.activate_phase("end",{})
	runtime.advance(3.0,{})
	t.expect_true(not runtime.has_residual(),"F1 stopped tails fully drain")
	playback.restart(); runtime.advance(.7,{}); runtime.clear()
	t.expect_true(runtime.draw_packets().is_empty(),"F1 restart/force clear retained")
	var service = preload("res://src/export/vfx_export_service.gd").new()
	service._ensure_ready()
	var compiled = service._compiler.compile(loaded.value)
	t.expect_true(compiled.success, "Canonical compiler accepts candidate")
	if compiled.success:
		var data: Dictionary = JSON.parse_string(compiled.value.runtime_text())
		t.expect_true(compiled.value.runtime_definition_version() == 3 and compiled.value.manifest_data().package_format_version == 1, "Candidate is v3 / package v1")
		var reader = preload("res://src/export/vfx_runtime_definition_reader.gd")
		t.expect_true(not reader.read(data).success and not reader.read(data, [1,2,3]).success, "Unsupported v3 or layer explicitly rejects")
		var decoded = reader.read(data, [3], ["CURVE_FLOW"])
		if not decoded.success:
			for issue in decoded.issues: print("ROUNDTRIP ", issue.code, " ", issue.message)
		t.expect_true(decoded.success, "v3 roundtrip validates with explicit capability")
		var bad_coordinates := data.duplicate(true); bad_coordinates.coordinate_contract.front_axis = "+Y"
		t.expect_true(not reader.read(bad_coordinates, [3], ["CURVE_FLOW"]).success, "Reject incompatible coordinates")
		for field in ["runtime_inputs", "runtime_modulation_sources"]:
			var malformed := data.duplicate(true); malformed[field] = null
			t.expect_true(not reader.read(malformed, [3], ["CURVE_FLOW"]).success, "Reject malformed " + field)
		var downgraded := data.duplicate(true); downgraded.runtime_definition_version = 2
		t.expect_true(not reader.read(downgraded, [2], ["CURVE_FLOW"]).success, "No automatic downgrade")
