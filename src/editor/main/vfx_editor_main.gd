class_name VfxEditorMain
extends Control

const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")

var editor_controller: VfxEditorControllerModel = VfxEditorControllerModel.new()


func _ready() -> void:
	editor_controller.configure_new_preset_dialog($NewPresetDialog)
	editor_controller.configure_preset_file_dialog($PresetFileDialog)
	editor_controller.configure_overwrite_confirmation_dialog($ConfirmationDialog)
	editor_controller.configure_workspace($PhaseTabs, $LayerStack)
	editor_controller.configure_inspectors($InspectorPanel/InspectorContents/PresetInspector, $InspectorPanel/InspectorContents/LayerInspector)
	$Toolbar/NewButton.pressed.connect(editor_controller._on_new_pressed)
	$Toolbar/OpenButton.pressed.connect(editor_controller._on_open_pressed)
	$Toolbar/SaveButton.pressed.connect(editor_controller._on_save_pressed)
	$Toolbar/SaveAsButton.pressed.connect(editor_controller._on_save_as_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		editor_controller.request_close()
