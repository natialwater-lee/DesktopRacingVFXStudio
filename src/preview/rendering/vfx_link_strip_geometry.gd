class_name VfxLinkStripGeometry
extends RefCounted
## Pure LINK_STRIP geometry shared by Preview and the Game port (contract: docs/contracts/link_strip_v1.md).
## All positions are host-vehicle source-local px. Returns 0..2 polylines (2 while a gap is open).

const MIN_VISIBLE_SOURCE_PX := 1.0


## Visible parameter ranges along the link, u in [0, 1] from start to end.
static func visible_ranges(parameters: Dictionary, phase_elapsed_seconds: float) -> Array:
	var reveal := _progress(phase_elapsed_seconds, float(parameters.get("reveal_seconds", 0.0)), true)
	var retract := _progress(phase_elapsed_seconds, float(parameters.get("retract_seconds", 0.0)), false)
	var gap := _progress(phase_elapsed_seconds, float(parameters.get("gap_seconds", 0.0)), false)
	var high := minf(reveal, 1.0 - retract)
	if high <= 0.0:
		return []
	if gap <= 0.0:
		return [Vector2(0.0, high)]
	var ranges: Array = []
	var gap_low := 0.5 - gap * 0.5
	var gap_high := 0.5 + gap * 0.5
	if gap_low > 0.0:
		ranges.append(Vector2(0.0, minf(gap_low, high)))
	if gap_high < high:
		ranges.append(Vector2(gap_high, high))
	return ranges


## Extra sag that grows while the gap opens (the broken halves go limp).
static func gap_sag(parameters: Dictionary, phase_elapsed_seconds: float) -> float:
	return float(parameters.get("gap_sag_source_px", 0.0)) * _progress(phase_elapsed_seconds, float(parameters.get("gap_seconds", 0.0)), false)


## Sag direction: host backward (+Y) made perpendicular to the link; +X when the link is lateral-free.
static func sag_normal(direction: Vector2) -> Vector2:
	var normal := Vector2(-direction.y, direction.x)
	if normal.y < -0.0001 or (absf(normal.y) <= 0.0001 and normal.x < 0.0):
		normal = -normal
	return normal


static func build(start: Vector2, end: Vector2, parameters: Dictionary, sag_source_px: float, phase_elapsed_seconds: float) -> Array:
	var span := end - start
	var length := span.length()
	if length <= MIN_VISIBLE_SOURCE_PX:
		return []
	var direction := span / length
	var inset_start := float(parameters.get("start_inset_source_px", 0.0))
	var inset_end := float(parameters.get("end_inset_source_px", 0.0))
	if length - inset_start - inset_end <= MIN_VISIBLE_SOURCE_PX:
		return []
	var a := start + direction * inset_start
	var b := end - direction * inset_end
	var normal := sag_normal(direction)
	# Whole-strip shift (e.g. a drop shadow); the layer offset only moves the start point.
	var shift_value: Variant = parameters.get("shift_source_px", [0.0, 0.0])
	var shift := Vector2(float(shift_value[0]), float(shift_value[1])) if shift_value is Array and shift_value.size() == 2 else Vector2.ZERO
	a += shift
	b += shift
	var segments := clampi(int(parameters.get("segments", 8)), 1, 16)
	var lines: Array = []
	for range_value in visible_ranges(parameters, phase_elapsed_seconds):
		var visible: Vector2 = range_value
		if (visible.y - visible.x) * a.distance_to(b) <= MIN_VISIBLE_SOURCE_PX:
			continue
		var count := maxi(1, ceili(segments * (visible.y - visible.x)))
		var points := PackedVector2Array()
		for index in count + 1:
			var u := lerpf(visible.x, visible.y, float(index) / float(count))
			points.append(a.lerp(b, u) + normal * sag_source_px * 4.0 * u * (1.0 - u))
		lines.append(points)
	return lines


## Linear progress 0..1 over `seconds`; ease-out for reveal. Zero seconds = done (reveal) / not started.
static func _progress(elapsed: float, seconds: float, reveal: bool) -> float:
	if seconds <= 0.0:
		return 1.0 if reveal else 0.0
	var t := clampf(elapsed / seconds, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0) if reveal else t
