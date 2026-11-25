extends SceneTree
# Generator for the Drift Master talent preset. Run:
#   godot --headless --path <studio> --script res://tools/drift_master_preset_generator.gd
# Output: presets/examples/talent.drift_master.vfx.json. Design: docs/superpowers/specs/2026-11-25-talent-drift-master-design.md
#
# LOOP (always): magenta neon tails behind both rear wheels + haze under them, bent along the corner just driven
# (turn_rate_normalized -> visual_bend), a little longer/brighter the harder the corner.
# Drift moment: drift_active (Game-smoothed 0..1) flares the tails and blooms pink tyre smoke.
# Texel units: transform pivots, bend span/offset are texture texels; offsets are vehicle source px.
const OUT := "res://presets/examples/talent.drift_master.vfx.json"
const HEAD := Vector2(95.0, 205.0)     # tail head (source px), just behind and outside the rear wheel (84, 160)
const HEAD_TEXEL_Y := -240.0           # both tail textures start at texel y 16 of 512
const TAIL_SPAN := 420.0               # texels from head to the faded tail end
const TAIL := [2.1, 1.6, 0.85]         # neon tail [scale X, scale Y, opacity]
const HAZE := [2.0, 1.7, 1.0]          # neon body: fills between the two strands and glows past them
const BEND_SOURCE_PX := 130.0          # tail tip shift at |turn| 0.2 (same in source px for tail and haze)
const SMOKE := Vector2(110.0, 340.0)   # drift smoke centre (source px), behind the rear bumper
const SMOKE_SCALE := 1.7
const SMOKE_OPACITY := 0.85
const SMOKE_OUTWARD := 45.0            # smoke pushed to the outside of the corner (source px)
const START_SEC := 0.6
const END_SEC := 0.4


