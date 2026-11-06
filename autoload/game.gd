extends Node
## Game state: the road (seed, zones, stations), the courier lineage, corpses, stash, upgrades, momentum.
## Pure state + rules. Scenes read from and write to it; Save serialises it.

const CONFIG: GameConfig = preload("res://autoload/game_config.tres")

var config: GameConfig = CONFIG

# --- Road ---
var world_seed: int = 0
var current_zone: int = 0
var highest_zone: int = 0
## Station index the next courier respawns at. Station s sits at the start of zone s.
var last_station: int = 0
var activated_stations: Array[int] = [0]
var time_of_day: float = 0.32
var play_time: float = 0.0
var zone_enter_time: float = 0.0
## Zone -> Array of toll ids already paid (toll-keepers stay peaceful).
var paid_tolls: Dictionary = {}
## Zone -> Array of loot cache ids already opened and taken from.
var looted_caches: Dictionary = {}

# --- Lineage ---
var courier: CourierData = null
var courier_counter: int = 0
## Roll of the Fallen: Array of Dictionaries {index, name, traits, zone, cause, lived}
var fallen: Array = []
var first_name_counts: Dictionary = {}

# --- Corpses ---
var corpses: Array[CorpseData] = []
var corpse_counter: int = 0

# --- Stations / meta ---
var stash: CarryInventory = CarryInventory.new(6)
var global_upgrades: Array[String] = []
## String(station index) -> Array[String] of upgrades built at that station.
var station_upgrades: Dictionary = {}
var momentum: int = 0
var fragments: Array[int] = []

# --- Runtime only (not saved) ---
var is_running: bool = false
var god_mode: bool = false
var debug_overlay: bool = false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if courier == null:
		new_road(12345)
		is_running = false


func _process(delta: float) -> void:
	if not is_running or get_tree().paused:
		return
	play_time += delta
	time_of_day = fposmod(time_of_day + delta / config.day_length_seconds, 1.0)
	if courier:
		courier.lived_seconds += delta


# =====================================================================
# Road
# =====================================================================

