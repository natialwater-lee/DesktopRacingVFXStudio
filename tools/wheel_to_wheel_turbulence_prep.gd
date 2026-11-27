extends SceneTree
# Prepares the GPT Wheel to Wheel turbulence wisps (64 x 256, flow = image down) for the Studio. Run:
#   godot --headless --path <studio> --script res://tools/wheel_to_wheel_turbulence_prep.gd -- <folder with the 2 GPT PNGs>
# Writes res://assets/vfx/talent_wheel_to_wheel_turbulence_{a,b}.png and prints checks.
# Particles scale uniformly, so the width is baked in: each wisp is widened x4 into a 160 x 256 canvas (the long side
# stays 256, so particle sizes keep their length). At ~10..16 screen px long that makes the wisp ~3..4 px wide on screen
# (the delivered 1:10 wisp was under 1 px and not visible in the race; x2.75 was still weak, Jihoon 11-27).
# Design: docs/superpowers/specs/2026-11-26-talent-wheel-to-wheel-design.md section 11
const OUT := "res://assets/vfx/"
const WIDEN := 4.0
const OUT_SIZE := Vector2i(160, 256)     # wide enough for the x4 wisp + sway (b reached the edge at 128)
const BORDER := 3


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the folder that holds the GPT PNGs.")
		quit(1)
		return
	for key in ["a", "b"]:
		var src := Image.load_from_file(args[0].path_join("talent_wheel_to_wheel_turbulence_%s.png" % key))
		src.convert(Image.FORMAT_RGBA8)
		var out := Image.create(OUT_SIZE.x, OUT_SIZE.y, false, Image.FORMAT_RGBA8)
		var half_in := src.get_width() * 0.5
		var half_out := OUT_SIZE.x * 0.5
		var amax := 0.0
		var xmin := OUT_SIZE.x
		var xmax := -1
		for y in OUT_SIZE.y:
			var sy := int(float(y) * src.get_height() / OUT_SIZE.y)
			for x in OUT_SIZE.x:
				if x < BORDER or x >= OUT_SIZE.x - BORDER or y < BORDER or y >= OUT_SIZE.y - BORDER:
					continue
				# Bilinear along x only (the source is sampled at the widened position).
				var fx := (x + 0.5 - half_out) / WIDEN + half_in - 0.5
				var x0 := clampi(int(floor(fx)), 0, src.get_width() - 1)
				var x1 := clampi(x0 + 1, 0, src.get_width() - 1)
				var c := src.get_pixel(x0, sy).lerp(src.get_pixel(x1, sy), clampf(fx - floor(fx), 0.0, 1.0))
				out.set_pixel(x, y, c)
				if c.a > 0.05:
					amax = maxf(amax, c.a)
					xmin = mini(xmin, x)
					xmax = maxi(xmax, x)
		out.save_png(ProjectSettings.globalize_path(OUT + "talent_wheel_to_wheel_turbulence_%s.png" % key))
		print("turbulence_%s: %s, alpha max %.2f, visible x %d..%d (%d px wide)" % [key, str(OUT_SIZE), amax, xmin, xmax, xmax - xmin + 1])
	quit(0)
