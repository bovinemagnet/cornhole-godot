extends RefCounted

const MapSpawnService = preload("res://scripts/map_spawn_service.gd")

const EPSILON := 0.001


func _zone(centre: Vector2, size: Vector2, type: String = "") -> Dictionary:
	return {"center": centre, "size": size, "type": type}


func _is_inside(point: Vector3, zone: Dictionary) -> bool:
	var centre: Vector2 = zone["center"]
	var size: Vector2 = zone["size"]
	var dx: float = abs(point.x - centre.x)
	var dz: float = abs(point.z - centre.y)
	return dx <= size.x * 0.5 + EPSILON and dz <= size.y * 0.5 + EPSILON


func test_same_seed_produces_same_positions() -> String:
	var zones := [_zone(Vector2(0, 0), Vector2(40, 40), "scatter")]
	var a := MapSpawnService.choose_static_prop_positions(123, 1, 50, zones, [], 72.0, 6.0)
	var b := MapSpawnService.choose_static_prop_positions(123, 1, 50, zones, [], 72.0, 6.0)
	if a.size() != b.size():
		return "different size: %d vs %d" % [a.size(), b.size()]
	for i in range(a.size()):
		if not a[i].is_equal_approx(b[i]):
			return "position %d differs: %s vs %s" % [i, str(a[i]), str(b[i])]
	return ""


func test_different_seed_produces_different_positions() -> String:
	var zones := [_zone(Vector2(0, 0), Vector2(40, 40))]
	var a := MapSpawnService.choose_static_prop_positions(123, 1, 50, zones, [], 72.0, 6.0)
	var b := MapSpawnService.choose_static_prop_positions(456, 1, 50, zones, [], 72.0, 6.0)
	var identical_count := 0
	for i in range(a.size()):
		if a[i].is_equal_approx(b[i]):
			identical_count += 1
	if identical_count == a.size():
		return "two different seeds produced identical layouts"
	return ""


func test_positions_fall_inside_zones() -> String:
	var zones := [
		_zone(Vector2(-30, -30), Vector2(20, 20), "a"),
		_zone(Vector2(30, 30), Vector2(20, 20), "b"),
	]
	var positions := MapSpawnService.choose_static_prop_positions(42, 1, 100, zones, [], 72.0, 0.0)
	for pos in positions:
		var inside := false
		for zone in zones:
			if _is_inside(pos, zone):
				inside = true
				break
		if not inside:
			return "position %s outside all zones" % str(pos)
	return ""


func test_count_matches_request() -> String:
	var zones := [_zone(Vector2(0, 0), Vector2(40, 40))]
	var positions := MapSpawnService.choose_static_prop_positions(1, 1, 17, zones, [], 72.0, 6.0)
	if positions.size() != 17:
		return "expected 17 positions, got %d" % positions.size()
	return ""


func test_zero_count_returns_empty() -> String:
	var zones := [_zone(Vector2(0, 0), Vector2(40, 40))]
	var positions := MapSpawnService.choose_static_prop_positions(1, 1, 0, zones, [], 72.0, 6.0)
	if positions.size() != 0:
		return "expected empty, got %d" % positions.size()
	return ""


func test_fallback_to_full_arena_when_no_zones() -> String:
	var positions := MapSpawnService.choose_static_prop_positions(7, 1, 50, [], [], 72.0, 6.0)
	if positions.size() != 50:
		return "expected 50 fallback positions, got %d" % positions.size()
	for pos in positions:
		if abs(pos.x) > 72.0 or abs(pos.z) > 72.0:
			return "fallback position %s outside arena bounds" % str(pos)
	return ""


func test_water_rejection_keeps_positions_out_of_water() -> String:
	# Whole zone overlaps a water region except a small dry strip on the left.
	var zones := [_zone(Vector2(0, 0), Vector2(40, 40), "scatter")]
	var water := [_zone(Vector2(10, 0), Vector2(20, 40), "river")]
	var positions := MapSpawnService.choose_static_prop_positions(13, 1, 30, zones, water, 72.0, 0.0)
	for pos in positions:
		if _is_inside(pos, water[0]):
			return "position %s landed in water" % str(pos)
	return ""


