extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewAssetRegistryModel := preload("res://src/preview/rendering/vfx_preview_asset_registry.gd")
const VfxPreviewAssetResolverModel := preload("res://src/preview/rendering/vfx_preview_asset_resolver.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const InputsModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd")
const EvaluatorModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_modulation_evaluator.gd")
const VfxPreviewEquipmentCatalogModel := preload("res://src/preview/equipment/vfx_preview_equipment_catalog.gd")

const REAR_CENTER_Y := 220.0
const NOZZLE_ROOT_Y := 279.0
const PRESETS := {
	"equipment.super_booster": {"xs": [0.0], "jet": "fx.super_booster_jet_single", "gold": false},
	"equipment.super_booster.dual": {"xs": [-60.0, 60.0], "jet": "fx.super_booster_jet_twin", "gold": false},
	"equipment.super_booster.mk4": {"xs": [-60.0, 60.0], "jet": "fx.super_booster_jet_twin", "gold": true}
}
const TEXTURE_SIZES := {
	"fx.super_booster_jet_single": Vector2i(256, 640),
	"fx.super_booster_jet_twin": Vector2i(192, 576),
	"fx.super_booster_envelope": Vector2i(256, 640),
	"fx.super_booster_flare": Vector2i(256, 256),
	"fx.super_booster_charge_ring": Vector2i(256, 256),
	"fx.super_booster_shock_arc": Vector2i(256, 96),
	"fx.super_booster_bolt": Vector2i(128, 128),
	"fx.super_booster_core_gold": Vector2i(192, 576)
}


static func run(tests: TestAssert) -> void:
	_test_textures(tests)
	for preset_id in PRESETS:
		_test_structure_and_routing(tests, preset_id)
		_test_bend_roots_and_turn_contract(tests, preset_id)
		_test_charge_burst_timeline(tests, preset_id)
	_test_dual_and_mk4_differ_from_single(tests)
	_test_equipment_deploy_preview(tests)


static func _test_textures(tests: TestAssert) -> void:
	var resolver := VfxPreviewAssetResolverModel.new(VfxPreviewAssetRegistryModel.new())
	var matches := true
	for logical_id in TEXTURE_SIZES:
		var result: VfxResult = resolver.resolve(logical_id)
		var texture := result.value.get("texture") as Texture2D if result.success else null
		var image: Image = texture.get_image() if texture != null else null
		var rect := image.get_used_rect() if image != null else Rect2i()
		matches = matches and result.success and not result.value.get("is_fallback", true) and image != null \
			and image.get_size() == TEXTURE_SIZES[logical_id] \
			and rect.position.x >= 2 and rect.position.y >= 2 \
			and rect.end.x <= image.get_width() - 2 and rect.end.y <= image.get_height() - 2
	tests.expect_true(matches, "Super Booster v2 resolves its eight approved RGBA textures without fallback, at the delivered sizes and with a 2 px transparent margin")


static func _load(preset_id: String) -> Dictionary:
	var document: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/%s.vfx.json" % preset_id)
	return document.value.normalized_data if document.success else {}


static func _layers(data: Dictionary, phase_name: String) -> Array:
	return data.get("phases", {}).get(phase_name, {}).get("layers", [])


static func _by_id(layers: Array) -> Dictionary:
	var result := {}
	for layer in layers:
		result[str(layer.get("id", ""))] = layer
	return result


