extends SceneTree
# Prepares the GPT Wheel to Wheel art for the Studio. Run:
#   godot --headless --path <studio> --script res://tools/wheel_to_wheel_art_prep.gd -- <folder with the 5 GPT PNGs>
# Writes res://assets/vfx/talent_wheel_to_wheel_*.png and prints checks.
# - flank_edge is pushed toward lemon yellow (TEXTURED_SPRITE has no colour tint); flank_spill = that edge blurred wide
#   (the yellow road reflection under the arcs).
# - pressure_wave is split from the SAME pixels into an air body (ALPHA, yellow rim turned to white air) and a rim-only
#   emission (ADDITIVE), so the rim always lines up with the air.
# - spark_fan comes for the right front corner (origin texel (48, 48)); the left copy is mirrored.
# Design: docs/superpowers/specs/2026-11-26-talent-wheel-to-wheel-design.md
const OUT := "res://assets/vfx/"
const LEMON := Color(1.0, 0.82, 0.2)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the folder that holds the GPT PNGs.")
		quit(1)
		return
	var src: String = args[0]
	_save(_cleared(_load(src, "talent_wheel_to_wheel_flank_body.png")), "talent_wheel_to_wheel_flank_body")
	var edge := _lemon(_cleared(_load(src, "talent_wheel_to_wheel_flank_edge.png")))
	_save(edge, "talent_wheel_to_wheel_flank_edge")
	_save(_spill(edge), "talent_wheel_to_wheel_flank_spill")
	_split_wave(_cleared(_load(src, "talent_wheel_to_wheel_pressure_wave.png")))
	var fan := _cleared(_load(src, "talent_wheel_to_wheel_spark_fan.png"))
	_save(fan, "talent_wheel_to_wheel_spark_fan_r")
	var fan_l := fan.duplicate() as Image
	fan_l.flip_x()
	_save(fan_l, "talent_wheel_to_wheel_spark_fan_l")
	_save(_cleared(_load(src, "talent_wheel_to_wheel_contact_flash.png")), "talent_wheel_to_wheel_contact_flash")
	# Particle spark: the Furious Overtake spark is red, so a particle tint cannot make it yellow. Keep its shape and
	# alpha, make it white-hot so the lemon particle tint shows.
	var spark := Image.load_from_file(ProjectSettings.globalize_path("res://assets/vfx/talent_furious_overtake_spark.png"))
	spark.convert(Image.FORMAT_RGBA8)
	for y in spark.get_height():
		for x in spark.get_width():
			var c := spark.get_pixel(x, y)
			var v := clampf(maxf(c.r, maxf(c.g, c.b)) * 1.15, 0.0, 1.0)
			spark.set_pixel(x, y, Color(v, v, v, c.a))
	_save(spark, "talent_wheel_to_wheel_spark")
	quit(0)


func _load(folder: String, file_name: String) -> Image:
	var image := Image.load_from_file(folder.path_join(file_name))
	image.convert(Image.FORMAT_RGBA8)
	print("%s %dx%d alpha max %.3f, bbox %s" % [file_name, image.get_width(), image.get_height(), _alpha_max(image), str(image.get_used_rect())])
	return image


## Zeroes the 2 px border (some GPT files keep ~3 % alpha at the edge, which would show as a frame when scaled).
func _cleared(image: Image) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	for y in h:
		for x in w:
			if x < 2 or y < 2 or x >= w - 2 or y >= h - 2:
				var c := image.get_pixel(x, y)
				image.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
	return image


## Keeps the white core, turns the cream glow lemon: blue drops most where the pixel is less than white-hot.
func _lemon(image: Image) -> Image:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			var hot := clampf((c.get_luminance() - 0.96) / 0.04, 0.0, 1.0)
			var tint := LEMON.lerp(Color(1.0, 0.95, 0.7), hot)
			image.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
	return image


## Wide soft copy of the edge: shrink x1/8, grow back (bilinear) twice, flat lemon colour.
func _spill(edge: Image) -> Image:
	var w := edge.get_width()
	var h := edge.get_height()
	var out := edge.duplicate() as Image
	for i in 2:
		out.resize(w / 8, h / 8, Image.INTERPOLATE_BILINEAR)
		out.resize(w, h, Image.INTERPOLATE_CUBIC)
	var amax := _alpha_max(out)
	for y in h:
		for x in w:
			var a := clampf(out.get_pixel(x, y).a / maxf(amax, 0.001), 0.0, 1.0)
			out.set_pixel(x, y, Color(LEMON.r, LEMON.g, LEMON.b, a * 0.9))
	return _cleared(out)


## Rim 0..1: clearly yellow pixels (blue well under red and green).
static func rim_of(c: Color) -> float:
	return clampf((minf(c.r, c.g) - c.b - 0.12) / 0.3, 0.0, 1.0)


func _split_wave(image: Image) -> void:
	var body := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	var rim := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	var rim_pixels := 0
	var solid := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			var r := rim_of(c)
			if c.a > 0.5:
				solid += 1
				if r > 0.5:
					rim_pixels += 1
			var air := Color(0.95, 0.96, 0.98, c.a)
			body.set_pixel(x, y, Color(c.r, c.g, c.b, c.a).lerp(air, r) if r > 0.0 else c)
			rim.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * r) if r > 0.0 else Color(1.0, 0.9, 0.4, 0.0))
	print("pressure_wave rim area %.0f%% of solid" % (100.0 * rim_pixels / maxf(solid, 1.0)))
	_save(body, "talent_wheel_to_wheel_wave_body")
	_save(rim, "talent_wheel_to_wheel_wave_rim")


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
