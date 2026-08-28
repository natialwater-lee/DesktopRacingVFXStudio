class_name VfxEditorController
extends RefCounted

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxAuthoringPathsModel := preload("res://src/editor/application/vfx_authoring_paths.gd")
const VfxDirtyTrackerModel := preload("res://src/editor/session/vfx_dirty_tracker.gd")
const VfxPresetEditSessionModel := preload("res://src/editor/session/vfx_preset_edit_session.gd")
const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")
const VfxPresetLibraryModel := preload("res://src/editor/library/vfx_preset_library.gd")
const VfxPresetLibraryEntryModel := preload("res://src/editor/library/vfx_preset_library_entry.gd")
const VfxEditorSaveServiceModel := preload("res://src/editor/persistence/vfx_editor_save_service.gd")
const VfxNewPresetDialogModel := preload("res://src/editor/dialogs/vfx_new_preset_dialog.gd")

var _paths: VfxAuthoringPaths
var _pipeline: VfxPresetPipeline
var _registry: VfxSchemaRegistry
var _session: VfxPresetEditSession
var _skeleton_factory: RefCounted
var _library: RefCounted
var _save_service: RefCounted
var _issues: Array[VfxIssue] = []
var _new_preset_dialog: ConfirmationDialog
var _preset_file_dialog: FileDialog
var _overwrite_confirmation_dialog: ConfirmationDialog
var _file_dialog_action := ""
var _pending_overwrite_path := ""


func _init() -> void:
	_paths = VfxAuthoringPathsModel.new()
	_pipeline = VfxPresetPipelineModel.new()
	var codec := VfxPresetCodecModel.new()
	_registry = VfxSchemaRegistryModel.new(codec, VfxRuleCatalogModel.new())
	_registry.load(VfxPresetPipeline.DEFAULT_SCHEMA_PATH)
	_session = VfxPresetEditSessionModel.new(VfxDirtyTrackerModel.new(codec))
	_skeleton_factory = VfxPresetSkeletonFactoryModel.new(_registry)
	_library = VfxPresetLibraryModel.new(_pipeline, _paths)
	_save_service = VfxEditorSaveServiceModel.new(_pipeline, codec, _paths)


func request_close() -> bool:
	return true


func create_new_preset(preset_id: String, display_name: String, category: String, lifecycle_mode: String, default_space_mode: String) -> VfxResult:
	var created: VfxResult = _skeleton_factory.create(preset_id, display_name, category, lifecycle_mode, default_space_mode)
	if not created.success:
		_issues = created.issues.duplicate()
		return created
	_session.begin_new(created.value)
	_refresh_issues()
	return created


func open_library_entry(entry: RefCounted) -> VfxResult:
	if entry == null or not entry.is_openable():
		return _policy_failure("invalid_library_entry", "Only a valid Preset Library entry can be opened.", "")
	_session.open_document(entry.document)
	_refresh_issues()
	return VfxResult.ok(entry.document)


func open_path(path: String) -> VfxResult:
	if not _paths.contains_preset_path(path):
		return _policy_failure("outside_authoring_root", "Preset files must be opened below the configured authoring root.", path)
	var loaded := _pipeline.load_and_validate(path)
	if not loaded.success:
		_issues = loaded.issues.duplicate()
		return loaded
	_session.open_document(loaded.value)
	_refresh_issues()
	return loaded


func save() -> VfxResult:
	if _session.source_path().is_empty():
		return _policy_failure("save_as_required", "A new Preset requires a Save As destination.", "")
	return _save_to(_session.source_path())


func save_as(target_path: String, overwrite_confirmed: bool = false) -> VfxResult:
	var normalized := _paths.normalize_authoring_path(target_path)
	if not _paths.contains_preset_path(normalized):
		return _policy_failure("outside_authoring_root", "Preset files must be saved below the configured authoring root.", target_path)
	if not normalized.ends_with(".vfx.json"):
		return _policy_failure("invalid_preset_extension", "Preset files must use the .vfx.json extension.", target_path)
	if FileAccess.file_exists(normalized) and not overwrite_confirmed:
		return _policy_failure("overwrite_confirmation_required", "Saving over an existing Preset requires confirmation.", normalized)
	return _save_to(normalized)


