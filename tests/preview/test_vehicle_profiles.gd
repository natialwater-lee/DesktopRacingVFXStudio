extends RefCounted

const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxVehicleProfileCodecModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_codec.gd")
const VfxVehicleProfileValidatorModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_validator.gd")
const VfxVehicleProfileRepositoryModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_repository.gd")


static func run(tests: TestAssert) -> void:
	var repository := _repository()
	var expected_categories := {
		"res://profiles/vehicles/formula.vehicle_profile.json": "FORMULA",
		"res://profiles/vehicles/sports.vehicle_profile.json": "SPORTS",
		"res://profiles/vehicles/gt.vehicle_profile.json": "GT",
		"res://profiles/vehicles/hyper.vehicle_profile.json": "HYPER"
	}
	for path in expected_categories:
		var loaded: VfxResult = repository.load_profile(path)
		tests.expect_true(loaded.success, "%s Profile loads with its reference image" % expected_categories[path])
		if loaded.success:
			tests.expect_true(loaded.value.data().get("category") == expected_categories[path], "%s keeps its official Category" % expected_categories[path])
			tests.expect_true(loaded.value.data().get("anchors", {}).size() == 14, "%s Profile maps every Schema v1 vehicle Anchor" % expected_categories[path])
	tests.expect_true(repository.list_profile_paths().size() == 4, "Profile repository enumerates exactly the four supported Studio vehicle Categories")

	var formula: VfxResult = repository.load_profile("res://profiles/vehicles/formula.vehicle_profile.json")
	if not formula.success:
		return
	var codec := VfxVehicleProfileCodecModel.new()
	var round_trip_path := "user://phase2_profile_round_trip.json"
	var written := codec.write_file(round_trip_path, formula.value.data())
	var round_trip := codec.decode_file(round_trip_path)
	tests.expect_true(written.success and round_trip.success and round_trip.value.get("profile_id") == "formula", "Profile codec writes and decodes authoring JSON without changing its id")
	if FileAccess.file_exists(round_trip_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(round_trip_path))
	var mismatched: Dictionary = formula.value.data()
	mismatched["reference_image"]["expected_source_size_px"] = [255, 512]
	var preflight_issues: Array[VfxIssue] = repository.preflight_profile(mismatched, "res://profiles/vehicles/formula.vehicle_profile.json")
	tests.expect_true(_has_issue(preflight_issues, "PROFILE_REFERENCE_SIZE_MISMATCH"), "reference size drift is rejected before Anchor projection")
	tests.expect_true(not preflight_issues.any(func(issue: VfxIssue) -> bool: return issue.code == "PROFILE_REFERENCE_NO_ALPHA"), "provided Formula reference remains alpha-capable")

	var invalid_anchor: Dictionary = formula.value.data()
	invalid_anchor["anchors"]["UNKNOWN_ANCHOR"] = [0, 0]
	var validator_issues: Array[VfxIssue] = _validator().validate(invalid_anchor, "res://profiles/vehicles/formula.vehicle_profile.json")
	tests.expect_true(_has_issue(validator_issues, "PROFILE_UNKNOWN_ANCHOR"), "Profile validator rejects Anchor names outside Schema v1")


static func _repository() -> RefCounted:
	return VfxVehicleProfileRepositoryModel.new(VfxVehicleProfileCodecModel.new(), _validator())


static func _validator() -> RefCounted:
	return VfxVehicleProfileValidatorModel.new(_registry())


static func _registry() -> RefCounted:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _has_issue(issues: Array[VfxIssue], code: String) -> bool:
	return issues.any(func(issue: VfxIssue) -> bool: return issue.code == code)
