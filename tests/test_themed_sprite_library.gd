extends RefCounted

const ThemedSpriteLibrary = preload("res://scripts/themed_sprites/themed_sprite_library.gd")


func test_manifest_loads() -> String:
	var manifest := ThemedSpriteLibrary.load_manifest()
	if manifest.is_empty():
		return "expected manifest to load"
	if not manifest.has("packs"):
		return "manifest missing 'packs' array"
	if manifest["packs"].size() == 0:
		return "manifest has no packs"
	return ""


func test_each_pack_loads_with_sprites() -> String:
	for pack_id in ["bunny", "candy", "robot", "prehistoric"]:
		var pack := ThemedSpriteLibrary.load_pack(pack_id)
		if pack.is_empty():
			return "pack %s failed to load" % pack_id
		var sprites: Array = pack.get("sprites", [])
		if sprites.size() != 16:
			return "pack %s expected 16 sprites, got %d" % [pack_id, sprites.size()]
	return ""


func test_every_sprite_texture_exists() -> String:
	for pack_id in ["bunny", "candy", "robot", "prehistoric"]:
		for sprite in ThemedSpriteLibrary.sprite_definitions(pack_id):
			var def: Dictionary = sprite
			var path: String = ThemedSpriteLibrary.texture_path(def)
			if not ResourceLoader.exists(path):
				return "missing texture %s for sprite %s" % [path, String(def.get("id", "?"))]
	return ""


func test_find_sprite_returns_definition() -> String:
	var def := ThemedSpriteLibrary.find_sprite("bunny", "white_bunny")
	if def.is_empty():
		return "expected to find white_bunny in bunny pack"
	if String(def.get("id", "")) != "white_bunny":
		return "wrong sprite returned"
	return ""


func test_find_sprite_missing_returns_empty() -> String:
	var def := ThemedSpriteLibrary.find_sprite("bunny", "does_not_exist")
	if not def.is_empty():
		return "expected empty for missing sprite"
	return ""


func test_sprites_in_category_filters() -> String:
	var characters := ThemedSpriteLibrary.sprites_in_category("bunny", "character")
	if characters.size() == 0:
		return "expected at least one 'character' sprite in bunny pack"
	for entry in characters:
		var def: Dictionary = entry
		if String(def.get("category", "")) != "character":
			return "non-character leaked: %s" % String(def.get("id", "?"))
	return ""


func test_unknown_pack_returns_empty() -> String:
	var pack := ThemedSpriteLibrary.load_pack("does_not_exist")
	if not pack.is_empty():
		return "expected empty for unknown pack"
	return ""
