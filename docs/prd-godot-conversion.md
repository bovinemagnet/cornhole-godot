# Product Requirements Document

## Corn Hole — Godot Edition

### Document status

**Product:** Corn Hole  
**Genre:** 3D arcade arena / Hole.io-inspired consume-and-grow game  
**Target engine:** Godot 4.x  
**Recommended current target:** Godot 4.6.3 stable, not 4.7 beta, because Godot lists 4.6.3 as the latest stable release as of 20 May 2026. ([Godot Engine][2])  
**Primary platforms:** Android, iOS, desktop test builds  
**Primary mode:** Private join-code multiplayer  
**Initial development style:** Single-player-first Godot rebuild, then authoritative multiplayer  
**Owner:** Paul Snow  
**Version:** 0.1 Godot conversion PRD

---

## 1. Executive summary

Corn Hole is a family-friendly, real-time 3D multiplayer game inspired by Hole.io. Each player controls a circular hole moving across a top-down arena. The hole consumes objects smaller than itself. Consumed objects increase the player’s score and mass, causing the hole to grow. Larger holes can consume larger objects, and later game modes allow larger holes to consume smaller player holes.

The existing Unity design should be preserved at the product level, but the Godot implementation should not attempt a direct Photon Fusion clone. The Godot version should use Godot’s scene tree, Node/Scene composition, autoload services, `ENetMultiplayerPeer`, RPCs, deterministic prop spawning, and headless/dedicated server support.

The most important architectural change is this:

> Do not network every consumable object as an active physics object.  
> Spawn the world deterministically on each client, let the server decide consumption, and replicate only player state plus authoritative events.

This matches the strongest idea already present in your repo docs: deterministic world generation, authoritative `ObjectConsumed` events, consumed-set sync, and server-owned outcomes. ([GitHub][3])

---

## 2. Existing Unity design to preserve

The current Unity version has these core implemented or planned concepts:

The player controls a hole in 3D space, consumes eligible objects, grows from consumption, scores points, and uses camera follow behaviour. Multiplayer is currently framed around Photon Fusion Host Mode, where one player acts as both server and player. The project targets Android, iOS, and desktop testing. ([GitHub][1])

The current gameplay code already includes a useful area-based growth model: `holeArea` is the authoritative growth stat, and radius is derived from area. The existing `HolePlayer` script uses networked radius, area, score, ready state, movement velocity, and input-authority/state-authority concepts. ([GitHub][4])

The existing `NetworkManager` design handles host/join flow, join-code session names, max players, input polling, player spawning, and session lifecycle. In Godot this should become a combination of `NetworkService`, `LobbyService`, `MatchService`, and scene-level spawners rather than a single Unity-style `MonoBehaviour`. ([GitHub][5])

The current `ObjectSpawner` randomly spawns networked consumables during the playing phase. In Godot, this should be redesigned. The MVP may still use simple spawning, but the target architecture should be deterministic spawning from a `map_seed`, not network-instantiating each prop. ([GitHub][6])

The current `MatchTimer` already has a clean lifecycle: Lobby → Countdown → Playing → Ended. This should be kept almost exactly as a product concept, but implemented as a Godot authoritative match-state service. ([GitHub][7])

---

## 3. Product vision

Build a simple, satisfying, private multiplayer “gobble arena” game where kids and family can quickly create a game, share a join code, and compete to become the largest hole.

The game should feel immediate, playful, and readable:

A small hole starts by consuming small objects such as cones, boxes, toys, plants, food, or props. As it grows, it consumes bigger objects such as benches, bins, cars, trees, buildings, and eventually smaller player holes. The match ends with a clear winner based on score, size, or last hole standing.

The long-term vision is a cross-platform private multiplayer game with these pillars:

1. **Fast to start:** create match, share code, play.
2. **Easy to control:** touch drag/virtual joystick on mobile, keyboard/controller on desktop.
3. **Satisfying growth:** strong suction, drop, score, camera zoom, sound, and scale feedback.
4. **Fair multiplayer:** server decides movement, consumption, scoring, deaths, and match timing.
5. **Low network complexity:** sync players and events, not thousands of physics props.
6. **Future-ready:** support host mode first, then dedicated Godot headless servers.

