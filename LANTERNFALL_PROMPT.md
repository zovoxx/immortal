# One-shot Claude Code prompt: LANTERNFALL (Godot 2D, Ubuntu)

This is a Godot 4 rebuild of Lanternfall (the web game in `zovoxx/Ne`) for Ubuntu desktop, with clearer damage feedback and more satisfying game feel.
Paste everything below the line into Claude Code in an **empty folder** on Ubuntu.

---

You are building a complete, playable **2D top-down action roguelike** called **LANTERNFALL** from scratch in **Godot 4 (latest stable 4.x, standard build, GDScript only, no C#, no plugins)**. It is a desktop game for **Ubuntu x86_64**, played with keyboard + mouse or a gamepad. Work autonomously from start to finish in this one session. Do not stop to ask me questions: when something is unclear, decide yourself, write the decision in `DECISIONS.md`, and keep going.

This is a Godot rebuild of my existing web game Lanternfall. If `https://github.com/zovoxx/Ne` is reachable, clone it into a scratch folder and use it as the reference for names, content and tuning numbers (especially `src/config/tuning.ts`, `src/game/boons/patrons.ts`, `src/game/enemies/*`, `src/game/rooms.ts` and `src/game/meta.ts`). Do not copy its TypeScript; rebuild everything in GDScript. If it is not reachable, everything you need is described below.

## 0. Setup (do this first)
- Check for Godot with `godot --version`. If it is missing, download the latest stable 4.x Linux x86_64 binary and matching export templates from the official Godot GitHub releases. Put the binary at `~/.local/bin/godot` and the templates in `~/.local/share/godot/export_templates/<version>/`.
- Use the Forward+ renderer with a Low preset (Compatibility-like settings, no glow) for integrated GPUs. Base resolution 1920×1080, stretch mode `canvas_items`, aspect `expand`. F11 toggles fullscreen. Target 60 FPS, or 144 Hz on fast machines, with a fixed 60 Hz simulation.
- `git init` the project and commit at the end of every phase.
- Keep three files up to date: `PHASES.md` (the plan below), `DECISIONS.md` (every choice made without asking) and `PROGRESS.md` (what each phase delivered).
- **Architecture.** Keep the game simulation (rooms, combat, enemies, boons, run state) separate from presentation (sprites, FX, audio, UI), communicating through a signal bus autoload. That way a **headless bot can play full runs** for testing. Put every feel and balance number in Resources (`tuning.tres`, `game_feel.tres`), never hard-coded.

## 1. The game
You are **Wren, the last Kindler**, descending four depths to take back a stolen sun. Each run is a chain of rooms. You clear a room, collect its reward, then choose your next door from 2–3 options, where each door shows its reward in advance. If you die, you return to **the Wick**, the hub between runs. There you spend the **Embers** you earned on permanent unlocks, and one new line of the story is revealed. Runs are short (20–35 minutes for a full clear), fast, and every build feels different.

Use placeholder art only, generated in code: bold, readable vector-style sprites drawn with `_draw()` or baked into textures at startup. Each sprite needs a strong silhouette, a dark outline and an emissive "lantern glow" accent. Every sprite gets an automatic white hit-flash silhouette (via a shader). Load every sprite through one central asset map (`res://render/assets.gd`) keyed by id (e.g. `cinderling`, `w_pike`, `boss_regent`). Dropping a PNG at `res://sprites/<id>.png` must replace the procedural sprite. Generate all audio procedurally (SFX and layered music). Any file at `res://audio/<id>.ogg|wav` must override its generated sound.

## 2. Content (keep all of this depth)
**Player.** 60 HP, quick acceleration, an attack combo, a **dash** with i-frames (1 charge, short cooldown, dash-cancels attack recovery, dash-attack window), a **Special** and a **Sigil** cast (2 charges, a delayed area blast that roots enemies). Inputs are buffered for 150 ms. With a mouse you aim at the cursor, with a soft snap to nearby enemies. With a gamepad you aim with the right stick, falling back to a smart auto-aim cone in the movement direction. Death Defiance revives you once per run, and the Wick can add more.

**5 weapons.** Each has its own combo, frame data (windup / active / recovery, damage, range or arc, power, knockback, lunge), Special and dash-attack, plus 3 **weapon forges** each.
- **Kestrel Fangs**: twin blades, a fast 4-hit combo with a spin finisher, backstab crits, and thrown knives as the Special.
- **Moonreach**: a crescent pike, long thrusts with tip crits, and a whirl as the Special.
- **Anvilheart**: a molten maul, slow armor-breaking swings, and a charged fissure as the Special.
- **Vesper Bow**: quick shots, a perfect-release power shot, and starfall as the Special.
- **Sunwheel Halo**: a returning chakram that cuts on the way out and on the way back.

**8 patron Lights** with about 88 boons in total. Boon slots are attack, special, cast, dash, revenge (triggers when you're hit), passive and legendary. Common, rare, epic and legendary rarities change the numbers. Add **18 duo boons** for pairs of patrons.
- **Ashka, the Kiln**: Burn, stacking fire damage.
- **Ilvra, the Rime Widow**: Chill → Freeze → Shatter.
- **Korr, the Thunder Ram**: chaining lightning.
- **Maelis, the Deep Tide**: knockback and wall slams.
- **Solenne, the Dawnmother**: radiant marks and critical hits.
- **Oruun, the Hollow Eye**: Hex, curses that spread on death.
- **Siffra, the Running Wind**: speed, extra dash charges and wind blades.
- **Brakka, the Thornmother**: Bleed stacks that burst on heavy hits.

Each patron has a colour, a portrait and short greeting lines.

**4 depths**, each with its own palette, floor style, hazards and room layouts:
1. **The Ashen Gardens**
2. **The Drowned Archive**
3. **The Clockwork Foundry**
4. **The Starless Crown**

Each depth is a short corridor of rooms. The room types are combat (waves with spawn telegraphs), elite, guardian (mini-boss), shop, spring (heal), **ordeal** (altar, gauntlet or wager) and a boss at the end. Enemy HP and damage scale by depth.

**32 enemies**, 8 per depth, each with a clear role (rusher, ranged, support, bomber, burrower, summoner, tank). Reference roster:
- **Depth 1:** Cinderling, Bramblehorn, Spitbloom, Ashwisp, Burrowmaw, Kindlepod, Thorn Warden, Grubmother.
- **Depth 2:** Inkshade, Lanternist, Twinned Scribe, Tidecleric, Hookjaw, Slurry, Echo, Glimmerjelly.
- **Depth 3:** Rivet Hound, Coil Sentry, Pylon, Ironclad, Forge Mortar, Bellwether, Gyrosaw, Slagcrawler, Sparkmite.
- **Depth 4:** Voidcaller (with Void Imps), Mirror Knight, Gravewell Seer, Prism, Wraith Lancer, Aegis Herald, Hexer, Null Shard.

**10 combinable elite modifiers:** Hasted, Shielded, Volatile, Blazing, Vampiric, Brood, Hulking, Blinking, Orbiting, Mending.

**8 guardians** (2 per depth, e.g. The Riveters, The Eclipsed Knight) and **4 multi-phase bosses**, each with 6+ named attacks and a phase-2 change:
- **Ashenhart, the Cinder Stag**: charge, sweep, firefall, flame ring, brood, spiral.
- **Velloran, the Drowned Archivist**: quills, pages, tide, snipe, blink, copies.
- **The Engine Tyrant**: lasers, mortars, saws, pistons, hounds, vents.
- **The Pale Regent**: crescents, starfall, gravity, mirror dash, time sigil, knights.

**Economy.** Gold is for shops during a run. Embers are the permanent currency for the Wick. Also include rerolls and a Fate Die.

**The Wick (meta progression).** Unlocks weapons, unlocks Lights, enables Concord (duo boons), raises max HP, adds Second Wick (an extra Death Defiance), adds rerolls and a starting purse. It also has Keepsakes (equip one per run) and the **Deepening** tiers (new enemies, more elite modifiers, more Embers). A short story is told one line per run end.

## 3. NEW: Damage clarity (top priority, make it excellent)
Use one **colour language** for the whole game and document it in `DECISIONS.md`:
- Red/orange means it will hurt you.
- White, gold and the patron colours mean it is yours.
- Purple means boss.
- Cyan means a pickup or heal.

Player projectiles are **never** red. Enemy projectiles are always red or orange, with a dark outline and a bright core, so they read on every floor.

- **Telegraph every enemy and boss attack.** Before an attack, a ground shape (circle, cone, line, ring) fills from the outside in over the windup and flashes white at the moment of impact. The attacker glows and makes a rising audio cue. The minimum windup is 0.35 s for regular enemies and 0.5 s for bosses. Hazard floors (vents, spikes, pools) pulse twice before they activate.
- **Boss attack callouts.** Show the attack's name as a short banner ("STARFALL") together with its telegraph. Phase changes get a big banner and a short invulnerable roar.
- **Spawn portals.** Enemies appear through a 0.42 s portal and are harmless and invulnerable during it. Never spawn an enemy closer than 170 units to you.
- **Player hitbox.** While dangerous projectiles are near you, show a small bright dot at your true hitbox centre. Your hitbox is smaller than your sprite.
- **Getting hit.** A 70 ms hit-stop, knockback, a red screen-edge flash and a **directional damage arc** pointing at the source. You get 0.8 s of i-frames, during which your sprite flickers and has a visible shield outline. A red damage number with the source's icon rises from you.
- **HP bar with chip damage.** The lost portion turns white and then drains after 0.5 s. Heals fill green. Show the numeric HP. Barriers appear as a blue segment on top. Death Defiance charges appear as lantern icons next to the bar. When a lantern is used, it shatters with a slow-motion "DEFIED" moment.
- **Low HP (under 25 %).** A heartbeat sound, a pulsing red vignette and muffled music. A heal clears all of it with a warm chime.
- **Off-screen threats.** Show edge arrows for off-screen enemies and incoming projectiles. Each arrow pulses faster as its threat gets closer.
- **Enemy readability.** Each enemy shows a small HP bar once damaged. Elites get a modifier icon row with a hover/pause tooltip. Status effects (Burn, Chill, Hex, Bleed, Mark) get stack icons above the enemy. An armored enemy shows armor pips that crack.
- **Pause damage log.** The pause screen lists the last 10 hits you took (source, attack name, damage) and your current boons with full descriptions.
- **Death recap.** Death plays a 0.7 s slow motion, then a recap card. The card shows the killer (sprite and name), the attack that killed you, your last 5 hits, a one-line tip specific to that enemy ("Hookjaw's pull can be dashed through"), your build, and the Embers earned with a progress bar toward the next Wick unlock.

## 4. NEW: Satisfaction and game feel ("juice")
Put every number here in `game_feel.tres`. Settings must have sliders for screen shake, hit-stop, flashes and damage numbers, plus a "reduce flashing" toggle.
- **Hit-stop** scales with hit power: 40–90 ms, plus extra on crits and kills. It is capped per second, so fast weapons stay fluid. FX keep moving at 12 % speed during hit-stop.
- **Trauma-based screen shake** with a directional camera kick along the hit, a zoom punch on the last kill of a room and on boss kills, and slow motion on both.
- **Enemy hit reaction.** A white flash, squash & stretch, hit-stun, knockback with **wall slams** for bonus damage, a directional spark spray and floor impact decals that fade. Deaths break the enemy into shards plus an ember burst.
- **Damage numbers** pop in large and then settle. Several hits on the same enemy merge into one rising total. Crits are big, gold and shaking. Status damage is orange.
- **Kill streak tiers** KINDLED → BLAZING → INFERNO → SUPERNOVA, with an edge glow, rising kill-sound pitch and small damage and gold bonuses. The streak timer pauses during transitions and choices.
- **Perfect dash.** Dashing through an attack in its last 0.15 s before impact triggers a 0.4 s slow motion, a blue flash and a "PERFECT" callout, and guarantees a crit on your next hit.
- **Counter.** Hitting an enemy during the white flash of its telegraph interrupts the attack, staggers it with a heavy "clang" and opens it to a finisher.
- **Finishers.** Staggered or frozen enemies under 15 % HP glow. Your next hit executes them with an exaggerated hit-stop, a big burst and HP orb drops.
- **Overdrive meter.** It fills from hits and perfect dashes. When full, your weapon glows and the next Special is empowered, with a unique effect for each weapon.
- **Room clear.** After a slow-motion last kill, all gold, Embers and orbs fly to you with a rising arpeggio. Then the reward orb flies to you and the doors light up one by one.
- **Boon choice reveal.** Cards flip in with rarity-specific sounds and glows, from a common shimmer up to a legendary chorus. When a duo becomes available, show a "CONCORD" flash. Every boon card shows the exact before/after numbers.
- **Synergy callouts.** When two of your effects combine (Freeze plus a lightning chain, a Bleed burst, a Hex spreading), show a small coloured "+COMBO" popup and play an extra layered sound.
- **Combo pitch.** The pitch of the attack combo rises with each step. Every sound gets ±8 % random pitch, with voice limits and a minimum retrigger time.
- **Layered music** reacts to the game: an exploration layer, then combat, streak and boss layers that fade in, plus a stinger on room clear.

## 5. NEW: Addictive loop (always something to chase)
- **Seconds:** combos, streak tiers, perfect dashes, counters, finishers, synergy popups.
- **Room to room:** visible door rewards, the build coming together, shops, ordeals that trade risk for reward.
- **Per run: 3 Vows.** Pick optional challenges at the Wick before a run ("No springs", "Elites everywhere", "Take less than 100 damage in depth 2") for bonus Embers.
- **Across runs:**
  - **Weapon mastery levels** (XP from kills with that weapon). Each level unlocks a forge or a cosmetic glow.
  - **The Wick tree.**
  - **A bestiary** that fills in enemy notes and tips as you fight and die to enemies.
  - **Story lines.**
  - **30 achievements** with toast pop-ups.
  - **The Kindling Heat**: an optional difficulty ladder unlocked after the first win, with stacking modifiers.
- **Daily Descent.** A fixed daily seed with a fixed weapon and a local best-score table.
- **Run summary.** Time, rooms cleared, damage dealt and taken (a bar per source), best single hit, highest streak, boons taken and personal-best comparisons.
- **Fast retry.** The death recap ends on the next-unlock progress bar. "Descend again" is the focused button, and a new run starts in under 2 seconds.

## 6. UI, save and settings
- **HUD:** HP bar (chip damage, barrier, Death Defiance lanterns), dash charges, Special and Sigil cooldown rings, the Overdrive meter, gold and Embers, the streak tier, a boon icon strip and the current depth and room. Keep it clean, with big, readable fonts.
- **Screens:** title, the Wick (hub), Vows, weapon select, boon choice, shop, ordeal prompt, pause (damage log and boons), settings, death recap, run summary, bestiary, achievements, story log and Daily Descent. Build every screen with one shared Theme and full keyboard and gamepad navigation.
- **Settings:** volume buses (Master/Music/SFX), full rebinding for keyboard and gamepad, aim mode (mouse / stick / auto-aim), the game-feel sliders, damage numbers on/off, a colour-blind-safe palette option, screen-shake intensity and graphics presets.
- **Default controls.**
  - Keyboard + mouse: WASD to move, left click / J to attack, right click / K for the Special, Space / Shift for the dash, Q / E for the Sigil, Esc to pause.
  - Gamepad: left stick to move, right stick to aim, A / RT to attack, X / LB for the Special, B / RB for the dash, Y / LT for the Sigil, Start to pause.
- **Save:** JSON in `user://` for meta progress, settings and the run in progress. Autosave after every room and on quit, and resume a run mid-way.

## 7. Debug, tests and export
- **Debug menu (F1).** Pick a depth, room and room type; spawn any enemy, elite modifier, guardian or boss; grant any boon or weapon; god mode; one-hit kills; and show hitboxes, AI states and telegraph shapes.
- **Headless bot.** `godot --headless --path . -- --bot --runs=20 --weapon=all` plays full runs. It reports crashes, soft-locks, room times, damage sources and win rate, and must finish with no errors.
- **Headless tests** at `tests/run_tests.gd`. They print PASS/FAIL and exit with code 1 on any failure. Cover:
  - weapon frame data and combo timing, i-frames, hit-stop budget, chip-damage timing and perfect-dash windows;
  - boon stacking and every duo requirement, elite modifier combinations and status effect math;
  - room and door generation determinism per seed, shop and ordeal outcomes;
  - Wick purchases and requirements, save/load round-trips.
- **`tools/check_all.gd`** loads every script, scene and resource and must report zero errors. A screenshot tool, working under `xvfb-run`, captures the boon choice, a boss telegraph, the death recap and the Wick.
- **Linux export** to `build/linux/lanternfall.x86_64` with the `.pck` embedded. Command-line flags `--new-run`, `--continue`, `--daily`, `--weapon=<id>` and `--depth=<n>`.

## 8. Phases (do all of them, in order, without stopping)
1. Project setup, simulation/presentation split, signal bus, input (keyboard, mouse, gamepad, buffering, aim), player movement, dash, a test room, camera
2. Combat core: all 5 weapons with frame data, Specials, dash-attacks, the Sigil, crits, the hit pipeline, and the full **game-feel juice** (hit-stop, shake, flash, knockback, wall slams, particles, decals, damage numbers, slow motion)
3. **Damage clarity**: player hurt pipeline, the telegraph system, colour language, HP bar with chip damage, directional arcs, hitbox dot, off-screen arrows, low-HP state, death recap
4. Enemies of depths 1 and 2 with roles, spawn portals, waves, elite modifiers; Ashenhart and Velloran plus their guardians
5. Rooms and doors, all room types, shops, springs, ordeals, depth progression and scaling
6. All 8 patron Lights, all boons and duos, rarities, the boon-choice screen, synergy callouts, the Overdrive meter, perfect dash, counters, finishers
7. Depths 3 and 4: enemies, hazards, guardians, the Engine Tyrant, the Pale Regent; the full run plus the ending
8. The Wick hub, meta unlocks, Keepsakes, Deepening, Vows, weapon mastery, bestiary, story, achievements, Daily Descent, Kindling Heat, run summary
9. Full UI pass, procedural SFX and layered music, settings with rebinding and accessibility, save/load with mid-run resume
10. Debug menu, the headless bot, a balancing pass based on bot data, screenshots, Linux export, README

**Every phase ends with:** `tools/check_all.gd` passing with zero errors, all tests passing, a short entry in `PROGRESS.md`, and a git commit named "Phase N: …". If a test fails, fix the code. Never delete or skip a test to get a pass.

When you finish, write `README.md` covering:
- how to run the game from the editor and from the exported binary on Ubuntu (each command in its own code block);
- the full controls table (keyboard + mouse and gamepad) and the debug keys;
- what each phase delivered, what you simplified and why, and known bugs;
- how to replace the sprites and sounds.

Then run the bot for 20 runs and the exported binary under `xvfb-run` for 10 seconds, and report both results.
