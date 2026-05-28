extends RefCounted

const MapCatalog = preload("res://scripts/map_catalog.gd")
const MapDefinition = preload("res://scripts/map_definition.gd")

const EPSILON := 0.001


func _minimal_map(id: String = "alpha") -> Dictionary:
	return {"id": id, "name": "Alpha", "seed": 1001}


func test_returns_empty_for_missing_id() -> String:
	var raw := {"name": "no id", "seed": 1001}
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	if not def.is_empty():
		return "expected empty dict for missing id"
	return ""


func test_returns_empty_for_missing_name() -> String:
	var raw := {"id": "x", "seed": 1001}
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	if not def.is_empty():
		return "expected empty dict for missing name"
	return ""


func test_returns_empty_for_missing_seed() -> String:
	var raw := {"id": "x", "name": "X"}
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	if not def.is_empty():
		return "expected empty dict for missing seed"
	return ""


func test_full_id_is_pack_prefixed() -> String:
	var def: Dictionary = MapDefinition.from_catalog_map("pack_a", "Pack A", _minimal_map("alpha"))
	if String(def["id"]) != "pack_a/alpha":
		return "expected 'pack_a/alpha', got %s" % String(def["id"])
	if String(def["map_id"]) != "alpha":
		return "expected map_id 'alpha', got %s" % String(def["map_id"])
	if String(def["pack_id"]) != "pack_a":
		return "expected pack_id 'pack_a'"
	if String(def["pack_name"]) != "Pack A":
		return "expected pack_name 'Pack A'"
	return ""


func test_size_defaults_to_arena_size_when_missing() -> String:
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", _minimal_map())
	var size: Vector2 = def["size"]
	if size != MapDefinition.DEFAULT_SIZE:
		return "expected default size %s, got %s" % [str(MapDefinition.DEFAULT_SIZE), str(size)]
	return ""


func test_size_array_is_coerced_to_vector2() -> String:
	var raw := _minimal_map()
	raw["size"] = [200, 160]
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	var size: Vector2 = def["size"]
	if not size.is_equal_approx(Vector2(200, 160)):
		return "expected (200, 160), got %s" % str(size)
	return ""


func test_missing_optional_arrays_default_to_empty() -> String:
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", _minimal_map())
	for key in ["ground_regions", "water_regions", "roads", "building_zones",
			"prop_spawn_zones", "people_paths", "moving_car_routes", "stack_spawn_points"]:
		if not def.has(key):
			return "missing key %s" % key
		var arr: Array = def[key]
		if arr.size() != 0:
			return "expected %s to be empty by default" % key
	return ""


func test_region_center_and_size_become_vector2() -> String:
	var raw := _minimal_map()
	raw["ground_regions"] = [{"type": "grass", "center": [10, -5], "size": [40, 20]}]
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	var regions: Array = def["ground_regions"]
	if regions.size() != 1:
		return "expected 1 region, got %d" % regions.size()
	var region: Dictionary = regions[0]
	if String(region["type"]) != "grass":
		return "expected type 'grass'"
	var centre: Vector2 = region["center"]
	if not centre.is_equal_approx(Vector2(10, -5)):
		return "expected centre (10,-5), got %s" % str(centre)
	var size: Vector2 = region["size"]
	if not size.is_equal_approx(Vector2(40, 20)):
		return "expected size (40,20), got %s" % str(size)
	return ""


func test_region_missing_centre_or_size_is_skipped() -> String:
	var raw := _minimal_map()
	raw["ground_regions"] = [
		{"type": "ok", "center": [0, 0], "size": [10, 10]},
		{"type": "no_centre", "size": [10, 10]},
		{"type": "no_size", "center": [0, 0]},
	]
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	var regions: Array = def["ground_regions"]
	if regions.size() != 1:
		return "expected 1 surviving region, got %d" % regions.size()
	return ""


func test_road_points_become_packed_vector2_array() -> String:
	var raw := _minimal_map()
	raw["roads"] = [{"id": 0, "width": 9.0, "lane_count": 2, "points": [[0, -10], [0, 10]]}]
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	var roads: Array = def["roads"]
	if roads.size() != 1:
		return "expected 1 road, got %d" % roads.size()
	var road: Dictionary = roads[0]
	var points: PackedVector2Array = road["points"]
	if points.size() != 2:
		return "expected 2 points, got %d" % points.size()
	if not points[0].is_equal_approx(Vector2(0, -10)) or not points[1].is_equal_approx(Vector2(0, 10)):
		return "road points not coerced correctly"
	if abs(float(road["width"]) - 9.0) > EPSILON:
		return "road width not preserved"
	return ""


