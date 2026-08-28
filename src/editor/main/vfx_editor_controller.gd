class_name VfxEditorController
extends RefCounted

signal layer_type_change_confirmation_requested(target_type: String)
signal close_approved

const VfxPresetPipelineModel := preload("res://src/app/vfx_preset_pipeline.gd")
const VfxPresetCodecModel := preload("res://src/model/vfx_preset_codec.gd")
const VfxRuleCatalogModel := preload("res://src/model/vfx_rule_catalog.gd")
const VfxSchemaRegistryModel := preload("res://src/model/vfx_schema_registry.gd")
const VfxAuthoringPathsModel := preload("res://src/editor/application/vfx_authoring_paths.gd")
const VfxDirtyTrackerModel := preload("res://src/editor/session/vfx_dirty_tracker.gd")
const VfxPresetEditSessionModel := preload("res://src/editor/session/vfx_preset_edit_session.gd")
const VfxPresetHistoryModel := preload("res://src/editor/session/vfx_preset_history.gd")
const VfxPresetSkeletonFactoryModel := preload("res://src/editor/factories/vfx_preset_skeleton_factory.gd")
const VfxLayerFactoryModel := preload("res://src/editor/factories/vfx_layer_factory.gd")
const VfxStructureChangeServiceModel := preload("res://src/editor/factories/vfx_structure_change_service.gd")
const VfxLayerStackModel := preload("res://src/editor/workspace/vfx_layer_stack.gd")
const VfxSchemaReaderModel := preload("res://src/editor/inspector/vfx_schema_reader.gd")
const VfxPresetInspectorModel := preload("res://src/editor/inspector/vfx_preset_inspector.gd")
const VfxLayerInspectorModel := preload("res://src/editor/inspector/vfx_layer_inspector.gd")
const VfxPresetLibraryModel := preload("res://src/editor/library/vfx_preset_library.gd")
const VfxPresetLibraryEntryModel := preload("res://src/editor/library/vfx_preset_library_entry.gd")
const VfxEditorSaveServiceModel := preload("res://src/editor/persistence/vfx_editor_save_service.gd")
const VfxNewPresetDialogModel := preload("res://src/editor/dialogs/vfx_new_preset_dialog.gd")
const VfxDiagnosticsNavigatorModel := preload("res://src/editor/diagnostics/vfx_diagnostics_navigator.gd")
const VfxVehicleProfileCodecModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_codec.gd")
const VfxVehicleProfileRepositoryModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_repository.gd")
const VfxVehicleProfileValidatorModel := preload("res://src/model/vehicle_profiles/vfx_vehicle_profile_validator.gd")
const VfxPreviewLayerContextResolverModel := preload("res://src/preview/vfx_preview_layer_context_resolver.gd")
const VfxPreviewRenderPlanBuilderModel := preload("res://src/preview/rendering/vfx_preview_render_plan_builder.gd")

var _paths: VfxAuthoringPaths
var _pipeline: VfxPresetPipeline
var _registry: VfxSchemaRegistry
var _session: VfxPresetEditSession
var _history: VfxPresetHistory
var _skeleton_factory: RefCounted
var _layer_factory: RefCounted
var _structure_change_service: RefCounted
var _library: RefCounted
var _library_panel
var _save_service: RefCounted
var _issues: Array[VfxIssue] = []
var _new_preset_dialog: ConfirmationDialog
var _preset_file_dialog: FileDialog
var _overwrite_confirmation_dialog: ConfirmationDialog
var _file_dialog_action := ""
var _pending_overwrite_path := ""
var _phase_tabs
var _layer_stack
var _preset_inspector: VfxPresetInspector
var _layer_inspector: VfxLayerInspector
var _selected_phase := ""
var _selected_layer_id := ""
var _diagnostics_panel
var _diagnostics_navigator: RefCounted
var _toolbar: HBoxContainer
var _unsaved_changes_dialog
var _structure_change_dialog
var _pending_transition: Callable
var _pending_transition_name := ""
var _pending_structure_kind := ""
var _pending_structure_target := ""
var _transition_performed := false
var _refreshing_workspace := false
var _preview: Node
var _preview_context_resolver: RefCounted
var _preview_render_plan_builder: RefCounted
var _last_preview_normalized_data: Dictionary = {}
var _has_last_preview_normalized_data := false
var _vehicle_profile_repository: RefCounted


func _init() -> void:
	_paths = VfxAuthoringPathsModel.new()
	_pipeline = VfxPresetPipelineModel.new()
	var codec := VfxPresetCodecModel.new()
	_registry = VfxSchemaRegistryModel.new(codec, VfxRuleCatalogModel.new())
	_registry.load(VfxPresetPipeline.DEFAULT_SCHEMA_PATH)
	_session = VfxPresetEditSessionModel.new(VfxDirtyTrackerModel.new(codec))
	_history = VfxPresetHistoryModel.new()
	_skeleton_factory = VfxPresetSkeletonFactoryModel.new(_registry)
	_layer_factory = VfxLayerFactoryModel.new(_registry)
	_structure_change_service = VfxStructureChangeServiceModel.new(_skeleton_factory, _layer_factory)
	_library = VfxPresetLibraryModel.new(_pipeline, _paths)
	_save_service = VfxEditorSaveServiceModel.new(_pipeline, codec, _paths)
	_diagnostics_navigator = VfxDiagnosticsNavigatorModel.new()
	_preview_context_resolver = VfxPreviewLayerContextResolverModel.new(_registry)
	_preview_render_plan_builder = VfxPreviewRenderPlanBuilderModel.new(_registry)
	_vehicle_profile_repository = VfxVehicleProfileRepositoryModel.new(VfxVehicleProfileCodecModel.new(codec), VfxVehicleProfileValidatorModel.new(_registry))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _history != null:
		_history.dispose()


