# Map And Stacked Object Plan

Goal: evolve the prototype from a flat arena with scattered props into a map-based world with ground regions, water, roads, moving cars, people, buildings, and multi-item stacked objects that can fall and interact with the hole. The plan keeps the future multiplayer model intact: deterministic map generation, server-authoritative gameplay decisions, and local-only visual physics where possible.

## Design Principles

- Keep gameplay metadata deterministic and server-simulatable.
- Treat full rigidbody physics as visual polish, not authoritative state.
- Separate map layout, static props, moving actors, people, buildings, and stacked objects into distinct systems.
- Use stable IDs for every consumable gameplay item, including stack members.
- Let the server eventually decide consumption, stack collapse triggers, scores, deaths, and match phase.
- Let clients locally animate falling, tumbling, splashes, and debris after authoritative events.

## Target World Model

Replace the single flat arena concept with a deterministic map definition:

```text
MapDefinition {
    id: String
    map_seed: int
    size: Vector2
    ground_regions: Region[]
    roads: RoadPath[]
    water_regions: Region[]
    building_zones: Region[]
    prop_spawn_zones: Region[]
    people_paths: Path[]
    moving_car_routes: Route[]
    stack_spawn_points: StackSpawnPoint[]
}
```

The current `ARENA_HALF_SIZE` can remain for the first version, but map boundaries should come from `MapDefinition.size` once the map system exists.

## Phase 1: Map-Based Ground

1. Add a map data script or resource.
   - Start with one built-in map definition in GDScript.
   - Later, convert to `.tres` resources or JSON if authoring becomes cumbersome.

2. Split ground into visual regions.
   - Grass/park areas.
   - Road strips.
   - Pavement/plaza areas.
   - Water regions.
   - Building footprints.

3. Keep collision simple.
   - The hole still moves on the XZ plane.
   - Ground type affects movement or visuals only after the base map is working.
   - Walls or map bounds still clamp movement.

4. Add map sampling helpers.

```text
get_ground_type_at(position) -> GroundType
is_in_water(position) -> bool
is_on_road(position) -> bool
is_in_spawn_blocker(position) -> bool
```

These helpers should be pure and deterministic so tests can validate spawn placement.

## Phase 2: Water

Start water as a non-consumable map region with visual and movement behavior.

First behavior:

- Water renders as a flat transparent/blue surface.
- Props do not spawn inside water unless explicitly allowed.
- Cars and people routes avoid water.
- The hole can cross shallow water, but movement can be slowed slightly.

Later behavior:

- Small floating props can spawn on water.
- Consuming near water creates splash effects.
- People/cars avoid water.
- If desired, water can become a hazard or boundary for certain modes.

Implementation notes:

- Do not use dynamic water physics.
- Store water as deterministic 2D regions.
- Use region checks for movement modifiers and spawn blockers.

## Phase 3: Roads And Moving Cars

Use the approach from `moving-cars.md`:

- Cars are deterministic moving prop actors.
- Cars are not part of the static 700-prop grid.
- Cars use stable moving-prop IDs.
- Position is sampled from route, speed, phase offset, and elapsed match time.
- Server can later reproduce the exact same car transform from server tick.

Road data:

```text
RoadPath {
    id: int
    points: PackedVector3Array
    lane_count: int
    width: float
}
```

Moving car data:

```text
MovingCar {
    id: int
    route_id: int
    lane_id: int
    phase_offset: float
    speed: float
    required_radius: float
    area: float
    score: int
    consumed: bool
}
```

Cars should be consumption targets but not required for clearing the static arena. Consuming a moving car should grant score/growth and hide the car, but not decrement the static `remaining_count`.

## Phase 4: People As Lightweight Moving Actors

People should be simple deterministic moving actors, similar to moving cars but smaller and slower.

First behavior:

- People walk along sidewalks or plaza paths.
- People avoid roads and water by route design.
- People can be consumed when the hole is large enough.
- People are not physics characters.

Data shape:

```text
MovingPerson {
    id: int
    path_id: int
    phase_offset: float
    speed: float
    required_radius: float
    area: float
    score: int
    consumed: bool
}
```

Use local animation only:

- walking bob
- turn toward path tangent
- small panic effect when near a large hole later

Avoid crowd AI initially. Use deterministic path sampling.

## Phase 5: Buildings

Buildings should start as static map fixtures with tiers.

Building types:

- kiosk / shed
- small house
- shop
- apartment block
- tower section

First behavior:

- Buildings are large static props with footprints.
- Only smaller buildings are consumable in early modes.
- Bigger buildings can show "too big" feedback like existing oversized props.

Important design choice:

- Do not model every wall/floor as authoritative physics.
- A building is one gameplay object until consumed.
- Consumption can spawn visual debris pieces locally.

Building data:

```text
BuildingProp {
    id: int
    building_type: String
    footprint: Vector2
    rotation_y: float
    required_radius: float
    area: float
    score: int
    consumed: bool
}
```

Later, buildings can become compound objects with child chunks, but the MVP should keep them as one gameplay item.

## Phase 6: Stacked Objects

Stacked objects need a hybrid model: deterministic gameplay state plus local visual falling.

Example: a stack of 10 boxes.

Authoritative gameplay representation:

```text
StackGroup {
    id: int
    stack_type: String
    base_position: Vector3
    rotation_y: float
    members: StackMember[]
    stability: float
    collapsed: bool
}

StackMember {
    id: int
    local_offset: Vector3
    size: Vector3
    required_radius: float
    area: float
    score: int
    consumed: bool
}
```

