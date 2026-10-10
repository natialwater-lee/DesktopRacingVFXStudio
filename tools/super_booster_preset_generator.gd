extends SceneTree
# Generator for the Super Booster v2 presets (single / dual / mk4). The presets are authored here; run:
#   godot --headless --path <studio> --script <this file>
# Output: presets/examples/equipment.super_booster{,.dual,.mk4}.vfx.json

const OUT_DIR := "res://presets/examples/"
# Nozzle root relative to REAR_CENTER (source-local y 220). Set per kind in _build from the Game flame
# sockets: y = 138.24 (equipment anchor) + (socket_y - 0.5) * 256 * 1.736 (0.868 scale x 512/256).
var _root_y := 59.0
var _lx := -60.0
var _rx := 60.0
const CLOCK_HZ := 0.05

var _sources: Array = []


func ph(t: float) -> float:
	return t * CLOCK_HZ


func _initialize() -> void:
	_write("equipment.super_booster", _build("single"))
	_write("equipment.super_booster.dual", _build("dual"))
	_write("equipment.super_booster.mk4", _build("mk4"))
	quit()


func _write(preset_id: String, data: Dictionary) -> void:
	var path := OUT_DIR + preset_id + ".vfx.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ", true) + "\n")
	file.close()
	print("wrote ", path)


# ---------- helpers ----------

func _src_lp(id: String, hz: float) -> void:
	_sources.append({"id": id, "type": "LINEAR_PHASE", "frequency_hz": hz})


func _src_osc(id: String, hz: float, phase_deg: float = 0.0) -> void:
	_sources.append({"id": id, "type": "OSCILLATOR", "wave": "SINE", "frequency_hz": hz, "phase_degrees": phase_deg})


func _m(id: String, source_id: String, target: String, in_min: float, in_max: float, out_min: float, out_max: float) -> Dictionary:
	var op := "ADD" if target.begins_with("TRANSFORM_OFFSET") or target == "TRANSFORM_ROTATION_DEGREES" else "MULTIPLY"
	return {
		"id": id,
		"mapping": {"input_min": in_min, "input_max": in_max, "output_min": out_min, "output_max": out_max, "type": "LINEAR_RANGE"},
		"operation": op,
		"source": {"source_id": source_id, "type": "PRESET_SOURCE"},
		"target": target
	}


# time-window ramp on the one-shot clock source; t values are effect seconds
func _mt(id: String, target: String, t0: float, t1: float, out0: float, out1: float) -> Dictionary:
	return _m(id, "time.clock", target, ph(t0), ph(t1), out0, out1)


func _turn(id: String, bend: float) -> Dictionary:
	return {
		"id": id,
		"mapping": {"input_min": -0.20, "input_max": 0.20, "output_min": -bend, "output_max": bend, "type": "LINEAR_RANGE"},
		"operation": "ADD",
		"source": {"input": "turn_rate_normalized", "type": "RUNTIME_INPUT"},
		"target": "VISUAL_BEND_OFFSET_X"
	}


func _bend_meta(span: float) -> Dictionary:
	return {"axis": "LOCAL_Y_POSITIVE", "start_ratio": 0.333333333, "curve": "QUADRATIC", "span_source_px": span}


func _sprite(id: String, tex: String, blend: String, imp: String, opacity: float, offset: Vector2, scl: Vector2, mods: Array, sort: float, opts: Dictionary = {}) -> Dictionary:
	var transform := {
		"offset": [offset.x, offset.y],
		"rotation_degrees": float(opts.get("rot", 0.0)),
		"scale": [scl.x, scl.y]
	}
	if opts.has("pivot"):
		transform["modulation_pivot_local"] = [opts["pivot"].x, opts["pivot"].y]
	var layer := {
		"anchors": ["REAR_CENTER"],
		"blend_mode": blend,
		"enabled": true,
		"id": id,
		"importance": imp,
		"parameters": {"opacity": opacity, "texture_asset_ref": tex},
		"render_plane": "UNDER_VEHICLE",
		"sort_order": int(sort),
		"transform": transform,
		"type": "TEXTURED_SPRITE"
	}
	var all_mods: Array = mods.duplicate()
	if opts.has("bend"):
		var bend: float = opts["bend"]
		all_mods.append(_turn(id + ".turn", bend))
		layer["visual_bend"] = _bend_meta(float(opts["span"]))
		layer["modulation_clamps"] = [{"target": "VISUAL_BEND_OFFSET_X", "min_effective": -bend, "max_effective": bend}]
	if not all_mods.is_empty():
		layer["modulations"] = all_mods
	return layer


