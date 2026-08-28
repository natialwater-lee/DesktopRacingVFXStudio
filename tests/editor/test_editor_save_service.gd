extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxDirtyTrackerModel := preload("res://src/editor/session/vfx_dirty_tracker.gd")
const VfxPresetEditSessionModel := preload("res://src/editor/session/vfx_preset_edit_session.gd")
const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")
const VfxLayerFactoryModel := preload("res://src/editor/factories/vfx_layer_factory.gd")
const VfxEditorSaveServiceModel := preload("res://src/editor/persistence/vfx_editor_save_service.gd")
const VfxAuthoringPathsModel := preload("res://src/editor/application/vfx_authoring_paths.gd")
const VfxEditorControllerModel := preload("res://src/editor/main/vfx_editor_controller.gd")
const VfxNewPresetDialogModel := preload("res://src/editor/dialogs/vfx_new_preset_dialog.gd")

const TEST_DIRECTORY := "res://presets/_phase1_task5_review_20260828"
const NORMALIZED_DIRECTORY := "%s/normalized" % TEST_DIRECTORY
const VALID_PATH := "%s/utility.saved.vfx.json" % NORMALIZED_DIRECTORY
const BACKSLASH_VALID_PATH := "%s\\utility.saved.vfx.json" % NORMALIZED_DIRECTORY
const INVALID_EXTENSION_PATH := "%s/utility.saved.json" % TEST_DIRECTORY
const TRAVERSAL_PATH := "res://presets/../tests/escaped.vfx.json"


class FailingWriteCodec:
	extends VfxPresetCodec

	func write_text_file(path: String, _text: String) -> VfxResult:
		return VfxResult.failure([VfxIssue.new("FILE_IO", "write_failed", "controlled write failure", "", path)])


