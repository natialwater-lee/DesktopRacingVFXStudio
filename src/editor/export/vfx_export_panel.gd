class_name VfxExportPanel
extends VBoxContainer

const VfxExportPathsModel := preload("res://src/export/vfx_export_paths.gd")

var _controller: RefCounted
var _preset_id_label: Label
var _package_root_label: Label
var _status_label: Label
var _requirements_label: Label
var _validate_button: Button
var _export_button: Button
var _replace_confirmation: ConfirmationDialog
var _last_validation: VfxResult
var _last_export: VfxResult
var _replace_pending := false


func _ready() -> void:
	_ensure_ui()


func configure(controller: RefCounted) -> void:
	_controller = controller
	_ensure_ui()
	refresh_validation()


func refresh_validation() -> VfxResult:
	_ensure_ui()
	var result: VfxResult = _validation_gate()
	if result.success:
		result = _controller.validate_active_export()
	present_validation(result)
	return result


func present_validation(result: VfxResult) -> void:
	_last_validation = result
	if result.success:
		var plan: Variant = result.value
		var manifest: Dictionary = plan.manifest_data() if plan != null and plan.has_method("manifest_data") else {}
		var preset: Dictionary = manifest.get("preset", {}) if manifest.get("preset") is Dictionary else {}
		_preset_id_label.text = "Preset ID: %s" % str(preset.get("preset_id", manifest.get("package_id", "Unknown")))
		_requirements_label.text = _requirements_text(manifest)
		_status_label.text = "READY"
		_export_button.disabled = false
		return
	_preset_id_label.text = "Preset ID: %s" % (_controller.active_export_source_path().get_file().trim_suffix(".vfx.json") if _controller != null and _controller.has_method("active_export_source_path") else "No saved Preset")
	_requirements_label.text = "Requirements are available after successful saved-source validation."
	_status_label.text = "WARNING — %s" % _first_message(result) if _has_warning_only(result) else "BLOCKED — %s" % _first_message(result)
	_export_button.disabled = true


func present_export_result(result: VfxResult) -> void:
	_last_export = result
	if result.success:
		_status_label.text = "READY — Package written to fixed Studio root"
		return
	_status_label.text = "WARNING — %s" % _first_message(result) if _has_warning_only(result) else "BLOCKED — %s" % _first_message(result)


func validation_status_text() -> String:
	return _status_label.text if _status_label != null else "BLOCKED"


func package_root_text() -> String:
	return VfxExportPathsModel.PACKAGE_ROOT


func requirement_summary_text() -> String:
	return _requirements_label.text if _requirements_label != null else ""


func replace_confirmation_visible() -> bool:
	return _replace_pending


func request_export() -> void:
	var validation: VfxResult = refresh_validation()
	if not validation.success:
		return
	var result: VfxResult = _controller.export_active_preset(false)
	if not result.success and _has_issue(result, "export_package_exists"):
		_show_replace_confirmation()
		return
	present_export_result(result)


func confirm_replace_export() -> void:
	if not _replace_pending or _controller == null:
		return
	_replace_pending = false
	if _replace_confirmation != null:
		_replace_confirmation.hide()
	present_export_result(_controller.export_active_preset(true))


func _ensure_ui() -> void:
	if _status_label != null:
		return
	name = "ExportPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := Label.new()
	heading.name = "ExportHeading"
	heading.text = "EXPORT PACKAGE"
	add_child(heading)
	_preset_id_label = Label.new()
	_preset_id_label.name = "PresetId"
	_preset_id_label.text = "Preset ID: No saved Preset"
	add_child(_preset_id_label)
	_package_root_label = Label.new()
	_package_root_label.name = "PackageRoot"
	_package_root_label.text = "Studio Package Root: %s" % package_root_text()
	add_child(_package_root_label)
	_status_label = Label.new()
	_status_label.name = "ValidationStatus"
	_status_label.text = "BLOCKED — Open and save a Preset before Export."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)
	_requirements_label = Label.new()
	_requirements_label.name = "Requirements"
	_requirements_label.text = "Requirements are available after successful saved-source validation."
	_requirements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_requirements_label)
	var actions := HBoxContainer.new()
	actions.name = "ExportActions"
	add_child(actions)
	_validate_button = Button.new()
	_validate_button.name = "ValidateExport"
	_validate_button.text = "Validate Saved Source"
	_validate_button.pressed.connect(refresh_validation)
	actions.add_child(_validate_button)
	_export_button = Button.new()
	_export_button.name = "ExportPackage"
	_export_button.text = "Export Package"
	_export_button.disabled = true
	_export_button.pressed.connect(request_export)
	actions.add_child(_export_button)
	_replace_confirmation = ConfirmationDialog.new()
	_replace_confirmation.name = "ReplaceExportPackageConfirmation"
	_replace_confirmation.title = "Replace Export Package"
	_replace_confirmation.dialog_text = "A Package already exists at the fixed Studio Package root. Replace it?"
	_replace_confirmation.confirmed.connect(confirm_replace_export)
	add_child(_replace_confirmation)


func _validation_gate() -> VfxResult:
	if _controller == null:
		return VfxResult.failure([VfxIssue.new("EXPORT_VALIDATION", "export_controller_missing", "Export panel is not configured with an Editor controller.")])
	if not _controller.has_method("active_export_source_path") or str(_controller.active_export_source_path()).is_empty():
		return VfxResult.failure([VfxIssue.new("EXPORT_VALIDATION", "export_unsaved_preset", "Save the Preset before validating or exporting a Package.")])
	if not _controller.has_method("active_export_is_dirty") or bool(_controller.active_export_is_dirty()):
		return VfxResult.failure([VfxIssue.new("EXPORT_VALIDATION", "export_dirty_preset", "Save or revert current Preset changes before exporting a Package.")])
	return VfxResult.ok(null)


func _requirements_text(manifest: Dictionary) -> String:
	var requirements: Dictionary = manifest.get("requirements", {}) if manifest.get("requirements") is Dictionary else {}
	var assets: Array = manifest.get("asset_dependencies", []) if manifest.get("asset_dependencies") is Array else []
	var anchors: Array = requirements.get("required_vehicle_anchors", []) if requirements.get("required_vehicle_anchors") is Array else []
	var inputs: Array = requirements.get("runtime_inputs", []) if requirements.get("runtime_inputs") is Array else []
	var asset_ids: Array[String] = []
	for dependency in assets:
		if dependency is Dictionary:
			asset_ids.append(str(dependency.get("logical_id", "")))
	return "Anchors: %s | Runtime Inputs: %s | Assets: %s" % [", ".join(anchors), ", ".join(inputs), ", ".join(asset_ids)]


func _show_replace_confirmation() -> void:
	_replace_pending = true
	if _replace_confirmation == null:
		return
	if is_inside_tree():
		_replace_confirmation.popup_centered()
	else:
		_replace_confirmation.show()


func _has_issue(result: VfxResult, code: String) -> bool:
	for issue in result.issues:
		if issue.code == code:
			return true
	return false


func _has_warning_only(result: VfxResult) -> bool:
	return not result.issues.is_empty() and not result.issues.any(func(issue: VfxIssue) -> bool: return issue.severity == "ERROR")


func _first_message(result: VfxResult) -> String:
	return result.issues[0].message if not result.issues.is_empty() else "No Export details available."
