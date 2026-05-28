extends RefCounted

# Builds the visual map (floor, ground regions, water, roads) from a
# normalised MapDefinition into the provided map_root Node3D. Each call to
# `build_map` clears the previous contents so reset_match can rebuild
# cheaply.
#
# Gameplay bounds (player/bot movement clamps) remain owned by main.gd
# because they live alongside the perimeter walls and prop_grid. Visual
# map extents from the MapDefinition can differ; this is intentional.

const BASE_FLOOR_Y := -0.03
const GROUND_REGION_Y := 0.001
const WATER_REGION_Y := 0.012
const ROAD_Y := 0.005
const BUILDING_ID_BASE := 20000


static func build_map(map_root: Node3D, map_definition: Dictionary) -> void:
	if not map_root:
		return
	for child in map_root.get_children():
		child.queue_free()
	if map_definition.is_empty():
		return

	_build_base_floor(map_root, map_definition)
	_build_regions(map_root, map_definition.get("ground_regions", []), GROUND_REGION_Y, false)
	_build_regions(map_root, map_definition.get("water_regions", []), WATER_REGION_Y, true)
	_build_roads(map_root, map_definition.get("roads", []))
	_build_buildings(map_root, map_definition.get("building_zones", []))


# Height per building type — visual only for the MVP. Authoritative
# gameplay metadata (area, required_radius, score) is intentionally absent
# until consumption is wired in a later pass.
static func _building_height_for_type(type_lower: String) -> float:
	if type_lower.contains("tower") or type_lower.contains("citadel"):
		return 12.0
	if type_lower.contains("office") or type_lower.contains("apartments") or type_lower.contains("factory"):
		return 8.0
	if type_lower.contains("warehouse") or type_lower.contains("shop") or type_lower.contains("market"):
		return 5.5
	if type_lower.contains("house") or type_lower.contains("cottage") or type_lower.contains("burrow"):
		return 4.0
	if type_lower.contains("kiosk") or type_lower.contains("stall") or type_lower.contains("booth"):
		return 2.5
	return 4.5


static func _building_color_for_type(type_lower: String) -> Color:
	if type_lower.contains("tower") or type_lower.contains("office"):
		return Color(0.42, 0.46, 0.54)
	if type_lower.contains("warehouse") or type_lower.contains("factory") or type_lower.contains("garage"):
		return Color(0.62, 0.55, 0.42)
	if type_lower.contains("shop") or type_lower.contains("market") or type_lower.contains("kiosk"):
		return Color(0.72, 0.48, 0.36)
	if type_lower.contains("house") or type_lower.contains("apartments"):
		return Color(0.78, 0.66, 0.52)
	if type_lower.contains("candy") or type_lower.contains("frosting"):
		return Color(0.95, 0.66, 0.78)
	if type_lower.contains("robot") or type_lower.contains("server") or type_lower.contains("conveyor"):
		return Color(0.36, 0.50, 0.66)
	return Color(0.66, 0.62, 0.56)


static func _build_buildings(map_root: Node3D, zones: Array) -> void:
	for index in range(zones.size()):
		var entry: Dictionary = zones[index]
		var centre: Vector2 = entry["center"]
		var size: Vector2 = entry["size"]
		if size.x <= 0.0 or size.y <= 0.0:
			continue
		var type := String(entry.get("type", "")).to_lower()
		var height := _building_height_for_type(type)
		var building := MeshInstance3D.new()
		building.name = "Building_%d" % (BUILDING_ID_BASE + index)
		var box := BoxMesh.new()
		box.size = Vector3(size.x, height, size.y)
		building.mesh = box
		building.material_override = _make_material(_building_color_for_type(type))
		building.position = Vector3(centre.x, height * 0.5, centre.y)
		map_root.add_child(building)


