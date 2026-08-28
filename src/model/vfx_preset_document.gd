class_name VfxPresetDocument
extends RefCounted

var source_path: String
var raw_data: Variant
var normalized_data: Dictionary


func _init(source_path_value: String, raw_value: Variant, normalized_value: Dictionary) -> void:
	source_path = source_path_value
	raw_data = _deep_copy(raw_value)
	normalized_data = normalized_value.duplicate(true)


static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
