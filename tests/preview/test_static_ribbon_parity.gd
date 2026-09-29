extends SceneTree
## Read-only Game reference; production scripts never depend on this path.
const GAME := "C:/GodotProjects/DesktopIdleRacing/"
const PATH := "res://presets/examples/talent.solo_run.static_ribbon.vfx.json"
const Support := preload("res://tests/preview/test_rotor_lift_downwash_authoring.gd")
const Host := preload("res://src/preview/curve_flow/vfx_curve_flow_static_host.gd")
var t = preload("res://tests/support/test_assert.gd").new()
func _init() -> void: call_deferred("run")
func run() -> void:
	var loaded = preload("res://src/app/vfx_preset_pipeline.gd").new().load_and_validate(PATH)
	var plan = preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd").new(Support._registry()).build(loaded.value.normalized_data).value
	var runtime = Support._runtime(plan)
	var second = Support._runtime(plan)
	runtime.activate_phase("loop", {}); second.activate_phase("loop", {})
	var packets: Array = runtime.draw_packets()
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/compatibility/curve_flow_f1.vfx.json"))
	var eval_script := GDScript.new()
	eval_script.source_code = FileAccess.get_file_as_string(GAME + "scripts/vfx/runtime/curve_flow/vfx_curve_flow_evaluator.gd")
	t.expect_true(eval_script.reload() == OK, "Actual Game evaluator compiles without running Game")
	var build_source := FileAccess.get_file_as_string(GAME + "scripts/vfx/prototypes/CurveFlowStaticRibbonRenderer.gd")
	var builder_script := GDScript.new()
	builder_script.source_code = "extends Node2D\nconst SAMPLE_STEP := 3.0\nconst WIDTH_FACTOR := 1.5\nconst HEAD_CAPACITY := 64\nvar flow: RefCounted\n" + build_source.get_slice("func _build_ribbon",1).get_slice("func advance",0).insert(0,"func _build_ribbon")
	t.expect_true(builder_script.reload() == OK, "Actual Game ribbon build method compiles")
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string(GAME + "scripts/vfx/prototypes/curve_flow_static_ribbon.gdshader")
	var references := []
	var views := []
	var hosts := [[],[]]
	for which in 2:
		var view := SubViewport.new(); view.size = Vector2i(1152,648)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view); views.append(view)
		for zoom in [1.0,4.4]:
			var rig := Node2D.new(); rig.position=Vector2(288 if zoom==1 else 864,305); rig.scale=Vector2.ONE*.095*zoom
			rig.rotation = .16
			view.add_child(rig)
			for i in 8:
				if i == 6:
					var car := Sprite2D.new(); car.texture=load("res://assets/reference/vehicles/hyper_reference.png"); rig.add_child(car)
				var packet: Dictionary = packets[i]
				var mesh_host: MeshInstance2D
				if which == 0:
					var flow = eval_script.new()
					flow.configure([preload("res://src/preview/curve_flow/vfx_curve_flow_contract.gd").lane(old.phases.loop.layers[i].parameters)])
					var builder = builder_script.new(); builder.flow = flow
					mesh_host = MeshInstance2D.new(); mesh_host.mesh = builder._build_ribbon(flow.lanes[0]); builder.free()
					var mat := ShaderMaterial.new(); mat.shader=shader
					var p: Dictionary = flow.lanes[0]
					var native: bool = p.texture_mode == "NATIVE_STRAND"
					mat.set_shader_parameter("native_strand",native)
					mat.set_shader_parameter("strand_texture" if native else "flow_texture",packet.asset.texture)
					mat.set_shader_parameter("segment_length",float(p.length)); mat.set_shader_parameter("path_length",float(flow.tables[0].length))
					mat.set_shader_parameter("brightness",float(p.brightness)); mat.set_shader_parameter("texture_phase",float(p.texture_phase))
					mesh_host.material=mat
					references.append(flow)
					var a: Array = mesh_host.mesh.surface_get_arrays(0)
					var b: Array = packet.curve_geometry.mesh.surface_get_arrays(0)
					var error := 0.0
					for v in a[Mesh.ARRAY_VERTEX].size(): error=maxf(error,a[Mesh.ARRAY_VERTEX][v].distance_to(b[Mesh.ARRAY_VERTEX][v]))
					t.expect_true(error<.001 and a[Mesh.ARRAY_COLOR]==b[Mesh.ARRAY_COLOR] and a[Mesh.ARRAY_TEX_UV]==b[Mesh.ARRAY_TEX_UV],"Game fixed mesh parity lane "+str(i))
				else:
					mesh_host = Host.new(); mesh_host.geometry=packet.curve_geometry; mesh_host.evaluator=packet.curve_flow; mesh_host.configure(packet.asset.texture)
					var other: Dictionary = second.draw_packets()[i]
					t.expect_true(mesh_host.mesh == other.curve_geometry.mesh and not is_same(packet.curve_flow,other.curve_flow),"Shared immutable geometry / independent flow")
				rig.add_child(mesh_host); hosts[which].append(mesh_host)
	var original_mesh: Mesh = hosts[1][0].mesh
	var canvas = preload("res://src/preview/rendering/vfx_preview_canvas_render_host.gd").new()
	root.add_child(canvas); canvas.apply_packets([packets[0]])
	var edited: Dictionary = loaded.value.normalized_data.duplicate(true)
	edited.phases.loop.layers[0].parameters.half_width = 46.0
	var edit_plan = preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd").new(Support._registry()).build(edited).value
	var edit_runtime = Support._runtime(edit_plan); edit_runtime.activate_phase("loop",{})
	canvas.apply_packets([edit_runtime.draw_packets()[0]])
	t.expect_true(canvas._curve_adapters.values()[0].mesh == edit_runtime.draw_packets()[0].curve_geometry.mesh,"Edited plan replaces static geometry without stale cache")
	canvas.queue_free()
	t.expect_true(is_same(packets[0].curve_geometry, runtime.draw_packets()[0].curve_geometry),"Packets reuse prepared resource, not table deep copies")
	t.expect_true(packets[0].curve_geometry.tables.is_read_only() and packets[0].curve_geometry.tables[0].points.is_read_only(),"Prepared tables are read-only")
	t.expect_true(hosts[1][0].material != hosts[1][8].material,"Views have independent materials")
	for tick in 240:
		if tick == 120:
			runtime.stop_phase_sources("loop"); runtime.activate_phase("end", {})
			for flow in references: flow.stop()
		runtime.advance(1.0/60, {})
		for i in references.size():
			var flow = references[i]; flow.advance(1.0/60)
			var heads := PackedFloat32Array(); heads.resize(64)
			for j in flow.segments.size(): heads[j]=flow.segments[j].head
			hosts[0][i].material.set_shader_parameter("heads",heads)
			hosts[0][i].material.set_shader_parameter("active_count",flow.segments.size())
			hosts[0][i].visible=not flow.segments.is_empty()
			var formal = packets[i%8].curve_flow
			t.expect_true(flow.segments == formal.segments and flow.birth_count == formal.birth_count,"Game birth/head/drain parity")
		for host in hosts[1]: host.refresh()
		if tick in [17,89,149,239]:
			await process_frame; await RenderingServer.frame_post_draw
			var a: Image = views[0].get_texture().get_image(); var b: Image = views[1].get_texture().get_image()
			var max_delta := 0.0; var changed := 0
			for y in a.get_height():
				for x in a.get_width():
					var ca:=a.get_pixel(x,y); var cb:=b.get_pixel(x,y)
					var d:=maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b)))
					max_delta=maxf(max_delta,d)
					if d>1.0/255+.00001: changed+=1
			print("STATIC_GL tick=",tick+1," max_delta=",max_delta," changed_gt_1byte=",changed)
			t.expect_true(changed==0,"Game approved static GL parity")
			if tick==89: a.save_png("user://static_game_reference.png"); b.save_png("user://static_studio.png")
	t.expect_true(hosts[1][0].mesh==original_mesh,"Same mesh through motion and drain")
	t.expect_true(not runtime.has_residual() and second.draw_packets()[0].curve_flow.time==0,"Drain complete, other instance unaffected")
	second.advance(.5,{}); second.clear()
	t.expect_true(second.draw_packets().is_empty(),"Force clear immediate")
	runtime.clear(); runtime.activate_phase("loop",{})
	t.expect_true(runtime.draw_packets()[0].curve_geometry.mesh==original_mesh and runtime.draw_packets()[0].curve_flow.time==0,"Restart reuses geometry with fresh schedule")
	for view in views: view.queue_free()
	await process_frame
	var editor = load("res://src/editor/main/vfx_editor_main.tscn").instantiate(); root.size=Vector2i(1600,1000); root.add_child(editor)
	await process_frame
	t.expect_true(editor.editor_controller.open_path(PATH).success,"Normal editor opens static preset")
	editor.editor_controller.select_phase("loop")
	var workspace = editor.get_node("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PreviewHost").get_child(0)
	workspace.vehicle_preview()._on_auto_playback_toggled(false); workspace.vehicle_preview()._on_play_preview_pressed()
	for frame in 45: await process_frame
	t.expect_true(workspace.vehicle_preview()._render_runtime.draw_packets().size()==8,"Normal editor plays eight static lanes")
	var live_hosts: Array = editor.find_children("*", "MeshInstance2D", true, false).filter(func(n): return n.get_script() == Host)
	t.expect_true(not live_hosts.is_empty(), "Static hosts exist in normal editor")
	var identities: Array = live_hosts.map(func(n): return [n.get_instance_id(), n.material.get_instance_id()])
	for frame in 3: await process_frame
	var later: Array = editor.find_children("*", "MeshInstance2D", true, false).filter(func(n): return n.get_script() == Host)
	t.expect_true(identities == later.map(func(n): return [n.get_instance_id(), n.material.get_instance_id()]), "Normal editor keeps static host/material identity across frames")
	editor.queue_free(); await process_frame
	# One slot / two ticks is a lifecycle test, not a stress/performance measurement.
	var slot = preload("res://src/preview/performance/vfx_stress_vehicle_slot.gd").new(Support._registry(), preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd").new(), preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd").new(preload("res://src/preview/rendering/vfx_preview_asset_registry.gd").new()))
	root.add_child(slot)
	slot.configure([plan], {"anchors":{"CENTER":[0,0]}}, Vector2.ONE, "STEADY_LOOP")
	slot.set_vfx_enabled(true); slot.advance(.5)
	await process_frame
	var slot_hosts: Array = slot.find_children("*", "MeshInstance2D", true, false).filter(func(n): return n.get_script() == Host)
	var slot_ids: Array = slot_hosts.map(func(n): return n.get_instance_id())
	slot.advance(.1); await process_frame
	t.expect_true(not slot_ids.is_empty() and slot_ids == slot.find_children("*", "MeshInstance2D", true, false).filter(func(n): return n.get_script() == Host).map(func(n): return n.get_instance_id()),"Single-slot presentation retains adapters")
	slot.set_vfx_enabled(false); slot.queue_free(); await process_frame
	print("STATIC_PARITY assertions=",t.assertion_count()," failures=",t.failure_count())
	quit(1 if t.failure_count() else 0)