static func resolve_region_color(region_type: String) -> Color:
	# Theme-aware colour lookup. Substring matches keep the table small as
	# new packs add type names; falls through to a neutral grass green.
	var t := region_type.to_lower()
	if t.contains("water") or t.contains("pond") or t.contains("river") \
			or t.contains("canal") or t.contains("harbor") or t.contains("pool") \
			or t.contains("fountain") or t.contains("milk") or t.contains("lake"):
		return Color(0.18, 0.42, 0.78, 0.65)
	if t.contains("lava") or t.contains("hazard") or t.contains("tar"):
		return Color(0.78, 0.22, 0.10)
	if t.contains("snow") or t.contains("ice"):
		return Color(0.86, 0.92, 0.98)
	if t.contains("sand") or t.contains("dune") or t.contains("desert") or t.contains("beach"):
		return Color(0.92, 0.84, 0.55)
	if t.contains("plaza") or t.contains("pavement") or t.contains("dock") \
			or t.contains("conveyor") or t.contains("metal") or t.contains("robot") \
			or t.contains("asphalt") or t.contains("garage") or t.contains("factory"):
		return Color(0.52, 0.55, 0.60)
	if t.contains("candy") or t.contains("sugar") or t.contains("frosting") \
			or t.contains("marshmallow") or t.contains("lollipop"):
		return Color(0.95, 0.66, 0.78)
	if t.contains("paw") or t.contains("yarn") or t.contains("kitten") or t.contains("cat"):
		return Color(0.86, 0.76, 0.94)
	if t.contains("bunny") or t.contains("burrow") or t.contains("carrot"):
		return Color(0.96, 0.92, 0.68)
	if t.contains("dino") or t.contains("jurassic") or t.contains("fossil") or t.contains("prehistoric"):
		return Color(0.36, 0.52, 0.28)
	if t.contains("park") or t.contains("meadow") or t.contains("yard") or t.contains("grass") or t.contains("lawn"):
		return Color(0.27, 0.58, 0.32)
	return Color(0.32, 0.55, 0.34)


static func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.85
	return material


static func _build_base_floor(map_root: Node3D, map_definition: Dictionary) -> void:
	var size: Vector2 = map_definition["size"]
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "BaseFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x * 1.05, size.y * 1.05)
	floor_mesh.mesh = plane
	floor_mesh.material_override = _make_material(Color(0.21, 0.46, 0.27))
	floor_mesh.position.y = BASE_FLOOR_Y
	map_root.add_child(floor_mesh)


static func _build_regions(map_root: Node3D, regions: Array, y_height: float, transparent: bool) -> void:
	for region in regions:
		var entry: Dictionary = region
		var center: Vector2 = entry["center"]
		var size: Vector2 = entry["size"]
		if size.x <= 0.0 or size.y <= 0.0:
			continue

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Region_%s" % String(entry.get("type", "untyped"))
		var plane := PlaneMesh.new()
		plane.size = size
		mesh_instance.mesh = plane
		var color := resolve_region_color(String(entry.get("type", "")))
		if transparent and color.a >= 1.0:
			color.a = 0.65
		mesh_instance.material_override = _make_material(color)
		mesh_instance.position = Vector3(center.x, y_height, center.y)
		map_root.add_child(mesh_instance)


static func _build_roads(map_root: Node3D, roads: Array) -> void:
	for road in roads:
		var entry: Dictionary = road
		var points: PackedVector2Array = entry["points"]
		var width: float = float(entry.get("width", 8.0))
		var road_material := _make_material(Color(0.16, 0.16, 0.18))

		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var delta := b - a
			var length := delta.length()
			if length <= 0.0:
				continue
			var segment := MeshInstance3D.new()
			segment.name = "RoadSegment_%d_%d" % [int(entry.get("id", 0)), i]
			var plane := PlaneMesh.new()
			plane.size = Vector2(length, width)
			segment.mesh = plane
			segment.material_override = road_material
			var midpoint := (a + b) * 0.5
			segment.position = Vector3(midpoint.x, ROAD_Y, midpoint.y)
			# atan2(z, x) on the XZ delta gives a Y rotation that aligns the
			# plane's local +X with the segment direction. Negate so the road
			# turns clockwise when delta sweeps positive Z.
			segment.rotation.y = -atan2(delta.y, delta.x)
			map_root.add_child(segment)
