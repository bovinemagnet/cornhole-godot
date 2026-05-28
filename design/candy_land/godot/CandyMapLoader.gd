extends Node
class_name CandyMapLoader

## Simple Godot 4 helper for loading the Candy Collapse map JSON files.
## Usage:
##   var data := CandyMapLoader.load_map("res://maps/candy/json/map_01_lollipop_lawn.json")
##   var world_pos := CandyMapLoader.npos(Vector2(data.regions[0].rect.x, data.regions[0].rect.y), data)

static func load_json(path: String) -> Variant:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Could not open JSON: " + path)
        return null
    var text: String = file.get_as_text()
    var parsed: Variant = JSON.parse_string(text)
    if parsed == null:
        push_error("Invalid JSON: " + path)
    return parsed

static func load_manifest(path: String = "res://maps/candy/manifest.json") -> Dictionary:
    var data: Variant = load_json(path)
    if typeof(data) != TYPE_DICTIONARY:
        return {}
    return data

static func load_map(path: String) -> Dictionary:
    var data: Variant = load_json(path)
    if typeof(data) != TYPE_DICTIONARY:
        return {}
    return data

static func npos(normalized: Vector2, map_data: Dictionary) -> Vector2:
    var godot_import: Dictionary = map_data.get("godot_import", {})
    var world: Dictionary = godot_import.get("world_size_px", {"x": 2048, "y": 2048})
    return Vector2(normalized.x * float(world["x"]), normalized.y * float(world["y"]))

static func nsize(normalized_size: Vector2, map_data: Dictionary) -> Vector2:
    var godot_import: Dictionary = map_data.get("godot_import", {})
    var world: Dictionary = godot_import.get("world_size_px", {"x": 2048, "y": 2048})
    return Vector2(normalized_size.x * float(world["x"]), normalized_size.y * float(world["y"]))

static func region_center(region: Dictionary, map_data: Dictionary) -> Vector2:
    match region.get("shape", ""):
        "circle":
            var c: Dictionary = region.get("center", {"x": 0.5, "y": 0.5})
            return npos(Vector2(c["x"], c["y"]), map_data)
        "rect":
            var r: Dictionary = region.get("rect", {"x": 0, "y": 0, "w": 1, "h": 1})
            return npos(Vector2(r["x"] + r["w"] * 0.5, r["y"] + r["h"] * 0.5), map_data)
        "polygon":
            var pts: Array = region.get("points", [])
            if pts.is_empty():
                return Vector2.ZERO
            var acc: Vector2 = Vector2.ZERO
            for p in pts:
                acc += npos(Vector2(p["x"], p["y"]), map_data)
            return acc / float(pts.size())
    return Vector2.ZERO
