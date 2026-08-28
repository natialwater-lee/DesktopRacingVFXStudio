class_name VfxDiagnosticsNavigator
extends RefCounted


const ROOT_PRESET_POINTERS := [
	"preset_id",
	"display_name",
	"category",
	"lifecycle",
	"default_space_mode",
	"runtime_inputs"
]
const PHASE_POINTER_CHILDREN := ["layers", "duration_seconds"]
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


func navigate(issue: VfxIssue, preset: Dictionary) -> Dictionary:
	if issue == null or issue.kind == "SCHEMA_CONFIGURATION":
		return {"handled": false}
	var parsed := _pointer_segments(issue.json_pointer)
	if not parsed.get("valid", false):
		return {"handled": false}
	var segments: Array[String] = parsed["segments"]
	if segments.size() == 1 and ROOT_PRESET_POINTERS.has(segments[0]):
		return _route("", "", issue.json_pointer)
	if segments.size() < 2 or segments[0] != "phases":
		return {"handled": false}
	var phases: Variant = preset.get("phases")
	if not phases is Dictionary or not phases.has(segments[1]) or not phases[segments[1]] is Dictionary:
		return {"handled": false}
	var phase_name: String = segments[1]
	if segments.size() == 2:
		return _route(phase_name, "", issue.json_pointer)
	if segments.size() == 3 and PHASE_POINTER_CHILDREN.has(segments[2]):
		return _route(phase_name, "", issue.json_pointer)
	if segments.size() < 4 or segments[2] != "layers":
		return {"handled": false}
	var layer_index := _array_index(segments[3])
	if layer_index < 0:
		return {"handled": false}
	var layers: Variant = phases[phase_name].get("layers")
	if not layers is Array or layer_index >= layers.size() or not layers[layer_index] is Dictionary:
		return {"handled": false}
	var layer_id: Variant = layers[layer_index].get("id")
	if not layer_id is String or layer_id.is_empty() or not _is_supported_layer_tail(segments.slice(4)):
		return {"handled": false}
	return _route(phase_name, layer_id, issue.json_pointer)


func _route(phase_name: String, layer_id: String, json_pointer: String) -> Dictionary:
	return {"handled": true, "phase_name": phase_name, "layer_id": layer_id, "json_pointer": json_pointer}


func _is_supported_layer_tail(tail: Array) -> bool:
	if tail.is_empty():
		return true
	var field_name: String = tail[0]
	if LAYER_DIRECT_FIELDS.has(field_name):
		return tail.size() == 1 or (field_name == "anchors" and tail.size() == 2 and _array_index(tail[1]) >= 0)
	if field_name == "parameters":
		return tail.size() >= 2
	if field_name != "transform":
		return false
	if tail.size() == 1:
		return true
	if not TRANSFORM_FIELDS.has(tail[1]):
		return false
	if tail[1] == "rotation_degrees":
		return tail.size() == 2
	return tail.size() == 2 or (tail.size() == 3 and _array_index(tail[2]) >= 0)


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
