extends SceneTree
# Prepares the GPT Chain Bind art for the Studio. Run:
#   godot --headless --path <studio> --script res://tools/chain_bind_art_prep.gd -- <folder with the 5 GPT PNGs>
# Writes res://assets/vfx/talent_chain_bind_*.png and prints checks.
# - LINK_STRIP textures run along +X (Line2D maps U along the line): chain links and heat glow are rotated 90 deg.
# - Chain, shackle and clamp are split from the SAME pixels into a cold steel base (ALPHA) and a heat-only
#   emission (ADDITIVE), so the "heating" overlay always lines up with the metal.
# Design: docs/superpowers/specs/2026-11-26-talent-chain-bind-design.md
const OUT := "res://assets/vfx/"
const STEEL_TINT := Color(0.92, 0.95, 1.05)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the folder that holds the GPT PNGs.")
		quit(1)
		return
	var src: String = args[0]
	var links := _load(src, "talent_chain_bind_chain_links.png")
	print("chain seam max diff (row 0 vs last row): %.3f" % _seam_diff(links))
	_split(_rotated(links), "talent_chain_bind_chain_links")
	_split(_load(src, "talent_chain_bind_shackle.png"), "talent_chain_bind_shackle")
	_split(_load(src, "talent_chain_bind_clamp.png"), "talent_chain_bind_clamp")
	_save(_rotated(_load(src, "talent_chain_bind_heat_glow.png")), "talent_chain_bind_heat_glow")
	_save(_load(src, "talent_chain_bind_snap_flash.png"), "talent_chain_bind_snap_flash")
	quit(0)


func _load(folder: String, file_name: String) -> Image:
	var image := Image.load_from_file(folder.path_join(file_name))
	image.convert(Image.FORMAT_RGBA8)
	print("%s %dx%d alpha max %.3f, bbox %s" % [file_name, image.get_width(), image.get_height(), _alpha_max(image), str(image.get_used_rect())])
	return image


func _rotated(image: Image) -> Image:
	var out := image.duplicate() as Image
	out.rotate_90(CLOCKWISE)
	return out


## Heat 0..1: warm-hued (red well above blue) or very bright warm pixels.
static func heat_of(c: Color) -> float:
	var warm := clampf((c.r - c.b - 0.12) / 0.35, 0.0, 1.0)
	var bright := clampf((c.get_luminance() - 0.72) / 0.2, 0.0, 1.0) if c.r >= c.b else 0.0
	return maxf(warm, bright)


func _split(image: Image, base_name: String) -> void:
	var cold := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	var heat := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	var hot_pixels := 0
	var solid_pixels := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			var h := heat_of(c)
			if c.a > 0.5:
				solid_pixels += 1
				if h > 0.5:
					hot_pixels += 1
			# Cold steel: hot pixels become grey steel of similar shading.
			var grey := 0.16 + c.get_luminance() * 0.42
			var steel := Color(grey * STEEL_TINT.r, grey * STEEL_TINT.g, grey * STEEL_TINT.b, c.a)
			cold.set_pixel(x, y, Color(c.r, c.g, c.b, c.a).lerp(steel, h) if h > 0.0 else c)
			# Heat: warm colour only; RGB kept bright where alpha is 0 so filtering does not darken edges.
			heat.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * h) if h > 0.0 else Color(1.0, 0.55, 0.15, 0.0))
	print("%s hot area %.0f%% of metal" % [base_name, 100.0 * hot_pixels / maxf(solid_pixels, 1.0)])
	_save(cold, base_name)
	_save(heat, base_name + "_heat")


func _save(image: Image, base_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT + base_name + ".png")
	image.save_png(path)
	print("wrote %s %dx%d" % [base_name, image.get_width(), image.get_height()])


func _alpha_max(image: Image) -> float:
	var m := 0.0
	for y in image.get_height():
		for x in image.get_width():
			m = maxf(m, image.get_pixel(x, y).a)
	return m


func _seam_diff(image: Image) -> float:
	var worst := 0.0
	var last := image.get_height() - 1
	for x in image.get_width():
		var a := image.get_pixel(x, 0)
		var b := image.get_pixel(x, last)
		worst = maxf(worst, absf(a.a - b.a))
	return worst
