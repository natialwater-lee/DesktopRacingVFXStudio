class_name VfxEditorMain
extends Control

const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")

var editor_controller: VfxEditorControllerModel = VfxEditorControllerModel.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		editor_controller.request_close()
