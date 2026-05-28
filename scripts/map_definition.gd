extends RefCounted

# Normalises raw catalog map dictionaries into a stable runtime shape that
# the rest of gameplay consumes. Pure (no IO) — feed it the parsed JSON
# entry plus the pack metadata. Returns {} when required fields are missing
# so callers can drop invalid entries safely.
#
# Output shape:
#   {
#     id: "<pack_id>/<map_id>", map_id: String, name: String,
#     pack_id: String, pack_name: String, seed: int, size: Vector2,
#     ground_regions: Array[Dictionary], water_regions: Array[Dictionary],
#     building_zones: Array[Dictionary], prop_spawn_zones: Array[Dictionary],
#     roads: Array[Dictionary], people_paths: Array[Dictionary],
#     moving_car_routes: Array[Dictionary], stack_spawn_points: Array[Dictionary],
#   }
# Regions carry { type: String, center: Vector2, size: Vector2 }.
# Roads carry { id: int, width: float, lane_count: int, points: PackedVector2Array }.
# People paths carry { id: int, points: PackedVector2Array }.
# Stacks carry { type: String, position: Vector2, count: int }.

const DEFAULT_SIZE := Vector2(144.0, 144.0)


static func from_catalog_map(pack_id: String, pack_name: String, map_data: Dictionary) -> Dictionary:
	if not map_data.has("id") or not map_data.has("name") or not map_data.has("seed"):
		return {}

	var map_id := String(map_data["id"])
	return {
		"id": "%s/%s" % [pack_id, map_id],
		"map_id": map_id,
		"name": String(map_data["name"]),
		"pack_id": pack_id,
		"pack_name": pack_name,
		"seed": int(map_data["seed"]),
		"size": _coerce_vector2(map_data.get("size", null), DEFAULT_SIZE),
		"ground_regions": _normalise_regions(map_data.get("ground_regions", [])),
		"water_regions": _normalise_regions(map_data.get("water_regions", [])),
		"building_zones": _normalise_regions(map_data.get("building_zones", [])),
		"prop_spawn_zones": _normalise_regions(map_data.get("prop_spawn_zones", [])),
		"roads": _normalise_roads(map_data.get("roads", [])),
		"people_paths": _normalise_paths(map_data.get("people_paths", [])),
		"moving_car_routes": _normalise_car_routes(map_data.get("moving_car_routes", [])),
		"stack_spawn_points": _normalise_stacks(map_data.get("stack_spawn_points", [])),
	}


static func _coerce_vector2(value: Variant, fallback: Vector2) -> Vector2:
	match typeof(value):
		TYPE_VECTOR2:
			return value
		TYPE_ARRAY:
			var arr: Array = value
			if arr.size() >= 2:
				return Vector2(float(arr[0]), float(arr[1]))
		TYPE_DICTIONARY:
			var d: Dictionary = value
			if d.has("x") and d.has("y"):
				return Vector2(float(d["x"]), float(d["y"]))
	return fallback


static func _normalise_regions(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var dict: Dictionary = entry
		if not dict.has("center") or not dict.has("size"):
			continue
		out.append({
			"type": String(dict.get("type", "")),
			"center": _coerce_vector2(dict["center"], Vector2.ZERO),
			"size": _coerce_vector2(dict["size"], Vector2.ZERO),
		})
	return out


static func _packed_points(value: Variant) -> PackedVector2Array:
	var points := PackedVector2Array()
	if typeof(value) != TYPE_ARRAY:
		return points
	var arr: Array = value
	for entry in arr:
		points.append(_coerce_vector2(entry, Vector2.ZERO))
	return points


static func _normalise_roads(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var dict: Dictionary = entry
		var points := _packed_points(dict.get("points", []))
		if points.size() < 2:
			continue
		out.append({
			"id": int(dict.get("id", out.size())),
			"width": float(dict.get("width", 8.0)),
			"lane_count": int(dict.get("lane_count", 2)),
			"points": points,
		})
	return out


static func _normalise_paths(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var dict: Dictionary = entry
		var points := _packed_points(dict.get("points", []))
		if points.size() < 2:
			continue
		out.append({
			"id": int(dict.get("id", out.size())),
			"points": points,
		})
	return out


static func _normalise_car_routes(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var dict: Dictionary = entry
		if not dict.has("road_id"):
			continue
		out.append({
			"id": int(dict.get("id", out.size())),
			"road_id": int(dict["road_id"]),
			"speed": float(dict.get("speed", 6.0)),
		})
	return out


static func _normalise_stacks(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for entry in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var dict: Dictionary = entry
		if not dict.has("position"):
			continue
		out.append({
			"type": String(dict.get("type", "")),
			"position": _coerce_vector2(dict["position"], Vector2.ZERO),
			"count": int(dict.get("count", 1)),
		})
	return out