func request_close() -> bool:
	return request_transition("Close", func() -> void: close_approved.emit())


func transition_performed() -> bool:
	return _transition_performed


func request_transition(action_name: String, continuation: Callable) -> bool:
	_transition_performed = false
	if _has_unsaved_changes():
		_pending_transition_name = action_name
		_pending_transition = continuation
		if _unsaved_changes_dialog != null:
			_unsaved_changes_dialog.request(action_name)
		return false
	_perform_transition(action_name, continuation)
	return true


func create_new_preset(preset_id: String, display_name: String, category: String, lifecycle_mode: String, default_space_mode: String) -> VfxResult:
	var created: VfxResult = _skeleton_factory.create(preset_id, display_name, category, lifecycle_mode, default_space_mode)
	if not created.success:
		_set_issues(created.issues)
		return created
	_history.clear()
	_session.begin_new(created.value)
	_refresh_issues()
	reconcile_selection()
	return created


func open_library_entry(entry: RefCounted) -> VfxResult:
	if entry == null or not entry.is_openable():
		return _policy_failure("invalid_library_entry", "Only a valid Preset Library entry can be opened.", "")
	_history.clear()
	_session.open_document(entry.document)
	_refresh_issues()
	reconcile_selection()
	return VfxResult.ok(entry.document)


func open_path(path: String) -> VfxResult:
	var normalized := _paths.normalize_authoring_path(path)
	if not _paths.contains_preset_path(normalized):
		var outside_root := _policy_failure("outside_authoring_root", "Preset files must be opened below the configured authoring root.", path)
		_set_issues(outside_root.issues)
		return outside_root
	if not normalized.ends_with(".vfx.json"):
		var invalid_extension := _policy_failure("invalid_preset_extension", "Preset files must use the .vfx.json extension.", path)
		_set_issues(invalid_extension.issues)
		return invalid_extension
	var loaded := _pipeline.load_and_validate(normalized)
	if not loaded.success:
		_set_issues(loaded.issues)
		return loaded
	_history.clear()
	_session.open_document(loaded.value)
	_refresh_issues()
	reconcile_selection()
	return loaded


func save() -> VfxResult:
	if _session.source_path().is_empty():
		var save_as_required := _policy_failure("save_as_required", "A new Preset requires a Save As destination.", "")
		_set_issues(save_as_required.issues)
		return save_as_required
	refresh_validation()
	return _save_to(_session.source_path())


func save_as(target_path: String, overwrite_confirmed: bool = false) -> VfxResult:
	var normalized := _paths.normalize_authoring_path(target_path)
	if not _paths.contains_preset_path(normalized):
		var outside_root := _policy_failure("outside_authoring_root", "Preset files must be saved below the configured authoring root.", target_path)
		_set_issues(outside_root.issues)
		return outside_root
	if not normalized.ends_with(".vfx.json"):
		var invalid_extension := _policy_failure("invalid_preset_extension", "Preset files must use the .vfx.json extension.", target_path)
		_set_issues(invalid_extension.issues)
		return invalid_extension
	if FileAccess.file_exists(normalized) and not overwrite_confirmed:
		var overwrite_required := _policy_failure("overwrite_confirmation_required", "Saving over an existing Preset requires confirmation.", normalized)
		_set_issues(overwrite_required.issues)
		return overwrite_required
	refresh_validation()
	return _save_to(normalized)


func scan_library() -> Array:
	return _library.scan()


func contract_services_ready() -> bool:
	return _pipeline != null and not _registry.schema().is_empty()


func current_issues() -> Array[VfxIssue]:
	return _issues.duplicate()


func working_preset() -> Dictionary:
	return _session.working_copy()


func selected_phase_name() -> String:
	return _selected_phase


func selected_layer_id() -> String:
	return _selected_layer_id


func can_undo() -> bool:
	return _history.can_undo()


func can_redo() -> bool:
	return _history.can_redo()


func configure_workspace(phase_tabs, layer_stack) -> void:
	_phase_tabs = phase_tabs
	_layer_stack = layer_stack
	_phase_tabs.set_duration_schemas(_schema_duration_schemas())
	_layer_stack.set_layer_factory(_layer_factory)
	_layer_stack.set_available_layer_types(_registry.schema().get("x_vfx_layer_types", {}).keys())
	if not _phase_tabs.phase_selected.is_connected(_on_phase_selected):
		_phase_tabs.phase_selected.connect(_on_phase_selected)
	if not _phase_tabs.duration_commit_requested.is_connected(_on_phase_duration_committed):
		_phase_tabs.duration_commit_requested.connect(_on_phase_duration_committed)
	if not _layer_stack.layer_selected.is_connected(_on_layer_selected):
		_layer_stack.layer_selected.connect(_on_layer_selected)
	if not _layer_stack.add_layer_requested.is_connected(_on_add_layer_requested):
		_layer_stack.add_layer_requested.connect(_on_add_layer_requested)
	if not _layer_stack.delete_layer_requested.is_connected(_on_delete_layer_requested):
		_layer_stack.delete_layer_requested.connect(_on_delete_layer_requested)
	if not _layer_stack.duplicate_layer_requested.is_connected(_on_duplicate_layer_requested):
		_layer_stack.duplicate_layer_requested.connect(_on_duplicate_layer_requested)
	if not _layer_stack.move_layer_requested.is_connected(_on_move_layer_requested):
		_layer_stack.move_layer_requested.connect(_on_move_layer_requested)
	if not _layer_stack.layer_enabled_requested.is_connected(_on_layer_enabled_requested):
		_layer_stack.layer_enabled_requested.connect(_on_layer_enabled_requested)
	reconcile_selection()


