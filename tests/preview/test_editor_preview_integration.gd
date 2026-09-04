extends RefCounted

const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")
const VfxEditorMainModel := preload("res://src/editor/main/vfx_editor_main.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewLayerContextResolverModel := preload("res://src/preview/vfx_preview_layer_context_resolver.gd")
const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")
const VfxPreviewWorkspaceModel := preload("res://src/preview/vfx_preview_workspace.gd")
const VfxVehiclePreviewModel := preload("res://src/preview/vfx_vehicle_preview.gd")


static func run(tests: TestAssert) -> void:
	_test_schema_resolved_context(tests)
	_test_controller_preview_bridge(tests)
	_test_main_runtime_preview_insertion(tests)
	_test_turn_rate_preview_control_contract(tests)


static func _test_schema_resolved_context(tests: TestAssert) -> void:
	var decoded: VfxResult = VfxPresetCodecModel.new().decode_file("res://presets/examples/talent.zero_zone.vfx.json")
	var resolver := VfxPreviewLayerContextResolverModel.new(_registry())
	var context: RefCounted = resolver.resolve(decoded.value if decoded.success else {}, "start", "start.focus_flash")
	tests.expect_true(context != null and context.layer_id == "start.focus_flash", "Layer context resolver identifies the selected Layer without Preview reading Preset JSON")
	if context == null:
		return
	tests.expect_true(context.anchor_names() == ["CENTER"] and context.effective_space() == "VEHICLE_LOCAL", "Layer context derives effective vehicle Space and declared Anchors from Schema rules")
	tests.expect_true(context.transform_offset() == Vector2.ZERO and context.render_plane() == "UNDER_VEHICLE", "Layer context retains transform offset and render plane as immutable Preview inputs")


static func _test_controller_preview_bridge(tests: TestAssert) -> void:
	var packed := load("res://src/preview/vfx_vehicle_preview.tscn") as PackedScene
	var preview := packed.instantiate() as VfxVehiclePreviewModel if packed != null else null
	if preview == null:
		tests.expect_true(false, "controller Preview bridge requires the reusable Preview scene")
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(preview)
	var controller := VfxEditorControllerModel.new()
	controller.configure_preview(preview)
	var created: VfxResult = controller.create_new_preset("utility.preview_bridge", "Preview Bridge", "UTILITY", "ONE_SHOT", "VEHICLE_LOCAL")
	var added := controller.add_active_layer("GLOW") if created.success else false
	var layer_id := str(controller.working_preset().get("phases", {}).get("one_shot", {}).get("layers", [{}])[0].get("id", "")) if added else ""
	controller.select_layer(layer_id)
	controller.commit_selected_layer_anchors(["TIRE_FL", "TIRE_FR"])
	var context: RefCounted = preview.shared_state().layer_context()
	tests.expect_true(context != null and context.anchor_names() == ["TIRE_FL", "TIRE_FR"], "selected Layer sends every declared Anchor through Controller, resolver, and Preview state")
	tests.expect_true(context != null and context.effective_space() == "VEHICLE_LOCAL" and context.render_plane() == "UNDER_VEHICLE", "Preview bridge passes resolved Space and render plane rather than a mutable Preset reference")
	var valid_plan: RefCounted = preview.active_render_plan()
	controller.commit_selected_layer_parameter("/radius", -1.0)
	tests.expect_true(valid_plan != null and preview.active_render_plan() == valid_plan and preview.preview_status_text() == "PREVIEW STALE — VALIDATION ERROR", "invalid working edits preserve the last valid Preview Plan and report a stale validation state instead of forwarding invalid data to renderers")
	tree.root.remove_child(preview)
	preview.free()


static func _test_main_runtime_preview_insertion(tests: TestAssert) -> void:
	var packed := load("res://src/editor/main/vfx_editor_main.tscn") as PackedScene
	var editor := packed.instantiate() as VfxEditorMainModel if packed != null else null
	if editor == null:
		tests.expect_true(false, "main runtime Preview insertion requires the Editor scene")
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(editor)
	var workspace_path := "EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PreviewHost/VfxPreviewWorkspace"
	var workspace := editor.get_node_or_null(workspace_path) as VfxPreviewWorkspaceModel
	var preview_path := "%s/VfxVehiclePreview" % workspace_path
	var runtime_preview := editor.get_node_or_null(preview_path) as VfxVehiclePreviewModel
	tests.expect_true(workspace != null and runtime_preview != null, "main scene inserts the runtime Preview Workspace and its Vehicle Preview below PreviewHost without editing the scene file")
	tests.expect_true(runtime_preview != null and runtime_preview.get_future_vfx_host("EDIT") != null and runtime_preview.get_future_vfx_host("GAME") != null, "runtime Preview retains separate Phase 3 FutureVfxHost boundaries")
	var profile_select := runtime_preview.get_node_or_null("PreviewControls/DisplayRow/ProfileSelect") as OptionButton if runtime_preview != null else null
	tests.expect_true(profile_select != null and profile_select.item_count == 4 and runtime_preview.shared_state().profile_data().get("category") == "FORMULA", "runtime Preview loads four Studio-owned Profiles and selects Formula without reading a game repository")
	tree.root.remove_child(editor)
	editor.free()


static func _test_turn_rate_preview_control_contract(tests: TestAssert) -> void:
	var packed := load("res://src/preview/vfx_vehicle_preview.tscn") as PackedScene
	var preview := packed.instantiate() as VfxVehiclePreviewModel if packed != null else null
	var fixture: VfxResult = VfxPresetPipelineModel.new().load_and_validate("res://tests/fixtures/presets/utility.runtime_modulation_fixture.vfx.json")
	var registry := _registry()
	var plan_result: VfxResult = VfxPreviewRenderPlanBuilderModel.new(registry).build(fixture.value.normalized_data) if fixture.success else VfxResult.failure(fixture.issues)
	if preview == null or not plan_result.success:
		tests.expect_true(false, "Turn Rate Preview control test requires the reusable Preview scene and a valid modulated fixture")
		if preview != null:
			preview.free()
		return
	var source_before := JSON.stringify(fixture.value.normalized_data)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(preview)
	preview.set_schema_registry(registry)
	preview.apply_render_plan(plan_result.value)
	var slider := preview.get_node_or_null("PreviewControls/RuntimeInputsRow/TurnRateSlider") as HSlider
	var initial_value := slider.value if slider != null else 99.0
	slider.value = 1.0 if slider != null else 0.0
	var values: Dictionary = preview.get("_runtime_input_values_by_name")
	tests.expect_true(slider != null and slider.visible and is_equal_approx(slider.min_value, -1.0) and is_equal_approx(slider.max_value, 1.0) and is_equal_approx(initial_value, 0.0) and is_equal_approx(slider.value, 1.0) and slider.tick_count == 3 and slider.ticks_on_borders and is_equal_approx(float(values.get("turn_rate_normalized", 99.0)), 1.0) and source_before == JSON.stringify(fixture.value.normalized_data), "Turn Rate Preview control is signed, centered at neutral, writes only session state, and exposes its three comparison points")
	tree.root.remove_child(preview)
	preview.free()


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
