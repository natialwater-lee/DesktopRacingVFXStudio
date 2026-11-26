extends SceneTree
# Generator for the three Chain Bind presets. Run:
#   godot --headless --path <studio> --script res://tools/chain_bind_preset_generator.gd
# Output: presets/examples/talent.chain_bind{,_shackle,_break}.vfx.json
# Design: docs/superpowers/specs/2026-11-26-talent-chain-bind-design.md (1 screen px ~ 12.4 source px in game)
const OUT_DIR := "res://presets/examples/"
# Link: binder FRONT clamp ring -> target shackle eye (REAR_CENTER + TARGET_EYE).
const CLAMP_OFFSET := [0.0, 10.0]        # clamp sprite centre from FRONT (ring sits ~on FRONT, plate on the nose)
const CLAMP_SCALE := 0.6                 # 256 px art -> ring ~85 source px (~7 screen px)
const RING_OFFSET := [0.0, -5.0]         # chain start (ring centre) from FRONT
const SHACKLE_OFFSET := [0.0, -10.0]     # shackle sprite centre from REAR_CENTER
const SHACKLE_SCALE := 0.64              # 440 px band -> ~280 source px, wraps the rear corners
const TARGET_EYE := [0.0, 40.0]          # shackle eye from REAR_CENTER = link end
const CHAIN_WIDTH := 150.0               # strip width; the chain fills 62 % -> ~7.5 screen px (190 read too thick in race, 11-26). TILE = 2 links per 2 x width
const GLOW_WIDTH := 330.0               # scaled with the chain (420 at 190)
const SLACK_SAG := 55.0                  # ~4.4 screen px of drag sag when the chain is slack
const START_SEC := 0.9
const REVEAL_SEC := 0.12
const AMBER := [1.0, 0.72, 0.38, 1.0]    # spark tint (fx.furious_overtake_spark is reused)
# link_distance_ratio = distance / D: slack <= 0.7, taut = 1.0 (speed matched), strain up to 1.5 (corner/slip stretch)
const RATIO_SLACK := 0.7
const RATIO_STRAIN := 1.5


func _init() -> void:
	_write("talent.chain_bind", _binder())
	_write("talent.chain_bind_shackle", _shackle())
	_write("talent.chain_bind_break", _break())
	quit(0)