---

## 4. Goals

### 4.1 Player goals

Players should be able to:

- Start a private match with a short join code.
- Join a match without accounts or public matchmaking.
- Move a hole smoothly around a 3D arena.
- Consume objects smaller than the hole.
- Grow visibly and mechanically from consumption.
- Compete on score, size, or survival.
- Understand why an object can or cannot be consumed.
- See consumed objects disappear consistently for all players.
- Play short matches that feel complete within 2–5 minutes.

### 4.2 Developer goals

The Godot project should:

- Be easy to iterate on in the Godot editor.
- Prefer Godot-native scenes and nodes over Unity-style manager objects everywhere.
- Keep gameplay logic testable and mostly independent of visual effects.
- Use deterministic spawning and stable object IDs.
- Keep multiplayer authority server-side.
- Avoid syncing prop physics.
- Support a headless/dedicated server build later. Godot supports running dedicated servers using `--headless` or exporting a project as a dedicated server, which makes this a good fit for your roadmap. ([Godot Engine documentation][8])

---

## 5. Non-goals for the first Godot version

The first Godot version should **not** try to replicate everything from Unity at once.

Non-goals:

- No public matchmaking.
- No accounts.
- No chat.
- No monetisation.
- No cosmetics store.
- No complex rigidbody networking.
- No large open-world map.
- No console support in the MVP.
- No battle royale until object consumption is reliable.
- No late join/reconnect until the consumed-set model is working.

This is important because the current design already has several ambitious multiplayer features. The Godot rebuild should first prove the feel, then the deterministic object model, then multiplayer.

---

## 6. Recommended Godot technology choices

### 6.1 Engine version

Use **Godot 4.6.3 stable** as the baseline unless a later stable release exists when development begins. Godot’s own site currently lists 4.6.3 as the latest stable release, while 4.7 is still shown as beta. ([Godot Engine][2])

### 6.2 Language choice

Use **GDScript** for the first Godot mobile version.

This is my strong recommendation. You are capable of using C#, and the Unity code is already C#, but Godot’s own export docs still mark C# export to Android and iOS as experimental. For a mobile-first game, GDScript will reduce platform friction. ([Godot Engine documentation][9])

Use C# later only if:

- you decide desktop/server is more important than mobile,
- you need shared C# simulation libraries,
- or you are comfortable accepting mobile export limitations.

### 6.3 Networking

Use Godot’s high-level multiplayer API with `ENetMultiplayerPeer` for the first multiplayer implementation. Godot’s docs state that high-level networking is managed through the scene tree, and that networking is initialized by creating a `MultiplayerPeer` as server or client and assigning it to the multiplayer API. ([Godot Engine documentation][10])

Godot’s high-level multiplayer uses UDP and a modified ENet implementation. For LAN play, clients can connect using a local IP; for internet play, UDP port forwarding or public hosting will be required. ([Godot Engine documentation][10])

### 6.4 Multiplayer replication approach

Use a hybrid approach:

- `MultiplayerSynchronizer` for simple player state such as position, visible radius, score, name, ready state, and alive state.
- RPCs for authoritative discrete events such as object consumed, player eaten, phase changed, snapshot received.
- `MultiplayerSpawner` only for player holes and major dynamic entities, not for every consumable prop.

Godot’s `MultiplayerSpawner` is designed to replicate scenes added by the authority under a spawn path, but this should be used selectively. ([Godot Engine documentation][11])  
Godot’s `MultiplayerSynchronizer` synchronizes configured properties from the multiplayer authority to remote peers, which fits player state better than world props. ([Godot Engine documentation][12])

### 6.5 Mobile export

Android export requires Android SDK setup and OpenJDK 17 is recommended by the Godot docs. ([Godot Engine documentation][13])  
iOS export requires macOS with Xcode installed and Godot export templates. ([Godot Engine documentation][9])

