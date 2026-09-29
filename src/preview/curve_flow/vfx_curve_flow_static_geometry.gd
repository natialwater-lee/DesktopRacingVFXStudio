extends RefCounted
## Immutable F2 entries are owned by a render plan, not a global/session service.
const Evaluator := preload("res://src/preview/curve_flow/vfx_curve_flow_evaluator.gd")
const Contract := preload("res://src/preview/curve_flow/vfx_curve_flow_contract.gd")
const SAMPLE_STEP := 3.0
const HEAD_CAPACITY := 64
class Prepared extends RefCounted:
	var _mesh: ArrayMesh
	var _tables: Array
	var mesh: ArrayMesh:
		get: return _mesh
	var tables: Array:
		get: return _tables
	func _init(value: ArrayMesh, values: Array) -> void:
		_mesh = value
		_tables = values

static func key(p: Dictionary) -> String:
	return var_to_bytes([2,p.curves,p.half_width,p.cap,SAMPLE_STEP,HEAD_CAPACITY,Evaluator.ARC_ERROR_PER_CUBIC,Evaluator.MAX_CHORD,1.0,0.000001,235.0]).hex_encode().sha256_text()

static func prepare(p: Dictionary) -> Prepared:
	var flow := Evaluator.new()
	flow.configure([Contract.lane(p)])
	var lane: Dictionary = flow.lanes[0]
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var length: float = flow.tables[0].length
	var end_y: float = flow.tables[0].points[-1].y
	var count := maxi(2, ceili(length / SAMPLE_STEP))
	for slot in int(lane.cap):
		var base := vertices.size()
		for j in range(count + 1):
			var d := lerpf(0.0, length, float(j) / count)
			var point: Vector2 = flow.sample(0, d)
			var tangent: Vector2 = flow.tangent(0, d)
			var normal := Vector2(-tangent.y, tangent.x)
			var release := 1.0 - smoothstep(235.0, end_y, point.y)
			for side_index in 2:
				var side := -1.0 if side_index == 0 else 1.0
				var v: Vector2 = point + normal * float(lane.half_width) * side
				vertices.append(Vector3(v.x, v.y, 0.0))
				uvs.append(Vector2(d, float(side_index)))
				colors.append(Color(float(slot) / HEAD_CAPACITY, release, 0.0, 1.0))
			if j < count:
				var k := base + j * 2
				indices.append_array(PackedInt32Array([k,k+1,k+2,k+1,k+3,k+2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	for table in flow.tables:
		table.points.make_read_only(); table.distances.make_read_only(); table.make_read_only()
	flow.tables.make_read_only()
	return Prepared.new(mesh, flow.tables)