func _binder() -> Dictionary:
	var start := []
	var loop := []
	var end := []
	# No drop-shadow strip: removed for load (2026-11-26, 지훈: first planned cut; 8 pairs = 8 fewer strips per phase).
	# --- START: chain whipped out (reveal), red hot, then cools toward the slack look while sag drops in.
	var intro := "chain_bind.intro"
	start.append(_link("start.chain_glow", "fx.chain_bind_heat_glow", "STRETCH", "UNDER_VEHICLE", "ADDITIVE", 1, GLOW_WIDTH, 0.9,
		{"reveal_seconds": REVEAL_SEC}, _intro_sag("start.chain_glow") + [_mod("start.chain_glow.cool", intro, 0.35, 1.0, 1.0, 0.45, "VISUAL_OPACITY_MULTIPLIER")]))
	start.append(_link("start.chain_links", "fx.chain_bind_chain_links", "TILE", "OVER_VEHICLE", "ALPHA", 2, CHAIN_WIDTH, 1.0,
		{"reveal_seconds": REVEAL_SEC}, _intro_sag("start.chain_links")))
	start.append(_link("start.chain_heat", "fx.chain_bind_chain_links_heat", "TILE", "OVER_VEHICLE", "ADDITIVE", 3, CHAIN_WIDTH, 1.0,
		{"reveal_seconds": REVEAL_SEC}, _intro_sag("start.chain_heat") + [_mod("start.chain_heat.cool", intro, 0.35, 1.0, 1.0, 0.3, "VISUAL_OPACITY_MULTIPLIER")]))
	for part in [["clamp", "fx.chain_bind_clamp", "ALPHA", 4], ["clamp_heat", "fx.chain_bind_clamp_heat", "ADDITIVE", 5]]:
		var id := "start.%s" % part[0]
		start.append(_sprite(id, part[1], "FRONT", CLAMP_OFFSET, CLAMP_SCALE, part[2], part[3], 1.0, [
			_mod(id + ".flash_x", intro, 0.0, 0.33, 1.6, 1.0, "TRANSFORM_SCALE_X"),
			_mod(id + ".flash_y", intro, 0.0, 0.33, 1.6, 1.0, "TRANSFORM_SCALE_Y")]))
	# --- LOOP: everything reacts to the real distance; lock pulse = "clank" when speed matching starts.
	loop.append(_link("loop.chain_glow", "fx.chain_bind_heat_glow", "STRETCH", "UNDER_VEHICLE", "ADDITIVE", 1, GLOW_WIDTH, 0.85, {},
		[_sag_by_ratio("loop.chain_glow")] + _heat_mods("loop.chain_glow", 0.45, 1.35, 1.5, true)))
	loop.append(_link("loop.chain_links", "fx.chain_bind_chain_links", "TILE", "OVER_VEHICLE", "ALPHA", 2, CHAIN_WIDTH, 1.0, {},
		[_sag_by_ratio("loop.chain_links")] + _width_mods("loop.chain_links")))
	loop.append(_link("loop.chain_heat", "fx.chain_bind_chain_links_heat", "TILE", "OVER_VEHICLE", "ADDITIVE", 3, CHAIN_WIDTH, 0.85, {},
		[_sag_by_ratio("loop.chain_heat")] + _width_mods("loop.chain_heat") + _heat_mods("loop.chain_heat", 0.3, 1.3, 1.35, false)))
	loop.append(_sprite("loop.clamp", "fx.chain_bind_clamp", "FRONT", CLAMP_OFFSET, CLAMP_SCALE, "ALPHA", 4, 1.0, []))
	loop.append(_sprite("loop.clamp_heat", "fx.chain_bind_clamp_heat", "FRONT", CLAMP_OFFSET, CLAMP_SCALE, "ADDITIVE", 5, 0.9,
		_heat_mods("loop.clamp_heat", 0.3, 1.3, 1.35, false)))
	loop.append(_lock_flash("loop.lock_flash", "FRONT", RING_OFFSET, 0.6))
	# --- END: the chain reels back into the clamp (retract), clamp fades via particle copies.
	end.append(_link("end.chain_glow", "fx.chain_bind_heat_glow", "STRETCH", "UNDER_VEHICLE", "ADDITIVE", 1, GLOW_WIDTH, 0.5,
		{"retract_seconds": 0.35}, [_sag_by_ratio("end.chain_glow")]))
	end.append(_link("end.chain_links", "fx.chain_bind_chain_links", "TILE", "OVER_VEHICLE", "ALPHA", 2, CHAIN_WIDTH, 1.0,
		{"retract_seconds": 0.35}, [_sag_by_ratio("end.chain_links")]))
	end.append(_link("end.chain_heat", "fx.chain_bind_chain_links_heat", "TILE", "OVER_VEHICLE", "ADDITIVE", 3, CHAIN_WIDTH, 0.4,
		{"retract_seconds": 0.35}, [_sag_by_ratio("end.chain_heat")]))
	end.append(_fade_copy("end.clamp", "fx.chain_bind_clamp", "FRONT", CLAMP_OFFSET, 128.0 * CLAMP_SCALE, "ALPHA", 4, 0.4))
	return _preset("talent.chain_bind", "Chain Bind", "START_LOOP_END", ["link_distance_ratio", "link_lock_pulse"],
		[{"id": intro, "type": "LINEAR_PHASE", "frequency_hz": 1.0 / START_SEC}],
		{"start": {"duration_seconds": START_SEC, "layers": start}, "loop": {"layers": loop}, "end": {"duration_seconds": 0.4, "layers": end}}, true)


