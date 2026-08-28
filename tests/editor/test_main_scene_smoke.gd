extends RefCounted

const VfxEditorMainModel := preload("res://src/editor/main/vfx_editor_main.gd")


static func run(tests: TestAssert) -> void:
	var packed := load("res://src/editor/main/vfx_editor_main.tscn") as PackedScene
	tests.expect_true(packed != null, "editor scene loads")
	if packed == null:
		return

	var editor := packed.instantiate() as VfxEditorMainModel
	tests.expect_true(editor != null, "editor scene instantiates its typed root")
	if editor == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var original_auto_accept_quit := tree.auto_accept_quit
	tree.root.add_child(editor)
	tests.expect_true(editor.editor_controller != null, "editor assigns its typed controller")
	tests.expect_true(editor.get_node_or_null("Toolbar") != null, "toolbar exists")
	tests.expect_true(editor.get_node_or_null("LibraryPanel") != null, "library region exists")
	tests.expect_true(editor.get_node_or_null("PhaseTabs") != null, "phase tabs region exists")
	tests.expect_true(editor.get_node_or_null("LayerStack") != null, "layer stack region exists")
	tests.expect_true(editor.get_node_or_null("LayerStack/Rows/AddControls/AddLayerButton") is Button, "Layer Stack scene creates its concrete Add control")
	tests.expect_true(editor.get_node_or_null("InspectorPanel") != null, "inspector region exists")
	tests.expect_true(editor.get_node_or_null("DiagnosticsPanel") != null, "diagnostics region exists")
	tests.expect_true(editor.get_node("Toolbar/NewButton").is_connected("pressed", Callable(editor.editor_controller, "_on_new_pressed")), "New button opens the schema-derived new dialog")
	tests.expect_true(editor.get_node("Toolbar/OpenButton").is_connected("pressed", Callable(editor.editor_controller, "_on_open_pressed")), "Open button starts the authoring-root file selection flow")
	tests.expect_true(editor.get_node("Toolbar/SaveButton").is_connected("pressed", Callable(editor.editor_controller, "_on_save_pressed")), "Save button uses the valid-only persistence flow")
	tests.expect_true(editor.get_node("Toolbar/SaveAsButton").is_connected("pressed", Callable(editor.editor_controller, "_on_save_as_pressed")), "Save As button starts the authoring-root destination flow")
	tests.expect_true(editor.get_node("LayerStack").add_layer_requested.is_connected(Callable(editor.editor_controller, "_on_add_layer_requested")), "Layer Stack Add signal is connected to the controller")
	tests.expect_true((editor.get_node("Toolbar/SaveButton") as Button).disabled, "Save is disabled before an existing document has a source path")
	tests.expect_true((editor.get_node("Toolbar/UndoButton") as Button).disabled and (editor.get_node("Toolbar/RedoButton") as Button).disabled, "history toolbar starts disabled without an edit session")

	var created := editor.editor_controller.create_new_preset("utility.close_guard", "Close Guard", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(created.success, "scene close guard fixture creates a dirty in-memory Preset")
	tests.expect_true((editor.get_node("Toolbar/SaveButton") as Button).disabled and not (editor.get_node("Toolbar/SaveAsButton") as Button).disabled, "new unsaved Preset enables only Save As")
	tests.expect_true(_has_issue(editor.editor_controller.current_issues(), "preset_has_no_layers"), "new session exposes its transient no-layer Contract diagnostic")
	var blocked_path := "res://presets/.phase1-task11-smoke.vfx.json"
	var invalid_save := editor.editor_controller.save_as(blocked_path, true)
	tests.expect_true(not invalid_save.success and not FileAccess.file_exists(blocked_path), "transient-invalid Save As writes no authoring file")
	editor.editor_controller.add_active_layer("GLOW")
	tests.expect_true(not (editor.get_node("Toolbar/UndoButton") as Button).disabled, "an editor data mutation enables Undo")
	editor.editor_controller.undo()
	tests.expect_true(not (editor.get_node("Toolbar/RedoButton") as Button).disabled, "Undo enables Redo through the toolbar state")
	editor.editor_controller.redo()

	# The focused close/diagnostics path does not depend on tab-selection events.
	# Blocking those events avoids exercising PhaseTabs' separate rebuild behavior here.
	editor.get_node("PhaseTabs").set_block_signals(true)

	var close_approved := {"value": false}
	editor.editor_controller.close_approved.connect(func() -> void: close_approved["value"] = true)
	editor._notification(Window.NOTIFICATION_WM_CLOSE_REQUEST)
	var unsaved_dialog := editor.get_node("UnsavedChangesDialog")
	tests.expect_true(not tree.auto_accept_quit and unsaved_dialog.action_name() == "Close", "dirty close disables automatic quit and opens the unsaved decision")
	unsaved_dialog.emit_decision("CANCEL")
	tests.expect_true(not close_approved["value"] and editor.editor_controller.working_preset().get("preset_id") == "utility.close_guard", "cancelled close preserves the active session and does not approve quitting")

	editor.editor_controller.request_transition("Open", func() -> void: pass)
	unsaved_dialog.emit_decision("SAVE")
	var diagnostics := editor.get_node("DiagnosticsPanel") as Control
	var focus_owner := editor.get_viewport().gui_get_focus_owner()
	tests.expect_true(focus_owner != null and diagnostics.is_ancestor_of(focus_owner), "failed transition Save focuses a diagnostics issue inside the real scene tree")

	tree.auto_accept_quit = original_auto_accept_quit
	tree.root.remove_child(editor)
	editor.free()
	var second_editor := packed.instantiate() as VfxEditorMainModel
	tests.expect_true(second_editor != null, "main scene can instantiate a second independent editor root")
	if second_editor != null:
		tree.root.add_child(second_editor)
		tests.expect_true(second_editor.editor_controller != null and second_editor.get_node_or_null("DiagnosticsPanel") != null, "second editor composition initializes its controller and named regions")
		tree.root.remove_child(second_editor)
		second_editor.free()


static func _has_issue(issues: Array[VfxIssue], code: String) -> bool:
	return issues.any(func(issue: VfxIssue) -> bool: return issue.code == code)
