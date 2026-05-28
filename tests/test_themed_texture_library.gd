extends RefCounted

const ThemedTextureLibrary = preload("res://scripts/themed_textures/themed_texture_library.gd")

const PACKS := ["candy", "bunny", "robot", "prehistoric"]


func test_texture_manifest_loads() -> String:
	var manifest := ThemedTextureLibrary.load_manifest()
	if manifest.is_empty():
		return "expected manifest to load"
	if manifest.get("packs", []).size() != 4:
		return "expected 4 packs, got %d" % manifest.get("packs", []).size()
	return ""


func test_each_pack_loads_ten_textures() -> String:
	for pack_id in PACKS:
		var defs := ThemedTextureLibrary.texture_definitions(pack_id)
		if defs.size() != 10:
			return "pack %s expected 10 textures, got %d" % [pack_id, defs.size()]
	return ""


func test_all_texture_paths_exist() -> String:
	for pack_id in PACKS:
		for entry in ThemedTextureLibrary.texture_definitions(pack_id):
			var def: Dictionary = entry
			var path: String = ThemedTextureLibrary.texture_path(def)
			if not ResourceLoader.exists(path):
				return "missing texture %s for %s" % [path, String(def.get("id", "?"))]
	return ""


func test_texture_categories_have_fallbacks() -> String:
	# Every pack must expose at least a ground/floor and a road candidate so
	# MapBuilder can always texture the dominant surfaces.
	for pack_id in PACKS:
		var ground := ThemedTextureLibrary.textures_in_category(pack_id, "ground")
		var floor := ThemedTextureLibrary.textures_in_category(pack_id, "floor")
		if ground.is_empty() and floor.is_empty():
			return "pack %s has no ground/floor texture" % pack_id
		if ThemedTextureLibrary.textures_in_category(pack_id, "road").is_empty():
			return "pack %s has no road texture" % pack_id
		if ThemedTextureLibrary.textures_in_category(pack_id, "water").is_empty():
			return "pack %s has no water texture" % pack_id
	return ""


func test_find_texture_returns_definition() -> String:
	var def := ThemedTextureLibrary.find_texture("candy", "jelly_water")
	if def.is_empty():
		return "expected to find jelly_water in candy pack"
	if String(def.get("category", "")) != "water":
		return "jelly_water should be category water"
	return ""


func test_unknown_pack_returns_empty() -> String:
	if not ThemedTextureLibrary.load_pack("nope").is_empty():
		return "expected empty for unknown pack"
	if ThemedTextureLibrary.texture_definitions("nope").size() != 0:
		return "expected no defs for unknown pack"
	return ""
