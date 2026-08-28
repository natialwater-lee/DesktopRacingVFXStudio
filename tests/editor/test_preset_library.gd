extends RefCounted

const VfxPresetLibraryModel := preload("res://src/editor/library/vfx_preset_library.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxAuthoringPathsModel := preload("res://src/editor/application/vfx_authoring_paths.gd")
const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")

const TEST_DIRECTORY := "res://presets/_phase1_task5_review_20260828"
const INVALID_PATH := "%s/invalid.vfx.json" % TEST_DIRECTORY


static func run(tests: TestAssert) -> void:
	var test_directory_created := _create_test_directory()
	tests.expect_true(test_directory_created, "library test owns its unique authoring-root child")
	if not test_directory_created:
		return
	var codec := VfxPresetCodecModel.new()
	var invalid_write := codec.write_text_file(INVALID_PATH, "{\"schema_version\": 1}")
	tests.expect_true(invalid_write.success, "library fixture writes invalid source text")
	var library := VfxPresetLibraryModel.new(VfxPresetPipelineModel.new(), VfxAuthoringPathsModel.new())
	var entries := library.scan()
	tests.expect_true(entries.any(func(entry): return entry.preset_id == "talent.zero_zone" and entry.document != null), "valid example appears in library")
	tests.expect_true(entries.any(func(entry): return entry.source_path == INVALID_PATH and not entry.issues.is_empty()), "invalid file becomes an error row")
	var invalid_entries := entries.filter(func(entry): return entry.source_path == INVALID_PATH)
	if not invalid_entries.is_empty():
		var invalid_entry = invalid_entries[0]
		tests.expect_true(invalid_entry.document == null, "invalid library entry is non-openable")
		tests.expect_true(not VfxEditorControllerModel.new().open_library_entry(invalid_entry).success, "controller refuses to open an invalid library row")
	var filtered := library.filter("zero", "RACE_TALENT")
	tests.expect_true(filtered.size() == 1 and filtered[0].preset_id == "talent.zero_zone", "library filtering uses display/id substring and exact category")
	tests.expect_true(library.filter("zero", "UTILITY").is_empty(), "library category filtering excludes nonmatching rows")
	_cleanup_test_directory(test_directory_created)


static func _create_test_directory() -> bool:
	var directory_path := ProjectSettings.globalize_path(TEST_DIRECTORY)
	if DirAccess.dir_exists_absolute(directory_path):
		return false
	return DirAccess.make_dir_recursive_absolute(directory_path) == OK


static func _cleanup_test_directory(test_directory_created: bool) -> void:
	if not test_directory_created:
		return
	if FileAccess.file_exists(INVALID_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(INVALID_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))
