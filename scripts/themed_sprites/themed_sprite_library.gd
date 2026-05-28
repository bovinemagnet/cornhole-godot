extends RefCounted

# Loads the themed sprite manifest + per-pack atlas JSON and exposes sprite
# metadata. Visual creation (Sprite3D nodes) lives here so the rest of the
# code can stay free of pixel_size/billboard plumbing. Gameplay metadata is
# NEVER read from sprite definitions — sprites are visual presentation only,
# per the spec ("Sprite metadata can suggest visuals, but should not silently
# change score or required radius").

const ASSET_ROOT := "res://assets/themed_3d_sprites/"
const MANIFEST_PATH := "res://assets/themed_3d_sprites/manifest.json"


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
		var atlas_json_rel := String(pack.get("atlas_json", ""))
		if atlas_json_rel.is_empty():
			return {}
		var atlas := _load_json(ASSET_ROOT + atlas_json_rel)
		if atlas.is_empty():
			return {}
		atlas["pack_id"] = pack_id
		return atlas
	return {}


static func sprite_definitions(pack_id: String) -> Array:
	var pack := load_pack(pack_id)
	if pack.is_empty():
		return []
	var sprites: Array = pack.get("sprites", [])
	return sprites


static func find_sprite(pack_id: String, sprite_id: String) -> Dictionary:
	for entry in sprite_definitions(pack_id):
		var sprite: Dictionary = entry
		if String(sprite.get("id", "")) == sprite_id:
			return sprite
	return {}


static func sprites_in_category(pack_id: String, category: String) -> Array:
	var matches: Array = []
	for entry in sprite_definitions(pack_id):
		var sprite: Dictionary = entry
		if String(sprite.get("category", "")) == category:
			matches.append(sprite)
	return matches


static func texture_path(sprite_def: Dictionary) -> String:
	var rel := String(sprite_def.get("texture", ""))
	if rel.is_empty():
		return ""
	return ASSET_ROOT + rel


# Builds a configured Sprite3D for the given sprite. Returns null when the
# texture cannot be loaded (so callers can fall back to primitives).
static func create_sprite3d(sprite_def: Dictionary) -> Sprite3D:
	if sprite_def.is_empty():
		return null
	var path := texture_path(sprite_def)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if not texture:
		return null

	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.no_depth_test = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED

	var sprite3d_block: Dictionary = sprite_def.get("sprite3d", {})
	sprite.pixel_size = float(sprite3d_block.get("pixel_size", 0.01))

	# Offset stays at (0, 0): the texture is centred on the node origin. The
	# caller chooses how to position the node (e.g. y = visual_height * 0.5
	# to make the sprite stand on the ground). Atlas pivot data is left on
	# the definition for callers that want pixel-perfect anchoring.
	return sprite


# World-space half-height of the sprite (centre to edge). Useful for placing
# a sprite so its bottom edge sits on y=0 — set node.y to this value.
static func sprite_half_height_world(sprite_def: Dictionary) -> float:
	if sprite_def.is_empty():
		return 0.0
	var sprite3d_block: Dictionary = sprite_def.get("sprite3d", {})
	var pixel_size := float(sprite3d_block.get("pixel_size", 0.01))
	var frame_h := 256.0
	if sprite_def.has("frame"):
		frame_h = float(Dictionary(sprite_def["frame"]).get("h", 256.0))
	return frame_h * pixel_size * 0.5


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
