
extends Node2D
class_name PrehistoricMapDebugBuilder

@export var world_size: Vector2 = Vector2(2048, 2048)
@export var map_json_path: String
@export var draw_spawn_points := true
@export var draw_labels := true

var map_data: Dictionary = {}

func _ready() -> void:
    if map_json_path != "":
        map_data = PrehistoricMapLoader.load_map(map_json_path)
        queue_redraw()

func _draw() -> void:
    if map_data.is_empty() or not map_data.has("map"):
        return
    var m: Dictionary = map_data["map"]
    var color_by_type = {
        "safe_area": Color(0.2, 0.8, 0.3, 0.25),
        "pickup_zone": Color(0.2, 0.6, 1.0, 0.25),
        "lane": Color(1.0, 0.8, 0.2, 0.25),
        "hub": Color(0.8, 0.4, 1.0, 0.25),
        "hazard_zone": Color(1.0, 0.25, 0.25, 0.25),
        "bridge": Color(0.9, 0.9, 0.9, 0.25),
        "boss_zone": Color(1.0, 0.2, 0.8, 0.25),
        "swamp": Color(0.3, 0.7, 0.5, 0.25),
        "jungle": Color(0.2, 0.7, 0.2, 0.25)
    }

    for region in m.get("regions", []):
        var pts := PackedVector2Array()
        for p in region.get("polygon", []):
            pts.append(Vector2(p[0], p[1]) * world_size)
        var fill: Color = color_by_type.get(region.get("type", "lane"), Color(1,1,1,0.2))
        if pts.size() >= 3:
            draw_colored_polygon(pts, fill)
            for i in range(pts.size()):
                draw_line(pts[i], pts[(i + 1) % pts.size()], fill.darkened(0.35), 2.0)
            if draw_labels:
                draw_string(ThemeDB.fallback_font, pts[0] + Vector2(6, 16), region.get("id", "region"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

    if draw_spawn_points:
        for sp in m.get("spawn_points", []):
            var pos = Vector2(sp["position"][0], sp["position"][1]) * world_size
            draw_circle(pos, 10.0, Color(1.0, 0.95, 0.2))
            draw_circle(pos, 12.0, Color.BLACK, false, 2.0)
            if draw_labels:
                draw_string(ThemeDB.fallback_font, pos + Vector2(12, -8), sp.get("id", "spawn"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
