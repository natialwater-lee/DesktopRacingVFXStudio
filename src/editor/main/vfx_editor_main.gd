class_name VfxEditorMain
extends Control

const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")
const VfxPreviewWorkspaceModel := preload("res://src/preview/vfx_preview_workspace.gd")

var editor_controller: VfxEditorControllerModel = VfxEditorControllerModel.new()


func _ready() -> void:
	get_tree().auto_accept_quit = false
	editor_controller.configure_toolbar($Toolbar)
	editor_controller.configure_library_panel($EditorLayout/AuthoringSplit/LibraryPanel)
	editor_controller.configure_new_preset_dialog($NewPresetDialog)
	editor_controller.configure_preset_file_dialog($PresetFileDialog)
	editor_controller.configure_overwrite_confirmation_dialog($ConfirmationDialog)
	editor_controller.configure_transition_dialogs($UnsavedChangesDialog, $StructureChangeDialog)
	editor_controller.configure_diagnostics_panel($EditorLayout/DiagnosticsPanel)
	editor_controller.configure_workspace($EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PhaseTabs, $EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/LayerStack)
	editor_controller.configure_inspectors($EditorLayout/AuthoringSplit/CenterInspectorSplit/InspectorPanel/InspectorContents/PresetInspector, $EditorLayout/AuthoringSplit/CenterInspectorSplit/InspectorPanel/InspectorContents/LayerInspector)
	_install_vehicle_preview()
	$Toolbar/NewButton.pressed.connect(editor_controller._on_new_pressed)
	$Toolbar/OpenButton.pressed.connect(editor_controller._on_open_pressed)
	$Toolbar/SaveButton.pressed.connect(editor_controller._on_save_pressed)
	$Toolbar/SaveAsButton.pressed.connect(editor_controller._on_save_as_pressed)
	$Toolbar/UndoButton.pressed.connect(editor_controller._on_undo_pressed)
	$Toolbar/RedoButton.pressed.connect(editor_controller._on_redo_pressed)
	$Toolbar/ValidateButton.pressed.connect(editor_controller._on_validate_pressed)
	editor_controller.close_approved.connect(_on_close_approved)


func _install_vehicle_preview() -> void:
	var preview_host := $EditorLayout/AuthoringSplit/CenterInspectorSplit/CenterWorkspace/PreviewHost
	var placeholder := preview_host.get_node_or_null("PreviewPlaceholder")
	if placeholder != null:
		preview_host.remove_child(placeholder)
		placeholder.free()
	var workspace := VfxPreviewWorkspaceModel.new()
	preview_host.add_child(workspace)
	editor_controller.configure_preview(workspace)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		editor_controller.request_close()


func _on_close_approved() -> void:
	get_tree().quit()
