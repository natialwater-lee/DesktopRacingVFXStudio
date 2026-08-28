class_name VfxPreviewPlaneHosts
extends RefCounted

const VfxPreviewVehicleArtHostModel := preload("res://src/preview/rendering/vfx_preview_vehicle_art_host.gd")
const VfxPreviewCanvasOverlayHostModel := preload("res://src/preview/rendering/vfx_preview_canvas_overlay_host.gd")

static func ensure(canvas: Control, future_vfx_host: Node2D) -> Dictionary:
	var stage_root := canvas.get_node_or_null("StageWorldRoot") as Node2D
	if stage_root == null:
		stage_root = Node2D.new()
		stage_root.name = "StageWorldRoot"
		canvas.add_child(stage_root)
	stage_root.z_index = 1
	if future_vfx_host.get_parent() != stage_root:
		if future_vfx_host.get_parent() != null:
			future_vfx_host.get_parent().remove_child(future_vfx_host)
		stage_root.add_child(future_vfx_host)
	_ensure_child(stage_root, "WorldPlaneHost", 0)
	_ensure_child(stage_root, "UnderFollowWorldHost", 10)
	_ensure_child(future_vfx_host, "UnderVehicleLocalHost", -1)
	var vehicle_art := _ensure_child(future_vfx_host, "VehicleArtHost", 0)
	if not vehicle_art is VfxPreviewVehicleArtHostModel:
		vehicle_art.set_script(VfxPreviewVehicleArtHostModel)
	_ensure_child(future_vfx_host, "OverVehicleLocalHost", 1)
	_ensure_child(stage_root, "OverFollowWorldHost", 30)
	var overlay := canvas.get_node_or_null("OverlayHost") as Node2D
	if overlay == null:
		overlay = Node2D.new()
		overlay.name = "OverlayHost"
		canvas.add_child(overlay)
	overlay.z_index = 2
	if not overlay is VfxPreviewCanvasOverlayHostModel:
		overlay.set_script(VfxPreviewCanvasOverlayHostModel)
	(overlay as VfxPreviewCanvasOverlayHostModel).set_canvas(canvas)
	return {
		"stage_root": stage_root,
		"world": stage_root.get_node("WorldPlaneHost"),
		"under_follow_world": stage_root.get_node("UnderFollowWorldHost"),
		"under_local": future_vfx_host.get_node("UnderVehicleLocalHost"),
		"vehicle_art": future_vfx_host.get_node("VehicleArtHost"),
		"over_local": future_vfx_host.get_node("OverVehicleLocalHost"),
		"over_follow_world": stage_root.get_node("OverFollowWorldHost"),
		"overlay": overlay
	}


static func _ensure_child(parent: Node2D, child_name: String, z_value: int) -> Node2D:
	var child := parent.get_node_or_null(child_name) as Node2D
	if child == null:
		child = Node2D.new()
		child.name = child_name
		parent.add_child(child)
	child.z_index = z_value
	return child
