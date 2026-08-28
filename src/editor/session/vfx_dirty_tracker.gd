class_name VfxDirtyTracker
extends RefCounted

var _codec: RefCounted


func _init(codec: RefCounted) -> void:
	_codec = codec


func is_dirty(working_data: Dictionary, saved_baseline: Dictionary) -> bool:
	var working_encoded: Variant = _codec.encode(working_data)
	if not working_encoded.success:
		return true
	var baseline_encoded: Variant = _codec.encode(saved_baseline)
	if not baseline_encoded.success:
		return true
	return working_encoded.value != baseline_encoded.value
