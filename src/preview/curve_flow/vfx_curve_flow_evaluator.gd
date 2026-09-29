extends RefCounted
## F1 vehicle-local distance evaluator. No world-history or external clock.
## Adaptive de Casteljau: summed control-polygon minus chord <= 0.05px/cubic.
## Chords <= 4px; sample() interpolates cumulative chord length, never raw t.

const ARC_ERROR_PER_CUBIC := 0.05
const MAX_CHORD := 4.0
var lanes: Array = []
var tables: Array = []
var segments: Array = []
var time := 0.0
var emitting := false
var birth_count := 0
var skipped_births := 0
var _next_birth: Array[float] = []

func configure(definitions: Array) -> void:
	lanes = definitions.duplicate(true)
	tables.clear()
	for lane in lanes:
		assert(lane.speed > 0 and lane.interval > 0 and lane.length > 0 and lane.cap > 0)
		var points: Array[Vector2] = [lane.curves[0][0]]
		for c in lane.curves:
			_flatten(c[0], c[1], c[2], c[3], ARC_ERROR_PER_CUBIC, 0, points)
		var distances: Array[float] = [0.0]
		for j in range(1, points.size()):
			distances.append(distances[-1] + points[j].distance_to(points[j - 1]))
		tables.append({"points": points, "distances": distances, "length": distances[-1]})
	restart()

func restart() -> void:
	time = 0.0
	emitting = true
	segments.clear()
	birth_count = 0
	skipped_births = 0
	_next_birth.clear()
	for lane in lanes:
		_next_birth.append(float(lane.delay))

func stop() -> void:
	emitting = false

func clear() -> void:
	emitting = false
	segments.clear()

func advance(delta: float) -> void:
	assert(delta >= 0.0)
	time += delta
	if emitting:
		for i in lanes.size():
			var lane: Dictionary = lanes[i]
			while _next_birth[i] <= time + 1.0e-9:
				var born: float = _next_birth[i]
				var alive := 0
				for s in segments:
					if s.lane == i and (born - s.born) * lane.speed < tables[i].length + lane.length:
						alive += 1
				if alive < int(lane.cap):
					segments.append({"lane": i, "born": born, "head": 0.0})
					birth_count += 1
				else:
					skipped_births += 1
				_next_birth[i] += float(lane.interval)
	var survivors: Array = []
	for s in segments:
		s.head = (time - s.born) * float(lanes[s.lane].speed)
		if s.head < float(tables[s.lane].length) + float(lanes[s.lane].length):
			survivors.append(s)
	segments = survivors

func sample(lane_index: int, distance: float) -> Vector2:
	var table: Dictionary = tables[lane_index]
	var d := clampf(distance, 0.0, table.length)
	var lo := 0
	var hi: int = table.distances.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if table.distances[mid] <= d:
			lo = mid
		else:
			hi = mid
	var span: float = table.distances[hi] - table.distances[lo]
	return table.points[lo].lerp(table.points[hi], (d - table.distances[lo]) / maxf(span, 0.000001))

func tangent(lane_index: int, distance: float) -> Vector2:
	return (sample(lane_index, distance + 1.0) - sample(lane_index, distance - 1.0)).normalized()

func _flatten(a: Vector2, b: Vector2, c: Vector2, d: Vector2, tolerance: float, depth: int, points: Array[Vector2]) -> void:
	var chord := a.distance_to(d)
	var polygon := a.distance_to(b) + b.distance_to(c) + c.distance_to(d)
	if depth >= 20 or (polygon - chord <= tolerance and chord <= MAX_CHORD):
		points.append(d)
		return
	var ab := (a + b) * 0.5
	var bc := (b + c) * 0.5
	var cd := (c + d) * 0.5
	var abc := (ab + bc) * 0.5
	var bcd := (bc + cd) * 0.5
	var center := (abc + bcd) * 0.5
	_flatten(a, ab, abc, center, tolerance * 0.5, depth + 1, points)
	_flatten(center, bcd, cd, d, tolerance * 0.5, depth + 1, points)
