extends RefCounted
## Explicit capability gate. Old consumers MUST NOT silently fall back to v1/v2.
const LEGACY_TYPES := ["PARTICLE", "TEXTURED_SPRITE", "TRAIL", "GLOW", "RING", "SHIELD"]

static func read(data: Dictionary, versions: Array = [1, 2], types: Array = LEGACY_TYPES, capabilities: Array = ["CURVE_FLOW_F1"]) -> VfxResult:
	var raw_version: Variant = data.get("runtime_definition_version")
	if not (raw_version is int or raw_version is float) or not is_finite(float(raw_version)) or float(raw_version) != floorf(float(raw_version)): return _failure("Invalid Runtime Definition version.")
	var version := int(raw_version)
	if not version in versions or not version in [1, 2, 3]: return _failure("Unsupported Runtime Definition version.")
	if not data.get("phases") is Array or not data.get("preset") is Dictionary: return _failure("Invalid runtime structure.")
	var required: Variant = data.get("required_capabilities", [])
	if version == 3:
		if not required is Array or required.is_empty(): return _failure("Missing v3 capabilities.")
		for cap in required:
			if not cap in capabilities or not cap in ["CURVE_FLOW_F1", "CURVE_FLOW_STATIC_RIBBON_F2"]: return _failure("Unsupported v3 capability/profile.")
	var used: Array = []
	if version == 3:
		var coordinates: Variant = data.get("coordinate_contract")
		if not coordinates is Dictionary or coordinates.get("front_axis") != "-Y" or coordinates.get("origin") != "CENTER": return _failure("Unsupported v3 coordinates.")
		var size: Variant = coordinates.get("vehicle_source_canvas_size_px")
		if not size is Array or size.size() != 2 or size[0] != 256 or size[1] != 512: return _failure("Unsupported v3 canvas size.")
	var meta: Dictionary = data.preset
	if not data.get("runtime_inputs", []) is Array or not data.get("runtime_modulation_sources", []) is Array: return _failure("Invalid runtime input/source containers.")
	var source := {"schema_version": 1, "preset_id": meta.get("preset_id"), "display_name": meta.get("display_name"), "category": meta.get("category"), "default_space_mode": meta.get("default_space_mode"), "lifecycle": {"mode": meta.get("lifecycle_mode")}, "runtime_inputs": [], "phases": {}}
	for input in data.get("runtime_inputs", []):
		if not input is Dictionary or not input.get("name") is String: return _failure("Invalid runtime input.")
		source.runtime_inputs.append(input.name)
	if data.has("runtime_modulation_sources"): source.runtime_modulation_sources = data.runtime_modulation_sources.duplicate(true)
	for phase in data.phases:
		if not phase is Dictionary or not phase.get("name") is String or not phase.get("layers") is Array: return _failure("Invalid phase.")
		if source.phases.has(phase.name): return _failure("Duplicate phase.")
		for layer in phase.layers:
			if not layer is Dictionary or not layer.get("type") in types: return _failure("Unsupported layer type.")
			if layer.type == "CURVE_FLOW" and version != 3: return _failure("CURVE_FLOW requires v3; downgrade is forbidden.")
			if layer.type == "CURVE_FLOW":
				if not layer.get("parameters") is Dictionary: return _failure("Invalid curve parameters.")
				var profile: Variant = layer.parameters.get("profile_version")
				if profile != 1 and profile != 2: return _failure("Unsupported profile.")
				var cap := "CURVE_FLOW_STATIC_RIBBON_F2" if profile == 2 else "CURVE_FLOW_F1"
				if not cap in required: return _failure("Profile capability mismatch.")
				if not cap in used: used.append(cap)
		var decoded: Dictionary = phase.duplicate(true)
		decoded.erase("name")
		source.phases[phase.name] = decoded
	if version == 3:
		used.sort()
		var declared: Array = required.duplicate(); declared.sort()
		if used != declared: return _failure("Extraneous/duplicate v3 capabilities.")
	return preload("res://src/app/vfx_preset_pipeline.gd").new().build_document_from_value(source)

static func _failure(message: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("RUNTIME_UNSUPPORTED", "runtime_capability", message)])
