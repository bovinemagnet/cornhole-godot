extends RefCounted

# Builds the visual map (floor, ground regions, water, roads) from a
# normalised MapDefinition into the provided map_root Node3D. Each call to
# `build_map` clears the previous contents so reset_match can rebuild
# cheaply.
#
# Gameplay bounds (player/bot movement clamps) remain owned by main.gd
# because they live alongside the perimeter walls and prop_grid. Visual
# map extents from the MapDefinition can differ; this is intentional.

const ThemedSpriteLibrary = preload("res://scripts/themed_sprites/themed_sprite_library.gd")
const ThemedSpriteRegistry = preload("res://scripts/themed_sprites/themed_sprite_registry.gd")
const MapTextureRegistry = preload("res://scripts/themed_textures/map_texture_registry.gd")

# The base floor sits well below everything else so it can never z-fight the
# full-map ground regions that cover it — it only shows at the map-edge
# border. Ground/road/water layers are then spread far enough apart for the
# camera to resolve at match-zoom distance, with a per-index micro bump so
# coplanar regions (e.g. plaza inside grass, crossing roads) don't fight.
const BASE_FLOOR_Y := -0.50
const GROUND_REGION_Y := 0.000
const GROUND_REGION_Y_STEP := 0.004
const WATER_REGION_Y := 0.100
const WATER_REGION_Y_STEP := 0.002
const ROAD_Y := 0.050
const ROAD_Y_STEP := 0.001
const BUILDING_ID_BASE := 20000


static func build_map(map_root: Node3D, map_definition: Dictionary) -> void:
	if not map_root:
		return
	for child in map_root.get_children():
		child.queue_free()
	if map_definition.is_empty():
		return

	var texture_pack: String = MapTextureRegistry.texture_pack_for_map_definition(map_definition)
	var map_id_hash: int = String(map_definition.get("id", "")).hash()

	_build_base_floor(map_root, map_definition, texture_pack, map_id_hash)
	_build_regions(map_root, map_definition.get("ground_regions", []), GROUND_REGION_Y, GROUND_REGION_Y_STEP, false, texture_pack, "ground", map_id_hash)
	_build_regions(map_root, map_definition.get("water_regions", []), WATER_REGION_Y, WATER_REGION_Y_STEP, true, texture_pack, "water", map_id_hash)
	var road_color := resolve_road_color(ThemedSpriteRegistry.sprite_pack_for_map_definition(map_definition))
	_build_roads(map_root, map_definition.get("roads", []), road_color, texture_pack, map_id_hash)
	# Buildings are spawned by main.gd so the visual and the consumable
	# gameplay state stay co-located. See `main.gd._spawn_buildings`.


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


static func building_height_for_type(type_lower: String) -> float:
	return _building_height_for_type(type_lower)


static func building_color_for_type(type_lower: String) -> Color:
	return _building_color_for_type(type_lower)


# Prefers `landmark` sprites because the catalog reserves those for the most
# visually load-bearing fixtures (towers, castles, cave huts). Falls back to
# `building` then `large_prop` so every themed map still gets sprite-driven
# fixtures even when no landmark candidate exists.
static func try_create_building_sprite(sprite_pack: String, hash_key: int, fallback_height: float) -> Node3D:
	if sprite_pack.is_empty():
		return null
	var def: Dictionary = ThemedSpriteRegistry.choose_sprite(sprite_pack, "landmark", 0, hash_key)
	if def.is_empty():
		def = ThemedSpriteRegistry.choose_sprite(sprite_pack, "building", 0, hash_key)
	if def.is_empty():
		def = ThemedSpriteRegistry.choose_sprite(sprite_pack, "large_prop", 0, hash_key)
	if def.is_empty():
		return null
	var sprite := ThemedSpriteLibrary.create_sprite3d(def)
	if not sprite:
		return null

	var target_height: float = max(fallback_height, 4.0)
	var natural_height: float = ThemedSpriteLibrary.sprite_half_height_world(def) * 2.0
	var scale: float = target_height / max(natural_height, 0.01)
	sprite.scale = Vector3(scale, scale, scale)

	var root := Node3D.new()
	root.position.y = natural_height * scale * 0.5
	root.add_child(sprite)
	return root


static func make_building_box(size: Vector2, height: float, type_lower: String) -> Node3D:
	var building := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, height, size.y)
	building.mesh = box
	building.material_override = _make_material(_building_color_for_type(type_lower))
	building.position.y = height * 0.5
	var root := Node3D.new()
	root.add_child(building)
	return root


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
			or t.contains("asphalt") or t.contains("garage") or t.contains("factory") \
			or t.contains("court") or t.contains("quad") or t.contains("bay") \
			or t.contains("scrap") or t.contains("foundry"):
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


