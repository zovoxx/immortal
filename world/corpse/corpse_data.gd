class_name CorpseData
extends RefCounted
## A fallen courier's body. Position is stored relative to its zone origin so it survives origin shifts.

var id: int = 0
var courier_index: int = 0
var courier_name: String = ""
var zone: int = 0
var local_pos: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var inventory: CarryInventory = CarryInventory.new(99)
var died_unix: float = 0.0
var cause: String = ""


func item_count() -> int:
	return inventory.entries.size()


func to_dict() -> Dictionary:
	return {
		"id": id, "courier_index": courier_index, "courier_name": courier_name,
		"zone": zone, "pos": [local_pos.x, local_pos.y, local_pos.z], "yaw": yaw,
		"items": inventory.to_array(), "died_unix": died_unix, "cause": cause,
	}


static func from_dict(d: Dictionary) -> CorpseData:
	var c := CorpseData.new()
	c.id = int(d.get("id", 0))
	c.courier_index = int(d.get("courier_index", 0))
	c.courier_name = String(d.get("courier_name", ""))
	c.zone = int(d.get("zone", 0))
	var p: Array = d.get("pos", [0, 0, 0])
	c.local_pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
	c.yaw = float(d.get("yaw", 0.0))
	c.inventory.from_array(d.get("items", []))
	c.died_unix = float(d.get("died_unix", 0.0))
	c.cause = String(d.get("cause", ""))
	return c