func _shackle() -> Dictionary:
	var intro := "chain_bind_shackle.intro"
	var eye := [TARGET_EYE[0], TARGET_EYE[1]]
	var start := [
		_sprite("start.band", "fx.chain_bind_shackle", "REAR_CENTER", SHACKLE_OFFSET, SHACKLE_SCALE, "ALPHA", 0, 1.0, [
			_mod("start.band.in", intro, 0.0, 0.15, 0.0, 1.0, "VISUAL_OPACITY_MULTIPLIER"),
			_mod("start.band.clamp_x", intro, 0.1, 0.5, 1.5, 1.0, "TRANSFORM_SCALE_X"),
			_mod("start.band.clamp_y", intro, 0.1, 0.5, 1.5, 1.0, "TRANSFORM_SCALE_Y")]),
		_sprite("start.band_heat", "fx.chain_bind_shackle_heat", "REAR_CENTER", SHACKLE_OFFSET, SHACKLE_SCALE, "ADDITIVE", 1, 1.0, [
			_mod("start.band_heat.in", intro, 0.0, 0.15, 0.0, 1.0, "VISUAL_OPACITY_MULTIPLIER"),
			_mod("start.band_heat.cool", intro, 0.5, 1.0, 1.0, 0.45, "VISUAL_OPACITY_MULTIPLIER"),
			_mod("start.band_heat.clamp_x", intro, 0.1, 0.5, 1.5, 1.0, "TRANSFORM_SCALE_X"),
			_mod("start.band_heat.clamp_y", intro, 0.1, 0.5, 1.5, 1.0, "TRANSFORM_SCALE_Y")]),
		_sprite("start.hit_flash", "fx.chain_bind_snap_flash", "REAR_CENTER", eye, 0.75, "ADDITIVE", 2, 1.0, [
			_mod("start.hit_flash.in", intro, 0.1, 0.2, 0.0, 1.0, "VISUAL_OPACITY_MULTIPLIER"),
			_mod("start.hit_flash.out", intro, 0.3, 0.75, 1.0, 0.0, "VISUAL_OPACITY_MULTIPLIER")]),
		_particle("start.hit_sparks", "fx.furious_overtake_spark", "REAR_CENTER", eye, "OVER_VEHICLE", "ADDITIVE", 3, {
			"emission_mode": "BURST", "burst_count": 10.0, "lifetime_seconds": 0.5, "size_start": 70.0, "size_end": 20.0,
			"alpha_start": 1.0, "alpha_end": 0.0, "color_rgba": AMBER, "direction_degrees": 180.0, "spread_degrees": 300.0,
			"speed_min": 250.0, "speed_max": 520.0, "rotation_min_degrees": 0.0, "rotation_max_degrees": 360.0})]
	var loop := [
		_sprite("loop.band", "fx.chain_bind_shackle", "REAR_CENTER", SHACKLE_OFFSET, SHACKLE_SCALE, "ALPHA", 0, 1.0, []),
		_sprite("loop.band_heat", "fx.chain_bind_shackle_heat", "REAR_CENTER", SHACKLE_OFFSET, SHACKLE_SCALE, "ADDITIVE", 1, 0.9,
			_heat_mods("loop.band_heat", 0.3, 1.3, 1.35, false)),
		_lock_flash("loop.lock_flash", "REAR_CENTER", eye, 0.6)]
	var end := [
		_fade_copy("end.band", "fx.chain_bind_shackle", "REAR_CENTER", SHACKLE_OFFSET, 256.0 * SHACKLE_SCALE, "ALPHA", 0, 0.3),
		_fade_copy("end.band_heat", "fx.chain_bind_shackle_heat", "REAR_CENTER", SHACKLE_OFFSET, 256.0 * SHACKLE_SCALE, "ADDITIVE", 1, 0.3)]
	return _preset("talent.chain_bind_shackle", "Chain Bind Shackle", "START_LOOP_END", ["link_distance_ratio", "link_lock_pulse"],
		[{"id": intro, "type": "LINEAR_PHASE", "frequency_hz": 1.0 / 0.6}],
		{"start": {"duration_seconds": 0.6, "layers": start}, "loop": {"layers": loop}, "end": {"duration_seconds": 0.3, "layers": end}}, false)


