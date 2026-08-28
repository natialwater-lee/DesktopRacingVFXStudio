class_name VfxUnsavedChangesDialog
extends ConfirmationDialog

signal decision(decision_name: String)

const SAVE := "SAVE"
const DISCARD := "DISCARD"
const CANCEL := "CANCEL"

var _action_name := ""
var _discard_button: Button


func request(action_name: String) -> void:
	_action_name = action_name
	title = "%s with unsaved changes?" % action_name
	if is_inside_tree():
		popup_centered()


func action_name() -> String:
	return _action_name


func emit_decision(decision_name: String) -> void:
	if [SAVE, DISCARD, CANCEL].has(decision_name):
		decision.emit(decision_name)


func _ready() -> void:
	get_ok_button().text = "Save"
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)
	if not canceled.is_connected(_on_canceled):
		canceled.connect(_on_canceled)
	if _discard_button == null:
		_discard_button = add_button("Discard", false, "discard")
		_discard_button.pressed.connect(_on_discard_pressed)


func _on_confirmed() -> void:
	emit_decision(SAVE)


func _on_canceled() -> void:
	emit_decision(CANCEL)


func _on_discard_pressed() -> void:
	emit_decision(DISCARD)
