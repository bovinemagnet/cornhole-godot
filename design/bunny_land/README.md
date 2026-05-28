# Bunny Map Pack for Godot

Ten bunny-inspired, brightly coloured maps for a Hole.io-style game. The maps progress from easy tutorial arenas to a dense final citadel.

## Contents

```text
BunnyMapPack/
  manifest.json
  maps/
    map_01_bunny_meadow.json
    ...
    map_10_great_bunny_citadel.json
  images/
    map_01_bunny_meadow.png
    ...
    map_10_great_bunny_citadel.png
    bunny_map_pack_overview.png
  scripts/
    BunnyMapLoader.gd
    BunnyMapDebugBuilder.gd
  schema/
    bunny_map_schema.json
  README.md
  LICENSE.txt
```

## How to use in Godot 4

1. Unzip this package.
2. Copy the `BunnyMapPack` folder into your Godot project root so it appears at `res://BunnyMapPack`.
3. Add `scripts/BunnyMapLoader.gd` and `scripts/BunnyMapDebugBuilder.gd` to your project.
4. Create a `Node2D` scene, attach `BunnyMapDebugBuilder.gd`, and set `map_id` to one of the map IDs.
5. Replace the debug drawing with your real terrain, object, hazard, bot, and collision generation.

## Coordinate system

All coordinates are normalized from `0.0` to `1.0`, using a top-left origin. This makes each map scalable:

```gdscript
var world_size := BunnyMapLoader.map_world_size(map_data)
var world_position := BunnyMapLoader.normalized_point_to_world([0.5, 0.5], world_size)
```

## Map IDs

1. `map_01_bunny_meadow`
2. `map_02_carrot_village`
3. `map_03_bunny_burrow_park`
4. `map_04_hopscotch_hills`
5. `map_05_easter_garden`
6. `map_06_bunny_bakery_town`
7. `map_07_whisker_wonderland`
8. `map_08_moonlit_burrows`
9. `map_09_bunny_kingdom`
10. `map_10_great_bunny_citadel`

## Notes

The PNGs are reference/blockout previews. The JSON files are the source of truth for gameplay layout, regions, spawn rules, hazards, blockers, and difficulty tuning.
