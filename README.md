# RELAY

A third-person, endless, forward-moving action-parkour game made in **Godot 4.7.2** (GDScript only).
You are a courier carrying a sealed Message down **the Long Road**. Every zone ends at a relay
station. When you die, your body — and everything you carried — stays where it fell, and a new
courier of your bloodline wakes at the last relay fire.

Placeholder art only (primitive meshes), procedurally generated placeholder sounds.

---

## Running the game

### From the Godot editor
1. Install Godot **4.7.x** (standard build, not .NET) — e.g. from <https://godotengine.org/download/linux/>
   or the official GitHub releases (`Godot_v4.7.2-stable_linux.x86_64.zip`).
2. Open Godot, *Import* → select this folder's `project.godot`.
3. Press **F5** (Run Project). The main scene is `res://ui/main_menu.tscn`.
   - `res://world/game_world.tscn` is the game itself (F6 on that scene starts a road directly).
   - `res://world/test_course.tscn` is the movement test course (also in the main menu).

From a terminal:
```bash
godot --path /path/to/relay
```

### The exported Linux binary (Ubuntu, x86_64)
The export lives at `build/linux/relay.x86_64` (the `.pck` is embedded in the binary).
```bash
cd build/linux
```
```bash
chmod +x relay.x86_64
```
```bash
./relay.x86_64
```
Command-line shortcuts (also work in the exported build): `./relay.x86_64 -- --new-road`,
`-- --continue`, `-- --test-course`.
To re-export it yourself (export templates for 4.7.2 must be installed):
```bash
godot --headless --path . --export-release "Linux" build/linux/relay.x86_64
```

Saves and settings are JSON files in `~/.local/share/godot/app_userdata/RELAY/`
(`relay_save.json`, `relay_settings.json`).

### Tests
```bash
godot --headless --path . --script res://tests/run_tests.gd
```
Prints `PASS`/`FAIL` per test and exits with code 1 on any failure. Filter with
`-- --only=<substring>` (e.g. `-- --only=test_zones`).

Developer tools (not part of the game):
- `tools/build_content.gd` — regenerates the placeholder model scenes and all zone modules.
- `tools/check_all.gd` — loads every script/scene/resource to surface parse errors.
- `tools/traverse_check.gd` — a bot walks every module of every biome from entry to exit (all 51 pass).
- `tools/screenshot.gd`, `tools/menu_shot.gd` — screenshots (need a display, e.g. `xvfb-run`).
- `tools/setup_input.gd` — writes the default input map into `project.godot`.

---

## Controls

| Action | Keyboard + mouse | Gamepad |
|---|---|---|
| Move | W A S D (or arrows) | Left stick (light tilt = walk) |
| Look / orbit camera | Mouse | Right stick |
| Jump / climb / pull up | Space | A |
| Sprint (uses stamina) | Shift (hold) | L3 or LB (hold) |
| Crouch / slide (crouch while sprinting) / drop from ledge | C or Ctrl | B |
| Walk | Alt (hold) | — (light stick tilt) |
| Interact (loot, pay toll, station) | E | X |
| Attack: tap = light, hold = charged | Left mouse | RT |
| Aim sling (then Attack to throw) | Right mouse (hold) | LT (hold) |
| Dodge roll (i-frames, stamina) | Q | RB |
| Use selected item (bandage/food, wield, ready throwable) | F | Y |
| Drop selected item | G | D-pad down |
| Select next / previous carry slot | Mouse wheel, 2 / 1 | D-pad right / left |
| Pause | Esc | Start |

Parkour is mostly automatic: run into obstacles under 1.2 m to **vault**; jump at a climbable ledge
to **grab** it (left/right to **shimmy**, Jump or forward to **pull up**, Crouch to drop); sprint and
jump along a blue "runnable" wall to **wall-run** (Jump again to kick off). All bindings can be
changed in *Settings → Key bindings*.

## Debug keys and cheats

