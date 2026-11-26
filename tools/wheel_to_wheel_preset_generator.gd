extends SceneTree
# Generator for the four Wheel to Wheel presets. Run:
#   godot --headless --path <studio> --script res://tools/wheel_to_wheel_preset_generator.gd
# Output: presets/examples/talent.wheel_to_wheel{,_surge,_grind_left,_grind_right}.vfx.json
# Design: docs/superpowers/specs/2026-11-26-talent-wheel-to-wheel-design.md (1 screen px ~ 12.4 source px in game)
#
# Main (12 s): white pressure crescents on both flanks (ALPHA air body + lemon ADD edge + lemon road spill).
#   battle_engaged (Game-smoothed 0..1, rear car of a battle) makes them denser, wider and leans them forward.
# Surge (battle_start, moment package): a pressure wave thrown forward from the nose + nose flash + corner sparks.
# Grind (hold_resisted, moment package): spark fountain + flash at the front corner on the opponent's side, and a pressure
#   wave kicking out to the other side (the side the car escapes to). left/right = side the opponent is on.
# Units: offsets are vehicle source px (canvas 256 x 512, front -Y); pivots are texture texels from the centre.
const OUT_DIR := "res://presets/examples/"
# Flank art: the car hole is texels x 156..356, y 160..560 of 512 x 768 -> its centre is 24 texels above the image centre.
const FLANK_SCALE := [1.0, 1.2]          # car hole 200 x 400 texels -> 200 x 480 source px (narrower X keeps the arcs off a car alongside)
const FLANK_OFFSET := [0.0, 29.0]        # image centre below the car centre (24 texels x 1.2)
const FLANK_HALF_LONG := 461.0      # particle copy size = half the displayed long side (768 x 1.2 / 2)
const IDLE := {"spill": 0.55, "body": 0.7, "edge": 0.85}
const ENGAGED_GAIN := {"spill": 1.7, "body": 1.35, "edge": 1.18}   # x idle opacity at battle_engaged 1
const ENGAGED_WIDTH := 1.1
const ENGAGED_LEAN := -50.0              # source px forward (~4 screen px) at battle_engaged 1
const FRONT_CORNER := Vector2(100.0, -215.0)
const WAVE_SCALE := 0.65                 # 420 px crescent -> ~270 source px (~22 screen px)
const FAN_SCALE := 1.3                   # longest spark line 190 texels -> ~250 source px (~20 screen px)
const FAN_ORIGIN_R := Vector2(-80.0, -80.0)   # spark origin texel (48, 48) from the 256 px image centre
const FLASH_SCALE := 0.85
const LEMON := [1.0, 0.9, 0.45, 1.0]     # spark tint (white-hot copy of the Furious Overtake spark; Chain Bind uses amber)
const START_SEC := 0.5
const END_SEC := 0.4
const SURGE_SEC := 0.55
const GRIND_SEC := 0.6
const MOMENT_END_SEC := 0.05          # empty END of the moment packages (the Game requires END > 0)


func _init() -> void:
	_write("talent.wheel_to_wheel", _main())
	_write("talent.wheel_to_wheel_surge", _surge())
	_write("talent.wheel_to_wheel_grind_left", _grind(-1.0))
	_write("talent.wheel_to_wheel_grind_right", _grind(1.0))
	quit(0)


