extends RefCounted

const ThemedSpriteRegistry = preload("res://scripts/themed_sprites/themed_sprite_registry.gd")


func test_known_map_packs_resolve_to_sprite_packs() -> String:
	if ThemedSpriteRegistry.sprite_pack_for_map_pack("candy_land") != "candy":
		return "candy_land should map to candy"
	if ThemedSpriteRegistry.sprite_pack_for_map_pack("bunny_land") != "bunny":
		return "bunny_land should map to bunny"
	if ThemedSpriteRegistry.sprite_pack_for_map_pack("robot_land") != "robot":
		return "robot_land should map to robot"
	if ThemedSpriteRegistry.sprite_pack_for_map_pack("dino_land") != "prehistoric":
		return "dino_land should map to prehistoric"
	return ""


func test_unmapped_packs_return_empty() -> String:
	if ThemedSpriteRegistry.sprite_pack_for_map_pack("base_maps") != "":
		return "base_maps must not map to a sprite pack"
	if ThemedSpriteRegistry.sprite_pack_for_map_pack("kitty_land") != "":
		return "kitty_land must not map without a kitty sprite pack"
	if ThemedSpriteRegistry.sprite_pack_for_map_pack("") != "":
		return "empty should map to empty"
	return ""


func test_choose_sprite_returns_stable_choice_for_same_inputs() -> String:
	for hash_key in [0, 7, 99, 100000]:
		var a := ThemedSpriteRegistry.choose_sprite("bunny", "character", 0, hash_key)
		var b := ThemedSpriteRegistry.choose_sprite("bunny", "character", 0, hash_key)
		if a.is_empty():
			return "expected non-empty character sprite for hash %d" % hash_key
		if String(a.get("id", "")) != String(b.get("id", "")):
			return "non-deterministic choice for hash %d" % hash_key
	return ""


func test_choose_sprite_differs_for_different_hash_keys_when_multiple_candidates() -> String:
	var ids: Dictionary = {}
	for hash_key in range(20):
		var def := ThemedSpriteRegistry.choose_sprite("candy", "pickup", 0, hash_key)
		if def.is_empty():
			continue
		ids[String(def.get("id", ""))] = true
	if ids.size() < 2:
		return "expected multiple distinct ids across 20 hash keys, got %d" % ids.size()
	return ""


func test_choose_sprite_returns_empty_for_unknown_pack() -> String:
	var def := ThemedSpriteRegistry.choose_sprite("does_not_exist", "character", 0, 1)
	if not def.is_empty():
		return "expected empty for unknown pack"
	return ""


func test_choose_sprite_returns_empty_for_unknown_category() -> String:
	var def := ThemedSpriteRegistry.choose_sprite("bunny", "no_such_category", 0, 1)
	if not def.is_empty():
		return "expected empty for unknown category"
	return ""


func test_choose_sprite_falls_back_to_category_when_tier_has_no_match() -> String:
	# Asking for an impossible tier (99) within a category that does have
	# sprites should still return one — the spec wants graceful fallback.
	var def := ThemedSpriteRegistry.choose_sprite("bunny", "character", 99, 0)
	if def.is_empty():
		return "expected fallback to category when tier matches none"
	return ""


func test_negative_hash_key_does_not_throw() -> String:
	var def := ThemedSpriteRegistry.choose_sprite("candy", "pickup", 0, -123456)
	if def.is_empty():
		return "expected stable result even for negative hash"
	return ""
