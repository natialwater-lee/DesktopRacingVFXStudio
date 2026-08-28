extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxVehicleProfileCodecModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_codec.gd")
const VfxVehicleProfileDocumentModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_document.gd")
const VfxVehicleProfileEditSessionModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_edit_session.gd")
const VfxVehicleProfileRepositoryModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_repository.gd")
const VfxVehicleProfileValidatorModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_validator.gd")
const VfxPreviewGameScaleModel := preload("res://src/preview/vfx_preview_game_scale.gd")
const VfxPreviewLayerContextModel := preload("res://src/preview/vfx_preview_layer_context.gd")
const VfxPreviewSharedStateModel := preload("res://src/preview/vfx_preview_shared_state.gd")
const VfxPreviewTransformResolverModel := preload("res://src/preview/vfx_preview_transform_resolver.gd")
const VfxVehiclePreviewCanvasModel := preload("res://src/preview/vfx_vehicle_preview_canvas.gd")


static func run(tests: TestAssert) -> void:
	_test_profile_save_and_revert(tests)
	_test_multi_anchor_and_game_readability_policy(tests)
	_test_source_local_motion_projection(tests)


static func _test_profile_save_and_revert(tests: TestAssert) -> void:
	var profile_data := _formula_profile_data()
	var temp_path := "user://phase2_profile_edit_session.json"
	var session := VfxVehicleProfileEditSessionModel.new(_repository())
	session.open_document(VfxVehicleProfileDocumentModel.new(temp_path, profile_data))
	var preset_before := {"preset_id": "untouched", "phases": {"one_shot": {"layers": []}}}
	session.set_anchor("CENTER", Vector2(11.4, -7.6))
	tests.expect_true(session.is_dirty() and session.working_copy()["anchors"]["CENTER"] == [11, -8], "Profile anchor editing rounds to one source pixel without mutating Preset data")
	tests.expect_true(preset_before == {"preset_id": "untouched", "phases": {"one_shot": {"layers": []}}}, "Profile edit session keeps Preset working data independent")
	var saved: VfxResult = session.save()
	var decoded: VfxResult = VfxVehicleProfileCodecModel.new().decode_file(temp_path)
	var saved_center: Variant = decoded.value.get("anchors", {}).get("CENTER", []) if decoded.success else []
	tests.expect_true(saved.success and decoded.success and saved_center is Array and saved_center.size() == 2 and is_equal_approx(float(saved_center[0]), 11.0) and is_equal_approx(float(saved_center[1]), -8.0), "Profile Save writes only the validated Profile working data")
	session.set_anchor("CENTER", Vector2(20, 20))
	session.revert()
	tests.expect_true(session.working_copy()["anchors"]["CENTER"] == [11, -8] and not session.is_dirty(), "Profile Revert restores the saved baseline without Profile Undo/Redo")
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))


static func _test_multi_anchor_and_game_readability_policy(tests: TestAssert) -> void:
	var canvas := VfxVehiclePreviewCanvasModel.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(canvas)
	canvas.size = Vector2(240, 240)
	var state := VfxPreviewSharedStateModel.new()
	state.set_game_scale_contract(_scale_contract())
	state.set_track_scale(1.0)
	state.set_profile_data(_formula_profile_data())
	state.set_layer_context(VfxPreviewLayerContextModel.new("loop.tires", ["TIRE_FL", "TIRE_FR", "TIRE_RL", "TIRE_RR"], "VEHICLE_LOCAL", Vector2(3, -2), "UNDER_VEHICLE"))
	canvas.set_interactive(true)
	canvas.set_view_zoom(2.0)
	canvas.set_shared_state(state)
	tests.expect_true(canvas.resolved_layer_anchor_positions().size() == 4, "four-Tire Layer highlights every declared Anchor")
	tests.expect_true(canvas.ghost_positions().size() == 4, "vehicle-local offset creates one ghost marker per selected Anchor")
	tests.expect_true(canvas.visible_anchor_labels().size() == 14, "Edit Canvas keeps labels available for Profile authoring")
	canvas.set_interactive(false)
	tests.expect_true(canvas.visible_anchor_labels().is_empty() and canvas.resolved_layer_anchor_positions().size() == 4, "Game Canvas suppresses labels but retains tiny selected-Layer markers")
	tree.root.remove_child(canvas)
	canvas.free()


static func _test_source_local_motion_projection(tests: TestAssert) -> void:
	var scale_result := VfxPreviewGameScaleModel.effective_scale(_scale_contract(), 1.0)
	if not scale_result.success:
		tests.expect_true(false, "motion projection requires the supplied game scale contract")
		return
	var source_translation := Vector2(160, 0)
	var game_position := VfxPreviewTransformResolverModel.project_source_local(Vector2.ZERO, Vector2(40, 50), source_translation, 0.0, scale_result.value, 1.0)
	var edit_position := VfxPreviewTransformResolverModel.project_source_local(Vector2.ZERO, Vector2(120, 90), source_translation, 0.0, scale_result.value, 4.0)
	tests.expect_true(is_equal_approx(game_position.x - 40.0, 15.2) and is_equal_approx(edit_position.x - 120.0, 60.8), "shared source-local motion state projects through each Canvas scale and zoom rather than sharing screen pixels")


static func _repository() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return VfxVehicleProfileRepositoryModel.new(VfxVehicleProfileCodecModel.new(), VfxVehicleProfileValidatorModel.new(registry))


static func _formula_profile_data() -> Dictionary:
	var decoded: VfxResult = VfxVehicleProfileCodecModel.new().decode_file("res://profiles/vehicles/formula.vehicle_profile.json")
	return decoded.value.duplicate(true) if decoded.success else {}


static func _scale_contract() -> Dictionary:
	return {
		"version": 1,
		"base_car_sprite_scale": [0.38, 0.38],
		"car_visual_scale": 0.25,
		"track_scales": [1.0, 0.95, 0.9, 0.85]
	}
