class_name VfxPreviewEquipmentCatalog
extends RefCounted

# Preview-only copy of the Game special equipment visuals. Placement mirrors
# Game SpecialEquipmentService.resolve_visual_placement; frames are copied PNGs.
const DEFAULT_CATALOG_PATH := "res://assets/preview/special_equipment/special_equipment_preview_catalog_v1.json"
const PHASE_ACTIVE := "active"
const PHASE_DEPLOY := "deploy"
const PHASE_RETRACT := "retract"

var _reference_texture_width := 0.0
var _equipment: Dictionary = {}
var _frame_cache: Dictionary = {}


func _init(catalog_path: String = DEFAULT_CATALOG_PATH) -> void:
	var file := FileAccess.open(catalog_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	_reference_texture_width = float(parsed.get("reference_texture_width", 0.0))
	if parsed.get("equipment") is Dictionary:
		_equipment = parsed["equipment"]


func equipment_type_for_preset(preset_id: String) -> String:
	for equipment_type in _equipment:
		var prefix := str((_equipment[equipment_type] as Dictionary).get("preset_id_prefix", ""))
		if not prefix.is_empty() and preset_id.begins_with(prefix):
			return str(equipment_type)
	return ""


func entry(equipment_type: String) -> Dictionary:
	return _equipment.get(equipment_type, {}) if _equipment.get(equipment_type, {}) is Dictionary else {}


func marks(equipment_type: String) -> Array[String]:
	var result: Array[String] = []
	var values: Variant = entry(equipment_type).get("marks", [])
	if values is Array:
		for mark_id in values:
			result.append(str(mark_id))
	return result


# RETRACT plays the deploy frames in reverse, as in Game.
func frames(equipment_type: String, mark_id: String, phase_id: String) -> Array[Texture2D]:
	var key := "%s/%s/%s" % [equipment_type, mark_id, phase_id]
	if _frame_cache.has(key):
		return _frame_cache[key]
	var result: Array[Texture2D] = []
	if phase_id == PHASE_RETRACT:
		result = frames(equipment_type, mark_id, PHASE_DEPLOY).duplicate()
		result.reverse()
	else:
		var asset_root := str(entry(equipment_type).get("asset_root", ""))
		if not asset_root.is_empty():
			var index := 0
			while true:
				var path := "%s/%s/%s/frame_%02d.png" % [asset_root, mark_id, phase_id, index]
				if not ResourceLoader.exists(path):
					break
				var texture := load(path) as Texture2D
				if texture == null:
					break
				result.append(texture)
				index += 1
	_frame_cache[key] = result
	return result


func placement(equipment_type: String, vehicle_texture_size: Vector2, equipment_texture_size: Vector2) -> Dictionary:
	var data := entry(equipment_type)
	var normalized: Variant = data.get("normalized_position", [0.5, 0.5])
	var normalized_x := float(normalized[0]) if normalized is Array and normalized.size() > 0 else 0.5
	var normalized_y := float(normalized[1]) if normalized is Array and normalized.size() > 1 else 0.5
	var runtime_visual: Dictionary = data.get("runtime_visual", {}) if data.get("runtime_visual", {}) is Dictionary else {}
	var anchor_position := Vector2((normalized_x - 0.5) * vehicle_texture_size.x, (normalized_y - 0.5) * vehicle_texture_size.y)
	anchor_position += Vector2(float(runtime_visual.get("offset_ratio_x", 0.0)) * vehicle_texture_size.x, float(runtime_visual.get("offset_ratio_y", 0.0)) * vehicle_texture_size.y)
	var equipment_scale := maxf(float(data.get("equipment_scale", 1.0)), 0.01) * float(runtime_visual.get("scale", 1.0))
	if _reference_texture_width > 0.0 and equipment_texture_size.x > 0.0:
		equipment_scale *= _reference_texture_width / equipment_texture_size.x
	return {
		"anchor_position": anchor_position,
		"equipment_scale": equipment_scale,
		"visual_layer": str(data.get("visual_layer", "underlay"))
	}


# True when the Game starts the VFX with the equipment DEPLOYING instead of ACTIVE (Super Booster charge-up).
func vfx_starts_at_deploy(equipment_type: String) -> bool:
	return str(entry(equipment_type).get("vfx_starts_at", "")) == "deploy"


# equipment_phase is PHASE_DEPLOY, PHASE_ACTIVE or PHASE_RETRACT; elapsed is seconds within it.
func resolve_frame(equipment_type: String, mark_id: String, equipment_phase: String, elapsed_seconds: float) -> Texture2D:
	var data := entry(equipment_type)
	if equipment_phase == PHASE_RETRACT:
		var retract_frames := frames(equipment_type, mark_id, PHASE_RETRACT)
		var duration := maxf(float(data.get("retract_duration_seconds", 0.5)), 0.001)
		if retract_frames.is_empty() or elapsed_seconds >= duration:
			return null
		var progress := clampf(elapsed_seconds / duration, 0.0, 0.999999)
		return retract_frames[clampi(int(floor(progress * retract_frames.size())), 0, retract_frames.size() - 1)]
	if equipment_phase == PHASE_DEPLOY:
		var deploy_frames := frames(equipment_type, mark_id, PHASE_DEPLOY)
		if deploy_frames.is_empty():
			return null
		var deploy_duration := maxf(float(data.get("deploy_duration_seconds", 0.5)), 0.001)
		var deploy_progress := clampf(elapsed_seconds / deploy_duration, 0.0, 0.999999)
		return deploy_frames[clampi(int(floor(deploy_progress * deploy_frames.size())), 0, deploy_frames.size() - 1)]
	if equipment_phase != PHASE_ACTIVE:
		return null
	var active_frames := frames(equipment_type, mark_id, PHASE_ACTIVE)
	if active_frames.is_empty():
		return null
	var frame_rate := float(data.get("active_frame_rate", 24.0))
	return active_frames[posmod(int(floor(maxf(elapsed_seconds, 0.0) * frame_rate)), active_frames.size())]