### 6.6 Touch controls

Use a custom virtual joystick implemented with `Control` nodes for the main movement input. Use `TouchScreenButton` for simple gameplay buttons if boost, ability, or ready/start controls are added to the in-game HUD. Godot’s `TouchScreenButton` is intended for gameplay use and supports multitouch. ([Godot Engine documentation][14])

---

## 7. Core gameplay requirements

### 7.1 Core loop

The core loop is:

1. Player moves hole around the arena.
2. Player targets objects that are small enough to consume.
3. Object enters the inner consume zone.
4. Server confirms consumption.
5. Object disappears for all players.
6. Player gains area/mass and score.
7. Hole radius increases.
8. Camera zooms out slightly.
9. Player can now consume larger objects.
10. Match ends by timer, score, or survival rule.

### 7.2 Movement

The hole moves on the XZ plane.

Movement requirements:

- Smooth acceleration.
- Smooth deceleration.
- Clamp diagonal speed.
- Clamp maximum input magnitude.
- Server validates input.
- Client may predict local movement later, but the MVP can use server-authoritative movement with interpolation.

### 7.3 Camera

The camera should be top-down / angled top-down.

Requirements:

- Follow local player smoothly.
- Zoom out based on hole radius.
- Clamp minimum and maximum zoom.
- Avoid jitter from network correction.
- Keep arena readable on mobile screens.

This directly preserves the intent of the current Unity `CameraFollow` script, which follows the local player and adjusts zoom height based on hole radius. ([GitHub][15])

### 7.4 Consumption

An object can be consumed when:

- it has not already been consumed,
- the player is alive,
- the match phase is `Playing`,
- the hole radius is greater than or equal to the object’s required radius,
- the object centre is inside the hole’s inner consume radius,
- and the server chooses that player as the winner if multiple players are eligible.

### 7.5 Growth model

Use area/mass as the canonical stat.

Recommended formula:

```text
initial_area = PI * initial_radius * initial_radius

on_object_consumed:
    hole_area = min(hole_area + object_area_value, max_area)
    radius = sqrt(hole_area / PI)
```

This matches the existing Unity design, where `HoleArea` is increased and `HoleRadius` is derived from area. ([GitHub][4])

### 7.6 Object tiers

Each consumable object should have:

```text
object_id: int
object_type: enum/string
required_radius: float
area_value: float
score_value: int
tier: int
visual_scene: PackedScene
collision_radius: float
spawn_position: Vector3
```

Example tiers:

| Tier | Example objects          | Required radius |
| ---: | ------------------------ | --------------: |
|    1 | cans, balls, small boxes |             1.0 |
|    2 | cones, bins, stools      |             1.5 |
|    3 | benches, shrubs, signs   |             2.5 |
|    4 | cars, trees, kiosks      |             4.0 |
|    5 | small buildings, buses   |             6.5 |

### 7.7 Object feedback

When an object is consumed:

- Play suction animation.
- Move visual clone toward hole centre.
- Shrink object to zero.
- Spin or tumble object.
- Play sound.
- Play particles.
- Update score and size.

The current Unity version already has this concept through `ConsumeEffect`, which pulls a visual clone toward the hole centre, shrinks it, spins it, and destroys it. ([GitHub][16])

---

## 8. Multiplayer requirements

### 8.1 Authority model

The server is authoritative.

Clients may send:

```text
InputFrame {
    client_tick
    move_vector
    buttons
    sequence
}
```

Clients must not send:

```text
I consumed object X
I gained score Y
My radius is now Z
I killed player B
The match is over
```

The current strategic docs already identify this as the correct model: clients send input only, while the server owns movement, positions, mass, consumed objects, kills, score, and match phase. ([GitHub][17])

### 8.2 Godot host mode

For the first multiplayer version:

- One Godot instance creates an ENet server.
- Other players join as ENet clients.
- Host is also a player.
- Host controls match start.
- Session is private via join code.

