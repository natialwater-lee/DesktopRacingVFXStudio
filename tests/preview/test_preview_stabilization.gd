extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxVehicleProfileCodecModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_codec.gd")
const VfxVehicleProfileEditSessionModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_edit_session.gd")
const VfxVehicleProfileRepositoryModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_repository.gd")
const VfxVehicleProfileValidatorModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_validator.gd")
const VfxPreviewLayerContextModel := preload("res://src/preview/vfx_preview_layer_context.gd")
const VfxPreviewSharedStateModel := preload("res://src/preview/vfx_preview_shared_state.gd")
const VfxPreviewTransformResolverModel := preload("res://src/preview/vfx_preview_transform_resolver.gd")
const VfxVehiclePreviewCanvasModel := preload("res://src/preview/vfx_vehicle_preview_canvas.gd")
const VfxVehiclePreviewModel := preload("res://src/preview/vfx_vehicle_preview.gd")


static func run(tests: TestAssert) -> void:
	_test_edit_canvas_uses_viewport_as_small_content_floor(tests)
	_test_profile_load_revert_and_switch_keep_anchor_baseline(tests)


static func _test_edit_canvas_uses_viewport_as_small_content_floor(tests: TestAssert) -> void:
	var resolver := VfxPreviewTransformResolverModel.new()
	var has_edit_layout_helpers := resolver.has_method("edit_content_size") and resolver.has_method("stage_center")
	tests.expect_true(has_edit_layout_helpers, "transform resolver exposes fixed-content centering helpers for the Edit Canvas")
	if not has_edit_layout_helpers:
		return
	var centered_content: Vector2 = resolver.edit_content_size(Vector2(48.64, 97.28), Vector2(320.0, 240.0), 24.0)
	var overflow_content: Vector2 = resolver.edit_content_size(Vector2(97.28, 194.56), Vector2(80.0, 80.0), 24.0)
	tests.expect_true(_same_vector(centered_content, Vector2(320.0, 240.0)) and _same_vector(resolver.stage_center(centered_content), Vector2(160.0, 120.0)), "transform resolver centers fixed Edit content within a larger viewport without changing source-local scale")
	tests.expect_true(_same_vector(overflow_content, Vector2(145.28, 242.56)), "transform resolver preserves 400 percent content plus padding when scrolling is required")

	var scroll := ScrollContainer.new()
	var canvas := VfxVehiclePreviewCanvasModel.new()
	var tree := Engine.get_main_loop() as SceneTree
	scroll.size = Vector2(320.0, 240.0)
	scroll.add_child(canvas)
	tree.root.add_child(scroll)
	canvas.set_interactive(true)
	canvas.set_view_zoom(2.0)
	canvas.set_shared_state(_state_with_formula())
	tests.expect_true(_same_vector(canvas.custom_minimum_size, Vector2(320.0, 240.0)), "Edit Canvas keeps fixed-scale content centered by expanding to an oversized ScrollContainer viewport")

	canvas.size = Vector2(320.0, 240.0)
	var future_host := canvas.get_future_vfx_host()
	var anchor_positions := canvas.resolved_layer_anchor_positions()
	var ghost_positions := canvas.ghost_positions()
	tests.expect_true(future_host != null and _same_vector(future_host.position, Vector2(160.0, 120.0)) and anchor_positions.size() == 1 and _same_vector(anchor_positions[0], Vector2(160.0, 120.0)) and ghost_positions.size() == 1 and _same_vector(ghost_positions[0], Vector2(160.57, 119.62)), "vehicle, Anchor, local ghost, and FutureVfxHost share the centered source-local stage transform")
	scroll.size = Vector2(400.0, 300.0)
	tests.expect_true(_same_vector(canvas.custom_minimum_size, Vector2(400.0, 300.0)), "Edit Canvas recomputes its viewport floor when a window or splitter resize changes the ScrollContainer")
	tree.root.remove_child(scroll)
	scroll.free()

	var overflow_scroll := ScrollContainer.new()
	var overflow_canvas := VfxVehiclePreviewCanvasModel.new()
	overflow_scroll.size = Vector2(80.0, 80.0)
	overflow_scroll.add_child(overflow_canvas)
	tree.root.add_child(overflow_scroll)
	overflow_canvas.set_interactive(true)
	overflow_canvas.set_view_zoom(4.0)
	overflow_canvas.set_shared_state(_state_with_formula())
	tests.expect_true(_same_vector(overflow_canvas.custom_minimum_size, Vector2(145.28, 242.56)), "Edit Canvas keeps its 400 percent fixed-scale vehicle bounds plus marker-safe padding for scrolling rather than fitting down")
	tree.root.remove_child(overflow_scroll)
	overflow_scroll.free()


