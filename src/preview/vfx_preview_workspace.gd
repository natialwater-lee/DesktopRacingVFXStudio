class_name VfxPreviewWorkspace
extends VBoxContainer

const VfxVehiclePreviewScene := preload("res://src/preview/vfx_vehicle_preview.tscn")
const VfxPerformancePanelModel := preload("res://src/editor/performance/vfx_performance_panel.gd")
const VfxExportPanelModel := preload("res://src/editor/export/vfx_export_panel.gd")

var _preview: Variant
var _performance_panel: Variant
var _export_panel: Variant
var _mode_select: OptionButton
var _registry: RefCounted
var _source_plan: RefCounted


func _ready() -> void:
	_build_workspace()


func set_schema_registry(registry: RefCounted) -> void:
	_registry = registry
	_with_preview("set_schema_registry", [registry])
	_sync_performance_panel()


func set_profile_repository(repository: RefCounted) -> void:
	_with_preview("set_profile_repository", [repository])


func set_profile_documents(documents: Array) -> void:
	_with_preview("set_profile_documents", [documents])
	_sync_performance_panel()


func set_profile_data(profile_data: Dictionary) -> void:
	_with_preview("set_profile_data", [profile_data])
	_sync_performance_panel()


func set_game_scale_contract(game_scale_contract: Dictionary) -> void:
	_with_preview("set_game_scale_contract", [game_scale_contract])
	_sync_performance_panel()


func set_preview_phase(phase_name: String) -> void:
	_with_preview("set_preview_phase", [phase_name])


func set_layer_context(layer_context: RefCounted) -> void:
	_with_preview("set_layer_context", [layer_context])


func set_preview_validation_state(issues: Array) -> void:
	_with_preview("set_preview_validation_state", [issues])


func apply_render_plan(render_plan: RefCounted) -> void:
	_source_plan = render_plan
	_with_preview("apply_render_plan", [render_plan])
	_sync_performance_panel()


func set_preview_lod_level(lod_level: String) -> void:
	_with_preview("set_preview_lod_level", [lod_level])


func active_render_plan() -> RefCounted:
	return _preview.active_render_plan() if _preview != null and _preview.has_method("active_render_plan") else null


func preview_status_text() -> String:
	return _preview.preview_status_text() if _preview != null and _preview.has_method("preview_status_text") else "PREVIEW — NO VALID PLAN"


func shared_state() -> RefCounted:
	return _preview.shared_state() if _preview != null and _preview.has_method("shared_state") else null


func get_future_vfx_host(canvas_name: String) -> Node2D:
	return _preview.get_future_vfx_host(canvas_name) if _preview != null and _preview.has_method("get_future_vfx_host") else null


func vehicle_preview() -> Node:
	return _preview if _preview is Node else null


func export_panel() -> Node:
	return _export_panel if _export_panel is Node else null


func configure_export_panel(controller: RefCounted) -> void:
	if _export_panel != null and _export_panel.has_method("configure"):
		_export_panel.configure(controller)


func _build_workspace() -> void:
	if _preview != null:
		return
	name = "VfxPreviewWorkspace"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var controls := HBoxContainer.new()
	controls.name = "WorkspaceControls"
	add_child(controls)
	var mode_label := Label.new()
	mode_label.text = "PREVIEW MODE"
	controls.add_child(mode_label)
	_mode_select = OptionButton.new()
	_mode_select.name = "PreviewModeSelect"
	_mode_select.add_item("AUTHORING PREVIEW")
	_mode_select.add_item("PERFORMANCE")
	_mode_select.add_item("EXPORT")
	_mode_select.select(0)
	_mode_select.item_selected.connect(_on_mode_selected)
	controls.add_child(_mode_select)
	_preview = VfxVehiclePreviewScene.instantiate()
	_preview.name = "VfxVehiclePreview"
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_preview)
	_performance_panel = VfxPerformancePanelModel.new()
	_performance_panel.name = "PerformancePanel"
	_performance_panel.visible = false
	add_child(_performance_panel)
	_export_panel = VfxExportPanelModel.new()
	_export_panel.name = "ExportPanel"
	_export_panel.visible = false
	add_child(_export_panel)
	_sync_performance_panel()


func _on_mode_selected(index: int) -> void:
	var authoring_preview := index == 0
	var performance := index == 1
	var export_mode := index == 2
	if _preview != null:
		_preview.visible = authoring_preview
	if _performance_panel != null:
		_performance_panel.visible = performance
	if _export_panel != null:
		_export_panel.visible = export_mode
	if performance:
		_sync_performance_panel()
	if export_mode and _export_panel != null and _export_panel.has_method("refresh_validation"):
		_export_panel.refresh_validation()


func _sync_performance_panel() -> void:
	if _performance_panel == null or not _performance_panel.has_method("configure"):
		return
	var profile_data: Dictionary = _preview.shared_state().profile_data() if _preview != null and _preview.has_method("shared_state") else {}
	var game_scale_contract: Dictionary = _preview.shared_state().game_scale_contract() if _preview != null and _preview.has_method("shared_state") else {}
	var track_scale: float = _preview.shared_state().track_scale() if _preview != null and _preview.has_method("shared_state") else 1.0
	_performance_panel.configure(_registry, _source_plan, profile_data, game_scale_contract, track_scale)


func _with_preview(method_name: String, arguments: Array) -> void:
	if _preview != null and _preview.has_method(method_name):
		_preview.callv(method_name, arguments)