| Key | Effect |
|---|---|
| F3 | Debug overlay: FPS, seed, zone, biome, time, weather, difficulty, courier state, nearest enemy states (labels over enemies too) and the scent trail drawn in the world |
| F5 | God mode on/off |
| F6 | Spawn an enemy in front of you (cycles hound pack → scavenger → toll-keeper → rider → watchtower) |
| F7 | Force a storm (press again to clear it) |
| F8 | Teleport to zone N (type a number, Enter) |
| F9 | Jump to the next zone |

---

## What every phase delivered

1. **Movement core** — `player/courier.gd` (walk 4 / run 7 / sprint 10 m/s, 1.4 m jump, 0.12 s coyote + buffer, 1 s slide, vault < 1.2 m, ledge grab ≤ 2.2 m with shimmy/pull-up, 1.2 s wall-run, stamina + exhaustion, fall damage > 6 m / death ≥ 15 m), all numbers in `player/movement_tuning.tres`; spring-arm orbit camera with sprint FOV kick; input map for KB+M and gamepad; the test course.
2. **Death, respawn and corpses** — health (no regen), bandages/food, carry slots (base 4, weight 1–3, 5 % slower per slot past 2, Message always 1 slot), item resources, 10 trait resources, name generator, death card, CorpseData + corpse body with a flag, respawn as a new courier at the last relay, max 30 corpses, Roll of the Fallen.
3. **Zone generation** — module scenes with Entry/Exit sockets and slot markers, seeded generator (`world_seed + zone_index`), winding 220–320 m zones with guaranteed station/shelter/loot/encounter/alternate route, edge blocking, prev/current/next streaming, floating origin, endless progression, runtime navmesh baking.
4. **Enemies part 1** — state machine (IDLE/PATROL/SUSPICIOUS/CHASE/ATTACK/SEARCH/RETURN), vision cone + raycast LOS, sound events, hounds with ring-buffer scent tracking (water erases scent, standing still strengthens it), scavengers that loot corpses every 45 s and drop what they stole.
5. **Enemies part 2 and combat** — blade light/charged, sling throwing (stones, noise-maker, smoke pot, caltrops, fire pot), dodge roll, toll-keeper (pay / sneak / fight), watchtower (sweeping spotlight, bell alarm, lantern can be shot out for 30 s), rider (fast, slow-turning, predictive, crashes into trees).
6. **Weather and day/night** — storm fronts that roll in from behind, rain + low visibility, lightning at the highest exposed point with a 1.5 s warning, wind gusts mid-air, shelters, flash floods, dust storms; a 12-minute day/night cycle that changes AI sight and scent.
7. **Biomes and difficulty** — Greywood Forest, Ruined Highway, Storm Plains, Floating Ruins, Salt Desert (8–11 modules each + station, distinct palettes and hazards), difficulty curves in a Resource, Long Road +1 loop every 50 zones.
8. **Stations, upgrades, momentum, Message** — rest/stash/upgrade bench (Bed, Forge, Kennel, Signal Mirror), materials, momentum 0–5 with its bonuses, 8 Message fragments + Seal Breaks card + Message page.
9. **UI, audio, settings, save, polish** — full HUD with compass, all menus, settings with rebinding, procedural audio with overridable files, Master/Music/SFX buses, JSON save/load, Low/Medium/High graphics presets.
10. **Debug tools, balancing and export** — F3 overlay with scent visualisation and enemy states, cheats, a balancing pass, Linux export.

Detailed notes are in `PROGRESS.md`; every design decision is in `DECISIONS.md`.

## Simplified or skipped (see DECISIONS.md for the reasoning)
- **Art & animation**: primitives with procedural "animation" (lean, limb swing, roll spin). No skeletal animation.
- **Scavenger theft only happens while the corpse's zone is loaded** (no offline simulation).
- **Riders steer directly** (no navmesh); they're meant for open ground anyway.
- **Hounds don't jump gaps**; on Floating Ruins they're confined to their platform.
- **Lightning targets** are sampled (courier + 10 random ground points) rather than an exhaustive scan.
- **Flash floods** raise the existing water volumes of a zone; there is no fluid simulation.
- **Sun glare** for Night-eyed couriers is an exposure + far-blur effect.
- **The loot window and station menu don't pause** the game — enemies keep moving.
- **Music** is a single generated drone loop.

