# Code Review

Review date: 2026-05-28

Scope reviewed:

- `scripts/main.gd`
- `scripts/audio_util.gd`
- `scripts/prop_grid.gd`
- `scripts/math_util.gd`
- `tests/*.gd`
- `project.godot`
- `scenes/main.tscn`
- Product baseline in `README.md` and `docs/prd-godot-conversion.md`

## Findings

### High: Effective prop fit radius bypasses the authored progression data

`scripts/main.gd:386-394` defines tier and `required_radius` data, but the actual consumption gate ignores `required_radius` for boxes and trees. `_get_prop_fit_radius()` returns the box footprint half-diagonal for all boxes and `collision_radius` for trees (`scripts/main.gd:1506-1513`), and `MathUtil.tier_fit_radius()` mirrors that behavior (`scripts/math_util.gd:27-35`).

With `INITIAL_RADIUS = 1.15`, this makes at least these high-value props edible far earlier than the tier data suggests:

- `Bench`: authored `required_radius` is `1.45`, effective fit is about `1.00`, so it is edible immediately.
- `Tree`: authored `required_radius` is `1.65`, effective fit is `0.75`, so it is edible immediately.
- `Car`: authored `required_radius` is `2.25`, effective fit is about `1.40`, so it unlocks much earlier than intended.

This undermines the core growth curve and score pacing: the player can eat tier 3 and tier 4 rewards near the start, and the unlock HUD also treats those props as already available because it uses the same fit calculation. If this is intentional, the authored `required_radius` values and tier labels are misleading. If not, use something like `max(required_radius, footprint.length())` for boxes/trees or retune the prop dimensions, score, and tier data around the actual fit formula.

### Medium: The prototype is still a large single-script implementation, which works against the planned multiplayer architecture

`scripts/main.gd` is 2,378 lines and `_ready()` wires together input, materials, prop definitions, audio, profile loading, world construction, HUD construction, and match reset (`scripts/main.gd:152-160`). The same file also owns world node construction (`scripts/main.gd:398-466`), all HUD/menu construction (`scripts/main.gd:554-818`), bot AI, match phases, prop spawning, consumption arbitration, VFX, persistence, and UI formatting.

That is acceptable for an early playable prototype, but it conflicts with the PRD direction to keep gameplay logic testable and to split long-lived services/scenes such as match state, prop world, input, networking, HUD, and player holes. The risk is highest when adding server-authoritative multiplayer: consumption, growth, match state, and visual feedback are currently coupled tightly enough that extracting an authority-only simulation later will be more expensive and easier to regress.

Recommended next step: before adding networking, split pure gameplay state and rules out of `main.gd` first. Good first extraction points are prop definitions/fit rules, match phase/timer state, prop spawning, consumption arbitration, and actor growth.

### Medium: Core frame paths allocate and scan more than the mobile/multiplayer target allows

The current code is fine at prototype scale, but it is already doing work the PRD explicitly calls out as risky for mobile and future multiplayer:

- `_refresh_interaction_cache()` rebuilds arrays and a `Dictionary` every physics frame (`scripts/main.gd:1554-1578`).
- `_update_too_big_prop_feedback()` still loops over every prop each frame before broad-phase rejection (`scripts/main.gd:1239-1258`).
- Consumption feedback creates new meshes, materials, labels, and tweens per event (`scripts/main.gd:1620-1668` and nearby VFX methods).
- Bot targeting repeatedly resolves IDs by linear scan. `_find_prop_by_id()` walks all props (`scripts/main.gd:1135-1141`) and is called at least twice per live bot update (`scripts/main.gd:1018-1027`).

This is unlikely to fail with 700 props and 3 bots on desktop, but it is not aligned with the mobile target or an 8-player LAN match. Consider keeping an `id -> index` map, reusing broad-phase buffers, iterating only active candidate prop indices where possible, and pooling short-lived visual effects.

### Medium: Deterministic spawning is central to the roadmap but is not covered by tests

`_spawn_props()` uses `selected_map_seed` and assigns stable IDs (`scripts/main.gd:832-884`), which is the right direction for the planned consumed-set/network model. However, there is no automated test that the same seed produces the same ordered prop IDs, types, rotations, and positions, or that different seeds produce different layouts.

Because deterministic local spawning is the foundation for avoiding networked prop instances, this should be pinned with tests before more gameplay or networking changes land. A focused test can extract the spawn algorithm into a testable function/resource and verify `test_same_seed_spawns_same_props`, `test_different_seed_changes_layout`, and `test_spawn_algo_version_changes_when_algorithm_changes`.

### Low: `PropGrid.query_radius()` has an approximate contract but a precise name

`PropGrid.query_radius()` returns every object in cells touched by the radius bounding box, not only objects within the radius. The current tests even lock in same-cell behavior for a zero-radius query (`tests/test_prop_grid.gd:61-72`). That is a reasonable broad-phase grid contract, but the name can mislead future callers into skipping exact distance checks.

This is currently handled by the consumption path, which performs exact footprint checks later. To reduce future misuse, rename it to something like `query_radius_candidates()` or document at the method level that it returns broad-phase candidates only.

### Low: Procedural audio helpers do not guard invalid inputs

`AudioUtil.make_tone()`, `make_chord()`, and `make_noise_burst()` calculate `sample_count` directly from `sample_rate * duration` and then resize a byte buffer (`scripts/audio_util.gd:7-13`, `scripts/audio_util.gd:24-30`, `scripts/audio_util.gd:43-48`). Current callers pass safe constants, but invalid duration or sample rate values would produce empty buffers, resize errors, or division by zero.

If these helpers stay internal and constant-driven, this can remain low priority. If they become utility APIs, clamp or reject `duration <= 0` and `sample_rate <= 0`.

## Tooling Concern

The repository guideline says to validate with `godot --headless --check-only .`, but Godot 4.6.3 reports `--check-only` as a script-only option. In this environment, `godot --headless --check-only .` did not terminate and had to be killed. Script-specific checks worked:

```sh
godot --headless --check-only --script scripts/main.gd
godot --headless --check-only --script scripts/audio_util.gd
godot --headless --check-only --script scripts/prop_grid.gd
godot --headless --check-only --script scripts/math_util.gd
```

Consider updating the documented validation command or adding a small project validation script that checks all scripts consistently.

## Verification

Commands run:

```sh
godot --version
godot --headless --check-only --script scripts/main.gd
godot --headless --check-only --script scripts/audio_util.gd
godot --headless --check-only --script scripts/prop_grid.gd
godot --headless --check-only --script scripts/math_util.gd
godot --headless --script tests/test_runner.gd
godot --headless --quit-after 3 .
```

Results:

- Godot version: `4.6.3.stable.arch_linux.35e80b3a8`
- Script parse checks: passed
- Test runner: `21 passed, 0 failed`
- Headless scene startup for 3 frames: passed