Godot does not give you Photon’s cloud lobby/session service out of the box. Therefore, a local join-code system needs a backing strategy.

For LAN MVP, use one of these:

1. **Manual IP + code:** simplest technical path.
2. **LAN discovery + code:** host broadcasts lobby info over UDP; clients see local games but still enter/confirm code.
3. **Tiny rendezvous service later:** maps join code to public IP/server for remote play.

The PRD should not pretend Godot automatically replaces Photon lobby/session discovery. That needs to be designed.

### 8.3 Join-code requirement

Player flow:

1. Host taps **Create Match**.
2. Game creates lobby.
3. Game generates code, e.g. `CORN-72` or `8K4M2Q`.
4. Joiners enter code.
5. Clients connect.
6. Lobby shows players.
7. Players ready up.
8. Host starts countdown.

### 8.4 Match phases

Keep the existing lifecycle:

```text
Lobby -> Countdown -> Playing -> Ended
```

Requirements:

- Only server changes phase.
- Countdown is synchronized.
- Match timer is server-owned.
- End screen uses server result.
- Clients display phase changes from replicated match state or RPC.

This preserves the current `MatchTimer` model. ([GitHub][7])

### 8.5 Shared world strategy

Do **not** spawn every consumable object as a networked node.

Instead:

1. Server creates `map_seed`.
2. All peers generate the same props locally.
3. Each prop receives stable `object_id`.
4. Server tracks `consumed_set`.
5. Server emits `ObjectConsumed`.
6. Clients hide/despawn that local object.
7. Late joiners receive full consumed-set snapshot.

This is already the target architecture in your docs and is the right design for Godot as well. ([GitHub][3])

### 8.6 Consumption arbitration

When multiple holes are eligible to consume the same object during the same server tick:

1. Server gathers candidates.
2. Rejects candidates below required radius.
3. Rejects candidates outside inner consume radius.
4. Chooses smallest distance to object centre.
5. If tied within epsilon, chooses larger radius.
6. If still tied, chooses lowest player ID.
7. Emits exactly one `ObjectConsumed`.

This matches the existing repo’s authoritative event model. ([GitHub][3])

### 8.7 Battle royale mode

Battle royale is not MVP, but the architecture must support it.

Rules:

- Larger holes can consume smaller holes.
- Use a kill margin to avoid unfair close-radius kills.
- Example: predator radius must be at least `prey_radius * 1.10`.
- Predator must overlap prey centre or inner consume zone.
- Prey is eliminated.
- Predator receives prey’s mass and optionally score.
- Last alive player wins.

The existing design already includes this long-term feature: larger holes consume smaller holes and inherit mass/loot. ([GitHub][3])

---

## 9. Godot architecture

### 9.1 Recommended scene structure

```text
res://
  scenes/
    app/
      Main.tscn
    menus/
      MainMenu.tscn
      JoinMenu.tscn
      Lobby.tscn
      EndScreen.tscn
    game/
      GameWorld.tscn
      Arena.tscn
      PlayerHole.tscn
      ConsumableProp.tscn
      CameraRig.tscn
      HUD.tscn
    effects/
      ConsumeEffect.tscn
  scripts/
    autoload/
      AppState.gd
      NetworkService.gd
      LobbyService.gd
      MatchService.gd
      InputService.gd
      AssetRegistry.gd
    game/
      player_hole.gd
      player_hole_authority.gd
      consumable_prop.gd
      prop_world.gd
      consume_arbiter.gd
      match_state.gd
      camera_rig.gd
    data/
      prop_definition.gd
      player_state.gd
      match_snapshot.gd
      consumed_set.gd
  resources/
    props/
      prop_definitions/
    maps/
      arena_definitions/
  art/
  audio/
```

### 9.2 Autoloads

Use Godot autoloads for long-lived services:

| Autoload         | Responsibility                                        |
| ---------------- | ----------------------------------------------------- |
| `AppState`       | Current app screen, local settings, nickname          |
| `NetworkService` | ENet server/client setup, peer lifecycle, RPC routing |
| `LobbyService`   | Join-code flow, lobby roster, ready state             |
| `MatchService`   | Match phase, timer, start/end flow                    |
| `InputService`   | Touch, keyboard, controller input normalization       |
| `AssetRegistry`  | Prop definitions, arena definitions, packed scenes    |

