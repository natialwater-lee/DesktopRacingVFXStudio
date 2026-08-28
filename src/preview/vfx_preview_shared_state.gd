class_name VfxPreviewSharedState
extends RefCounted

const VfxPreviewGameScaleModel := preload("res://src/preview/vfx_preview_game_scale.gd")

signal changed

var _profile_data: Dictionary = {}
var _game_scale_contract: Dictionary = {}
var _track_scale := 1.0
var _background_mode := "DARK"
var _motion_mode := "STATIC"
var _motion_time := 0.0
var _vehicle_translation := Vector2.ZERO
var _vehicle_rotation_degrees := 0.0
var _layer_context: RefCounted


func set_profile_data(profile_data: Dictionary) -> void:
	_profile_data = profile_data.duplicate(true)
	changed.emit()


func profile_data() -> Dictionary:
	return _profile_data.duplicate(true)


func set_game_scale_contract(contract: Dictionary) -> void:
	_game_scale_contract = contract.duplicate(true)
	changed.emit()


func game_scale_contract() -> Dictionary:
	return _game_scale_contract.duplicate(true)


func set_track_scale(track_scale: float) -> void:
	_track_scale = track_scale
	changed.emit()


func track_scale() -> float:
	return _track_scale


func effective_game_scale() -> VfxResult:
	return VfxPreviewGameScaleModel.effective_scale(_game_scale_contract, _track_scale)


func set_background_mode(background_mode: String) -> void:
	_background_mode = background_mode
	changed.emit()


func background_mode() -> String:
	return _background_mode


func set_motion(mode: String, motion_time: float, translation: Vector2, rotation_degrees: float) -> void:
	_motion_mode = mode
	_motion_time = motion_time
	_vehicle_translation = translation
	_vehicle_rotation_degrees = rotation_degrees
	changed.emit()


func motion_mode() -> String:
	return _motion_mode


func motion_time() -> float:
	return _motion_time


func vehicle_translation() -> Vector2:
	return _vehicle_translation


func vehicle_rotation_degrees() -> float:
	return _vehicle_rotation_degrees


func set_layer_context(layer_context: RefCounted) -> void:
	_layer_context = layer_context
	changed.emit()


func layer_context() -> RefCounted:
	return _layer_context
