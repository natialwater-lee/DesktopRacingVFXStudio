extends SceneTree
# Generator for the four Wheel to Wheel presets. Run:
#   godot --headless --path <studio> --script res://tools/wheel_to_wheel_preset_generator.gd
# Output: presets/examples/talent.wheel_to_wheel{,_surge,_grind_left,_grind_right}.vfx.json
# Design: docs/superpowers/specs/2026-11-26-talent-wheel-to-wheel-design.md (1 screen px ~ 12.4 source px in game)
#
# Main (talent duration): sustain v2 — short warm-white turbulence wisps flow back along both flanks and scatter behind,
#   with a few lemon embers and a faint road haze. battle_engaged (Game-smoothed 0..1) lifts the haze (both sides alike).
# Surge (battle_start, moment package): a pressure wave thrown forward from the nose + nose flash + corner sparks.
# Grind (hold_resisted, moment package): spark fountain + flash at the front corner on the opponent's side, and a pressure
#   wave kicking out to the other side (the side the car escapes to). left/right = side the opponent is on.
# Units: offsets are vehicle source px (canvas 256 x 512, front -Y); pivots are texture texels from the centre.
const OUT_DIR := "res://presets/examples/"
# Flank art: the car hole is texels x 156..356, y 160..560 of 512 x 768 -> its centre is 24 texels above the image centre.
const FLANK_SCALE := [1.0, 1.2]          # car hole 200 x 400 texels -> 200 x 480 source px (narrower X keeps the arcs off a car alongside)
const FLANK_OFFSET := [0.0, 29.0]        # image centre below the car centre (24 texels x 1.2)
const FLANK_HALF_LONG := 461.0      # particle copy size = half the displayed long side (768 x 1.2 / 2)
const ENGAGED_WIDTH := 1.1
const ENGAGED_LEAN := -50.0              # source px forward (~4 screen px) at battle_engaged 1
# Sustain v2 (Jihoon 11-27: the white crescents are too crisp and static, a white blob in a pack): no fixed band. Short
# warm-white turbulence wisps are born beside the front doors, flow back past the tail and scatter. Particles cannot take
# opacity/rate modulation in the Game, so battle_engaged drives only a faint road haze (the old spill sprite).
const HAZE_IDLE := 0.2                   # was the 0.55 spill; battle_engaged x2.25 -> 0.45
const HAZE_ENGAGED_GAIN := 2.25
const WISP_TEX := ["fx.wheel_to_wheel_turbulence_a", "fx.wheel_to_wheel_turbulence_b"]   # GPT wisps widened x4 (tools/wheel_to_wheel_turbulence_prep.gd)
const WISP_ORIGIN := Vector2(128.0, -60.0)    # beside the front door, a little behind the nose (car body half width ~100)
const WISP_BOX := [12.0, 60.0]           # narrow birth lane beside the door (was 25 wide)
const WISP_SPEED := [650.0, 950.0]       # x 0.45 s -> 290..430 source px back (past the tail, ~25..35 screen px)
const WISP_LIFE := 0.45
const WISP_SIZE := [60.0, 100.0]         # half long side: ~10 -> ~16 screen px long
const WISP_ALPHA := 0.6                  # 0.3 (the art README's 30 %) was barely visible; 0.45 still weak on the bright bridge (Jihoon 11-27)
const WISP_RATE := 6.0                   # per layer; 2 layers a side -> ~12 alive per car
const WISP_TINT := [1.0, 0.97, 0.9, 1.0]
const WISP_SCATTER := 20.0               # small outward drift: straight back, only a slight opening at the tail (Jihoon 11-27: no sprinkler look; was 120)
const WISP_BEND := 5.0                   # +- texels of sine bend: a gentle waver, not a sway (was 8)
# [texture index, bend frequency Hz, phase degrees] per layer; left/right use different beats so they never sway together.
const WISP_LAYERS := {"l": [[0, 1.3, 0.0], [1, 1.9, 120.0]], "r": [[0, 1.6, 200.0], [1, 2.2, 300.0]]}
const EMBER_RATE := 2.0
const FRONT_CORNER := Vector2(100.0, -215.0)
const FAN_ORIGIN_R := Vector2(-80.0, -80.0)   # spark origin texel (48, 48) from the 256 px image centre
const LEMON := [1.0, 0.9, 0.45, 1.0]     # spark tint (white-hot copy of the Furious Overtake spark; Chain Bind uses amber)
const START_SEC := 0.5
const END_SEC := 0.4
const SURGE_SEC := 0.9
const GRIND_SEC := 0.9
const MOMENT_END_SEC := 0.05          # empty END of the moment packages (the Game requires END > 0)
# Moment look (hit v1, Jihoon 11-27: "the contact moment is too short to see"): a fast burst, then a slow fade, ~0.9 s.
#   Seconds: in 0 -> 0.04, peak until 0.12, drop to 55 % by 0.30, fade to 0 by 0.88 (before START ends at 0.9).
const HIT_IN_SEC := 0.04
const HIT_PEAK_SEC := 0.12
const HIT_SETTLE_SEC := 0.30
const HIT_SETTLE_LEVEL := 0.55
const HIT_FADE_END_SEC := 0.88
const HIT_BURST_SEC := 0.15           # waves / fan reach most of their size and travel in this time
const HIT_WAVE_SCALE := 0.75          # surge wave (was 0.65)
const HIT_KICK_SCALE := 0.85          # grind kick-out wave (was 0.75)
const HIT_FAN_SCALE := 1.45           # grind spark fan (was 1.3)
const HIT_FLASH_SCALE := 1.1          # nose / contact flash (was 0.85)


