class_name ItemDB
extends RefCounted
## Static registry of all item definitions. Add a new .tres path here to add an item.

const PATHS: Array[String] = [
	"res://items/defs/message.tres",
	"res://items/defs/short_blade.tres",
	"res://items/defs/fine_blade.tres",
	"res://items/defs/hand_axe.tres",
	"res://items/defs/bandage.tres",
	"res://items/defs/dried_meat.tres",
	"res://items/defs/sling_stones.tres",
	"res://items/defs/noise_maker.tres",
	"res://items/defs/smoke_pot.tres",
	"res://items/defs/caltrops.tres",
	"res://items/defs/fire_pot.tres",
	"res://items/defs/scrap.tres",
	"res://items/defs/cloth.tres",
	"res://items/defs/oil.tres",
	"res://items/defs/feathers.tres",
]

const MATERIALS: Array[String] = ["scrap", "cloth", "oil", "feathers"]

static var _defs: Dictionary = {}


static func _ensure() -> void:
	if not _defs.is_empty():
		return
	for p in PATHS:
		var d := load(p) as ItemDef
		if d == null:
			push_error("ItemDB: failed to load %s" % p)
			continue
		_defs[d.id] = d


static func get_def(id: String) -> ItemDef:
	_ensure()
	return _defs.get(id) as ItemDef


static func has(id: String) -> bool:
	_ensure()
	return _defs.has(id)


static func all() -> Array:
	_ensure()
	return _defs.values()


static func display_name(id: String) -> String:
	var d := get_def(id)
	return d.display_name if d else id


## Weighted random loot roll. luck > 0 shifts towards valuable items; loot_mult scales quantity.
static func roll_loot(rng: RandomNumberGenerator, rolls: int, luck: float) -> Array:
	_ensure()
	var pool: Array = []
	var total := 0.0
	for d: ItemDef in _defs.values():
		if d.loot_weight <= 0.0:
			continue
		var w := d.loot_weight * (1.0 + luck * clampf(float(d.value - 1) / 4.0, 0.0, 2.0))
		pool.append([d, w])
		total += w
	var out: Array = []
	for i in rolls:
		var r := rng.randf() * total
		for e in pool:
			r -= e[1]
			if r <= 0.0:
				var d: ItemDef = e[0]
				var c := rng.randi_range(d.loot_min, d.loot_max)
				if luck > 0.3 and rng.randf() < luck * 0.5:
					c += 1
				out.append({"id": d.id, "count": mini(c, d.max_stack)})
				break
	return out
