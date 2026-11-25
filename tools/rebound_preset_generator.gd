extends SceneTree
# Generator for the Rebound talent preset. Run:
#   godot --headless --path <studio> --script res://tools/rebound_preset_generator.gd
# Output: presets/examples/talent.rebound.vfx.json. Design: docs/superpowers/specs/2026-11-25-talent-rebound-design.md
const OUT := "res://presets/examples/talent.rebound.vfx.json"
const WHEEL := Vector2(84.0, 160.0)
const RAIL := Vector2(140.0, 40.0)
const RAIL_PIVOT := [0.0, 250.0]
const RAIL_LEN := 1.45
const RAIL_CORE := [4.5, 0.8]        # [scale X, opacity]
const RIM_CORE := [[1.8, 1.35], 1.0]  # [scale, opacity]
const GLOW := [1.9, 0.5]             # contact glow pool under the rear wheel [uniform scale, opacity]
const PULSE := [4.5, 0.45, 0.9]       # light pulse running along the rail [scale X, scale Y, opacity]
const PULSE_TRAVEL := 360.0
const START_SEC := 0.9
const MIST_TINT := [0.4, 1.0, 0.78, 1.0]   # less red than the texture's own mint -> deeper, more saturated mint


func _init() -> void:
	var start_layers := []
	var loop_layers := []
	var end_layers := []
	for side in [["l", -1.0], ["r", 1.0]]:
		var s: String = side[0]
		var sx: float = side[1]
		var wheel := [WHEEL.x * sx, WHEEL.y]
		var rail := [RAIL.x * sx, RAIL.y]
		# --- START only: contact mist burst
		# Tire-wear emphasis: saturated mint energy spreading behind the rear wheels (strong at START, steady in LOOP).
		var behind := [WHEEL.x * sx, WHEEL.y + 35.0]
		start_layers.append(_particle("start.mist_" + s, "fx.rebound_contact_mist", behind, "UNDER_VEHICLE", 1, "CORE", {
			"emission_mode": "BURST", "burst_count": 4.0, "lifetime_seconds": 0.8,
			"size_start": 90.0, "size_end": 230.0, "alpha_start": 1.0, "alpha_end": 0.0, "color_rgba": MIST_TINT,
			"direction_degrees": 180.0, "speed_min": 50.0, "speed_max": 150.0, "spread_degrees": 140.0,
			"rotation_min_degrees": 0.0, "rotation_max_degrees": 360.0}))
		# LOOP: faint overlapping puffs (rate x life >= 3) so moving particles never pop in visibly.
		loop_layers.append(_particle("loop.mist_" + s, "fx.rebound_contact_mist", behind, "UNDER_VEHICLE", 1, "CORE", {
			"emission_mode": "CONTINUOUS", "emission_rate_per_second": 6.0, "max_particles": 5.0, "lifetime_seconds": 0.65,
			"size_start": 110.0, "size_end": 250.0, "alpha_start": 0.65, "alpha_end": 0.0, "color_rgba": MIST_TINT,
			"direction_degrees": 180.0, "speed_min": 110.0, "speed_max": 170.0, "spread_degrees": 35.0,
			"rotation_min_degrees": 0.0, "rotation_max_degrees": 360.0}))
		# --- layers present in START (with intro ramps) and LOOP (with breath)
		var defs := [
			["glow", "fx.rebound_contact_mist", wheel, [GLOW[0], GLOW[0]], [0.0, 0.0], "UNDER_VEHICLE", 1.0, GLOW[1], "fade_in", [0.75, 1.0]],
			["rail", "fx.rebound_grip_rail", rail, [RAIL_CORE[0], RAIL_LEN], RAIL_PIVOT, "UNDER_VEHICLE", 3.0, RAIL_CORE[1], "grow", [0.8, 1.0]],
			["rim", "fx.rebound_rim_glow", wheel, RIM_CORE[0], [0.0, 0.0], "OVER_VEHICLE", 2.0, RIM_CORE[1], "flash", [0.75, 1.0]],
		]
		for d in defs:
			var name: String = d[0]
			var intro := []
			var sid := "start.%s_%s" % [name, s]
			match d[8]:
				"fade_in":
					intro = [_mod(sid + ".in", "rebound.intro", 0.0, 0.3, 0.0, 1.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER")]
				"grow":
					intro = [_mod(sid + ".grow", "rebound.intro", 0.0, 0.4, 0.02, 1.0, "MULTIPLY", "TRANSFORM_SCALE_Y"),
						_mod(sid + ".fade", "rebound.intro", 0.0, 0.15, 0.3, 1.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER")]
				"flash":
					intro = [_mod(sid + ".flash_x", "rebound.intro", 0.0, 0.35, 1.5, 1.0, "MULTIPLY", "TRANSFORM_SCALE_X"),
						_mod(sid + ".flash_y", "rebound.intro", 0.0, 0.35, 1.5, 1.0, "MULTIPLY", "TRANSFORM_SCALE_Y")]
			start_layers.append(_sprite(sid, d[1], d[2], d[3], d[4], d[5], d[6], d[7], intro))
			var lid := "loop.%s_%s" % [name, s]
			loop_layers.append(_sprite(lid, d[1], d[2], d[3], d[4], d[5], d[6], d[7], [
				_mod(lid + ".breath", "rebound.breath", -1.0, 1.0, d[9][0], d[9][1], "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER")]))
		# --- LOOP only: light pulse running front -> back along each rail (period = START_SEC, so it starts at the front)
		var pid := "loop.pulse_" + s
		loop_layers.append(_sprite(pid, "fx.rebound_grip_rail", rail, [PULSE[0], PULSE[1]], [0.0, 0.0], "UNDER_VEHICLE", 4.0, PULSE[2], [
			_mod(pid + ".move", "rebound.pulse", 0.0, 1.0, -PULSE_TRAVEL, PULSE_TRAVEL, "ADD", "TRANSFORM_OFFSET_Y"),
			_mod(pid + ".in", "rebound.pulse", 0.0, 0.15, 0.0, 1.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"),
			_mod(pid + ".out", "rebound.pulse", 0.8, 1.0, 1.0, 0.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER")]))
		# --- END: TEXTURED_SPRITE cannot ramp in END (effect-local time is unknown there), so fade particle copies.
		# PARTICLE size is half of the texture's longest displayed side.
		end_layers.append(_end_particle("end.glow_" + s, "fx.rebound_contact_mist", wheel, "UNDER_VEHICLE", 1.0, 64.0 * GLOW[0], GLOW[1] * 0.9))
		end_layers.append(_end_particle("end.rail_" + s, "fx.rebound_grip_rail", rail, "UNDER_VEHICLE", 3.0, 256.0 * RAIL_LEN, RAIL_CORE[1] * 0.9))
		end_layers.append(_end_particle("end.rim_" + s, "fx.rebound_rim_glow", wheel, "OVER_VEHICLE", 2.0, 64.0 * RIM_CORE[0][1], 0.9))
	var preset := {
		"schema_version": 1.0,
		"preset_id": "talent.rebound",
		"display_name": "Rebound",
		"category": "RACE_TALENT",
		"default_space_mode": "VEHICLE_LOCAL",
		"lifecycle": {"mode": "START_LOOP_END"},
		"runtime_inputs": [],
		"runtime_modulation_sources": [
			{"id": "rebound.intro", "type": "LINEAR_PHASE", "frequency_hz": 1.0 / START_SEC},
			{"id": "rebound.pulse", "type": "LINEAR_PHASE", "frequency_hz": 1.0 / START_SEC},
			# value +1 at the START->LOOP hand-over (t = START_SEC) so LOOP opacity matches START end.
			{"id": "rebound.breath", "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": 0.8,
				"phase_degrees": fposmod(90.0 - 360.0 * 0.8 * START_SEC, 360.0)}],
		"phases": {
			"start": {"duration_seconds": START_SEC, "layers": start_layers},
			"loop": {"layers": loop_layers},
			"end": {"duration_seconds": 0.4, "layers": end_layers}}
	}
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(preset, "  ", true) + "\n")
	f.close()
	print("wrote ", OUT)
	quit(0)


func _sprite(id: String, tex: String, offset: Array, scale: Array, pivot: Array, plane: String, sort: float, opacity: float, mods: Array) -> Dictionary:
	return {"id": id, "type": "TEXTURED_SPRITE", "enabled": true, "importance": "CORE", "anchors": ["CENTER"],
		"blend_mode": "ADDITIVE", "render_plane": plane, "sort_order": sort, "modulations": mods,
		"parameters": {"opacity": opacity, "texture_asset_ref": tex},
		"transform": {"offset": offset, "rotation_degrees": 0.0, "scale": scale, "modulation_pivot_local": pivot}}


func _particle(id: String, tex: String, offset: Array, plane: String, sort: float, importance: String, p: Dictionary) -> Dictionary:
	var params := {"acceleration": [0.0, 0.0], "angular_velocity_min_degrees_per_second": 0.0, "angular_velocity_max_degrees_per_second": 0.0,
		"color_rgba": [1.0, 1.0, 1.0, 1.0], "direction_degrees": 0.0, "emitter": {"shape": "POINT"},
		"rotation_min_degrees": 0.0, "rotation_max_degrees": 0.0, "size_multiplier_min": 1.0, "size_multiplier_max": 1.0,
		"speed_min": 0.0, "speed_max": 0.0, "spread_degrees": 0.0, "sprite_asset_ref": tex}
	params.merge(p, true)
	return {"id": id, "type": "PARTICLE", "enabled": true, "importance": importance, "anchors": ["CENTER"],
		"blend_mode": "ADDITIVE", "render_plane": plane, "sort_order": sort, "parameters": params,
		"transform": {"offset": offset, "rotation_degrees": 0.0, "scale": [1.0, 1.0]}}


func _mod(id: String, source_id: String, in_min: float, in_max: float, out_min: float, out_max: float, op: String, target: String) -> Dictionary:
	return {"id": id, "operation": op, "target": target,
		"source": {"type": "PRESET_SOURCE", "source_id": source_id},
		"mapping": {"type": "LINEAR_RANGE", "input_min": in_min, "input_max": in_max, "output_min": out_min, "output_max": out_max}}


func _end_particle(id: String, tex: String, offset: Array, plane: String, sort: float, size: float, alpha: float) -> Dictionary:
	return _particle(id, tex, offset, plane, sort, "CORE", {"emission_mode": "BURST", "burst_count": 1.0, "lifetime_seconds": 0.4,
		"size_start": size, "size_end": size, "alpha_start": alpha, "alpha_end": 0.0})
