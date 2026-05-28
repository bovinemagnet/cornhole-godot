# Moving Cars Implementation Plan

Goal: integrate the low-poly prop scenes into the game, then add cars as deterministic moving prop actors that are separate from the static 700-prop world. The design should preserve the future multiplayer model: static props remain deterministic local spawn data, and moving cars have deterministic routes/state that can later be simulated or validated by the server.

## Principles

- Keep the existing static prop count and static `prop_grid` model intact.
- Do not put moving cars into the static prop grid built from the 700 static props.
- Represent moving cars with stable IDs, route IDs, deterministic phase offsets, and current positions derived from match time.
- Avoid frame-accumulated random movement. A car's position should be computed from `map_seed`, `route_id`, `speed`, `phase_offset`, and elapsed match time.
- Keep visual effects and gameplay state separate enough that server-side simulation can reuse the same route math later.

## Phase 1: Use The Prop Scenes For Static Visuals

1. Add a prop visual registry.
   - Map current object type names to packed scenes:
     - `Can` -> `res://scenes/props/PropCan.tscn`
     - `Box` -> `res://scenes/props/PropBox.tscn`
     - `Ball` -> `res://scenes/props/PropBall.tscn`
     - `Bin` -> `res://scenes/props/PropBin.tscn`
     - `Bench` -> `res://scenes/props/PropBench.tscn`
     - `Car` -> `res://scenes/props/PropCar.tscn`
     - `Tree` -> `res://scenes/props/PropTree.tscn`

2. Replace procedural static prop visuals behind a feature-safe helper.
   - Keep the existing prop dictionaries and gameplay metadata.
   - Change only `_build_prop_visual()` or its replacement to instance a packed scene when available.
   - Preserve current fallback primitive generation for missing scenes.

3. Disable or ignore scene `StaticBody3D` collisions for gameplay if needed.
   - The game currently uses custom footprint checks, not Godot physics overlap, for prop consumption.
   - The scene collision bodies are useful for editor inspection and future tooling, but consumption should continue using deterministic metadata.

4. Validate visual scale against the current tier metadata.
   - Ensure each visual scene roughly matches the existing `scale`, `collision_radius`, and `footprint` values.
   - If a prop scene's visual size differs from metadata, update metadata deliberately rather than relying on visual dimensions implicitly.

## Phase 2: Define Moving Car Data Separately

Add a new moving-prop collection, separate from `props`:

```gdscript
var moving_props := []
var moving_props_root: Node3D
```

Each moving car entry should use data shaped like:

```text
{
    id: int,                         # stable moving-prop ID
    object_type: "MovingCar",
    scene_path: String,
    route_id: int,
    lane_id: int,
    phase_offset: float,
    speed: float,
    area: float,
    score: int,
    required_radius: float,
    collision_radius: float,
    footprint: Vector2,
    rotation_y: float,
    node: Node3D,
    consumed: bool,
    position: Vector3
}
```

Use a separate ID range so static prop IDs and moving prop IDs never collide. For example:

```text
static prop IDs: 0..699
moving prop IDs: 10000..10000 + moving_prop_count - 1
```

Future network events can then include `object_kind` or reserve ID ranges:

```text
ObjectConsumed {
    object_kind: StaticProp | MovingProp
    object_id: int
}
```

## Phase 3: Deterministic Route Model

Start with fixed lane routes rather than pathfinding.

Recommended route type: looped polyline.

```text
Route {
    id: int
    points: PackedVector3Array
    loop: bool
    width: float
}
```

Example routes:

- Horizontal lane across the north half of the arena.
- Horizontal lane across the south half of the arena.
- Vertical lane on the west side.
- Vertical lane on the east side.
- Rectangular loop around the center.

For deterministic positioning:

```text
distance = fposmod((elapsed_seconds * speed) + phase_offset, route_length)
position = sample_route(route, distance)
rotation_y = direction angle from route tangent
```

Important: `elapsed_seconds` should come from match simulation time, not wall-clock time. In the current local prototype, derive it from:

```text
elapsed_seconds = selected_match_seconds - time_remaining
```

Later, multiplayer can use:

```text
elapsed_seconds = server_tick * fixed_delta
```

## Phase 4: Spawn Moving Cars Deterministically

Add a `_spawn_moving_props()` step after `_spawn_props()`.

Use the selected map seed plus a moving-prop namespace value:

```text
rng.seed = selected_map_seed + 910_000 + SPAWN_ALGO_VERSION
```

For each moving car:

- Choose a route ID deterministically.
- Choose a phase offset deterministically along that route.
- Choose a speed from a small deterministic range.
- Assign a stable moving ID.
- Instance `PropCar.tscn`.
- Store initial computed position and rotation.

