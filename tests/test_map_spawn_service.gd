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
