class_name VfxStressVehicleSlot
extends Node2D

const VfxPreviewRenderRuntimeModel := preload("res://src/preview/rendering/vfx_preview_render_runtime.gd")
const VfxPreviewPlaybackControllerModel := preload("res://src/preview/rendering/vfx_preview_playback_controller.gd")
const VfxPreviewVehicleArtHostModel := preload("res://src/preview/rendering/vfx_preview_vehicle_art_host.gd")
const VfxPreviewCanvasRenderHostModel := preload("res://src/preview/rendering/vfx_preview_canvas_render_host.gd")

var _registry: RefCounted
var _factory: RefCounted
var _asset_resolver: RefCounted
var _profile_data: Dictionary = {}
var _effective_game_scale := Vector2.ONE
var _entries: Array[Dictionary] = []
var _render_hosts: Dictionary = {}
var _future_vfx_host: Node2D
var _world_root: Node2D


func _init(registry: RefCounted, factory: RefCounted, asset_resolver: RefCounted) -> void:
	_registry = registry
	_factory = factory
	_asset_resolver = asset_resolver


func configure(plan_values: Array, profile_data: Dictionary, effective_game_scale: Vector2, workload_type: String) -> Array[VfxIssue]:
	_clear_entries()
	_profile_data = profile_data.duplicate(true)
	_effective_game_scale = effective_game_scale
	_ensure_hosts()
	_configure_vehicle_art()
	var issues: Array[VfxIssue] = []
	for plan in plan_values:
		if plan == null:
			continue
		_preload_assets(plan, issues)
		_entries.append({
			"plan": plan,
			"workload_type": workload_type,
			"runtime": VfxPreviewRenderRuntimeModel.new(plan, _profile_data, _registry, _factory, _asset_resolver),
			"playback": null
		})
	return issues


func set_vfx_enabled(enabled: bool) -> void:
	_clear_render_packets()
	for entry in _entries:
		var runtime: RefCounted = entry.get("runtime")
		if runtime == null:
			continue
		runtime.clear()
		entry["playback"] = null
		if not enabled:
			continue
		var playback := VfxPreviewPlaybackControllerModel.new(entry.get("plan"), runtime)
		playback.set_auto_playback(false)
		var phase_name := "loop" if entry.get("workload_type") == "STEADY_LOOP" else "one_shot"
		playback.set_manual_phase(phase_name)
		entry["playback"] = playback


func advance(delta_seconds: float) -> Dictionary:
	var facts := _empty_facts()
	var routed: Dictionary = {}
	for entry in _entries:
		var playback: RefCounted = entry.get("playback")
		var runtime: RefCounted = entry.get("runtime")
		if playback == null or runtime == null:
			continue
		if entry.get("workload_type") == "REPEATED_ONE_SHOT" and playback.state_name() == "TERMINATED":
			playback.restart(_frame_context())
		playback.advance(delta_seconds, _frame_context())
		facts["active_vfx_instances"] += 1 if playback.is_advancing() else 0
		facts["active_layer_renderers"] += runtime.active_renderer_count()
		facts["active_runtime_instances"] += runtime.active_renderer_count()
		var packets: Array = runtime.draw_packets()
		facts["packet_count"] += packets.size()
		for packet in packets:
			_accumulate_packet_facts(facts, packet)
			var host := _render_host_for_packet(packet)
			if host == null:
				continue
			var key := str(host.get_instance_id())
			if not routed.has(key):
				routed[key] = {"host": host, "packets": []}
			routed[key]["packets"].append(packet)
	_clear_render_packets()
	for route in routed.values():
		route["host"].apply_packets(route["packets"])
	return facts


func effective_game_scale() -> Vector2:
	return _effective_game_scale


func runtime_slot_count() -> int:
	return _entries.size()


func _ensure_hosts() -> void:
	if _world_root != null:
		return
	_world_root = Node2D.new()
	_world_root.name = "StressWorldRoot"
	add_child(_world_root)
	_future_vfx_host = Node2D.new()
	_future_vfx_host.name = "FutureVfxHost"
	_world_root.add_child(_future_vfx_host)
	_ensure_plane_node(_world_root, "WorldPlaneHost", 0)
	_ensure_plane_node(_world_root, "UnderFollowWorldHost", 10)
	_ensure_plane_node(_future_vfx_host, "UnderVehicleLocalHost", -1)
	var art := VfxPreviewVehicleArtHostModel.new()
	art.name = "VehicleArtHost"
	_future_vfx_host.add_child(art)
	_ensure_plane_node(_future_vfx_host, "OverVehicleLocalHost", 1)
	_ensure_plane_node(_world_root, "OverFollowWorldHost", 30)
	_ensure_plane_node(_world_root, "ScreenUiPlaneHost", 40)


