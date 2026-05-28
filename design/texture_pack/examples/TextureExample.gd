extends Node3D

@export var asset_base_path := "res://assets/themed_textures"
@export_enum("candy", "bunny", "robot", "prehistoric") var pack_id := "candy"
@export var texture_id := "sprinkle_path"

func _ready() -> void:
    var pack = ThemedTextureLibrary.load_pack(asset_base_path, pack_id)
    var tex_def = ThemedTextureLibrary.get_texture_def(pack, texture_id)
    if tex_def.is_empty():
        push_error("Texture not found")
        return
    var plane = PlaneMesh.new()
    plane.size = Vector2(20, 20)
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.mesh = plane
    mesh_instance.material_override = TextureMaterialFactory.create_material(asset_base_path, tex_def)
    mesh_instance.rotation_degrees.x = -90
    add_child(mesh_instance)
