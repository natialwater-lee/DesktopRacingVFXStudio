extends SceneTree
const PATH := "res://presets/examples/talent.solo_run.static_ribbon.vfx.json"
const Support := preload("res://tests/preview/test_rotor_lift_downwash_authoring.gd")
func _init() -> void: call_deferred("_focused")
func _focused() -> void:
	var t = preload("res://tests/support/test_assert.gd").new()
	run(t)
	print("SOLO_FINAL assertions=",t.assertion_count()," failures=",t.failure_count())
	quit(1 if t.failure_count() else 0)
static func run(t: TestAssert) -> void:
	var pipeline = preload("res://src/app/vfx_preset_pipeline.gd").new()
	var library = preload("res://src/editor/library/vfx_preset_library.gd").new(pipeline,preload("res://src/editor/application/vfx_authoring_paths.gd").new())
	var solo: Array = library.scan().filter(func(e): return str(e.preset_id).begins_with("talent.solo_run"))
	t.expect_true(solo.size()==1 and solo[0].preset_id=="talent.solo_run.static_ribbon","Editor exposes only final Solo Run")
	var loaded = pipeline.load_and_validate(PATH)
	t.expect_true(loaded.success,"Final Solo Run validates")
	if not loaded.success: return
	var layers: Array = loaded.value.normalized_data.phases.loop.layers
	t.expect_true(layers.size()==8 and layers.all(func(l): return l.type=="CURVE_FLOW" and l.parameters.profile_version==2),"Eight static F2 lanes")
	for i in layers.size():
		t.expect_true(layers[i].parameters.half_width==[45.0,17.1,13.5,45.0,17.1,13.5,18.0,18.0][i],"Approved final width")
	var plan = preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd").new(Support._registry()).build(loaded.value.normalized_data).value
	var runtime = Support._runtime(plan)
	runtime.activate_phase("loop",{}); runtime.advance(1.5,{})
	t.expect_true(runtime.draw_packets().size()==8 and runtime.draw_packets().all(func(p):return p.has("curve_geometry")),"Final playback uses shared static geometry")
	runtime.stop_phase_sources("loop"); runtime.activate_phase("end",{})
	runtime.advance(3.0,{})
	t.expect_true(not runtime.has_residual(),"Final emission stop drains")
	runtime.clear()
	t.expect_true(runtime.draw_packets().is_empty(),"Final force clear")
	preload("res://tests/preview/test_particle_bend_compatibility.gd").run(t)
	preload("res://tests/preview/test_curve_flow_authoring.gd").run(t)
