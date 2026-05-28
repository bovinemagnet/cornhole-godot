extends RefCounted
class_name ThemedSpriteLibrary

## Loads the themed sprite atlas JSON files and creates Sprite3D nodes.
## Copy this pack to something like:
##   res://assets/themed_3d_sprites/

static func load_json(path: String) -> Dictionary:
    var text := FileAccess.get_file_as_string(path)
    if text.is_empty():
        push_error("Could not read JSON: %s" % path)
        return {}
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Invalid JSON dictionary: %s" % path)
        return {}
    return parsed

static func load_manifest(base_path: String) -> Dictionary:
    return load_json(base_path.path_join("manifest.json"))

static func load_atlas(base_path: String, pack_id: String) -> Dictionary:
    var path := base_path.path_join("sprites/%s/atlas/%s_atlas.json" % [pack_id, pack_id])
    return load_json(path)

static func get_sprite_def(atlas_data: Dictionary, sprite_id: String) -> Dictionary:
    for s in atlas_data.get("sprites", []):
        if s.get("id", "") == sprite_id:
            return s
    return {}

static func create_sprite3d(base_path: String, sprite_def: Dictionary) -> Sprite3D:
    var node := Sprite3D.new()
    var texture_path := base_path.path_join(sprite_def.get("texture", ""))
    node.texture = load(texture_path)
    node.centered = true
    node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    node.no_depth_test = false
    node.shaded = false
    node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
    node.pixel_size = sprite_def.get("sprite3d", {}).get("pixel_size", 0.01)
    node.name = sprite_def.get("id", "themed_sprite")
    return node

static func create_collision_shape(sprite_def: Dictionary) -> CollisionShape3D:
    var shape := SphereShape3D.new()
    shape.radius = float(sprite_def.get("gameplay", {}).get("collision_radius_world", 0.3))
    var collision := CollisionShape3D.new()
    collision.shape = shape
    collision.name = "%s_collision" % sprite_def.get("id", "sprite")
    return collision
