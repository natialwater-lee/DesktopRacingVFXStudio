class_name VfxVehicleProfileDocument
extends RefCounted

var source_path: String
var _data: Dictionary


func _init(source_path_value: String, data_value: Dictionary) -> void:
	source_path = source_path_value
	_data = data_value.duplicate(true)


func data() -> Dictionary:
	return _data.duplicate(true)