func _particle(id: String, tex: String, blend: String, imp: String, offset: Vector2, p: Dictionary, sort: float, opts: Dictionary = {}) -> Dictionary:
	var burst: bool = p.get("mode", "BURST") == "BURST"
	var parameters := {
		"acceleration": [0.0, 0.0],
		"alpha_end": float(p.get("alpha_end", 0.0)),
		"alpha_start": float(p.get("alpha_start", 1.0)),
		"angular_velocity_max_degrees_per_second": 0.0,
		"angular_velocity_min_degrees_per_second": 0.0,
		"color_rgba": [1.0, 1.0, 1.0, 1.0],
		"direction_degrees": float(p.get("dir", 180.0)),
		"emission_mode": "BURST" if burst else "CONTINUOUS",
		"emitter": p.get("emitter", {"shape": "POINT"}),
		"lifetime_seconds": float(p.get("life", 0.3)),
		"rotation_max_degrees": float(p.get("rot_max", 360.0)),
		"rotation_min_degrees": float(p.get("rot_min", 0.0)),
		"size_end": float(p.get("size_end", 20.0)),
		"size_multiplier_max": float(p.get("mult_max", 1.0)),
		"size_multiplier_min": float(p.get("mult_min", 1.0)),
		"size_start": float(p.get("size_start", 30.0)),
		"speed_max": float(p.get("speed_max", 400.0)),
		"speed_min": float(p.get("speed_min", 400.0)),
		"spread_degrees": float(p.get("spread", 0.0)),
		"sprite_asset_ref": tex
	}
	if burst:
		parameters["burst_count"] = float(p.get("count", 1.0))
	else:
		parameters["emission_rate_per_second"] = float(p.get("rate", 10.0))
		parameters["max_particles"] = float(p.get("max", 4.0))
	var transform := {
		"offset": [offset.x, offset.y],
		"rotation_degrees": 0.0,
		"scale": [float(opts.get("sx", 1.0)), float(opts.get("sy", 1.0))]
	}
	var layer := {
		"anchors": ["REAR_CENTER"],
		"blend_mode": blend,
		"enabled": true,
		"id": id,
		"importance": imp,
		"parameters": parameters,
		"render_plane": "UNDER_VEHICLE",
		"sort_order": int(sort),
		"transform": transform,
		"type": "PARTICLE"
	}
	if opts.has("bend"):
		var bend: float = opts["bend"]
		transform["modulation_pivot_local"] = [opts["pivot"].x, opts["pivot"].y]
		layer["visual_bend"] = _bend_meta(float(opts["span"]))
		layer["modulation_clamps"] = [{"target": "VISUAL_BEND_OFFSET_X", "min_effective": -bend, "max_effective": bend}]
		layer["modulations"] = [_turn(id + ".turn", bend)]
	return layer


# ---------- jet geometry ----------

class Jet:
	var tex := ""
	var tex_h := 640.0
	var root_texel := 14.0
	var span := 596.0
	var sx := 1.0
	var sy := 1.0
	var root_y := 59.0
	var bend := 75.0

	func pivot_y() -> float:
		return root_texel - tex_h * 0.5

	func offset_y() -> float:
		return root_y - pivot_y() * sy



func _jet(tex: String, h: float, root: float, span: float, sx: float, sy: float, bend: float) -> Jet:
	var j := Jet.new()
	j.tex = tex
	j.tex_h = h
	j.root_texel = root
	j.span = span
	j.sx = sx
	j.sy = sy
	j.bend = bend
	j.root_y = _root_y
	return j


# ---------- shared layer groups ----------

# charge flare (START) whose end values hand over to the LOOP nozzle glow
func _charge_flare(id: String, x: float, t_shift: float, base: float, peak: float, size_mult: float) -> Dictionary:
	var m: Array = []
	var t0 := t_shift
	m.append(_mt(id + ".sx1", "TRANSFORM_SCALE_X", t0, 0.35 + t_shift * 0.5, 0.15, 0.9))
	m.append(_mt(id + ".sy1", "TRANSFORM_SCALE_Y", t0, 0.35 + t_shift * 0.5, 0.15, 0.9))
	m.append(_mt(id + ".sx2", "TRANSFORM_SCALE_X", 0.35 + t_shift * 0.5, 0.45, 1.0, 0.55))
	m.append(_mt(id + ".sy2", "TRANSFORM_SCALE_Y", 0.35 + t_shift * 0.5, 0.45, 1.0, 0.55))
	m.append(_mt(id + ".sx3", "TRANSFORM_SCALE_X", 0.45, 0.5, 1.0, peak / 0.5))
	m.append(_mt(id + ".sy3", "TRANSFORM_SCALE_Y", 0.45, 0.5, 1.0, peak / 0.5))
	m.append(_mt(id + ".o1", "VISUAL_OPACITY_MULTIPLIER", t0, 0.35 + t_shift * 0.5, 0.15, 0.8))
	m.append(_mt(id + ".o2", "VISUAL_OPACITY_MULTIPLIER", 0.35 + t_shift * 0.5, 0.45, 1.0, 1.25))
	return _sprite(id, "fx.super_booster_flare", "ADDITIVE", "CORE", 1.0, Vector2(x, _root_y), Vector2(size_mult, size_mult), m, 3.0)


