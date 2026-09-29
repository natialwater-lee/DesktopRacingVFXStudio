extends MeshInstance2D
## Fixed geometry; only per-instance head uniforms change on steady-state ticks.
const RibbonShader := preload("res://src/preview/curve_flow/vfx_curve_flow_static.gdshader")
var evaluator: RefCounted
var geometry: RefCounted
var heads := PackedFloat32Array()

func configure(texture: Texture2D) -> void:
	mesh = geometry.mesh
	var lane: Dictionary = evaluator.lanes[0]
	var shader_material := ShaderMaterial.new()
	shader_material.shader = RibbonShader
	var native: bool = lane.texture_mode == "NATIVE_STRAND"
	shader_material.set_shader_parameter("native_strand", native)
	shader_material.set_shader_parameter("strand_texture" if native else "flow_texture", texture)
	shader_material.set_shader_parameter("segment_length", float(lane.length))
	shader_material.set_shader_parameter("path_length", float(evaluator.tables[0].length))
	shader_material.set_shader_parameter("brightness", float(lane.brightness))
	shader_material.set_shader_parameter("texture_phase", float(lane.texture_phase))
	material = shader_material
	heads.resize(64)
	refresh()

func refresh() -> void:
	var count: int = evaluator.segments.size()
	for i in count: heads[i] = float(evaluator.segments[i].head)
	material.set_shader_parameter("heads", heads)
	material.set_shader_parameter("active_count", count)
	visible = count > 0
