extends Node
## Save/load of the game state as JSON in user://.

var save_path: String = "user://relay_save.json"


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	var data := Game.to_dict()
	data["saved_unix"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot write %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var text := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Save: corrupt save file %s" % save_path)
		return false
	Game.from_dict(parsed)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


## Reads just the summary for the main menu without touching Game state.
func peek() -> Dictionary:
	if not has_save():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return parsed if parsed is Dictionary else {}
