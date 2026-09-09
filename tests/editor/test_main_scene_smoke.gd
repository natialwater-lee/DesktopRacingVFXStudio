extends RefCounted

const VfxEditorMainModel := preload("res://src/editor/main/vfx_editor_main.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")

const INVALID_LIBRARY_PATH := "res://presets/.phase1-task11-review-invalid.vfx.json"
const WORKFLOW_SAVE_PATH := "res://presets/.phase1-task11-review-workflow.vfx.json"


static func run(tests: TestAssert) -> void:
	var packed := load("res://src/editor/main/vfx_editor_main.tscn") as PackedScene
	tests.expect_true(packed != null, "editor scene loads")
	if packed == null:
		return

	var editor := packed.instantiate() as VfxEditorMainModel
	tests.expect_true(editor != null, "editor scene instantiates its typed root")
	if editor == null:
		return
	var editor_layout := editor.get_node_or_null("EditorLayout") as VSplitContainer
	var authoring_split := editor.get_node_or_null("EditorLayout/AuthoringSplit") as HSplitContainer
	var center_inspector_split := editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit") as HSplitContainer
	var layout_library_panel := editor.get_node_or_null("EditorLayout/AuthoringSplit/LibraryPanel") as Control
	var center_workspace := editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace") as VBoxContainer
	var inspector_panel_layout := editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/InspectorPanel") as ScrollContainer
	var preview_host := editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PreviewHost") as PanelContainer
	var diagnostics_panel_layout := editor.get_node_or_null("EditorLayout/DiagnosticsPanel") as ScrollContainer
	tests.expect_true(editor_layout != null and authoring_split != null, "main scene exposes nested vertical and horizontal resizable splits")
	tests.expect_true(center_inspector_split != null and authoring_split.get_child_count() == 2 and center_inspector_split.get_child_count() == 2, "nested HSplitContainers provide one drag boundary for Library and one for Inspector")
	tests.expect_true(layout_library_panel != null and center_workspace != null and inspector_panel_layout != null, "authoring split owns Library, flexible Center, and Inspector regions")
	tests.expect_true(preview_host != null and preview_host.get_node_or_null("PreviewPlaceholder") is Panel, "Center exposes an empty Phase 2 PreviewHost boundary")
	tests.expect_true(diagnostics_panel_layout != null and diagnostics_panel_layout.custom_minimum_size.y <= 140.0, "Diagnostics starts as a compact resizable lower region")
	if layout_library_panel != null and center_workspace != null and inspector_panel_layout != null:
		var minimum_width_sum := layout_library_panel.custom_minimum_size.x + center_workspace.custom_minimum_size.x + inspector_panel_layout.custom_minimum_size.x
		tests.expect_true(minimum_width_sum <= 960.0, "three-column minimum widths remain usable at 1152px")
		tests.expect_true(center_workspace.size_flags_stretch_ratio > layout_library_panel.size_flags_stretch_ratio and center_workspace.size_flags_stretch_ratio > inspector_panel_layout.size_flags_stretch_ratio, "Center receives the flexible share for the future PreviewHost")
		tests.expect_true(editor.get_node_or_null("EditorLayout/AuthoringSplit/LibraryPanel/RowsScroll") is ScrollContainer, "Library rows scroll without forcing long Preset text wider")
	_remove_test_file(INVALID_LIBRARY_PATH)
	_remove_test_file(WORKFLOW_SAVE_PATH)
	var invalid_fixture := VfxPresetCodecModel.new().write_text_file(INVALID_LIBRARY_PATH, "{\"schema_version\": 1}")
	tests.expect_true(invalid_fixture.success, "scene library fixture writes one invalid authoring file")
	var tree := Engine.get_main_loop() as SceneTree
	var original_auto_accept_quit := tree.auto_accept_quit
	tree.root.add_child(editor)
	tests.expect_true(editor.editor_controller != null, "editor assigns its typed controller")
	tests.expect_true(editor.get_node_or_null("Toolbar") != null, "toolbar exists")
	tests.expect_true(editor.get_node_or_null("EditorLayout/AuthoringSplit/LibraryPanel") != null, "library region exists")
	tests.expect_true(editor.get_node_or_null("EditorLayout/AuthoringSplit/LibraryPanel/Search") is LineEdit, "Library exposes its concrete search field")
	tests.expect_true(editor.get_node_or_null("EditorLayout/AuthoringSplit/LibraryPanel/CategoryFilter") is OptionButton, "Library exposes its Schema-derived category filter")
	tests.expect_true(editor.get_node_or_null("EditorLayout/AuthoringSplit/LibraryPanel/RowsScroll/Rows") is VBoxContainer, "Library exposes its concrete scrollable result rows")
	tests.expect_true(editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PhaseTabs") != null, "phase tabs region exists")
	tests.expect_true(editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/LayerStack") != null, "layer stack region exists")
	tests.expect_true(editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/LayerStack/Rows/AddControls/AddLayerButton") is Button, "Layer Stack scene creates its concrete Add control")
	tests.expect_true(editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/InspectorPanel") != null, "inspector region exists")
	tests.expect_true(editor.get_node_or_null("EditorLayout/DiagnosticsPanel") != null, "diagnostics region exists")
	tests.expect_true(editor.get_node("EditorLayout/AuthoringSplit/CenterInspectorSplit/InspectorPanel") is ScrollContainer, "Inspector is a scrollable authoring region at normal launch")
	tests.expect_true(editor.get_node("EditorLayout/DiagnosticsPanel") is ScrollContainer, "Diagnostics is a scrollable authoring region at normal launch")
	var inspector_panel := editor.get_node("EditorLayout/AuthoringSplit/CenterInspectorSplit/InspectorPanel") as ScrollContainer
	tests.expect_true(inspector_panel.follow_focus, "Inspector scroll follows focused authoring controls")
	tests.expect_true(int(ProjectSettings.get_setting("display/window/size/initial_width", 0)) >= 1024 and int(ProjectSettings.get_setting("display/window/size/initial_height", 0)) >= 720, "project declares a sensible initial editor window size")
	tests.expect_true(int(ProjectSettings.get_setting("display/window/size/min_width", 0)) >= 1024 and int(ProjectSettings.get_setting("display/window/size/min_height", 0)) >= 720, "project declares a non-clipping minimum editor window size")
	tests.expect_true(editor.get_node("Toolbar/NewButton").is_connected("pressed", Callable(editor.editor_controller, "_on_new_pressed")), "New button opens the schema-derived new dialog")
	tests.expect_true(editor.get_node("Toolbar/OpenButton").is_connected("pressed", Callable(editor.editor_controller, "_on_open_pressed")), "Open button starts the authoring-root file selection flow")
	tests.expect_true(editor.get_node("Toolbar/SaveButton").is_connected("pressed", Callable(editor.editor_controller, "_on_save_pressed")), "Save button uses the valid-only persistence flow")
	tests.expect_true(editor.get_node("Toolbar/SaveAsButton").is_connected("pressed", Callable(editor.editor_controller, "_on_save_as_pressed")), "Save As button starts the authoring-root destination flow")
	tests.expect_true(editor.get_node("Toolbar/UndoButton").is_connected("pressed", Callable(editor.editor_controller, "_on_undo_pressed")), "Undo button is connected through the controller")
	tests.expect_true(editor.get_node("Toolbar/RedoButton").is_connected("pressed", Callable(editor.editor_controller, "_on_redo_pressed")), "Redo button is connected through the controller")
	tests.expect_true(editor.get_node("Toolbar/ValidateButton").is_connected("pressed", Callable(editor.editor_controller, "_on_validate_pressed")), "Validate button is connected through the controller")
	tests.expect_true(editor.get_node("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/LayerStack").add_layer_requested.is_connected(Callable(editor.editor_controller, "_on_add_layer_requested")), "Layer Stack Add signal is connected to the controller")
	var library_panel := editor.get_node("EditorLayout/AuthoringSplit/LibraryPanel") as Node
	tests.expect_true(library_panel.is_connected("filter_changed", Callable(editor.editor_controller, "_on_library_filter_changed")), "Library search/category signal is connected through the controller")
	tests.expect_true(library_panel.is_connected("preset_open_requested", Callable(editor.editor_controller, "_on_library_preset_open_requested")), "valid Library row signal opens through the controller")
	tests.expect_true(library_panel.is_connected("invalid_entry_selected", Callable(editor.editor_controller, "_on_library_invalid_entry_selected")), "invalid Library row signal routes to diagnostics")
	tests.expect_true(editor.editor_controller.contract_services_ready(), "controller composes initialized Schema Registry and Contract Pipeline")
	tests.expect_true((editor.get_node("Toolbar/SaveButton") as Button).disabled, "Save is disabled before an existing document has a source path")
	tests.expect_true((editor.get_node("Toolbar/UndoButton") as Button).disabled and (editor.get_node("Toolbar/RedoButton") as Button).disabled, "history toolbar starts disabled without an edit session")
	tests.expect_true((editor.get_node("Toolbar/ValidateButton") as Button).disabled, "Validate is disabled without an edit session")
	tests.expect_true((editor.get_node("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PhaseTabs") as Node).has_signal("duration_commit_requested"), "Phase Tabs expose a committed duration edit signal for Schema-timed phases")
	var library_rows := editor.get_node("EditorLayout/AuthoringSplit/LibraryPanel/RowsScroll/Rows") as VBoxContainer
	tests.expect_true(library_rows.get_child_count() >= 3, "Library displays valid examples plus the invalid fixture")
	var valid_library_row := library_rows.get_child(0) as Button
	tests.expect_true(valid_library_row.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and valid_library_row.tooltip_text == valid_library_row.text, "Library rows trim long text while retaining the complete tooltip")
	valid_library_row.emit_signal("pressed")
	tests.expect_true(not editor.editor_controller.working_preset().is_empty(), "pressing a valid Library row opens its Contract document")
	var search := editor.get_node("EditorLayout/AuthoringSplit/LibraryPanel/Search") as LineEdit
	search.text = "zero"
	search.emit_signal("text_changed", search.text)
	tests.expect_true(library_rows.get_child_count() == 1 and (library_rows.get_child(0) as Button).text.contains("talent.zero_zone"), "Library search filters through the existing Library model")
	search.text = ""
	search.emit_signal("text_changed", search.text)
	var category_filter := editor.get_node("EditorLayout/AuthoringSplit/LibraryPanel/CategoryFilter") as OptionButton
	var race_talent_index := -1
	for index in category_filter.item_count:
		if category_filter.get_item_text(index) == "RACE_TALENT":
			race_talent_index = index
			break
	tests.expect_true(race_talent_index >= 0, "Library category filter is populated from the Schema category enum")
	if race_talent_index >= 0:
		category_filter.select(race_talent_index)
		category_filter.emit_signal("item_selected", race_talent_index)
		var talent_rows: Array[String] = []
		for row in library_rows.get_children():
			talent_rows.append((row as Button).text)
		tests.expect_true(talent_rows.size() == 3 and talent_rows.all(func(text: String): return text.contains("RACE_TALENT")) and talent_rows.any(func(text: String): return text.contains("talent.zero_zone")) and talent_rows.any(func(text: String): return text.contains("talent.photosynthesis")) and talent_rows.any(func(text: String): return text.contains("talent.solo_run")), "Library category filter includes every saved Race Talent, including Solo Run")
		category_filter.select(0)
		category_filter.emit_signal("item_selected", 0)
	var invalid_library_row: Button = null
	for row in library_rows.get_children():
		if row is Button and (row as Button).text.contains(INVALID_LIBRARY_PATH):
			invalid_library_row = row
			break
	tests.expect_true(invalid_library_row != null, "Library displays an invalid row with its source path")
	if invalid_library_row != null:
		invalid_library_row.emit_signal("pressed")
		tests.expect_true(not editor.editor_controller.current_issues().is_empty(), "selecting an invalid Library row displays its Contract diagnostics")

	var focus_created := editor.editor_controller.create_new_preset("utility.diagnostic_focus", "Diagnostic Focus", "UTILITY", "START_LOOP_END", "WORLD_AREA")
	tests.expect_true(focus_created.success, "diagnostic focus fixture creates a multi-phase Preset")
	editor.editor_controller.select_phase("start")
	editor.editor_controller.add_active_layer("GLOW")
	var focus_layer_id: String = editor.editor_controller.working_preset()["phases"]["start"]["layers"][0]["id"]
	var diagnostics_panel := editor.get_node("EditorLayout/DiagnosticsPanel") as VfxDiagnosticsPanel
	var display_name := editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/InspectorPanel/InspectorContents/PresetInspector/DisplayName") as LineEdit
	diagnostics_panel.set_issues([VfxIssue.new("PRESET_VALIDATION", "required", "missing", "/display_name")])
	diagnostics_panel.activate_issue(0)
	tests.expect_true(editor.get_viewport().gui_get_focus_owner() == display_name, "root diagnostic activation focuses the matching Preset editable field")
	diagnostics_panel.set_issues([VfxIssue.new("PRESET_VALIDATION", "minimum", "invalid", "/phases/start/duration_seconds")])
	diagnostics_panel.activate_issue(0)
	var diagnostic_duration := editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PhaseTabs/Start/DurationSeconds") as SpinBox
	tests.expect_true(diagnostic_duration != null and editor.get_viewport().gui_get_focus_owner() == diagnostic_duration.get_line_edit(), "phase duration diagnostic activation focuses its editable SpinBox field")
	diagnostics_panel.set_issues([VfxIssue.new("PRESET_VALIDATION", "enum", "invalid", "/phases/start/layers/0/blend_mode")])
	diagnostics_panel.activate_issue(0)
	var blend_mode := editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/InspectorPanel/InspectorContents/LayerInspector/BlendMode") as OptionButton
	tests.expect_true(editor.get_viewport().gui_get_focus_owner() == blend_mode, "Layer common-field diagnostic activation focuses the matching editable control")
	diagnostics_panel.set_issues([VfxIssue.new("PRESET_VALIDATION", "minimum", "invalid", "/phases/start/layers/0/parameters/radius")])
	inspector_panel.scroll_vertical = 0
	diagnostics_panel.activate_issue(0)
	var radius := editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/InspectorPanel/InspectorContents/LayerInspector/Parameters/radius/Input") as SpinBox
	tests.expect_true(radius != null and editor.get_viewport().gui_get_focus_owner() == radius.get_line_edit(), "nested Layer parameter diagnostic activation focuses the Schema-owned editable control")
	tests.expect_true(inspector_panel.scroll_vertical > 0, "nested parameter diagnostic focus scrolls its editable field into the Inspector viewport")
	var focus_before_unsupported := editor.get_viewport().gui_get_focus_owner()
	diagnostics_panel.set_issues([VfxIssue.new("PRESET_VALIDATION", "additionalProperties", "unexpected", "/phases/start/layers/0/parameters/not_declared")])
	diagnostics_panel.activate_issue(0)
	tests.expect_true(editor.get_viewport().gui_get_focus_owner() == focus_before_unsupported, "unsupported diagnostic targets remain visible without guessing a focus destination")

	var created := editor.editor_controller.create_new_preset("utility.close_guard", "Close Guard", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(created.success, "scene close guard fixture creates a dirty in-memory Preset")
	tests.expect_true((editor.get_node("Toolbar/SaveButton") as Button).disabled and not (editor.get_node("Toolbar/SaveAsButton") as Button).disabled, "new unsaved Preset enables only Save As")
	tests.expect_true(_has_issue(editor.editor_controller.current_issues(), "preset_has_no_layers"), "new session exposes its transient no-layer Contract diagnostic")
	var blocked_path := "res://presets/.phase1-task11-smoke.vfx.json"
	var invalid_save := editor.editor_controller.save_as(blocked_path, true)
	tests.expect_true(not invalid_save.success and not FileAccess.file_exists(blocked_path), "transient-invalid Save As writes no authoring file")
	editor.editor_controller.add_active_layer("GLOW")
	tests.expect_true(not (editor.get_node("Toolbar/UndoButton") as Button).disabled, "an editor data mutation enables Undo")
	var workflow_layer_id: String = editor.editor_controller.working_preset()["phases"]["one_shot"]["layers"][0]["id"]
	editor.editor_controller.select_layer(workflow_layer_id)
	editor.editor_controller.undo()
	tests.expect_true(not (editor.get_node("Toolbar/RedoButton") as Button).disabled, "Undo enables Redo through the toolbar state")
	editor.editor_controller.redo()
	tests.expect_true(editor.editor_controller.commit_preset_field("/display_name", "Close Guard Edited"), "common Preset field edit joins the controller history flow")
	editor.editor_controller.undo()
	tests.expect_true(editor.editor_controller.working_preset().get("display_name") == "Close Guard", "Undo restores the common Preset field")
	editor.editor_controller.redo()
	tests.expect_true(editor.editor_controller.working_preset().get("display_name") == "Close Guard Edited", "Redo reapplies the common Preset field")
	editor.editor_controller.select_layer(workflow_layer_id)
	var saved := editor.editor_controller.save_as(WORKFLOW_SAVE_PATH, true)
	tests.expect_true(saved.success and FileAccess.file_exists(WORKFLOW_SAVE_PATH), "valid Save As writes only the requested authoring-root Preset")
	tests.expect_true(not (editor.get_node("Toolbar/SaveButton") as Button).disabled, "successful Save As reconciles the session before enabling Save")
	tests.expect_true(editor.editor_controller.selected_layer_id() == workflow_layer_id and editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/LayerStack/Rows") != null, "successful Save As reconciles the selected Layer and workspace before toolbar refresh")
	var saved_library_row: Button = _find_library_row(library_rows, "utility.close_guard")
	tests.expect_true(saved_library_row != null, "successful Save As refreshes the visible Library with its new row")
	editor.editor_controller.commit_preset_field("/display_name", "Close Guard Saved Again")
	var saved_again := editor.editor_controller.save()
	tests.expect_true(saved_again.success, "later save succeeds for the existing authoring document")
	saved_library_row = _find_library_row(library_rows, "utility.close_guard")
	if saved_library_row != null:
		saved_library_row.emit_signal("pressed")
		tests.expect_true(editor.editor_controller.working_preset().get("display_name") == "Close Guard Saved Again", "Library refresh replaces its cached document after later save")
	var reopened := editor.editor_controller.open_path(WORKFLOW_SAVE_PATH)
	tests.expect_true(reopened.success and editor.editor_controller.working_preset().get("display_name") == "Close Guard Saved Again", "workflow reopens the saved Contract document")
	editor.editor_controller.commit_preset_field("/display_name", "Discarded Change")
	editor.editor_controller.request_transition("Open", func() -> void: editor.editor_controller.open_path(WORKFLOW_SAVE_PATH))
	(editor.get_node("UnsavedChangesDialog") as Node).emit_decision("DISCARD")
	tests.expect_true(editor.editor_controller.working_preset().get("display_name") == "Close Guard Saved Again", "discarding a subsequent unsaved change restores the reopened saved document")

	var loop_created := editor.editor_controller.create_new_preset("utility.duration", "Duration", "UTILITY", "START_LOOP_END", "WORLD_AREA")
	tests.expect_true(loop_created.success, "duration smoke fixture creates a multi-phase Skeleton")
	var start_duration := editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PhaseTabs/Start/DurationSeconds") as SpinBox
	tests.expect_true(start_duration != null and editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PhaseTabs/Loop/DurationSeconds") == null, "only Schema-timed phases expose duration controls")
	if start_duration != null:
		tests.expect_true(is_equal_approx(start_duration.min_value, 0.001) and start_duration.max_value > 250.0, "duration SpinBox derives its unbounded numeric range from the resolved Schema")
		var duration_line_edit := start_duration.get_line_edit()
		duration_line_edit.grab_focus()
		start_duration.value = 0.5
		start_duration.value = 0.75
		tests.expect_true(not is_equal_approx(float(editor.editor_controller.working_preset()["phases"]["start"]["duration_seconds"]), 0.75), "duration edits do not snapshot or rebuild while the SpinBox value changes")
		var duration_focus_target := editor.get_node("Toolbar/ValidateButton") as Button
		duration_focus_target.grab_focus()
		tests.expect_true(editor.get_viewport().gui_get_focus_owner() == duration_focus_target and is_instance_valid(start_duration), "real LineEdit focus transfer commits without rebuilding the active Phase tabs")
		tests.expect_true(is_equal_approx(float(editor.editor_controller.working_preset()["phases"]["start"]["duration_seconds"]), 0.75), "real LineEdit focus exit commits one controller mutation")
		editor.editor_controller.undo()
		tests.expect_true(not is_equal_approx(float(editor.editor_controller.working_preset()["phases"]["start"]["duration_seconds"]), 0.75), "duration commit is restored by Undo")
		tests.expect_true(not editor.editor_controller.can_undo(), "SpinBox and LineEdit focus exits create one duration history action")
		editor.editor_controller.redo()
		tests.expect_true(is_equal_approx(float(editor.editor_controller.working_preset()["phases"]["start"]["duration_seconds"]), 0.75), "duration commit reapplies through Redo")
		start_duration = editor.get_node_or_null("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PhaseTabs/Start/DurationSeconds") as SpinBox
		duration_line_edit = start_duration.get_line_edit()
		duration_line_edit.grab_focus()
		start_duration.value = 250.0
		duration_line_edit.emit_signal("text_submitted", "250")
		tests.expect_true(is_equal_approx(float(editor.editor_controller.working_preset()["phases"]["start"]["duration_seconds"]), 250.0), "duration Enter commit accepts values above the old implicit maximum")
		tests.expect_true(start_duration.has_focus() or start_duration.get_line_edit().has_focus(), "duration Enter commit preserves an editing focus target")
		editor.editor_controller.undo()
		tests.expect_true(is_equal_approx(float(editor.editor_controller.working_preset()["phases"]["start"]["duration_seconds"]), 0.75) and editor.editor_controller.can_redo(), "immediate Undo while duration LineEdit owns focus restores exactly and preserves Redo")
		editor.editor_controller.redo()
		tests.expect_true(is_equal_approx(float(editor.editor_controller.working_preset()["phases"]["start"]["duration_seconds"]), 250.0) and not editor.editor_controller.can_redo(), "Redo remains valid after focus-owned duration Undo")
		duration_focus_target.grab_focus()
		editor.editor_controller.undo()
		tests.expect_true(is_equal_approx(float(editor.editor_controller.working_preset()["phases"]["start"]["duration_seconds"]), 0.75), "duration duplicate suppression keeps Enter and later focus exit as one action")

	# The focused close/diagnostics path does not depend on tab-selection events.
	# Blocking those events avoids exercising PhaseTabs' separate rebuild behavior here.
	editor.get_node("EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PhaseTabs").set_block_signals(true)

	var close_approved := {"value": false}
	editor.editor_controller.close_approved.connect(func() -> void: close_approved["value"] = true)
	editor._notification(Window.NOTIFICATION_WM_CLOSE_REQUEST)
	var unsaved_dialog := editor.get_node("UnsavedChangesDialog")
	tests.expect_true(not tree.auto_accept_quit and unsaved_dialog.action_name() == "Close", "dirty close disables automatic quit and opens the unsaved decision")
	unsaved_dialog.emit_decision("CANCEL")
	tests.expect_true(not close_approved["value"] and editor.editor_controller.working_preset().get("preset_id") == "utility.duration", "cancelled close preserves the active session and does not approve quitting")

	editor.editor_controller.request_transition("Open", func() -> void: pass)
	unsaved_dialog.emit_decision("SAVE")
	var diagnostics := editor.get_node("EditorLayout/DiagnosticsPanel") as Control
	var focus_owner := editor.get_viewport().gui_get_focus_owner()
	tests.expect_true(focus_owner != null and diagnostics.is_ancestor_of(focus_owner), "failed transition Save focuses a diagnostics issue inside the real scene tree")

	tree.auto_accept_quit = original_auto_accept_quit
	tree.root.remove_child(editor)
	editor.free()
	_restore_invalid_library_fixture()
	_remove_test_file(WORKFLOW_SAVE_PATH)
	var second_editor := packed.instantiate() as VfxEditorMainModel
	tests.expect_true(second_editor != null, "main scene can instantiate a second independent editor root")
	if second_editor != null:
		tree.root.add_child(second_editor)
		tests.expect_true(second_editor.editor_controller != null and second_editor.get_node_or_null("EditorLayout/DiagnosticsPanel") != null, "second editor composition initializes its controller and named regions")
		tree.root.remove_child(second_editor)
		second_editor.free()


static func _has_issue(issues: Array[VfxIssue], code: String) -> bool:
	return issues.any(func(issue: VfxIssue) -> bool: return issue.code == code)


static func _remove_test_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _restore_invalid_library_fixture() -> void:
	VfxPresetCodecModel.new().write_text_file(INVALID_LIBRARY_PATH, "{\"schema_version\": 1}")


static func _find_library_row(rows: VBoxContainer, text_fragment: String) -> Button:
	for row in rows.get_children():
		if row is Button and (row as Button).text.contains(text_fragment):
			return row
	return null