static func _test_structure_and_routing(tests: TestAssert, preset_id: String) -> void:
	var data := _load(preset_id)
	var phases: Dictionary = data.get("phases", {})
	var all_layers: Array = _layers(data, "start") + _layers(data, "loop") + _layers(data, "end")
	var routing_ok := not all_layers.is_empty() and all_layers.all(func(layer: Dictionary) -> bool:
		return layer.get("render_plane") == "UNDER_VEHICLE" and layer.get("blend_mode") == "ADDITIVE" and layer.get("anchors") == ["REAR_CENTER"])
	var start := _by_id(_layers(data, "start"))
	var loop := _by_id(_layers(data, "loop"))
	var end := _by_id(_layers(data, "end"))
	var single: bool = preset_id == "equipment.super_booster"
	var flare_ids: Array = ["start.charge_flare"] if single else ["start.left_flare", "start.right_flare"]
	var jets: Array = ["loop.jet"] if single else ["l.loop.jet", "r.loop.jet"]
	var structure_ok: bool = data.get("preset_id") == preset_id and data.get("category") == "SPECIAL_EQUIPMENT" \
		and data.get("default_space_mode") == "VEHICLE_LOCAL" and data.get("lifecycle", {}).get("mode") == "START_LOOP_END" \
		and data.get("runtime_inputs", []) == ["turn_rate_normalized"] \
		and is_equal_approx(float(phases.get("start", {}).get("duration_seconds", 0.0)), 0.5) \
		and is_equal_approx(float(phases.get("end", {}).get("duration_seconds", 0.0)), 0.35) \
		and flare_ids.all(func(id: String) -> bool: return start.has(id)) \
		and jets.all(func(id: String) -> bool: return loop.has(id) and loop[id].get("importance") == "CORE") \
		and loop.has("burst.shock_arc_a") and loop.has("burst.shock_arc_b") and loop.has("loop.sparks") \
		and end.has("end.sparks") and end.has("end.arc") \
		and (_layers(data, "end").filter(func(layer: Dictionary) -> bool: return layer.get("type") != "PARTICLE").is_empty())
	tests.expect_true(routing_ok and structure_ok, "%s is a 0.5 s charge START, burst-and-sustain LOOP and 0.35 s particle END, all ADDITIVE UNDER_VEHICLE REAR_CENTER layers" % preset_id)


static func _test_bend_roots_and_turn_contract(tests: TestAssert, preset_id: String) -> void:
	var config: Dictionary = PRESETS[preset_id]
	var data := _load(preset_id)
	var body_layers: Array = []
	for phase_name in ["loop", "end"]:
		for layer in _layers(data, phase_name):
			if str(layer.get("id", "")).ends_with("jet") or str(layer.get("id", "")).ends_with("envelope") or str(layer.get("id", "")).ends_with("gold_core"):
				body_layers.append(layer)
	var expected_count: int = config["xs"].size() * (3 if config["gold"] else 2) * 2
	var matches := body_layers.size() == expected_count
	var root_error := 0.0
	var xs_seen: Array = []
	for layer in body_layers:
		var transform: Dictionary = layer["transform"]
		var pivot: Array = transform.get("modulation_pivot_local", [])
		var bend: Dictionary = layer.get("visual_bend", {})
		var turn_bindings: Array = layer.get("modulations", []).filter(func(b: Dictionary) -> bool: return b.get("source", {}).get("input") == "turn_rate_normalized")
		var clamps: Array = layer.get("modulation_clamps", [])
		matches = matches and pivot.size() == 2 and bend.get("axis") == "LOCAL_Y_POSITIVE" and bend.get("curve") == "QUADRATIC" \
			and is_equal_approx(float(bend.get("start_ratio", 0.0)), 0.333333333) and float(bend.get("span_source_px", 0.0)) > 400.0 \
			and turn_bindings.size() == 1 and turn_bindings[0].get("target") == "VISUAL_BEND_OFFSET_X" and turn_bindings[0].get("operation") == "ADD" \
			and clamps.size() == 1 and clamps[0].get("target") == "VISUAL_BEND_OFFSET_X"
		if turn_bindings.size() == 1:
			var mapping: Dictionary = turn_bindings[0]["mapping"]
			var maximum := absf(float(mapping.get("output_max", 0.0)))
			matches = matches and is_equal_approx(float(mapping.get("input_min", 0.0)), -0.2) and is_equal_approx(float(mapping.get("input_max", 0.0)), 0.2) \
				and is_equal_approx(float(mapping.get("output_min", 0.0)), -maximum) and maximum >= 45.0 \
				and is_equal_approx(float(clamps[0].get("max_effective", 0.0)), maximum) and is_equal_approx(float(clamps[0].get("min_effective", 0.0)), -maximum)
		var x: float = float(transform["offset"][0])
		var root_y: float
		if layer["type"] == "TEXTURED_SPRITE":
			root_y = REAR_CENTER_Y + float(transform["offset"][1]) + float(pivot[1]) * float(transform["scale"][1])
		else:
			# a particle spawns at the jet centre: root = centre - half length (size_start)
			root_y = REAR_CENTER_Y + float(transform["offset"][1]) - float(layer["parameters"]["size_start"])
		root_error = maxf(root_error, absf(root_y - NOZZLE_ROOT_Y))
		if not xs_seen.has(x):
			xs_seen.append(x)
	xs_seen.sort()
	tests.expect_true(matches and root_error <= 0.001 and xs_seen == config["xs"], "%s keeps every flame body on its nozzle root and bends it with one saturated +-0.20 turn-rate binding per layer (root error %.6f)" % [preset_id, root_error])


