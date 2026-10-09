extends SceneTree
# Generates the Headlights v2 textures (assets/vfx/headlight_beam_core.png and headlight_beam_soft.png; the soft texture is the wide road-spill cone).
# Run: Godot --headless --script res://tools/headlight_texture_generator.gd
# Both textures: beam axis points up (-Y), root near the bottom centre, symmetrical about the vertical axis,
# straight RGBA with edge-colour RGB under zero alpha (no dark fringe under ADDITIVE blending).

const OUT_DIR := "res://assets/vfx/"

# Core beam: narrow, hard-cutoff low-beam cone with a hot spot just beyond the nose.
const CORE_W := 160
const CORE_H := 256
const CORE_ROOT_FROM_BOTTOM := 8.0
# Spill: wide, faint cone that lights the surrounding road.
const SPILL_W := 256
const SPILL_H := 240
const SPILL_ROOT_FROM_BOTTOM := 8.0

# The spill is blended with ALPHA, so its RGB is the brightest value the road can reach where many cars overlap.
const SPILL_CAP := 0.80
const WARM := Color(1.0, 0.955, 0.84)
const NEUTRAL := Color(0.97, 0.98, 1.0)
const COOL := Color(0.74, 0.87, 1.0)


func _initialize() -> void:
	var core := _render_core()
	core.save_png(ProjectSettings.globalize_path(OUT_DIR + "headlight_beam_core.png"))
	var spill := _render_spill()
	spill.save_png(ProjectSettings.globalize_path(OUT_DIR + "headlight_beam_soft.png"))
	print("textures written")
	quit()


func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0


func _vnoise(x: float, y: float) -> float:
	var xi := int(floor(x))
	var yi := int(floor(y))
	var fx := x - xi
	var fy := y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(_hash(xi, yi), _hash(xi + 1, yi), fx)
	var b := lerpf(_hash(xi, yi + 1), _hash(xi + 1, yi + 1), fx)
	return lerpf(a, b, fy)


func _store(img: Image, x: int, y: int, intensity: float, color: Color) -> void:
	var a := clampf(intensity, 0.0, 1.0)
	# +-0.5 level dither so shallow gradients do not band.
	var dither := (_hash(x * 7 + 3, y * 13 + 5) - 0.5) / 255.0
	a = clampf(a + dither * (1.0 if a > 0.003 else 0.0), 0.0, 1.0)
	img.set_pixel(x, y, Color(color.r, color.g, color.b, a))


func _render_core() -> Image:
	var img := Image.create(CORE_W, CORE_H, false, Image.FORMAT_RGBA8)
	var root_y := CORE_H - CORE_ROOT_FROM_BOTTOM
	var cx := (CORE_W - 1) * 0.5
	for py in CORE_H:
		for px in CORE_W:
			var d := root_y - float(py)       # distance along the axis from the root, texels
			var x := absf(float(px) - cx)
			if d < 0.0:
				_store(img, px, py, 0.0, NEUTRAL)
				continue
			var w := 17.0 + 0.19 * d          # ~11 degree half angle, wide soft shoulders
			var u := x / w
			# lateral: flat top with a soft cut-off edge, brighter rim at the cut-off line
			var lateral := exp(-pow(u, 2.5) * 1.15)
			var rim := 0.0
			var centre_streak := 0.16 * exp(-pow(u / 0.38, 2.0))
			# axial: ramps up past the nose (hot spot ~ d=58), then inverse-distance style decay
			var ramp := smoothstep(0.0, 52.0, d)
			var hot := exp(-pow((d - 70.0) / 44.0, 2.0)) * 0.20
			var decay := 0.50 * exp(-d / 110.0) + 0.32 * exp(-d / 250.0)
			# rounded tip: fade by an elliptical distance so the far end is a soft arc, not a straight cut across the beam
			var r_eff := sqrt(d * d + pow(x * 2.4, 2.0))
			var tail_fade := 1.0 - smoothstep(0.28 * float(CORE_H), 0.97 * float(CORE_H), r_eff)
			tail_fade *= tail_fade
			var spread := pow(17.0 / w * 1.5, 0.5)
			var grain := 0.94 + 0.12 * _vnoise(float(px) * 0.55, float(py) * 0.07)
			var i := (decay + hot) * ramp * (lateral + rim + centre_streak * lateral) * spread * tail_fade * grain
			var edge := smoothstep(0.55, 1.25, u) + 0.35 * clampf(d / float(CORE_H), 0.0, 1.0)
			var col := WARM.lerp(NEUTRAL, clampf(d / 120.0, 0.0, 1.0) * 0.6).lerp(COOL, clampf(edge, 0.0, 1.0) * 0.55)
			_store(img, px, py, i * 0.98, col)
	return img


func _render_spill() -> Image:
	var img := Image.create(SPILL_W, SPILL_H, false, Image.FORMAT_RGBA8)
	var root_y := SPILL_H - SPILL_ROOT_FROM_BOTTOM
	var cx := (SPILL_W - 1) * 0.5
	for py in SPILL_H:
		for px in SPILL_W:
			var d := root_y - float(py)
			var x := absf(float(px) - cx)
			if d < 0.0:
				_store(img, px, py, 0.0, NEUTRAL)
				continue
			var w := 14.0 + 0.62 * d          # ~32 degree half angle
			var u := x / w
			var lateral := exp(-pow(u, 2.3) * 1.9)
			var ramp := smoothstep(0.0, 42.0, d)
			var pool := exp(-pow((d - 82.0) / 96.0, 2.0))
			var far := pow(clampf(1.0 - d / (float(SPILL_H) - 6.0), 0.0, 1.0), 1.5)
			var grain := 0.95 + 0.10 * _vnoise(float(px) * 0.09, float(py) * 0.09)
			var i := (0.62 * pool + 0.18) * far * ramp * lateral * grain
			var edge := smoothstep(0.35, 1.3, u)
			var col := NEUTRAL.lerp(COOL, clampf(0.25 + edge * 0.6, 0.0, 1.0))
			_store(img, px, py, i * 0.60, col * SPILL_CAP)
	return img
