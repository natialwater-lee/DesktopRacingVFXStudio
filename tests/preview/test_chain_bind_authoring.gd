extends RefCounted
# Chain Bind presets + the LINK_STRIP / link_target contract (docs/contracts/link_strip_v1.md).

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const Reader = preload("res://src/export/vfx_runtime_definition_reader.gd")
const Geometry = preload("res://src/preview/rendering/vfx_link_strip_geometry.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const DIR = "res://presets/examples/"
const ASSETS := {
	"fx.chain_bind_chain_links": Vector2i(256, 128), "fx.chain_bind_chain_links_heat": Vector2i(256, 128),
	"fx.chain_bind_heat_glow": Vector2i(512, 128), "fx.chain_bind_snap_flash": Vector2i(256, 256),
	"fx.chain_bind_shackle": Vector2i(512, 256), "fx.chain_bind_shackle_heat": Vector2i(512, 256),
	"fx.chain_bind_clamp": Vector2i(256, 256), "fx.chain_bind_clamp_heat": Vector2i(256, 256),
}


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var binder := _load(t, "talent.chain_bind")
	var shackle := _load(t, "talent.chain_bind_shackle")
	var broken := _load(t, "talent.chain_bind_break")
	if binder.is_empty() or shackle.is_empty() or broken.is_empty():
		return
	var link_counts := []
	for phase in ["start", "loop", "end"]:
		link_counts.append(binder.phases[phase].layers.filter(func(l): return l.type == "LINK_STRIP").size())
	t.expect_true(binder.get("link_target", {}).get("target_anchor") == "REAR_CENTER" and link_counts == [4, 4, 4] \
		and binder.runtime_inputs == ["link_distance_ratio", "link_lock_pulse"] and not shackle.has("link_target") \
		and broken.lifecycle.mode == "ONE_SHOT" and broken.phases.one_shot.layers.any(func(l): return l.get("link_point_t", -1.0) == 0.5),
		"Chain Bind: binder links FRONT -> target REAR_CENTER, shackle stays target-local, break bursts mid-link")
	_check_contract(t, binder)
	_check_geometry(t)
	_check_renderer(t)
	_check_export(t)


static func _load(t: TestAssert, id: String) -> Dictionary:
	var result: VfxResult = Pipeline.new().load_and_validate(DIR + id + ".vfx.json")
	t.expect_true(result.success, "%s is a valid preset" % id)
	return result.value.normalized_data if result.success else {}


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Chain Bind resolves its 8 textures (strip textures run along +X)")


static func _check_contract(t: TestAssert, binder: Dictionary) -> void:
	var pipeline := Pipeline.new()
	var no_target := binder.duplicate(true)
	no_target.erase("link_target")
	var wrong_layer := binder.duplicate(true)
	wrong_layer.phases.loop.layers[4]["link_point_t"] = 0.5   # TEXTURED_SPRITE
	var unused := binder.duplicate(true)
	for phase in unused.phases.values():
		phase.layers = phase.layers.filter(func(l): return l.type != "LINK_STRIP" and not l.has("link_point_t"))
	var codes := []
	for value in [no_target, wrong_layer, unused]:
		var result: VfxResult = pipeline.build_document_from_value(value)
		codes.append(result.issues[0].code if not result.success and not result.issues.is_empty() else "")
	t.expect_true(codes == ["link_target_required", "link_point_layer", "link_target_unused"], "Link rules reject a missing, misplaced or unused link (%s)" % str(codes))


static func _check_geometry(t: TestAssert) -> void:
	var p := {"reveal_seconds": 0.2, "segments": 4}
	var half: Array = Geometry.visible_ranges(p, 0.1)
	var gap: Array = Geometry.visible_ranges({"gap_seconds": 0.2}, 0.1)
	var lines: Array = Geometry.build(Vector2.ZERO, Vector2(0, -400), {"sag_source_px": 50.0, "segments": 4, "shift_source_px": [10.0, 0.0]}, 50.0, 0.0)
	var mid: Vector2 = lines[0][2] if lines.size() == 1 and lines[0].size() == 5 else Vector2.INF
	t.expect_true(half.size() == 1 and half[0].y > 0.5 and half[0].y < 1.0 and gap.size() == 2 and is_equal_approx(gap[0].y, 0.25) \
		and mid.is_equal_approx(Vector2(60.0, -200.0)) and Geometry.build(Vector2.ZERO, Vector2(0.5, 0), {}, 0.0, 0.0).is_empty(),
		"LINK_STRIP geometry: eased reveal, middle gap, quadratic sag + shift, degenerate link hidden")


static func _check_renderer(t: TestAssert) -> void:
	var spec := preload("res://src/preview/rendering/vfx_preview_layer_spec.gd").new("loop.l", "LINK_STRIP", "CORE", "ALPHA", "OVER_VEHICLE", "VEHICLE_LOCAL", ["FRONT"],
		{"offset": [0.0, -5.0], "rotation_degrees": 0.0, "scale": [1.0, 1.0]}, {"texture_asset_ref": "fx.chain_bind_chain_links", "texture_mode": "TILE", "width_source_px": 190.0}, true, 0, 0)
	var instance := preload("res://src/preview/rendering/vfx_preview_render_instance_spec.gd").new("loop", spec, "FRONT", Vector2(0, -220), 0)
	var renderer := preload("res://src/preview/rendering/vfx_link_strip_layer_renderer.gd").new(instance, {})
	renderer.restart({})
	var without := renderer.draw_packets().size()
	renderer.advance(1.0 / 60.0, {"link_target_source": Vector2(300, -100)})
	var packets: Array = renderer.draw_packets()
	t.expect_true(without == 0 and packets.size() == 1 and (packets[0].points[0] as Vector2).is_equal_approx(Vector2(0, -225)) \
		and (packets[0].points[-1] as Vector2).is_equal_approx(Vector2(300, -100)) and is_equal_approx(packets[0].width, 190.0),
		"LINK_STRIP draws only with a link target, from anchor+offset to the target point")


static func _check_export(t: TestAssert) -> void:
	var export := Export.new()
	var binder: VfxResult = export.validate_saved_source(DIR + "talent.chain_bind.vfx.json")
	var shackle: VfxResult = export.validate_saved_source(DIR + "talent.chain_bind_shackle.vfx.json")
	if not binder.success or not shackle.success:
		t.expect_true(false, "Chain Bind presets compile to packages")
		return
	var runtime: Dictionary = JSON.parse_string(binder.value.runtime_text())
	var types := Reader.LEGACY_TYPES + ["LINK_STRIP"]
	var linked: VfxResult = Reader.read(runtime, [3], types, [Reader.LINK_CAPABILITY])
	var legacy: VfxResult = Reader.read(runtime, [1, 2, 3], types)
	t.expect_true(runtime.runtime_definition_version == 3 and runtime.required_capabilities == ["LINK_TARGET_V1"] \
		and runtime.link_target.target_offset == [0.0, 40.0] and linked.success and linked.value.normalized_data.has("link_target") \
		and not legacy.success and shackle.value.runtime_definition_version() == 2 \
		and binder.value.manifest_data().requirements.required_vehicle_anchors == ["FRONT", "REAR_CENTER"],
		"Linked packages are v3 + LINK_TARGET_V1 (round-trip ok, old readers reject); the shackle stays v2")