Each member has a stable consumable ID. For ID ranges:

```text
static props:       0..9999
moving actors:      10000..19999
buildings:          20000..29999
stack groups:       30000..39999
stack members:      40000..49999
```

First stack behavior:

1. Stack spawns as a deterministic group of boxes.
2. Each box is individually consumable if the hole reaches it.
3. If the player presses against the stack while too small, the stack gains pressure.
4. When pressure crosses a threshold, the stack collapses.
5. Collapse changes each member from stacked position to a deterministic fallen layout.
6. Clients animate from stacked to fallen positions locally.

Do not use authoritative rigidbody simulation. Instead, precompute or derive deterministic fallen offsets.

Example deterministic collapse:

```text
fallen_angle = hash(stack_id, member_id, map_seed) mapped to 0..TAU
fallen_distance = hash(...) mapped to min/max spread
fallen_position = base_position + direction * fallen_distance
fallen_rotation = deterministic random rotation
```

The server only needs to know:

- stack group ID
- collapsed/not collapsed
- consumed member IDs
- collapse event tick

Clients can play a convincing local tumble animation to the deterministic final layout.

## Phase 7: Stack-Hole Interaction

Stack interactions should build on the existing oversized prop pressure idea.

Behavior rules:

- If the hole can consume a stack member and overlaps its footprint, consume that member.
- If the hole cannot consume the member but overlaps the stack group, add pressure.
- Pressure can lean the stack visually.
- At threshold, emit `StackCollapsed`.
- After collapse, members use fallen positions for consumption checks.

Potential events:

```text
StackPressureChanged {
    stack_id: int
    pressure_bucket: int
}

StackCollapsed {
    server_tick: int
    stack_id: int
    collapse_seed: int
}

StackMemberConsumed {
    server_tick: int
    member_id: int
    eater_player_id: int
}
```

For the local prototype, direct function calls are enough. The event shape should still guide the implementation.

## Phase 8: Spatial Partitioning

Keep separate spatial structures by object class:

- `static_prop_grid`: regular static props.
- `building_grid`: static buildings.
- `stack_grid`: stack group/member broad-phase.
- moving cars/people: dynamic small arrays or a dynamic grid later.

Do not rebuild the static prop grid every frame.

For stacks:

- Before collapse, grid the stack group bounding box.
- After collapse, either update the stack group's bounding box or register member fallen positions in a stack-specific grid.
- Keep stack count small initially to avoid over-engineering.

## Phase 9: Visual Effects

Map and stack visuals should be local-only unless they affect gameplay.

Recommended effects:

- Water splash rings when props fall into water or the hole crosses water.
- Dust puff when stacks collapse.
- Box tumble tweens from stacked to fallen final transforms.
- Building consume burst with local debris chunks.
- People/cars small pop or suction effects when consumed.

Pool repeated effects later. Do not make debris authoritative gameplay objects unless there is a specific reason.

## Phase 10: Multiplayer Compatibility

Server-authoritative state:

- map seed and map ID
- match time/tick
- consumed sets by object class
- moving car/person route sampling
- stack collapsed states
- stack member consumed states
- player area, score, deaths, phase

Client-local state:

- water shader animation
- stack falling animation
- building debris
- car/person interpolation
- dust/splash/score popups

Snapshots should include:

```text
SnapshotFull {
    map_id: String
    map_seed: int
    spawn_algo_version: int
    static_consumed_set: PackedByteArray
    moving_consumed_set: PackedByteArray
    building_consumed_set: PackedByteArray
    stack_group_state: PackedByteArray
    stack_member_consumed_set: PackedByteArray
}
```

## Suggested Implementation Order

1. Add `MapDefinition` and one hardcoded map with grass, roads, water, and spawn blocker regions.
2. Replace flat floor generation with map-region ground visuals.
3. Update static prop spawning to avoid water, roads if desired, and building footprints.
4. Add road routes and deterministic moving cars.
5. Add deterministic people paths and simple person props.
6. Add building fixtures as static large consumables.
7. Add `StackGroup` and `StackMember` data without collapse behavior.
8. Add stack member consumption while stacked.
9. Add deterministic stack collapse final positions.
10. Add local stack falling animations.
11. Add tests for map sampling, spawn blockers, route sampling, stack collapse determinism, and stack member consumption rules.

## Tests

Add tests before relying on the systems:

- `test_same_seed_generates_same_map_props`
- `test_props_do_not_spawn_in_water`
- `test_cars_follow_same_route_at_same_elapsed_time`
- `test_people_follow_same_path_at_same_elapsed_time`
- `test_stack_member_ids_are_stable`
- `test_stack_collapse_layout_is_deterministic`
- `test_collapsed_stack_members_keep_consumable_positions`
- `test_consuming_stack_member_updates_only_that_member`
- `test_building_consumption_uses_footprint`

## Acceptance Criteria

- The map has visually distinct ground, roads, and water.
- Static props still spawn deterministically and use stable IDs.
- Cars and people move deterministically from route/path data, not random per-frame movement.
- Buildings are large static consumables with footprint-based interaction.
- A stack of 10 boxes can be represented as 10 stable consumable members.
- Stack collapse is deterministic and can be replayed from seed/group/member IDs.
- Falling/tumbling is local visual animation, while final member positions are deterministic gameplay state.
- None of the new systems require networked rigidbody physics.
