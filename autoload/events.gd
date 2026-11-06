extends Node
## Global signal bus. Systems emit and listen here instead of holding references to each other.

# --- Courier ---
signal courier_spawned(courier: Node)
signal courier_damaged(amount: float, cause: String)
signal courier_healed(amount: float)
signal courier_died(cause: String)
signal courier_respawned()
signal stamina_changed(value: float, max_value: float)
signal health_changed(value: float, max_value: float)
signal inventory_changed()
signal selected_slot_changed(index: int)

# --- World / zones ---
signal zone_entered(zone_index: int)
signal zone_loaded(zone_index: int)
signal zone_unloaded(zone_index: int)
signal station_activated(station_index: int)
signal origin_shifted(delta: Vector3)

# --- AI / perception ---
## A noise in the world. radius is how far it can be heard (metres). kind: "footstep", "land", "combat", "noise_maker", "bell", ...
signal sound_emitted(position: Vector3, radius: float, kind: String)
## A watchtower bell rang. Every hunter within radius enters CHASE.
signal alarm_raised(position: Vector3, radius: float)
## Something the HUD compass should flag briefly (howl, bell, ...).
signal compass_alert(position: Vector3, kind: String)
signal enemy_state_changed(enemy: Node, state: String)

# --- Weather ---
signal storm_started(kind: String)
signal storm_ended()
signal lightning_warning(position: Vector3)
signal lightning_strike(position: Vector3)

# --- Meta progression ---
signal momentum_changed(value: int)
signal message_fragment_revealed(index: int)
signal upgrades_changed()
signal stash_changed()
signal notify(text: String)

# --- UI ---
signal open_container(container: Object, title: String)
signal open_station_menu(station: Node)
signal ui_modal_changed(open: bool)