static func _build_base_floor(map_root: Node3D, map_definition: Dictionary, texture_pack: String, map_id_hash: int) -> void:
	var size: Vector2 = map_definition["size"]
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "BaseFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x * 1.05, size.y * 1.05)
	floor_mesh.mesh = plane
	var textured: Material = MapTextureRegistry.material_for_region(texture_pack, "ground", map_id_hash)
	floor_mesh.material_override = textured if textured else _make_material(Color(0.21, 0.46, 0.27))
	floor_mesh.position.y = BASE_FLOOR_Y
	map_root.add_child(floor_mesh)


# Built/paved surfaces want the pack's `floor` textures; open terrain wants
# `ground`. The default_category fixes water regions to water regardless.
static func _surface_category_for(region_type: String, default_category: String) -> String:
	if default_category != "ground":
		return default_category
	var t := region_type.to_lower()
	if t.contains("plaza") or t.contains("pavement") or t.contains("floor") \
			or t.contains("court") or t.contains("tile") or t.contains("dock") \
			or t.contains("quad") or t.contains("bay") or t.contains("pad") \
			or t.contains("boardwalk"):
		return "floor"
	return "ground"


static func _build_regions(map_root: Node3D, regions: Array, y_base: float, y_step: float, transparent: bool, texture_pack: String, default_category: String, map_id_hash: int) -> void:
	# Later regions in the array render slightly higher than earlier ones, so
	# overlapping zones (e.g. a plaza laid on top of grass) never z-fight.
	# The map author already orders these from "background" → "foreground".
	for i in range(regions.size()):
		var entry: Dictionary = regions[i]
		var center: Vector2 = entry["center"]
		var size: Vector2 = entry["size"]
		if size.x <= 0.0 or size.y <= 0.0:
			continue

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Region_%s" % String(entry.get("type", "untyped"))
		var plane := PlaneMesh.new()
		plane.size = size
		mesh_instance.mesh = plane

		# Themed texture preferred; flat colour is the fallback for base/kitty
		# maps or when a pack lacks the category entirely.
		var category := String(entry.get("surface_category", ""))
		if category.is_empty():
			category = _surface_category_for(String(entry.get("type", "")), default_category)
		var textured: Material = MapTextureRegistry.material_for_region(
			texture_pack, category, map_id_hash + i, String(entry.get("texture_id", ""))
		)
		if textured:
			mesh_instance.material_override = textured
		else:
			var color := resolve_region_color(String(entry.get("type", "")))
			if transparent and color.a >= 1.0:
				color.a = 0.65
			mesh_instance.material_override = _make_material(color)
		mesh_instance.position = Vector3(center.x, y_base + i * y_step, center.y)
		map_root.add_child(mesh_instance)


# Road colour follows the map's sprite pack so themed maps don't all read as
# grey asphalt. Base/kitty maps (no sprite pack) keep neutral asphalt.
static func resolve_road_color(sprite_pack: String) -> Color:
	match sprite_pack:
		"candy":
			return Color(0.88, 0.74, 0.80)  # pale conveyor cream-pink
		"bunny":
			return Color(0.64, 0.52, 0.36)  # garden dirt path
		"robot":
			return Color(0.34, 0.40, 0.48)  # brushed metal lane
		"prehistoric":
			return Color(0.46, 0.38, 0.28)  # packed earth trail
		_:
			return Color(0.16, 0.16, 0.18)  # neutral asphalt


static func _build_roads(map_root: Node3D, roads: Array, road_color: Color, texture_pack: String, map_id_hash: int) -> void:
	# Each road gets its own Y so crossing roads (very common in
	# downtown_grid) don't share a plane and z-fight.
	for road_index in range(roads.size()):
		var entry: Dictionary = roads[road_index]
		var points: PackedVector2Array = entry["points"]
		var width: float = float(entry.get("width", 8.0))
		var textured: Material = MapTextureRegistry.material_for_region(texture_pack, "road", map_id_hash + road_index)
		var road_material: Material = textured if textured else _make_material(road_color)
		var road_y := ROAD_Y + road_index * ROAD_Y_STEP

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
			segment.position = Vector3(midpoint.x, road_y, midpoint.y)
			# atan2(z, x) on the XZ delta gives a Y rotation that aligns the
			# plane's local +X with the segment direction. Negate so the road
			# turns clockwise when delta sweeps positive Z.
			segment.rotation.y = -atan2(delta.y, delta.x)
			map_root.add_child(segment)
