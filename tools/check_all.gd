extends SceneTree
## Loads every script, resource and scene in the project to surface parse/load errors.
## Run: godot --headless --path . --script res://tools/check_all.gd

var failures := 0


func _initialize() -> void:
	await process_frame
	_scan("res://")
	print("check_all: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _scan(dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d == "build" or d == "addons":
			continue
		_scan(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		var p := dir.path_join(f)
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			var r := ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REUSE)
			if r == null:
				failures += 1
				print("FAILED: ", p)
			elif r is GDScript and not (r as GDScript).can_instantiate():
				failures += 1
				print("SCRIPT ERROR: ", p)