func _main() -> Dictionary:
	var intro := "wheel_to_wheel.intro"
	var start := []
	var loop := []
	var end := []
	for part in [["spill", "fx.wheel_to_wheel_flank_spill", "ADDITIVE", "UNDER_VEHICLE", 0], ["body", "fx.wheel_to_wheel_flank_body", "ALPHA", "OVER_VEHICLE", 1], ["edge", "fx.wheel_to_wheel_flank_edge", "ADDITIVE", "OVER_VEHICLE", 2]]:
		var key: String = part[0]
		# START: the arcs burst out of the body sides (x0.7 -> x1.15 -> x1.0), edge and spill flash x1.6 then settle.
		var sid := "start." + key
		var start_mods := [
			_mod(sid + ".in", intro, 0.0, 0.2, 0.0, 1.0, "VISUAL_OPACITY_MULTIPLIER"),
			_mod(sid + ".out_x", intro, 0.0, 0.5, 0.7, 1.15, "TRANSFORM_SCALE_X"),
			_mod(sid + ".settle_x", intro, 0.5, 1.0, 1.0, 1.0 / 1.15, "TRANSFORM_SCALE_X")]
		if key != "body":
			start_mods.append(_mod(sid + ".flash", intro, 0.2, 0.7, 1.6, 1.0, "VISUAL_OPACITY_MULTIPLIER"))
		start.append(_sprite(sid, part[1], "CENTER", FLANK_OFFSET, FLANK_SCALE, part[2], part[3], part[4], IDLE[key], start_mods))
		# LOOP: idle look; battle_engaged -> denser, wider, leaning forward ("shoulder in").
		var lid := "loop." + key
		loop.append(_sprite(lid, part[1], "CENTER", FLANK_OFFSET, FLANK_SCALE, part[2], part[3], part[4], IDLE[key], [
			_input_mod(lid + ".battle_a", "battle_engaged", 0.0, 1.0, 1.0, ENGAGED_GAIN[key], "VISUAL_OPACITY_MULTIPLIER"),
			_input_mod(lid + ".battle_w", "battle_engaged", 0.0, 1.0, 1.0, ENGAGED_WIDTH, "TRANSFORM_SCALE_X"),
			_input_mod(lid + ".battle_lean", "battle_engaged", 0.0, 1.0, 0.0, ENGAGED_LEAN, "TRANSFORM_OFFSET_Y")]))
		# END: TEXTURED_SPRITE cannot ramp in END, so fade a particle copy that also folds in (size x0.8).
		end.append(_particle("end." + key, part[1], "CENTER", FLANK_OFFSET, part[3], part[2], part[4], {
			"emission_mode": "BURST", "burst_count": 1.0, "lifetime_seconds": END_SEC,
			"size_start": FLANK_HALF_LONG, "size_end": FLANK_HALF_LONG * 0.8, "alpha_start": IDLE[key], "alpha_end": 0.0}))
	# START: one small pressure wave off the nose announces the activation.
	start += _wave("start.wave", intro, [0.0, -200.0], 0.0, [0.0, -160.0], 0.45, 0.0, 0.8)
	return _preset("talent.wheel_to_wheel", "Wheel to Wheel", "START_LOOP_END", ["battle_engaged"],
		[{"id": intro, "type": "LINEAR_PHASE", "frequency_hz": 1.0 / START_SEC}],
		{"start": {"duration_seconds": START_SEC, "layers": start}, "loop": {"layers": loop}, "end": {"duration_seconds": END_SEC, "layers": end}})


func _surge() -> Dictionary:
	var t := "wheel_to_wheel_surge.time"
	var layers := _wave("one_shot.wave", t, [0.0, -230.0], 0.0, [0.0, -250.0], WAVE_SCALE, 0.0, 0.85)
	layers.append(_sprite("one_shot.nose_flash", "fx.wheel_to_wheel_contact_flash", "CENTER", [0.0, -240.0], [FLASH_SCALE, FLASH_SCALE], "ADDITIVE", "OVER_VEHICLE", 5, 1.0, [
		_mod("one_shot.nose_flash.in", t, 0.0, 0.06, 0.0, 1.0, "VISUAL_OPACITY_MULTIPLIER"),
		_mod("one_shot.nose_flash.out", t, 0.12, 0.4, 1.0, 0.0, "VISUAL_OPACITY_MULTIPLIER")]))
	for sx in [-1.0, 1.0]:
		layers.append(_sparks("one_shot.sparks_%s" % ("l" if sx < 0.0 else "r"), [FRONT_CORNER.x * sx, FRONT_CORNER.y], 35.0 * sx, 5.0, 0.4, 55.0))
	return _preset("talent.wheel_to_wheel_surge", "Wheel to Wheel Surge", "START_LOOP_END", [],
		[{"id": t, "type": "LINEAR_PHASE", "frequency_hz": 1.0 / SURGE_SEC}], _moment(SURGE_SEC, layers))


