extends RefCounted
const Pipeline := preload("res://src/app/vfx_preset_pipeline.gd")
const Builder := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const Support := preload("res://tests/preview/test_rotor_lift_downwash_authoring.gd")
const PATH := "res://tests/fixtures/compatibility/particle_bend.vfx.json"
static func run(t: TestAssert) -> void:
	var loaded = Pipeline.new().load_and_validate(PATH)
	t.expect_true(loaded.success, "Particle Bend compatibility fixture validates")
	if not loaded.success: return
	var built = Builder.new(Support._registry()).build(loaded.value.normalized_data)
	t.expect_true(built.success, "Particle Bend compatibility builds")
	if built.success: _check_particle_bend(t, loaded.value.normalized_data, built.value)

static func _check_particle_bend(t: TestAssert, data: Dictionary, plan: RefCounted) -> void:
	var program = plan.runtime_modulation_program()
	var inputs = preload("res://src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd").new(program)
	var evaluator = preload("res://src/preview/runtime_modulation/vfx_preview_runtime_modulation_evaluator.gd").new(program, inputs)
	var slot := -1
	for i in program.target_count():
		if program.target_name(i) == "VISUAL_BEND_OFFSET_X":
			slot = i
	for layer in data.phases.loop.layers:
		if not str(layer.id).begins_with("loop.rear_flow_"):
			continue
		t.expect_true(layer.get("visual_bend") == {"axis": "LOCAL_Y_POSITIVE", "start_ratio": 0.333333333, "curve": "QUADRATIC", "span_source_px": 384.0} and layer.transform.modulation_pivot_local == [0.0, -192.0] and layer.modulations.size() == 1 and layer.modulation_clamps == [{"target": "VISUAL_BEND_OFFSET_X", "min_effective": -21.763595, "max_effective": 21.763595}], "Rear emitted texture carries the approved source-local Bend contract")
		if layer.modulations.is_empty() or slot < 0:
			continue
		var binding: Dictionary = layer.modulations[0]
		t.expect_true(binding.source == {"type": "RUNTIME_INPUT", "input": "turn_rate_normalized"} and binding.target == "VISUAL_BEND_OFFSET_X" and binding.operation == "ADD", "Rear reuses signed turn input and ADD target")
		var specs: Array = plan.phase_named("loop").layer_specs()
		var spec = specs.filter(func(s): return s.layer_id() == layer.id)[0]
		var state = evaluator.create_effective_state(spec)
		for pair in [[-1.0, -21.763595], [-0.2, -21.763595], [-0.1, -10.8817975], [0.0, 0.0], [0.1, 10.8817975], [0.2, 21.763595], [1.0, 21.763595]]:
			inputs.set_named_value(program, "turn_rate_normalized", pair[0])
			evaluator.refresh(0.0, [state])
			t.expect_true(absf(state.effective_value(slot) - pair[1]) < 0.000001, "Generic evaluator preserves Super Booster sign and final target clamp")
	var service = preload("res://src/export/vfx_export_service.gd").new()
	service._ensure_ready()
	var compiled = service._compiler.compile(Pipeline.new().load_and_validate(PATH).value)
	t.expect_true(compiled.success, "In-memory compilation succeeds without package writer")
	if compiled.success:
		var runtime: Dictionary = JSON.parse_string(compiled.value.runtime_text())
		t.expect_true(runtime.runtime_definition_version == 2 and runtime.runtime_inputs.size() == 1 and runtime.runtime_inputs[0].name == "turn_rate_normalized", "Real Bend binding selects Runtime v2")
		for phase in runtime.phases:
			for layer in phase.layers:
				var authored: Dictionary = data.phases[phase.name].layers.filter(func(l): return l.id == layer.id)[0]
				t.expect_true(layer.get("visual_bend") == authored.get("visual_bend") and layer.get("modulations", []) == authored.modulations and layer.get("modulation_clamps", []) == authored.modulation_clamps and layer.transform.get("modulation_pivot_local", [0.0, 0.0]) == authored.transform.modulation_pivot_local, "Existing v2 projection serializes metadata/pivot/bindings/clamp unchanged")
	var pipeline = Pipeline.new()
	var document = pipeline.build_document_from_value(data, PATH)
	var encoded = pipeline.serialize_document(document.value)
	var decoded = preload("res://src/model/vfx_preset_codec.gd").new().decode_text(encoded.value, PATH)
	var reloaded = pipeline.build_document_from_value(decoded.value, PATH)
	t.expect_true(reloaded.success and reloaded.value.normalized_data == data, "Bend source round-trip preserves normalized particle authoring")
	var snapshots := []
	for turn in [-1.0, 0.0, 1.0]:
		var session = preload("res://src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd").new(program)
		session.set_named_value(program, "turn_rate_normalized", turn)
		var rt = Support._runtime(plan)
		rt.set_runtime_input_state(session)
		rt.activate_phase("loop", {})
		rt.advance(0.7, {})
		var geometry := []
		for packet in rt.draw_packets():
			geometry.append([packet.layer_id, packet.position, packet.size, packet.alpha, packet.rotation_degrees, packet.geometry_scale])
		snapshots.append(geometry)
	t.expect_true(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2], "Preview deliberately remains straight fallback with identical particle packets across turn values")
