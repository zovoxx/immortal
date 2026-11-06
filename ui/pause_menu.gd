extends CanvasLayer
## Pause menu: Resume / Settings / Roll of the Fallen / The Message / Main Menu / Quit.

var _root: Control
var _settings: Node


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := UITheme.modal(self, Vector2(420, 420))
	_root = m[0]
	var vb: VBoxContainer = m[1]
	vb.add_child(UITheme.title("PAUSED"))
	vb.add_child(UITheme.button("Resume", close))
	vb.add_child(UITheme.button("Settings", _open_settings))
	vb.add_child(UITheme.button("Roll of the Fallen", func(): _open_page("res://ui/roll_of_fallen.tscn")))
	vb.add_child(UITheme.button("The Message", func(): _open_page("res://ui/message_page.tscn")))
	vb.add_child(UITheme.button("Save & Main Menu", _to_menu))
	vb.add_child(UITheme.button("Save & Quit", _quit))
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _root.visible:
			if _settings == null or not is_instance_valid(_settings):
				close()
		elif not _modal_open():
			open()
		get_viewport().set_input_as_handled()


func _modal_open() -> bool:
	for n in get_tree().get_nodes_in_group("modal_ui"):
		if n.visible:
			return true
	return false


func open() -> void:
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_root.find_children("*", "Button", true, false)[0] as Button).grab_focus()


func close() -> void:
	_root.visible = false
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_settings() -> void:
	_settings = load("res://ui/settings_menu.tscn").instantiate()
	add_child(_settings)


func _open_page(path: String) -> void:
	if ResourceLoader.exists(path):
		add_child(load(path).instantiate())


func _save_if_running() -> void:
	if Game.is_running and get_tree().current_scene and get_tree().current_scene.has_method("save_now"):
		get_tree().current_scene.save_now()


func _to_menu() -> void:
	_save_if_running()
	get_tree().paused = false
	Game.is_running = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _quit() -> void:
	_save_if_running()
	get_tree().quit()