## side = -1: the opponent is on my left (sparks at my front-left, I kick out to the right); +1 the mirror.
func _grind(side: float) -> Dictionary:
	var t := "wheel_to_wheel_grind.time"
	var corner := [FRONT_CORNER.x * side, FRONT_CORNER.y]
	var fan_tex := "fx.wheel_to_wheel_spark_fan_r" if side > 0.0 else "fx.wheel_to_wheel_spark_fan_l"
	var origin := Vector2(FAN_ORIGIN_R.x * side, FAN_ORIGIN_R.y)
	var fan_centre := [corner[0] - origin.x * FAN_SCALE, corner[1] - origin.y * FAN_SCALE]
	var layers := [
		_sprite("one_shot.spark_fan", fan_tex, "CENTER", fan_centre, [FAN_SCALE, FAN_SCALE], "ADDITIVE", "OVER_VEHICLE", 4, 1.0, [
			_mod("one_shot.spark_fan.in", t, 0.0, 0.05, 0.0, 1.0, "VISUAL_OPACITY_MULTIPLIER"),
			_mod("one_shot.spark_fan.out", t, 0.3, 0.75, 1.0, 0.0, "VISUAL_OPACITY_MULTIPLIER"),
			_mod("one_shot.spark_fan.grow_x", t, 0.0, 0.5, 0.55, 1.15, "TRANSFORM_SCALE_X"),
			_mod("one_shot.spark_fan.grow_y", t, 0.0, 0.5, 0.55, 1.15, "TRANSFORM_SCALE_Y")], [origin.x, origin.y]),
		_sprite("one_shot.contact_flash", "fx.wheel_to_wheel_contact_flash", "CENTER", corner, [FLASH_SCALE, FLASH_SCALE], "ADDITIVE", "OVER_VEHICLE", 5, 1.0, [
			_mod("one_shot.contact_flash.in", t, 0.0, 0.05, 0.0, 1.0, "VISUAL_OPACITY_MULTIPLIER"),
			_mod("one_shot.contact_flash.out", t, 0.1, 0.35, 1.0, 0.0, "VISUAL_OPACITY_MULTIPLIER")]),
		_sparks("one_shot.sparks", corner, 125.0 * side, 9.0, 0.45, 60.0)]
	# Kick-out wave on the escape side: crescent rotated to bulge outward, pushed ~10 screen px out.
	layers += _wave("one_shot.kick", t, [-250.0 * side, -60.0], -90.0 * side, [-150.0 * side, 0.0], 0.75, 0.0, 0.7)
	var label := "Left" if side < 0.0 else "Right"
	return _preset("talent.wheel_to_wheel_grind_" + label.to_lower(), "Wheel to Wheel Grind " + label, "START_LOOP_END", [],
		[{"id": t, "type": "LINEAR_PHASE", "frequency_hz": 1.0 / GRIND_SEC}], _moment(GRIND_SEC, layers))


# --- helpers

## Moment package: the Game runs START_LOOP_END only, so a one-shot is START = the moment, an empty LOOP and a short
## empty END; the Game stops it after START (VfxService option normal_stop_after_seconds, as Pit Stop Ace does).
func _moment(seconds: float, layers: Array) -> Dictionary:
	return {"start": {"duration_seconds": seconds, "layers": layers}, "loop": {"layers": []}, "end": {"duration_seconds": MOMENT_END_SEC, "layers": []}}


## Pressure wave (ALPHA air + ADD rim): moves by `travel` (source px) and grows x0.6 -> x1.4 over phase t0..t1, fading out.
func _wave(id: String, source: String, offset: Array, rotation: float, travel: Array, scale: float, t0: float, t1: float) -> Array:
	var out := []
	for part in [["body", "fx.wheel_to_wheel_wave_body", "ALPHA", 6, 0.95], ["rim", "fx.wheel_to_wheel_wave_rim", "ADDITIVE", 7, 1.0]]:
		var lid := "%s_%s" % [id, part[0]]
		var mods := [
			_mod(lid + ".in", source, t0, t0 + 0.08, 0.0, 1.0, "VISUAL_OPACITY_MULTIPLIER"),
			_mod(lid + ".out", source, lerpf(t0, t1, 0.45), t1, 1.0, 0.0, "VISUAL_OPACITY_MULTIPLIER"),
			_mod(lid + ".grow_x", source, t0, t1, 0.6, 1.4, "TRANSFORM_SCALE_X"),
			_mod(lid + ".grow_y", source, t0, t1, 0.6, 1.4, "TRANSFORM_SCALE_Y")]
		if travel[0] != 0.0:
			mods.append(_mod(lid + ".travel_x", source, t0, t1, 0.0, travel[0], "TRANSFORM_OFFSET_X"))
		if travel[1] != 0.0:
			mods.append(_mod(lid + ".travel_y", source, t0, t1, 0.0, travel[1], "TRANSFORM_OFFSET_Y"))
		var layer := _sprite(lid, part[1], "CENTER", offset, [scale, scale], part[2], "OVER_VEHICLE", part[3], part[4], mods)
		layer["transform"]["rotation_degrees"] = rotation
		out.append(layer)
	return out


