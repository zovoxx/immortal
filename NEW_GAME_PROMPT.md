# One-shot Claude Code prompt — EMBERLINE (a successor to RELAY)

Paste everything below the line into Claude Code in an **empty folder** on Ubuntu.

---

You are building a complete, playable 3D game from scratch in **Godot 4 (latest stable 4.x, standard build, GDScript only, no C#, no plugins)** that runs on **Ubuntu x86_64**. Work autonomously from start to finish in this one session. Do not stop to ask me questions: when something is unclear, make the decision yourself, write it in `DECISIONS.md`, and keep going.

## 0. Setup (do this first)
- Check for Godot with `godot --version`. If it is missing, download the latest stable 4.x Linux x86_64 binary and matching export templates from the official GitHub releases, put the binary at `~/.local/bin/godot`, and install the templates in `~/.local/share/godot/export_templates/<version>/`.
- Use **Jolt Physics** for 3D. Use Forward+ rendering, with a Low graphics preset that runs well on integrated Intel/AMD GPUs.
- `git init` the project and commit at the end of every phase.
- Write `PHASES.md` (the plan below), `DECISIONS.md` (every choice you make without asking) and `PROGRESS.md` (what each phase actually delivered). Keep all three up to date.

## 1. The game
**EMBERLINE** is a third-person, endless, forward-moving action-parkour run. You play a **Lantern-runner** carrying a living Ember down **the Dark Road**, a chain of dead beacons. Each zone ends at a beacon. Lighting it saves your progress. When you die, your body and everything you carried stay where you fell, and the next runner of your **lineage** wakes at the last lit beacon with new random traits. They can run back and take the gear off the body, if the enemies haven't stripped it first.

Keep the depth and adrenaline of a tense survival run: parkour, stealth, enemies that track you, weather that hunts you, permadeath with consequences. **The two design goals for this version are:**
1. **Clarity.** The player always knows what hit them, from where, for how much, and what they could have done instead. No death should feel unfair or confusing.
2. **Satisfaction and "one more run".** Every action has juicy feedback, every run gives progress, and short, medium and long-term goals overlap so there is always a reason to start one more run.

Use placeholder art only: primitive meshes, but with strong silhouettes, a clear colour language and emissive accents. Generate all sound procedurally at startup. Any file at `res://audio/sfx/<id>.ogg|wav` must override its generated sound. Put every visual in its own `*_model.tscn` so I can drop in .glb models later.

## 2. Core systems (keep all of this complexity)
**Movement.** Walk 4, run 7 and sprint 10 m/s, with stamina and exhaustion. Add a 1.4 m jump with coyote time and jump buffering, a slide, auto-vault under 1.2 m, mantling, ledge grab with shimmy and pull-up, wall-run on tagged walls with a wall-kick, and a dodge roll with i-frames. Fall damage starts above 6 m and kills at 15 m or more. Put every number in a `movement_tuning.tres` Resource. Use a spring-arm orbit camera with an FOV kick when sprinting. Support keyboard + mouse and gamepad, with full rebinding.

**Health and items.** Health does not regenerate; bandages and food restore it. Add carry slots (base 4, items weigh 1–3; you get slower when overloaded). The Ember always takes one slot and passes to the next runner. Materials go in a weightless pouch. Add 10 traits (positive and negative), a name generator, and a **Lineage Book** that lists every dead runner.

**Corpses.** Each corpse keeps its inventory and gets a flag in that runner's colour. Keep at most 30 corpses. Scavenger enemies loot the newest corpse after a while, so going back fast pays off.

**Zones.** Build zones from hand-made modules with Entry and Exit sockets, using a seeded generator (`world_seed + zone_index`). Zones are 220–320 m of winding road. Every zone guarantees a beacon, a shelter, loot, an encounter and an alternate route. Stream the previous, current and next zones, use a floating origin and bake the navmesh at runtime. Progression never ends.

**Enemies.** All enemies share a state machine (IDLE / PATROL / SUSPICIOUS / CHASE / ATTACK / SEARCH / RETURN), a vision cone with line-of-sight raycasts, and sound events. The roster:
- **Hounds**: track your scent trail. Water erases the trail and standing still makes it stronger.
- **Scavengers**: steal from corpses.
- **Gatekeepers**: pay, sneak past or fight.
- **Watchtowers**: a sweeping spotlight and an alarm bell. Their lantern can be shot out.
- **Riders**: fast but slow to turn. They predict your path and crash into trees.

**Combat.** A blade with a light tap and a charged hold, a sling with throwables (stones, noise-maker, smoke pot, caltrops, fire pot), and the dodge roll.

**Weather and time.** Storm fronts roll in from behind you. Lightning hits the highest exposed point. Add wind gusts, flash floods, dust storms and shelters. A 12-minute day/night cycle changes how far enemies see and how well they smell.

**Biomes.** Five biomes, each with its own palette, hazards and 8+ modules: forest, ruined highway, storm plains, floating ruins and salt desert. Put the difficulty curves in a Resource and add a +1 loop every 50 zones.

**Beacons.** Each beacon offers rest, a shared stash and an upgrade bench where you spend materials on permanent upgrades. Add a momentum meter from 0 to 5, and Ember lore fragments that unlock at milestones.

## 3. NEW: Damage clarity (top priority, make it excellent)
- **Telegraphs on every enemy attack.** Show a wind-up pose, a bright emissive flash on the weapon or jaws, and a rising audio cue at least 0.4–0.6 s before the hit. Melee lunges and slams project a red ground decal showing their exact reach. Watchtower spotlights tint yellow while suspicious and red once they've spotted you, with a sound sting for each change.
- **Directional damage indicators.** A red arc around the screen centre points to where the hit came from and fades over 1 s. Off-screen threats that are chasing you show small pulsing chevrons on the screen edge.
- **The health bar uses chip damage.** The lost portion first turns white, then drains after 0.5 s. Healing fills in green with a sparkle. Show a numeric HP value next to the bar. The bar shakes when you are hit.
- **Floating damage numbers** on enemies (white for normal hits, yellow for charged, orange for critical hits) and on the player (red), with a toggle in Settings.
- **Hit reaction.** A short knockback, a 0.6 s invulnerability window after a hit (the runner flickers), a hurt grunt that varies by damage type, and a screen-edge colour that matches the damage type: red for physical, blue-white for lightning, cyan for drowning, orange for fire.
- **Low-health state.** Below 30 % add a heartbeat sound, a pulsing vignette, slightly muffled audio and desaturation. All of this clears with a satisfying "breath" sound when you heal.
- **Fall-damage preview.** While airborne, show a landing marker on the ground that turns orange when the landing will hurt and red when it will kill. Pressing Dodge just before landing does a **landing roll** that halves the fall damage, with a satisfying thud.
- **Lightning warning.** Show a crackling ground circle and an aura on any exposed target 1.5 s before the strike, with an unmistakable sound.
- **Death recap.** The death card shows the cause, the attacker, the last 5 damage events (source, amount, time) and a one-line tip ("Hounds lose your scent in water"). Then the camera replays the final 3 seconds in slow motion from a cinematic angle.
- **Enemy health** appears as a small bar over the enemy once damaged. When you strike, enemies flash white, stagger and show clear stun stars when stunned.

## 4. NEW: Satisfaction and game feel ("juice")
Put every parameter below in a `game_feel.tres` Resource. Settings must have sliders for screen-shake intensity, hit-stop and flashes, plus a "reduce flashing" accessibility toggle.
- **Hit-stop** on every melee hit you land: 50 ms for light hits, 90 ms for charged hits, 140 ms for kills. Add a camera punch toward the hit direction, spark and dust particles, and a crunchy layered hit sound.
- **Kills** knock enemies back with a physics-tumble death, burst them into embers and drop loot that gets **magnetised** to you with a rising chime. When you kill the last enemy of an encounter, add a 0.4 s slow motion and an "AREA CLEAR" sting.
- **Perfect dodge.** Dodging within 0.15 s of a hit landing triggers 0.5 s of slow motion, a blue flash and a stamina refund, and fills the Flow meter.
- **Parry.** Tapping Attack right as an enemy's telegraph flash peaks staggers the enemy, makes a distinct metallic "ting" and opens a riposte that does triple damage.
- **The Flow meter replaces momentum and powers it.** Chaining vault → wall-run → slide → jump without stopping or getting hit raises Flow. Each level adds speed lines, a warmer camera grade, a louder music layer, rising pitch on footsteps and a small speed bonus. Taking damage drains one level, with a glass-crack sound.
- **Trick callouts.** Short stylish text pops up for parkour chains ("WALL-KICK", "LONG SLIDE", "CLOSE CALL" when lightning or a rider just misses you, "GHOST" when you pass a watchtower unseen). They award Flow and score.
- **Run score and style.** A score built from distance, tricks, kills, stealth passes and corpse recoveries, with a combo multiplier. Beacons show a run split time with a **personal best** comparison: green when you're ahead, red when you're behind.
- **Beacon arrival celebration.** The beacon ignites in a column of light. Show a summary of the zone (time, score, tricks, kills, damage taken) and play a warm musical resolution.
- **Corpse recovery payoff.** Reaching your previous body shows a gold beam on it from far away. Recovering it plays a special "Lineage Restored" sting, returns its items with a flourish and grants bonus materials.
- **Pickups** bob, glow and pop with a small burst. Rare items get a beam and a distinct chime.
- **Responsive audio.** Footsteps change by surface, wind rushes when you're fast, and the music has layers that rise with danger (chase, storm) and Flow.

## 5. NEW: Addictive loop (always something to chase)
- **Short-term (seconds):** Flow chains, combos, trick callouts, perfect dodges, parries.
- **Medium-term (one run):** **3 Bounties per run**, picked at the beacon from a random set ("Kill 4 hounds without being hit", "Clear a zone without sprinting", "Light a beacon at Flow 5"). Each one pays materials and Lineage XP when completed.
- **Long-term (across runs):** **Lineage XP and lineage level.** Each level unlocks something: a new starting trait pool, a cosmetic scarf or lantern colour, a new throwable, a new upgrade on the bench, or a new biome variant. A Lineage tree screen shows what comes next.
- **Daily Road.** A fixed daily seed with its own local leaderboard of your best attempts.
- **Ghost runner.** A translucent ghost of your best run through the current zone races you (optional toggle).
- **"Next unlock" bar.** It shows on the death card and the main menu ("320 XP to unlock the Fire Lantern"), so death always ends on a hook. The Restart button is focused by default, and a new run starts in under 2 seconds.
- **Achievements**: 25 local ones with toast pop-ups.

## 6. UI, save and settings
- A HUD with a health bar (chip damage), stamina, the Flow meter, a compass with beacon/corpse/threat markers, carry slots, bounties, the score and the split timer. Keep it clean and readable.
- Menus: main menu, pause, settings, death card, beacon menu, Lineage Book, Lineage tree, achievements and Daily Road. Build them in code with one shared UI theme, big readable fonts and full gamepad navigation.
- Settings: volume buses (Master/Music/SFX), rebinding, mouse sensitivity, invert Y, FOV, the graphics presets Low/Medium/High, the game-feel sliders, damage-number and ghost toggles, and colour-blind-friendly damage colours.
- Save the game and settings as JSON in `user://`, with autosave at each beacon and on quit.

## 7. Debug, tests and export
- **F3 debug overlay**: FPS, seed, zone, biome, weather, Flow, enemy states drawn over the enemies, and the scent trail drawn in the world. Cheats: god mode, spawn an enemy, force a storm, teleport to a zone, skip a zone.
- **Headless tests** at `tests/run_tests.gd`, run with `godot --headless --path . --script res://tests/run_tests.gd`. They print PASS/FAIL and exit with code 1 on any failure. Cover movement numbers, damage and i-frames, chip damage, fall preview thresholds, hit-stop timing, Flow gain and loss, bounty completion, XP and unlocks, zone generation determinism, save/load round-trips and corpse persistence.
- **Tools.** A `tools/check_all.gd` that loads every script, scene and resource to catch parse errors. A traversal bot that walks every module of every biome from entry to exit and must pass for all of them. A screenshot tool that works under `xvfb-run`.
- **Linux export** to `build/linux/emberline.x86_64` with the `.pck` embedded. Command-line flags `--new-run`, `--continue` and `--daily`.

## 8. Phases (do all of them, in order, without stopping)
1. Movement core + test course + camera + input
2. Health, damage-clarity foundation (chip bar, directional indicators, hit reaction, fall preview, landing roll), death recap, corpses, respawn, traits, the Lineage Book
3. Zone generation + streaming + beacons
4. Enemies part 1 (state machine, perception, hounds, scavengers) with full telegraphs
5. Enemies part 2 + combat + **all the game-feel juice** (hit-stop, parry, perfect dodge, kills, magnet loot)
6. Weather and day/night, with clear hazard warnings
7. Biomes and difficulty
8. Flow meter, trick callouts, score, splits and personal bests, bounties, Lineage XP and the unlock tree, achievements, Daily Road, ghost runner
9. Full UI, layered music and audio, settings, accessibility, save/load
10. Debug tools, a balancing pass, the traversal bot, export, and the README

**Every phase ends with:** the headless parse check (`tools/check_all.gd`) with zero errors, all tests passing, a short entry in `PROGRESS.md`, and a git commit named "Phase N: …". If a test fails, fix the code. Never delete or skip a test to get a pass.

When you finish, write `README.md` with: how to run the game from the editor and from the exported binary on Ubuntu, the full controls table (keyboard and gamepad), the debug keys, what each phase delivered, what you simplified and why, known bugs, and how to replace the placeholder models and sounds. Then run the exported binary once under `xvfb-run` for 10 seconds to confirm it starts without errors, and report the result.
