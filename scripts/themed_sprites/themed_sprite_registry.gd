extends RefCounted

# Decides which sprite to use for a gameplay object. All choices are pure
# functions of (pack_id, category, tier, hash_key) so the same object always
# resolves to the same sprite across clients — required for multiplayer
# determinism without per-object replication.

const ThemedSpriteLibrary = preload("res://scripts/themed_sprites/themed_sprite_library.gd")

# Map-pack-id → sprite-pack-id. Map pack ids in this project are the catalog
# pack_id (e.g. "candy_land"); the sprite pack ids are the manifest entries
# (e.g. "candy"). Anything not listed here resolves to "" so the caller can
# fall back to its existing primitive visuals.
const PACK_MAPPING := {
	"candy_land": "candy",
	"bunny_land": "bunny",
	"robot_land": "robot",
	"dino_land": "prehistoric",
}


static func sprite_pack_for_map_pack(map_pack_id: String) -> String:
	return String(PACK_MAPPING.get(map_pack_id, ""))


static func sprite_pack_for_map_definition(map_definition: Dictionary) -> String:
	if map_definition.is_empty():
		return ""
	return sprite_pack_for_map_pack(String(map_definition.get("pack_id", "")))


# Deterministic choice from sprites in the given category. `tier` filters
# further when > 0; pass 0 to ignore tier. `hash_key` is the per-object stable
# integer (typically object_id) used to pick within the candidate list.
static func choose_sprite(pack_id: String, category: String, tier: int, hash_key: int) -> Dictionary:
	if pack_id.is_empty():
		return {}
	var candidates := ThemedSpriteLibrary.sprites_in_category(pack_id, category)
	if tier > 0:
		var tier_filtered: Array = []
		for entry in candidates:
			var def: Dictionary = entry
			if int(def.get("tier", 0)) == tier:
				tier_filtered.append(def)
		# Only narrow to tier when there's something to pick from. Otherwise
		# fall through to the broader category list so themed packs always
		# return a sprite if any candidate exists.
		if not tier_filtered.is_empty():
			candidates = tier_filtered
	if candidates.is_empty():
		return {}
	var index: int = (hash_key % candidates.size() + candidates.size()) % candidates.size()
	return candidates[index]


static func choose_sprite_id(pack_id: String, category: String, tier: int, hash_key: int) -> String:
	var def := choose_sprite(pack_id, category, tier, hash_key)
	return String(def.get("id", "")) if not def.is_empty() else ""
