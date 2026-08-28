class_name VfxIssue
extends RefCounted

var kind: String
var code: String
var message: String
var json_pointer: String
var source_path: String
var line: int
var column: int
var severity: String


func _init(
	kind_value: String,
	code_value: String,
	message_value: String,
	json_pointer_value: String = "",
	source_path_value: String = "",
	line_value: int = -1,
	column_value: int = -1,
	severity: String = "ERROR"
) -> void:
	kind = kind_value
	code = code_value
	message = message_value
	json_pointer = json_pointer_value
	source_path = source_path_value
	line = line_value
	column = column_value
	self.severity = severity
