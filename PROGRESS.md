# RELAY — Progress

Engine: Godot 4.7.2 stable (Linux x86_64), Jolt Physics.

## Status
- [x] Phase 1 — Movement core
- [x] Phase 2 — Death, respawn and corpses
- [ ] Phase 3 — Zone generation
- [ ] Phase 4 — Enemies part 1
- [ ] Phase 5 — Enemies part 2 and combat
- [ ] Phase 6 — Weather and day/night
- [ ] Phase 7 — Biomes and difficulty
- [ ] Phase 8 — Stations, upgrades, momentum, Message
- [ ] Phase 9 — UI, audio, settings, save, polish
- [ ] Phase 10 — Debug tools, balancing, export

## Log

### Phase 1 — Movement core (done)
- `player/courier.gd`: walk/run/sprint, jump (coyote + buffer), slide, vault/mantle, ledge grab + shimmy + pull-up, wall-run + wall-jump, dodge roll (i-frames), stamina with exhaustion, fall damage (>6 m hurts, >=15 m kills), footstep noise events, scent trail.
- `player/movement_tuning.tres`: every movement number. `player/camera_rig.tscn`: spring-arm orbit, sprint FOV kick, aim mode, shake.
- Input map for KB+M and gamepad (`autoload/input_defaults.gd`, written into project.godot by `tools/setup_input.gd`).
- `world/test_course.tscn`: every obstacle type. Tests: movement suite (speeds, jump height, vault, climb, slide, wall-run, fall damage) + test-course smoke test.

### Phase 2 — Death, respawn and corpses (done)
- Health (no regen), bandage/food use (timed), carry slots (`items/carry_inventory.gd`, weight 1-3, pouch for materials, load penalty 5%/slot past 2), item defs as .tres, pickups, drop, loot caches, loot window UI.
- 10 traits as Resources (`traits/*.tres`), name generator, CourierData. Death: slow-mo + death card, CorpseData record (zone-local pos), corpse body with flag, respawn as a new courier at the last station (`world/death_flow.gd`). Corpse cap 30 (oldest decays).
- Relay station scene (hut + signal fire, activation area, autosave). Roll of the Fallen page.
- `tools/build_content.gd` generates all placeholder visual scenes (`*_model.tscn`).