func _init() -> void:
	var start_layers := []
	var loop_layers := []
	var end_layers := []
	# START: neon flash pool under the car (fades out by the end of START)
	start_layers.append(_sprite("start.flash", "fx.drift_master_tail_haze", [0.0, 120.0], [3.2, 1.6], [0.0, 0.0], "ADDITIVE", 1, 0.7, [
		_mod("start.flash.in", _src("drift.intro"), 0.0, 0.25, 0.0, 1.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"),
		_mod("start.flash.out", _src("drift.intro"), 0.25, 1.0, 1.0, 0.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER")]))
	for side in [["l", -1.0], ["r", 1.0]]:
		var s: String = side[0]
		var sx: float = side[1]
		var tail_centre := [HEAD.x * sx, HEAD.y - HEAD_TEXEL_Y * TAIL[1]]
		var haze_centre := [HEAD.x * sx, HEAD.y - HEAD_TEXEL_Y * HAZE[1]]
		var smoke := [SMOKE.x * sx, SMOKE.y]
		# START: pink smoke burst spreading back and out
		start_layers.append(_particle("start.smoke_" + s, "fx.drift_master_drift_smoke", "ALPHA", [HEAD.x * sx, HEAD.y + 20.0], 2, {
			"emission_mode": "BURST", "burst_count": 3.0, "lifetime_seconds": 0.6,
			"size_start": 70.0, "size_end": 190.0, "alpha_start": 0.9, "alpha_end": 0.0,
			"direction_degrees": 180.0 - 35.0 * sx, "speed_min": 60.0, "speed_max": 160.0, "spread_degrees": 70.0,
			"rotation_min_degrees": 0.0, "rotation_max_degrees": 360.0}))
		for phase in ["start", "loop"]:
			var intro: bool = phase == "start"
			# haze under the tail
			var hid := "%s.haze_%s" % [phase, s]
			var haze_mods := _corner_mods(hid) + [
				_mod(hid + ".drift", _input("drift_active"), 0.0, 1.0, 1.0, 1.8, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER")]
			if intro:
				haze_mods += _grow_mods(hid)
			var haze := _sprite(hid, "fx.drift_master_tail_haze", haze_centre, [HAZE[0], HAZE[1]], [0.0, HEAD_TEXEL_Y], "ADDITIVE", 3, HAZE[2], haze_mods)
			_add_bend(haze, BEND_SOURCE_PX / HAZE[0])
			# neon tail (two strands)
			var tid := "%s.tail_%s" % [phase, s]
			var tail_mods := _corner_mods(tid) + [
				_mod(tid + ".drift_a", _input("drift_active"), 0.0, 1.0, 1.0, 1.5, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"),
				_mod(tid + ".drift_l", _input("drift_active"), 0.0, 1.0, 1.0, 1.35, "MULTIPLY", "TRANSFORM_SCALE_Y"),
				_mod(tid + ".drift_w", _input("drift_active"), 0.0, 1.0, 1.0, 1.2, "MULTIPLY", "TRANSFORM_SCALE_X")]
			if intro:
				tail_mods += _grow_mods(tid)
			var tail := _sprite(tid, "fx.drift_master_neon_tail", tail_centre, [TAIL[0], TAIL[1]], [0.0, HEAD_TEXEL_Y], "ADDITIVE", 4, TAIL[2], tail_mods)
			_add_bend(tail, BEND_SOURCE_PX / TAIL[0])
			var target: Array = start_layers if intro else loop_layers
			target.append(haze)
			target.append(tail)
		# LOOP: drift smoke, invisible until drift_active rises; pushed to the outside of the corner
		var mid := "loop.smoke_" + s
		loop_layers.append(_sprite(mid, "fx.drift_master_drift_smoke", smoke, [SMOKE_SCALE, SMOKE_SCALE], [0.0, 0.0], "ALPHA", 2, SMOKE_OPACITY, [
			_mod(mid + ".drift", _input("drift_active"), 0.0, 1.0, 0.0, 1.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"),
			_mod(mid + ".grow_x", _input("drift_active"), 0.0, 1.0, 0.8, 1.2, "MULTIPLY", "TRANSFORM_SCALE_X"),
			_mod(mid + ".grow_y", _input("drift_active"), 0.0, 1.0, 0.8, 1.2, "MULTIPLY", "TRANSFORM_SCALE_Y"),
			_mod(mid + ".outward", _input("turn_rate_normalized"), -0.2, 0.2, SMOKE_OUTWARD, -SMOKE_OUTWARD, "ADD", "TRANSFORM_OFFSET_X")]))
		# END: TEXTURED_SPRITE cannot ramp in END (effect-local time is unknown there), so fade particle copies.
		# PARTICLE size is half of the texture's longest displayed side; particles are not bent.
		end_layers.append(_particle("end.haze_" + s, "fx.drift_master_tail_haze", "ADDITIVE", haze_centre, 3, _fade(256.0 * HAZE[1], HAZE[2] * 0.9)))
		end_layers.append(_particle("end.tail_" + s, "fx.drift_master_neon_tail", "ADDITIVE", tail_centre, 4, _fade(256.0 * TAIL[1], TAIL[2] * 0.9)))
	var preset := {
		"schema_version": 1.0,
		"preset_id": "talent.drift_master",
		"display_name": "Drift Master",
		"category": "RACE_TALENT",
		"default_space_mode": "VEHICLE_LOCAL",
		"lifecycle": {"mode": "START_LOOP_END"},
		"runtime_inputs": ["turn_rate_normalized", "drift_active"],
		"runtime_modulation_sources": [{"id": "drift.intro", "type": "LINEAR_PHASE", "frequency_hz": 1.0 / START_SEC}],
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


# Harder corner (|turn| -> 0.2): tail up to x1.15 longer and x1.2 brighter. Two clamped half-ranges make |turn|.
func _corner_mods(id: String) -> Array:
	return [
		_mod(id + ".corner_l_r", _input("turn_rate_normalized"), 0.0, 0.2, 1.0, 1.15, "MULTIPLY", "TRANSFORM_SCALE_Y"),
		_mod(id + ".corner_l_l", _input("turn_rate_normalized"), -0.2, 0.0, 1.15, 1.0, "MULTIPLY", "TRANSFORM_SCALE_Y"),
		_mod(id + ".corner_a_r", _input("turn_rate_normalized"), 0.0, 0.2, 1.0, 1.2, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER"),
		_mod(id + ".corner_a_l", _input("turn_rate_normalized"), -0.2, 0.0, 1.2, 1.0, "MULTIPLY", "VISUAL_OPACITY_MULTIPLIER")]


# START: drawn out from the head in 0.35 s to x1.15 length, settling to x1.0 by the end of START.
func _grow_mods(id: String) -> Array:
	var drawn := 0.35 / START_SEC
	return [
		_mod(id + ".grow", _src("drift.intro"), 0.0, drawn, 0.02, 1.15, "MULTIPLY", "TRANSFORM_SCALE_Y"),
		_mod(id + ".settle", _src("drift.intro"), drawn, 1.0, 1.0, 1.0 / 1.15, "MULTIPLY", "TRANSFORM_SCALE_Y")]


# Tail follows the corner just driven: right turn (+) moves the tail end to +x (inside), like the road trace.
func _add_bend(layer: Dictionary, bend_texels: float) -> void:
	layer["visual_bend"] = {"axis": "LOCAL_Y_POSITIVE", "curve": "QUADRATIC", "start_ratio": 0.1, "span_source_px": TAIL_SPAN}
	layer["modulations"].append(_mod(layer["id"] + ".bend", _input("turn_rate_normalized"), -0.2, 0.2, -bend_texels, bend_texels, "ADD", "VISUAL_BEND_OFFSET_X"))
	layer["modulation_clamps"] = [{"target": "VISUAL_BEND_OFFSET_X", "min_effective": -bend_texels, "max_effective": bend_texels}]


func _src(source_id: String) -> Dictionary:
	return {"type": "PRESET_SOURCE", "source_id": source_id}


func _input(input_name: String) -> Dictionary:
	return {"type": "RUNTIME_INPUT", "input": input_name}


func _sprite(id: String, tex: String, offset: Array, scale: Array, pivot: Array, blend: String, sort: int, opacity: float, mods: Array) -> Dictionary:
	return {"id": id, "type": "TEXTURED_SPRITE", "enabled": true, "importance": "CORE", "anchors": ["CENTER"],
		"blend_mode": blend, "render_plane": "UNDER_VEHICLE", "sort_order": sort, "modulations": mods,
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
		"size_start": size, "size_end": size, "alpha_start": alpha, "alpha_end": 0.0}


func _mod(id: String, source: Dictionary, in_min: float, in_max: float, out_min: float, out_max: float, op: String, target: String) -> Dictionary:
	return {"id": id, "operation": op, "target": target, "source": source,
		"mapping": {"type": "LINEAR_RANGE", "input_min": in_min, "input_max": in_max, "output_min": out_min, "output_max": out_max}}
