class_name VfxPreviewAssetResolver
extends RefCounted

var _registry: RefCounted
var _resolved_cache: Dictionary = {}


func _init(registry: RefCounted) -> void:
	_registry = registry


func resolve(logical_id: String) -> VfxResult:
	if _resolved_cache.has(logical_id):
		return VfxResult.ok(_resolved_cache[logical_id].duplicate())
	var definition: Dictionary = _registry.asset_definition(logical_id) if _registry != null else {}
	if not definition.is_empty():
		return _resolve_definition(logical_id, definition)
	return _resolve_with_fallback(logical_id, "preview_asset_missing", "Preview Asset is not present in the Studio catalog: %s" % logical_id)


func _resolve_definition(logical_id: String, definition: Dictionary) -> VfxResult:
	var source := str(definition.get("source", "PROCEDURAL")).to_upper()
	match source:
		"PROCEDURAL":
			var resolved := _resolved_procedural_asset(logical_id, definition, false)
			_resolved_cache[logical_id] = resolved
			return VfxResult.ok(resolved.duplicate())
		"TEXTURE":
			return _resolve_texture_asset(logical_id, definition)
		_:
			return _resolve_with_fallback(logical_id, "preview_asset_source_unsupported", "Preview Asset has an unsupported source: %s" % source)


func _resolve_texture_asset(logical_id: String, definition: Dictionary) -> VfxResult:
	var texture_path := str(definition.get("texture_path", ""))
	if texture_path.is_empty():
		return _resolve_with_fallback(logical_id, "preview_asset_texture_path_missing", "TEXTURE Preview Asset has no texture_path: %s" % logical_id)
	if not FileAccess.file_exists(texture_path):
		return _resolve_with_fallback(logical_id, "preview_asset_texture_load_failed", "TEXTURE Preview Asset cannot load texture_path: %s" % texture_path)
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(texture_path))
	if image == null or image.is_empty():
		return _resolve_with_fallback(logical_id, "preview_asset_texture_load_failed", "TEXTURE Preview Asset cannot create Texture2D: %s" % texture_path)
	var texture := ImageTexture.create_from_image(image)
	if texture == null:
		return _resolve_with_fallback(logical_id, "preview_asset_texture_load_failed", "TEXTURE Preview Asset cannot create Texture2D: %s" % texture_path)
	var texture_size := texture.get_size()
	var resolved := {
		"logical_id": logical_id,
		"source": "TEXTURE",
		"texture_path": texture_path,
		"size_px": [int(texture_size.x), int(texture_size.y)],
		"color_rgba": [1.0, 1.0, 1.0, 1.0],
		"texture": texture,
		"is_fallback": false
	}
	_resolved_cache[logical_id] = resolved
	return VfxResult.ok(resolved.duplicate())


func _resolve_with_fallback(logical_id: String, issue_code: String, message: String) -> VfxResult:
	var fallback := _fallback_asset(logical_id)
	_resolved_cache[logical_id] = fallback
	return VfxResult.with_issues(fallback.duplicate(), [VfxIssue.new("PREVIEW_ASSET", issue_code, message, "", "", -1, -1, "WARNING")])


func _fallback_asset(logical_id: String) -> Dictionary:
	return _resolved_procedural_asset(logical_id, {"primitive": "SQUARE", "size_px": [6, 6], "color_rgba": [1.0, 0.0, 1.0, 1.0]}, true)


func _resolved_procedural_asset(logical_id: String, definition: Dictionary, is_fallback: bool) -> Dictionary:
	var size_values: Array = definition.get("size_px", [4, 4]) if definition.get("size_px", [4, 4]) is Array else [4, 4]
	var size := Vector2i(maxi(1, int(size_values[0])), maxi(1, int(size_values[1])))
	var color_values: Array = definition.get("color_rgba", [1.0, 1.0, 1.0, 1.0]) if definition.get("color_rgba", [1.0, 1.0, 1.0, 1.0]) is Array else [1.0, 1.0, 1.0, 1.0]
	var color := Color(float(color_values[0]), float(color_values[1]), float(color_values[2]), float(color_values[3]))
	return {
		"logical_id": logical_id,
		"source": "PROCEDURAL",
		"primitive": str(definition.get("primitive", "SQUARE")),
		"size_px": size_values.duplicate(),
		"color_rgba": color_values.duplicate(),
		"texture": _make_preview_texture(size, color, str(definition.get("primitive", "SQUARE"))),
		"is_fallback": is_fallback
	}


func _make_preview_texture(size: Vector2i, color: Color, primitive: String) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(color.r, color.g, color.b, 0.0) if primitive == "DIAMOND" else color)
	if primitive == "DIAMOND":
		var centre := Vector2(float(size.x - 1) * 0.5, float(size.y - 1) * 0.5)
		for y in size.y:
			for x in size.x:
				var normalized_distance: float = absf(float(x) - centre.x) / maxf(centre.x, 0.5) + absf(float(y) - centre.y) / maxf(centre.y, 0.5)
				if normalized_distance <= 1.0:
					image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