func scan_library() -> Array:
	return _library.scan()


func current_issues() -> Array[VfxIssue]:
	return _issues.duplicate()


func configure_new_preset_dialog(dialog: ConfirmationDialog) -> void:
	_new_preset_dialog = dialog
	_new_preset_dialog.set_schema(_registry.schema())
	if not _new_preset_dialog.preset_requested.is_connected(_on_new_preset_requested):
		_new_preset_dialog.preset_requested.connect(_on_new_preset_requested)


func configure_preset_file_dialog(dialog: FileDialog) -> void:
	_preset_file_dialog = dialog
	_preset_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_preset_file_dialog.filters = PackedStringArray(["*.vfx.json ; VFX Preset"])
	if not _preset_file_dialog.file_selected.is_connected(_on_preset_file_selected):
		_preset_file_dialog.file_selected.connect(_on_preset_file_selected)


func configure_overwrite_confirmation_dialog(dialog: ConfirmationDialog) -> void:
	_overwrite_confirmation_dialog = dialog
	if not _overwrite_confirmation_dialog.confirmed.is_connected(_on_overwrite_confirmed):
		_overwrite_confirmation_dialog.confirmed.connect(_on_overwrite_confirmed)


func _on_new_pressed() -> void:
	if _new_preset_dialog != null:
		_new_preset_dialog.popup_centered()


func _on_open_pressed() -> void:
	_file_dialog_action = "OPEN"
	_show_file_dialog(FileDialog.FILE_MODE_OPEN_FILE)


func _on_save_pressed() -> void:
	if _session.source_path().is_empty():
		_file_dialog_action = "SAVE_AS"
		_show_file_dialog(FileDialog.FILE_MODE_SAVE_FILE)
		return
	save()


func _on_save_as_pressed() -> void:
	_file_dialog_action = "SAVE_AS"
	_show_file_dialog(FileDialog.FILE_MODE_SAVE_FILE)


func _on_new_preset_requested(preset_id: String, display_name: String, category: String, lifecycle_mode: String, default_space_mode: String) -> void:
	create_new_preset(preset_id, display_name, category, lifecycle_mode, default_space_mode)


func _on_preset_file_selected(path: String) -> void:
	if _file_dialog_action == "OPEN":
		open_path(path)
	elif _file_dialog_action == "SAVE_AS":
		var normalized := _paths.normalize_authoring_path(path)
		if FileAccess.file_exists(normalized):
			_pending_overwrite_path = normalized
			if _overwrite_confirmation_dialog != null:
				_overwrite_confirmation_dialog.popup_centered()
			else:
				save_as(normalized, false)
		else:
			save_as(normalized, true)
	_file_dialog_action = ""


func _on_overwrite_confirmed() -> void:
	if not _pending_overwrite_path.is_empty():
		save_as(_pending_overwrite_path, true)
	_pending_overwrite_path = ""


func _save_to(target_path: String) -> VfxResult:
	var saved: VfxResult = _save_service.save(_session, target_path)
	_issues = saved.issues.duplicate()
	return saved


func _show_file_dialog(mode: FileDialog.FileMode) -> void:
	if _preset_file_dialog == null:
		return
	_preset_file_dialog.file_mode = mode
	_preset_file_dialog.current_dir = _paths.preset_root()
	_preset_file_dialog.popup_centered_ratio()


func _refresh_issues() -> void:
	var built := _pipeline.build_document_from_value(_session.working_copy(), _session.source_path())
	_issues = built.issues.duplicate()


func _policy_failure(code: String, message: String, path: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EDITOR_POLICY", code, message, "", path)])
