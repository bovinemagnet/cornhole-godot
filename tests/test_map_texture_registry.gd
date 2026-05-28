extends RefCounted

const MapTextureRegistry = preload("res://scripts/themed_textures/map_texture_registry.gd")


func test_known_map_packs_resolve_to_texture_packs() -> String:
	if MapTextureRegistry.texture_pack_for_map_pack("candy_land") != "candy":
		return "candy_land should map to candy"
	if MapTextureRegistry.texture_pack_for_map_pack("dino_land") != "prehistoric":
		return "dino_land should map to prehistoric"
	return ""


func test_unmapped_packs_return_empty() -> String:
	if MapTextureRegistry.texture_pack_for_map_pack("base_maps") != "":
		return "base_maps must not map to a texture pack"
	if MapTextureRegistry.texture_pack_for_map_pack("kitty_land") != "":
		return "kitty_land must not map without a texture pack"
	return ""


func test_explicit_texture_pack_override_wins() -> String:
	var def := {"pack_id": "base_maps", "texture_pack": "candy"}
	if MapTextureRegistry.texture_pack_for_map_definition(def) != "candy":
		return "explicit texture_pack should win over pack_id mapping"
	return ""


func test_definition_without_override_uses_pack_mapping() -> String:
	var def := {"pack_id": "robot_land"}
	if MapTextureRegistry.texture_pack_for_map_definition(def) != "robot":
		return "robot_land should map to robot"
	return ""


func test_choose_texture_is_deterministic() -> String:
	for hash_key in [0, 5, 91, 100000]:
		var a := MapTextureRegistry.choose_texture("candy", "ground", hash_key)
		var b := MapTextureRegistry.choose_texture("candy", "ground", hash_key)
		if a.is_empty():
			return "expected a ground texture for candy"
		if String(a.get("id", "")) != String(b.get("id", "")):
			return "non-deterministic choice for hash %d" % hash_key
	return ""


func test_explicit_texture_id_is_honoured() -> String:
	var def := MapTextureRegistry.choose_texture("prehistoric", "hazard", 0, "tar_pit")
	if String(def.get("id", "")) != "tar_pit":
		return "expected explicit tar_pit, got %s" % String(def.get("id", "?"))
	return ""


func test_category_fallback_when_pack_lacks_category() -> String:
	# prehistoric pack has no 'floor' category; requesting it should fall back
	# to ground rather than return empty.
	var def := MapTextureRegistry.choose_texture("prehistoric", "floor", 0)
	if def.is_empty():
		return "expected a fallback texture when category missing"
	return ""


func test_material_for_region_returns_material_for_themed_pack() -> String:
	var material := MapTextureRegistry.material_for_region("candy", "water", 0)
	if material == null:
		return "expected a water material for candy"
	if not (material is ShaderMaterial):
		return "candy water should be a scrolling ShaderMaterial"
	return ""


func test_material_for_region_null_for_unmapped_pack() -> String:
	if MapTextureRegistry.material_for_region("", "ground", 0) != null:
		return "expected null material for empty pack so caller falls back to flat colour"
	return ""