func _charge_ring(id: String, x: float, t0: float, t1: float, base: float, from_mult: float, to_mult: float, imp: String = "DETAIL") -> Dictionary:
	var m: Array = []
	m.append(_mt(id + ".sx", "TRANSFORM_SCALE_X", t0, t1, from_mult, to_mult))
	m.append(_mt(id + ".sy", "TRANSFORM_SCALE_Y", t0, t1, from_mult, to_mult))
	m.append(_mt(id + ".o_in", "VISUAL_OPACITY_MULTIPLIER", t0, t0 + 0.06, 0.0, 0.9))
	m.append(_mt(id + ".o_out", "VISUAL_OPACITY_MULTIPLIER", t1 - 0.06, t1, 1.0, 0.0))
	return _sprite(id, "fx.super_booster_charge_ring", "ADDITIVE", imp, 1.0, Vector2(x, _root_y), Vector2(base, base), m, 1.0)


# one-shot shock arc starting at LOOP begin (t=0.5)
func _shock_arc(id: String, x: float, delay: float, dur: float, base: Vector2, s0: float, s1: float, travel: float, peak_opacity: float) -> Dictionary:
	var t0 := 0.5 + delay
	var t1 := t0 + dur
	var m: Array = []
	m.append(_mt(id + ".sx", "TRANSFORM_SCALE_X", t0, t1, s0, s1))
	m.append(_mt(id + ".sy", "TRANSFORM_SCALE_Y", t0, t1, s0, s1))
	m.append(_mt(id + ".move", "TRANSFORM_OFFSET_Y", t0, t1, 0.0, travel))
	m.append(_mt(id + ".fade", "VISUAL_OPACITY_MULTIPLIER", t0, t1, 1.0, 0.0))
	return _sprite(id, "fx.super_booster_shock_arc", "ADDITIVE", "DETAIL", peak_opacity, Vector2(x, _root_y + 24.0), base, m, 4.0)


# repeating thrust pulse running down the near flame; hz via its own LINEAR_PHASE source
func _pulse(id: String, source_id: String, x: float, base: Vector2, travel: float, opacity: float, imp: String = "EXTRA") -> Dictionary:
	var m: Array = []
	m.append(_m(id + ".sx", source_id, "TRANSFORM_SCALE_X", 0.0, 1.0, 0.8, 1.5))
	m.append(_m(id + ".sy", source_id, "TRANSFORM_SCALE_Y", 0.0, 1.0, 0.8, 1.5))
	m.append(_m(id + ".move", source_id, "TRANSFORM_OFFSET_Y", 0.0, 1.0, 0.0, travel))
	m.append(_m(id + ".o_in", source_id, "VISUAL_OPACITY_MULTIPLIER", 0.0, 0.15, 0.0, 1.0))
	m.append(_m(id + ".o_out", source_id, "VISUAL_OPACITY_MULTIPLIER", 0.35, 1.0, 1.0, 0.0))
	return _sprite(id, "fx.super_booster_shock_arc", "ADDITIVE", imp, opacity, Vector2(x, _root_y + 30.0), base, m, 4.5)