func configure_preview(preview: Node) -> void:
	_preview = preview
	if _preview == null:
		return
	_preview.set_schema_registry(_registry)
	_preview.set_profile_repository(_vehicle_profile_repository)
	_preview.set_profile_documents(_load_preview_profiles())
	_preview.set_game_scale_contract(_load_preview_game_scale_contract())
	_refresh_preview()


func configure_toolbar(toolbar: HBoxContainer) -> void:
	_toolbar = toolbar
	_refresh_toolbar()


func configure_library_panel(panel) -> void:
	_library_panel = panel
	var reader := VfxSchemaReaderModel.new(_registry)
	var category_schema := reader.property_schema(reader.root_schema(), "category")
	_library_panel.set_categories(reader.enum_values(category_schema.value) if category_schema.success else [])
	if not _library_panel.filter_changed.is_connected(_on_library_filter_changed):
		_library_panel.filter_changed.connect(_on_library_filter_changed)
	if not _library_panel.preset_open_requested.is_connected(_on_library_preset_open_requested):
		_library_panel.preset_open_requested.connect(_on_library_preset_open_requested)
	if not _library_panel.invalid_entry_selected.is_connected(_on_library_invalid_entry_selected):
		_library_panel.invalid_entry_selected.connect(_on_library_invalid_entry_selected)
	_refresh_library()


func configure_diagnostics_panel(panel) -> void:
	_diagnostics_panel = panel
	if not _diagnostics_panel.issue_activated.is_connected(_on_diagnostic_issue_activated):
		_diagnostics_panel.issue_activated.connect(_on_diagnostic_issue_activated)
	_diagnostics_panel.set_issues(_issues)


func configure_transition_dialogs(unsaved_changes_dialog, structure_change_dialog) -> void:
	_unsaved_changes_dialog = unsaved_changes_dialog
	_structure_change_dialog = structure_change_dialog
	if not _unsaved_changes_dialog.decision.is_connected(_on_unsaved_changes_decision):
		_unsaved_changes_dialog.decision.connect(_on_unsaved_changes_decision)
	if not _structure_change_dialog.confirmed.is_connected(_on_structure_change_confirmed):
		_structure_change_dialog.confirmed.connect(_on_structure_change_confirmed)
	if not _structure_change_dialog.canceled.is_connected(_on_structure_change_canceled):
		_structure_change_dialog.canceled.connect(_on_structure_change_canceled)


func configure_inspectors(preset_inspector: VfxPresetInspector, layer_inspector: VfxLayerInspector) -> void:
	_preset_inspector = preset_inspector
	_layer_inspector = layer_inspector
	var reader := VfxSchemaReaderModel.new(_registry)
	_preset_inspector.set_schema_reader(reader)
	_layer_inspector.set_schema_reader(reader)
	if not _preset_inspector.preset_field_commit.is_connected(_on_preset_field_commit):
		_preset_inspector.preset_field_commit.connect(_on_preset_field_commit)
	if not _preset_inspector.lifecycle_change_requested.is_connected(_on_lifecycle_change_requested):
		_preset_inspector.lifecycle_change_requested.connect(_on_lifecycle_change_requested)
	if not _preset_inspector.runtime_inputs_committed.is_connected(_on_runtime_inputs_committed):
		_preset_inspector.runtime_inputs_committed.connect(_on_runtime_inputs_committed)
	if not _layer_inspector.layer_field_commit.is_connected(_on_layer_field_commit):
		_layer_inspector.layer_field_commit.connect(_on_layer_field_commit)
	if not _layer_inspector.space_override_changed.is_connected(_on_space_override_changed):
		_layer_inspector.space_override_changed.connect(_on_space_override_changed)
	if not _layer_inspector.layer_type_change_requested.is_connected(_on_layer_type_change_requested):
		_layer_inspector.layer_type_change_requested.connect(_on_layer_type_change_requested)
	if not _layer_inspector.anchors_committed.is_connected(_on_anchors_committed):
		_layer_inspector.anchors_committed.connect(_on_anchors_committed)
	if not _layer_inspector.anchors_cleared.is_connected(_on_anchors_cleared):
		_layer_inspector.anchors_cleared.connect(_on_anchors_cleared)
	_refresh_workspace()


func select_phase(phase_name: String) -> void:
	if _phase_names().has(phase_name):
		_selected_phase = phase_name
		_selected_layer_id = ""
		reconcile_selection()


func select_layer(layer_id: String) -> void:
	_selected_layer_id = layer_id if _layer_exists_in_selected_phase(layer_id) else ""
	_refresh_workspace()


func add_active_layer(layer_type: String) -> bool:
	if _selected_phase.is_empty():
		return false
	return _commit_workspace_change("Add Layer", VfxLayerStackModel.add_layer_with_factory(_layer_factory, _session.working_copy(), _selected_phase, layer_type))


func delete_active_layer(layer_id: String) -> bool:
	if _selected_phase.is_empty():
		return false
	return _commit_workspace_change("Delete Layer", VfxLayerStackModel.delete_layer_in_phase(_session.working_copy(), _selected_phase, layer_id))


func duplicate_active_layer(layer_id: String) -> bool:
	if _selected_phase.is_empty():
		return false
	return _commit_workspace_change("Duplicate Layer", VfxLayerStackModel.duplicate_layer_with_factory(_layer_factory, _session.working_copy(), _selected_phase, layer_id))


func move_active_layer(layer_id: String, direction: int) -> bool:
	if _selected_phase.is_empty():
		return false
	var index := _selected_layer_index(layer_id)
	if index < 0:
		return false
	return _commit_workspace_change("Move Layer", VfxLayerStackModel.move_layer_in_phase(_session.working_copy(), _selected_phase, index, direction))


