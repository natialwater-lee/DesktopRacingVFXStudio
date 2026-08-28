class_name VfxStructureChangeDialog
extends ConfirmationDialog

var _kind := ""
var _label := ""


func request(kind: String, label: String) -> void:
	_kind = kind
	_label = label
	title = "%s will replace %s" % [kind.capitalize(), label]
	dialog_text = "This structural change replaces existing Layer Stack data."
	if is_inside_tree():
		popup_centered()


func kind() -> String:
	return _kind


func label() -> String:
	return _label
