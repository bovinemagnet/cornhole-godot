extends RefCounted

const MapBuilder = preload("res://scripts/map_builder.gd")
const MapDefinition = preload("res://scripts/map_definition.gd")


func _themed_definition() -> Dictionary:
	var raw := {
		"id": "tex_test",
		"name": "Tex Test",
		"seed": 1,
		"size": [100, 100],
		"ground_regions": [{"type": "grass", "center": [0, 0], "size": [100, 100]}],
		"water_regions": [{"type": "river", "center": [0, 0], "size": [20, 20]}],
		"roads": [{"id": 0, "width": 8, "points": [[-40, 0], [40, 0]]}],
	}
	return MapDefinition.from_catalog_map("candy_land", "Candy", raw)


func test_themed_map_uses_textured_ground_and_shader_water() -> String:
	var root := Node3D.new()
	MapBuilder.build_map(root, _themed_definition())

	var ground_textured := false
	var water_shader := false
	var road_present := false
	for child in root.get_children():
		if not (child is MeshInstance3D):
			continue
		var mat: Material = (child as MeshInstance3D).material_override
		if String(child.name).begins_with("Region_grass") and mat is StandardMaterial3D \
				and (mat as StandardMaterial3D).albedo_texture != null:
			ground_textured = true
		if String(child.name).begins_with("Region_river") and mat is ShaderMaterial:
			water_shader = true
		if String(child.name).begins_with("RoadSegment"):
			road_present = true
	root.free()

	if not ground_textured:
		return "candy ground region should use a textured StandardMaterial3D"
	if not water_shader:
		return "candy water region should use a scrolling ShaderMaterial"
	if not road_present:
		return "road segment should be built"
	return ""


func test_unthemed_map_falls_back_to_flat_materials() -> String:
	var raw := {
		"id": "flat_test",
		"name": "Flat Test",
		"seed": 1,
		"size": [100, 100],
		"ground_regions": [{"type": "grass", "center": [0, 0], "size": [100, 100]}],
	}
	var def := MapDefinition.from_catalog_map("base_maps", "Base", raw)
	var root := Node3D.new()
	MapBuilder.build_map(root, def)

	var has_flat_ground := false
	for child in root.get_children():
		if not (child is MeshInstance3D):
			continue
		var mat: Material = (child as MeshInstance3D).material_override
		if String(child.name).begins_with("Region_grass"):
			# Base maps have no texture pack — must stay a flat StandardMaterial3D
			# with no albedo texture.
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture == null:
				has_flat_ground = true
			else:
				root.free()
				return "base-map ground should use a flat material, got %s" % str(mat)
	root.free()

	if not has_flat_ground:
		return "expected a flat ground region for base map"
	return ""
