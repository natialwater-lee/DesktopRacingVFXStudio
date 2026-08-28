extends RefCounted

const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")
const VfxUnsavedChangesDialogModel := preload("res://src/editor/dialogs/vfx_unsaved_changes_dialog.gd")
const VfxStructureChangeDialogModel := preload("res://src/editor/dialogs/vfx_structure_change_dialog.gd")
const VfxDiagnosticsPanelModel := preload("res://src/editor/diagnostics/vfx_diagnostics_panel.gd")


static func run(tests: TestAssert) -> void:
	var controller := VfxEditorControllerModel.new()
	var unsaved_dialog := VfxUnsavedChangesDialogModel.new()
	var structure_dialog := VfxStructureChangeDialogModel.new()
	var diagnostics := VfxDiagnosticsPanelModel.new()
	controller.configure_transition_dialogs(unsaved_dialog, structure_dialog)
	controller.configure_diagnostics_panel(diagnostics)

	var created := controller.create_new_preset("utility.transitions", "Transitions", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(created.success, "transition fixture creates an in-memory Skeleton")
	tests.expect_true(_has_issue(diagnostics.issues(), "preset_has_no_layers"), "new empty Skeleton is shown as a transient diagnostics issue")
	if not created.success:
		unsaved_dialog.free()
		structure_dialog.free()
		diagnostics.free()
		return
	var outside_open := controller.open_path("res://schemas/vfx_schema_v1.json")
	tests.expect_true(not outside_open.success and _has_issue(diagnostics.issues(), "outside_authoring_root"), "failed open policy decisions are surfaced in diagnostics")

	var transitioned := {"value": false}
	controller.request_transition("Open", func() -> void: transitioned["value"] = true)
	unsaved_dialog.emit_decision("CANCEL")
	tests.expect_true(not transitioned["value"] and not controller.transition_performed(), "cancel leaves the active session untouched")
	tests.expect_true(not controller.can_undo(), "cancelled transition creates no history entry")
	controller.request_transition("Open", func() -> void: transitioned["value"] = true)
	unsaved_dialog.emit_decision("SAVE")
	tests.expect_true(not transitioned["value"] and not controller.transition_performed(), "a failed Save cancels the pending transition")
	controller.request_transition("Open", func() -> void: transitioned["value"] = true)
	unsaved_dialog.emit_decision("DISCARD")
	tests.expect_true(transitioned["value"] and controller.transition_performed(), "Discard performs the pending transition without a write")

	controller.add_active_layer("GLOW")
	tests.expect_true(not _has_issue(diagnostics.issues(), "preset_has_no_layers"), "adding a valid Layer refreshes and clears the empty-Preset diagnostic")
	var layer_id: String = controller.working_preset()["phases"]["one_shot"]["layers"][0]["id"]
	controller.select_layer(layer_id)
	controller.request_selected_layer_type_change("RING")
	structure_dialog.emit_signal("canceled")
	tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"][0]["type"] == "GLOW", "cancelling a Layer Type replacement preserves its Layer")
	controller.undo()
	tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"].is_empty(), "a cancelled Layer Type dialog does not consume an Undo history action")
	controller.redo()
	controller.select_layer(controller.working_preset()["phases"]["one_shot"]["layers"][0]["id"])
	controller.request_selected_layer_type_change("RING")
	structure_dialog.emit_signal("confirmed")
	tests.expect_true(controller.working_preset()["phases"]["one_shot"]["layers"][0]["type"] == "RING", "confirming a Layer Type dialog performs the replacement")
	controller.request_lifecycle_change("START_LOOP_END")
	structure_dialog.emit_signal("canceled")
	tests.expect_true(controller.working_preset()["lifecycle"]["mode"] == "ONE_SHOT", "cancelling a lifecycle replacement preserves the phase stack")

	controller.delete_active_layer(layer_id)
	tests.expect_true(controller.selected_layer_id().is_empty(), "deleting the selected Layer reconciles stale selection")
	controller.undo()
	tests.expect_true(controller.selected_layer_id().is_empty(), "undo after delete does not retain stale Layer selection")
	controller.redo()
	var layer_issue := diagnostics.issues().filter(func(issue: VfxIssue) -> bool: return issue.code == "preset_has_no_layers")
	tests.expect_true(layer_issue.size() == 1, "redo refreshes diagnostics for an empty active Preset")

	unsaved_dialog.free()
	structure_dialog.free()
	diagnostics.free()


static func _has_issue(issues: Array[VfxIssue], code: String) -> bool:
	return issues.any(func(issue: VfxIssue) -> bool: return issue.code == code)
