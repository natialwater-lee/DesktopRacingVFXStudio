extends Node2D
## Versioned F1 mesh host. Parameters are canonical vehicle-local pixels.
const RibbonShader := preload("res://src/preview/curve_flow/vfx_curve_flow.gdshader")
const SAMPLE_STEP := 3.0
var evaluator: RefCounted
var _mesh := ArrayMesh.new()

func configure(texture: Texture2D) -> void:
	var ribbon_material := ShaderMaterial.new()
	ribbon_material.shader = RibbonShader
	# Bind only the active sampler: native uses clamp/sRGB, filament uses repeat/data.
	# Sharing one GL texture across these conflicting sampler states changes sampling.
	var native: bool = evaluator.lanes[0].texture_mode == "NATIVE_STRAND"
	ribbon_material.set_shader_parameter("strand_texture" if native else "flow_texture", texture)
	ribbon_material.set_shader_parameter("refined", true)
	ribbon_material.set_shader_parameter("textured", true)
	material = ribbon_material

func refresh() -> void:
	_mesh.clear_surfaces()
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for segment in evaluator.segments:
		var lane: Dictionary = evaluator.lanes[segment.lane]
		var png_lane: bool = lane.texture_mode == "NATIVE_STRAND"
		var tail: float = segment.head - lane.length
		var start := maxf(tail, 0.0)
		var end := minf(segment.head, evaluator.tables[segment.lane].length)
		if end - start < 0.001:
			continue
		var count := maxi(2, ceili((end - start) / SAMPLE_STEP))
		var base := vertices.size()
		for j in range(count + 1):
			var d := lerpf(start, end, float(j) / count)
			var u: float = (d - tail) / lane.length
			var p: Vector2 = evaluator.sample(segment.lane, d)
			var tangent: Vector2 = evaluator.tangent(segment.lane, d)
			var normal := Vector2(-tangent.y, tangent.x)
			var taper := smoothstep(0.0, 0.30, u) * (1.0 - smoothstep(0.74, 1.0, u))
			var width: float = lane.half_width * lerpf(0.04, 1.0, taper)
			var release := 1.0 - smoothstep(235.0, evaluator.tables[segment.lane].points[-1].y, p.y)
			width *= lerpf(0.18, 1.0, release)
			# Path-end attenuation removes hard clipping while the tail exits, never wraps.
			var path_fade := smoothstep(0.0, 16.0, d) * smoothstep(0.0, 28.0, evaluator.tables[segment.lane].length - d)
			for side in [-1.0, 1.0]:
				var v: Vector2 = p + normal * width * float(side)
				vertices.append(Vector3(v.x, v.y, 0.0))
				# B=0 identifies ONLY the PNG strand; R remains segment progress.
				colors.append(Color(u, 1.0, 0.0 if png_lane else 1.0, lane.brightness * path_fade * release))
				# World-local arc distance relative to moving head; constant texture scale.
				var texture_u: float = (d - segment.head) / 1024.0 + lane.texture_phase
				# PNG right edge (U=1) is the moving head. Crop only transparent Y margin.
				var v_uv: float = (side + 1.0) * 0.5
				uvs.append(Vector2(u if png_lane else texture_u, lerpf(38.0 / 171.0, 148.0 / 171.0, v_uv) if png_lane else v_uv))
			if j < count:
				var k := base + j * 2
				indices.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	queue_redraw()

func _draw() -> void:
	if _mesh.get_surface_count() > 0:
		draw_mesh(_mesh, null)
