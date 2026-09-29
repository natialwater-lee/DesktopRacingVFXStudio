class_name VfxPreviewCanvasRenderHost
extends Node2D

const VfxPreviewShieldArcHostModel := preload("res://src/preview/rendering/vfx_preview_shield_arc_host.gd")

var _packets: Array[Dictionary] = []
var _trail_adapters: Dictionary = {}
var _shield_adapters: Dictionary = {}
var _curve_adapters: Dictionary = {}
var _glow_texture: GradientTexture2D


func set_blend_mode(blend_mode: String) -> void:
	var canvas_material := CanvasItemMaterial.new()
	canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if blend_mode == "ADDITIVE" else CanvasItemMaterial.BLEND_MODE_MIX
	material = canvas_material


func apply_packets(packet_values: Array) -> void:
	set_packets(packet_values)


func set_packets(packet_values: Array) -> void:
	_packets.clear()
	var trail_packets: Array[Dictionary] = []
	var textured_shield_packets: Array[Dictionary] = []
	var curve_packets: Array[Dictionary] = []
	for packet_value in packet_values:
		if not packet_value is Dictionary:
			continue
		var packet: Dictionary = packet_value.duplicate(true)
		if packet.get("type") == "CURVE_FLOW":
			curve_packets.append(packet)
		elif packet.get("type") == "TRAIL":
			trail_packets.append(packet)
		elif packet.get("type") == "SHIELD" and _has_texture(packet):
			textured_shield_packets.append(packet)
		else:
			_packets.append(packet)
	_sync_trail_adapters(trail_packets)
	_sync_textured_shield_adapters(textured_shield_packets)
	_sync_curve_adapters(curve_packets)
	queue_redraw()


func clear_packets() -> void:
	set_packets([])

func _sync_curve_adapters(packets: Array[Dictionary]) -> void:
	var used := {}
	for packet in packets:
		var key := str(packet.layer_id) + (":static" if packet.has("curve_geometry") else ":dynamic")
		used[key] = true
		var node: Node2D = _curve_adapters.get(key)
		if node != null and not is_same(node.evaluator, packet.curve_flow):
			node.visible = false
			node.queue_free()
			node = null
		if node == null:
			if packet.has("curve_geometry"):
				node = preload("res://src/preview/curve_flow/vfx_curve_flow_static_host.gd").new()
				node.geometry = packet.curve_geometry
			else:
				node = preload("res://src/preview/curve_flow/vfx_curve_flow_mesh.gd").new()
			node.evaluator = packet.curve_flow
			node.configure(packet.asset.texture)
			add_child(node)
			_curve_adapters[key] = node
		node.position = packet.position
		node.scale = _geometry_scale(packet)
		node.rotation_degrees = packet.geometry_rotation_degrees
		node.evaluator = packet.curve_flow
		node.refresh()
	for key in _curve_adapters.keys():
		if not used.has(key):
			_curve_adapters[key].visible = false
			_curve_adapters[key].queue_free()
			_curve_adapters.erase(key)


func _draw() -> void:
	for packet in _packets:
		var color := _packet_color(packet)
		match packet.get("type", ""):
			"GLOW":
				_begin_packet_transform(packet)
				_draw_glow(Vector2.ZERO, float(packet.get("radius", 0.0)), color)
				_end_packet_transform()
			"RING":
				_begin_packet_transform(packet)
				draw_arc(Vector2.ZERO, float(packet.get("radius", 0.0)), 0.0, TAU, 32, color, float(packet.get("width", 1.0)), true)
				_end_packet_transform()
			"TEXTURED_SPRITE":
				_begin_packet_transform(packet)
				_draw_textured_sprite(packet, color)
				_end_packet_transform()
			"SHIELD":
				_begin_packet_transform(packet)
				var arc_degrees: float = float(packet.get("arc_degrees", 360.0))
				var half_arc := deg_to_rad(arc_degrees) * 0.5
				draw_arc(Vector2.ZERO, float(packet.get("radius", 0.0)), -half_arc, half_arc, 32, color, float(packet.get("thickness", 1.0)), true)
				_end_packet_transform()
			"PARTICLE":
				_begin_particle_transform(packet)
				_draw_particle(packet, color)
				_end_packet_transform()


func _sync_trail_adapters(trail_packets: Array[Dictionary]) -> void:
	var used: Dictionary = {}
	for packet_index in trail_packets.size():
		var packet := trail_packets[packet_index]
		var key := "%s:%d" % [str(packet.get("layer_id", "trail")), packet_index]
		used[key] = true
		var line := _trail_adapters.get(key) as Line2D
		if line == null:
			line = Line2D.new()
			line.name = "TrailAdapter_%s" % key.replace(".", "_")
			line.texture_mode = Line2D.LINE_TEXTURE_TILE
			add_child(line)
			_trail_adapters[key] = line
		var points: PackedVector2Array = PackedVector2Array(packet.get("points", []))
		line.points = points
		line.default_color = _packet_color(packet)
		line.width = maxf(float(packet.get("width_start", 1.0)), 0.01)
		line.width_curve = _trail_width_curve(float(packet.get("width_start", 1.0)), float(packet.get("width_end", 1.0)))
		var asset: Dictionary = packet.get("asset", {}) if packet.get("asset", {}) is Dictionary else {}
		line.texture = asset.get("texture") as Texture2D
		line.visible = points.size() >= 2
	for key in _trail_adapters.keys():
		if used.has(key):
			continue
		var line := _trail_adapters[key] as Line2D
		if line != null:
			line.queue_free()
		_trail_adapters.erase(key)


