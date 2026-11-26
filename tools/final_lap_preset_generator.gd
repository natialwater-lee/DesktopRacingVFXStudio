extends SceneTree
# Generator for the Final Lap talent preset. Run:
#   godot --headless --path <studio> --script res://tools/final_lap_preset_generator.gd
# Output: presets/examples/talent.final_lap.vfx.json. Design: docs/superpowers/specs/2026-11-26-talent-final-lap-design.md
#
# START: crimson charge ring sucked into the car -> white/crimson flash -> checker finish-line band passing under
#        the car nose to tail -> flank ribbons whipped out backwards from their front end.
# LOOP:  black/white checker ribbons on both flanks (ALPHA) + white sheen / crimson edge (ADDITIVE) + crimson road
#        spill. They flutter (two oscillators on visual_bend) and trail out on corners (turn_rate). boost_active
#        (normal boost, Game-smoothed) stretches them backwards and brightens the crimson.
# END:   particle copies fade (TEXTURED_SPRITE cannot ramp in END).
# Units: art canvas texel = SCALE source px. The 512x768 GPT canvas had the car at x156..356, y160..560
# (centre texel y 360); body/sheen were padded to 704 wide by tools/final_lap_art_prep.gd (centre unchanged).
const OUT := "res://presets/examples/talent.final_lap.vfx.json"
const SCALE := 1.15                              # ribbon width scale (art texel -> source px)
const SCALE_Y := 1.0                              # ribbon length scale
const HEAD_Y := -120.0                            # ribbon front end (source px), beside the front wheels
const HEAD_TEXEL_Y := 195.0 - 384.0               # ribbon front end, texels from the texture centre (pivot)
const CENTRE_Y := HEAD_Y - HEAD_TEXEL_Y * SCALE_Y # sprite centre y (source px)
# Each side is a 352-texel half of the padded 704 canvas; the car centre is the canvas centre x 352.
const SIDE_X := 176.0 * SCALE + 8.0               # |x| of a half-texture centre (source px), nudged outward
const FLARE_DEGREES := 5.0                        # tails lean outward (left +, right -)
const RIBBON_SPAN := 540.0                        # texels from the front end to the faded tail
const BODY_OPACITY := 0.9
const SHEEN_OPACITY := 0.42
const SPILL_OPACITY := 0.5
const BOOST_LENGTH := 1.25
const BOOST_SHEEN := 0.9 / SHEEN_OPACITY          # sheen 0.42 -> 0.9
const BOOST_SPILL := 0.9 / SPILL_OPACITY          # spill 0.5 -> 0.9
# Flutter: [Hz, tail sway in source px, phase left, phase right] - the two sides do not wave in step.
const FLUTTER_A := [1.3, 22.0, 0.0, 140.0]
const FLUTTER_B := [2.1, 12.0, 90.0, 250.0]
const SWAY_DEGREES := 3.5                         # streamer swing about its front end (left/right off-beat)
const RIPPLE := 0.07                              # width ripple of the cloth
const TAIL_X := 222.0                             # where the tail scraps tear off (source px, after the flare)
const TAIL_Y := 285.0
const TURN_FULL := 0.1                           # measured corner p90 (Drift Master 2026-11-26)
const TURN_BEND := 55.0                           # tail shift (source px) at |turn| >= TURN_FULL, right turn -> +x
const START_SEC := 0.7
const END_SEC := 0.4


