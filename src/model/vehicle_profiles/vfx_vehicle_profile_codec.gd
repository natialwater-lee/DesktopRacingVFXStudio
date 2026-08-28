class_name VfxVehicleProfileCodec
extends RefCounted

var _codec: RefCounted


func _init(codec: RefCounted = null) -> void:
	_codec = codec if codec != null else VfxPresetCodec.new()


func decode_text(text: String, source_path: String = "") -> VfxResult:
	return _codec.decode_text(text, source_path)


func decode_file(path: String) -> VfxResult:
	return _codec.decode_file(path)


func encode(value: Variant) -> VfxResult:
	return _codec.encode(value)


func write_file(path: String, value: Variant) -> VfxResult:
	return _codec.write_file(path, value)
