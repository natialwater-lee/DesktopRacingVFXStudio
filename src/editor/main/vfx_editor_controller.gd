class_name VfxEditorController
extends RefCounted

signal layer_type_change_confirmation_requested(target_type: String)

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

var _paths: VfxAuthoringPaths
var _pipeline: VfxPresetPipeline
var _registry: VfxSchemaRegistry
var _session: VfxPresetEditSession
var _history: VfxPresetHistory
var _skeleton_factory: RefCounted
var _layer_factory: RefCounted
var _structure_change_service: RefCounted
var _library: RefCounted
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _history != null:
		_history.dispose()


func request_close() -> bool:
	return true


func create_new_preset(preset_id: String, display_name: String, category: String, lifecycle_mode: String, default_space_mode: String) -> VfxResult:
	var created: VfxResult = _skeleton_factory.create(preset_id, display_name, category, lifecycle_mode, default_space_mode)
	if not created.success:
		_issues = created.issues.duplicate()
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
		return _policy_failure("outside_authoring_root", "Preset files must be opened below the configured authoring root.", path)
	if not normalized.ends_with(".vfx.json"):
		return _policy_failure("invalid_preset_extension", "Preset files must use the .vfx.json extension.", path)
	var loaded := _pipeline.load_and_validate(normalized)
	if not loaded.success:
		_issues = loaded.issues.duplicate()
		return loaded
	_history.clear()
	_session.open_document(loaded.value)
	_refresh_issues()
	reconcile_selection()
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


func working_preset() -> Dictionary:
	return _session.working_copy()


func selected_phase_name() -> String:
	return _selected_phase


func selected_layer_id() -> String:
	return _selected_layer_id


func can_undo() -> bool:
	return _history.can_undo()


func configure_workspace(phase_tabs, layer_stack) -> void:
	_phase_tabs = phase_tabs
	_layer_stack = layer_stack
	_layer_stack.set_layer_factory(_layer_factory)
	_layer_stack.set_available_layer_types(_registry.schema().get("x_vfx_layer_types", {}).keys())
	if not _phase_tabs.phase_selected.is_connected(_on_phase_selected):
		_phase_tabs.phase_selected.connect(_on_phase_selected)
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
	if not _layer_inspector.layer_field_commit.is_connected(_on_layer_field_commit):
		_layer_inspector.layer_field_commit.connect(_on_layer_field_commit)
	if not _layer_inspector.space_override_changed.is_connected(_on_space_override_changed):
		_layer_inspector.space_override_changed.connect(_on_space_override_changed)
	if not _layer_inspector.layer_type_change_requested.is_connected(_on_layer_type_change_requested):
		_layer_inspector.layer_type_change_requested.connect(_on_layer_type_change_requested)
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
	return _commit_workspace_change("Edit Preset Field", _replace_json_pointer(_session.working_copy(), json_pointer, _duplicate_value(value)))


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
	return _commit_workspace_change("Set Layer Space Override", next)


func change_lifecycle(target_mode: String) -> bool:
	var replaced: VfxResult = _structure_change_service.replace_lifecycle(_session.working_copy(), target_mode)
	if not replaced.success:
		_issues = replaced.issues.duplicate()
		return false
	return _commit_workspace_change("Change Lifecycle", replaced.value)


func change_selected_layer_type(target_type: String) -> bool:
	var index := _selected_layer_index(_selected_layer_id)
	if _selected_phase.is_empty() or index < 0:
		return false
	var replaced: VfxResult = _structure_change_service.replace_layer_type(_session.working_copy(), _selected_phase, index, target_type)
	if not replaced.success:
		_issues = replaced.issues.duplicate()
		return false
	return _commit_workspace_change("Change Layer Type", replaced.value)


func undo() -> void:
	if _history.can_undo():
		_history.undo()


func redo() -> void:
	if _history.can_redo():
		_history.redo()


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


func _on_phase_selected(phase_name: String) -> void:
	select_phase(phase_name)


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
	change_lifecycle(target_mode)


func _on_layer_field_commit(json_pointer: String, value: Variant) -> void:
	commit_selected_layer_field(json_pointer, value)


func _on_space_override_changed(mode_or_inherit: String) -> void:
	set_selected_layer_space_override(mode_or_inherit)


func _on_layer_type_change_requested(target_type: String) -> void:
	layer_type_change_confirmation_requested.emit(target_type)


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


func _refresh_workspace() -> void:
	if _phase_tabs != null:
		_phase_tabs.set_preset(_session.working_copy())
		_phase_tabs.select_phase(_selected_phase)
	if _layer_stack != null:
		_layer_stack.set_phase(_session.working_copy(), _selected_phase)
	if _preset_inspector != null:
		_preset_inspector.set_preset(_session.working_copy())
	if _layer_inspector != null:
		var index := _selected_layer_index(_selected_layer_id)
		_layer_inspector.visible = index >= 0
		_layer_inspector.set_layer(_session.working_copy()["phases"][_selected_phase]["layers"][index] if index >= 0 else {})


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
