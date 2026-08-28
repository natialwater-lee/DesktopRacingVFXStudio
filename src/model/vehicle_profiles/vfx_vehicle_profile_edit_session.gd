class_name VfxVehicleProfileEditSession
extends RefCounted

const VfxVehicleProfileCodecModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_codec.gd")

var _repository: RefCounted
var _codec: RefCounted
var _source_path := ""
var _working_data: Dictionary = {}
var _saved_baseline: Dictionary = {}


func _init(repository: RefCounted, codec: RefCounted = null) -> void:
	_repository = repository
	_codec = codec if codec != null else VfxVehicleProfileCodecModel.new()


func open_document(document: RefCounted) -> void:
	_source_path = document.source_path
	_working_data = document.data()
	_saved_baseline = _working_data.duplicate(true)


func working_copy() -> Dictionary:
	return _working_data.duplicate(true)


func source_path() -> String:
	return _source_path


func set_anchor(anchor_name: String, source_position: Vector2) -> bool:
	if not (_working_data.get("anchors") is Dictionary) or not _working_data["anchors"].has(anchor_name):
		return false
	_working_data["anchors"][anchor_name] = [int(round(source_position.x)), int(round(source_position.y))]
	return true


func is_dirty() -> bool:
	var working_encoded: VfxResult = _codec.encode(_working_data)
	var baseline_encoded: VfxResult = _codec.encode(_saved_baseline)
	return not working_encoded.success or not baseline_encoded.success or working_encoded.value != baseline_encoded.value


func save() -> VfxResult:
	if _source_path.is_empty():
		return VfxResult.failure([VfxIssue.new("PROFILE_SESSION", "PROFILE_SOURCE_PATH", "Vehicle Profile needs a source path before saving.")])
	var saved: VfxResult = _repository.save_profile(_source_path, _working_data)
	if saved.success:
		_working_data = saved.value.data()
		_saved_baseline = _working_data.duplicate(true)
	return saved


func revert() -> void:
	_working_data = _saved_baseline.duplicate(true)
