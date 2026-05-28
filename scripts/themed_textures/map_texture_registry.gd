extends RefCounted

# Maps gameplay map-region categories to texture IDs and produces the Godot
# Material to render them. All selection is deterministic (pure function of
# pack/category/hash_key) so clients reproduce the same look from map data.

const ThemedTextureLibrary = preload("res://scripts/themed_textures/themed_texture_library.gd")
const TextureMaterialFactory = preload("res://scripts/themed_textures/texture_material_factory.gd")

const PACK_MAPPING := {
	"candy_land": "candy",
	"bunny_land": "bunny",
	"robot_land": "robot",
	"dino_land": "prehistoric",
}

# When a pack has no texture in the requested category, try these in order so
# the dominant surfaces always get a themed material.
const CATEGORY_FALLBACKS := {
	"ground": ["ground", "floor"],
	"floor": ["floor", "ground"],
	"road": ["road", "bridge", "ground"],
	"bridge": ["bridge", "road", "ground"],
	"water": ["water"],
	"hazard": ["hazard", "ground"],
	"landing_pad": ["landing_pad", "floor", "ground"],
}


static func texture_pack_for_map_pack(map_pack_id: String) -> String:
	return String(PACK_MAPPING.get(map_pack_id, ""))


static func texture_pack_for_map_definition(map_definition: Dictionary) -> String:
	if map_definition.is_empty():
		return ""
	# An explicit texture_pack on the map wins over the pack-id mapping.
	var explicit := String(map_definition.get("texture_pack", ""))
	if not explicit.is_empty():
		return explicit
	return texture_pack_for_map_pack(String(map_definition.get("pack_id", "")))


static func choose_texture(pack_id: String, category: String, hash_key: int, explicit_id: String = "") -> Dictionary:
	if pack_id.is_empty():
		return {}
	if not explicit_id.is_empty():
		var explicit_def := ThemedTextureLibrary.find_texture(pack_id, explicit_id)
		if not explicit_def.is_empty():
			return explicit_def

	var chain: Array = CATEGORY_FALLBACKS.get(category, [category])
	for fallback_category in chain:
		var candidates := ThemedTextureLibrary.textures_in_category(pack_id, fallback_category)
		if candidates.is_empty():
			continue
		var index: int = (hash_key % candidates.size() + candidates.size()) % candidates.size()
		return candidates[index]
	return {}


static func material_for_region(pack_id: String, category: String, hash_key: int, explicit_id: String = "") -> Material:
	var def := choose_texture(pack_id, category, hash_key, explicit_id)
	if def.is_empty():
		return null
	return TextureMaterialFactory.material_for(def)
