class_name VfxPresetLibraryEntry
extends RefCounted

var source_path: String
var display_name: String
var preset_id: String
var category: String
var document: VfxPresetDocument
var issues: Array[VfxIssue]


func _init(
	source_path_value: String,
	display_name_value: String = "",
	preset_id_value: String = "",
	category_value: String = "",
	document_value: VfxPresetDocument = null,
	issue_values: Array[VfxIssue] = []
) -> void:
	source_path = source_path_value
	display_name = display_name_value
	preset_id = preset_id_value
	category = category_value
	document = document_value
	issues = issue_values.duplicate()


func is_openable() -> bool:
	return document != null