static func _evaluator_for(preset_id: String) -> Dictionary:
	var document: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://presets/examples/%s.vfx.json" % preset_id)
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(registry).build(document.value.normalized_data) if document.success else VfxResult.failure(document.issues)
	if not plan_result.success:
		return {}
	var program: RefCounted = plan_result.value.runtime_modulation_program()
	var slots := {}
	for index in program.target_count():
		slots[program.target_name(index)] = index
	return {"plan": plan_result.value, "evaluator": EvaluatorModel.new(program, InputsModel.new(program)), "slots": slots}


static func _sample(context: Dictionary, phase_name: String, layer_id: String, time: float) -> Dictionary:
	var specs: Array = context["plan"].phase_named(phase_name).layer_specs().filter(func(spec: RefCounted) -> bool: return spec.layer_id() == layer_id)
	if specs.is_empty():
		return {}
	var evaluator: RefCounted = context["evaluator"]
	var state: RefCounted = evaluator.create_effective_state(specs[0])
	evaluator.refresh(time, [state])
	var slots: Dictionary = context["slots"]
	return {
		"sx": state.effective_value(slots["TRANSFORM_SCALE_X"]),
		"sy": state.effective_value(slots["TRANSFORM_SCALE_Y"]),
		"op": state.effective_value(slots["VISUAL_OPACITY_MULTIPLIER"]),
		"oy": state.effective_value(slots["TRANSFORM_OFFSET_Y"])
	}


static func _test_charge_burst_timeline(tests: TestAssert, preset_id: String) -> void:
	var context := _evaluator_for(preset_id)
	if context.is_empty():
		tests.expect_true(false, "%s timeline test requires a valid render plan" % preset_id)
		return
	var single: bool = preset_id == "equipment.super_booster"
	var flare_id := "start.charge_flare" if single else "start.left_flare"
	var glow_id := "loop.nozzle_glow" if single else "l.loop.nozzle_glow"
	var jet_id := "loop.jet" if single else "l.loop.jet"
	var flare_charge := _sample(context, "start", flare_id, 0.30)
	var flare_squeeze := _sample(context, "start", flare_id, 0.44)
	var flare_end := _sample(context, "start", flare_id, 0.499)
	var glow_start := _sample(context, "loop", glow_id, 0.5)
	var jet_birth := _sample(context, "loop", jet_id, 0.5)
	var jet_peak := _sample(context, "loop", jet_id, 0.56)
	var jet_a := _sample(context, "loop", jet_id, 1.5)
	var jet_b := _sample(context, "loop", jet_id, 2.9)
	var charge_ok: bool = flare_charge["sx"] > 0.3 and flare_squeeze["sx"] < flare_charge["sx"] * 1.05 and flare_end["sx"] > flare_squeeze["sx"] * 1.5
	# START hands over to LOOP: the flash at the end of START continues as the decaying nozzle glow
	var handoff_ok: bool = absf(flare_end["sx"] * 1.0 - glow_start["sx"]) <= 0.15 * flare_end["sx"] and absf(flare_end["op"] - 0.5 * glow_start["op"]) <= 0.2
	# burst: the jet is born short and overshoots, then settles to a steady length with only small flicker
	var burst_ok: bool = jet_birth["sy"] < 0.5 * jet_a["sy"] and jet_peak["sy"] > 1.2 * jet_a["sy"] \
		and absf(jet_a["sy"] - jet_b["sy"]) <= 0.12 * jet_a["sy"] and jet_a["sx"] > 0.0
	tests.expect_true(charge_ok and handoff_ok and burst_ok, "%s charges, squeezes and flashes in START, hands the flash to the nozzle glow, then the jet overshoots at LOOP start and settles (the one-shot ramps hold their end values)" % preset_id)