func _loop_body(prefix: String, x: float, jet: Jet, env_sx: float, env_sy: float, env_bend: float, env_opacity: float, jet_opacity: float, over_len: float, over_w: float, osc_set: Array, env_span: float) -> Array:
	# returns [envelope, jet]
	var layers: Array = []
	var env_pivot := Vector2(0.0, 14.0 - 320.0)
	var env_off := _root_y - env_pivot.y * env_sy
	var em: Array = []
	em.append(_mt(prefix + "env.over_len", "TRANSFORM_SCALE_Y", 0.5, 0.9, over_len, 1.0))
	em.append(_mt(prefix + "env.over_w", "TRANSFORM_SCALE_X", 0.5, 0.8, over_w, 1.0))
	em.append(_mt(prefix + "env.grow_len", "TRANSFORM_SCALE_Y", 0.5, 0.56, 0.25, 1.0))
	em.append(_mt(prefix + "env.grow_w", "TRANSFORM_SCALE_X", 0.5, 0.56, 0.5, 1.0))
	em.append(_mt(prefix + "env.grow_o", "VISUAL_OPACITY_MULTIPLIER", 0.5, 0.56, 0.4, 1.0))
	em.append(_m(prefix + "env.alpha", osc_set[3], "VISUAL_OPACITY_MULTIPLIER", -1.0, 1.0, 0.92, 1.08))
	layers.append(_sprite(prefix + "loop.envelope", "fx.super_booster_envelope", "ADDITIVE", "DETAIL", env_opacity, Vector2(x, env_off), Vector2(env_sx, env_sy), em, 0.0, {"pivot": env_pivot, "bend": env_bend, "span": env_span}))
	var jm: Array = []
	jm.append(_mt(prefix + "jet.over_len", "TRANSFORM_SCALE_Y", 0.5, 0.9, over_len, 1.0))
	jm.append(_mt(prefix + "jet.over_w", "TRANSFORM_SCALE_X", 0.5, 0.8, over_w, 1.0))
	jm.append(_mt(prefix + "jet.grow_len", "TRANSFORM_SCALE_Y", 0.5, 0.56, 0.25, 1.0))
	jm.append(_mt(prefix + "jet.grow_w", "TRANSFORM_SCALE_X", 0.5, 0.56, 0.5, 1.0))
	jm.append(_mt(prefix + "jet.grow_o", "VISUAL_OPACITY_MULTIPLIER", 0.5, 0.56, 0.4, 1.0))
	jm.append(_m(prefix + "jet.len_a", osc_set[0], "TRANSFORM_SCALE_Y", -1.0, 1.0, 0.975, 1.025))
	jm.append(_m(prefix + "jet.len_b", osc_set[1], "TRANSFORM_SCALE_Y", -1.0, 1.0, 0.98, 1.02))
	jm.append(_m(prefix + "jet.w", osc_set[1], "TRANSFORM_SCALE_X", -1.0, 1.0, 0.97, 1.03))
	jm.append(_m(prefix + "jet.alpha", osc_set[2], "VISUAL_OPACITY_MULTIPLIER", -1.0, 1.0, 0.93, 1.07))
	layers.append(_sprite(prefix + "loop.jet", jet.tex, "ADDITIVE", "CORE", jet_opacity, Vector2(x, jet.offset_y()), Vector2(jet.sx, jet.sy), jm, 1.0, {"pivot": Vector2(0.0, jet.pivot_y()), "bend": jet.bend, "span": jet.span}))
	return layers


func _nozzle_glow(id: String, x: float, glow_scale: float, flash_scale: float, osc: String) -> Dictionary:
	var m: Array = []
	var mult := flash_scale / glow_scale
	m.append(_mt(id + ".flash_sx", "TRANSFORM_SCALE_X", 0.5, 0.75, mult, 1.0))
	m.append(_mt(id + ".flash_sy", "TRANSFORM_SCALE_Y", 0.5, 0.75, mult, 1.0))
	m.append(_mt(id + ".flash_o", "VISUAL_OPACITY_MULTIPLIER", 0.5, 0.75, 2.0, 1.0))
	m.append(_m(id + ".alpha", osc, "VISUAL_OPACITY_MULTIPLIER", -1.0, 1.0, 0.88, 1.12))
	return _sprite(id, "fx.super_booster_flare", "ADDITIVE", "DETAIL", 0.5, Vector2(x, _root_y + 6.0), Vector2(glow_scale, glow_scale), m, 3.0)


func _bolt_spray(id: String, x: float, count: float, spread: float, speed_min: float, speed_max: float, size: float) -> Dictionary:
	return _particle(id, "fx.super_booster_bolt", "ADDITIVE", "EXTRA", Vector2(x, _root_y + 10.0), {
		"mode": "BURST", "count": count, "dir": 180.0, "spread": spread, "speed_min": speed_min, "speed_max": speed_max,
		"life": 0.3, "size_start": size, "size_end": size * 0.6, "alpha_start": 1.0, "alpha_end": 0.0
	}, 5.0)


