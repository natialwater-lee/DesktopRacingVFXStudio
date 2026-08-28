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

const TEST_DIRECTORY := "res://presets/_phase1_task5_save_test"
const VALID_PATH := "%s/utility.saved.vfx.json" % TEST_DIRECTORY
const OUTSIDE_PATH := "res://tests/_phase1_task5_outside.vfx.json"


static func run(tests: TestAssert) -> void:
	_cleanup_test_files()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))
	var paths := VfxAuthoringPathsModel.new()
	var pipeline := VfxPresetPipelineModel.new()
	var save_service := VfxEditorSaveServiceModel.new(pipeline, VfxPresetCodecModel.new(), paths)
	var empty_session := _new_session(_empty_skeleton())
	var invalid_path := paths.default_save_path("utility.empty")
	var invalid_save := save_service.save(empty_session, invalid_path)
	tests.expect_true(not invalid_save.success, "empty transient-invalid Skeleton cannot save")
	tests.expect_true(not FileAccess.file_exists(invalid_path), "invalid save performs no write")

	var valid_data := _valid_preset()
	var valid_session := _new_session(valid_data)
	var saved := save_service.save(valid_session, VALID_PATH)
	tests.expect_true(saved.success, "valid session saves through the persistence service")
	tests.expect_true(FileAccess.file_exists(VALID_PATH), "valid session writes only its requested authoring path")
	if saved.success:
		var reloaded := pipeline.load_and_validate(VALID_PATH)
		tests.expect_true(reloaded.success, "saved preset reloads through the Contract pipeline")
		if reloaded.success:
			tests.expect_true(reloaded.value.normalized_data == saved.value.normalized_data, "saved source reloads to the normalized saved document")
		tests.expect_true(valid_session.source_path() == VALID_PATH and not valid_session.is_dirty(), "save marks the session with the normalized saved document")

	var outside := save_service.save(_new_session(valid_data), OUTSIDE_PATH)
	tests.expect_true(not outside.success and _has_issue(outside.issues, "outside_authoring_root"), "outside-root Save As returns the authoring policy issue")
	tests.expect_true(not FileAccess.file_exists(OUTSIDE_PATH), "outside-root Save As performs no write")
	var controller := VfxEditorControllerModel.new()
	var created := controller.create_new_preset("utility.controller_empty", "Controller Empty", "UTILITY", "ONE_SHOT", "WORLD_AREA")
	tests.expect_true(created.success, "New creates a transient-invalid skeleton in the edit session")
	var controller_outside := controller.save_as(OUTSIDE_PATH)
	tests.expect_true(not controller_outside.success and _has_issue(controller_outside.issues, "outside_authoring_root"), "controller Save As rejects outside-root paths before persistence")
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
	_cleanup_test_files()


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


static func _cleanup_test_files() -> void:
	var valid_absolute := ProjectSettings.globalize_path(VALID_PATH)
	if FileAccess.file_exists(VALID_PATH):
		DirAccess.remove_absolute(valid_absolute)
	var directory_path := ProjectSettings.globalize_path(TEST_DIRECTORY)
	if DirAccess.dir_exists_absolute(directory_path):
		DirAccess.remove_absolute(directory_path)
	if FileAccess.file_exists(OUTSIDE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUTSIDE_PATH))
