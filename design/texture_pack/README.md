# Themed Texture Packs for Godot

Tileable texture/material packs for the four world themes created in this conversation:

- Candy
- Bunny
- Robot
- Prehistoric

## Included

- `manifest.json`
- per-pack manifests in `packs/<theme>/<theme>_textures.json`
- tileable `512x512` PNG textures
- preview sheets
- GDScript helpers
- example shaders
- example scene/script
- schema

## Typical Uses

- roads / paths
- water / rivers / coolant
- ground / grass / dirt / jungle floor
- floors / tiles / metal plating
- hazards like tar pits, ice, lava, and warning chevrons
- bridges / boardwalks / landing pads

## Godot Usage

Copy the folder into your Godot project, for example:

```text
res://assets/themed_textures/
```

Then:

```gdscript
var pack = ThemedTextureLibrary.load_pack("res://assets/themed_textures", "candy")
var tex_def = ThemedTextureLibrary.get_texture_def(pack, "sprinkle_path")
var material = TextureMaterialFactory.create_material("res://assets/themed_textures", tex_def)
$MeshInstance3D.material_override = material
```

## Notes

- Textures are procedurally generated prototype assets for rapid iteration.
- They are designed to tile and repeat well in top-down / 3D arcade worlds.
- Water/conveyor/emissive textures are paired with simple example shaders.