func _end_group(prefix: String, x: float, jet: Jet, env_sx: float, env_sy: float, env_bend: float, env_span: float, jet_opacity: float, env_opacity: float, glow_size: float, life: float) -> Array:
	var layers: Array = []
	var jh := jet.tex_h * jet.sy
	var jet_speed := 0.3 * jh / life
	var jet_cy := _root_y + jh * 0.5
	layers.append(_particle(prefix + "end.jet", jet.tex, "ADDITIVE", "CORE", Vector2(x, jet_cy), {
		"mode": "BURST", "count": 1.0, "dir": 0.0, "speed_min": jet_speed, "speed_max": jet_speed,
		"life": life, "size_start": jh * 0.5, "size_end": jh * 0.5 * 0.4, "alpha_start": jet_opacity, "alpha_end": 0.0,
		"rot_min": 0.0, "rot_max": 0.0
	}, 1.0, {"sx": jet.sx / jet.sy, "bend": jet.bend, "pivot": Vector2(0.0, jet.pivot_y()), "span": jet.span}))
	var eh := 640.0 * env_sy
	var env_speed := 0.3 * eh / life
	layers.append(_particle(prefix + "end.envelope", "fx.super_booster_envelope", "ADDITIVE", "DETAIL", Vector2(x, _root_y + eh * 0.5), {
		"mode": "BURST", "count": 1.0, "dir": 0.0, "speed_min": env_speed, "speed_max": env_speed,
		"life": life, "size_start": eh * 0.5, "size_end": eh * 0.5 * 0.4, "alpha_start": env_opacity, "alpha_end": 0.0,
		"rot_min": 0.0, "rot_max": 0.0
	}, 0.0, {"sx": env_sx / env_sy, "bend": env_bend, "pivot": Vector2(0.0, 14.0 - 320.0), "span": env_span}))
	layers.append(_particle(prefix + "end.flare", "fx.super_booster_flare", "ADDITIVE", "DETAIL", Vector2(x, _root_y + 6.0), {
		"mode": "BURST", "count": 1.0, "dir": 180.0, "speed_min": 0.0, "speed_max": 0.0,
		"life": life, "size_start": glow_size, "size_end": glow_size * 0.5, "alpha_start": 0.5, "alpha_end": 0.0,
		"rot_min": 0.0, "rot_max": 0.0
	}, 3.0))
	return layers


# ---------- builders ----------

func _build(kind: String) -> Dictionary:
	_sources = []
	_src_lp("time.clock", CLOCK_HZ)
	var dual := kind != "single"
	var mk4 := kind == "mk4"
	match kind:
		"single":
			_root_y = 83.1 # Mk.I (0.875) and Mk.II (0.867) share this preset: mean of 84.9 and 81.3
		"dual":
			_root_y = 74.67
			_lx = -74.66
			_rx = 72.88
		"mk4":
			_root_y = 86.67
			_lx = -72.0
			_rx = 70.22
	if not dual:
		return _build_single()
	return _build_dual(mk4)


func _build_single() -> Dictionary:
	_src_osc("osc.len_a", 13.1)
	_src_osc("osc.len_b", 8.3, 90.0)
	_src_osc("osc.alpha", 9.7)
	_src_osc("osc.env", 6.1)
	_src_osc("osc.glow", 15.3)
	_src_lp("pulse.a", 2.2)
	_src_lp("pulse.b", 1.7)
	var jet := _jet("fx.super_booster_jet_single", 640.0, 14.0, 596.0, 1.8, 1.2, 75.0)
	var start: Array = []
	start.append(_charge_flare("start.charge_flare", 0.0, 0.0, 0.5, 1.72, 1.0))
	start.append(_charge_ring("start.charge_ring_a", 0.0, 0.0, 0.30, 1.0, 1.3, 0.25))
	start.append(_charge_ring("start.charge_ring_b", 0.0, 0.15, 0.45, 1.0, 1.3, 0.25))
	start.append(_particle("start.inhale_bolts", "fx.super_booster_bolt", "ADDITIVE", "EXTRA", Vector2(0.0, _root_y + 140.0), {
		"mode": "CONTINUOUS", "rate": 40.0, "max": 10.0, "dir": 0.0, "spread": 12.0, "speed_min": 560.0, "speed_max": 700.0,
		"life": 0.2, "size_start": 28.0, "size_end": 16.0, "alpha_start": 0.9, "alpha_end": 0.3, "emitter": {"shape": "BOX", "size": [110.0, 40.0]}
	}, 5.0))
	var loop: Array = _loop_body("", 0.0, jet, 1.8, 1.2, 110.0, 0.85, 0.95, 1.7, 1.4, ["osc.len_a", "osc.len_b", "osc.alpha", "osc.env"], 600.0)
	loop.append(_nozzle_glow("loop.nozzle_glow", 0.0, 0.7, 1.7, "osc.glow"))
	loop.append(_shock_arc("burst.shock_arc_a", 0.0, 0.0, 0.35, Vector2(1.25, 1.25), 0.4, 2.6, 330.0, 1.0))
	loop.append(_shock_arc("burst.shock_arc_b", 0.0, 0.08, 0.35, Vector2(1.0, 1.0), 0.4, 2.2, 290.0, 0.8))
	loop.append(_bolt_spray("burst.bolt_spray", 0.0, 14.0, 70.0, 500.0, 950.0, 40.0))
	loop.append(_pulse("loop.pulse_a", "pulse.a", 0.0, Vector2(0.6, 0.6), 190.0, 0.6))
	loop.append(_pulse("loop.pulse_b", "pulse.b", 0.0, Vector2(0.52, 0.52), 180.0, 0.5))
	loop.append(_particle("loop.sparks", "fx.super_booster_bolt", "ADDITIVE", "EXTRA", Vector2(0.0, _root_y + 220.0), {
		"mode": "CONTINUOUS", "rate": 14.0, "max": 5.0, "dir": 180.0, "spread": 25.0, "speed_min": 350.0, "speed_max": 600.0,
		"life": 0.22, "size_start": 32.0, "size_end": 16.0, "alpha_start": 0.9, "alpha_end": 0.0, "emitter": {"shape": "BOX", "size": [90.0, 360.0]}
	}, 5.0))
	var life := 0.35
	var end: Array = _end_group("", 0.0, jet, 1.8, 1.2, 110.0, 600.0, 0.95, 0.85, 80.0, life)
	end.append(_bolt_spray_end("end.sparks", 0.0))
	end.append(_particle("end.arc", "fx.super_booster_shock_arc", "ADDITIVE", "EXTRA", Vector2(0.0, _root_y + 30.0), {
		"mode": "BURST", "count": 1.0, "dir": 180.0, "speed_min": 400.0, "speed_max": 400.0, "life": 0.3, "size_start": 64.0, "size_end": 96.0,
		"alpha_start": 0.5, "alpha_end": 0.0, "rot_min": 0.0, "rot_max": 0.0
	}, 4.0))
	return _preset("equipment.super_booster", "Super Booster", start, loop, end, 0.5, life)