func _break() -> Dictionary:
	var src := "chain_bind_break.time"
	var layers := [
		_link("one_shot.chain_glow", "fx.chain_bind_heat_glow", "STRETCH", "UNDER_VEHICLE", "ADDITIVE", 1, GLOW_WIDTH, 0.9,
			{"gap_seconds": 0.3, "gap_sag_source_px": 90.0}, [_mod("one_shot.chain_glow.out", src, 0.0, 0.6, 1.0, 0.0, "VISUAL_OPACITY_MULTIPLIER")]),
		_link("one_shot.chain_links", "fx.chain_bind_chain_links", "TILE", "OVER_VEHICLE", "ALPHA", 2, CHAIN_WIDTH, 1.0,
			{"gap_seconds": 0.3, "gap_sag_source_px": 90.0}, [_mod("one_shot.chain_links.out", src, 0.45, 1.0, 1.0, 0.0, "VISUAL_OPACITY_MULTIPLIER")]),
		_link("one_shot.chain_heat", "fx.chain_bind_chain_links_heat", "TILE", "OVER_VEHICLE", "ADDITIVE", 3, CHAIN_WIDTH, 1.0,
			{"gap_seconds": 0.3, "gap_sag_source_px": 90.0}, [_mod("one_shot.chain_heat.cool", src, 0.0, 0.6, 1.0, 0.0, "VISUAL_OPACITY_MULTIPLIER")]),
		_fade_copy("one_shot.clamp", "fx.chain_bind_clamp", "FRONT", CLAMP_OFFSET, 128.0 * CLAMP_SCALE, "ALPHA", 4, 0.6),
		_on_link(_particle("one_shot.snap_flash", "fx.chain_bind_snap_flash", "FRONT", RING_OFFSET, "OVER_VEHICLE", "ADDITIVE", 5, {
			"emission_mode": "BURST", "burst_count": 1.0, "lifetime_seconds": 0.35, "size_start": 110.0, "size_end": 170.0,
			"alpha_start": 1.0, "alpha_end": 0.0, "rotation_min_degrees": 0.0, "rotation_max_degrees": 360.0}), 0.5),
		_on_link(_particle("one_shot.snap_sparks", "fx.furious_overtake_spark", "FRONT", RING_OFFSET, "OVER_VEHICLE", "ADDITIVE", 6, {
			"emission_mode": "BURST", "burst_count": 16.0, "lifetime_seconds": 0.55, "size_start": 80.0, "size_end": 20.0,
			"alpha_start": 1.0, "alpha_end": 0.0, "color_rgba": AMBER, "direction_degrees": 0.0, "spread_degrees": 360.0,
			"speed_min": 300.0, "speed_max": 650.0, "rotation_min_degrees": 0.0, "rotation_max_degrees": 360.0}), 0.5),
		_on_link(_particle("one_shot.release_sparks", "fx.furious_overtake_spark", "FRONT", RING_OFFSET, "OVER_VEHICLE", "ADDITIVE", 6, {
			"emission_mode": "BURST", "burst_count": 6.0, "lifetime_seconds": 0.4, "size_start": 60.0, "size_end": 18.0,
			"alpha_start": 1.0, "alpha_end": 0.0, "color_rgba": AMBER, "direction_degrees": 180.0, "spread_degrees": 240.0,
			"speed_min": 200.0, "speed_max": 420.0, "rotation_min_degrees": 0.0, "rotation_max_degrees": 360.0}), 1.0)]
	# The Game runs START_LOOP_END only: START = the break, an empty LOOP and a short empty END. The Game stops it
	# after START (VfxService normal_stop_after_seconds), as for the Wheel to Wheel moment packages.
	return _preset("talent.chain_bind_break", "Chain Bind Break", "START_LOOP_END", [],
		[{"id": src, "type": "LINEAR_PHASE", "frequency_hz": 1.0 / 0.7}],
		{"start": {"duration_seconds": 0.7, "layers": layers}, "loop": {"layers": []}, "end": {"duration_seconds": 0.05, "layers": []}}, true)


# --- helpers

func _preset(id: String, name: String, mode: String, inputs: Array, sources: Array, phases: Dictionary, linked: bool) -> Dictionary:
	var preset := {"schema_version": 1, "preset_id": id, "display_name": name, "category": "RACE_TALENT",
		"default_space_mode": "VEHICLE_LOCAL", "lifecycle": {"mode": mode}, "runtime_inputs": inputs,
		"runtime_modulation_sources": sources, "phases": phases}
	if linked:
		preset["link_target"] = {"source_anchor": "FRONT", "target_anchor": "REAR_CENTER", "target_offset": TARGET_EYE}
	return preset


func _link(id: String, tex: String, mode: String, plane: String, blend: String, sort: int, width: float, opacity: float, extra: Dictionary, mods: Array) -> Dictionary:
	var params := {"texture_asset_ref": tex, "texture_mode": mode, "width_source_px": width, "opacity": opacity,
		"sag_source_px": SLACK_SAG, "segments": 10}
	params.merge(extra, true)
	return {"id": id, "type": "LINK_STRIP", "enabled": true, "importance": "CORE", "anchors": ["FRONT"],
		"blend_mode": blend, "render_plane": plane, "sort_order": sort, "modulations": mods, "parameters": params,
		"transform": {"offset": RING_OFFSET, "rotation_degrees": 0.0, "scale": [1.0, 1.0]}}


func _sprite(id: String, tex: String, anchor: String, offset: Array, scale: float, blend: String, sort: int, opacity: float, mods: Array) -> Dictionary:
	return {"id": id, "type": "TEXTURED_SPRITE", "enabled": true, "importance": "CORE", "anchors": [anchor],
		"blend_mode": blend, "render_plane": "OVER_VEHICLE", "sort_order": sort, "modulations": mods,
		"parameters": {"opacity": opacity, "texture_asset_ref": tex},
		"transform": {"offset": offset, "rotation_degrees": 0.0, "scale": [scale, scale], "modulation_pivot_local": [0.0, 0.0]}}


