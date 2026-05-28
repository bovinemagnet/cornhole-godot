# Themed 3D Sprite Packs for Godot

Transparent pseudo-3D PNG sprites for the map packs created in this conversation:

- Candy world
- Bunny world
- Futuristic robot world
- Prehistoric world

Each pack includes:

- 16 individual transparent PNG sprites
- 1 spritesheet atlas PNG
- 1 atlas JSON file with frame, pivot, gameplay, and `Sprite3D` hints
- combined manifest and all-atlases JSON
- Godot 4 loader/spawner scripts
- schema
- preview sheet

## Godot Setup

Copy this folder into your project, for example:

```text
res://assets/themed_3d_sprites/
```

Then attach `scripts/Sprite3DSpawner.gd` to a `Node3D`, or load sprites manually:

```gdscript
var atlas = ThemedSpriteLibrary.load_atlas("res://assets/themed_3d_sprites", "candy")
var def = ThemedSpriteLibrary.get_sprite_def(atlas, "lollipop_swirl")
var sprite3d = ThemedSpriteLibrary.create_sprite3d("res://assets/themed_3d_sprites", def)
add_child(sprite3d)
```

## Notes

These are prototype-ready game sprites, not final production art. They are designed to be clear in a top-down 3D/isometric arcade game and can be used as:

- consumables
- hazards
- landmarks
- blockers
- map decorations
- NPC-style props

All PNGs use transparent backgrounds and should import cleanly into Godot 4.
