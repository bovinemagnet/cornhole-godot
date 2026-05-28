extends RefCounted

# Pure route sampling helpers for deterministic moving props. Routes are
# polylines in 3D, but only XZ length is what gameplay cares about. When
# `loop` is true, the closing segment from the last point back to the first is
# included and sampled distances wrap modulo route length so the same
# `elapsed * speed + phase_offset` can be fed in every frame.


static func route_length(points: PackedVector3Array, loop: bool) -> float:
	if points.size() < 2:
		return 0.0
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	if loop:
		total += points[points.size() - 1].distance_to(points[0])
	return total


# Returns { "position": Vector3, "tangent": Vector3 } at the given distance.
# `tangent` is a unit vector pointing along the direction of travel; callers
# can derive a Y-rotation from atan2(tangent.x, tangent.z) or similar.
static func sample_route(points: PackedVector3Array, loop: bool, distance: float) -> Dictionary:
	if points.size() == 0:
		return {"position": Vector3.ZERO, "tangent": Vector3.FORWARD}
	if points.size() == 1:
		return {"position": points[0], "tangent": Vector3.FORWARD}

	var length := route_length(points, loop)
	var d := distance
	if loop and length > 0.0:
		d = fposmod(distance, length)
	else:
		d = clamp(distance, 0.0, length)

	var segment_count: int = points.size() - 1
	var last_index := segment_count
	if loop:
		last_index = points.size()

	var travelled := 0.0
	for i in range(last_index):
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()] if loop else points[i + 1]
		var segment_length := a.distance_to(b)
		if segment_length <= 0.0:
			continue
		if d <= travelled + segment_length:
			var t := (d - travelled) / segment_length
			var position := a.lerp(b, t)
			var tangent := (b - a) / segment_length
			return {"position": position, "tangent": tangent}
		travelled += segment_length

	# Clamp past the end: return the last point with the previous tangent.
	var tail := points[points.size() - 1]
	var prev := points[points.size() - 2]
	var tail_segment := tail - prev
	var tail_length := tail_segment.length()
	var tangent_out := Vector3.FORWARD if tail_length <= 0.0 else tail_segment / tail_length
	return {"position": tail, "tangent": tangent_out}
