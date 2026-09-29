class_name VfxPreviewRendererFactory
extends RefCounted

const ParticleRendererModel := preload("res://src/preview/rendering/vfx_particle_layer_renderer.gd")
const TrailRendererModel := preload("res://src/preview/rendering/vfx_trail_layer_renderer.gd")
const RingRendererModel := preload("res://src/preview/rendering/vfx_ring_layer_renderer.gd")
const GlowRendererModel := preload("res://src/preview/rendering/vfx_glow_layer_renderer.gd")
const TexturedSpriteRendererModel := preload("res://src/preview/rendering/vfx_textured_sprite_layer_renderer.gd")
const ShieldRendererModel := preload("res://src/preview/rendering/vfx_shield_layer_renderer.gd")

var _registrations: Dictionary


func _init(registrations: Variant = null) -> void:
	_registrations = registrations.duplicate() if registrations is Dictionary else {
		"CURVE_FLOW": preload("res://src/preview/curve_flow/vfx_curve_flow_layer_renderer.gd"),
		"PARTICLE": ParticleRendererModel,
		"TRAIL": TrailRendererModel,
		"RING": RingRendererModel,
		"GLOW": GlowRendererModel,
		"TEXTURED_SPRITE": TexturedSpriteRendererModel,
		"SHIELD": ShieldRendererModel
	}


func validate_configuration(registry: RefCounted) -> VfxResult:
	if registry == null:
		return VfxResult.failure([VfxIssue.new("PREVIEW_CONFIGURATION", "renderer_registry_missing", "Renderer Factory requires a Schema Registry.")])
	var schema_types: Dictionary = registry.schema().get("x_vfx_layer_types", {})
	var issues: Array[VfxIssue] = []
	for layer_type in schema_types:
		if not _registrations.has(layer_type):
			issues.append(VfxIssue.new("PREVIEW_CONFIGURATION", "renderer_missing_for_schema_type", "Schema Layer Type has no Preview Renderer: %s" % layer_type))
	for layer_type in _registrations:
		if not schema_types.has(layer_type):
			issues.append(VfxIssue.new("PREVIEW_CONFIGURATION", "renderer_not_declared_by_schema", "Preview Renderer is not declared by Schema: %s" % layer_type))
	return VfxResult.with_issues(_registrations.duplicate(), issues)


func renderer_registration(layer_type: String) -> Variant:
	return _registrations.get(layer_type)
