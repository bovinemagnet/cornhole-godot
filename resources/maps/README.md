# Map Catalog

`map_catalog.json` contains 20 deterministic map concepts for future map-based gameplay.

The current prototype does not load this catalog yet. The file is structured so a future `MapDefinition` loader can build ground regions, water, roads, moving car routes, people paths, building zones, prop spawn zones, and stacked object spawn points without changing the static prop model.

Coordinate convention:

- `size` is `[width, depth]` in XZ arena units.
- Rectangles use `{ "center": [x, z], "size": [width, depth] }`.
- Paths/routes use XZ points: `[x, z]`.
- Stack spawn points use `{ "position": [x, z], "count": n, "type": "..." }`.
