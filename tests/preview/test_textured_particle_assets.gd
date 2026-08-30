extends RefCounted

const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxPreviewLayerSpecModel := preload("res://src/preview/rendering/vfx_preview_layer_spec.gd")
const VfxPreviewRenderInstanceSpecModel := preload("res://src/preview/rendering/vfx_preview_render_instance_spec.gd")
const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const VfxPreviewRendererFactoryModel := preload("res://src/preview/rendering/vfx_preview_renderer_factory.gd")
const VfxPreviewRenderRuntimeModel := preload("res://src/preview/rendering/vfx_preview_render_runtime.gd")

const FIXTURE_CATALOG_PATH := "res://tests/fixtures/preview/vfx_preview_texture_test_catalog.json"


static func run(tests: TestAssert) -> void:
	_test_catalog_resolves_procedural_and_textured_assets(tests)
	_test_zero_zone_production_art_assets_resolve_as_textures(tests)
	_test_invalid_textures_use_cached_preview_warning_fallback(tests)
	_test_texture_particle_rect_preserves_half_size_and_aspect(tests)
	_test_texture_particle_packet_preserves_authoring_tint_and_layer_scale(tests)
	_test_textured_particle_uses_the_same_lifetime_alpha_scalar(tests)
	_test_zero_zone_uses_distinct_shard_and_spark_logical_assets(tests)
	_test_renderer_showcase_uses_the_ordinary_texture_particle_route(tests)


static func _test_catalog_resolves_procedural_and_textured_assets(tests: TestAssert) -> void:
	var resolver := _resolver()
	var procedural: VfxResult = resolver.resolve("fx.procedural_particle_test")
	var texture_first: VfxResult = resolver.resolve("fx.texture_particle_test")
	var texture_second: VfxResult = resolver.resolve("fx.texture_particle_test")
	var texture: Texture2D = texture_first.value.get("texture") as Texture2D if texture_first.success else null
	var image := texture.get_image() if texture != null else null
	var source_and_cache_are_correct: bool = procedural.success \
		and procedural.value.get("source") == "PROCEDURAL" \
		and procedural.value.get("primitive") == "DIAMOND" \
		and texture_first.success \
		and texture_first.value.get("source") == "TEXTURE" \
		and texture != null \
		and texture_second.success \
		and texture_second.value.get("texture") == texture
	tests.expect_true(source_and_cache_are_correct, "Preview Asset Resolver distinguishes PROCEDURAL and TEXTURE catalog sources and caches one Texture2D per logical ID")
	tests.expect_true(image != null and image.get_size() == Vector2i(4, 6) and is_zero_approx(image.get_pixel(0, 0).a) and is_equal_approx(image.get_pixel(2, 1).a, 1.0), "TEXTURE catalog resolution preserves the transparent PNG dimensions and alpha channel")