func _trail_width_curve(width_start: float, width_end: float) -> Curve:
	var curve := Curve.new()
	var base_width := maxf(width_start, 0.01)
	curve.add_point(Vector2(0.0, maxf(width_end, 0.0) / base_width))
	curve.add_point(Vector2(1.0, 1.0))
	return curve


func _sync_textured_shield_adapters(shield_packets: Array[Dictionary]) -> void:
	var used: Dictionary = {}
	for packet_index in shield_packets.size():
		var packet := shield_packets[packet_index]
		var key := "%s:%d" % [str(packet.get("layer_id", "shield")), packet_index]
		used[key] = true
		var adapter: Variant = _shield_adapters.get(key)
		if adapter == null:
			adapter = VfxPreviewShieldArcHostModel.new()
			adapter.name = "ShieldAdapter_%s" % key.replace(".", "_").replace(":", "_")
			add_child(adapter)
			_shield_adapters[key] = adapter
		adapter.set_packet(packet)
	for key in _shield_adapters.keys():
		if used.has(key):
			continue
		var adapter: Variant = _shield_adapters[key]
		if adapter is Node:
			adapter.queue_free()
		_shield_adapters.erase(key)


func _has_texture(packet: Dictionary) -> bool:
	var asset: Variant = packet.get("asset", {})
	return asset is Dictionary and asset.get("texture") is Texture2D


func _begin_packet_transform(packet: Dictionary) -> void:
	draw_set_transform(packet.get("position", Vector2.ZERO), deg_to_rad(float(packet.get("geometry_rotation_degrees", 0.0))), _geometry_scale(packet))


func _begin_particle_transform(packet: Dictionary) -> void:
	draw_set_transform(packet.get("position", Vector2.ZERO), deg_to_rad(float(packet.get("rotation_degrees", 0.0))), _geometry_scale(packet))


func _end_packet_transform() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _geometry_scale(packet: Dictionary) -> Vector2:
	var value: Variant = packet.get("geometry_scale", Vector2.ONE)
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ONE


func _draw_particle(packet: Dictionary, color: Color) -> void:
	var size := maxf(float(packet.get("size", 1.0)), 0.01)
	var asset: Dictionary = packet.get("asset", {}) if packet.get("asset", {}) is Dictionary else {}
	var texture := asset.get("texture") as Texture2D
	if asset.get("source") == "TEXTURE" and texture != null:
		draw_texture_rect(texture, texture_particle_rect(texture, size), false, color)
		return
	match asset.get("primitive", "SQUARE"):
		"DIAMOND":
			draw_colored_polygon(PackedVector2Array([Vector2(0.0, -size), Vector2(size, 0.0), Vector2(0.0, size), Vector2(-size, 0.0)]), color)
		"DOT":
			draw_circle(Vector2.ZERO, size * 0.5, color)
		"STREAK":
			draw_rect(Rect2(Vector2(-size, -size * 0.25), Vector2(size * 2.0, size * 0.5)), color)
		_:
			draw_rect(Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size), color)


func _draw_textured_sprite(packet: Dictionary, color: Color) -> void:
	var asset: Dictionary = packet.get("asset", {}) if packet.get("asset", {}) is Dictionary else {}
	var texture := asset.get("texture") as Texture2D
	if texture == null:
		return
	var native_size := texture.get_size()
	draw_texture_rect(texture, Rect2(native_size * -0.5, native_size), false, color)


func texture_particle_rect(texture: Texture2D, half_size: float) -> Rect2:
	var native_size := texture.get_size()
	var longest_dimension := maxf(native_size.x, native_size.y)
	if is_zero_approx(longest_dimension):
		return Rect2(Vector2.ONE * -half_size, Vector2.ONE * half_size * 2.0)
	var longest_display_dimension := maxf(half_size, 0.01) * 2.0
	var display_size := native_size * (longest_display_dimension / longest_dimension)
	return Rect2(display_size * -0.5, display_size)


func _draw_glow(position: Vector2, radius: float, color: Color) -> void:
	var texture := _radial_glow_texture()
	draw_texture_rect(texture, Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, color)


func _radial_glow_texture() -> GradientTexture2D:
	if _glow_texture != null:
		return _glow_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.55), Color(1.0, 1.0, 1.0, 0.0)])
	_glow_texture = GradientTexture2D.new()
	_glow_texture.width = 64
	_glow_texture.height = 64
	_glow_texture.fill = GradientTexture2D.FILL_RADIAL
	_glow_texture.fill_from = Vector2(0.5, 0.5)
	_glow_texture.fill_to = Vector2(1.0, 0.5)
	_glow_texture.gradient = gradient
	return _glow_texture


func _packet_color(packet: Dictionary) -> Color:
	var asset: Dictionary = packet.get("asset", {}) if packet.get("asset", {}) is Dictionary else {}
	var color_value: Variant = packet.get("color_rgba", asset.get("color_rgba", [1.0, 1.0, 1.0, 1.0]))
	var alpha := float(packet.get("alpha", 1.0))
	if color_value is Array and color_value.size() == 4:
		return Color(float(color_value[0]), float(color_value[1]), float(color_value[2]), float(color_value[3]) * alpha)
	return Color(1.0, 1.0, 1.0, alpha)
