class_name VfxPreviewVehicleArtHost
extends Node2D

var _texture: Texture2D
var _source_size := Vector2.ZERO
var _equipment_texture: Texture2D
var _equipment_position := Vector2.ZERO
var _equipment_scale := 1.0
var _equipment_over_vehicle := false


func set_reference(texture: Texture2D, source_size: Vector2i) -> void:
	_texture = texture
	_source_size = Vector2(source_size)
	queue_redraw()


# Game draws an underlay between UNDER_VEHICLE VFX and the car, an overlay above the car.
func set_equipment(texture: Texture2D, equipment_position: Vector2, equipment_scale: float, over_vehicle: bool) -> void:
	if texture == _equipment_texture and equipment_position == _equipment_position and is_equal_approx(equipment_scale, _equipment_scale) and over_vehicle == _equipment_over_vehicle:
		return
	_equipment_texture = texture
	_equipment_position = equipment_position
	_equipment_scale = equipment_scale
	_equipment_over_vehicle = over_vehicle
	queue_redraw()


func equipment_texture() -> Texture2D:
	return _equipment_texture


func _draw() -> void:
	if not _equipment_over_vehicle:
		_draw_equipment()
	if _texture != null and _source_size != Vector2.ZERO:
		draw_texture_rect(_texture, Rect2(-_source_size * 0.5, _source_size), false)
	if _equipment_over_vehicle:
		_draw_equipment()


func _draw_equipment() -> void:
	if _equipment_texture == null:
		return
	var draw_size := Vector2(_equipment_texture.get_size()) * _equipment_scale
	draw_texture_rect(_equipment_texture, Rect2(_equipment_position - draw_size * 0.5, draw_size), false)
