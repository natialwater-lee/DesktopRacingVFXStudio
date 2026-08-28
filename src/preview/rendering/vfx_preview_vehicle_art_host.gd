class_name VfxPreviewVehicleArtHost
extends Node2D

var _texture: Texture2D
var _source_size := Vector2.ZERO


func set_reference(texture: Texture2D, source_size: Vector2i) -> void:
	_texture = texture
	_source_size = Vector2(source_size)
	queue_redraw()


func _draw() -> void:
	if _texture == null or _source_size == Vector2.ZERO:
		return
	draw_texture_rect(_texture, Rect2(-_source_size * 0.5, _source_size), false)