## Lemon sparks (white-hot copy of the Furious Overtake spark, tinted): direction degrees clockwise from forward (0 forward, 90 right, 180 back).
func _sparks(id: String, offset: Array, direction: float, count: float, life: float, spread: float) -> Dictionary:
	return _particle(id, "fx.wheel_to_wheel_spark", "CENTER", offset, "OVER_VEHICLE", "ADDITIVE", 8, {
		"emission_mode": "BURST", "burst_count": count, "lifetime_seconds": life, "size_start": 95.0, "size_end": 28.0,
		"alpha_start": 1.0, "alpha_end": 0.0, "color_rgba": LEMON, "direction_degrees": fposmod(direction, 360.0),
		"spread_degrees": spread, "speed_min": 300.0, "speed_max": 620.0, "rotation_min_degrees": 0.0, "rotation_max_degrees": 360.0})


func _preset(id: String, name: String, mode: String, inputs: Array, sources: Array, phases: Dictionary) -> Dictionary:
	return {"schema_version": 1, "preset_id": id, "display_name": name, "category": "RACE_TALENT",
		"default_space_mode": "VEHICLE_LOCAL", "lifecycle": {"mode": mode}, "runtime_inputs": inputs,
		"runtime_modulation_sources": sources, "phases": phases}


func _sprite(id: String, tex: String, anchor: String, offset: Array, scale: Array, blend: String, plane: String, sort: int, opacity: float, mods: Array, pivot: Array = [0.0, 0.0]) -> Dictionary:
	return {"id": id, "type": "TEXTURED_SPRITE", "enabled": true, "importance": "CORE", "anchors": [anchor],
		"blend_mode": blend, "render_plane": plane, "sort_order": sort, "modulations": mods,
		"parameters": {"opacity": opacity, "texture_asset_ref": tex},
		"transform": {"offset": offset, "rotation_degrees": 0.0, "scale": scale, "modulation_pivot_local": pivot}}


func _particle(id: String, tex: String, anchor: String, offset: Array, plane: String, blend: String, sort: int, p: Dictionary) -> Dictionary:
	var params := {"acceleration": [0.0, 0.0], "angular_velocity_min_degrees_per_second": 0.0, "angular_velocity_max_degrees_per_second": 0.0,
		"color_rgba": [1.0, 1.0, 1.0, 1.0], "direction_degrees": 0.0, "emitter": {"shape": "POINT"},
		"rotation_min_degrees": 0.0, "rotation_max_degrees": 0.0, "size_multiplier_min": 1.0, "size_multiplier_max": 1.0,
		"speed_min": 0.0, "speed_max": 0.0, "spread_degrees": 0.0, "sprite_asset_ref": tex}
	params.merge(p, true)
	return {"id": id, "type": "PARTICLE", "enabled": true, "importance": "CORE", "anchors": [anchor],
		"blend_mode": blend, "render_plane": plane, "sort_order": sort, "parameters": params,
		"transform": {"offset": offset, "rotation_degrees": 0.0, "scale": [1.0, 1.0]}}


func _mod(id: String, source_id: String, in_min: float, in_max: float, out_min: float, out_max: float, target: String) -> Dictionary:
	var op := "ADD" if target in ["TRANSFORM_OFFSET_X", "TRANSFORM_OFFSET_Y"] else "MULTIPLY"
	return {"id": id, "operation": op, "target": target,
		"source": {"type": "PRESET_SOURCE", "source_id": source_id},
		"mapping": {"type": "LINEAR_RANGE", "input_min": in_min, "input_max": in_max, "output_min": out_min, "output_max": out_max}}


func _input_mod(id: String, input: String, in_min: float, in_max: float, out_min: float, out_max: float, target: String) -> Dictionary:
	var op := "ADD" if target in ["TRANSFORM_OFFSET_X", "TRANSFORM_OFFSET_Y"] else "MULTIPLY"
	return {"id": id, "operation": op, "target": target,
		"source": {"type": "RUNTIME_INPUT", "input": input},
		"mapping": {"type": "LINEAR_RANGE", "input_min": in_min, "input_max": in_max, "output_min": out_min, "output_max": out_max}}


func _write(id: String, preset: Dictionary) -> void:
	var path := OUT_DIR + id + ".vfx.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(preset, "  ", true) + "\n")
	f.close()
	var pipeline = preload("res://src/app/vfx_preset_pipeline.gd").new()
	var result: VfxResult = pipeline.build_document_from_value(preset)
	print("%s -> %s" % [id, "VALID" if result.success else "INVALID"])
	for issue in result.issues:
		print("  ", issue.code, " ", issue.message, " ", issue.pointer)
