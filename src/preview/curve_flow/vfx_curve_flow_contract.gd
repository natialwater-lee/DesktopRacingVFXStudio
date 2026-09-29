extends RefCounted
## Called only after structural schema validation.
static func validate_preset(data: Dictionary) -> Array[VfxIssue]:
	var issues: Array[VfxIssue] = []
	for phase_name in data.get("phases", {}):
		var phase: Dictionary = data.phases[phase_name]
		if phase.get("duration_seconds", 1.0) == 0.0 and (phase_name != "start" or not phase.layers.is_empty()):
			issues.append(VfxIssue.new("PRESET_VALIDATION", "zero_phase", "Only an empty START may have zero duration."))
		for layer in phase.get("layers", []):
			if layer.get("type") != "CURVE_FLOW": continue
			var p: Dictionary = layer.get("parameters", {})
			if not _finite(p) or phase_name != "loop" or layer.get("blend_mode") != "ADDITIVE" or layer.get("space_mode", data.get("default_space_mode")) != "VEHICLE_LOCAL":
				issues.append(VfxIssue.new("PRESET_VALIDATION", "curve_flow_contract", "CURVE_FLOW requires finite data, LOOP, ADDITIVE and VEHICLE_LOCAL."))
			var curves: Array = p.get("curves", [])
			for i in curves.size():
				if not curves[i] is Array or curves[i].size() != 4: continue
				var c: Array = curves[i]
				if not c.all(func(v): return v is Array and v.size() == 2): continue
				var a := Vector2(c[0][0], c[0][1])
				var b := Vector2(c[1][0], c[1][1])
				var d := Vector2(c[2][0], c[2][1])
				var e := Vector2(c[3][0], c[3][1])
				if a.distance_to(b) < 0.001 or d.distance_to(e) < 0.001 or a.distance_to(e) < 0.001:
					issues.append(VfxIssue.new("PRESET_VALIDATION", "curve_degenerate", "Curve needs nonzero endpoint tangents and span."))
				if i > 0:
					var prev: Array = curves[i - 1]
					if prev.size() != 4 or not prev.all(func(v): return v is Array and v.size() == 2): continue
					var end := Vector2(prev[3][0], prev[3][1])
					var tangent := end - Vector2(prev[2][0], prev[2][1])
					if a.distance_to(end) > 0.001 or (b - a).distance_to(tangent) > 0.001:
						issues.append(VfxIssue.new("PRESET_VALIDATION", "curve_join", "Connected cubics require C1 continuity."))
	return issues

static func _finite(value: Variant) -> bool:
	if value is float: return is_finite(value)
	if value is Array:
		for item in value:
			if not _finite(item): return false
	if value is Dictionary:
		for item in value.values():
			if not _finite(item): return false
	return true

static func lane(parameters: Dictionary) -> Dictionary:
	var result := parameters.duplicate(true)
	for i in result.curves.size():
		for j in 4:
			var point: Array = result.curves[i][j]
			result.curves[i][j] = Vector2(point[0], point[1])
	return result
