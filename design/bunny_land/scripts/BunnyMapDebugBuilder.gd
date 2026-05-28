extends Node2D
class_name BunnyMapDebugBuilder

## Debug blockout builder. It draws regions, paths, spawn points, and hazard markers.
## This is intentionally simple so you can replace Polygon2D/Sprite2D placeholders
## with your real meshes, tiles, sprites, navigation, and collision generation.

@export var map_id := "map_01_bunny_meadow"
@export var auto_build_on_ready := true

var map_data: Dictionary = {}
var world_size := Vector2(2400, 2400)

func _ready() -> void:
	if auto_build_on_ready:
		build_from_id(map_id)

func build_from_id(id: String) -> void:
	clear_children()
	map_data = BunnyMapLoader.load_map_by_id(id)
	if map_data.is_empty():
		return
	world_size = BunnyMapLoader.map_world_size(map_data)
	build_regions()
	build_paths()
	build_spawns()
	build_hazards()

func clear_children() -> void:
	for child in get_children():
		child.queue_free()

func build_regions() -> void:
	for region in map_data.get("regions", []):
		var poly := Polygon2D.new()
		poly.name = "Region_" + str(region.get("id", "unknown"))
		poly.polygon = BunnyMapLoader.normalized_polygon_to_world(region.get("polygon", []), world_size)
		poly.color = Color(region.get("color_hint", "#88CC66"))
		poly.z_index = 0
		add_child(poly)

func build_paths() -> void:
	for path in map_data.get("paths", []):
		var line := Line2D.new()
		line.name = "Path_" + str(path.get("id", "unknown"))
		line.width = float(path.get("width", 0.04)) * world_size.x
		line.default_color = Color("#E7C982")
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		for p in path.get("points", []):
			line.add_point(BunnyMapLoader.normalized_point_to_world(p, world_size))
		line.z_index = 2
		add_child(line)

func build_spawns() -> void:
	for spawn in map_data.get("spawn_points", []):
		var marker := ColorRect.new()
		marker.name = "Spawn_" + str(spawn.get("id", "unknown"))
		marker.size = Vector2(28, 28)
		marker.color = Color("#FFFFFF") if spawn.get("kind") == "player" else Color("#222222")
		marker.position = BunnyMapLoader.normalized_point_to_world(spawn.get("position", [0.5, 0.5]), world_size) - marker.size * 0.5
		marker.z_index = 10
		add_child(marker)

func build_hazards() -> void:
	for hazard in map_data.get("hazards", []):
		if hazard.has("position"):
			_add_hazard_marker(hazard.get("position"), hazard.get("id", "hazard"))
		for p in hazard.get("positions", []):
			_add_hazard_marker(p, hazard.get("id", "hazard"))

func _add_hazard_marker(pos: Array, label: String) -> void:
	var marker := ColorRect.new()
	marker.name = "Hazard_" + str(label)
	marker.size = Vector2(36, 36)
	marker.color = Color("#FF4F99")
	marker.position = BunnyMapLoader.normalized_point_to_world(pos, world_size) - marker.size * 0.5
	marker.z_index = 11
	add_child(marker)
