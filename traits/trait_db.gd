class_name TraitDB
extends RefCounted
## Registry of all courier traits.

const PATHS: Array[String] = [
	"res://traits/swift.tres",
	"res://traits/ox.tres",
	"res://traits/night_eyed.tres",
	"res://traits/lucky.tres",
	"res://traits/veteran.tres",
	"res://traits/old.tres",
	"res://traits/scarred.tres",
	"res://traits/light_footed.tres",
	"res://traits/iron_lunged.tres",
	"res://traits/clumsy.tres",
]

static var _traits: Dictionary = {}


static func _ensure() -> void:
	if not _traits.is_empty():
		return
	for p in PATHS:
		var t := load(p) as CourierTrait
		if t:
			_traits[t.id] = t
		else:
			push_error("TraitDB: failed to load %s" % p)


static func get_trait(id: String) -> CourierTrait:
	_ensure()
	return _traits.get(id) as CourierTrait


static func ids() -> Array:
	_ensure()
	return _traits.keys()


## Rolls 1-2 distinct traits that don't share an exclusive group.
static func roll(rng: RandomNumberGenerator) -> Array[String]:
	_ensure()
	var pool: Array = _traits.keys()
	pool.sort()
	var out: Array[String] = []
	var count := 1 if rng.randf() < 0.55 else 2
	var groups: Array[String] = []
	var guard := 0
	while out.size() < count and guard < 50:
		guard += 1
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		var t: CourierTrait = _traits[id]
		if out.has(id) or (t.exclusive_group != "" and groups.has(t.exclusive_group)):
			continue
		out.append(id)
		if t.exclusive_group != "":
			groups.append(t.exclusive_group)
	return out