func set_active_layer_enabled(layer_id: String, enabled: bool) -> bool:
	if _selected_phase.is_empty():
		return false
	return _commit_workspace_change("Set Layer Enabled", VfxLayerStackModel.set_layer_enabled_in_phase(_session.working_copy(), _selected_phase, layer_id, enabled))


func commit_preset_field(json_pointer: String, value: Variant) -> bool:
	if json_pointer == "/default_space_mode" and value is String:
		return _commit_default_space_mode(value)
	return _commit_workspace_change("Edit Preset Field", _replace_json_pointer(_session.working_copy(), json_pointer, _duplicate_value(value)))


func commit_runtime_inputs(inputs: Array[String]) -> bool:
	var declared_inputs: Variant = _registry.schema().get("x_vfx_runtime_inputs", {})
	if not declared_inputs is Dictionary:
		return false
	var requested: Dictionary = {}
	for input_name in inputs:
		requested[input_name] = true
	var ordered: Array[String] = []
	for input_name in declared_inputs:
		if requested.has(input_name):
			ordered.append(input_name)
	return commit_preset_field("/runtime_inputs", ordered)


func commit_phase_duration(phase_name: String, duration_seconds: float) -> bool:
	if not _schema_duration_schemas().has(phase_name):
		return false
	var before := _session.working_copy()
	var next := _replace_json_pointer(before, "/phases/%s/duration_seconds" % _escape_pointer_segment(phase_name), duration_seconds)
	if before == next:
		return false
	_history.record_snapshot("Edit Phase Duration", before, next, _restore_duration_snapshot)
	return true


func commit_selected_layer_field(json_pointer: String, value: Variant) -> bool:
	if json_pointer.begins_with("/parameters/"):
		return commit_selected_layer_parameter(json_pointer.trim_prefix("/parameters"), value)
	var index := _selected_layer_index(_selected_layer_id)
	if _selected_phase.is_empty() or index < 0:
		return false
	var layer_pointer := "/phases/%s/layers/%d%s" % [_escape_pointer_segment(_selected_phase), index, json_pointer]
	var before := _session.working_copy()
	var next := _replace_json_pointer(before, layer_pointer, _duplicate_value(value))
	if before == next:
		return false
	if json_pointer == "/id" and value is String:
		_selected_layer_id = value
	return _commit_workspace_change("Edit Layer Field", next)


func commit_selected_layer_parameter(json_pointer_suffix: String, value: Variant) -> bool:
	var index := _selected_layer_index(_selected_layer_id)
	if _selected_phase.is_empty() or index < 0 or not json_pointer_suffix.begins_with("/"):
		return false
	var pointer := "/phases/%s/layers/%d/parameters%s" % [_escape_pointer_segment(_selected_phase), index, json_pointer_suffix]
	var before := _session.working_copy()
	var edited := _upsert_json_pointer(before, pointer, _duplicate_value(value))
	if before == edited:
		return false
	_prune_particle_selector_fields(edited, index, json_pointer_suffix)
	var built := _pipeline.build_document_from_value(edited, _session.source_path())
	var next: Dictionary = built.value.normalized_data.duplicate(true) if built.success else edited
	return _commit_workspace_change("Edit Layer Parameter", next)


func commit_selected_layer_anchors(anchors: Array) -> bool:
	var anchor_rule := _rule_named(_registry.schema(), "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")
	var anchors_field: String = anchor_rule.get("anchors_field", "")
	if anchors_field.is_empty():
		return false
	return commit_selected_layer_field("/%s" % _escape_pointer_segment(anchors_field), anchors)


func clear_selected_layer_anchors() -> bool:
	var index := _selected_layer_index(_selected_layer_id)
	if _selected_phase.is_empty() or index < 0:
		return false
	var anchor_rule := _rule_named(_registry.schema(), "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")
	var anchors_field: String = anchor_rule.get("anchors_field", "")
	if anchors_field.is_empty():
		return false
	var next := _session.working_copy()
	var layer: Dictionary = next["phases"][_selected_phase]["layers"][index]
	if not layer.has(anchors_field):
		return false
	layer.erase(anchors_field)
	return _commit_workspace_change("Clear Layer Anchors", next)


func set_selected_layer_space_override(mode_or_inherit: String) -> bool:
	var index := _selected_layer_index(_selected_layer_id)
	if _selected_phase.is_empty() or index < 0:
		return false
	var next := _session.working_copy()
	var layer: Dictionary = next["phases"][_selected_phase]["layers"][index]
	if mode_or_inherit == VfxLayerInspectorModel.INHERIT_DEFAULT:
		layer.erase("space_mode")
	else:
		layer["space_mode"] = mode_or_inherit
	if not _apply_effective_space_common_fields(layer):
		return false
	return _commit_workspace_change("Set Layer Space Override", next)


func change_lifecycle(target_mode: String) -> bool:
	var replaced: VfxResult = _structure_change_service.replace_lifecycle(_session.working_copy(), target_mode)
	if not replaced.success:
		_set_issues(replaced.issues)
		return false
	return _commit_workspace_change("Change Lifecycle", replaced.value)


func change_selected_layer_type(target_type: String) -> bool:
	var index := _selected_layer_index(_selected_layer_id)
	if _selected_phase.is_empty() or index < 0:
		return false
	var replaced: VfxResult = _structure_change_service.replace_layer_type(_session.working_copy(), _selected_phase, index, target_type)
	if not replaced.success:
		_set_issues(replaced.issues)
		return false
	return _commit_workspace_change("Change Layer Type", replaced.value)


