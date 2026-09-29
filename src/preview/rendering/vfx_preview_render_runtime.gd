class_name VfxPreviewRenderRuntime
extends RefCounted

const VfxPreviewInstanceResolverModel := preload("res://src/preview/rendering/vfx_preview_instance_resolver.gd")
const VfxPreviewRuntimeInputStateModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_input_state.gd")
const VfxPreviewRuntimeModulationEvaluatorModel := preload("res://src/preview/runtime_modulation/vfx_preview_runtime_modulation_evaluator.gd")

var _plan: RefCounted
var _instances_by_phase: Dictionary = {}
var _entries: Array[Dictionary] = []
var _factory: RefCounted
var _asset_resolver: RefCounted
var _issues: Array[VfxIssue] = []
var _runtime_input_state: RefCounted
var _active_runtime_modulation_program: RefCounted
var _runtime_modulation_evaluator: RefCounted
var _modulation_elapsed_seconds := 0.0


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
		var renderer: RefCounted = renderer_script.new(instance, asset_result.value, null)
		if layer_spec.layer_type() == "CURVE_FLOW" and layer_spec.parameters().profile_version == 2:
			renderer.geometry = _plan.curve_geometry(layer_spec.parameters())
		renderer.restart(frame_context)
		_entries.append({"phase_name": phase_name, "renderer": renderer, "layer_id": layer_spec.layer_id(), "layer_spec": layer_spec, "effective_state": null})
	_rebuild_runtime_modulation_for_renderer_entries()
	refresh_modulation(frame_context)


func stop_phase_sources(phase_name: String) -> void:
	for entry in _entries:
		if entry.get("phase_name") == phase_name:
			(entry.get("renderer") as RefCounted).stop_emission()
	_rebuild_runtime_modulation_for_renderer_entries()


func advance(delta_seconds: float, frame_context: Dictionary) -> void:
	_modulation_elapsed_seconds = float(frame_context.get("preview_time", _modulation_elapsed_seconds + delta_seconds))
	refresh_modulation(frame_context)
	var active_entries: Array[Dictionary] = []
	for entry in _entries:
		var renderer: RefCounted = entry.get("renderer")
		renderer.advance(delta_seconds, frame_context)
		if renderer.is_source_active() or renderer.has_residual():
			active_entries.append(entry)
	var entries_changed := active_entries.size() != _entries.size()
	_entries = active_entries
	if entries_changed:
		_rebuild_runtime_modulation_for_renderer_entries()


func clear() -> void:
	for entry in _entries:
		(entry.get("renderer") as RefCounted).clear()
	_entries.clear()
	_issues.clear()
	_active_runtime_modulation_program = null
	_runtime_modulation_evaluator = null
	_modulation_elapsed_seconds = 0.0


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


func set_runtime_input_state(state: RefCounted) -> void:
	_runtime_input_state = state


func refresh_modulation(frame_context: Dictionary) -> void:
	if _runtime_modulation_evaluator == null:
		return
	var states: Array = []
	for entry in _entries:
		var state: RefCounted = entry.get("effective_state")
		if state != null:
			states.append(state)
	_runtime_modulation_evaluator.refresh(float(frame_context.get("preview_time", _modulation_elapsed_seconds)), states)
	for entry in _entries:
		(entry.get("renderer") as RefCounted).update_effective_packet(frame_context)


func has_modulation_evaluator() -> bool:
	return _runtime_modulation_evaluator != null


func active_runtime_modulation_binding_count() -> int:
	return _active_runtime_modulation_program.binding_count() if _active_runtime_modulation_program != null else 0


func modulation_sample_count_last_tick() -> int:
	return _runtime_modulation_evaluator.sampled_source_count_last_tick() if _runtime_modulation_evaluator != null else 0


func _rebuild_runtime_modulation_for_renderer_entries() -> void:
	var base_program: RefCounted = _plan.runtime_modulation_program() if _plan != null else null
	if base_program == null:
		_active_runtime_modulation_program = null
		_runtime_modulation_evaluator = null
		return
	var reachable_layer_ids: Dictionary = {}
	for entry in _entries:
		reachable_layer_ids[str(entry.get("layer_id", ""))] = true
	_active_runtime_modulation_program = base_program.filtered_to_reachable_layer_ids(reachable_layer_ids)
	if _active_runtime_modulation_program.binding_count() == 0:
		_runtime_modulation_evaluator = null
		for entry in _entries:
			(entry.get("renderer") as RefCounted).set_effective_state(null)
			entry["effective_state"] = null
		return
	if _runtime_input_state == null:
		_runtime_input_state = VfxPreviewRuntimeInputStateModel.new(_active_runtime_modulation_program)
	_runtime_modulation_evaluator = VfxPreviewRuntimeModulationEvaluatorModel.new(_active_runtime_modulation_program, _runtime_input_state)
	for entry in _entries:
		var layer_spec: RefCounted = entry.get("layer_spec")
		if _active_runtime_modulation_program.binding_refs_for_layer(layer_spec.layer_id()).is_empty():
			(entry.get("renderer") as RefCounted).set_effective_state(null)
			entry["effective_state"] = null
			continue
		var state: RefCounted = _runtime_modulation_evaluator.create_effective_state(layer_spec)
		entry["effective_state"] = state
		(entry.get("renderer") as RefCounted).set_effective_state(state)


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