## Starts a fresh road. Keeps nothing from previous runs.
func new_road(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi() % 1000000
	world_seed = seed_value
	rng.seed = hash(seed_value)
	current_zone = 0
	highest_zone = 0
	last_station = 0
	activated_stations = [0]
	time_of_day = config.start_time_of_day
	play_time = 0.0
	zone_enter_time = 0.0
	paid_tolls = {}
	looted_caches = {}
	courier_counter = 0
	fallen = []
	first_name_counts = {}
	corpses = []
	corpse_counter = 0
	stash = CarryInventory.new(config.stash_slots)
	global_upgrades = []
	station_upgrades = {}
	momentum = 0
	fragments = []
	courier = create_new_courier(0)


func zone_seed(zone_index: int) -> int:
	return world_seed + zone_index


func biome_index(zone_index: int) -> int:
	return (zone_index / config.zones_per_biome) % 5


## Long Road +N: how many times the five biomes have looped.
func loop_index(zone_index: int) -> int:
	return zone_index / (config.zones_per_biome * 5)


func is_night() -> bool:
	return time_of_day < 0.22 or time_of_day > 0.78


## 0 at full day, 1 at deep night (smooth).
func night_factor() -> float:
	var sun := sin((time_of_day - 0.25) * TAU)  # 1 at noon, -1 at midnight
	return clampf(remap(sun, 0.2, -0.3, 0.0, 1.0), 0.0, 1.0)


func set_current_zone(zone_index: int) -> void:
	if zone_index == current_zone:
		return
	current_zone = zone_index
	highest_zone = maxi(highest_zone, zone_index)
	zone_enter_time = play_time
	Events.zone_entered.emit(zone_index)


# =====================================================================
# Couriers
# =====================================================================

func create_new_courier(station_index: int) -> CourierData:
	courier_counter += 1
	var c := CourierData.new()
	c.index = courier_counter
	c.traits = TraitDB.roll(rng)
	var n := NameGenerator.generate(rng, c.traits, first_name_counts)
	c.first_name = n.first
	c.full_name = n.full
	first_name_counts[c.first_name] = int(first_name_counts.get(c.first_name, 0)) + 1
	var bonus := config.bed_hp_bonus if has_upgrade("bed", station_index) else 0.0
	c.apply_base_stats(config.base_hp, config.base_carry_slots, bonus)
	c.born_unix = Time.get_unix_time_from_system()
	c.spawn_station = station_index
	# Kit: Message + basic gear (+ forge blade, + veteran weapon). Kit may exceed capacity.
	c.inventory.add("message", 1, true)
	for id in config.starting_kit:
		var item_id := String(id)
		if item_id == "short_blade" and has_upgrade("forge"):
			item_id = "fine_blade"
		c.inventory.add(item_id, int(config.starting_kit[id]), true)
	for t in c.trait_resources():
		if t.extra_weapon != "":
			c.inventory.add(t.extra_weapon, 1, true)
	return c


## Records a death. Creates a corpse at zone-local position, adds the Roll of the Fallen entry,
## resets momentum. Returns the corpse (or null if the courier carried nothing droppable).
func handle_death(cause: String, zone_index: int, local_pos: Vector3, yaw: float = 0.0) -> CorpseData:
	if courier == null:
		return null
	fallen.append({
		"index": courier.index, "name": courier.full_name, "traits": courier.traits.duplicate(),
		"zone": zone_index, "cause": cause, "lived": courier.lived_seconds,
		"died_unix": Time.get_unix_time_from_system(),
	})
	var corpse := CorpseData.new()
	corpse_counter += 1
	corpse.id = corpse_counter
	corpse.courier_index = courier.index
	corpse.courier_name = courier.full_name
	corpse.zone = zone_index
	corpse.local_pos = local_pos
	corpse.yaw = yaw
	corpse.cause = cause
	corpse.died_unix = Time.get_unix_time_from_system()
	for e in courier.inventory.droppable_entries():
		corpse.inventory.add(e.id, e.count, true)
	add_corpse(corpse)
	set_momentum(0)
	return corpse


func add_corpse(c: CorpseData) -> void:
	corpses.append(c)
	while corpses.size() > config.max_corpses:
		corpses.remove_at(0)  # the oldest decays


func get_corpse(id: int) -> CorpseData:
	for c in corpses:
		if c.id == id:
			return c
	return null


func corpses_in_zone(zone_index: int) -> Array[CorpseData]:
	var out: Array[CorpseData] = []
	for c in corpses:
		if c.zone == zone_index:
			out.append(c)
	return out


func most_recent_corpse() -> CorpseData:
	return corpses[corpses.size() - 1] if not corpses.is_empty() else null


## A scavenger takes one item from a corpse. Returns {id,count} or {} if empty.
func steal_from_corpse(corpse_id: int) -> Dictionary:
	var c := get_corpse(corpse_id)
	if c == null or c.inventory.entries.is_empty():
		return {}
	var idx := rng.randi_range(0, c.inventory.entries.size() - 1)
	return c.inventory.remove_at(idx, 1)


## Replaces the dead courier with a new one at the last station.
func respawn() -> CourierData:
	courier = create_new_courier(last_station)
	current_zone = last_station
	zone_enter_time = play_time
	return courier


func loot_luck() -> float:
	var l := courier.loot_luck() if courier else 0.0
	if momentum >= config.momentum_loot_level:
		l += config.momentum_loot_luck
	return l


func reveals_hidden_paths() -> bool:
	return (courier != null and courier.reveals_hidden_paths()) or momentum >= config.momentum_fast_level


func momentum_speed_mult() -> float:
	return 1.0 + (config.momentum_speed_bonus if momentum >= config.momentum_speed_level else 0.0)


# =====================================================================
# Stations, momentum, fragments
# =====================================================================

## Called when the courier walks into a station. Returns true if this was a new activation.
func activate_station(station_index: int) -> bool:
	var is_new := not activated_stations.has(station_index)
	var advanced := station_index > last_station
	if is_new:
		activated_stations.append(station_index)
	if advanced:
		var zone_time := play_time - zone_enter_time
		last_station = station_index
		set_momentum(mini(momentum + 1, config.momentum_max))
		if momentum >= config.momentum_fast_level and zone_time <= config.fast_courier_par_time and courier:
			var mat: String = ItemDB.MATERIALS[rng.randi_range(0, ItemDB.MATERIALS.size() - 1)]
			courier.inventory.add(mat, 2)
			Events.notify.emit("Fast Courier bonus: +2 %s" % ItemDB.display_name(mat))
		_check_fragment(station_index)
	if is_new or advanced:
		Events.station_activated.emit(station_index)
	return is_new or advanced


func _check_fragment(station_index: int) -> void:
	if station_index <= 0 or station_index % config.fragment_every_zones != 0:
		return
	var frag := station_index / config.fragment_every_zones - 1
	if frag < config.fragment_count and not fragments.has(frag):
		fragments.append(frag)
		fragments.sort()
		Events.message_fragment_revealed.emit(frag)


func set_momentum(v: int) -> void:
	v = clampi(v, 0, config.momentum_max)
	if v != momentum:
		momentum = v
		Events.momentum_changed.emit(v)


func is_global_upgrade(id: String) -> bool:
	return config.global_upgrades.has(id)


func has_upgrade(id: String, station_index: int = -1) -> bool:
	if is_global_upgrade(id):
		return global_upgrades.has(id)
	var list: Array = station_upgrades.get(str(station_index), [])
	return list.has(id)


func material_count(id: String) -> int:
	var n := courier.inventory.count_of(id) if courier else 0
	return n + stash.count_of(id)


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if material_count(String(k)) < int(cost[k]):
			return false
	return true


## Spends materials, courier pouch first, then the stash.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		var need := int(cost[k])
		need -= courier.inventory.remove_id(String(k), need)
		if need > 0:
			stash.remove_id(String(k), need)
	Events.inventory_changed.emit()
	Events.stash_changed.emit()
	return true


func build_upgrade(id: String, station_index: int) -> bool:
	if has_upgrade(id, station_index):
		return false
	var cost: Dictionary = config.upgrade_costs.get(id, {})
	if not spend(cost):
		return false
	if is_global_upgrade(id):
		global_upgrades.append(id)
	else:
		var key := str(station_index)
		var list: Array = station_upgrades.get(key, [])
		list.append(id)
		station_upgrades[key] = list
	Events.upgrades_changed.emit()
	return true


func is_cache_looted(zone_index: int, cache_id: String) -> bool:
	return (looted_caches.get(str(zone_index), []) as Array).has(cache_id)


func mark_cache_looted(zone_index: int, cache_id: String) -> void:
	var list: Array = looted_caches.get(str(zone_index), [])
	if not list.has(cache_id):
		list.append(cache_id)
	looted_caches[str(zone_index)] = list


func is_toll_paid(zone_index: int, toll_id: String) -> bool:
	return (paid_tolls.get(str(zone_index), []) as Array).has(toll_id)


func mark_toll_paid(zone_index: int, toll_id: String) -> void:
	var list: Array = paid_tolls.get(str(zone_index), [])
	if not list.has(toll_id):
		list.append(toll_id)
	paid_tolls[str(zone_index)] = list


# =====================================================================
# Serialisation
# =====================================================================

func to_dict() -> Dictionary:
	var corpse_list: Array = []
	for c in corpses:
		corpse_list.append(c.to_dict())
	return {
		"version": 1,
		"world_seed": world_seed, "current_zone": current_zone, "highest_zone": highest_zone,
		"last_station": last_station, "activated_stations": activated_stations.duplicate(),
		"time_of_day": time_of_day, "play_time": play_time, "paid_tolls": paid_tolls.duplicate(true), "looted_caches": looted_caches.duplicate(true),
		"courier": courier.to_dict() if courier else {},
		"courier_counter": courier_counter, "fallen": fallen.duplicate(true),
		"first_name_counts": first_name_counts.duplicate(),
		"corpses": corpse_list, "corpse_counter": corpse_counter,
		"stash": stash.to_array(), "global_upgrades": global_upgrades.duplicate(),
		"station_upgrades": station_upgrades.duplicate(true),
		"momentum": momentum, "fragments": fragments.duplicate(),
		"rng_state": str(rng.state),
	}


func from_dict(d: Dictionary) -> void:
	world_seed = int(d.get("world_seed", 0))
	current_zone = int(d.get("current_zone", 0))
	highest_zone = int(d.get("highest_zone", 0))
	last_station = int(d.get("last_station", 0))
	activated_stations.clear()
	for s in d.get("activated_stations", [0]):
		activated_stations.append(int(s))
	time_of_day = float(d.get("time_of_day", config.start_time_of_day))
	play_time = float(d.get("play_time", 0.0))
	zone_enter_time = play_time
	paid_tolls = d.get("paid_tolls", {})
	looted_caches = d.get("looted_caches", {})
	var cd: Dictionary = d.get("courier", {})
	courier = CourierData.from_dict(cd) if not cd.is_empty() else null
	courier_counter = int(d.get("courier_counter", 1))
	fallen = []
	for f in d.get("fallen", []):
		var e: Dictionary = f.duplicate()
		e["index"] = int(e.get("index", 0))
		e["zone"] = int(e.get("zone", 0))
		e["lived"] = float(e.get("lived", 0.0))
		fallen.append(e)
	first_name_counts = {}
	var fnc: Dictionary = d.get("first_name_counts", {})
	for k in fnc:
		first_name_counts[String(k)] = int(fnc[k])
	corpses.clear()
	for c in d.get("corpses", []):
		corpses.append(CorpseData.from_dict(c))
	corpse_counter = int(d.get("corpse_counter", corpses.size()))
	stash = CarryInventory.new(config.stash_slots)
	stash.from_array(d.get("stash", []))
	global_upgrades.clear()
	for u in d.get("global_upgrades", []):
		global_upgrades.append(String(u))
	station_upgrades = d.get("station_upgrades", {})
	momentum = int(d.get("momentum", 0))
	fragments.clear()
	for f in d.get("fragments", []):
		fragments.append(int(f))
	if d.has("rng_state"):
		rng.state = int(String(d.rng_state))
	if courier == null:
		courier = create_new_courier(last_station)