func request_lifecycle_change(target_mode: String) -> bool:
	if target_mode == _session.working_copy().get("lifecycle", {}).get("mode") or _structure_change_dialog == null:
		return false
	_pending_structure_kind = "lifecycle"
	_pending_structure_target = target_mode
	_structure_change_dialog.request("Lifecycle", target_mode)
	return true


func request_selected_layer_type_change(target_type: String) -> bool:
	var index := _selected_layer_index(_selected_layer_id)
	if index < 0 or _structure_change_dialog == null:
		return false
	var current_layer_type: Variant = _session.working_copy().get("phases", {}).get(_selected_phase, {}).get("layers", [])[index].get("type")
	if target_type == current_layer_type:
		return false
	_pending_structure_kind = "layer_type"
	_pending_structure_target = target_type
	_structure_change_dialog.request("Layer Type", target_type)
	return true


func undo() -> void:
	if _history.can_undo():
		_history.undo()
		_refresh_workspace()
	_refresh_toolbar()


func redo() -> void:
	if _history.can_redo():
		_history.redo()
		_refresh_workspace()
	_refresh_toolbar()


func refresh_validation() -> Array[VfxIssue]:
	_refresh_issues()
	return current_issues()


func reconcile_selection() -> void:
	var names := _phase_names()
	if not names.has(_selected_phase):
		_selected_phase = names[0] if not names.is_empty() else ""
	if not _layer_exists_in_selected_phase(_selected_layer_id):
		_selected_layer_id = ""
	_refresh_workspace()


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
	request_transition("New", func() -> void:
		if _new_preset_dialog != null:
			_new_preset_dialog.popup_centered()
	)


func _on_open_pressed() -> void:
	request_transition("Open", func() -> void:
		_file_dialog_action = "OPEN"
		_show_file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	)


func _on_save_pressed() -> void:
	if _session.source_path().is_empty():
		_file_dialog_action = "SAVE_AS"
		_show_file_dialog(FileDialog.FILE_MODE_SAVE_FILE)
		return
	save()


func _on_save_as_pressed() -> void:
	_file_dialog_action = "SAVE_AS"
	_show_file_dialog(FileDialog.FILE_MODE_SAVE_FILE)


func _on_undo_pressed() -> void:
	undo()


func _on_redo_pressed() -> void:
	redo()


func _on_validate_pressed() -> void:
	refresh_validation()


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
	_set_issues(saved.issues)
	if saved.success:
		_refresh_library()
		reconcile_selection()
	_refresh_toolbar()
	return saved


func _show_file_dialog(mode: FileDialog.FileMode) -> void:
	if _preset_file_dialog == null:
		return
	_preset_file_dialog.file_mode = mode
	_preset_file_dialog.current_dir = _paths.preset_root()
	_preset_file_dialog.popup_centered_ratio()


func _refresh_issues() -> void:
	var built := _pipeline.build_document_from_value(_session.working_copy(), _session.source_path())
	_set_issues(built.issues)


func _set_issues(issues: Array[VfxIssue]) -> void:
	_issues = issues.duplicate()
	if _diagnostics_panel != null:
		_diagnostics_panel.set_issues(_issues)


func _has_unsaved_changes() -> bool:
	return not _session.working_copy().is_empty() and _session.is_dirty()


func _perform_transition(action_name: String, continuation: Callable) -> void:
	_clear_pending_transition()
	_transition_performed = true
	if continuation.is_valid():
		continuation.call()


func _clear_pending_transition() -> void:
	_pending_transition = Callable()
	_pending_transition_name = ""


func _on_unsaved_changes_decision(decision_name: String) -> void:
	if _pending_transition_name.is_empty():
		return
	var action_name := _pending_transition_name
	var continuation := _pending_transition
	if decision_name == "SAVE":
		var saved := save()
		if not saved.success:
			_clear_pending_transition()
			_focus_diagnostics()
			return
		_perform_transition(action_name, continuation)
	elif decision_name == "DISCARD":
		_perform_transition(action_name, continuation)
	else:
		_clear_pending_transition()


func _on_structure_change_confirmed() -> void:
	var kind := _pending_structure_kind
	var target := _pending_structure_target
	_clear_pending_structure_change()
	if kind == "lifecycle":
		change_lifecycle(target)
	elif kind == "layer_type":
		change_selected_layer_type(target)


func _on_structure_change_canceled() -> void:
	_clear_pending_structure_change()
	_refresh_workspace()


func _clear_pending_structure_change() -> void:
	_pending_structure_kind = ""
	_pending_structure_target = ""


func _on_diagnostic_issue_activated(issue: VfxIssue) -> void:
	var route: Dictionary = _diagnostics_navigator.navigate(issue, _session.working_copy())
	if not route.get("handled", false):
		return
	var phase_name: String = route.get("phase_name", "")
	var layer_id: String = route.get("layer_id", "")
	if not phase_name.is_empty():
		select_phase(phase_name)
	if not layer_id.is_empty():
		select_layer(layer_id)
	elif phase_name.is_empty():
		_selected_layer_id = ""
		_refresh_workspace()
	var json_pointer: String = route.get("json_pointer", "")
	if not layer_id.is_empty() and _layer_inspector != null:
		_layer_inspector.focus_json_pointer(_layer_pointer_suffix(json_pointer, phase_name, layer_id))
	elif not phase_name.is_empty() and _phase_tabs != null:
		_phase_tabs.focus_json_pointer(json_pointer)
	elif phase_name.is_empty() and _preset_inspector != null:
		_preset_inspector.focus_json_pointer(json_pointer)