Keep the count small at first:

```text
MOVING_CAR_COUNT := 8
```

The cars should not reduce `remaining_count` for static props unless the game intentionally wants moving cars included in match clear conditions. Recommended first behavior: moving cars are score opportunities but not required to clear the arena.

## Phase 5: Update Moving Cars Each Physics Frame

Add `_update_moving_props()` during the `PLAYING` phase before consumption checks:

```text
_update_moving_props()
_refresh_interaction_cache()
_check_consumption()
_check_moving_prop_consumption()
_check_hole_consumption()
```

For each unconsumed moving car:

- Compute position from route and elapsed match time.
- Compute facing from route tangent.
- Update the node transform.
- Update the dictionary `position` and `rotation_y`.

When the match is paused, do not advance because elapsed match time should not advance while paused.

## Phase 6: Consumption Checks For Moving Cars

Do not add moving cars to `active_prop_indices` or `prop_grid`.

Instead add:

```text
func _check_moving_prop_consumption() -> void
```

The function should:

- Iterate `moving_props`.
- Skip consumed cars.
- Use the same actor cache from `_refresh_interaction_cache()`.
- Reuse the same eligibility logic where possible:
  - `_can_actor_consume_prop()`
  - `_does_prop_footprint_touch_consume_radius()`
  - `_find_consumption_winner()`
- Consume exactly one actor per moving car per frame.

If existing helpers require a static prop dictionary, keep the moving car dictionary compatible with the same keys: `position`, `shape`, `footprint`, `required_radius`, `collision_radius`, `rotation_y`, `area`, `score`, `consumed`, `node`.

Add a separate consume function if needed:

```text
func _consume_moving_prop(prop: Dictionary, actor: Dictionary) -> void
```

It can call shared growth/VFX helpers, but it should not decrement `remaining_count`.

## Phase 7: Bot Targeting

Keep first implementation simple:

1. Static props remain bot targets.
2. Moving cars can be opportunistically consumed if a bot overlaps one.

After that works, add moving-car targeting:

- Only consider moving cars that are currently edible.
- Predict a short intercept point using deterministic route position at `elapsed + lead_seconds`.
- Compare weighted distance against static prop targets.
- Keep this separate from static `prop_grid` lookup.

This avoids destabilizing bot behavior while proving the moving prop model.

## Phase 8: Multiplayer Compatibility

The server-authoritative future should use the same route sampling function.

Server owns:

- `map_seed`
- `spawn_algo_version`
- moving prop route definitions
- moving prop consumed set
- consumption arbitration
- score and growth updates

Clients own:

- local visual interpolation
- rendering the same deterministic route motion
- hiding cars after server `ObjectConsumed` events

The network event should include enough information to identify moving cars separately from static props:

```text
ObjectConsumed {
    server_tick: int
    event_seq: int
    object_kind: int
    object_id: int
    eater_player_id: int
    eater_hole_area_after: int
    eater_score_after: int
}
```

Late join snapshots should include:

```text
moving_consumed_set: PackedByteArray
```

or a unified consumed set with non-overlapping object ID ranges.

## Phase 9: Tests

Add deterministic tests before enabling moving cars by default:

- `test_same_seed_spawns_same_moving_cars`
- `test_different_seed_changes_moving_car_phase_or_route`
- `test_route_sampling_is_repeatable`
- `test_route_sampling_wraps_loop_distance`
- `test_moving_car_position_matches_elapsed_time`
- `test_consumed_moving_car_does_not_decrement_static_remaining_count`

If route sampling is extracted into a pure utility script, these tests can run in the existing custom test runner.

## Suggested Implementation Order

1. Add `MovingRouteUtil.gd` with pure route length and route sampling helpers.
2. Add tests for route sampling.
3. Add moving car constants and route definitions.
4. Add `_spawn_moving_props()` and `moving_props_root`.
5. Add `_update_moving_props()` using match elapsed time.
6. Add `_check_moving_prop_consumption()` without changing static prop behavior.
7. Add visual feedback and event feed messages for moving car consumption.
8. Add optional bot targeting for moving cars.
9. Document the moving-prop ID range and network event shape.

## Acceptance Criteria

- Static 700-prop spawning still uses the static grid and existing IDs.
- Moving cars are not inserted into `prop_grid`.
- Same seed, match time, and route definitions produce the same car transforms.
- Consuming a moving car grants score/growth and hides the car.
- Consuming a moving car does not decrement `remaining_count`.
- Pausing the match stops visual car progression because match elapsed time stops.
- The implementation has pure tests for route sampling and deterministic moving-car spawn data.
