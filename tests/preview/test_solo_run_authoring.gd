extends SceneTree

const Pipeline := preload("res://src/app/vfx_preset_pipeline.gd")
const Builder := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const Support := preload("res://tests/preview/test_rotor_lift_downwash_authoring.gd")
const PATH := "res://presets/examples/talent.solo_run.vfx.json"


func _init() -> void:
	call_deferred("_focused")


func _focused() -> void:
	var t := preload("res://tests/support/test_assert.gd").new()
	if "--motion-only" not in OS.get_cmdline_user_args():
		preload("res://tests/unit/test_runtime_modulation_contract.gd").run(t)
		var booster = preload("res://tests/preview/test_super_booster_bend_authoring.gd")
		booster.check_preset(t, "res://presets/examples/equipment.super_booster.vfx.json", 6)
		booster.check_preset(t, "res://presets/examples/equipment.super_booster.dual.vfx.json", 12)
	run(t)
	print("SOLO_P3_FOCUSED assertions=%d failures=%d" % [t.assertion_count(), t.failure_count()])
	quit(1 if t.failure_count() else 0)


static func run(t: TestAssert) -> void:
	var loaded = Pipeline.new().load_and_validate(PATH)
	t.expect_true(loaded.success, "Particle-only prototype validates")
	if not loaded.success:
		return
	var data: Dictionary = loaded.value.normalized_data
	var built = Builder.new(Support._registry()).build(data)
	t.expect_true(built.success, "Prototype builds in existing Preview")
	if not built.success:
		return
	if "--motion-only" not in OS.get_cmdline_user_args():
		_check_particle_bend(t, data, built.value)
	var rear_only := true
	for phase in data.phases.values():
		for layer in phase.layers:
			rear_only = rear_only and layer.type == "PARTICLE" and str(layer.id).begins_with("loop.rear_flow_") and str(layer.parameters.sprite_asset_ref).begins_with("fx.solo_run_rear_streak_")
	t.expect_true(rear_only and data.phases.start.layers.is_empty() and data.phases.end.layers.is_empty() and data.phases.loop.layers.size() == 2, "Only Rear L/R particles remain in all phases; no Side references or static sprites")
	for side in ["left", "right"]:
		var layers: Array = data.phases.loop.layers
		var rear: Dictionary = layers.filter(func(l): return l.id == "loop.rear_flow_" + side)[0]
		t.expect_true(rear.parameters.sprite_asset_ref == "fx.solo_run_rear_streak_" + side and rear.render_plane == "UNDER_VEHICLE" and rear.parameters.max_particles == 1 and rear.importance == "CORE" and rear.parameters.emitter.size == [15.0, 12.0] and rear.transform.offset[1] == 355.5 and rear.parameters.emission_rate_per_second == (1.6 if side == "left" else 1.9), "Rear uses native separate texture below vehicle with cap one")
		var runtime = Support._runtime(built.value)
		runtime.activate_phase("loop", {})
		runtime.advance(1.0 / rear.parameters.emission_rate_per_second + 0.001, {})
		var packets: Array = runtime.draw_packets().filter(func(p): return p.layer_id == rear.id)
		t.expect_true(packets.size() == 1, "Rear emits one wave")
		if packets.size() != 1:
			continue
		var birth: Dictionary = packets[0].duplicate(true)
		runtime.stop_phase_sources("loop")
		runtime.advance(0.549, {})
		packets = runtime.draw_packets().filter(func(p): return p.layer_id == rear.id)
		t.expect_true(packets.size() == 1, "Rear survives to just before expiry")
		if packets.is_empty():
			continue
		var jitter: Vector2 = birth.position - Vector2(rear.transform.offset[0], rear.transform.offset[1])
		t.expect_true(absf(jitter.x) <= 7.5 and absf(jitter.y) <= 6.0, "Rear spawn stays within compact BOX")
		var delta: Vector2 = packets[0].position - birth.position
		var visible_length: float = 2.0 * float(birth.size)
		t.expect_true(delta.y / visible_length >= 0.10 and delta.y / visible_length <= 0.15 and packets[0].alpha < 0.002 and packets[0].rotation_degrees == 0, "Rear travels only 10-15 percent of birth length and fades without rotation")
		print("SOLO_P29_REAR ", side, " birth_size=", birth.size, " end_size=", packets[0].size, " travel=", delta, " ratio=", delta.y / visible_length)
		runtime.advance(0.452, {})
		t.expect_true(runtime.draw_packets().is_empty() and not runtime.has_residual(), "All stopped Rear particles clean up")
	var rt = Support._runtime(built.value)
	rt.activate_phase("loop", {})
	rt.advance(0.7, {})
	var packets: Array = rt.draw_packets()
	t.expect_true(packets.size() == 2 and packets.all(func(p): return str(p.layer_id).begins_with("loop.rear_flow_")), "Visible packets contain only two moving Rear waves")
	rt.stop_phase_sources("loop")
	rt.advance(0.551, {})
	t.expect_true(rt.draw_packets().is_empty() and not rt.has_residual(), "Rear-only sources clean up after emission stops")

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
	var compiled = preload("res://src/export/vfx_export_service.gd").new().validate_saved_source(PATH)
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
