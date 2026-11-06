# RELAY — Design & Technical Decisions

Decisions made without asking, with the reasoning.

## Engine / tooling
- **Godot 4.7.2 stable** (latest stable 4.x available at build time), official Linux x86_64 binary + export templates.
- **Jolt Physics** is set as the 3D physics engine (`physics/3d/physics_engine`), built into Godot since 4.4.
- No plugins are used.
- Extra autoloads beyond Game/Events/Save: **Settings** (user settings + input rebinding) and **Audio** (procedural placeholder sounds + buses). Keeping these out of `Game` keeps game state serialisation clean.

## Movement
- "Grab ledges up to 2.2 m above you" is measured from the courier's feet at the moment of the grab. Combined with the 1.4 m jump this lets you reach ~3.6 m ledges from the ground, which felt right for chunky placeholder geometry.
- Low obstacles 0.2–1.2 m are vaulted when thin, mantled (stepped onto) when deep. CharacterBody3D doesn't auto-step, so modules use ramps or vaultable steps.
- Jump/crouch/dodge presses are edge-detected once per physics frame inside the courier (not `is_action_just_pressed`) so inputs are never lost between render and physics frames.
- Movement is camera-relative; walking is "hold Walk" on keyboard or a light stick deflection on gamepad.
- Test harness: `tests/run_tests.gd` uses `_initialize()` + one frame wait because autoloads aren't registered while a `--script` main loop is compiled. Engine errors are captured with `OS.add_logger()` (Godot 4.5+ Logger API) for the smoke tests.