func _particle(id: String, tex: String, anchor: String, offset: Array, plane: String, blend: String, sort: int, p: Dictionary) -> Dictionary:
	var params := {"acceleration": [0.0, 0.0], "angular_velocity_min_degrees_per_second": 0.0, "angular_velocity_max_degrees_per_second": 0.0,
		"color_rgba": [1.0, 1.0, 1.0, 1.0], "direction_degrees": 0.0, "emitter": {"shape": "POINT"},
		"rotation_min_degrees": 0.0, "rotation_max_degrees": 0.0, "size_multiplier_min": 1.0, "size_multiplier_max": 1.0,
		"speed_min": 0.0, "speed_max": 0.0, "spread_degrees": 0.0, "sprite_asset_ref": tex}
	params.merge(p, true)
	return {"id": id, "type": "PARTICLE", "enabled": true, "importance": "CORE", "anchors": [anchor],
		"blend_mode": blend, "render_plane": plane, "sort_order": sort, "parameters": params,
		"transform": {"offset": offset, "rotation_degrees": 0.0, "scale": [1.0, 1.0]}}


func _on_link(layer: Dictionary, t: float) -> Dictionary:
	layer["link_point_t"] = t
	return layer


## END/one-shot fade: TEXTURED_SPRITE cannot ramp outside START, so fade a single particle copy (size = half long side).
func _fade_copy(id: String, tex: String, anchor: String, offset: Array, size: float, blend: String, sort: int, seconds: float) -> Dictionary:
	return _particle(id, tex, anchor, offset, "OVER_VEHICLE", blend, sort, {"emission_mode": "BURST", "burst_count": 1.0,
		"lifetime_seconds": seconds, "size_start": size, "size_end": size, "alpha_start": 1.0, "alpha_end": 0.0})


func _lock_flash(id: String, anchor: String, offset: Array, scale: float) -> Dictionary:
	return _sprite(id, "fx.chain_bind_snap_flash", anchor, offset, scale, "ADDITIVE", 6, 1.0, [
		_input_mod(id + ".pulse", "link_lock_pulse", 0.0, 1.0, 0.0, 1.0, "VISUAL_OPACITY_MULTIPLIER"),
		_input_mod(id + ".size", "link_lock_pulse", 0.0, 1.0, 0.7, 1.2, "TRANSFORM_SCALE_X"),
		_input_mod(id + ".size_y", "link_lock_pulse", 0.0, 1.0, 0.7, 1.2, "TRANSFORM_SCALE_Y")])


## Heat: slack -> taut brightens to the authored opacity, strain and the lock pulse push it further.
func _heat_mods(id: String, slack: float, strain: float, pulse: float, _glow: bool) -> Array:
	return [
		_input_mod(id + ".taut", "link_distance_ratio", RATIO_SLACK, 1.0, slack, 1.0, "VISUAL_OPACITY_MULTIPLIER"),
		_input_mod(id + ".strain", "link_distance_ratio", 1.0, RATIO_STRAIN, 1.0, strain, "VISUAL_OPACITY_MULTIPLIER"),
		_input_mod(id + ".lock", "link_lock_pulse", 0.0, 1.0, 1.0, pulse, "VISUAL_OPACITY_MULTIPLIER")]


func _width_mods(id: String) -> Array:
	return [
		_input_mod(id + ".strain_w", "link_distance_ratio", 1.0, RATIO_STRAIN, 1.0, 1.12, "TRANSFORM_SCALE_X"),
		_input_mod(id + ".lock_w", "link_lock_pulse", 0.0, 1.0, 1.0, 1.15, "TRANSFORM_SCALE_X")]


func _sag_by_ratio(id: String) -> Dictionary:
	return _input_mod(id + ".tension", "link_distance_ratio", RATIO_SLACK, 1.0, 0.0, -SLACK_SAG, "LINK_SAG_OFFSET")


## START: thrown straight (no sag), the slack sag drops in after the hit.
func _intro_sag(id: String) -> Array:
	return [_mod(id + ".sag", "chain_bind.intro", 0.3, 1.0, -SLACK_SAG, 0.0, "LINK_SAG_OFFSET")]


func _mod(id: String, source_id: String, in_min: float, in_max: float, out_min: float, out_max: float, target: String) -> Dictionary:
	var op := "ADD" if target in ["LINK_SAG_OFFSET", "TRANSFORM_OFFSET_X", "TRANSFORM_OFFSET_Y"] else "MULTIPLY"
	return {"id": id, "operation": op, "target": target,
		"source": {"type": "PRESET_SOURCE", "source_id": source_id},
		"mapping": {"type": "LINEAR_RANGE", "input_min": in_min, "input_max": in_max, "output_min": out_min, "output_max": out_max}}


func _input_mod(id: String, input: String, in_min: float, in_max: float, out_min: float, out_max: float, target: String) -> Dictionary:
	var op := "ADD" if target == "LINK_SAG_OFFSET" else "MULTIPLY"
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
