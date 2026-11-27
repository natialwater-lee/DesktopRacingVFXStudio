extends RefCounted
# Wheel to Wheel presets (docs/superpowers/specs/2026-11-26-talent-wheel-to-wheel-design.md).

const Pipeline = preload("res://src/app/vfx_preset_pipeline.gd")
const Export = preload("res://src/export/vfx_export_service.gd")
const AssetRegistry = preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const AssetResolver = preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const DIR = "res://presets/examples/"
const ASSETS := {
	"fx.wheel_to_wheel_turbulence_a": Vector2i(128, 256), "fx.wheel_to_wheel_turbulence_b": Vector2i(128, 256),
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
	# Sustain v2 (section 11): one road-haze sprite driven by battle_engaged, four flowing wisp streams (bent by their own
	# sine beat, flowing back) and two lemon ember streams. Game particles take only bend modulation.
	var sprites := loop.filter(func(l: Dictionary) -> bool: return l.type == "TEXTURED_SPRITE")
	var wisps := loop.filter(func(l: Dictionary) -> bool: return l.type == "PARTICLE" and str(l.parameters.sprite_asset_ref).begins_with("fx.wheel_to_wheel_turbulence_"))
	var embers := loop.filter(func(l: Dictionary) -> bool: return l.type == "PARTICLE" and l.parameters.sprite_asset_ref == "fx.wheel_to_wheel_spark")
	var haze_ok: bool = sprites.size() == 1 and sprites[0].modulations.any(func(m: Dictionary) -> bool:
		return m.source.get("input") == "battle_engaged" and m.target == "VISUAL_OPACITY_MULTIPLIER" and float(m.mapping.output_max) > 1.0)
	var beats := {}
	var wisps_ok: bool = wisps.size() == 4 and wisps.all(func(l: Dictionary) -> bool:
		var p: Dictionary = l.parameters
		return p.emission_mode == "CONTINUOUS" and is_equal_approx(float(p.direction_degrees), 180.0) and l.has("visual_bend") \
			and l.modulations.size() == 1 and l.modulations[0].target == "VISUAL_BEND_OFFSET_X" and l.modulations[0].source.type == "PRESET_SOURCE")
	for l in wisps:
		beats[l.modulations[0].source.source_id] = true
	var left_n: int = wisps.filter(func(l: Dictionary) -> bool: return float(l.transform.offset[0]) < 0.0).size()
	t.expect_true(main.lifecycle.mode == "START_LOOP_END" and main.runtime_inputs == ["battle_engaged"] and haze_ok and wisps_ok \
		and beats.size() == 4 and left_n == 2 and embers.size() == 2 and loop.size() == 7,
		"Wheel to Wheel LOOP: battle haze sprite + 4 backward wisp streams (2 a side, each its own sway beat) + 2 ember streams")
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
	var expected := {"talent.wheel_to_wheel": ["fx.wheel_to_wheel_flank_spill", "fx.wheel_to_wheel_spark", "fx.wheel_to_wheel_turbulence_a", "fx.wheel_to_wheel_turbulence_b", "fx.wheel_to_wheel_wave_body", "fx.wheel_to_wheel_wave_rim"],
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