static func _test_dual_and_mk4_differ_from_single(tests: TestAssert) -> void:
	var single := _load("equipment.super_booster")
	var dual := _load("equipment.super_booster.dual")
	var mk4 := _load("equipment.super_booster.mk4")
	var single_loop := _by_id(_layers(single, "loop"))
	var dual_loop := _by_id(_layers(dual, "loop"))
	var mk4_loop := _by_id(_layers(mk4, "loop"))
	var single_jet: Dictionary = single_loop["loop.jet"]
	var dual_jet: Dictionary = dual_loop["l.loop.jet"]
	var single_width := float(single_jet["transform"]["scale"][0]) * 91.0
	var dual_width := float(dual_jet["transform"]["scale"][0]) * 66.0
	var dual_start := _by_id(_layers(dual, "start"))
	var dual_ok: bool = single_jet["parameters"]["texture_asset_ref"] == "fx.super_booster_jet_single" \
		and dual_jet["parameters"]["texture_asset_ref"] == "fx.super_booster_jet_twin" \
		and dual_width < single_width \
		and 2.0 * dual_width > single_width \
		and dual_start.has("start.bridge_a") and dual_start.has("start.bridge_b") and dual_loop.has("loop.bridge") \
		and not single_loop.has("loop.bridge") \
		and dual_loop.has("l.loop.pulse") and dual_loop.has("r.loop.pulse")
	var gold_ok: bool = mk4_loop.has("l.loop.gold_core") and mk4_loop.has("r.loop.gold_core") and mk4_loop.has("loop.big_pulse") \
		and not dual_loop.has("l.loop.gold_core") and not dual_loop.has("loop.big_pulse") \
		and _by_id(_layers(mk4, "start")).has("start.center_ring") and _by_id(_layers(mk4, "end")).has("l.end.gold_core") \
		and float(mk4_loop["l.loop.jet"]["transform"]["scale"][1]) > float(dual_jet["transform"]["scale"][1])
	tests.expect_true(dual_ok and gold_ok, "Dual uses the twin-helix jets (each narrower than the Single lance, together wider) with a lightning bridge, and Mk.IV adds the gold core, centre charge ring and big thrust pulse at a larger size")


static func _test_equipment_deploy_preview(tests: TestAssert) -> void:
	var catalog := VfxPreviewEquipmentCatalogModel.new()
	var deploy: Array = catalog.frames("super_booster", "mk3", "deploy")
	var active: Array = catalog.frames("super_booster", "mk3", "active")
	tests.expect_true(
		catalog.equipment_type_for_preset("equipment.super_booster") == "super_booster" \
		and catalog.equipment_type_for_preset("equipment.super_booster.dual") == "super_booster" \
		and catalog.equipment_type_for_preset("equipment.super_booster.mk4") == "super_booster" \
		and catalog.marks("super_booster") == ["mk1", "mk2", "mk3", "mk4"] \
		and catalog.vfx_starts_at_deploy("super_booster") and not catalog.vfx_starts_at_deploy("rotor_lift") \
		and not deploy.is_empty() and not active.is_empty() \
		and catalog.resolve_frame("super_booster", "mk3", "deploy", 0.0) == deploy[0] \
		and catalog.resolve_frame("super_booster", "mk3", "deploy", 0.49) == deploy[deploy.size() - 1],
		"Studio preview knows the Super Booster hardware (Mk.I-IV, hyper) and starts its VFX with the deploy frames"
	)
