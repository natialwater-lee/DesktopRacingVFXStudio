extends RefCounted

const VfxPreviewLayerSpecModel := preload("res://src/preview/rendering/vfx_preview_layer_spec.gd")
const VfxPreviewRenderInstanceSpecModel := preload("res://src/preview/rendering/vfx_preview_render_instance_spec.gd")


static func run(tests: TestAssert) -> void:
	_test_glow_pulse_uses_documented_opacity_range(tests)
	_test_ring_repeats_only_while_source_active(tests)
	_test_ring_lifetime_alpha_uses_each_repeated_instance_age(tests)
	_test_shield_packet_preserves_declared_arc_and_scroll(tests)
	_test_textured_shield_uses_a_dedicated_arc_adapter(tests)


static func _test_glow_pulse_uses_documented_opacity_range(tests: TestAssert) -> void:
	var renderer_script := load("res://src/preview/rendering/vfx_glow_layer_renderer.gd") as Script
	tests.expect_true(renderer_script != null, "Glow Preview Renderer script is available")
	if renderer_script == null:
		return
	var renderer = renderer_script.new(_instance("GLOW", {"radius": 10.0, "opacity": 0.8, "pulse_hz": 1.0}), {})
	renderer.restart({})
	renderer.advance(0.25, {})
	var packets: Array = renderer.draw_packets()
	var alpha: float = float(packets[0].get("alpha", -1.0)) if not packets.is_empty() else -1.0
	tests.expect_true(is_equal_approx(alpha, 0.8), "Glow pulse reaches declared opacity at its sine peak without an undeclared amplitude")
	renderer.restart({})
	renderer.advance(0.0, {})
	var start_alpha: float = float(renderer.draw_packets()[0].get("alpha", -1.0))
	tests.expect_true(is_equal_approx(start_alpha, 0.4), "Glow pulse starts at half declared opacity and pulse_hz zero remains a separate constant case")


static func _test_ring_repeats_only_while_source_active(tests: TestAssert) -> void:
	var renderer_script := load("res://src/preview/rendering/vfx_ring_layer_renderer.gd") as Script
	tests.expect_true(renderer_script != null, "Ring Preview Renderer script is available")
	if renderer_script == null:
		return
	var renderer = renderer_script.new(_instance("RING", {"radius_start": 2.0, "radius_end": 10.0, "width": 1.0, "duration_seconds": 1.0, "repeat_interval_seconds": 0.5, "alpha_start": 1.0, "alpha_end": 1.0}), {})
	renderer.restart({})
	renderer.advance(0.5, {})
	var packets: Array = renderer.draw_packets()
	var first_radius: float = float(packets[0].get("radius", -1.0)) if not packets.is_empty() else -1.0
	tests.expect_true(packets.size() == 2 and is_equal_approx(first_radius, 6.0) and packets.all(func(packet: Dictionary) -> bool: return is_equal_approx(float(packet.get("alpha", -1.0)), 1.0)), "Ring repeats at its declared interval while alpha one-to-one preserves existing visual output")
	renderer.stop_emission()
	renderer.advance(0.5, {})
	tests.expect_true(renderer.draw_packets().size() == 1, "Stopping a Ring source prevents repeats while its already-created residual remains for duration")


static func _test_ring_lifetime_alpha_uses_each_repeated_instance_age(tests: TestAssert) -> void:
	var renderer_script := load("res://src/preview/rendering/vfx_ring_layer_renderer.gd") as Script
	if renderer_script == null:
		tests.expect_true(false, "Ring lifetime alpha test requires the Ring Renderer")
		return
	var renderer = renderer_script.new(_instance("RING", {
		"radius_start": 2.0,
		"radius_end": 10.0,
		"width": 1.0,
		"duration_seconds": 1.0,
		"repeat_interval_seconds": 0.5,
		"alpha_start": 1.0,
		"alpha_end": 0.0
	}), {})
	renderer.restart({})
	renderer.advance(0.5, {})
	var packets: Array = renderer.draw_packets()
	var oldest: Dictionary = packets[0] if packets.size() > 0 else {}
	var newest: Dictionary = packets[1] if packets.size() > 1 else {}
	tests.expect_true(packets.size() == 2 and is_equal_approx(float(oldest.get("radius", -1.0)), 6.0) and is_equal_approx(float(oldest.get("alpha", -1.0)), 0.5) and is_equal_approx(float(newest.get("radius", -1.0)), 2.0) and is_equal_approx(float(newest.get("alpha", -1.0)), 1.0), "Repeated Rings derive radius and lifetime alpha from each instance's own normalized age")


static func _test_shield_packet_preserves_declared_arc_and_scroll(tests: TestAssert) -> void:
	var renderer_script := load("res://src/preview/rendering/vfx_shield_layer_renderer.gd") as Script
	tests.expect_true(renderer_script != null, "Shield Preview Renderer script is available")
	if renderer_script == null:
		return
	var renderer = renderer_script.new(_instance("SHIELD", {"radius": 12.0, "arc_degrees": 180.0, "thickness": 2.0, "opacity": 0.75, "scroll_speed": 4.0}), {})
	renderer.restart({})
	renderer.advance(0.25, {})
	var packets: Array = renderer.draw_packets()
	var packet: Dictionary = packets[0] if not packets.is_empty() else {}
	tests.expect_true(packet.get("arc_degrees") == 180.0 and is_equal_approx(float(packet.get("scroll_offset", -1.0)), 1.0), "Shield packet uses declared arc geometry and advances only its declared texture-scroll coordinate")
	tests.expect_true(packet.get("alpha") == 0.75 and packet.get("render_plane") == "OVER_VEHICLE", "Shield packet preserves declared opacity and plane without an implicit visual layer")


static func _test_textured_shield_uses_a_dedicated_arc_adapter(tests: TestAssert) -> void:
	var host_script := load("res://src/preview/rendering/vfx_preview_canvas_render_host.gd") as Script
	if host_script == null:
		tests.expect_true(false, "Textured Shield test requires the Canvas Render Host")
		return
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var host: Variant = host_script.new()
	host.apply_packets([{
		"layer_id": "shield.textured",
		"type": "SHIELD",
		"position": Vector2.ZERO,
		"geometry_scale": Vector2.ONE,
		"geometry_rotation_degrees": 0.0,
		"radius": 8.0,
		"arc_degrees": 180.0,
		"thickness": 2.0,
		"scroll_offset": 0.5,
		"color_rgba": [1.0, 1.0, 1.0, 1.0],
		"asset": {"texture": ImageTexture.create_from_image(image)}
	}])
	tests.expect_true(host.get_node_or_null("ShieldAdapter_shield_textured_0") != null, "Textured Shield packets route through a dedicated fixed-shader arc adapter so scroll_offset can affect texture UVs")
	host.free()


static func _instance(layer_type: String, parameters: Dictionary) -> RefCounted:
	var spec := VfxPreviewLayerSpecModel.new("test.%s" % layer_type.to_lower(), layer_type, "CORE", "ADDITIVE", "OVER_VEHICLE", "VEHICLE_LOCAL", ["CENTER"], {"offset": [0.0, 0.0], "rotation_degrees": 0.0, "scale": [1.0, 1.0]}, parameters, true, 0, 0)
	return VfxPreviewRenderInstanceSpecModel.new("loop", spec, "CENTER", Vector2.ZERO, 0)
