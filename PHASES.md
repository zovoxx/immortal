# RELAY — Build Phases

1. **Movement core** — Courier controller (walk/run/sprint/jump/slide/vault/climb/wall-run), stamina, third-person camera, input map (KB+M and gamepad), hand-built test course with every obstacle type, fall damage.
2. **Death, respawn and corpses** — Health, death card, relay station scene (activation + autosave), respawn as new courier, corpse spawning and looting, carry slots, basic items, courier traits, name generator, Roll of the Fallen.
3. **Zone generation** — Module system with sockets, seeded generator, 6+ Greywood Forest modules, zone streaming (prev/current/next), stations at zone ends, endless progression.
4. **Enemies part 1** — Enemy state machine base, sight and sound detection, Hounds with scent tracking, Scavengers stealing from corpses, per-zone runtime navmesh baking.
5. **Enemies part 2 and combat** — Blade, sling, throwables, dodge roll, Toll-keeper (fight/pay/sneak), Watchtower (spotlight + alarm), Rider.
6. **Weather and day/night** — WeatherManager, storm front, lightning with warnings, wind gusts, shelters, day/night cycle and its AI effects.
7. **Biomes and difficulty** — 5 biomes with modules and palettes, biome hazards (floods, dust, void), difficulty curves, Long Road +1 loop.
8. **Stations, upgrades, momentum, Message** — Stash, upgrade bench, materials, momentum, Message fragments + menu page.
9. **UI, audio, settings, save, polish** — Full HUD, all menus, settings with rebinding, full save/load, procedural audio, Low graphics preset.
10. **Debug tools, balancing, export** — F3 overlay, cheats, balancing pass, Linux export to build/linux/relay.x86_64.

Every phase ends with: headless parse check, automated tests (`tests/run_tests.gd`), git commit.