func _configure_vehicle_art() -> void:
	_future_vfx_host.position = Vector2.ZERO
	_future_vfx_host.rotation = 0.0
	_future_vfx_host.scale = _effective_game_scale
	var art := _future_vfx_host.get_node_or_null("VehicleArtHost") as Node2D
	if art == null or not art.has_method("set_reference"):
		return
	var reference_image: Variant = _profile_data.get("reference_image", {})
	var reference_path := str(reference_image.get("path", "")) if reference_image is Dictionary else ""
	var texture := load(reference_path) as Texture2D if not reference_path.is_empty() else null
	var source_size := Vector2i(texture.get_width(), texture.get_height()) if texture != null else Vector2i.ZERO
	art.set_reference(texture, source_size)


func _preload_assets(plan: RefCounted, issues: Array[VfxIssue]) -> void:
	for phase in plan.phase_plans():
		for layer in phase.layer_specs():
			var parameters: Dictionary = layer.parameters()
			var asset_id := str(parameters.get("sprite_asset_ref", parameters.get("texture_asset_ref", "")))
			if asset_id.is_empty():
				continue
			var resolved: VfxResult = _asset_resolver.resolve(asset_id)
			issues.append_array(resolved.issues)


func _render_host_for_packet(packet: Dictionary) -> Node2D:
	var render_plane := str(packet.get("render_plane", ""))
	var effective_space := str(packet.get("space", ""))
	var parent: Node2D
	if render_plane == "SCREEN_UI":
		parent = _world_root.get_node_or_null("ScreenUiPlaneHost") as Node2D
	elif effective_space == "VEHICLE_FOLLOW_WORLD_TRAIL":
		parent = _world_root.get_node_or_null("UnderFollowWorldHost" if render_plane == "UNDER_VEHICLE" else "OverFollowWorldHost") as Node2D
	elif render_plane == "WORLD":
		parent = _world_root.get_node_or_null("WorldPlaneHost") as Node2D
	else:
		parent = _future_vfx_host.get_node_or_null("UnderVehicleLocalHost" if render_plane == "UNDER_VEHICLE" else "OverVehicleLocalHost") as Node2D
	if parent == null:
		return null
	var blend_mode := str(packet.get("blend_mode", "ALPHA"))
	var key := "%s:%s" % [parent.get_path(), blend_mode]
	var host := _render_hosts.get(key) as Node2D
	if host == null:
		host = VfxPreviewCanvasRenderHostModel.new()
		host.name = "StressRenderHost_%s" % blend_mode
		host.set_blend_mode(blend_mode)
		parent.add_child(host)
		_render_hosts[key] = host
	return host


func _accumulate_packet_facts(facts: Dictionary, packet: Dictionary) -> void:
	match packet.get("type", ""):
		"PARTICLE":
			facts["alive_particle_count"] += 1
		"TRAIL":
			var points: Variant = packet.get("points", [])
			facts["active_trail_point_count"] += points.size() if points is Array else 0
		"RING":
			facts["active_ring_count"] += 1


func _clear_entries() -> void:
	for entry in _entries:
		var runtime: RefCounted = entry.get("runtime")
		if runtime != null:
			runtime.clear()
	_entries.clear()
	_clear_render_packets()


func _clear_render_packets() -> void:
	for host in _render_hosts.values():
		if host is Node and host.has_method("clear_packets"):
			host.clear_packets()


func _ensure_plane_node(parent: Node2D, node_name: String, z_value: int) -> Node2D:
	var node := parent.get_node_or_null(node_name) as Node2D
	if node == null:
		node = Node2D.new()
		node.name = node_name
		parent.add_child(node)
	node.z_index = z_value
	return node


func _frame_context() -> Dictionary:
	return {
		"vehicle_translation_source": Vector2.ZERO,
		"vehicle_rotation_degrees": 0.0,
		"effective_game_scale": _effective_game_scale
	}


func _empty_facts() -> Dictionary:
	return {
		"active_vfx_instances": 0,
		"active_layer_renderers": 0,
		"active_runtime_instances": 0,
		"packet_count": 0,
		"alive_particle_count": 0,
		"active_trail_point_count": 0,
		"active_ring_count": 0
	}
