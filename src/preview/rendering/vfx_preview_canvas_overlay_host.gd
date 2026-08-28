class_name VfxPreviewCanvasOverlayHost
extends Node2D

var _canvas: WeakRef


func set_canvas(canvas: Control) -> void:
	_canvas = weakref(canvas)
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var canvas := _canvas.get_ref() as VfxVehiclePreviewCanvas if _canvas != null else null
	if canvas == null:
		return
	var ghost_color := Color("ff66cf")
	for ghost_position in canvas.visible_ghost_positions():
		draw_rect(Rect2(ghost_position - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), ghost_color, false, 1.5)
	var layer_positions := canvas.resolved_layer_anchor_positions()
	if canvas.is_interactive() and canvas.shared_state().show_anchors():
		var anchors: Variant = canvas.shared_state().profile_data().get("anchors")
		if anchors is Dictionary:
			for anchor_name in anchors:
				var position: Variant = canvas.project_anchor_position(str(anchor_name), Vector2.ZERO)
				if position == null:
					continue
				var is_layer_anchor := canvas.layer_anchor_names().has(str(anchor_name))
				var is_selected: bool = canvas.shared_state().selected_profile_anchor() == str(anchor_name)
				var marker_color := Color("ffaf4f") if is_selected else Color("55d6ff") if is_layer_anchor else Color("b8c1cd")
				draw_circle(position, 3.0, marker_color)
				draw_string(ThemeDB.fallback_font, position + Vector2(5, -3), _short_label(str(anchor_name)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, marker_color)
	else:
		for position in layer_positions:
			draw_circle(position, 1.5, Color("55d6ff"))


func _short_label(anchor_name: String) -> String:
	var label := ""
	for segment in anchor_name.split("_"):
		label += segment.left(1)
	return label