func _init() -> void:
	_write("talent.wheel_to_wheel", _main())
	_write("talent.wheel_to_wheel_surge", _surge())
	_write("talent.wheel_to_wheel_grind_left", _grind(-1.0))
	_write("talent.wheel_to_wheel_grind_right", _grind(1.0))
	quit(0)


func _main() -> Dictionary:
	var intro := "wheel_to_wheel.intro"
	var sources := [{"id": intro, "type": "LINEAR_PHASE", "frequency_hz": 1.0 / START_SEC}]
	for side in WISP_LAYERS:
		for i in WISP_LAYERS[side].size():
			var spec: Array = WISP_LAYERS[side][i]
			sources.append({"id": "wheel_to_wheel.sway_%s%d" % [side, i], "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": spec[1], "phase_degrees": spec[2]})
	var haze := ["fx.wheel_to_wheel_flank_spill", "ADDITIVE", "UNDER_VEHICLE", 0]
	# START: the haze fades in, the wisps start flowing at once (their particles drain into LOOP), one small pressure wave.
	var start := [_sprite("start.haze", haze[0], "CENTER", FLANK_OFFSET, FLANK_SCALE, haze[1], haze[2], haze[3], HAZE_IDLE, [
		_mod("start.haze.in", intro, 0.0, 0.4, 0.0, 1.0, "VISUAL_OPACITY_MULTIPLIER")])]
	start += _wisps("start")
	start += _wave("start.wave", intro, [0.0, -200.0], 0.0, [0.0, -160.0], 0.45, 0.0, 0.8)
	# LOOP: flowing wisps + embers; battle_engaged lifts only the faint haze (both sides alike in v1), wider and leaning in.
	var loop := [_sprite("loop.haze", haze[0], "CENTER", FLANK_OFFSET, FLANK_SCALE, haze[1], haze[2], haze[3], HAZE_IDLE, [
		_input_mod("loop.haze.battle_a", "battle_engaged", 0.0, 1.0, 1.0, HAZE_ENGAGED_GAIN, "VISUAL_OPACITY_MULTIPLIER"),
		_input_mod("loop.haze.battle_w", "battle_engaged", 0.0, 1.0, 1.0, ENGAGED_WIDTH, "TRANSFORM_SCALE_X"),
		_input_mod("loop.haze.battle_lean", "battle_engaged", 0.0, 1.0, 0.0, ENGAGED_LEAN, "TRANSFORM_OFFSET_Y")])]
	loop += _wisps("loop")
	# END: the LOOP wisps stop emitting and drain on their own (~0.45 s); the haze fades as a particle copy.
	var end := [_particle("end.haze", haze[0], "CENTER", FLANK_OFFSET, haze[2], haze[1], haze[3], {
		"emission_mode": "BURST", "burst_count": 1.0, "lifetime_seconds": END_SEC,
		"size_start": FLANK_HALF_LONG, "size_end": FLANK_HALF_LONG * 0.9, "alpha_start": HAZE_IDLE, "alpha_end": 0.0})]
	return _preset("talent.wheel_to_wheel", "Wheel to Wheel", "START_LOOP_END", ["battle_engaged"], sources,
		{"start": {"duration_seconds": START_SEC, "layers": start}, "loop": {"layers": loop}, "end": {"duration_seconds": END_SEC, "layers": end}})


