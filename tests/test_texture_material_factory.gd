extends RefCounted

const ThemedTextureLibrary = preload("res://scripts/themed_textures/themed_texture_library.gd")
const TextureMaterialFactory = preload("res://scripts/themed_textures/texture_material_factory.gd")


func test_standard_shader_makes_standard_material() -> String:
	var def := ThemedTextureLibrary.find_texture("candy", "frosting_sprinkles")
	if def.is_empty():
		return "fixture missing: frosting_sprinkles"
	var material := TextureMaterialFactory.material_for(def)
	if not (material is StandardMaterial3D):
		return "expected StandardMaterial3D for standard shader"
	if (material as StandardMaterial3D).albedo_texture == null:
		return "standard material missing albedo texture"
	return ""


func test_scrolling_water_makes_shader_material() -> String:
	var def := ThemedTextureLibrary.find_texture("candy", "jelly_water")
	if def.is_empty():
		return "fixture missing: jelly_water"
	var material := TextureMaterialFactory.material_for(def)
	if not (material is ShaderMaterial):
		return "expected ShaderMaterial for scrolling_water"
	if (material as ShaderMaterial).get_shader_parameter("albedo_tex") == null:
		return "water shader missing albedo_tex param"
	return ""


func test_known_shaders_each_build_shader_materials() -> String:
	# robot pack exercises conveyor_scroll + emissive_pulse + scrolling_water.
	var ids := {
		"conveyor_belt": "conveyor_scroll",
		"circuit_board": "emissive_pulse",
		"coolant_water": "scrolling_water",
	}
	for id in ids:
		var def := ThemedTextureLibrary.find_texture("robot", id)
		if def.is_empty():
			return "fixture missing: %s" % id
		var material := TextureMaterialFactory.material_for(def)
		if not (material is ShaderMaterial):
			return "%s should produce a ShaderMaterial" % id
	return ""


func test_uv_scale_passed_to_standard_material() -> String:
	var def := ThemedTextureLibrary.find_texture("candy", "frosting_sprinkles")
	var material := TextureMaterialFactory.material_for(def) as StandardMaterial3D
	if material.uv1_scale.x <= 0.0 or material.uv1_scale.y <= 0.0:
		return "expected positive uv1_scale, got %s" % str(material.uv1_scale)
	return ""


func test_material_is_cached() -> String:
	var def := ThemedTextureLibrary.find_texture("bunny", "meadow_grass")
	var a := TextureMaterialFactory.material_for(def)
	var b := TextureMaterialFactory.material_for(def)
	if a != b:
		return "expected identical cached material instance"
	return ""


func test_empty_definition_returns_null() -> String:
	if TextureMaterialFactory.material_for({}) != null:
		return "expected null for empty definition"
	return ""


func test_missing_texture_returns_null() -> String:
	var bogus := {"albedo_texture": "packs/none/textures/missing.png", "material": {"shader": "standard"}}
	if TextureMaterialFactory.material_for(bogus) != null:
		return "expected null when texture path does not resolve"
	return ""