### 9.3 Key gameplay scenes

#### `PlayerHole.tscn`

Suggested nodes:

```text
PlayerHole (CharacterBody3D or Node3D)
  VisualRoot (Node3D)
    HoleMesh (MeshInstance3D)
    RingMesh (MeshInstance3D)
  ConsumeArea (Area3D)
    CollisionShape3D
  MultiplayerSynchronizer
  NameLabel3D
```

Use `CharacterBody3D` if you want Godot movement helpers. Use plain `Node3D` if the server simulation is fully custom and grid-based. My preference for this game is `Node3D` plus explicit simulation, because the hole is not a normal physical character.

#### `ConsumableProp.tscn`

Suggested nodes:

```text
ConsumableProp (Node3D)
  VisualRoot (Node3D)
    MeshInstance3D
  ConsumeMarker (Node3D)
  OptionalArea (Area3D)
```

Avoid `RigidBody3D` for most gameplay props in multiplayer. If a prop needs to visually fall, animate it locally. The server should treat props as static deterministic objects with simple radius/size metadata.

#### `GameWorld.tscn`

```text
GameWorld (Node3D)
  Arena
  PropWorld
  Players
  Effects
  CameraRig
  HUD
```

### 9.4 Server-side systems

#### `ConsumeArbiter`

Runs only on authority.

Responsibilities:

- Maintain spatial grid of unconsumed objects.
- Check nearby objects for each player.
- Determine eligibility.
- Resolve contested consumption.
- Update consumed set.
- Update score and area.
- Emit `object_consumed` RPC.

#### `ConsumedSet`

Data structure:

```text
num_objects: int
bits: PackedByteArray
last_event_seq: int
```

Requirements:

- `is_consumed(object_id)`.
- `mark_consumed(object_id)`.
- `serialize_full()`.
- `serialize_changed_chunks()`.
- `apply_snapshot()`.
- `apply_event()`.

The repo’s consumed-set doc recommends a bitset or chunked bitset, where one bit per object ID indicates whether the object still exists or has been consumed. ([GitHub][18])

---

## 10. Unity-to-Godot conversion map

| Unity / Photon concept   | Existing role                     | Godot replacement                                                                       |
| ------------------------ | --------------------------------- | --------------------------------------------------------------------------------------- |
| `MonoBehaviour`          | Component script                  | Script attached to `Node`, `Node3D`, `Control`, `Area3D`, etc.                          |
| `NetworkBehaviour`       | Photon networked object behaviour | Godot node with authority checks, RPC methods, and optionally `MultiplayerSynchronizer` |
| `[Networked]` properties | Replicated state                  | `MultiplayerSynchronizer` properties or explicit RPC/snapshot state                     |
| `NetworkRunner`          | Session, spawn, input, tick       | `NetworkService` autoload + `SceneTree.multiplayer` + `ENetMultiplayerPeer`             |
| `NetworkPrefabRef`       | Network-spawnable prefab          | `PackedScene`, `MultiplayerSpawner`, or deterministic local spawn                       |
| `Runner.Spawn()`         | Network instantiate               | `MultiplayerSpawner.spawn()` for players only; deterministic local spawning for props   |
| `RPC_*` methods          | Network events                    | Godot `@rpc` methods                                                                    |
| `SphereCollider` trigger | Consume detection                 | `Area3D` + `CollisionShape3D`, or server spatial grid                                   |
| `Rigidbody` consumables  | Falling/physics props             | Mostly avoid for multiplayer; use static metadata plus local-only visual effects        |
| `TextMeshPro` UI         | Menus/HUD                         | Godot `Control`, `Label`, `Button`, `LineEdit`, `CanvasLayer`                           |
| `SceneManager.LoadScene` | Scene navigation                  | `get_tree().change_scene_to_file()` or app state scene router                           |
| `DontDestroyOnLoad`      | Persistent manager                | Autoload singleton                                                                      |
| Unity input axes/touch   | Player movement                   | Godot Input Map + custom virtual joystick                                               |
| Photon Host Mode         | Host player is server             | ENet server hosted by one Godot client                                                  |
| Photon Server Mode       | Dedicated server                  | Godot `--headless` or dedicated server export                                           |

