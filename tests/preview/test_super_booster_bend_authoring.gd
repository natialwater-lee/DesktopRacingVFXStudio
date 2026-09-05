extends RefCounted

const Pipeline := preload("res://src/app/vfx_preset_pipeline.gd")
const Registry := preload("res://src/model/vfx_schema_registry.gd")
const Codec := preload("res://src/model/vfx_preset_codec.gd")
const Rules := preload("res://src/model/vfx_rule_catalog.gd")
const Builder := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const Inputs := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd")
const Evaluator := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_modulation_evaluator.gd")

const START_RATIO := 0.333333333
const CORE_B := 102.0904551776
const SOFT_B := 178.5185009320


static func check_preset(tests: TestAssert, path: String, expected_count: int) -> void:
	var loaded := Pipeline.new().load_and_validate(path)
	tests.expect_true(loaded.success, "BEND-F3 production source validates: %s" % path)
	if not loaded.success:
		return
	var registry := Registry.new(Codec.new(), Rules.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	var built := Builder.new(registry).build(loaded.value.normalized_data)
	tests.expect_true(built.success, "BEND-F3 builds through the generic modulation program")
	if not built.success:
		return
	var program: RefCounted = built.value.runtime_modulation_program()
	var slot := -1
	for i in program.target_count():
		if program.target_name(i) == "VISUAL_BEND_OFFSET_X":
			slot = i
	var input_state := Inputs.new(program)
	var evaluator := Evaluator.new(program, input_state)
	var count := 0
	var old_turn_count := 0
	var geometry_valid := true
	var mapping_valid := true
	var root_error := 0.0
	var source: Dictionary = loaded.value.normalized_data
	for phase_name in ["start", "loop", "end"]:
		var specs: Array = built.value.phase_named(phase_name).layer_specs()
		for layer in source["phases"][phase_name]["layers"]:
			for binding in layer.get("modulations", []):
				if binding.get("source", {}).get("input") == "turn_rate_normalized" and binding.get("target") == "TRANSFORM_ROTATION_DEGREES":
					old_turn_count += 1
			if layer["type"] != "TEXTURED_SPRITE":
				geometry_valid = geometry_valid and not layer.has("visual_bend") and layer.get("modulations", []).is_empty()
				continue
			var core: bool = layer["parameters"]["texture_asset_ref"] == "fx.super_booster_flame_core"
			var span := 365.0 if core else 375.0
			var maximum := CORE_B if core else SOFT_B
			var pivot := Vector2(0.0, -181.0) if core else Vector2(-0.5, -183.0)
			var image := Image.new()
			image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/vfx/fx.super_booster_flame_%s.png" % ("core" if core else "soft")))
			var tail := float(image.get_used_rect().end.y) - image.get_height() * 0.5
			geometry_valid = geometry_valid and image.get_size() == Vector2i(256, 384) and is_equal_approx(tail - pivot.y, span)
			geometry_valid = geometry_valid and layer.get("visual_bend") == {"axis": "LOCAL_Y_POSITIVE", "start_ratio": START_RATIO, "curve": "QUADRATIC", "span_source_px": span}
			var turn_bindings: Array = layer.get("modulations", []).filter(func(b: Dictionary) -> bool: return b.get("source", {}).get("input") == "turn_rate_normalized")
			if turn_bindings.size() != 1 or turn_bindings[0].get("target") != "VISUAL_BEND_OFFSET_X" or slot < 0:
				mapping_valid = false
				continue
			count += 1
			var binding: Dictionary = turn_bindings[0]
			mapping_valid = mapping_valid and binding["operation"] == "ADD" and binding["mapping"] == {"type": "LINEAR_RANGE", "input_min": -0.2, "input_max": 0.2, "output_min": -maximum, "output_max": maximum}
			var matching_specs: Array = specs.filter(func(s: RefCounted) -> bool: return s.layer_id() == layer["id"])
			var state: RefCounted = evaluator.create_effective_state(matching_specs[0])
			for turn in [-1.0, -0.2, -0.166422, -0.1, 0.0, 0.1, 0.166422, 0.2, 1.0]:
				input_state.set_named_value(program, "turn_rate_normalized", turn)
				for time in [0.0, 1.0 / 28.0, 3.0 / 28.0]:
					evaluator.refresh(time, [state])
					var expected: float = clampf(turn / 0.2, -1.0, 1.0) * maximum
					mapping_valid = mapping_valid and absf(state.effective_value(slot) - expected) < 0.00001 and is_zero_approx(state.effective_rotation_degrees())
					var base_scale := Vector2(layer["transform"]["scale"][0], layer["transform"]["scale"][1])
					var base_offset := Vector2(layer["transform"]["offset"][0], layer["transform"]["offset"][1])
					var target_x := -60.0 if str(layer["id"]).contains(".left_") else 60.0 if str(layer["id"]).contains(".right_") else 0.0
					var anchor_root := Vector2(0.0, 220.0) + base_offset + pivot * base_scale
					root_error = maxf(root_error, anchor_root.distance_to(Vector2(target_x, 279.0)))
			var full_angle := rad_to_deg(atan(2.0 * maximum / ((1.0 - START_RATIO) * span)))
			var half_angle := rad_to_deg(atan(maximum / ((1.0 - START_RATIO) * span)))
			mapping_valid = mapping_valid and absf(full_angle - (40.0 if core else 55.0)) < 0.000001 and absf(half_angle - (22.760476275 if core else 35.529644867)) < 0.000001
			# Positive rotation on a +Y tail moves it toward -X. Preserve that lag,
			# so negative turn must produce negative visible-X displacement.
			var old_left_tail := Vector2(0.0, span).rotated(deg_to_rad(3.0 if core else 6.0))
			mapping_valid = mapping_valid and old_left_tail.x < 0.0 and binding["mapping"]["output_min"] < 0.0
	tests.expect_true(geometry_valid, "BEND-F3 uses actual alpha-tail span and unchanged pivots on every flame, never Spark")
	tests.expect_true(mapping_valid and old_turn_count == 0 and count == expected_count, "BEND-F3 replaces every rotation binding: saturated signed sweep, trace symmetry, tangent and generic evaluator")
	tests.expect_true(root_error <= 0.001, "BEND-F3 retains provisional Single/Dual root geometry")
	print("BEND_F3 count=%d old_turn=%d root_error=%.9f" % [count, old_turn_count, root_error])
