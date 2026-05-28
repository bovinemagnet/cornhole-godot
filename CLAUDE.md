# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A Godot 4.6.3 rebuild of Corn Hole, a 3D arcade arena game inspired by Hole.io: a circular hole moves around a top-down arena consuming objects smaller than itself, growing as it does. Development is single-player-first, with authoritative private-join-code multiplayer planned for a later phase.

The full conversion plan, including the target multiplayer architecture, scene layout, and network message schema, lives in `docs/prd-godot-conversion.md`. `AGENTS.md` covers contribution conventions. Read both before substantial changes.

## Commands

Target Godot 4.6.3 stable (not 4.7 beta).

- `godot --editor .` — open the project in the editor.
- `godot --headless --check-only --script scripts/<file>.gd` — validate one GDScript file. In Godot 4.6.3 `--check-only` is a script-only flag, so the directory form (`--check-only .`) hangs; always pass a `--script` path. Validate every script you touch.
- `godot --headless --script tests/test_runner.gd` — run the lightweight test suite under `tests/`. This is the canonical validator: it also parses every test script, so it catches parse errors in addition to running behaviour tests.
- `godot .` — run the project (main scene is `scenes/main.tscn`).

Tests live in `tests/` as `RefCounted` subclasses with `test_*` methods returning `""` on pass or a message on fail; the runner script aggregates results. When gameplay rules, deterministic spawning, growth maths, or networking state transitions are added, add tests and name them around behaviour, e.g. `test_consumption_requires_radius`, `test_same_seed_spawns_same_props`.

## Architecture

The entire game is a single ~2,160-line script, `scripts/main.gd` (`extends Node3D`), attached to `scenes/main.tscn`. It builds everything procedurally at runtime — no `.tscn` art, no imported assets, no other scripts.

- `_ready()` runs the build pipeline: input actions → materials → prop tiers → profile load → world → HUD → `reset_match(false)`.
- `_build_world()` builds environment, lighting, floor, walls, the `PlayerHole` node, the AI rivals (`_create_bots()`), and the camera from primitive meshes.
- `_physics_process()` dispatches on `match_phase` (see state machine below) and, while playing, runs the loop: respawns → player movement → bot AI → too-big-prop feedback → prop markers → prop consumption → hole-vs-hole consumption → camera → HUD.
- `prop_tiers` (`_create_prop_tiers()`) defines the consumable catalogue (Can → Tree) with `shape`, `scale`, `required_radius`, `area`, `score`, and spawn `weight`. `_spawn_props()` seeds a `RandomNumberGenerator` with `selected_map_seed` so the layout is deterministic; each prop is a plain `Dictionary` in the `props` array (not a node-per-prop), carrying a stable `id` and `spawn_algo_version` — this is the basis for the planned deterministic multiplayer spawning.

**Match state machine**: `match_phase` is one of `MatchPhase.{MENU, COUNTDOWN, PLAYING, PAUSED, ENDED}`. `_physics_process()` `match`es on it; `reset_match()`, `_start_practice_match()`, `_pause_match()`, `_resume_match()`, `_return_to_menu()`, and `_end_match()` are the transitions. The HUD has a panel per phase (menu, pause, result).

**Actor abstraction**: the player and each AI rival ("bot") are both treated as an *actor* — a `Dictionary` with `radius`, `area`, `score`, `alive`, `is_player`, etc. The `_get_actor_*` / `_is_actor_alive()` helpers and `_get_consumption_actors()` let consumption, growth, and ranking code treat player and bots uniformly. Bot AI lives in `_update_bots()` and is tuned by `selected_bot_difficulty` via the `_get_bot_*_scale()` helpers.

**Growth model** (canonical, preserve this): area is the authoritative stat. `hole_area` accumulates consumed `area` values capped at `MAX_AREA`; `hole_radius = sqrt(hole_area / PI)` is derived from it. Consumption requires the prop's *footprint* to touch the actor's consume radius (`radius * CONSUME_RADIUS_FACTOR`) *and* the actor radius to clear the prop's fit radius — rectangular props use their rotated-rect footprint (`_distance_to_rotated_rect()`), not a single tier radius. Holes can also eat smaller holes (`_check_hole_consumption()`).

**Persistence**: best score and player name persist to `user://profile.cfg` via `_load_profile()` / `_save_profile()`.

**Tuning constants** are the large `const` block at the top of `main.gd` (arena size, speeds, match length, prop count, consume factor, bot weights, minimap size). Adjust feel there. `selected_*` vars are the menu-chosen runtime overrides of the `MATCH_SECONDS` / `MAP_SEED` / `BOT_COUNT` defaults.

## Tooling

`.mcp.json` configures the `godot` MCP server (`@coding-solo/godot-mcp`), which exposes editor/run/scene tools and reads `GODOT_PATH`.

## Conventions

- GDScript first; prefer Godot-native node/scene composition over Unity-style manager singletons.
- Tabs for indentation, `snake_case` for variables/functions, `PascalCase` for class and scene names.
- Keep gameplay rules testable and separate from presentation.
- For future multiplayer: the server is authoritative; clients send input only. Do not network individual props — spawn them deterministically from a shared `map_seed` with stable object IDs and replicate only player state plus authoritative events (see PRD sections 8–9).
- Commit subjects are short and imperative, optionally with a PR number, e.g. `Add the Godot conversion PRD and surface the architecture baseline in README (#1)`.
