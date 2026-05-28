extends RefCounted

# Loads the themed texture manifest + per-pack texture definitions. Textures
# are visual presentation only — gameplay region type, hazard type, movement
# rules, and spawn blocking stay in map data (per the texture-pack spec).

const ASSET_ROOT := "res://assets/themed_textures/"
const MANIFEST_PATH := "res://assets/themed_textures/manifest.json"


static func load_manifest() -> Dictionary:
	return _load_json(MANIFEST_PATH)


static func load_pack(pack_id: String) -> Dictionary:
	var manifest := load_manifest()
	if manifest.is_empty():
		return {}
	for entry in manifest.get("packs", []):
		var pack: Dictionary = entry
		if String(pack.get("id", "")) != pack_id:
			continue
		var manifest_rel := String(pack.get("manifest_path", ""))
		if manifest_rel.is_empty():
			return {}
		var pack_data := _load_json(ASSET_ROOT + manifest_rel)
		if pack_data.is_empty():
			return {}
		pack_data["pack_id"] = pack_id
		return pack_data
	return {}


static func texture_definitions(pack_id: String) -> Array:
	var pack := load_pack(pack_id)
	if pack.is_empty():
		return []
	return pack.get("textures", [])


static func find_texture(pack_id: String, texture_id: String) -> Dictionary:
	for entry in texture_definitions(pack_id):
		var def: Dictionary = entry
		if String(def.get("id", "")) == texture_id:
			return def
	return {}


static func textures_in_category(pack_id: String, category: String) -> Array:
	var matches: Array = []
	for entry in texture_definitions(pack_id):
		var def: Dictionary = entry
		if String(def.get("category", "")) == category:
			matches.append(def)
	return matches


static func texture_path(texture_def: Dictionary) -> String:
	var rel := String(texture_def.get("albedo_texture", ""))
	if rel.is_empty():
		return ""
	return ASSET_ROOT + rel


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
