extends RefCounted

const MovingRouteUtil = preload("res://scripts/moving_route_util.gd")

const EPSILON := 0.0001


func _points(values: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(values.size())
	for i in range(values.size()):
		out[i] = values[i]
	return out


func test_route_length_open_polyline_sums_segments() -> String:
	var pts := _points([
		Vector3(0.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 5.0),
	])
	var length := MovingRouteUtil.route_length(pts, false)
	if abs(length - 15.0) > EPSILON:
		return "expected 15.0, got %f" % length
	return ""


func test_route_length_closed_polyline_adds_closing_segment() -> String:
	var pts := _points([
		Vector3(0.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 5.0),
	])
	var expected := 15.0 + sqrt(100.0 + 25.0)
	var length := MovingRouteUtil.route_length(pts, true)
	if abs(length - expected) > EPSILON:
		return "expected %f, got %f" % [expected, length]
	return ""


func test_sample_route_at_zero_returns_start() -> String:
	var pts := _points([Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)])
	var sample := MovingRouteUtil.sample_route(pts, false, 0.0)
	var pos: Vector3 = sample["position"]
	if pos.distance_to(Vector3(0.0, 0.0, 0.0)) > EPSILON:
		return "expected start, got %s" % str(pos)
	return ""


func test_sample_route_midway_in_first_segment() -> String:
	var pts := _points([Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)])
	var sample := MovingRouteUtil.sample_route(pts, false, 5.0)
	var pos: Vector3 = sample["position"]
	if pos.distance_to(Vector3(5.0, 0.0, 0.0)) > EPSILON:
		return "expected (5,0,0), got %s" % str(pos)
	return ""


func test_sample_route_crosses_segment_boundary() -> String:
	var pts := _points([
		Vector3(0.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 5.0),
	])
	var sample := MovingRouteUtil.sample_route(pts, false, 12.0)
	var pos: Vector3 = sample["position"]
	if pos.distance_to(Vector3(10.0, 0.0, 2.0)) > EPSILON:
		return "expected (10,0,2), got %s" % str(pos)
	return ""


func test_sample_route_wraps_loop_distance() -> String:
	var pts := _points([Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)])
	# Loop length is 20.0 (10 there + 10 back).
	var first := MovingRouteUtil.sample_route(pts, true, 3.0)
	var wrapped := MovingRouteUtil.sample_route(pts, true, 23.0)
	var a: Vector3 = first["position"]
	var b: Vector3 = wrapped["position"]
	if a.distance_to(b) > EPSILON:
		return "expected wrap to match, got %s vs %s" % [str(a), str(b)]
	return ""


func test_sample_route_tangent_is_unit_along_segment() -> String:
	var pts := _points([Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)])
	var sample := MovingRouteUtil.sample_route(pts, false, 5.0)
	var tangent: Vector3 = sample["tangent"]
	var expected := Vector3(1.0, 0.0, 0.0)
	if tangent.distance_to(expected) > EPSILON:
		return "expected (1,0,0), got %s" % str(tangent)
	return ""


func test_sample_route_clamps_past_end_for_open_route() -> String:
	var pts := _points([Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)])
	var sample := MovingRouteUtil.sample_route(pts, false, 50.0)
	var pos: Vector3 = sample["position"]
	if pos.distance_to(Vector3(10.0, 0.0, 0.0)) > EPSILON:
		return "expected end-clamp (10,0,0), got %s" % str(pos)
	return ""


func test_sample_route_handles_negative_distance_with_loop() -> String:
	var pts := _points([Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)])
	# -3 + 20 == 17, equivalent to distance 17 on a 20m loop (= 3 into return leg).
	var a := MovingRouteUtil.sample_route(pts, true, -3.0)
	var b := MovingRouteUtil.sample_route(pts, true, 17.0)
	var pa: Vector3 = a["position"]
	var pb: Vector3 = b["position"]
	if pa.distance_to(pb) > EPSILON:
		return "negative distance should wrap, got %s vs %s" % [str(pa), str(pb)]
	return ""
