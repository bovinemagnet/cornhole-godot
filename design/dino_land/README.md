# Prehistoric World Map Pack

A pack of 10 prehistoric-world arenas for **Hole.io-inspired gameplay in Godot 4**.

## Included
- `manifest.json`
- `maps/*.json` — one normalized map definition per arena
- `images/*.png` — 10 preview card images plus `prehistoric_world_map_pack_overview.png`
- `scripts/PrehistoricMapLoader.gd` — helper to load and validate map data
- `scripts/PrehistoricMapDebugBuilder.gd` — draws debug regions/spawn points in a `Node2D`
- `schema/prehistoric_map_schema.json` — simple schema reference

## Content Theme
The pack includes maps inspired by multiple prehistoric eras and fantasy crossovers, with:
- cave men and cave women
- dinosaurs
- woolly mammoths
- woolly rhinoceroses
- sabre-tooth tigers

Some maps are single-era themed, while others intentionally combine time periods.

## Coordinate System
All region polygons, spawn points, and bounds use normalized coordinates in the range **0.0 to 1.0**. Multiply by your world size in pixels or world units.

## Suggested Use in Godot
1. Copy the pack into your project, for example `res://assets/prehistoric_maps/`.
2. Load `manifest.json` to list maps in your UI.
3. Use `PrehistoricMapLoader.gd` to load a selected map definition.
4. Feed the JSON into your procedural builder, or render the preview image as concept art.
5. Use `PrehistoricMapDebugBuilder.gd` in editor/debug mode to visualize regions and spawn points.

## Notes
- PNG files are **visual references** derived from the pack overview image.
- JSON files are intended as **gameplay/layout specs**, not exact traced collision geometry.
- Tweak object tiers, hazard counts, and AI values to fit your movement and hole growth model.