## Known bugs / limitations
- The CharacterBody3D can catch on the corners of rotated boxes (e.g. car wrecks); jumping frees it.
- Ledge detection uses raycasts: very thin or sloped "climbable" geometry may not be grabbable.
- Toll-keepers stand on open banks: you can provoke them by walking around them while they watch (intended), but their "block" is a rule, not a physical wall.
- Very long sessions keep every zone's layout in a cache (small, but it grows with distance travelled).
- In headless/no-audio environments Godot prints an ALSA warning; harmless.

## Replacing placeholder models with your own .glb files
Every visual lives in its own scene; logic never references mesh nodes except where noted.

| Object | Scene to edit | Notes |
|---|---|---|
| Courier | `player/courier_model.tscn` | Replace the mesh children with your .glb instance. `courier_model.gd` receives `set_pose(state, speed, delta, wall_side)` — drive your AnimationPlayer/AnimationTree from it (states: move, crouch, air, slide, vault, hang, climb, wallrun, roll, attack, aim, dead). Keep a node named `Scarf` or remove `set_scarf_color`. Model faces **-Z**, origin at the feet. |
| Camera | `player/camera_rig.tscn` | Spring arm length etc. are exported on `camera_rig.gd`. |
| Corpse | `world/corpse/corpse_model.tscn` | Keep a mesh named `Flag` if you want the per-courier flag colour. |
| Relay station | `world/station/station_model.tscn` | Keep the Marker3D nodes `FirePoint`, `RestPoint`, `StashPoint`, `BenchPoint`, `SpawnPoint`. Colliders (StaticBody3D) live here too. |
| Hound / Scavenger / Toll-keeper / Rider | `enemies/<type>/<type>_model.tscn` | Faces -Z, origin at feet. Toll-keeper: keep `WeaponArm` and `WeaponArm/Mace` for the telegraphed slam (optional). |
| Watchtower | `enemies/watchtower/watchtower_model.tscn` | Keep `LanternPoint` and `BellPoint` markers. |
| Items | `items/pickup_model.tscn`, `items/loot_cache_model.tscn`, `items/loot_bag_model.tscn` | Pickup tint uses a mesh named `Mesh`. |
| Storm front | `world/weather/storm_front_model.tscn` | Keep a mesh named `Wall` for the colour change. |
| Zone modules | `world/modules/<biome>/*.tscn` | Edit freely in the editor: keep the root `ZoneModule` script, the `Entry`/`Exit` markers and the `Slots` markers. Tag colliders with groups `climbable` / `runnable`. |

Note: `tools/build_content.gd` regenerates these scenes from code and **overwrites** them — don't run
it after you start editing the scenes by hand.

To replace sounds, drop files named after the sound ids into `res://audio/sfx/` (e.g.
`footstep_dirt.ogg`, `bell.wav`, `thunder_warning.ogg`, `howl.ogg`, `wind_loop.ogg`, `music_loop.ogg`);
see the list at the top of `autoload/audio.gd`.

## Project layout
```
autoload/   game.gd (state), events.gd (signal bus), save.gd, settings.gd, audio.gd, input_defaults.gd, game_config.tres
player/     courier.tscn/.gd, courier_model.tscn, camera_rig.tscn, movement_tuning.tres, courier_actions/combat.gd, scent_trail.gd
traits/     trait.gd + 10 trait .tres            items/   item defs, inventory, pickups, caches, projectiles, effects
enemies/    enemy_base.gd, perception.gd, spawner, hound/, rider/, tollkeeper/, watchtower/, scavenger/
world/      game_world.tscn, test_course.tscn, zone_gen/, modules/, biomes/, station/, weather/, corpse/
ui/         hud, menus, death card, station menu, settings, debug overlay
tests/      run_tests.gd + suites            tools/   content builders and dev tools
```
