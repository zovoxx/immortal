# RELAY — Design & Technical Decisions

Decisions made without asking, with the reasoning.

## Engine / tooling
- **Godot 4.7.2 stable** (latest stable 4.x available at build time), official Linux x86_64 binary + export templates.
- **Jolt Physics** is set as the 3D physics engine (`physics/3d/physics_engine`), built into Godot since 4.4.
- No plugins are used.
- Extra autoloads beyond Game/Events/Save: **Settings** (user settings + input rebinding) and **Audio** (procedural placeholder sounds + buses). Keeping these out of `Game` keeps game state serialisation clean.
