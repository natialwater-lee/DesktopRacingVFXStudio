extends SceneTree
# Prepares the GPT Final Lap art for the Studio. Run:
#   godot --headless --path <studio> --script res://tools/final_lap_art_prep.gd -- <folder with the 6 GPT PNGs>
# Writes res://assets/vfx/talent_final_lap_*.png and prints checks.
# - Ribbon body + sheen (512x768) get SIDE_PAD transparent texels left and right (the Game bend shader moves UV
#   inside the sprite rectangle, so the ribbons need room to sway) and are split into left / right halves (352x768)
#   so each side can flare outward and flutter on its own beat.
# - The spill came with a hard alpha step where the "car area" was cleared (y 280, x 62..190). Its alpha is
#   box-blurred so the road glow has no straight edge.
# Design: docs/superpowers/specs/2026-11-26-talent-final-lap-design.md
const OUT := "res://assets/vfx/"
const SIDE_PAD := 96
const SPILL_BLUR := 7
const PLAIN := ["finish_line", "charge_ring", "charge_flash"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the folder that holds the GPT PNGs.")
		quit(1)
		return
	var src: String = args[0]
	for n in ["flag_body", "flag_sheen"]:
		var padded := _padded(_load(src, n))
		var half := padded.get_width() / 2
		_save(padded.get_region(Rect2i(0, 0, half, padded.get_height())), n + "_l")
		_save(padded.get_region(Rect2i(half, 0, half, padded.get_height())), n + "_r")
	_save(_piece(_load(src, "flag_body")), "flag_piece")
	_save(_blurred_alpha(_load(src, "flag_spill"), SPILL_BLUR), "flag_spill")
	for n in PLAIN:
		_save(_load(src, n), n)
	quit(0)


func _load(folder: String, n: String) -> Image:
	var image := Image.load_from_file(folder.path_join("talent_final_lap_%s.png" % n))
	image.convert(Image.FORMAT_RGBA8)
	print("%s %dx%d alpha max %.3f, used %s" % [n, image.get_width(), image.get_height(), _alpha_max(image), str(image.get_used_rect())])
	return image


func _padded(image: Image) -> Image:
	var out := Image.create(image.get_width() + SIDE_PAD * 2, image.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color(1, 1, 1, 0))
	out.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(SIDE_PAD, 0))
	return out


## A torn-off checker scrap for the tail particles: a 2x2-square patch of the real ribbon cloth (left ribbon,
## mid length, unpadded art x 67..138, y 420..484) with a soft round alpha edge, centred on a 96x96 canvas.
func _piece(body: Image) -> Image:
	var patch := body.get_region(Rect2i(68, 420, 68, 64))
	var out := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	out.fill(Color(1, 1, 1, 0))
	out.blit_rect(patch, Rect2i(Vector2i.ZERO, patch.get_size()), Vector2i(14, 16))
	for y in 96:
		for x in 96:
			var d := Vector2((x - 48.0) / 34.0, (y - 48.0) / 32.0).length()
			var c := out.get_pixel(x, y)
			c.a *= 1.0 - smoothstep(0.7, 1.0, d)
			out.set_pixel(x, y, c)
	return out


## Two-pass box blur of alpha only (RGB kept), repeated twice ~ gaussian.
func _blurred_alpha(image: Image, radius: int) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	var a := PackedFloat32Array()
	a.resize(w * h)
	for y in h:
		for x in w:
			a[y * w + x] = image.get_pixel(x, y).a
	for _pass in 2:
		a = _box(a, w, h, radius, true)
		a = _box(a, w, h, radius, false)
	var out := image.duplicate() as Image
	var worst := 0.0
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			c.a = a[y * w + x]
			out.set_pixel(x, y, c)
			if y > 0:
				worst = maxf(worst, absf(a[y * w + x] - a[(y - 1) * w + x]))
	print("  spill blurred, largest row-to-row alpha step %.3f" % worst)
	return out


func _box(src: PackedFloat32Array, w: int, h: int, r: int, horizontal: bool) -> PackedFloat32Array:
	var dst := PackedFloat32Array()
	dst.resize(w * h)
	for y in h:
		for x in w:
			var s := 0.0
			var n := 0
			for k in range(-r, r + 1):
				var xx := x + k if horizontal else x
				var yy := y if horizontal else y + k
				if xx < 0 or yy < 0 or xx >= w or yy >= h:
					n += 1
					continue
				s += src[yy * w + xx]
				n += 1
			dst[y * w + x] = s / float(n)
	return dst


func _save(image: Image, n: String) -> void:
	var path := OUT + "talent_final_lap_%s.png" % n
	image.save_png(ProjectSettings.globalize_path(path))
	print("  -> %s %dx%d" % [path, image.get_width(), image.get_height()])


func _alpha_max(image: Image) -> float:
	var m := 0.0
	for y in image.get_height():
		for x in image.get_width():
			m = maxf(m, image.get_pixel(x, y).a)
	return m
