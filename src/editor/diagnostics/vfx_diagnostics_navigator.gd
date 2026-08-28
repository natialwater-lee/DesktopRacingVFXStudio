class_name VfxDiagnosticsNavigator
extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxSchemaReaderModel := preload("res://src/editor/inspector/vfx_schema_reader.gd")

const ROOT_PRESET_POINTERS := [
	"preset_id",
	"display_name",
	"category",
	"lifecycle",
	"default_space_mode",
	"runtime_inputs"
]
const LAYER_DIRECT_FIELDS := [
	"id",
	"type",
	"importance",
	"blend_mode",
	"render_plane",
	"sort_order",
	"enabled",
	"space_mode",
	"anchors"
]
const TRANSFORM_FIELDS := ["offset", "rotation_degrees", "scale"]

var _registry: VfxSchemaRegistry
var _schema_reader: VfxSchemaReader


func _init() -> void:
	var codec := VfxPresetCodecModel.new()
	_registry = VfxSchemaRegistryModel.new(codec, VfxRuleCatalogModel.new())
	_registry.load(VfxPresetPipelineModel.DEFAULT_SCHEMA_PATH)
	_schema_reader = VfxSchemaReaderModel.new(_registry)


func navigate(issue: VfxIssue, preset: Dictionary) -> Dictionary:
	if issue == null or issue.kind == "SCHEMA_CONFIGURATION":
		return {"handled": false}
	var parsed := _pointer_segments(issue.json_pointer)
	if not parsed.get("valid", false):
		return {"handled": false}
	var segments: Array[String] = parsed["segments"]
	if _is_supported_root_pointer(segments, preset):
		return _route("", "", issue.json_pointer)
	if segments.size() < 2 or segments[0] != "phases":
		return {"handled": false}
	var phases: Variant = preset.get("phases")
	if not phases is Dictionary or not phases.has(segments[1]) or not phases[segments[1]] is Dictionary:
		return {"handled": false}
	var phase_name: String = segments[1]
	var phase_schema := _phase_schema(phase_name)
	if not phase_schema.success:
		return {"handled": false}
	if segments.size() == 2:
		return _route(phase_name, "", issue.json_pointer)
	if segments.size() == 3 and _schema_reader.property_schema(phase_schema.value, segments[2]).success:
		return _route(phase_name, "", issue.json_pointer)
	if segments.size() < 4 or segments[2] != "layers" or not _schema_reader.property_schema(phase_schema.value, "layers").success:
		return {"handled": false}
	var layer_index := _array_index(segments[3])
	if layer_index < 0:
		return {"handled": false}
	var layers: Variant = phases[phase_name].get("layers")
	if not layers is Array or layer_index >= layers.size() or not layers[layer_index] is Dictionary:
		return {"handled": false}
	var layer_id: Variant = layers[layer_index].get("id")
	if not layer_id is String or layer_id.is_empty() or not _is_supported_layer_tail(segments.slice(4), layers[layer_index]):
		return {"handled": false}
	return _route(phase_name, layer_id, issue.json_pointer)


func _route(phase_name: String, layer_id: String, json_pointer: String) -> Dictionary:
	return {"handled": true, "phase_name": phase_name, "layer_id": layer_id, "json_pointer": json_pointer}


func _phase_schema(phase_name: String) -> VfxResult:
	var phases_schema := _schema_reader.property_schema(_schema_reader.root_schema(), "phases")
	if not phases_schema.success:
		return phases_schema
	return _schema_reader.property_schema(phases_schema.value, phase_name)


func _is_supported_root_pointer(segments: Array[String], preset: Dictionary) -> bool:
	if segments.size() == 1:
		return ROOT_PRESET_POINTERS.has(segments[0])
	if segments.size() != 2:
		return false
	if segments[0] == "lifecycle" and segments[1] == "mode":
		return preset.get("lifecycle") is Dictionary
	if segments[0] != "runtime_inputs":
		return false
	var inputs: Variant = preset.get("runtime_inputs")
	var input_index := _array_index(segments[1])
	return inputs is Array and input_index >= 0 and input_index < inputs.size()