func _layer_pointer_suffix(json_pointer: String, phase_name: String, layer_id: String) -> String:
	var phases: Variant = _session.working_copy().get("phases")
	if not phases is Dictionary or not phases.has(phase_name) or not phases[phase_name] is Dictionary:
		return ""
	var layers: Variant = phases[phase_name].get("layers")
	if not layers is Array:
		return ""
	for index in layers.size():
		if layers[index] is Dictionary and layers[index].get("id") == layer_id:
			var prefix := "/phases/%s/layers/%d" % [_escape_pointer_segment(phase_name), index]
			return json_pointer.trim_prefix(prefix)
	return ""


func _focus_diagnostics() -> void:
	if _diagnostics_panel != null and _diagnostics_panel.is_inside_tree():
		_diagnostics_panel.focus_diagnostics()


func _on_phase_selected(phase_name: String) -> void:
	if _refreshing_workspace:
		return
	select_phase(phase_name)


func _on_phase_duration_committed(phase_name: String, duration_seconds: float) -> void:
	commit_phase_duration(phase_name, duration_seconds)


func _on_library_filter_changed(_query: String, _category: String) -> void:
	_refresh_library_filter()


func _on_library_preset_open_requested(entry: RefCounted) -> void:
	request_transition("Open", func() -> void: open_library_entry(entry))


func _on_library_invalid_entry_selected(entry: RefCounted) -> void:
	if entry != null:
		_set_issues(entry.issues)
		_focus_diagnostics()


func _on_layer_selected(layer_id: String) -> void:
	select_layer(layer_id)


func _on_add_layer_requested(layer_type: String) -> void:
	add_active_layer(layer_type)


func _on_delete_layer_requested(layer_id: String) -> void:
	delete_active_layer(layer_id)


func _on_duplicate_layer_requested(layer_id: String) -> void:
	duplicate_active_layer(layer_id)


func _on_move_layer_requested(layer_id: String, direction: int) -> void:
	move_active_layer(layer_id, direction)


func _on_layer_enabled_requested(layer_id: String, enabled: bool) -> void:
	set_active_layer_enabled(layer_id, enabled)


func _on_preset_field_commit(json_pointer: String, value: Variant) -> void:
	commit_preset_field(json_pointer, value)


func _on_lifecycle_change_requested(target_mode: String) -> void:
	request_lifecycle_change(target_mode)


func _on_runtime_inputs_committed(inputs: Array[String]) -> void:
	commit_runtime_inputs(inputs)


func _on_layer_field_commit(json_pointer: String, value: Variant) -> void:
	commit_selected_layer_field(json_pointer, value)


func _on_space_override_changed(mode_or_inherit: String) -> void:
	set_selected_layer_space_override(mode_or_inherit)


func _on_anchors_committed(anchors: Array) -> void:
	commit_selected_layer_anchors(anchors)


func _on_anchors_cleared() -> void:
	clear_selected_layer_anchors()


func _on_layer_type_change_requested(target_type: String) -> void:
	layer_type_change_confirmation_requested.emit(target_type)
	request_selected_layer_type_change(target_type)


func _commit_workspace_change(label: String, next_data: Dictionary) -> bool:
	var before := _session.working_copy()
	if before == next_data:
		return false
	_history.record_snapshot(label, before, next_data, _restore_workspace_snapshot)
	return true


func _restore_workspace_snapshot(snapshot: Dictionary) -> void:
	_session.replace_working_data(snapshot)
	_refresh_issues()
	reconcile_selection()


func _restore_duration_snapshot(snapshot: Dictionary) -> void:
	_session.replace_working_data(snapshot)
	_refresh_issues()
	_refresh_workspace(false)


func _phase_names() -> Array[String]:
	var names: Array[String] = []
	for phase_name_variant in _session.working_copy().get("phases", {}):
		names.append(str(phase_name_variant))
	return names


func _layer_exists_in_selected_phase(layer_id: String) -> bool:
	if layer_id.is_empty():
		return false
	for layer in _session.working_copy().get("phases", {}).get(_selected_phase, {}).get("layers", []):
		if layer is Dictionary and layer.get("id") == layer_id:
			return true
	return false


func _selected_layer_index(layer_id: String) -> int:
	var layers: Array = _session.working_copy().get("phases", {}).get(_selected_phase, {}).get("layers", [])
	for index in layers.size():
		if layers[index] is Dictionary and layers[index].get("id") == layer_id:
			return index
	return -1


func _refresh_workspace(refresh_phase_tabs: bool = true) -> void:
	_refreshing_workspace = refresh_phase_tabs
	if _phase_tabs != null and refresh_phase_tabs:
		_phase_tabs.set_preset(_session.working_copy())
		_phase_tabs.select_phase(_selected_phase)
	if _layer_stack != null:
		_layer_stack.set_phase(_session.working_copy(), _selected_phase)
		_layer_stack.set_selected_layer_id(_selected_layer_id)
	if _preset_inspector != null:
		_preset_inspector.set_preset(_session.working_copy())
	if _layer_inspector != null:
		var index := _selected_layer_index(_selected_layer_id)
		_layer_inspector.visible = index >= 0
		var layer: Dictionary = _session.working_copy()["phases"][_selected_phase]["layers"][index] if index >= 0 else {}
		_layer_inspector.set_layer(layer)
		_layer_inspector.set_effective_space(_effective_space_for_layer(layer))
	_refreshing_workspace = false
	_refresh_preview()
	_refresh_toolbar()


