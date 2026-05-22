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

## Delivery phases

1. Phase 0: create the Godot project foundation and core scene structure
2. Phase 1: rebuild single-player feel, consumption, growth, HUD, and camera
3. Phase 2+: add authoritative multiplayer, deterministic prop spawning, and
   dedicated server support
