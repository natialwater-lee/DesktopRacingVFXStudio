extends RefCounted
# Wheel to Wheel presets (docs/superpowers/specs/2026-11-26-talent-wheel-to-wheel-design.md).

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const DIR = "res://presets/examples/"
const ASSETS := {
	"fx.wheel_to_wheel_flank_body": Vector2i(512, 768), "fx.wheel_to_wheel_flank_edge": Vector2i(512, 768),
	"fx.wheel_to_wheel_flank_spill": Vector2i(512, 768), "fx.wheel_to_wheel_wave_body": Vector2i(512, 256),
	"fx.wheel_to_wheel_wave_rim": Vector2i(512, 256), "fx.wheel_to_wheel_spark_fan_r": Vector2i(256, 256),
	"fx.wheel_to_wheel_spark_fan_l": Vector2i(256, 256), "fx.wheel_to_wheel_contact_flash": Vector2i(256, 256),
	"fx.wheel_to_wheel_spark": Vector2i(32, 32),
}


static func run(t: TestAssert) -> void:
	_check_assets(t)
	var main := _load(t, "talent.wheel_to_wheel")
	var surge := _load(t, "talent.wheel_to_wheel_surge")
	var left := _load(t, "talent.wheel_to_wheel_grind_left")
	var right := _load(t, "talent.wheel_to_wheel_grind_right")
	if main.is_empty() or surge.is_empty() or left.is_empty() or right.is_empty():
		return
	var loop: Array = main.phases.loop.layers
	var battle_ok := loop.size() == 3 and loop.all(func(l: Dictionary) -> bool:
		return l.type == "TEXTURED_SPRITE" and l.modulations.any(func(m: Dictionary) -> bool:
			return m.source.get("input") == "battle_engaged" and m.target == "TRANSFORM_OFFSET_Y" and float(m.mapping.output_max) < 0.0))
	t.expect_true(main.lifecycle.mode == "START_LOOP_END" and main.runtime_inputs == ["battle_engaged"] and battle_ok,
		"Wheel to Wheel LOOP: three flank sprites, battle_engaged leans them forward")
	var moments_ok := true
	for m in [surge, left, right]:
		moments_ok = moments_ok and m.lifecycle.mode == "START_LOOP_END" and m.runtime_inputs.is_empty() and not m.phases.start.layers.is_empty() \
			and m.phases.loop.layers.is_empty() and m.phases.end.layers.is_empty() and float(m.phases.end.duration_seconds) > 0.0
	t.expect_true(moments_ok, "Surge and grind are input-free moment packages: START only, empty LOOP/END (the Game stops them after START)")
	# Grind mirrors: sparks at the front corner on the opponent's side (left = -x), kick wave out on the other side.
	var l_fan := _layer(left, "one_shot.spark_fan")
	var r_fan := _layer(right, "one_shot.spark_fan")
	var l_kick := _layer(left, "one_shot.kick_body")
	var r_kick := _layer(right, "one_shot.kick_body")
	t.expect_true(l_fan.parameters.texture_asset_ref == "fx.wheel_to_wheel_spark_fan_l" and r_fan.parameters.texture_asset_ref == "fx.wheel_to_wheel_spark_fan_r" \
		and float(l_fan.transform.offset[0]) < 0.0 and float(r_fan.transform.offset[0]) > 0.0 \
		and float(l_kick.transform.offset[0]) > 0.0 and float(r_kick.transform.offset[0]) < 0.0 \
		and is_equal_approx(float(l_kick.transform.rotation_degrees), 90.0) and is_equal_approx(float(r_kick.transform.rotation_degrees), -90.0),
		"Grind left/right mirror: sparks on the opponent's side, kick wave bulging out on the escape side")
	var expected := {"talent.wheel_to_wheel": ["fx.wheel_to_wheel_flank_body", "fx.wheel_to_wheel_flank_edge", "fx.wheel_to_wheel_flank_spill", "fx.wheel_to_wheel_wave_body", "fx.wheel_to_wheel_wave_rim"],
		"talent.wheel_to_wheel_surge": ["fx.wheel_to_wheel_contact_flash", "fx.wheel_to_wheel_spark", "fx.wheel_to_wheel_wave_body", "fx.wheel_to_wheel_wave_rim"],
		"talent.wheel_to_wheel_grind_left": ["fx.wheel_to_wheel_contact_flash", "fx.wheel_to_wheel_spark", "fx.wheel_to_wheel_spark_fan_l", "fx.wheel_to_wheel_wave_body", "fx.wheel_to_wheel_wave_rim"]}
	var ok := true
	for id in expected:
		var plan: VfxResult = Export.new().validate_saved_source(DIR + id + ".vfx.json")
		var ids: Array = plan.value.manifest_data().get("asset_dependencies", []).map(func(d: Dictionary) -> String: return str(d.get("logical_id", ""))) if plan.success else []
		ids.sort()
		ok = ok and plan.success and ids == expected[id]
	t.expect_true(ok, "Wheel to Wheel presets compile to packages with only their own textures")


static func _load(t: TestAssert, id: String) -> Dictionary:
	var result: VfxResult = Pipeline.new().load_and_validate(DIR + id + ".vfx.json")
	t.expect_true(result.success, "%s is a valid preset" % id)
	return result.value.normalized_data if result.success else {}


static func _layer(preset: Dictionary, id: String) -> Dictionary:
	for phase in preset.phases.values():
		for layer in phase.layers:
			if layer.id == id:
				return layer
	return {"parameters": {"texture_asset_ref": ""}, "transform": {"offset": [0.0, 0.0], "rotation_degrees": 0.0}}


static func _check_assets(t: TestAssert) -> void:
	var resolver := AssetResolver.new(AssetRegistry.new())
	var ok := true
	for asset_id in ASSETS:
		var resolved: VfxResult = resolver.resolve(asset_id)
		var texture: Texture2D = resolved.value.get("texture") as Texture2D if resolved.success else null
		ok = ok and resolved.success and not resolved.value.get("is_fallback", true) \
			and texture != null and Vector2i(texture.get_size()) == ASSETS[asset_id]
	t.expect_true(ok, "Wheel to Wheel resolves its 9 textures without fallback")
