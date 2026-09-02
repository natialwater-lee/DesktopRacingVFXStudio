extends RefCounted

const VfxPreviewLayerSpecModel := preload("res://src/preview/rendering/vfx_preview_layer_spec.gd")
const VfxPreviewRenderInstanceSpecModel := preload("res://src/preview/rendering/vfx_preview_render_instance_spec.gd")
const VfxPreviewRendererFactoryModel := preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")


static func run(tests: TestAssert) -> void:
	_test_textured_sprite_keeps_one_static_packet_until_its_phase_stops(tests)
	_test_headlight_art_resolves_through_generic_texture_lookup(tests)


static func _test_textured_sprite_keeps_one_static_packet_until_its_phase_stops(tests: TestAssert) -> void:
	var factory := VfxPreviewRendererFactoryModel.new()
	var renderer_script: Variant = factory.renderer_registration("TEXTURED_SPRITE")
	tests.expect_true(renderer_script is Script, "TEXTURED_SPRITE has a registered generic Preview Renderer")
	if not renderer_script is Script:
		return
	var image := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var renderer = renderer_script.new(_instance(), {"source": "TEXTURE", "texture": texture})
	renderer.restart({})
	var initial: Array = renderer.draw_packets()
	renderer.advance(1.0, {})
	var advanced: Array = renderer.draw_packets()
	var first: Dictionary = initial[0] if initial.size() == 1 else {}
	var second: Dictionary = advanced[0] if advanced.size() == 1 else {}
	tests.expect_true(
		initial.size() == 1
		and advanced.size() == 1
		and first.get("asset", {}).get("texture") == texture
		and second.get("asset", {}).get("texture") == texture
		and first.get("position") == Vector2(12.0, -18.0)
		and first.get("geometry_rotation_degrees") == 30.0
		and first.get("geometry_scale") == Vector2(1.5, 0.75)
		and first.get("alpha") == 0.65
		and first.get("blend_mode") == "ALPHA"
		and first.get("render_plane") == "UNDER_VEHICLE",
		"TEXTURED_SPRITE keeps one texture-backed packet with common offset, rotation, non-uniform scale, alpha, blend, and plane metadata instead of spawning particles every frame"
	)
	renderer.stop_emission()
	tests.expect_true(renderer.draw_packets().is_empty() and not renderer.is_source_active() and not renderer.has_residual(), "TEXTURED_SPRITE releases its single packet when its active phase stops")


static func _test_headlight_art_resolves_through_generic_texture_lookup(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var core: VfxResult = resolver.resolve("fx.headlight_beam_core")
	var soft: VfxResult = resolver.resolve("fx.headlight_beam_soft")
	tests.expect_true(core.success and soft.success and core.value.get("source") == "TEXTURE" and soft.value.get("source") == "TEXTURE" and core.value.get("texture") is Texture2D and soft.value.get("texture") is Texture2D, "Headlight beam art resolves through the generic TEXTURED_SPRITE asset path without a Headlight renderer branch")


static func _instance() -> RefCounted:
	var spec := VfxPreviewLayerSpecModel.new(
		"loop.static_texture",
		"TEXTURED_SPRITE",
		"CORE",
		"ALPHA",
		"UNDER_VEHICLE",
		"VEHICLE_LOCAL",
		["CENTER"],
		{"offset": [12.0, -18.0], "rotation_degrees": 30.0, "scale": [1.5, 0.75]},
		{"texture_asset_ref": "fx.headlight_beam_core", "opacity": 0.65},
		true,
		0,
		0
	)
	return VfxPreviewRenderInstanceSpecModel.new("loop", spec, "CENTER", Vector2.ZERO, 0)