func _refresh_preview() -> void:
	if _preview == null or _preview_context_resolver == null:
		return
	_preview.set_preview_phase(_selected_phase)
	_preview.set_layer_context(_preview_context_resolver.resolve(_session.working_copy(), _selected_phase, _selected_layer_id))
	var document_result: VfxResult = _pipeline.build_document_from_value(_session.working_copy())
	if not document_result.success:
		_preview.set_preview_validation_state(document_result.issues)
		return
	var normalized_data: Dictionary = document_result.value.normalized_data
	if not _has_last_preview_normalized_data or _last_preview_normalized_data != normalized_data:
		var plan_result: VfxResult = _preview_render_plan_builder.build(normalized_data)
		if not plan_result.success:
			_preview.set_preview_validation_state(plan_result.issues)
			return
		_preview.apply_render_plan(plan_result.value)
		_last_preview_normalized_data = normalized_data.duplicate(true)
		_has_last_preview_normalized_data = true
	_preview.set_preview_validation_state([])


func _load_preview_profiles() -> Array:
	var documents: Array = []
	if _vehicle_profile_repository == null:
		return documents
	for profile_path in _vehicle_profile_repository.list_profile_paths():
		var loaded: VfxResult = _vehicle_profile_repository.load_profile(profile_path)
		if loaded.success:
			documents.append(loaded.value)
	return documents


func _load_preview_game_scale_contract() -> Dictionary:
	var loaded: VfxResult = VfxPresetCodecModel.new().decode_file("res://profiles/preview/game_display_scale_v1.json")
	return loaded.value.duplicate(true) if loaded.success and loaded.value is Dictionary else {}


func _refresh_library() -> void:
	_library.scan()
	_refresh_library_filter()


func _refresh_library_filter() -> void:
	if _library_panel != null:
		_library_panel.set_entries(_library.filter(_library_panel.current_query(), _library_panel.current_category()))


func _refresh_toolbar() -> void:
	if _toolbar == null:
		return
	var has_session := not _session.working_copy().is_empty()
	var save_button := _toolbar.get_node_or_null("SaveButton") as Button
	var save_as_button := _toolbar.get_node_or_null("SaveAsButton") as Button
	var undo_button := _toolbar.get_node_or_null("UndoButton") as Button
	var redo_button := _toolbar.get_node_or_null("RedoButton") as Button
	var dirty_indicator := _toolbar.get_node_or_null("DirtyIndicator") as Label
	if save_button != null:
		save_button.disabled = not has_session or _session.source_path().is_empty()
	if save_as_button != null:
		save_as_button.disabled = not has_session
	if undo_button != null:
		undo_button.disabled = not _history.can_undo()
	if redo_button != null:
		redo_button.disabled = not _history.can_redo()
	var validate_button := _toolbar.get_node_or_null("ValidateButton") as Button
	if validate_button != null:
		validate_button.disabled = not has_session
	if dirty_indicator != null:
		dirty_indicator.text = "Unsaved" if has_session and _session.is_dirty() else ""


func _schema_duration_schemas() -> Dictionary:
	var reader := VfxSchemaReaderModel.new(_registry)
	var phases_schema := reader.property_schema(reader.root_schema(), "phases")
	if not phases_schema.success:
		return {}
	var resolved_phases := reader.resolve(phases_schema.value)
	if not resolved_phases.success:
		return {}
	var schemas: Dictionary = {}
	for phase_name in (resolved_phases.value as Dictionary).get("properties", {}):
		var phase_schema := reader.property_schema(resolved_phases.value, phase_name)
		if not phase_schema.success:
			continue
		var duration_schema := reader.property_schema(phase_schema.value, "duration_seconds")
		if duration_schema.success:
			schemas[phase_name] = duration_schema.value
	return schemas


func _commit_default_space_mode(target_space: String) -> bool:
	var root_schema := _registry.schema()
	var render_rule := _rule_named(root_schema, "RENDER_PLANE_FOR_EFFECTIVE_SPACE")
	if render_rule.is_empty():
		return false
	var default_space_field: String = render_rule.get("default_space_field", "")
	var layer_space_field: String = render_rule.get("layer_space_field", "")
	var phases_field: String = str(render_rule.get("phases_path", "")).trim_prefix("/")
	if default_space_field.is_empty() or layer_space_field.is_empty() or phases_field.is_empty():
		return false
	var next := _session.working_copy()
	next[default_space_field] = target_space
	var phases: Variant = next.get(phases_field)
	if not phases is Dictionary:
		return false
	for phase in phases.values():
		if not phase is Dictionary:
			continue
		var layers: Variant = phase.get("layers")
		if not layers is Array:
			continue
		for layer in layers:
			if layer is Dictionary and not layer.has(layer_space_field):
				if not _apply_effective_space_common_fields(layer, target_space):
					return false
	return _commit_workspace_change("Set Default Space Mode", next)


func _apply_effective_space_common_fields(layer: Dictionary, inherited_default_space: String = "") -> bool:
	var root_schema := _registry.schema()
	var anchor_rule := _rule_named(root_schema, "EFFECTIVE_SPACE_ANCHOR_REQUIREMENTS")
	var render_rule := _rule_named(root_schema, "RENDER_PLANE_FOR_EFFECTIVE_SPACE")
	if anchor_rule.is_empty() or render_rule.is_empty():
		return false
	var effective_space := _effective_space_for_layer(layer, inherited_default_space)
	var anchors_field: String = anchor_rule.get("anchors_field", "")
	if anchor_rule.get("vehicle_space_modes", []).has(effective_space):
		var anchors: Variant = layer.get(anchors_field)
		if anchors_field.is_empty() or not anchors is Array or anchors.is_empty():
			var center_anchor: VfxResult = _layer_factory._center_anchor()
			if not center_anchor.success:
				_issues = center_anchor.issues.duplicate()
				return false
			layer[anchors_field] = [center_anchor.value]
	elif not anchors_field.is_empty():
		layer.erase(anchors_field)
	var render_plane_field: String = render_rule.get("render_plane_field", "")
	var allowed_planes: Variant = render_rule.get("allowed_planes_by_space", {}).get(effective_space, [])
	if not render_plane_field.is_empty() and allowed_planes is Array and not allowed_planes.is_empty():
		layer[render_plane_field] = allowed_planes[0]
		return true
	return false


