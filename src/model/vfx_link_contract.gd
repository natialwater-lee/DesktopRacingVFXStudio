extends RefCounted
## Cross-field rules for linked VFX (LINK_STRIP layers and PARTICLE link_point_t).
## Called only after structural schema validation. Design: docs/contracts/link_strip_v1.md

const LINK_STRIP := "LINK_STRIP"


static func uses_link(data: Dictionary) -> bool:
	for phase in data.get("phases", {}).values():
		for layer in phase.get("layers", []):
			if layer.get("type") == LINK_STRIP or layer.has("link_point_t"):
				return true
	return false


static func validate_preset(data: Dictionary) -> Array[VfxIssue]:
	var issues: Array[VfxIssue] = []
	var has_target: bool = data.get("link_target") is Dictionary
	var used := false
	for phase_name in data.get("phases", {}):
		var layers: Array = data.phases[phase_name].get("layers", [])
		for index in layers.size():
			var layer: Dictionary = layers[index]
			var pointer := "/phases/%s/layers/%d" % [phase_name, index]
			var space := str(layer.get("space_mode", data.get("default_space_mode", "")))
			if layer.get("type") == LINK_STRIP:
				used = true
				if space != "VEHICLE_LOCAL":
					issues.append(VfxIssue.new("PRESET_VALIDATION", "link_strip_space", "LINK_STRIP requires VEHICLE_LOCAL space.", pointer))
				if layer.get("anchors", []).size() != 1:
					issues.append(VfxIssue.new("PRESET_VALIDATION", "link_strip_anchor", "LINK_STRIP requires exactly one start Anchor.", pointer + "/anchors"))
				if layer.has("visual_bend"):
					issues.append(VfxIssue.new("PRESET_VALIDATION", "link_strip_bend", "LINK_STRIP does not support visual_bend.", pointer))
			if layer.has("link_point_t"):
				used = true
				if layer.get("type") != "PARTICLE" or space != "VEHICLE_LOCAL":
					issues.append(VfxIssue.new("PRESET_VALIDATION", "link_point_layer", "link_point_t is only valid on VEHICLE_LOCAL PARTICLE layers.", pointer + "/link_point_t"))
	if used and not has_target:
		issues.append(VfxIssue.new("PRESET_VALIDATION", "link_target_required", "LINK_STRIP or link_point_t requires a top-level link_target.", "/link_target"))
	if has_target and not used:
		issues.append(VfxIssue.new("PRESET_VALIDATION", "link_target_unused", "link_target is declared but no layer uses the link.", "/link_target"))
	return issues