static func _test_profile_load_revert_and_switch_keep_anchor_baseline(tests: TestAssert) -> void:
	var repository := _repository()
	var formula: VfxResult = repository.load_profile("res://profiles/vehicles/formula.vehicle_profile.json")
	var sports: VfxResult = repository.load_profile("res://profiles/vehicles/sports.vehicle_profile.json")
	if not formula.success or not sports.success:
		tests.expect_true(false, "Profile lifecycle regression requires Formula and Sports Profiles")
		return
	var formula_baseline: Dictionary = formula.value.data().get("anchors", {}).duplicate(true)
	var session := VfxVehicleProfileEditSessionModel.new(repository)
	session.open_document(formula.value)
	tests.expect_true(session.working_copy().get("anchors", {}) == formula_baseline, "Profile load creates a working Anchor copy equal to its saved baseline")

	var state := _state_with_formula()
	var canvas := VfxVehiclePreviewCanvasModel.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(canvas)
	canvas.size = Vector2(240.0, 160.0)
	canvas.set_interactive(true)
	canvas.set_view_zoom(2.0)
	state.set_profile_data(session.working_copy())
	canvas.set_shared_state(state)
	var load_projection := canvas.resolved_layer_anchor_positions()
	session.revert()
	state.set_profile_data(session.working_copy())
	var revert_projection := canvas.resolved_layer_anchor_positions()
	tests.expect_true(session.working_copy().get("anchors", {}) == formula_baseline and load_projection == revert_projection, "Revert without Profile edits preserves both Anchor data and projected positions")

	session.set_anchor("CENTER", Vector2(17.0, -9.0))
	state.set_profile_data(session.working_copy())
	session.revert()
	state.set_profile_data(session.working_copy())
	tests.expect_true(session.working_copy().get("anchors", {}) == formula_baseline and canvas.resolved_layer_anchor_positions() == load_projection, "Anchor drag followed by Revert restores the exact loaded Profile baseline")
	tree.root.remove_child(canvas)
	canvas.free()

	var packed := load("res://src/preview/vfx_vehicle_preview.tscn") as PackedScene
	var preview := packed.instantiate() as VfxVehiclePreviewModel if packed != null else null
	if preview == null:
		tests.expect_true(false, "Profile switch regression requires the Preview scene")
		return
	tree.root.add_child(preview)
	preview.set_profile_repository(repository)
	preview.set_profile_documents([formula.value, sports.value])
	var profile_select := preview.get_node_or_null("PreviewControls/DisplayRow/ProfileSelect") as OptionButton
	_select_profile(profile_select, "res://profiles/vehicles/sports.vehicle_profile.json")
	_select_profile(profile_select, "res://profiles/vehicles/formula.vehicle_profile.json")
	var preset_before := {"preset_id": "unchanged", "phases": {"one_shot": {"layers": []}}}
	tests.expect_true(preview.shared_state().profile_data().get("anchors", {}) == formula_baseline and preset_before == {"preset_id": "unchanged", "phases": {"one_shot": {"layers": []}}}, "Formula to Sports to Formula restores Formula baseline without changing Preset working data")
	tree.root.remove_child(preview)
	preview.free()


static func _state_with_formula() -> RefCounted:
	var decoded: VfxResult = VfxVehicleProfileCodecModel.new().decode_file("res://profiles/vehicles/formula.vehicle_profile.json")
	var state := VfxPreviewSharedStateModel.new()
	state.set_game_scale_contract({
		"version": 1,
		"base_car_sprite_scale": [0.38, 0.38],
		"car_visual_scale": 0.25,
		"track_scales": [1.0, 0.95, 0.9, 0.85]
	})
	state.set_track_scale(1.0)
	state.set_profile_data(decoded.value if decoded.success and decoded.value is Dictionary else {})
	state.set_layer_context(VfxPreviewLayerContextModel.new("preview.center", ["CENTER"], "VEHICLE_LOCAL", Vector2(3.0, -2.0), "UNDER_VEHICLE"))
	return state


static func _repository() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return VfxVehicleProfileRepositoryModel.new(VfxVehicleProfileCodecModel.new(), VfxVehicleProfileValidatorModel.new(registry))


static func _select_profile(profile_select: OptionButton, profile_path: String) -> void:
	if profile_select == null:
		return
	for index in profile_select.item_count:
		if str(profile_select.get_item_metadata(index)) == profile_path:
			profile_select.select(index)
			profile_select.emit_signal("item_selected", index)
			return


static func _same_vector(actual: Vector2, expected: Vector2) -> bool:
	return is_equal_approx(actual.x, expected.x) and is_equal_approx(actual.y, expected.y)
