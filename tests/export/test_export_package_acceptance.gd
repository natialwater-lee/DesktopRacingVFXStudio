extends RefCounted

const VfxExportHasherModel := preload("res://src/export/vfx_export_hasher.gd")
const VfxExportServiceModel := preload("res://src/export/vfx_export_service.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")

const ZERO_ZONE_ROOT := "res://exports/packages/talent.zero_zone/"


static func run(tests: TestAssert) -> void:
	_test_final_zero_zone_package(tests)
	_test_renderer_showcase_remains_blocked(tests)
	_test_export_documentation_and_temporary_ignores(tests)


static func _test_final_zero_zone_package(tests: TestAssert) -> void:
	var manifest_path := "%smanifest.json" % ZERO_ZONE_ROOT
	var required_paths := [
		manifest_path,
		"%ssource/talent.zero_zone.vfx.json" % ZERO_ZONE_ROOT,
		"%sruntime/vfx_runtime_definition_v1.json" % ZERO_ZONE_ROOT,
		"%sassets/energy_shard.png" % ZERO_ZONE_ROOT,
		"%sassets/energy_spark.png" % ZERO_ZONE_ROOT
	]
	tests.expect_true(required_paths.all(func(path: String) -> bool: return FileAccess.file_exists(path)), "final Zero Zone Package contains Manifest, Source, Runtime, and both Production PNG assets")
	if not FileAccess.file_exists(manifest_path):
		return
	var codec := VfxPresetCodecModel.new()
	var decoded: VfxResult = codec.decode_file(manifest_path)
	tests.expect_true(decoded.success and decoded.value is Dictionary, "final Zero Zone Manifest is valid JSON")
	if not decoded.success or not decoded.value is Dictionary:
		return
	var manifest: Dictionary = decoded.value
	var requirements: Dictionary = manifest.get("requirements", {}) if manifest.get("requirements") is Dictionary else {}
	var dependencies: Array = manifest.get("asset_dependencies", []) if manifest.get("asset_dependencies") is Array else []
	tests.expect_true(manifest.get("package_format_version") == 1 and manifest.get("package_id") == "talent.zero_zone" and requirements.get("required_vehicle_anchors") == ["CENTER"] and requirements.get("runtime_inputs") == ["intensity"], "final Manifest fixes Zero Zone Package version, identity, CENTER Anchor, and intensity input")
	tests.expect_true(dependencies.size() == 2 and dependencies.all(func(entry: Variant) -> bool: return entry is Dictionary and str(entry.get("logical_id", "")).begins_with("fx.energy_") and str(entry.get("kind", "")) == "TEXTURE_PNG"), "final Manifest maps exactly two Production texture assets and no procedural or fixture asset")
	var hasher := VfxExportHasherModel.new()
	var all_hashes_match := true
	for entry in manifest.get("files", []):
		if not entry is Dictionary:
			all_hashes_match = false
			break
		var package_path := str(entry.get("path", ""))
		var metadata: VfxResult = hasher.metadata_for_file("%s%s" % [ZERO_ZONE_ROOT, package_path])
		if not metadata.success or metadata.value.get("sha256") != entry.get("sha256") or metadata.value.get("byte_size") != entry.get("byte_size"):
			all_hashes_match = false
			break
	tests.expect_true(all_hashes_match and not (manifest.get("files", []) as Array).any(func(entry: Variant) -> bool: return entry is Dictionary and entry.get("path") == "manifest.json"), "every Manifest-listed file exists with matching SHA-256 and byte size while Manifest avoids self-hash")
	var package_json_is_portable := true
	for package_json_path in [manifest_path, "%ssource/talent.zero_zone.vfx.json" % ZERO_ZONE_ROOT, "%sruntime/vfx_runtime_definition_v1.json" % ZERO_ZONE_ROOT]:
		var text := FileAccess.get_file_as_string(package_json_path)
		if text.contains("res://") or text.contains("user://") or text.contains("C:\\") or text.contains("../") or text.contains("\\"):
			package_json_is_portable = false
	tests.expect_true(package_json_is_portable, "final Package JSON contains no Studio URI, absolute path, traversal, or backslash")


static func _test_renderer_showcase_remains_blocked(tests: TestAssert) -> void:
	var service := VfxExportServiceModel.new()
	var validation: VfxResult = service.validate_saved_source("res://presets/examples/utility.renderer_showcase.vfx.json")
	tests.expect_true(not validation.success and not FileAccess.file_exists("res://exports/packages/utility.renderer_showcase/manifest.json"), "Studio-only Renderer Showcase remains Export-blocked without a Package")


static func _test_export_documentation_and_temporary_ignores(tests: TestAssert) -> void:
	var gitignore := FileAccess.get_file_as_string("res://.gitignore")
	tests.expect_true(FileAccess.file_exists("res://docs/VFX_EXPORT_PACKAGE_V1.md") and gitignore.contains("/exports/.staging/") and gitignore.contains("/exports/.backup/"), "export contract documentation and temporary staging/backup ignore policy are present")