## Two wisp streams per side (different art, speed spread and sway beat) + a few lemon embers per side.
func _wisps(phase: String) -> Array:
	var out := []
	for side in WISP_LAYERS:
		var sx := -1.0 if side == "l" else 1.0
		var origin := [WISP_ORIGIN.x * sx, WISP_ORIGIN.y]
		for i in WISP_LAYERS[side].size():
			var spec: Array = WISP_LAYERS[side][i]
			var id := "%s.wisp_%s%d" % [phase, side, i]
			var layer := _particle(id, WISP_TEX[spec[0]], "CENTER", origin, "OVER_VEHICLE", "ADDITIVE", 3, {
				"emission_mode": "CONTINUOUS", "emission_rate_per_second": WISP_RATE, "max_particles": 4.0,
				"lifetime_seconds": WISP_LIFE, "emitter": {"shape": "BOX", "size": WISP_BOX},
				"direction_degrees": 180.0, "spread_degrees": 1.0, "speed_min": WISP_SPEED[0], "speed_max": WISP_SPEED[1],
				"acceleration": [WISP_SCATTER * sx, 0.0], "angular_velocity_min_degrees_per_second": 0.0, "angular_velocity_max_degrees_per_second": 0.0,
				"size_start": WISP_SIZE[0], "size_end": WISP_SIZE[1], "size_multiplier_min": 0.8, "size_multiplier_max": 1.2,
				"alpha_start": WISP_ALPHA, "alpha_end": 0.0, "color_rgba": WISP_TINT})
			# Sway: the whole stream bends with a sine (each layer its own beat) -> wavering, broken-looking flow.
			layer["visual_bend"] = {"axis": "LOCAL_Y_POSITIVE", "curve": "QUADRATIC", "span_source_px": 220.0, "start_ratio": 0.3}
			layer["transform"]["modulation_pivot_local"] = [0.0, 0.0]
			layer["modulations"] = [{"id": id + ".sway", "operation": "ADD", "target": "VISUAL_BEND_OFFSET_X",
				"source": {"type": "PRESET_SOURCE", "source_id": "wheel_to_wheel.sway_%s%d" % [side, i]},
				"mapping": {"type": "LINEAR_RANGE", "input_min": -1.0, "input_max": 1.0, "output_min": -WISP_BEND, "output_max": WISP_BEND}}]
			layer["modulation_clamps"] = [{"target": "VISUAL_BEND_OFFSET_X", "min_effective": -WISP_BEND, "max_effective": WISP_BEND}]
			out.append(layer)
		out.append(_particle("%s.ember_%s" % [phase, side], "fx.wheel_to_wheel_spark", "CENTER", origin, "OVER_VEHICLE", "ADDITIVE", 4, {
			"emission_mode": "CONTINUOUS", "emission_rate_per_second": EMBER_RATE, "max_particles": 2.0, "lifetime_seconds": 0.4,
			"emitter": {"shape": "BOX", "size": WISP_BOX}, "direction_degrees": 180.0, "spread_degrees": 3.0,
			"speed_min": 500.0, "speed_max": 800.0, "acceleration": [WISP_SCATTER * sx, 0.0],
			"size_start": 36.0, "size_end": 12.0, "alpha_start": 0.5, "alpha_end": 0.0, "color_rgba": LEMON}))
	return out


