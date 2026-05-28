extends Node3D
class_name Sprite3DSpawner

@export var asset_base_path := "res://assets/themed_3d_sprites"
@export_enum("candy", "bunny", "robot", "prehistoric") var pack_id := "candy"
@export var sprite_id := "lollipop_swirl"
@export var add_collision := true

func _ready() -> void:
    spawn_sprite(pack_id, sprite_id, Vector3.ZERO)

func spawn_sprite(pack: String, id: String, pos: Vector3) -> Node3D:
    var atlas := ThemedSpriteLibrary.load_atlas(asset_base_path, pack)
    var def := ThemedSpriteLibrary.get_sprite_def(atlas, id)
    if def.is_empty():
        push_error("Sprite not found: %s/%s" % [pack, id])
        return null

    var root := Node3D.new()
    root.name = "%s_%s" % [pack, id]
    root.position = pos

    var sprite := ThemedSpriteLibrary.create_sprite3d(asset_base_path, def)
    root.add_child(sprite)

    if add_collision:
        var body := StaticBody3D.new()
        body.name = "%s_body" % id
        body.add_child(ThemedSpriteLibrary.create_collision_shape(def))
        root.add_child(body)

    add_child(root)
    return root