static func run(tests: TestAssert) -> void:
	var test_directory_created := _create_test_directory()
	tests.expect_true(test_directory_created, "save test owns its unique authoring-root child")
	if not test_directory_created:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NORMALIZED_DIRECTORY))
	var paths := VfxAuthoringPathsModel.new()
	var pipeline := VfxPresetPipelineModel.new()
	var save_service := VfxEditorSaveServiceModel.new(pipeline, VfxPresetCodecModel.new(), paths)
	var empty_session := _new_session(_empty_skeleton())
	var invalid_path := "%s/utility.empty.vfx.json" % TEST_DIRECTORY
	var invalid_save := save_service.save(empty_session, invalid_path)
	tests.expect_true(not invalid_save.success, "empty transient-invalid Skeleton cannot save")
	tests.expect_true(not FileAccess.file_exists(invalid_path), "invalid save performs no write")

	var valid_data := _valid_preset()
	var valid_session := _new_session(valid_data)
	var saved := save_service.save(valid_session, BACKSLASH_VALID_PATH)
	tests.expect_true(saved.success, "valid session saves through the persistence service")
	tests.expect_true(FileAccess.file_exists(VALID_PATH), "valid session writes the canonical validated authoring path")
	if saved.success:
		var reloaded := pipeline.load_and_validate(VALID_PATH)
		tests.expect_true(reloaded.success, "saved preset reloads through the Contract pipeline")
		if reloaded.success:
			tests.expect_true(reloaded.value.normalized_data == saved.value.normalized_data, "saved source reloads to the normalized saved document")
		tests.expect_true(valid_session.source_path() == VALID_PATH and not valid_session.is_dirty(), "save marks the session with the canonical normalized saved document")

	var traversal := save_service.save(_new_session(valid_data), TRAVERSAL_PATH)
	tests.expect_true(not paths.contains_preset_path(TRAVERSAL_PATH), "authoring path policy rejects traversal outside the Preset root")
	tests.expect_true(not traversal.success and _has_issue(traversal.issues, "outside_authoring_root"), "save rejects traversal outside the authoring root")
	var invalid_extension := save_service.save(_new_session(valid_data), INVALID_EXTENSION_PATH)
	tests.expect_true(not invalid_extension.success and _has_issue(invalid_extension.issues, "invalid_preset_extension"), "save rejects a non-.vfx.json extension")

	var controller := VfxEditorControllerModel.new()
	var created := controller.create_new_preset("utility.controller_empty", "Controller Empty", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(created.success, "New creates a transient-invalid skeleton in the edit session")
	var controller_traversal := controller.save_as(TRAVERSAL_PATH)
	tests.expect_true(not controller_traversal.success and _has_issue(controller_traversal.issues, "outside_authoring_root"), "controller Save As rejects traversal before persistence")
	var controller_extension := controller.save_as(INVALID_EXTENSION_PATH)
	tests.expect_true(not controller_extension.success and _has_issue(controller_extension.issues, "invalid_preset_extension"), "controller Save As rejects a non-Preset extension")
	var overwrite := controller.save_as(VALID_PATH)
	tests.expect_true(not overwrite.success and _has_issue(overwrite.issues, "overwrite_confirmation_required"), "controller Save As requires confirmation before overwriting")

	var failed_session := _new_session(valid_data)
	var failing_service := VfxEditorSaveServiceModel.new(pipeline, FailingWriteCodec.new(), paths)
	var write_failure := failing_service.save(failed_session, "%s/write_failure.vfx.json" % TEST_DIRECTORY)
	tests.expect_true(not write_failure.success and _has_issue(write_failure.issues, "write_failed"), "write failure is returned after successful validation and serialization")
	tests.expect_true(failed_session.source_path().is_empty() and failed_session.is_dirty(), "write failure leaves the session unsaved and dirty")

	var new_dialog := VfxNewPresetDialogModel.new()
	new_dialog.set_schema(_loaded_registry().schema())
	new_dialog._ready()
	tests.expect_true(new_dialog.category_options().has("UTILITY"), "New dialog derives category choices from the active Schema")
	tests.expect_true(new_dialog.lifecycle_options().has("ONE_SHOT"), "New dialog derives lifecycle choices from the active Schema")
	tests.expect_true(new_dialog.default_space_options().has("WORLD_AREA"), "New dialog derives default space choices from the active Schema")
	tests.expect_true(new_dialog.get_node_or_null("Body/Category") is OptionButton, "New dialog presents the Schema-derived category choices")
	var requested := {"value": false}
	new_dialog.preset_requested.connect(func(_preset_id, _display_name, _category, _lifecycle_mode, _default_space_mode): requested["value"] = true)
	new_dialog.request_preset("utility.dialog", "Dialog", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(requested["value"], "New dialog emits an accepted Schema-constrained choice")
	new_dialog.free()
	_cleanup_test_files(test_directory_created)


static func _new_session(data: Dictionary) -> VfxPresetEditSession:
	var session := VfxPresetEditSessionModel.new(VfxDirtyTrackerModel.new(VfxPresetCodecModel.new()))
	session.begin_new(data)
	return session


static func _empty_skeleton() -> Dictionary:
	var result := VfxPresetSkeletonFactoryModel.new(_loaded_registry()).create("utility.empty", "Empty", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	return result.value


static func _valid_preset() -> Dictionary:
	var skeleton := _empty_skeleton()
	var layer := VfxLayerFactoryModel.new(_loaded_registry()).create("GLOW", "one_shot", skeleton)
	skeleton["phases"]["one_shot"]["layers"].append(layer.value)
	return skeleton


static func _loaded_registry() -> VfxSchemaRegistry:
	var registry := VfxSchemaRegistryModel.new(VfxPresetCodecModel.new(), VfxRuleCatalogModel.new())
	registry.load("res://schemas/vfx_schema_v1.json")
	return registry


static func _has_issue(issues: Array, code: String) -> bool:
	for issue in issues:
		if issue.code == code:
			return true
	return false


static func _create_test_directory() -> bool:
	var directory_path := ProjectSettings.globalize_path(TEST_DIRECTORY)
	if DirAccess.dir_exists_absolute(directory_path):
		return false
	return DirAccess.make_dir_recursive_absolute(directory_path) == OK


static func _cleanup_test_files(test_directory_created: bool) -> void:
	if not test_directory_created:
		return
	for path in [VALID_PATH, "%s/write_failure.vfx.json" % TEST_DIRECTORY]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NORMALIZED_DIRECTORY))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))
