class_name VfxVehicleProfileValidator
extends RefCounted

const VfxSchemaSubsetValidatorModel := preload("res://src/model/vfx_schema_subset_validator.gd")

var _vfx_registry: RefCounted
var _subset_validator: RefCounted
var _profile_schema: Dictionary = {}
var _schema_issues: Array[VfxIssue] = []


func _init(vfx_registry: RefCounted, schema_path: String = "res://schemas/vehicle_anchor_profile_v1.json") -> void:
	_vfx_registry = vfx_registry
	_subset_validator = VfxSchemaSubsetValidatorModel.new(vfx_registry)
	var decoded: VfxResult = VfxPresetCodec.new().decode_file(schema_path)
	if decoded.success and decoded.value is Dictionary:
		_profile_schema = decoded.value.duplicate(true)
	else:
		_schema_issues = decoded.issues.duplicate() if not decoded.success else [VfxIssue.new("PROFILE_CONFIGURATION", "PROFILE_SCHEMA_ROOT", "Vehicle Profile Schema root must be an object.", "/type", schema_path)]


func validate(value: Variant, source_path: String = "") -> Array[VfxIssue]:
	var issues: Array[VfxIssue] = []
	if not _schema_issues.is_empty():
		for issue in _schema_issues:
			issues.append(VfxIssue.new(issue.kind, issue.code, issue.message, issue.json_pointer, source_path if not source_path.is_empty() else issue.source_path))
		return issues
	issues.append_array(_subset_validator.validate(value, _profile_schema, "", "PROFILE_VALIDATION"))
	if not value is Dictionary:
		return issues
	_validate_anchor_contract(value, source_path, issues)
	return issues


func _validate_anchor_contract(profile: Dictionary, source_path: String, issues: Array[VfxIssue]) -> void:
	var anchors_value: Variant = profile.get("anchors")
	if not anchors_value is Dictionary:
		return
	var known_anchors: Array[String] = _known_anchors()
	if known_anchors.is_empty():
		issues.append(VfxIssue.new("PROFILE_CONFIGURATION", "PROFILE_ANCHOR_CONTRACT", "VFX Schema registry does not expose vehicle Anchors.", "/anchors", source_path))
		return
	for anchor_name in known_anchors:
		if not anchors_value.has(anchor_name):
			issues.append(VfxIssue.new("PROFILE_VALIDATION", "PROFILE_REQUIRED_ANCHOR", "Vehicle Profile must map every Schema v1 vehicle Anchor.", "/anchors/%s" % anchor_name, source_path))
	for anchor_name_variant in anchors_value:
		var anchor_name: String = str(anchor_name_variant)
		if not known_anchors.has(anchor_name):
			issues.append(VfxIssue.new("PROFILE_VALIDATION", "PROFILE_UNKNOWN_ANCHOR", "Vehicle Profile Anchor is not declared by Schema v1.", "/anchors/%s" % anchor_name, source_path))
			continue
		var coordinate: Variant = anchors_value[anchor_name]
		if not coordinate is Array or coordinate.size() != 2 or not _is_number(coordinate[0]) or not _is_number(coordinate[1]):
			issues.append(VfxIssue.new("PROFILE_VALIDATION", "PROFILE_ANCHOR_COORDINATE", "Vehicle Profile Anchor must be a two-number source-local coordinate.", "/anchors/%s" % anchor_name, source_path))


func _known_anchors() -> Array[String]:
	var known: Array[String] = []
	var anchor_definition: Variant = _vfx_registry.schema().get("$defs", {}).get("anchor", {})
	if anchor_definition is Dictionary:
		for anchor_value in anchor_definition.get("enum", []):
			if anchor_value is String:
				known.append(anchor_value)
	return known


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
