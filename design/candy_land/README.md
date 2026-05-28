# Candy Collapse Arenas - Godot JSON Map Pack

This pack contains ten candy-themed, Hole.io-inspired arena specifications for a Godot map generator.

## Contents

- `maps/manifest.json` - list of all maps and their JSON/PNG references.
- `maps/json/map_XX_*.json` - one generator specification per map.
- `maps/images/map_XX_*.png` - reference concept PNGs generated for the maps.
- `maps/candy_map_schema.json` - lightweight JSON schema.
- `godot/CandyMapLoader.gd` - small Godot 4 helper for loading the JSON and converting normalized coordinates into world pixels.

## Important note

The JSON files are generator/layout specifications, not pixel-perfect traces of the PNGs. Coordinates are normalized top-left values from `0.0` to `1.0`, so your Godot generator can scale them to any arena size. The included `world_size_px` is `2048 x 2048` by default.

## Suggested Godot folder layout

Copy the `maps` folder into:

```text
res://maps/candy/
```

Copy the loader into:

```text
res://scripts/CandyMapLoader.gd
```

Then load a map:

```gdscript
var map_data := CandyMapLoader.load_map("res://maps/candy/json/map_01_lollipop_lawn.json")
```

## Implementation notes

- Treat `regions` as semantic zones for spawning, scoring, and visual biome selection.
- Treat `pathways` as walkable lane definitions. Use their `width` and `points` to create Path2D/Line2D, NavigationRegion2D, or custom collision-clear zones.
- Treat `blockers` as collision-generation instructions. Some are concrete, such as boundaries; others are procedural clusters, such as gumdrops or shop blocks.
- Treat `hazards` as optional gameplay rules. You can skip them at first and add them later.
- `edible_tiers` are shared across all maps so growth rules remain consistent.

My recommendation: implement maps 1-3 first with static props only, then add bridges, liquid barriers, moving props, conveyors, and timed hazards from maps 5-10 once the core swallowing loop feels good.
