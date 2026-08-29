extends RefCounted

const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")
const VfxExportServiceModel := preload("res://src/export/vfx_export_service.gd")
const VfxExportPanelModel := preload("res://src/editor/export/vfx_export_panel.gd")
const VfxPreviewWorkspaceModel := preload("res://src/preview/vfx_preview_workspace.gd")


class ExportPanelControllerFake:
	extends RefCounted

	var source_path := "res://presets/examples/talent.zero_zone.vfx.json"
	var dirty := false
	var validation_result: VfxResult
	var validation_calls := 0
	var export_calls: Array[bool] = []
	var package_exists_on_first_export := false

	func active_export_source_path() -> String:
		return source_path

	func active_export_is_dirty() -> bool:
		return dirty

	func validate_active_export() -> VfxResult:
		validation_calls += 1
		return validation_result

	func export_active_preset(replace_existing: bool) -> VfxResult:
		export_calls.append(replace_existing)
		if package_exists_on_first_export and not replace_existing:
			return VfxResult.failure([VfxIssue.new("EXPORT_IO", "export_package_exists", "Package already exists.")])
		return VfxResult.ok("res://exports/packages/talent.zero_zone/")


static func run(tests: TestAssert) -> void:
	_test_workspace_exposes_export_mode(tests)
	_test_editor_bridge_blocks_unsaved_and_dirty_sessions(tests)
	_test_export_panel_shows_requirements_and_requires_replace_confirmation(tests)


static func _test_workspace_exposes_export_mode(tests: TestAssert) -> void:
	var workspace := VfxPreviewWorkspaceModel.new()
	workspace._build_workspace()
	var mode_select := workspace.get_node_or_null("WorkspaceControls/PreviewModeSelect") as OptionButton
	tests.expect_true(mode_select != null and mode_select.item_count == 3 and mode_select.get_item_text(0) == "AUTHORING PREVIEW" and mode_select.get_item_text(1) == "PERFORMANCE" and mode_select.get_item_text(2) == "EXPORT", "Workspace mode selector keeps AUTHORING PREVIEW, PERFORMANCE, EXPORT in order")
	workspace.free()


static func _test_editor_bridge_blocks_unsaved_and_dirty_sessions(tests: TestAssert) -> void:
	var controller := VfxEditorControllerModel.new()
	var unsaved: VfxResult = controller.validate_active_export()
	tests.expect_true(not unsaved.success and _has_issue(unsaved, "export_unsaved_preset"), "Controller blocks Export validation for an unsaved session")
	var opened: VfxResult = controller.open_path("res://presets/examples/talent.zero_zone.vfx.json")
	var saved: VfxResult = controller.validate_active_export()
	tests.expect_true(opened.success and not controller.active_export_is_dirty() and saved.success, "Controller validates only the saved Zero Zone source through Export service")
	controller.commit_preset_field("/display_name", "Dirty Zero Zone")
	var dirty: VfxResult = controller.export_active_preset(false)
	tests.expect_true(controller.active_export_is_dirty() and not dirty.success and _has_issue(dirty, "export_dirty_preset"), "Controller blocks Export before the service when the Editor session is dirty")


static func _test_export_panel_shows_requirements_and_requires_replace_confirmation(tests: TestAssert) -> void:
	var plan_result: VfxResult = VfxExportServiceModel.new().validate_saved_source("res://presets/examples/talent.zero_zone.vfx.json")
	if not plan_result.success:
		tests.expect_true(false, "Export panel test requires a valid saved Zero Zone Package plan")
		return
	var fake := ExportPanelControllerFake.new()
	fake.validation_result = plan_result
	var panel := VfxExportPanelModel.new()
	panel.configure(fake)
	panel.refresh_validation()
	tests.expect_true(panel.validation_status_text() == "READY" and panel.package_root_text() == "res://exports/packages/" and panel.requirement_summary_text().contains("CENTER") and panel.requirement_summary_text().contains("intensity"), "Export panel exposes fixed Studio root and derived requirements without reading Preset JSON")
	fake.dirty = true
	var calls_before_dirty := fake.validation_calls
	panel.refresh_validation()
	tests.expect_true(panel.validation_status_text().begins_with("BLOCKED") and fake.validation_calls == calls_before_dirty, "dirty session is BLOCKED by the panel before Export service validation")
	fake.dirty = false
	panel.refresh_validation()
	fake.package_exists_on_first_export = true
	panel.request_export()
	tests.expect_true(fake.export_calls == [false] and panel.replace_confirmation_visible(), "existing Package requests local confirmation before REPLACE_EXISTING is passed")
	panel.confirm_replace_export()
	tests.expect_true(fake.export_calls == [false, true], "confirmed replacement is the only path that passes REPLACE_EXISTING to the Controller")
	panel.free()


static func _has_issue(result: VfxResult, code: String) -> bool:
	for issue in result.issues:
		if issue.code == code:
			return true
	return false
