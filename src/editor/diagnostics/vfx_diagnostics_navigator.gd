class_name VfxDiagnosticsNavigator
extends RefCounted


const ROOT_PRESET_POINTERS := [
	"/preset_id",
	"/display_name",
	"/category",
	"/lifecycle",
	"/default_space_mode",
	"/runtime_inputs"
]


func navigate(issue: VfxIssue, preset: Dictionary) -> Dictionary:
	if issue == null or issue.kind == "SCHEMA_CONFIGURATION":
		return {"handled": false}
	var pointer := issue.json_pointer
	if ROOT_PRESET_POINTERS.has(pointer) or _is_root_pointer_child(pointer):
		return {"handled": true, "phase_name": "", "layer_id": "", "json_pointer": pointer}
	var segments := _pointer_segments(pointer)
	if segments.size() < 2 or segments[0] != "phases":
		return {"handled": false}
	var phases: Variant = preset.get("phases")
	if not phases is Dictionary or not phases.has(segments[1]) or not phases[segments[1]] is Dictionary:
		return {"handled": false}
	var phase_name: String = segments[1]
	if segments.size() < 4 or segments[2] != "layers":
		return {"handled": true, "phase_name": phase_name, "layer_id": "", "json_pointer": pointer}
	var layer_index := segments[3].to_int()
	if str(layer_index) != segments[3]:
		return {"handled": false}
	var layers: Variant = phases[phase_name].get("layers")
	if not layers is Array or layer_index < 0 or layer_index >= layers.size() or not layers[layer_index] is Dictionary:
		return {"handled": false}
	var layer_id: Variant = layers[layer_index].get("id")
	if not layer_id is String or layer_id.is_empty():
		return {"handled": false}
	return {"handled": true, "phase_name": phase_name, "layer_id": layer_id, "json_pointer": pointer}


func _is_root_pointer_child(pointer: String) -> bool:
	for root_pointer in ROOT_PRESET_POINTERS:
		if pointer.begins_with("%s/" % root_pointer):
			return true
	return false


func _pointer_segments(pointer: String) -> Array[String]:
	if pointer.is_empty() or not pointer.begins_with("/"):
		return []
	var segments: Array[String] = []
	for raw_segment in pointer.trim_prefix("/").split("/", false):
		segments.append(raw_segment.replace("~1", "/").replace("~0", "~"))
	return segments