func _bolt_spray_end(id: String, x: float) -> Dictionary:
	return _particle(id, "fx.super_booster_bolt", "ADDITIVE", "EXTRA", Vector2(x, _root_y + 10.0), {
		"mode": "BURST", "count": 6.0, "dir": 180.0, "spread": 60.0, "speed_min": 200.0, "speed_max": 450.0,
		"life": 0.3, "size_start": 26.0, "size_end": 14.0, "alpha_start": 0.9, "alpha_end": 0.0
	}, 5.0)


func _build_dual(mk4: bool) -> Dictionary:
	_src_osc("osc.len_a", 12.7)
	_src_osc("osc.len_b", 8.9, 90.0)
	_src_osc("osc.alpha", 10.3)
	_src_osc("osc.env", 6.1)
	_src_osc("osc.glow", 15.3)
	_src_osc("r.len_a", 12.7, 180.0)
	_src_osc("r.len_b", 8.9, 270.0)
	_src_osc("r.alpha", 10.3, 180.0)
	_src_osc("r.env", 6.1, 180.0)
	_src_osc("r.glow", 15.3, 180.0)
	_src_osc("bridge.flicker", 31.0)
	_src_lp("pulse.l", 2.3)
	_src_lp("pulse.r", 2.0)
	_src_lp("bridge.loop", 0.9)
	var k := 1.15 if mk4 else 1.0
	var jet := _jet("fx.super_booster_jet_twin", 576.0, 14.0, 530.0, 1.4 * k, 1.1 * k, 55.0)
	var env_sx := 1.45 * k
	var env_sy := 1.1 * k
	var lx := _lx
	var rx := _rx
	var start: Array = []
	start.append(_charge_flare("start.left_flare", lx, 0.0, 0.5, 1.57, 0.9))
	start.append(_charge_flare("start.right_flare", rx, 0.1, 0.5, 1.57, 0.9))
	start.append(_charge_ring("start.left_ring", lx, 0.0, 0.32, 0.8, 1.6, 0.2))
	start.append(_charge_ring("start.right_ring", rx, 0.1, 0.42, 0.8, 1.6, 0.2))
	if mk4:
		start.append(_charge_ring("start.center_ring", 0.0, 0.05, 0.40, 1.1, 1.8, 0.3))
	# lightning bridge between the two nozzles, flickering through the last 0.2 s of the charge
	for variant in [["start.bridge_a", -45.0], ["start.bridge_b", 135.0]]:
		var bm: Array = []
		bm.append(_mt(variant[0] + ".on", "VISUAL_OPACITY_MULTIPLIER", 0.3, 0.33, 0.0, 1.0))
		bm.append(_m(variant[0] + ".flicker", "bridge.flicker" if variant[0].ends_with("a") else "bridge.flicker", "VISUAL_OPACITY_MULTIPLIER", -1.0, 1.0, 0.25 if variant[0].ends_with("a") else 1.0, 1.0 if variant[0].ends_with("a") else 0.25))
		start.append(_sprite(variant[0], "fx.super_booster_bolt", "ADDITIVE", "EXTRA", 0.9, Vector2(0.0, _root_y + 8.0), Vector2(0.75, 0.75), bm, 5.0, {"rot": variant[1]}))
	start.append(_particle("start.inhale_bolts", "fx.super_booster_bolt", "ADDITIVE", "EXTRA", Vector2(0.0, _root_y + 130.0), {
		"mode": "CONTINUOUS", "rate": 44.0, "max": 11.0, "dir": 0.0, "spread": 14.0, "speed_min": 520.0, "speed_max": 680.0,
		"life": 0.2, "size_start": 26.0, "size_end": 14.0, "alpha_start": 0.9, "alpha_end": 0.3, "emitter": {"shape": "BOX", "size": [200.0, 40.0]}
	}, 5.0))
	var loop: Array = []
	var over_len := 1.6 if not mk4 else 1.65
	loop.append_array(_loop_body("l.", lx, jet, env_sx, env_sy, 90.0, 0.85, 0.95, over_len, 1.35, ["osc.len_a", "osc.len_b", "osc.alpha", "osc.env"], 530.0))
	loop.append_array(_loop_body("r.", rx, jet, env_sx, env_sy, 90.0, 0.85, 0.95, over_len, 1.35, ["r.len_a", "r.len_b", "r.alpha", "r.env"], 530.0))
	if mk4:
		var gold_jet := _jet("fx.super_booster_core_gold", 576.0, 14.0, 530.0, 1.4 * k, 1.1 * k, 45.0)
		for side in [["l.", lx, "osc.len_a", "osc.alpha"], ["r.", rx, "r.len_a", "r.alpha"]]:
			var gm: Array = []
			gm.append(_mt(side[0] + "gold.over_len", "TRANSFORM_SCALE_Y", 0.5, 0.9, over_len, 1.0))
			gm.append(_mt(side[0] + "gold.grow_len", "TRANSFORM_SCALE_Y", 0.5, 0.56, 0.25, 1.0))
			gm.append(_mt(side[0] + "gold.grow_o", "VISUAL_OPACITY_MULTIPLIER", 0.5, 0.56, 0.4, 1.0))
			gm.append(_m(side[0] + "gold.len", side[2], "TRANSFORM_SCALE_Y", -1.0, 1.0, 0.975, 1.025))
			gm.append(_m(side[0] + "gold.alpha", side[3], "VISUAL_OPACITY_MULTIPLIER", -1.0, 1.0, 0.9, 1.1))
			loop.append(_sprite(side[0] + "loop.gold_core", gold_jet.tex, "ADDITIVE", "CORE", 0.85, Vector2(side[1], gold_jet.offset_y()), Vector2(gold_jet.sx, gold_jet.sy), gm, 2.0, {"pivot": Vector2(0.0, gold_jet.pivot_y()), "bend": gold_jet.bend, "span": gold_jet.span}))
	loop.append(_nozzle_glow("l.loop.nozzle_glow", lx, 0.6, 1.4, "osc.glow"))
	loop.append(_nozzle_glow("r.loop.nozzle_glow", rx, 0.6, 1.4, "r.glow"))
	var arc_k := 1.3 if mk4 else 1.0
	loop.append(_shock_arc("burst.shock_arc_a", 0.0, 0.0, 0.4, Vector2(1.25, 1.25), 0.5 * arc_k, 3.0 * arc_k, 340.0, 1.0))
	loop.append(_shock_arc("burst.shock_arc_b", 0.0, 0.09, 0.4, Vector2(1.0, 1.0), 0.5 * arc_k, 2.5 * arc_k, 300.0, 0.8))
	loop.append(_bolt_spray("l.burst.bolt_spray", lx, 10.0, 80.0, 450.0, 900.0, 36.0))
	loop.append(_bolt_spray("r.burst.bolt_spray", rx, 10.0, 80.0, 450.0, 900.0, 36.0))
	loop.append(_pulse("l.loop.pulse", "pulse.l", lx, Vector2(0.5, 0.5), 180.0, 0.55))
	loop.append(_pulse("r.loop.pulse", "pulse.r", rx, Vector2(0.5, 0.5), 180.0, 0.55))
	# periodic lightning flash bridging the two flames (about once per second)
	var lm: Array = []
	lm.append(_m("loop.bridge.in", "bridge.loop", "VISUAL_OPACITY_MULTIPLIER", 0.0, 0.04, 0.0, 1.0))
	lm.append(_m("loop.bridge.out", "bridge.loop", "VISUAL_OPACITY_MULTIPLIER", 0.05, 0.12, 1.0, 0.0))
	loop.append(_sprite("loop.bridge", "fx.super_booster_bolt", "ADDITIVE", "EXTRA", 0.8, Vector2(0.0, _root_y + 110.0), Vector2(0.75, 0.75), lm, 5.0, {"rot": -45.0}))
	loop.append(_particle("loop.sparks", "fx.super_booster_bolt", "ADDITIVE", "EXTRA", Vector2(0.0, _root_y + 200.0), {
		"mode": "CONTINUOUS", "rate": 16.0, "max": 6.0, "dir": 180.0, "spread": 30.0, "speed_min": 350.0, "speed_max": 600.0,
		"life": 0.22, "size_start": 30.0, "size_end": 15.0, "alpha_start": 0.9, "alpha_end": 0.0, "emitter": {"shape": "BOX", "size": [200.0, 340.0]}
	}, 5.0))
	if mk4:
		_src_lp("pulse.big", 0.75)
		var bm2: Array = []
		bm2.append(_m("loop.big_pulse.sx", "pulse.big", "TRANSFORM_SCALE_X", 0.0, 1.0, 0.8, 1.9))
		bm2.append(_m("loop.big_pulse.sy", "pulse.big", "TRANSFORM_SCALE_Y", 0.0, 1.0, 0.8, 1.9))
		bm2.append(_m("loop.big_pulse.move", "pulse.big", "TRANSFORM_OFFSET_Y", 0.0, 1.0, 0.0, 190.0))
		bm2.append(_m("loop.big_pulse.in", "pulse.big", "VISUAL_OPACITY_MULTIPLIER", 0.0, 0.12, 0.0, 1.0))
		bm2.append(_m("loop.big_pulse.out", "pulse.big", "VISUAL_OPACITY_MULTIPLIER", 0.3, 1.0, 1.0, 0.0))
		loop.append(_sprite("loop.big_pulse", "fx.super_booster_shock_arc", "ADDITIVE", "DETAIL", 0.6, Vector2(0.0, _root_y + 30.0), Vector2(0.9, 0.9), bm2, 4.6))
	var life := 0.35
	var end: Array = []
	end.append_array(_end_group("l.", lx, jet, env_sx, env_sy, 90.0, 530.0, 0.95, 0.85, 66.0, life))
	end.append_array(_end_group("r.", rx, jet, env_sx, env_sy, 90.0, 530.0, 0.95, 0.85, 66.0, life))
	if mk4:
		var gold_jet2 := _jet("fx.super_booster_core_gold", 576.0, 14.0, 530.0, 1.4 * k, 1.1 * k, 45.0)
		var gh := gold_jet2.tex_h * gold_jet2.sy
		for gx in [["l.", lx], ["r.", rx]]:
			end.append(_particle(gx[0] + "end.gold_core", gold_jet2.tex, "ADDITIVE", "CORE", Vector2(gx[1], _root_y + gh * 0.5), {
				"mode": "BURST", "count": 1.0, "dir": 0.0, "speed_min": 0.3 * gh / life, "speed_max": 0.3 * gh / life,
				"life": life, "size_start": gh * 0.5, "size_end": gh * 0.5 * 0.4, "alpha_start": 0.85, "alpha_end": 0.0,
				"rot_min": 0.0, "rot_max": 0.0
			}, 2.0, {"sx": gold_jet2.sx / gold_jet2.sy, "bend": gold_jet2.bend, "pivot": Vector2(0.0, gold_jet2.pivot_y()), "span": gold_jet2.span}))
	end.append(_bolt_spray_end("end.sparks", 0.0))
	end.append(_particle("end.arc", "fx.super_booster_shock_arc", "ADDITIVE", "EXTRA", Vector2(0.0, _root_y + 30.0), {
		"mode": "BURST", "count": 1.0, "dir": 180.0, "speed_min": 400.0, "speed_max": 400.0, "life": 0.3, "size_start": 90.0, "size_end": 130.0,
		"alpha_start": 0.5, "alpha_end": 0.0, "rot_min": 0.0, "rot_max": 0.0
	}, 4.0))
	var preset_id := "equipment.super_booster.mk4" if mk4 else "equipment.super_booster.dual"
	return _preset(preset_id, "Super Booster Mk.IV" if mk4 else "Dual Super Booster", start, loop, end, 0.5, life)


func _preset(preset_id: String, display_name: String, start: Array, loop: Array, end: Array, start_dur: float, end_dur: float) -> Dictionary:
	return {
		"category": "SPECIAL_EQUIPMENT",
		"default_space_mode": "VEHICLE_LOCAL",
		"display_name": display_name,
		"lifecycle": {"mode": "START_LOOP_END"},
		"phases": {
			"start": {"duration_seconds": start_dur, "layers": start},
			"loop": {"layers": loop},
			"end": {"duration_seconds": end_dur, "layers": end}
		},
		"preset_id": preset_id,
		"runtime_inputs": ["turn_rate_normalized"],
		"runtime_modulation_sources": _sources,
		"schema_version": 1.0
	}