func _is_supported_layer_tail(tail: Array, layer: Dictionary) -> bool:
	if tail.is_empty():
		return true
	var field_name: String = tail[0]
	if LAYER_DIRECT_FIELDS.has(field_name):
		return tail.size() == 1 or (field_name == "anchors" and tail.size() == 2 and _value_has_index(layer.get("anchors"), tail[1]))
	if field_name == "parameters":
		return _is_supported_parameter_tail(layer, tail.slice(1))
	if field_name != "transform":
		return false
	if tail.size() == 1:
		return true
	if not TRANSFORM_FIELDS.has(tail[1]):
		return false
	if tail[1] == "rotation_degrees":
		return tail.size() == 2
	return tail.size() == 2 or (tail.size() == 3 and _transform_value_has_index(layer, tail[1], tail[2]))


func _is_supported_parameter_tail(layer: Dictionary, tail: Array) -> bool:
	if tail.is_empty():
		return true
	var layer_type: Variant = layer.get("type")
	if not layer_type is String:
		return false
	var parameter_schema := _schema_reader.layer_parameter_schema(layer_type)
	if not parameter_schema.success:
		return false
	return _schema_path_is_navigable(layer.get("parameters"), parameter_schema.value, tail)


func _schema_path_is_navigable(value: Variant, schema_or_ref: Dictionary, tail: Array) -> bool:
	var resolved := _schema_reader.resolve(schema_or_ref)
	if not resolved.success:
		return false
	var schema: Dictionary = resolved.value
	if tail.is_empty():
		return true
	if schema.get("type") == "object":
		var properties: Variant = schema.get("properties")
		if not properties is Dictionary or not properties.has(tail[0]):
			return false
		if tail.size() == 1:
			return true
		if not value is Dictionary or not value.has(tail[0]) or not properties[tail[0]] is Dictionary:
			return false
		return _schema_path_is_navigable(value[tail[0]], properties[tail[0]], tail.slice(1))
	if schema.get("type") == "array":
		if not _value_has_index(value, tail[0]):
			return false
		var items: Variant = schema.get("items")
		if not items is Dictionary:
			return false
		return _schema_path_is_navigable(value[_array_index(tail[0])], items, tail.slice(1))
	return false


func _transform_value_has_index(layer: Dictionary, field_name: String, index_segment: String) -> bool:
	var transform: Variant = layer.get("transform")
	return transform is Dictionary and _value_has_index(transform.get(field_name), index_segment)


func _value_has_index(value: Variant, index_segment: String) -> bool:
	var index := _array_index(index_segment)
	return value is Array and index >= 0 and index < value.size()


func _array_index(segment: String) -> int:
	if not segment.is_valid_int() or segment.begins_with("-") or str(int(segment)) != segment:
		return -1
	return int(segment)


func _pointer_segments(pointer: String) -> Dictionary:
	if pointer.is_empty() or not pointer.begins_with("/"):
		return {"valid": false}
	var segments: Array[String] = []
	for raw_segment in pointer.trim_prefix("/").split("/", true):
		var decoded := _decode_segment(raw_segment)
		if decoded.is_empty():
			return {"valid": false}
		segments.append(decoded)
	return {"valid": not segments.is_empty(), "segments": segments}


func _decode_segment(raw_segment: String) -> String:
	if raw_segment.is_empty():
		return ""
	var decoded := ""
	var index := 0
	while index < raw_segment.length():
		var character := raw_segment[index]
		if character != "~":
			decoded += character
			index += 1
			continue
		if index + 1 >= raw_segment.length():
			return ""
		var escape_character := raw_segment[index + 1]
		if escape_character == "0":
			decoded += "~"
		elif escape_character == "1":
			decoded += "/"
		else:
			return ""
		index += 2
	return decoded
