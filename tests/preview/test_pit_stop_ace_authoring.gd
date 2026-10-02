extends RefCounted

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const PATH = "res://presets/examples/talent.pit_stop_ace.vfx.json"
const ASSETS := {
	"fx.pit_stop_ace_wheel_ring": Vector2i(128, 128),
	"fx.pit_stop_ace_service_flash": Vector2i(320, 320),
	"fx.pit_stop_ace_launch_line": Vector2i(48, 256),
}
# Shared rear-wheel contacts (front wheel positions differ per car and are not used).
const REAR_WHEEL := Vector2(84.0, 160.0)


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var result: VfxResult = Pipeline.new().load_and_validate(PATH)
	if not result.success:
		t.expect_true(false, "Pit Stop Ace requires a valid Preset")
		return
	var d: Dictionary = result.value.normalized_data
	_check_structure(t, d)
	_check_wheels(t, d)
	_check_export_plan(t)


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Pit Stop Ace resolves its wheel ring, service flash and launch line textures without fallback")


static func _check_structure(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var loop: Array = phases.get("loop", {}).get("layers", [])
	# Fixed-time talent: the Game stops LOOP at a fixed time, so LOOP must be length-agnostic.
	var loop_continuous: bool = loop.all(func(layer: Dictionary) -> bool: return layer.get("parameters", {}).get("emission_mode") == "CONTINUOUS")
	t.expect_true(
		d.get("preset_id") == "talent.pit_stop_ace" and d.get("category") == "RACE_TALENT" \
		and d.get("lifecycle", {}).get("mode") == "START_LOOP_END" and d.get("runtime_inputs", []).is_empty() \
		and loop.size() == 4 and loop_continuous and float(phases.get("end", {}).get("duration_seconds", 0.0)) > 0.0,
		"Pit Stop Ace runs a strong START and a length-agnostic LOOP the Game stops at a fixed time"
	)


static func _check_wheels(t: TestAssert, d: Dictionary) -> void:
	var phases: Dictionary = d.get("phases", {})
	var start := _by_id(phases.get("start", {}).get("layers", []))
	var loop := _by_id(phases.get("loop", {}).get("layers", []))
	var ok := true
	for side in [["l", -1.0], ["r", 1.0]]:
		for layer in [start.get("start.wheel_%s" % side[0], {}), loop.get("loop.wheel_%s" % side[0], {})]:
			var offset: Array = layer.get("transform", {}).get("offset", [0.0, 0.0])
			var p: Dictionary = layer.get("parameters", {})
			ok = ok and layer.get("render_plane") == "OVER_VEHICLE" \
				and is_equal_approx(float(offset[0]), side[1] * REAR_WHEEL.x) and is_equal_approx(float(offset[1]), REAR_WHEEL.y) \
				and absf(float(p.get("angular_velocity_min_degrees_per_second", 0.0))) > 0.0
	var start_duration := float(phases.get("start", {}).get("duration_seconds", 0.0))
	var first_ring := start_duration + 1.0 / float(loop.get("loop.wheel_l", {}).get("parameters", {}).get("emission_rate_per_second", 0.001))
	ok = ok and float(start.get("start.wheel_l", {}).get("parameters", {}).get("lifetime_seconds", 0.0)) >= first_ring
	t.expect_true(ok, "Pit Stop Ace spins glowing rims over the shared rear-wheel contacts and bridges START into LOOP")


static func _check_export_plan(t: TestAssert) -> void:
	var plan: VfxResult = Export.new().validate_saved_source(PATH)
	var manifest: Dictionary = plan.value.manifest_data() if plan.success else {}
	var ids: Array = manifest.get("asset_dependencies", []).map(func(dependency: Dictionary) -> String: return str(dependency.get("logical_id", "")))
	ids.sort()
	t.expect_true(
		plan.success and ids == ["fx.furious_overtake_spark", "fx.pit_stop_ace_launch_line", "fx.pit_stop_ace_service_flash", "fx.pit_stop_ace_wheel_ring"],
		"Pit Stop Ace compiles to a package with its three textures and the reused spark"
	)


static func _by_id(layers: Array) -> Dictionary:
	var result: Dictionary = {}
	for layer in layers:
		if layer is Dictionary:
			result[str(layer.get("id", ""))] = layer
	return result
