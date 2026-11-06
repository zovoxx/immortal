extends SceneTree
## Generates the placeholder visual scenes and zone module scenes from code.
## Run: godot --headless --path . --script res://tools/build_content.gd [-- --only=models|modules]
## After generation the .tscn files are the source of truth: edit them in the editor or swap in .glb
## models. Re-running this tool overwrites them.

func _initialize() -> void:
	await process_frame
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var count := 0
	if only == "" or only == "models":
		count += load("res://tools/builders/model_builder.gd").new().build_all()
	if only == "" or only == "modules":
		count += load("res://tools/builders/module_builder.gd").new().build_all()
	print("build_content: wrote %d scenes" % count)
	quit(0)


static func save_scene(root: Node, path: String) -> bool:
	_set_owner_recursive(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed for %s" % path)
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	err = ResourceSaver.save(ps, path)
	root.free()
	if err != OK:
		push_error("save failed for %s: %s" % [path, error_string(err)])
		return false
	return true


static func _set_owner_recursive(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_set_owner_recursive(c, owner)