func _effective_space_for_layer(layer: Dictionary, inherited_default_space: String = "") -> String:
	var render_rule := _rule_named(_registry.schema(), "RENDER_PLANE_FOR_EFFECTIVE_SPACE")
	var default_space_field: String = render_rule.get("default_space_field", "")
	var layer_space_field: String = render_rule.get("layer_space_field", "")
	if layer_space_field.is_empty() or default_space_field.is_empty():
		return ""
	var default_space := inherited_default_space if not inherited_default_space.is_empty() else str(_session.working_copy().get(default_space_field, ""))
	return str(layer.get(layer_space_field, default_space))


func _replace_json_pointer(source: Dictionary, pointer: String, value: Variant) -> Dictionary:
	if not pointer.begins_with("/"):
		return source.duplicate(true)
	var next := source.duplicate(true)
	var segments := pointer.trim_prefix("/").split("/")
	var current: Variant = next
	for index in segments.size() - 1:
		var segment := segments[index].replace("~1", "/").replace("~0", "~")
		if current is Dictionary:
			if not current.has(segment):
				return source.duplicate(true)
			current = current[segment]
		elif current is Array:
			if not segment.is_valid_int() or int(segment) < 0 or int(segment) >= current.size():
				return source.duplicate(true)
			current = current[int(segment)]
		else:
			return source.duplicate(true)
	var final_segment := segments[segments.size() - 1].replace("~1", "/").replace("~0", "~")
	if current is Dictionary:
		if not current.has(final_segment):
			return source.duplicate(true)
		current[final_segment] = value
	elif current is Array and final_segment.is_valid_int() and int(final_segment) >= 0 and int(final_segment) < current.size():
		current[int(final_segment)] = value
	else:
		return source.duplicate(true)
	return next


func _upsert_json_pointer(source: Dictionary, pointer: String, value: Variant) -> Dictionary:
	if not pointer.begins_with("/"):
		return source.duplicate(true)
	var next := source.duplicate(true)
	var segments := pointer.trim_prefix("/").split("/")
	var current: Variant = next
	for index in segments.size() - 1:
		var segment := segments[index].replace("~1", "/").replace("~0", "~")
		if current is Dictionary:
			if not current.has(segment):
				return source.duplicate(true)
			current = current[segment]
		elif current is Array:
			if not segment.is_valid_int() or int(segment) < 0 or int(segment) >= current.size():
				return source.duplicate(true)
			current = current[int(segment)]
		else:
			return source.duplicate(true)
	var final_segment := segments[segments.size() - 1].replace("~1", "/").replace("~0", "~")
	if current is Dictionary:
		current[final_segment] = value
	elif current is Array and final_segment.is_valid_int() and int(final_segment) >= 0 and int(final_segment) < current.size():
		current[int(final_segment)] = value
	else:
		return source.duplicate(true)
	return next


func _prune_particle_selector_fields(preset: Dictionary, layer_index: int, pointer_suffix: String) -> void:
	var layer: Dictionary = preset["phases"][_selected_phase]["layers"][layer_index]
	var parameters: Variant = layer.get("parameters")
	if not parameters is Dictionary:
		return
	var root_schema := _registry.schema()
	var emission_rule := _rule_named(root_schema, "PARTICLE_EMISSION_CONFIGURATION")
	if emission_rule.get("particle_type") == layer.get("type"):
		var mode_field: String = emission_rule["emission_mode_field"]
		if pointer_suffix == "/%s" % _escape_pointer_segment(mode_field):
			var requirements: Variant = emission_rule.get("mode_requirements", {}).get(parameters.get(mode_field))
			if requirements is Dictionary:
				for forbidden_field in requirements.get("forbidden_fields", []):
					parameters.erase(forbidden_field)
	var emitter_rule := _rule_named(root_schema, "PARTICLE_EMITTER_SHAPE")
	if emitter_rule.get("particle_type") != layer.get("type"):
		return
	var emitter_field: String = emitter_rule["emitter_field"]
	var shape_field: String = emitter_rule["shape_field"]
	if pointer_suffix != "/%s/%s" % [_escape_pointer_segment(emitter_field), _escape_pointer_segment(shape_field)]:
		return
	var emitter: Variant = parameters.get(emitter_field)
	if not emitter is Dictionary:
		return
	var geometry_by_shape: Dictionary = emitter_rule.get("geometry_by_shape", {})
	var allowed_geometry: Variant = geometry_by_shape.get(emitter.get(shape_field))
	if not allowed_geometry is Array:
		return
	var all_geometry_fields: Array = []
	for configured_geometry in geometry_by_shape.values():
		for geometry_field in configured_geometry:
			if not all_geometry_fields.has(geometry_field):
				all_geometry_fields.append(geometry_field)
	for geometry_field in all_geometry_fields:
		if not allowed_geometry.has(geometry_field):
			emitter.erase(geometry_field)


func _rule_named(root_schema: Dictionary, rule_name: String) -> Dictionary:
	for rule in root_schema.get("x_vfx_rules", []):
		if rule is Dictionary and rule.get("name") == rule_name:
			return rule
	return {}


func _duplicate_value(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


func _escape_pointer_segment(value: String) -> String:
	return value.replace("~", "~0").replace("/", "~1")


func _policy_failure(code: String, message: String, path: String) -> VfxResult:
	return VfxResult.failure([VfxIssue.new("EDITOR_POLICY", code, message, "", path)])