func _surge() -> Dictionary:
	var t := "wheel_to_wheel_surge.time"
	# Same end point as before (250 forward): the wave does not reach further over the opponent, it just stays longer.
	var layers := _hit_wave("one_shot.wave", t, SURGE_SEC, [0.0, -230.0], 0.0, [0.0, -250.0], HIT_WAVE_SCALE)
	layers.append(_hit_flash("one_shot.nose_flash", t, SURGE_SEC, [0.0, -240.0]))
	for sx in [-1.0, 1.0]:
		layers.append(_sparks("one_shot.sparks_%s" % ("l" if sx < 0.0 else "r"), [FRONT_CORNER.x * sx, FRONT_CORNER.y], 35.0 * sx, 5.0, 0.75, 55.0))
	return _preset("talent.wheel_to_wheel_surge", "Wheel to Wheel Surge", "START_LOOP_END", [],
		[{"id": t, "type": "LINEAR_PHASE", "frequency_hz": 1.0 / SURGE_SEC}], _moment(SURGE_SEC, layers))


## side = -1: the opponent is on my left (sparks at my front-left, I kick out to the right); +1 the mirror.
func _grind(side: float) -> Dictionary:
	var t := "wheel_to_wheel_grind.time"
	var corner := [FRONT_CORNER.x * side, FRONT_CORNER.y]
	var fan_tex := "fx.wheel_to_wheel_spark_fan_r" if side > 0.0 else "fx.wheel_to_wheel_spark_fan_l"
	var origin := Vector2(FAN_ORIGIN_R.x * side, FAN_ORIGIN_R.y)
	var fan_centre := [corner[0] - origin.x * HIT_FAN_SCALE, corner[1] - origin.y * HIT_FAN_SCALE]
	var fan_id := "one_shot.spark_fan"
	# Fan spreads from the spark origin (pivot): x0.55 -> x1.15 in the burst, then slowly to x1.25.
	var fan_mods := _hit_opacity(fan_id, t, GRIND_SEC)
	for axis in ["X", "Y"]:
		fan_mods.append(_mod("%s.grow_%s" % [fan_id, axis.to_lower()], t, 0.0, HIT_BURST_SEC / GRIND_SEC, 0.55, 1.15, "TRANSFORM_SCALE_" + axis))
		fan_mods.append(_mod("%s.spread_%s" % [fan_id, axis.to_lower()], t, HIT_BURST_SEC / GRIND_SEC, HIT_FADE_END_SEC / GRIND_SEC, 1.0, 1.25 / 1.15, "TRANSFORM_SCALE_" + axis))
	var layers := [
		_sprite(fan_id, fan_tex, "CENTER", fan_centre, [HIT_FAN_SCALE, HIT_FAN_SCALE], "ADDITIVE", "OVER_VEHICLE", 4, 1.0, fan_mods, [origin.x, origin.y]),
		_hit_flash("one_shot.contact_flash", t, GRIND_SEC, corner),
		_sparks("one_shot.sparks", corner, 125.0 * side, 9.0, 0.75, 60.0)]
	# Kick-out wave on the escape side: crescent rotated to bulge outward, pushed ~10 screen px out (same end point as before).
	layers += _hit_wave("one_shot.kick", t, GRIND_SEC, [-250.0 * side, -60.0], -90.0 * side, [-150.0 * side, 0.0], HIT_KICK_SCALE)
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


## Moment opacity envelope (multiplied ranges over the phase): burst in, hold the peak, quick drop to 55 %, slow fade out.
func _hit_opacity(id: String, source: String, seconds: float) -> Array:
	return [
		_mod(id + ".in", source, 0.0, HIT_IN_SEC / seconds, 0.0, 1.0, "VISUAL_OPACITY_MULTIPLIER"),
		_mod(id + ".settle", source, HIT_PEAK_SEC / seconds, HIT_SETTLE_SEC / seconds, 1.0, HIT_SETTLE_LEVEL, "VISUAL_OPACITY_MULTIPLIER"),
		_mod(id + ".out", source, HIT_SETTLE_SEC / seconds, HIT_FADE_END_SEC / seconds, 1.0, 0.0, "VISUAL_OPACITY_MULTIPLIER")]


