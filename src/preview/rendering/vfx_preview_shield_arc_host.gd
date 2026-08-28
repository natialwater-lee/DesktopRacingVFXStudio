class_name VfxPreviewShieldArcHost
extends Node2D

const ShieldAlphaShader := preload("res://src/preview/rendering/materials/vfx_shield_arc.gdshader")
const ShieldAdditiveShader := preload("res://src/preview/rendering/materials/vfx_shield_arc_additive.gdshader")

var _packet: Dictionary = {}


func set_packet(packet: Dictionary) -> void:
	_packet = packet.duplicate(true)
	position = _packet.get("position", Vector2.ZERO)
	rotation = deg_to_rad(float(_packet.get("geometry_rotation_degrees", 0.0)))
	scale = _geometry_scale(_packet.get("geometry_scale", Vector2.ONE))
	var shader_material := ShaderMaterial.new()
	shader_material.shader = ShieldAdditiveShader if _packet.get("blend_mode") == "ADDITIVE" else ShieldAlphaShader
	shader_material.set_shader_parameter("scroll_offset", float(_packet.get("scroll_offset", 0.0)))
	material = shader_material
	queue_redraw()


func _draw() -> void:
	var asset: Dictionary = _packet.get("asset", {}) if _packet.get("asset", {}) is Dictionary else {}
	var texture := asset.get("texture") as Texture2D
	if texture == null:
		return
	var radius := float(_packet.get("radius", 0.0))
	var thickness := float(_packet.get("thickness", 0.0))
	var arc_degrees := float(_packet.get("arc_degrees", 360.0))
	var segments := maxi(8, int(ceil(arc_degrees / 12.0)))
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	var inner_radius := maxf(0.0, radius - thickness * 0.5)
	var outer_radius := radius + thickness * 0.5
	var color := _packet_color()
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for index in segments:
		var t0 := float(index) / float(segments)
		var t1 := float(index + 1) / float(segments)
		var angle0 := lerpf(-half_arc, half_arc, t0)
		var angle1 := lerpf(-half_arc, half_arc, t1)
		var outer0 := Vector2.RIGHT.rotated(angle0) * outer_radius
		var inner0 := Vector2.RIGHT.rotated(angle0) * inner_radius
		var outer1 := Vector2.RIGHT.rotated(angle1) * outer_radius
		var inner1 := Vector2.RIGHT.rotated(angle1) * inner_radius
		vertices.append_array(PackedVector2Array([outer0, inner0, outer1, outer1, inner0, inner1]))
		for _color_index in 6:
			colors.append(color)
		uvs.append_array(PackedVector2Array([Vector2(t0, 0.0), Vector2(t0, 1.0), Vector2(t1, 0.0), Vector2(t1, 0.0), Vector2(t0, 1.0), Vector2(t1, 1.0)]))
	draw_primitive(vertices, colors, uvs, texture)


func _geometry_scale(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ONE


func _packet_color() -> Color:
	var value: Variant = _packet.get("color_rgba", [1.0, 1.0, 1.0, 1.0])
	var alpha := float(_packet.get("alpha", 1.0))
	if value is Array and value.size() == 4:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]) * alpha)
	return Color(1.0, 1.0, 1.0, alpha)
