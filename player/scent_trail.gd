class_name ScentTrail
extends RefCounted
## Ring buffer of scent points the courier leaves behind (one every `interval` seconds, max `capacity`).
## Standing still strengthens the newest point instead of adding new ones. Water erases points.

var capacity: int = 60
var interval: float = 0.5
var still_distance: float = 0.4
var max_strength: float = 3.0
var strengthen_rate: float = 0.5

## Each point: {"pos": Vector3, "time": float, "strength": float}
var _buf: Array = []
var _head: int = 0  # index of the oldest point
var _count: int = 0
var _timer: float = 0.0


func _init(cap: int = 60) -> void:
	capacity = cap
	_buf.resize(capacity)


func size() -> int:
	return _count


func clear() -> void:
	_count = 0
	_head = 0


## Oldest -> newest.
func points() -> Array:
	var out: Array = []
	for i in _count:
		out.append(_buf[(_head + i) % capacity])
	return out


func newest() -> Dictionary:
	return _buf[(_head + _count - 1) % capacity] if _count > 0 else {}


func add_point(pos: Vector3, time: float) -> void:
	var p := {"pos": pos, "time": time, "strength": 1.0}
	if _count < capacity:
		_buf[(_head + _count) % capacity] = p
		_count += 1
	else:
		_buf[_head] = p
		_head = (_head + 1) % capacity


## Call every frame. water_check: Callable(Vector3) -> bool (true if the point is under water).
func update(delta: float, pos: Vector3, time: float, water_check: Callable = Callable()) -> void:
	_timer += delta
	if _timer < interval:
		return
	_timer -= interval
	var last := newest()
	if not last.is_empty() and (last.pos as Vector3).distance_to(pos) < still_distance:
		last.strength = minf(float(last.strength) + strengthen_rate, max_strength)
		last.time = time
	else:
		add_point(pos, time)
	if water_check.is_valid():
		erase_where(water_check)


## Removes every point for which predicate(pos) is true (e.g. inside water).
func erase_where(predicate: Callable) -> int:
	var kept: Array = []
	var removed := 0
	for p in points():
		if predicate.call(p.pos):
			removed += 1
		else:
			kept.append(p)
	if removed > 0:
		clear()
		for p in kept:
			_buf[(_head + _count) % capacity] = p
			_count += 1
	return removed


func shift(delta: Vector3) -> void:
	for i in _count:
		var p: Dictionary = _buf[(_head + i) % capacity]
		p.pos = (p.pos as Vector3) + delta