static func _test_zero_zone_production_art_assets_resolve_as_textures(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var shard_result: VfxResult = resolver.resolve("fx.energy_shard")
	var spark_result: VfxResult = resolver.resolve("fx.energy_spark")
	var flow_result: VfxResult = resolver.resolve("fx.zero_zone_flow_streak")
	var shard_texture: Texture2D = shard_result.value.get("texture") as Texture2D if shard_result.success else null
	var spark_texture: Texture2D = spark_result.value.get("texture") as Texture2D if spark_result.success else null
	var flow_texture: Texture2D = flow_result.value.get("texture") as Texture2D if flow_result.success else null
	var shard_image := shard_texture.get_image() if shard_texture != null else null
	var spark_image := spark_texture.get_image() if spark_texture != null else null
	var flow_image := flow_texture.get_image() if flow_texture != null else null
	var has_production_textures: bool = shard_result.success \
		and spark_result.success \
		and flow_result.success \
		and shard_result.issues.is_empty() \
		and spark_result.issues.is_empty() \
		and flow_result.issues.is_empty() \
		and shard_result.value.get("source") == "TEXTURE" \
		and spark_result.value.get("source") == "TEXTURE" \
		and flow_result.value.get("source") == "TEXTURE" \
		and not shard_result.value.get("is_fallback", true) \
		and not spark_result.value.get("is_fallback", true) \
		and not flow_result.value.get("is_fallback", true) \
		and shard_texture != null \
		and spark_texture != null \
		and flow_texture != null \
		and shard_image != null \
		and spark_image != null \
		and flow_image != null \
		and shard_image.get_size() == Vector2i(64, 64) \
		and spark_image.get_size() == Vector2i(32, 32) \
		and flow_image.get_size() == Vector2i(64, 128) \
		and _has_transparent_pixel(shard_image) \
		and _has_transparent_pixel(spark_image) \
		and _has_transparent_pixel(flow_image)
	tests.expect_true(has_production_textures, "Zero Zone Production Art resolves shard, spark, and 64x128 forward-flow textures as non-fallback Texture2D assets")
	var host_script := load("res://src/preview/rendering/vfx_preview_canvas_render_host.gd") as Script
	var host: Node2D = host_script.new() if host_script != null else null
	var shard_rect: Rect2 = host.call("texture_particle_rect", shard_texture, 5.0) if host != null and shard_texture != null else Rect2()
	var spark_rect: Rect2 = host.call("texture_particle_rect", spark_texture, 5.0) if host != null and spark_texture != null else Rect2()
	var flow_rect: Rect2 = host.call("texture_particle_rect", flow_texture, 5.0) if host != null and flow_texture != null else Rect2()
	tests.expect_true(host != null and shard_rect.size == Vector2(10.0, 10.0) and spark_rect.size == Vector2(10.0, 10.0) and flow_rect.size == Vector2(5.0, 10.0), "Production texture native dimensions preserve the 2 times packet.size longest display dimension and the flow 1:2 aspect")
	if host != null:
		host.free()


static func _test_invalid_textures_use_cached_preview_warning_fallback(tests: TestAssert) -> void:
	var resolver := _resolver()
	var missing_path: VfxResult = resolver.resolve("fx.texture_missing_path")
	var missing_file_first: VfxResult = resolver.resolve("fx.texture_missing_file")
	var missing_file_second: VfxResult = resolver.resolve("fx.texture_missing_file")
	tests.expect_true(missing_path.success and missing_path.value.get("is_fallback", false) and _has_issue(missing_path, "preview_asset_texture_path_missing"), "TEXTURE entries without texture_path keep the Preset valid and produce a magenta Preview fallback warning")
	tests.expect_true(missing_file_first.success and missing_file_first.value.get("is_fallback", false) and _has_issue(missing_file_first, "preview_asset_texture_load_failed") and missing_file_second.success and missing_file_second.issues.is_empty(), "A missing TEXTURE file produces one cached Preview warning rather than a warning per Particle resolve")


static func _test_texture_particle_rect_preserves_half_size_and_aspect(tests: TestAssert) -> void:
	var host_script := load("res://src/preview/rendering/vfx_preview_canvas_render_host.gd") as Script
	var texture_result: VfxResult = _resolver().resolve("fx.texture_particle_test")
	var host: Node2D = host_script.new() if host_script != null else null
	if host == null or not host.has_method("texture_particle_rect") or not texture_result.success:
		tests.expect_true(false, "Texture Particle drawing exposes a real Canvas rectangle calculation for a resolved Texture2D")
		if host != null:
			host.free()
		return
	var rect: Rect2 = host.call("texture_particle_rect", texture_result.value.get("texture"), 5.0)
	tests.expect_true(is_equal_approx(rect.size.x, 6.6666665) and is_equal_approx(rect.size.y, 10.0) and is_equal_approx(rect.position.x, -3.3333333) and is_equal_approx(rect.position.y, -5.0), "TEXTURE Particle uses packet.size as the half-size of its longest displayed dimension and preserves the native 4 by 6 aspect ratio")
	host.free()


static func _test_texture_particle_packet_preserves_authoring_tint_and_layer_scale(tests: TestAssert) -> void:
	var renderer_script := load("res://src/preview/rendering/vfx_particle_layer_renderer.gd") as Script
	var texture_result: VfxResult = _resolver().resolve("fx.texture_particle_test")
	if renderer_script == null or not texture_result.success:
		tests.expect_true(false, "Texture Particle transform regression requires the existing Particle simulation and resolved Texture2D")
		return
	var parameters := {
		"emission_mode": "BURST",
		"emitter": {"shape": "POINT"},
		"sprite_asset_ref": "fx.texture_particle_test",
		"burst_count": 1,
		"lifetime_seconds": 1.0,
		"speed_min": 0.0,
		"speed_max": 0.0,
		"size_start": 5.0,
		"size_end": 5.0,
		"alpha_start": 1.0,
		"alpha_end": 1.0,
		"color_rgba": [0.2, 0.4, 0.6, 0.75]
	}
	var renderer = renderer_script.new(_particle_instance(parameters), texture_result.value)
	renderer.restart(_frame())
	var packet: Dictionary = renderer.draw_packets()[0] if not renderer.draw_packets().is_empty() else {}
	tests.expect_true(packet.get("asset", {}).get("source") == "TEXTURE" and packet.get("color_rgba") == [0.2, 0.4, 0.6, 0.75] and packet.get("size") == 5.0 and packet.get("geometry_scale") == Vector2(0.75, 0.0625), "TEXTURE Particles retain Layer color, half-size authoring, and transform.scale times Space projection without native-pixel scaling")


static func _test_textured_particle_uses_the_same_lifetime_alpha_scalar(tests: TestAssert) -> void:
	var renderer_script := load("res://src/preview/rendering/vfx_particle_layer_renderer.gd") as Script
	var texture_result: VfxResult = _resolver().resolve("fx.texture_particle_test")
	if renderer_script == null or not texture_result.success:
		tests.expect_true(false, "TEXTURE lifetime alpha requires the existing Particle Renderer and Texture2D route")
		return
	var parameters := {
		"emission_mode": "BURST",
		"emitter": {"shape": "POINT"},
		"sprite_asset_ref": "fx.texture_particle_test",
		"burst_count": 1,
		"lifetime_seconds": 1.0,
		"speed_min": 0.0,
		"speed_max": 0.0,
		"size_start": 5.0,
		"size_end": 5.0,
		"color_rgba": [1.0, 1.0, 1.0, 0.8],
		"alpha_start": 1.0,
		"alpha_end": 0.0
	}
	var renderer = renderer_script.new(_particle_instance(parameters), texture_result.value)
	renderer.restart(_frame())
	renderer.advance(0.5, _frame())
	var packet: Dictionary = renderer.draw_packets()[0] if not renderer.draw_packets().is_empty() else {}
	tests.expect_true(packet.get("asset", {}).get("source") == "TEXTURE" and is_equal_approx(float(packet.get("alpha", -1.0)), 0.5) and packet.get("color_rgba") == [1.0, 1.0, 1.0, 0.8], "TEXTURE Particles use the same lifetime alpha scalar without changing texture or authored color semantics")


static func _test_zero_zone_uses_distinct_shard_and_spark_logical_assets(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/talent.zero_zone.vfx.json")
	var layers: Array = document_result.value.normalized_data.get("phases", {}).get("loop", {}).get("layers", []) if document_result.success else []
	var assets_by_layer: Dictionary = {}
	for layer in layers:
		assets_by_layer[layer.get("id", "")] = layer.get("parameters", {}).get("sprite_asset_ref", "")
	tests.expect_true(document_result.success and assets_by_layer.get("loop.forward_flow") == "fx.zero_zone_flow_streak" and assets_by_layer.get("loop.alignment_shards") == "fx.energy_shard" and assets_by_layer.get("loop.precision_sparks") == "fx.energy_spark", "Zero Zone uses stable logical IDs for forward racing-line, shard, and spark art")


static func _test_renderer_showcase_uses_the_ordinary_texture_particle_route(tests: TestAssert) -> void:
	var document_result: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/utility.renderer_showcase.vfx.json")
	var registry := _registry()
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(registry).build(document_result.value.normalized_data) if document_result.success else VfxResult.failure(document_result.issues)
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var resolved: VfxResult = resolver.resolve("fx.preview_texture_fixture")
	var runtime := VfxPreviewRenderRuntimeModel.new(plan_result.value, {"anchors": {"CENTER": [0, 0], "REAR_CENTER": [0, 160]}}, registry, VfxPreviewRendererFactoryModel.new(), resolver) if plan_result.success else null
	if runtime != null:
		runtime.activate_phase("loop", _frame())
		runtime.advance(0.25, _frame())
	var particle_packet: Dictionary = {}
	if runtime != null:
		for packet in runtime.draw_packets():
			if packet.get("layer_id") == "loop.energy_particles":
				particle_packet = packet
	tests.expect_true(plan_result.success and resolved.success and resolved.value.get("source") == "TEXTURE" and resolved.value.get("texture") is Texture2D and particle_packet.get("asset", {}).get("source") == "TEXTURE" and particle_packet.get("asset", {}).get("texture") is Texture2D, "Renderer Showcase reaches a Texture2D Particle through the ordinary Catalog, Resolver, Runtime, and Canvas route")


static func _resolver() -> RefCounted:
	return VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new(FIXTURE_CATALOG_PATH))


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _particle_instance(parameters: Dictionary) -> RefCounted:
	var spec := VfxPreviewLayerSpecModel.new("test.texture_particle", "PARTICLE", "CORE", "ADDITIVE", "OVER_VEHICLE", "VEHICLE_FOLLOW_WORLD_TRAIL", ["CENTER"], {"offset": [0.0, 0.0], "rotation_degrees": 0.0, "scale": [1.5, 0.25]}, parameters, true, 0, 0)
	return VfxPreviewRenderInstanceSpecModel.new("loop", spec, "CENTER", Vector2.ZERO, 0)


static func _frame() -> Dictionary:
	return {"vehicle_translation_source": [0.0, 0.0], "vehicle_rotation_degrees": 0.0, "effective_game_scale": [0.5, 0.25], "playback_generation": 1}


static func _has_issue(result: VfxResult, code: String) -> bool:
	for issue in result.issues:
		if issue.code == code:
			return true
	return false


static func _has_transparent_pixel(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 1.0:
				return true
	return false
