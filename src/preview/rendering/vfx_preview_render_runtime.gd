class_name VfxPreviewRenderRuntime
extends RefCounted

const VfxPreviewInstanceResolverModel := preload("res://src/preview/rendering/vfx_preview_instance_resolver.gd")

var _plan: RefCounted
var _instances_by_phase: Dictionary = {}
var _entries: Array[Dictionary] = []
var _factory: RefCounted
var _asset_resolver: RefCounted
var _issues: Array[VfxIssue] = []


func _init(plan: RefCounted, profile_data: Dictionary, registry: RefCounted, factory: RefCounted, asset_resolver: RefCounted) -> void:
	_plan = plan
	_factory = factory
	_asset_resolver = asset_resolver
	var resolved: VfxResult = VfxPreviewInstanceResolverModel.new(registry).resolve(plan, profile_data)
	if resolved.success:
		for instance in resolved.value:
			var phase_name: String = instance.phase_name()
			if not _instances_by_phase.has(phase_name):
				_instances_by_phase[phase_name] = []
			_instances_by_phase[phase_name].append(instance)
	_issues = resolved.issues.duplicate()


func activate_phase(phase_name: String, frame_context: Dictionary) -> void:
	for instance in _instances_by_phase.get(phase_name, []):
		var layer_spec: RefCounted = instance.layer_spec()
		if not layer_spec.is_enabled():
			continue
		var asset_result := _resolve_asset(layer_spec)
		_issues.append_array(asset_result.issues)
		if not asset_result.success:
			continue
		var renderer_script: Variant = _factory.renderer_registration(layer_spec.layer_type()) if _factory != null else null
		if not renderer_script is Script:
			continue
		var renderer: RefCounted = renderer_script.new(instance, asset_result.value)
		renderer.restart(frame_context)
		_entries.append({"phase_name": phase_name, "renderer": renderer})


func stop_phase_sources(phase_name: String) -> void:
	for entry in _entries:
		if entry.get("phase_name") == phase_name:
			(entry.get("renderer") as RefCounted).stop_emission()


func advance(delta_seconds: float, frame_context: Dictionary) -> void:
	var active_entries: Array[Dictionary] = []
	for entry in _entries:
		var renderer: RefCounted = entry.get("renderer")
		renderer.advance(delta_seconds, frame_context)
		if renderer.is_source_active() or renderer.has_residual():
			active_entries.append(entry)
	_entries = active_entries


func clear() -> void:
	for entry in _entries:
		(entry.get("renderer") as RefCounted).clear()
	_entries.clear()
	_issues.clear()


func has_residual() -> bool:
	for entry in _entries:
		var renderer: RefCounted = entry.get("renderer")
		if renderer.is_source_active() or renderer.has_residual():
			return true
	return false


func active_renderer_count() -> int:
	return _entries.size()


func draw_packets() -> Array:
	var packets: Array = []
	for entry in _entries:
		packets.append_array((entry.get("renderer") as RefCounted).draw_packets())
	return packets


func issues() -> Array[VfxIssue]:
	return _issues.duplicate()


func _resolve_asset(layer_spec: RefCounted) -> VfxResult:
	var parameters: Dictionary = layer_spec.parameters()
	var logical_id := ""
	if parameters.has("sprite_asset_ref"):
		logical_id = str(parameters.get("sprite_asset_ref"))
	elif parameters.has("texture_asset_ref"):
		logical_id = str(parameters.get("texture_asset_ref"))
	if logical_id.is_empty():
		return VfxResult.ok({})
	return _asset_resolver.resolve(logical_id) if _asset_resolver != null else VfxResult.failure([VfxIssue.new("PREVIEW_ASSET", "preview_asset_resolver_missing", "Preview renderer requires an Asset Resolver.")])