func test_player_clearance_keeps_props_off_origin() -> String:
	var zones := [_zone(Vector2(0, 0), Vector2(20, 20))]
	var clearance := 5.0
	var positions := MapSpawnService.choose_static_prop_positions(99, 1, 80, zones, [], 72.0, clearance)
	for pos in positions:
		var distance := Vector2(pos.x, pos.z).length()
		if distance < clearance - 0.5:
			return "position %s only %f from origin, expected >= %f" % [str(pos), distance, clearance]
	return ""


func test_starter_props_spawn_in_ring_near_origin() -> String:
	# A far-away zone plus a guaranteed starter ring: the first `starter_count`
	# positions must land within [clearance, starter_radius] of origin.
	var zones := [_zone(Vector2(60, 60), Vector2(20, 20), "far")]
	var clearance := 4.0
	var starter_radius := 22.0
	var starter_count := 15
	var positions := MapSpawnService.choose_static_prop_positions(
		7, 1, 100, zones, [], 72.0, clearance, starter_count, starter_radius
	)
	for i in range(starter_count):
		var d := Vector2(positions[i].x, positions[i].z).length()
		if d < clearance - 0.5:
			return "starter prop %d at %f is inside clearance" % [i, d]
		if d > starter_radius + 0.5:
			return "starter prop %d at %f is beyond starter_radius %f" % [i, d, starter_radius]
	return ""


func test_non_starter_props_still_use_zones() -> String:
	var zones := [_zone(Vector2(60, 0), Vector2(10, 10), "far")]
	var positions := MapSpawnService.choose_static_prop_positions(
		7, 1, 40, zones, [], 72.0, 4.0, 10, 20.0
	)
	# Props after the starter block should sit in the far zone, not near origin.
	var found_far := false
	for i in range(10, positions.size()):
		if abs(positions[i].x - 60.0) <= 5.5 and abs(positions[i].z) <= 5.5:
			found_far = true
	if not found_far:
		return "expected non-starter props to use the far zone"
	return ""


func test_starter_count_zero_matches_no_starter_call() -> String:
	# Determinism guard: passing starter_count 0 must reproduce the original
	# (default-arg) behaviour exactly.
	var zones := [_zone(Vector2(0, 0), Vector2(40, 40))]
	var a := MapSpawnService.choose_static_prop_positions(55, 1, 30, zones, [], 72.0, 6.0)
	var b := MapSpawnService.choose_static_prop_positions(55, 1, 30, zones, [], 72.0, 6.0, 0, 20.0)
	if a.size() != b.size():
		return "size mismatch"
	for i in range(a.size()):
		if not a[i].is_equal_approx(b[i]):
			return "position %d differs when starter_count is 0" % i
	return ""


func test_starter_props_are_deterministic() -> String:
	var zones := [_zone(Vector2(50, 50), Vector2(20, 20))]
	var a := MapSpawnService.choose_static_prop_positions(88, 1, 40, zones, [], 72.0, 4.0, 12, 22.0)
	var b := MapSpawnService.choose_static_prop_positions(88, 1, 40, zones, [], 72.0, 4.0, 12, 22.0)
	for i in range(a.size()):
		if not a[i].is_equal_approx(b[i]):
			return "starter spawn not deterministic at %d" % i
	return ""


func test_starter_props_avoid_water() -> String:
	var zones := [_zone(Vector2(50, 50), Vector2(20, 20))]
	# Water covering the right half of the starter ring.
	var water := [_zone(Vector2(12, 0), Vector2(24, 48), "river")]
	var positions := MapSpawnService.choose_static_prop_positions(
		3, 1, 60, zones, water, 72.0, 3.0, 20, 22.0
	)
	for i in range(20):
		if _is_inside(positions[i], water[0]):
			return "starter prop %d landed in water" % i
	return ""
