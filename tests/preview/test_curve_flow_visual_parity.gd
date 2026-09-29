extends SceneTree
## F1 GL compatibility smoke; retired prototype pixel comparator is no longer required.
const Support := preload("res://tests/preview/test_rotor_lift_downwash_authoring.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var loaded = preload("res://src/app/vfx_preset_pipeline.gd").new().load_and_validate("res://tests/fixtures/compatibility/curve_flow_f1.vfx.json")
	var plan = preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd").new(Support._registry()).build(loaded.value.normalized_data).value
	var runtime = Support._runtime(plan)
	runtime.activate_phase("loop", {})
	runtime.advance(1.5, {})
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host = preload("res://src/preview/rendering/vfx_preview_canvas_render_host.gd").new()
	host.position = Vector2(128,90)
	host.scale = Vector2.ONE * 0.2
	viewport.add_child(host)
	host.set_blend_mode("ADDITIVE")
	host.apply_packets(runtime.draw_packets())
	for tick in 3: await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image().get_used_rect().has_area()
	print("F1_GL_COMPAT visible=", rendered)
	viewport.queue_free()
	await process_frame
	quit(0 if rendered else 1)