## Moment pressure wave (ALPHA air + ADD rim): most of the growth (x0.6 -> x1.2) and travel (68 %) in the burst, then
## slowly to x1.35 and the full `travel` while it fades. The end point stays where the 11-26 wave ended.
func _hit_wave(id: String, source: String, seconds: float, offset: Array, rotation: float, travel: Array, scale: float) -> Array:
	var out := []
	var burst := HIT_BURST_SEC / seconds
	var fade_end := HIT_FADE_END_SEC / seconds
	for part in [["body", "fx.wheel_to_wheel_wave_body", "ALPHA", 6, 0.95], ["rim", "fx.wheel_to_wheel_wave_rim", "ADDITIVE", 7, 1.0]]:
		var lid := "%s_%s" % [id, part[0]]
		var mods := _hit_opacity(lid, source, seconds)
		for axis in ["X", "Y"]:
			mods.append(_mod("%s.grow_%s" % [lid, axis.to_lower()], source, 0.0, burst, 0.6, 1.2, "TRANSFORM_SCALE_" + axis))
			mods.append(_mod("%s.drift_%s" % [lid, axis.to_lower()], source, burst, fade_end, 1.0, 1.35 / 1.2, "TRANSFORM_SCALE_" + axis))
		for i in 2:
			if travel[i] != 0.0:
				var axis: String = ["x", "y"][i]
				var target: String = ["TRANSFORM_OFFSET_X", "TRANSFORM_OFFSET_Y"][i]
				mods.append(_mod("%s.travel_%s" % [lid, axis], source, 0.0, burst, 0.0, travel[i] * 0.68, target))
				mods.append(_mod("%s.coast_%s" % [lid, axis], source, burst, fade_end, 0.0, travel[i] * 0.32, target))
		var layer := _sprite(lid, part[1], "CENTER", offset, [scale, scale], part[2], "OVER_VEHICLE", part[3], part[4], mods)
		layer["transform"]["rotation_degrees"] = rotation
		out.append(layer)
	return out


## Moment flash: swells x1.15 at the peak, then shrinks to x0.8 while it lingers as a glow.
func _hit_flash(id: String, source: String, seconds: float, offset: Array) -> Dictionary:
	var mods := _hit_opacity(id, source, seconds)
	for axis in ["X", "Y"]:
		mods.append(_mod("%s.swell_%s" % [id, axis.to_lower()], source, 0.0, HIT_PEAK_SEC / seconds, 0.9, 1.15, "TRANSFORM_SCALE_" + axis))
		mods.append(_mod("%s.shrink_%s" % [id, axis.to_lower()], source, HIT_PEAK_SEC / seconds, HIT_FADE_END_SEC / seconds, 1.0, 0.8 / 1.15, "TRANSFORM_SCALE_" + axis))
	return _sprite(id, "fx.wheel_to_wheel_contact_flash", "CENTER", offset, [HIT_FLASH_SCALE, HIT_FLASH_SCALE], "ADDITIVE", "OVER_VEHICLE", 5, 1.0, mods)


## Lemon sparks (white-hot copy of the Furious Overtake spark, tinted): direction degrees clockwise from forward (0 forward, 90 right, 180 back).
## Hit v1: longer life at lower speed (about the same reach), a bit bigger.
func _sparks(id: String, offset: Array, direction: float, count: float, life: float, spread: float) -> Dictionary:
	return _particle(id, "fx.wheel_to_wheel_spark", "CENTER", offset, "OVER_VEHICLE", "ADDITIVE", 8, {
		"emission_mode": "BURST", "burst_count": count, "lifetime_seconds": life, "size_start": 120.0, "size_end": 36.0,
		"alpha_start": 1.0, "alpha_end": 0.0, "color_rgba": LEMON, "direction_degrees": fposmod(direction, 360.0),
		"spread_degrees": spread, "speed_min": 180.0, "speed_max": 380.0, "rotation_min_degrees": 0.0, "rotation_max_degrees": 360.0})


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