func _init() -> void:
	var start_layers := []
	var loop_layers := []
	var end_layers := []
	# START 0.00-0.30 s: charge ring shrinking into the car (radius ~2x car half-length -> under a quarter).
	start_layers.append(_sprite("start.charge_ring", "fx.final_lap_charge_ring", [0.0, 0.0], [2.25, 2.25], [0.0, 0.0], "ADDITIVE", "OVER_VEHICLE", 20, 1.0, [
		_mod("start.charge_ring.sx", _src("fl.intro"), 0.0, 0.43, 1.0, 0.22, "MULTIPLY", "TRANSFORM_SCALE_X"),
		_mod("start.charge_ring.sy", _src("fl.intro"), 0.0, 0.43, 1.0, 0.22, "MULTIPLY", "TRANSFORM_SCALE_Y"),
		_mod("start.charge_ring.in", _src("fl.intro"), 0.0, 0.3, 0.45, 1.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"),
		_mod("start.charge_ring.out", _src("fl.intro"), 0.36, 0.46, 1.0, 0.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER")]))
	# 0.25-0.45 s: flash where the ring lands.
	start_layers.append(_sprite("start.charge_flash", "fx.final_lap_charge_flash", [0.0, 0.0], [3.4, 3.4], [0.0, 0.0], "ADDITIVE", "OVER_VEHICLE", 21, 1.0, [
		_mod("start.charge_flash.in", _src("fl.intro"), 0.34, 0.42, 0.0, 1.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"),
		_mod("start.charge_flash.out", _src("fl.intro"), 0.42, 0.68, 1.0, 0.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"),
		_mod("start.charge_flash.sx", _src("fl.intro"), 0.34, 0.68, 0.7, 1.25, "MULTIPLY", "TRANSFORM_SCALE_X"),
		_mod("start.charge_flash.sy", _src("fl.intro"), 0.34, 0.68, 0.7, 1.25, "MULTIPLY", "TRANSFORM_SCALE_Y")]))
	# 0.25-0.65 s: checker finish line passing under the car from in front of the nose to behind the tail.
	start_layers.append(_sprite("start.finish_line", "fx.final_lap_finish_line", [0.0, -330.0], [SCALE, SCALE], [0.0, 0.0], "ALPHA", "UNDER_VEHICLE", 4, 0.95, [
		_mod("start.finish_line.move", _src("fl.intro"), 0.36, 0.93, 0.0, 680.0, "ADD", "TRANSFORM_OFFSET_Y"),
		_mod("start.finish_line.in", _src("fl.intro"), 0.36, 0.44, 0.0, 1.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"),
		_mod("start.finish_line.out", _src("fl.intro"), 0.78, 0.93, 1.0, 0.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER")]))
	for phase in ["start", "loop"]:
		var intro: bool = phase == "start"
		var target: Array = start_layers if intro else loop_layers
		# crimson road spill (art at half resolution -> x2)
		var spill_id: String = phase + ".spill"
		var spill_mods := [
			_mod(spill_id + ".boost_a", _input("boost_active"), 0.0, 1.0, 1.0, BOOST_SPILL, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"),
			_mod(spill_id + ".boost_l", _input("boost_active"), 0.0, 1.0, 1.0, BOOST_LENGTH, "MULTIPLY", "TRANSFORM_SCALE_Y")]
		if intro:
			spill_mods += _unfurl_mods(spill_id)
		target.append(_sprite(spill_id, "fx.final_lap_flag_spill", [0.0, CENTRE_Y], [SCALE * 2.0, SCALE_Y * 2.0], [0.0, HEAD_TEXEL_Y * 0.5], "ADDITIVE", "UNDER_VEHICLE", 1, SPILL_OPACITY, spill_mods))
		# checker ribbons (ALPHA) and their sheen / crimson edge (ADDITIVE), one sprite per side, bent together
		for side in [["l", -1.0], ["r", 1.0]]:
			for part in [["body", "ALPHA", 2, BODY_OPACITY, 1.0], ["sheen", "ADDITIVE", 3, SHEEN_OPACITY, BOOST_SHEEN]]:
				var id: String = "%s.%s_%s" % [phase, part[0], side[0]]
				var mods := [_mod(id + ".boost_l", _input("boost_active"), 0.0, 1.0, 1.0, BOOST_LENGTH, "MULTIPLY", "TRANSFORM_SCALE_Y")]
				if float(part[4]) != 1.0:
					mods.append(_mod(id + ".boost_a", _input("boost_active"), 0.0, 1.0, 1.0, part[4], "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"))
				# always moving: the streamer swings about its front end and its width ripples (visible in Studio
				# and Game; the Game also bends the tail with the flutter below); the sheen glints.
				mods.append(_mod(id + ".sway", _src("fl.sway_" + side[0]), -1.0, 1.0, -SWAY_DEGREES, SWAY_DEGREES, "ADD", "TRANSFORM_ROTATION_DEGREES"))
				mods.append(_mod(id + ".ripple", _src("fl.ripple_" + side[0]), -1.0, 1.0, 1.0 - RIPPLE, 1.0 + RIPPLE, "MULTIPLY", "TRANSFORM_SCALE_X"))
				if part[0] == "sheen":
					mods.append(_mod(id + ".glint", _src("fl.glint_" + side[0]), -1.0, 1.0, 0.65, 1.25, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"))
				if intro:
					mods += _unfurl_mods(id)
				var layer := _sprite(id, "fx.final_lap_flag_%s_%s" % [part[0], side[0]], [SIDE_X * side[1], CENTRE_Y], [SCALE, SCALE_Y], [0.0, HEAD_TEXEL_Y], part[1], "UNDER_VEHICLE", part[2], part[3], mods)
				layer["transform"]["rotation_degrees"] = -FLARE_DEGREES * side[1]
				_add_bend(layer, side[0])
				target.append(layer)
			# LOOP: checker scraps torn off the tail, tumbling back (rate x life ~3 so they never visibly pop in).
			if not intro:
				var tail := [TAIL_X * side[1], TAIL_Y]
				var pieces := _particle("loop.pieces_" + side[0], "fx.final_lap_flag_piece", "ALPHA", tail, 2, {
					"emission_mode": "CONTINUOUS", "emission_rate_per_second": 5.5, "max_particles": 6.0, "lifetime_seconds": 0.7,
					"size_start": 70.0, "size_end": 40.0, "alpha_start": 0.95, "alpha_end": 0.0,
					"direction_degrees": 180.0 + 12.0 * side[1], "speed_min": 150.0, "speed_max": 260.0, "spread_degrees": 30.0,
					"rotation_min_degrees": 0.0, "rotation_max_degrees": 360.0,
					"angular_velocity_min_degrees_per_second": -320.0, "angular_velocity_max_degrees_per_second": 320.0})
				pieces["parameters"]["emitter"] = {"shape": "BOX", "size": [40.0, 60.0]}
				target.append(pieces)
	# END: particle copies fade; PARTICLE size = half of the longest displayed side; not bent.
	end_layers.append(_particle("end.spill", "fx.final_lap_flag_spill", "ADDITIVE", [0.0, CENTRE_Y], 1, _fade(192.0 * SCALE_Y * 2.0, SPILL_OPACITY)))
	for side in [["l", -1.0], ["r", 1.0]]:
		var at := [SIDE_X * side[1], CENTRE_Y]
		var body := _particle("end.body_" + side[0], "fx.final_lap_flag_body_" + side[0], "ALPHA", at, 2, _fade(384.0 * SCALE_Y, BODY_OPACITY))
		var sheen := _particle("end.sheen_" + side[0], "fx.final_lap_flag_sheen_" + side[0], "ADDITIVE", at, 3, _fade(384.0 * SCALE_Y, SHEEN_OPACITY))
		for p in [body, sheen]:
			p["transform"]["rotation_degrees"] = -FLARE_DEGREES * side[1]
			end_layers.append(p)
	var preset := {
		"schema_version": 1.0,
		"preset_id": "talent.final_lap",
		"display_name": "Final Lap",
		"category": "RACE_TALENT",
		"default_space_mode": "VEHICLE_LOCAL",
		"lifecycle": {"mode": "START_LOOP_END"},
		"runtime_inputs": ["turn_rate_normalized", "boost_active"],
		"runtime_modulation_sources": [
			{"id": "fl.intro", "type": "LINEAR_PHASE", "frequency_hz": 1.0 / START_SEC},
			{"id": "fl.flutter_a_l", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": FLUTTER_A[0], "phase_degrees": FLUTTER_A[2]},
			{"id": "fl.flutter_b_l", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": FLUTTER_B[0], "phase_degrees": FLUTTER_B[2]},
			{"id": "fl.flutter_a_r", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": FLUTTER_A[0], "phase_degrees": FLUTTER_A[3]},
			{"id": "fl.flutter_b_r", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": FLUTTER_B[0], "phase_degrees": FLUTTER_B[3]},
			{"id": "fl.sway_l", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 1.1, "phase_degrees": 0.0},
			{"id": "fl.sway_r", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 1.1, "phase_degrees": 160.0},
			{"id": "fl.ripple_l", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 2.6, "phase_degrees": 0.0},
			{"id": "fl.ripple_r", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 2.6, "phase_degrees": 110.0},
			{"id": "fl.glint_l", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 3.3, "phase_degrees": 0.0},
			{"id": "fl.glint_r", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 3.3, "phase_degrees": 200.0}],
		"phases": {
			"start": {"duration_seconds": START_SEC, "layers": start_layers},
			"loop": {"layers": loop_layers},
			"end": {"duration_seconds": END_SEC, "layers": end_layers}}
	}
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(preset, "  ", true) + "\n")
	f.close()
	print("wrote ", OUT)
	quit(0)


# START: hidden until the flash (0.30 s), then whipped out backwards from the front end 0.30-0.56 s to x1.1,
# settling to x1.0 by the end of START.
func _unfurl_mods(id: String) -> Array:
	return [
		_mod(id + ".show", _src("fl.intro"), 0.42, 0.5, 0.0, 1.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"),
		_mod(id + ".grow", _src("fl.intro"), 0.43, 0.8, 0.2, 1.1, "MULTIPLY", "TRANSFORM_SCALE_Y"),
		_mod(id + ".settle", _src("fl.intro"), 0.8, 1.0, 1.0, 1.0 / 1.1, "MULTIPLY", "TRANSFORM_SCALE_Y")]


# Flutter (two sines) + corner trail. Bend offsets are texels; the art prep left 96 texels of side padding.
func _add_bend(layer: Dictionary, side: String) -> void:
	var a: float = FLUTTER_A[1] / SCALE
	var b: float = FLUTTER_B[1] / SCALE
	var t := TURN_BEND / SCALE
	var limit := a + b + t
	layer["visual_bend"] = {"axis": "LOCAL_Y_POSITIVE", "curve": "QUADRATIC", "start_ratio": 0.1, "span_source_px": RIBBON_SPAN}
	var id: String = layer["id"]
	layer["modulations"].append(_mod(id + ".flutter_a", _src("fl.flutter_a_" + side), -1.0, 1.0, -a, a, "ADD", "VISUAL_BEND_OFFSET_X"))
	layer["modulations"].append(_mod(id + ".flutter_b", _src("fl.flutter_b_" + side), -1.0, 1.0, -b, b, "ADD", "VISUAL_BEND_OFFSET_X"))
	layer["modulations"].append(_mod(id + ".corner", _input("turn_rate_normalized"), -TURN_FULL, TURN_FULL, -t, t, "ADD", "VISUAL_BEND_OFFSET_X"))
	layer["modulation_clamps"] = [{"target": "VISUAL_BEND_OFFSET_X", "min_effective": -limit, "max_effective": limit}]


func _src(source_id: String) -> Dictionary:
	return {"type": "PRESET_SOURCE", "source_id": source_id}


func _input(input_name: String) -> Dictionary:
	return {"type": "RUNTIME_INPUT", "input": input_name}


func _sprite(id: String, tex: String, offset: Array, scale: Array, pivot: Array, blend: String, plane: String, sort: int, opacity: float, mods: Array) -> Dictionary:
	return {"id": id, "type": "TEXTURED_SPRITE", "enabled": true, "importance": "CORE", "anchors": ["CENTER"],
		"blend_mode": blend, "render_plane": plane, "sort_order": sort, "modulations": mods,
		"parameters": {"opacity": opacity, "texture_asset_ref": tex},
		"transform": {"offset": offset, "rotation_degrees": 0.0, "scale": scale, "modulation_pivot_local": pivot}}


func _particle(id: String, tex: String, blend: String, offset: Array, sort: int, p: Dictionary) -> Dictionary:
	var params := {"acceleration": [0.0, 0.0], "angular_velocity_min_degrees_per_second": 0.0, "angular_velocity_max_degrees_per_second": 0.0,
		"color_rgba": [1.0, 1.0, 1.0, 1.0], "direction_degrees": 0.0, "emitter": {"shape": "POINT"},
		"rotation_min_degrees": 0.0, "rotation_max_degrees": 0.0, "size_multiplier_min": 1.0, "size_multiplier_max": 1.0,
		"speed_min": 0.0, "speed_max": 0.0, "spread_degrees": 0.0, "sprite_asset_ref": tex}
	params.merge(p, true)
	return {"id": id, "type": "PARTICLE", "enabled": true, "importance": "CORE", "anchors": ["CENTER"],
		"blend_mode": blend, "render_plane": "UNDER_VEHICLE", "sort_order": sort, "parameters": params,
		"transform": {"offset": offset, "rotation_degrees": 0.0, "scale": [1.0, 1.0]}}


func _fade(size: float, alpha: float) -> Dictionary:
	return {"emission_mode": "BURST", "burst_count": 1.0, "lifetime_seconds": END_SEC,
		"size_start": size, "size_end": size * 0.92, "alpha_start": alpha, "alpha_end": 0.0}


func _mod(id: String, source: Dictionary, in_min: float, in_max: float, out_min: float, out_max: float, op: String, target: String) -> Dictionary:
	return {"id": id, "operation": op, "target": target, "source": source,
		"mapping": {"type": "LINEAR_RANGE", "input_min": in_min, "input_max": in_max, "output_min": out_min, "output_max": out_max}}
