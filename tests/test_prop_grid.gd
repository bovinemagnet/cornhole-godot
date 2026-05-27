extends RefCounted

const PropGrid = preload("res://scripts/prop_grid.gd")


func _make_grid(positions: Array) -> RefCounted:
	var packed := PackedVector2Array()
	packed.resize(positions.size())
	for i in range(positions.size()):
		packed[i] = positions[i]
	var grid: RefCounted = PropGrid.new()
	grid.build(packed, 50.0, 5.0)
	return grid


func _sorted(arr: PackedInt32Array) -> Array:
	var out: Array = []
	for v in arr:
		out.append(int(v))
	out.sort()
	return out


func test_query_returns_props_in_radius() -> String:
	var grid := _make_grid([
		Vector2(0.0, 0.0),
		Vector2(2.5, 0.0),
		Vector2(20.0, 20.0),
	])
	var result: PackedInt32Array = grid.query_radius(Vector2(0.0, 0.0), 4.0)
	var ids := _sorted(result)
	if not (ids.has(0) and ids.has(1)) or ids.has(2):
		return "expected ids 0 and 1 only, got %s" % str(ids)
	return ""


func test_query_excludes_distant_props() -> String:
	var grid := _make_grid([
		Vector2(-30.0, -30.0),
		Vector2(30.0, 30.0),
	])
	var result: PackedInt32Array = grid.query_radius(Vector2(0.0, 0.0), 3.0)
	if result.size() != 0:
		return "expected empty result, got %s" % str(_sorted(result))
	return ""


func test_query_at_corner_returns_local_props() -> String:
	var grid := _make_grid([
		Vector2(-49.0, -49.0),
		Vector2(-30.0, -30.0),
		Vector2(45.0, 45.0),
	])
	var result: PackedInt32Array = grid.query_radius(Vector2(-49.0, -49.0), 4.0)
	var ids := _sorted(result)
	if not ids.has(0) or ids.has(2):
		return "expected id 0, never id 2, got %s" % str(ids)
	return ""


func test_query_zero_radius_returns_same_cell_indices() -> String:
	var grid := _make_grid([
		Vector2(7.0, 7.0),
		Vector2(8.0, 8.0),
		Vector2(50.0, 50.0),
	])
	var result: PackedInt32Array = grid.query_radius(Vector2(7.5, 7.5), 0.0)
	var ids := _sorted(result)
	# Both 0 and 1 sit in the same 5m cell as the query point.
	if not (ids.has(0) and ids.has(1)) or ids.has(2):
		return "expected ids 0,1; got %s" % str(ids)
	return ""


func test_query_returns_empty_for_empty_grid() -> String:
	var grid: RefCounted = PropGrid.new()
	grid.build(PackedVector2Array(), 50.0, 5.0)
	var result: PackedInt32Array = grid.query_radius(Vector2.ZERO, 100.0)
	if result.size() != 0:
		return "expected empty, got size %d" % result.size()
	return ""


func test_query_large_radius_returns_all_props() -> String:
	var positions: Array = [
		Vector2(-40.0, -40.0),
		Vector2(0.0, 0.0),
		Vector2(40.0, 40.0),
		Vector2(20.0, -20.0),
	]
	var grid := _make_grid(positions)
	var result: PackedInt32Array = grid.query_radius(Vector2.ZERO, 200.0)
	if result.size() != positions.size():
		return "expected %d ids, got %d" % [positions.size(), result.size()]
	return ""