---

## 11. Network messages

### 11.1 Client to server

```text
JoinRequest {
    join_code: String
    client_version: int
    nickname: String
    reconnect_token: String?
}
```

```text
InputFrame {
    client_tick: int
    sequence: int
    move_x: int8
    move_z: int8
    buttons: int
}
```

```text
ReadyChanged {
    is_ready: bool
}
```

### 11.2 Server to client

```text
JoinAccepted {
    match_id: int
    player_id: int
    reconnect_token: String
    server_tick: int
    match_phase: int
}
```

```text
SnapshotFull {
    snapshot_id: int
    server_tick: int
    match_phase: int
    match_time_remaining_ms: int
    map_seed: int
    spawn_algo_version: int
    players: PlayerState[]
    consumed_set: PackedByteArray
    event_seq: int
}
```

```text
ObjectConsumed {
    server_tick: int
    event_seq: int
    object_id: int
    eater_player_id: int
    eater_hole_area_after: int
    eater_score_after: int
}
```

```text
PlayerEaten {
    server_tick: int
    event_seq: int
    predator_id: int
    prey_id: int
    predator_hole_area_after: int
    predator_score_after: int
    prey_eliminated: bool
}
```

```text
MatchPhaseChanged {
    server_tick: int
    phase: int
    phase_ends_at_tick: int
}
```

These messages are a Godot adaptation of the existing authoritative event schema in your docs. ([GitHub][3])

---

## 12. Game modes

### 12.1 Classic timed match

MVP game mode.

Rules:

- Match duration: default 120 seconds.
- Players consume objects.
- Highest score wins.
- No player elimination.
- Optional collision/overlap between players ignored.
- Objects do not respawn in MVP unless map feels too sparse.

### 12.2 Battle royale

Post-MVP.

Rules:

- Players consume objects to grow.
- Larger holes can consume smaller holes.
- Eaten players are eliminated.
- Last alive wins.
- If timer expires, largest alive player wins.

### 12.3 Practice mode

Useful for Godot rebuild.

Rules:

- Single player.
- No networking.
- Fixed map seed.
- Timer optional.
- Used for feel tuning, object tiers, camera, and VFX.

---

## 13. UI/UX requirements

### 13.1 Main menu

Buttons:

- Play Practice
- Host Private Match
- Join Private Match
- Settings
- Quit, desktop only

### 13.2 Join screen

Fields:

- Join code
- Nickname
- Error message area

Validation:

- Empty join code shows friendly error.
- Invalid code shows friendly error.
- Full match shows friendly error.
- Version mismatch shows friendly error.

### 13.3 Lobby

Show:

- Join code
- Player list
- Ready state
- Host marker
- Start button for host only
- Leave button

Rules:

- Host can start when at least one player is ready.
- Later: require all players ready, configurable.

### 13.4 In-game HUD

Show:

- Timer
- Score
- Size/radius
- Leaderboard top 3
- Current rank
- Optional minimap later

### 13.5 End screen

Show:

- Winner
- Final score
- Final size
- Ranking list
- Play again
- Return to menu

---

## 14. Performance requirements

### 14.1 Mobile targets

Target:

- 60 FPS on modern phones/tablets.
- 30 FPS acceptable baseline on older devices.
- 8-player LAN match stable.
- 20-player architecture possible later.

### 14.2 Performance rules

The game must:

- Use object pooling for VFX.
- Avoid per-frame allocations in core gameplay.
- Avoid networking individual props.
- Avoid networked rigidbody physics.
- Use simple collision shapes.
- Use spatial partitioning for server consumption checks.
- Use LOD or simplified visuals for large prop counts.
- Keep UI lightweight.
- Use deterministic world generation instead of network spawns for props.

