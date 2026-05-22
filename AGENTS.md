# Repository Guidelines

## Project Structure & Module Organization

This repository contains a Godot rebuild prototype for Corn Hole. The product baseline is in [README.md](README.md), and the detailed conversion plan is in [docs/prd-godot-conversion.md](docs/prd-godot-conversion.md).

- `project.godot` configures the Godot project.
- `scenes/` contains reusable `.tscn` scenes. `scenes/main.tscn` is the current entry point.
- `scripts/` contains GDScript gameplay and service code. `scripts/main.gd` currently builds the prototype arena, props, HUD, and game loop.
- `docs/` contains product and architecture notes.
- Add future imported art, audio, materials, and textures under `assets/`.
- Add automated simulation or unit-style checks under `tests/`.

## Build, Test, and Development Commands

Use Godot 4.6.3 stable as the target engine unless the project explicitly upgrades.

- `godot --editor .` opens the project in the editor.
- `godot --headless --check-only .` validates scripts and resources without launching the editor.
- `godot --headless --run-tests` should run automated tests if a Godot test framework is added.

Document any export presets before relying on Android, iOS, desktop, or dedicated server builds.

## Coding Style & Naming Conventions

Use GDScript first, matching the PRD direction. Prefer Godot-native node and scene composition over Unity-style manager objects. Use tabs for GDScript indentation, `snake_case` for variables and functions, `PascalCase` for class names, and descriptive scene names such as `PlayerHole.tscn` or `MatchHud.tscn`.

Keep gameplay rules testable and separate from presentation. Multiplayer authority should remain server-side; deterministic prop spawning should use stable object IDs and a shared `map_seed`.

## Testing Guidelines

No automated test framework is configured yet. Add tests when gameplay rules, deterministic spawning, growth calculations, or networking state transitions are introduced. Name tests around behavior, for example `test_consumption_requires_radius` or `test_same_seed_spawns_same_props`.

At minimum, validate core flows manually in the editor before opening a pull request: movement, consumption, growth, match phase changes, and any changed UI.

## Commit & Pull Request Guidelines

The current history uses short, imperative commit subjects, sometimes with a PR number, for example `Add the Godot conversion PRD and surface the architecture baseline in README (#1)`. Follow that style.

Pull requests should include a clear summary, linked issue when applicable, test or manual verification notes, and screenshots or short clips for visual gameplay changes. Call out changes to architecture, multiplayer authority, export settings, or deterministic world generation explicitly.
