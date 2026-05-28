
extends RefCounted
class_name PrehistoricMapLoader

static func load_manifest(path: String) -> Dictionary:
    var text := FileAccess.get_file_as_string(path)
    if text.is_empty():
        push_error("Could not read manifest: %s" % path)
        return {}
    var parsed = JSON.parse_string(text)
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

static func load_map(path: String) -> Dictionary:
    var text := FileAccess.get_file_as_string(path)
    if text.is_empty():
        push_error("Could not read map json: %s" % path)
        return {}
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Map JSON is not a dictionary: %s" % path)
        return {}
    return parsed

static func validate_basic(map_data: Dictionary) -> bool:
    if not map_data.has("map"):
        return false
    var m: Dictionary = map_data["map"]
    var required = ["id", "name", "difficulty", "bounds", "regions", "spawn_points", "object_tiers", "gameplay_rules"]
    for key in required:
        if not m.has(key):
            push_warning("Missing required key: %s" % key)
            return false
    return true

static func to_world(point: Vector2, world_size: Vector2) -> Vector2:
    return Vector2(point.x * world_size.x, point.y * world_size.y)