func test_road_with_fewer_than_two_points_is_skipped() -> String:
	var raw := _minimal_map()
	raw["roads"] = [
		{"id": 0, "width": 9.0, "points": [[0, 0]]},
		{"id": 1, "width": 9.0, "points": [[0, 0], [10, 0]]},
	]
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	if def["roads"].size() != 1:
		return "expected 1 surviving road, got %d" % def["roads"].size()
	return ""


func test_people_paths_become_packed_vector2_arrays() -> String:
	var raw := _minimal_map()
	raw["people_paths"] = [{"id": 0, "points": [[0, 0], [5, 5], [10, 0]]}]
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	var paths: Array = def["people_paths"]
	var path: Dictionary = paths[0]
	var points: PackedVector2Array = path["points"]
	if points.size() != 3:
		return "expected 3 path points, got %d" % points.size()
	return ""


func test_stack_position_becomes_vector2() -> String:
	var raw := _minimal_map()
	raw["stack_spawn_points"] = [{"type": "boxes", "position": [3, 7], "count": 5}]
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	var stacks: Array = def["stack_spawn_points"]
	var stack: Dictionary = stacks[0]
	var pos: Vector2 = stack["position"]
	if not pos.is_equal_approx(Vector2(3, 7)):
		return "expected (3,7), got %s" % str(pos)
	if int(stack["count"]) != 5:
		return "expected count 5, got %d" % int(stack["count"])
	return ""


func test_moving_car_route_preserves_road_reference_and_speed() -> String:
	var raw := _minimal_map()
	raw["moving_car_routes"] = [{"id": 0, "road_id": 2, "speed": 7.5}]
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	var routes: Array = def["moving_car_routes"]
	var route: Dictionary = routes[0]
	if int(route["road_id"]) != 2:
		return "expected road_id 2"
	if abs(float(route["speed"]) - 7.5) > EPSILON:
		return "expected speed 7.5"
	return ""


func test_difficulty_defaults_to_zero() -> String:
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", _minimal_map())
	if int(def.get("difficulty", -1)) != 0:
		return "expected default difficulty 0, got %s" % str(def.get("difficulty"))
	return ""


func test_difficulty_passes_through() -> String:
	var raw := _minimal_map()
	raw["difficulty"] = 7
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	if int(def["difficulty"]) != 7:
		return "expected difficulty 7, got %s" % str(def["difficulty"])
	return ""


func test_theme_passes_through() -> String:
	var raw := _minimal_map()
	raw["theme"] = "open park"
	var def: Dictionary = MapDefinition.from_catalog_map("p", "Pack", raw)
	if String(def["theme"]) != "open park":
		return "expected theme 'open park', got %s" % String(def["theme"])
	return ""


func test_every_real_catalog_map_normalises() -> String:
	# Load every pack via MapCatalog, then for each option re-load its
	# source catalog and verify each raw map normalises without error.
	var paths := PackedStringArray([
		"res://resources/maps/map_catalog.json",
		"res://resources/maps/kitty_land/kitty_land_catalog.json",
		"res://resources/maps/candy_land/candy_land_catalog.json",
		"res://resources/maps/robot_land/robot_land_catalog.json",
		"res://resources/maps/bunny_land/bunny_land_catalog.json",
		"res://resources/maps/dino_land/dino_land_catalog.json",
	])
	var normalised_count := 0
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var catalog: Dictionary = parsed
		var pack_id := String(catalog.get("pack_id", ""))
		var pack_name := String(catalog.get("name", pack_id))
		var maps_value: Variant = catalog.get("maps", [])
		if typeof(maps_value) != TYPE_ARRAY:
			continue
		for map_data in maps_value:
			if typeof(map_data) != TYPE_DICTIONARY:
				continue
			var def: Dictionary = MapDefinition.from_catalog_map(pack_id, pack_name, map_data)
			if def.is_empty():
				return "failed to normalise %s/%s" % [pack_id, String(map_data.get("id", "?"))]
			normalised_count += 1
	if normalised_count < 6:
		return "expected >=6 normalised maps across real catalogs, got %d" % normalised_count
	return ""