### 14.3 Spatial grid

For consumption checks, use a 2D grid over the XZ plane.

Each cell contains object IDs.

Server query:

```text
for each player:
    find grid cells overlapping player consume radius
    test nearby unconsumed object IDs
    collect eligible candidates
    arbitrate winners
```

This is better than using Godot physics overlap checks for thousands of props, especially once you add multiplayer.

---

## 15. Phased delivery plan

### Phase 0 — Godot project foundation

Goal: create a clean Godot project structure.

Deliverables:

- Godot 4.6.x project created.
- Main scene router.
- Basic arena scene.
- Player hole scene.
- Camera rig.
- Input actions.
- Basic debug HUD.
- Export presets for desktop.

Acceptance criteria:

- Project opens cleanly.
- Player hole appears in arena.
- Keyboard movement works.
- Camera follows player.

### Phase 1 — Single-player gameplay feel

Goal: rebuild the core game loop before networking.

Deliverables:

- Touch/keyboard movement.
- Acceleration/deceleration.
- Area-based growth.
- Consumable prop definitions.
- Local object consumption.
- Suction/drop VFX.
- Score and timer HUD.
- End screen.

Acceptance criteria:

- Player can consume eligible objects.
- Ineligible objects are not consumed.
- Radius grows using area formula.
- Camera zooms as radius increases.
- 2-minute practice match is fun enough to replay.

[1]: https://raw.githubusercontent.com/bovinemagnet/corn-hole/main/README.md "raw.githubusercontent.com"
[2]: https://godotengine.org/ "Godot Engine - Free and open source 2D and 3D game engine"
[3]: https://github.com/bovinemagnet/corn-hole/blob/main/docs/prd-1.md "corn-hole/docs/prd-1.md at main · bovinemagnet/corn-hole · GitHub"
[4]: https://raw.githubusercontent.com/bovinemagnet/corn-hole/main/Assets/Scripts/HolePlayer.cs "raw.githubusercontent.com"
[5]: https://raw.githubusercontent.com/bovinemagnet/corn-hole/main/Assets/Scripts/NetworkManager.cs "raw.githubusercontent.com"
[6]: https://raw.githubusercontent.com/bovinemagnet/corn-hole/main/Assets/Scripts/ObjectSpawner.cs "raw.githubusercontent.com"
[7]: https://raw.githubusercontent.com/bovinemagnet/corn-hole/main/Assets/Scripts/MatchTimer.cs "raw.githubusercontent.com"
[8]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html "Exporting for dedicated servers — Godot Engine (stable) documentation in English"
[9]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html "Exporting for iOS — Godot Engine (stable) documentation in English"
[10]: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html "High-level multiplayer — Godot Engine (stable) documentation in English"
[11]: https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html "MultiplayerSpawner — Godot Engine (stable) documentation in English"
[12]: https://docs.godotengine.org/en/4.4/classes/class_multiplayersynchronizer.html "MultiplayerSynchronizer — Godot Engine (4.4) documentation in English"
[13]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html "Exporting for Android — Godot Engine (stable) documentation in English"
[14]: https://docs.godotengine.org/en/stable/classes/class_touchscreenbutton.html "TouchScreenButton — Godot Engine (stable) documentation in English"
[15]: https://raw.githubusercontent.com/bovinemagnet/corn-hole/main/Assets/Scripts/CameraFollow.cs "raw.githubusercontent.com"
[16]: https://raw.githubusercontent.com/bovinemagnet/corn-hole/main/Assets/Scripts/ConsumeEffect.cs "raw.githubusercontent.com"
[17]: https://raw.githubusercontent.com/bovinemagnet/corn-hole/main/docs/overview_rules.md "raw.githubusercontent.com"
[18]: https://raw.githubusercontent.com/bovinemagnet/corn-hole/main/docs/consumedSet_sync.md "raw.githubusercontent.com"
