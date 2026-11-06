@tool
class_name ZoneModule
extends Node3D
## Root of a hand-built zone chunk. Local frame: the Entry socket is at the origin facing +Z; the
## module occupies x in [-10, 10] and z in [0, 20 * length_cells]. The Exit socket is at
## (0, 0, 20*L) for straight modules, (+10, 0, 10) for left turns and (-10, 0, 10) for right turns.
##
## Slot markers (Marker3D children of "Slots") tell the generator where things may go:
##   Enemy*  generic enemy encounter     Loot*   supply cache       Toll*  toll-keeper post
##   Tower*  watchtower                  Open*   rider territory    Station  relay station
## Hidden shortcut geometry lives under nodes with hidden_path.gd (revealed by Old / Fast Courier).

enum Exit { STRAIGHT, LEFT, RIGHT }

const CELL := 20.0

@export var module_id: String = ""
## path, bridge, climb, chase_open, stealth, shelter, rest, landmark, station
@export var tags: PackedStringArray = ["path"]
@export_range(1, 2) var length_cells: int = 1
@export var exit_dir: Exit = Exit.STRAIGHT
@export var weight: float = 1.0
## Zones before this index never pick the module (keeps the first zones gentle).
@export var min_zone: int = 0


static func exit_local_position(dir: int, length: int) -> Vector3:
	match dir:
		Exit.LEFT: return Vector3(CELL * 0.5, 0, CELL * 0.5)
		Exit.RIGHT: return Vector3(-CELL * 0.5, 0, CELL * 0.5)
	return Vector3(0, 0, CELL * length)


## Heading after the exit, in module-local terms, as a yaw delta.
static func exit_yaw_delta(dir: int) -> float:
	match dir:
		Exit.LEFT: return PI * 0.5
		Exit.RIGHT: return -PI * 0.5
	return 0.0
