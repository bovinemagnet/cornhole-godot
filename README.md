# Corn Hole — Godot Edition

This repository tracks the Godot rebuild of Corn Hole as a 3D arcade arena game
with single-player-first development and a later move to authoritative private
multiplayer.

## Current product direction

- Engine target: Godot 4.6.3 stable
- Initial language: GDScript
- Primary platforms: Android, iOS, and desktop test builds
- Multiplayer target: private join-code matches using `ENetMultiplayerPeer`
- Core networking rule: deterministically spawn props locally and replicate
  only authoritative player state plus server-owned events

## Product requirements

The full conversion product requirements document lives at
[`docs/prd-godot-conversion.md`](docs/prd-godot-conversion.md).

## Current implementation

The repository now includes a playable single-player Godot prototype:

- `project.godot` configures the Godot project.
- `scenes/main.tscn` is the main scene.
- `scripts/main.gd` builds the arena, player hole, consumable props, camera,
  menu, HUD, timer, scoring, AI rivals, live rank, match results, leaderboard,
  and restart flow.

Controls:

- Enter a player name, choose a match length, arena seed, rival count, and rival
  skill, then select **Play Practice** or press `Enter` from the menu to start.
- `WASD` or arrow keys move the hole.
- Drag the on-screen joystick for touch-style movement.
- `Esc` or `P` pauses during countdown or play.
- Consume objects whose footprint touches the inner ring and fits the hole.
  Rectangular props use their actual width and length instead of an arbitrary
  tier radius.
- Oversized objects lean or start to fall when caught by the hole but remain in
  the arena until the hole is large enough.
- Nearby objects show green markers when edible and amber markers when they are
  caught by the hole but still too large.
- AI rivals compete for the same deterministic prop set, with selectable skill
  levels that change speed, prop targeting, hunting, and threat avoidance.
- Larger holes can eat smaller holes; eaten players respawn after a short delay.
- The event feed records recent eats, unlocks, knockouts, respawns, and results.
- The HUD shows current radius, match eat count, saved best score, and progress
  toward the next prop type.
- Match results include player stats for props eaten, holes eaten, deaths, biggest
  prop eaten, and best score.
- Best score is saved locally under Godot's `user://` profile storage.
- A minimap shows the player, rivals, and nearby edible or oversized props.
- Growth milestones announce newly edible prop types.
- Matches start with a short countdown.
- `Space`, `Enter`, or the restart button restarts after the match ends.

Run locally with Godot 4.6.x:

```sh
godot --editor .
```

## Delivery phases

1. Phase 0: create the Godot project foundation and core scene structure
2. Phase 1: rebuild single-player feel, consumption, growth, HUD, and camera
3. Phase 2+: add authoritative multiplayer, deterministic prop spawning, and
   dedicated server support
