extends RefCounted

const MovingCarSpawn = preload("res://scripts/moving_car_spawn.gd")

const EPSILON := 0.0001


func _lengths(values: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(values.size())
	for i in range(values.size()):
		out[i] = float(values[i])
	return out


func _spawns_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		var x: Dictionary = a[i]
		var y: Dictionary = b[i]
		if int(x["id"]) != int(y["id"]):
			return false
		if int(x["route_id"]) != int(y["route_id"]):
			return false
		if abs(float(x["phase_offset"]) - float(y["phase_offset"])) > EPSILON:
			return false
		if abs(float(x["speed"]) - float(y["speed"])) > EPSILON:
			return false
	return true


func test_same_seed_produces_same_spawns() -> String:
	var lengths := _lengths([40.0, 60.0, 80.0])
	var first := MovingCarSpawn.make_spawns(123, 8, lengths, 2.0, 5.0)
	var second := MovingCarSpawn.make_spawns(123, 8, lengths, 2.0, 5.0)
	if not _spawns_equal(first, second):
		return "expected identical spawn lists for same seed"
	return ""


func test_different_seed_changes_spawn_data() -> String:
	var lengths := _lengths([40.0, 60.0, 80.0])
	var first := MovingCarSpawn.make_spawns(123, 8, lengths, 2.0, 5.0)
	var second := MovingCarSpawn.make_spawns(124, 8, lengths, 2.0, 5.0)
	if _spawns_equal(first, second):
		return "expected different spawn data for different seed"
	return ""


func test_spawn_count_matches_request() -> String:
	var lengths := _lengths([50.0])
	var spawns := MovingCarSpawn.make_spawns(7, 5, lengths, 1.0, 1.0)
	if spawns.size() != 5:
		return "expected 5 spawns, got %d" % spawns.size()
	return ""


func test_spawn_ids_are_dedicated_range_and_stable_order() -> String:
	var lengths := _lengths([50.0])
	var spawns := MovingCarSpawn.make_spawns(7, 4, lengths, 1.0, 1.0)
	for i in range(spawns.size()):
		var expected_id := MovingCarSpawn.MOVING_PROP_ID_BASE + i
		var actual_id := int(spawns[i]["id"])
		if actual_id != expected_id:
			return "spawn %d expected id %d, got %d" % [i, expected_id, actual_id]
	return ""


func test_phase_offset_is_within_route_length() -> String:
	var lengths := _lengths([30.0, 90.0])
	var spawns := MovingCarSpawn.make_spawns(42, 20, lengths, 1.0, 1.0)
	for spawn in spawns:
		var route_id := int(spawn["route_id"])
		var phase := float(spawn["phase_offset"])
		if route_id < 0 or route_id >= lengths.size():
			return "route_id %d out of range" % route_id
		if phase < 0.0 or phase > float(lengths[route_id]):
			return "phase %f out of bounds for route_length %f" % [phase, float(lengths[route_id])]
	return ""


func test_speed_is_within_requested_range() -> String:
	var lengths := _lengths([50.0])
	var spawns := MovingCarSpawn.make_spawns(99, 20, lengths, 2.5, 6.5)
	for spawn in spawns:
		var speed := float(spawn["speed"])
		if speed < 2.5 - EPSILON or speed > 6.5 + EPSILON:
			return "speed %f out of range [2.5, 6.5]" % speed
	return ""


func test_zero_count_returns_empty() -> String:
	var spawns := MovingCarSpawn.make_spawns(1, 0, _lengths([50.0]), 1.0, 1.0)
	if spawns.size() != 0:
		return "expected empty, got %d" % spawns.size()
	return ""


func test_empty_routes_returns_empty() -> String:
	var spawns := MovingCarSpawn.make_spawns(1, 5, _lengths([]), 1.0, 1.0)
	if spawns.size() != 0:
		return "expected empty, got %d" % spawns.size()
	return ""
