extends Node
class_name BunnyMapLoader

## Minimal loader for Bunny Map Pack JSON files.
## Copy the BunnyMapPack folder into res://BunnyMapPack, then call:
##   var manifest = BunnyMapLoader.load_json("res://BunnyMapPack/manifest.json")
##   var map_data = BunnyMapLoader.load_map_by_id("map_01_bunny_meadow")

const PACK_ROOT := "res://BunnyMapPack"
const MAPS_ROOT := PACK_ROOT + "/maps"

static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("JSON file not found: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON dictionary: " + path)
		return {}
	return parsed

static func load_manifest() -> Dictionary:
	return load_json(PACK_ROOT + "/manifest.json")

static func load_map_by_id(map_id: String) -> Dictionary:
	return load_json(MAPS_ROOT + "/" + map_id + ".json")

static func normalized_point_to_world(point: Array, world_size: Vector2) -> Vector2:
	return Vector2(float(point[0]) * world_size.x, float(point[1]) * world_size.y)

static func normalized_polygon_to_world(points: Array, world_size: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(normalized_point_to_world(p, world_size))
	return result

static func map_world_size(map_data: Dictionary) -> Vector2:
	var s: Dictionary = map_data.get("world", {}).get("recommended_world_size", {"width": 2400, "height": 2400})
	return Vector2(float(s.get("width", 2400)), float(s.get("height", 2400)))
