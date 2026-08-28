class_name VfxVehicleProfileRepository
extends RefCounted

const VfxVehicleProfileDocumentModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_document.gd")

var _codec: RefCounted
var _validator: RefCounted


func _init(codec: RefCounted, validator: RefCounted) -> void:
	_codec = codec
	_validator = validator


func load_profile(path: String) -> VfxResult:
	var decoded: VfxResult = _codec.decode_file(path)
	if not decoded.success:
		return decoded
	if not decoded.value is Dictionary:
		return VfxResult.failure([VfxIssue.new("PROFILE_VALIDATION", "PROFILE_ROOT_TYPE", "Vehicle Profile root must be an object.", "/type", path)])
	var profile: Dictionary = decoded.value
	var issues: Array[VfxIssue] = _validator.validate(profile, path)
	issues.append_array(preflight_profile(profile, path))
	if issues.any(func(issue: VfxIssue) -> bool: return issue.severity == "ERROR"):
		return VfxResult.failure(issues)
	return VfxResult.with_issues(VfxVehicleProfileDocumentModel.new(path, profile), issues)


func save_profile(path: String, profile: Dictionary) -> VfxResult:
	var issues: Array[VfxIssue] = _validator.validate(profile, path)
	issues.append_array(preflight_profile(profile, path))
	if issues.any(func(issue: VfxIssue) -> bool: return issue.severity == "ERROR"):
		return VfxResult.failure(issues)
	var written: VfxResult = _codec.write_file(path, profile)
	if not written.success:
		return written
	return VfxResult.with_issues(VfxVehicleProfileDocumentModel.new(path, profile), issues)


func list_profile_paths(root_path: String = "res://profiles/vehicles") -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return paths
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".vehicle_profile.json"):
			paths.append("%s/%s" % [root_path.trim_suffix("/"), file_name])
		file_name = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths


func preflight_profile(profile: Dictionary, source_path: String = "") -> Array[VfxIssue]:
	var issues: Array[VfxIssue] = []
	var reference_value: Variant = profile.get("reference_image")
	if not reference_value is Dictionary:
		return issues
	var reference_path: String = str(reference_value.get("path", ""))
	if reference_path.is_empty() or not reference_path.begins_with("res://assets/reference/vehicles/"):
		issues.append(VfxIssue.new("PROFILE_REFERENCE", "PROFILE_REFERENCE_PATH", "Vehicle reference image must be a Studio-owned vehicle asset.", "/reference_image/path", source_path))
		return issues
	if not FileAccess.file_exists(reference_path):
		issues.append(VfxIssue.new("PROFILE_REFERENCE", "PROFILE_REFERENCE_MISSING", "Vehicle reference image does not exist.", "/reference_image/path", source_path))
		return issues
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(reference_path))
	if image == null or image.is_empty():
		issues.append(VfxIssue.new("PROFILE_REFERENCE", "PROFILE_REFERENCE_LOAD_FAILED", "Vehicle reference image cannot be loaded.", "/reference_image/path", source_path))
		return issues
	var expected_value: Variant = reference_value.get("expected_source_size_px")
	if expected_value is Array and expected_value.size() == 2:
		var expected: Vector2i = Vector2i(int(expected_value[0]), int(expected_value[1]))
		if image.get_size() != expected:
			issues.append(VfxIssue.new("PROFILE_REFERENCE", "PROFILE_REFERENCE_SIZE_MISMATCH", "Vehicle reference image size differs from expected_source_size_px.", "/reference_image/expected_source_size_px", source_path))
	if image.detect_alpha() == Image.ALPHA_NONE:
		issues.append(VfxIssue.new("PROFILE_REFERENCE", "PROFILE_REFERENCE_NO_ALPHA", "Vehicle reference image must contain an alpha channel.", "/reference_image/path", source_path))
	return issues
