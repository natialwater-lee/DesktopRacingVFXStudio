extends RefCounted

const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")
const VfxEditorMainModel := preload("res://src/editor/main/vfx_editor_main.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxPreviewLayerContextResolverModel := preload("res://src/preview/vfx_preview_layer_context_resolver.gd")
const VfxVehiclePreviewModel := preload("res://src/preview/vfx_vehicle_preview.gd")


static func run(tests: TestAssert) -> void:
	_test_schema_resolved_context(tests)
	_test_controller_preview_bridge(tests)
	_test_main_runtime_preview_insertion(tests)


static func _test_schema_resolved_context(tests: TestAssert) -> void:
	var decoded: VfxResult = VfxPresetCodecModel.new().decode_file("res://presets/examples/talent.zero_zone.vfx.json")
	var resolver := VfxPreviewLayerContextResolverModel.new(_registry())
	var context: RefCounted = resolver.resolve(decoded.value if decoded.success else {}, "start", "start.inner_flash")
	tests.expect_true(context != null and context.layer_id == "start.inner_flash", "Layer context resolver identifies the selected Layer without Preview reading Preset JSON")
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
	var preview_path := "EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PreviewHost/VfxVehiclePreview"
	var runtime_preview := editor.get_node_or_null(preview_path) as VfxVehiclePreviewModel
	tests.expect_true(runtime_preview != null, "main scene inserts Vehicle Preview below PreviewHost at runtime without editing the scene file")
	tests.expect_true(runtime_preview != null and runtime_preview.get_future_vfx_host("EDIT") != null and runtime_preview.get_future_vfx_host("GAME") != null, "runtime Preview retains separate Phase 3 FutureVfxHost boundaries")
	var profile_select := runtime_preview.get_node_or_null("PreviewControls/DisplayRow/ProfileSelect") as OptionButton if runtime_preview != null else null
	tests.expect_true(profile_select != null and profile_select.item_count == 4 and runtime_preview.shared_state().profile_data().get("category") == "FORMULA", "runtime Preview loads four Studio-owned Profiles and selects Formula without reading a game repository")
	tree.root.remove_child(editor)
	editor.free()


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry
