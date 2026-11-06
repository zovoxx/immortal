extends Control
## Main menu: Continue / New Road / Roll of the Fallen / The Message / Settings / Test Course / Quit.

const GAME_SCENE := "res://world/game_world.tscn"

var _vb: VBoxContainer
var _info: Label


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.is_running = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.set_loop_volume(Audio.music_player, 0.5)
	Audio.set_loop_volume(Audio.rain_player, 0.0)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_vb = VBoxContainer.new()
	_vb.add_theme_constant_override("separation", 10)
	center.add_child(_vb)
	_vb.add_child(UITheme.title("R E L A Y", 84))
	var sub := UITheme.label("Carry the Message down the Long Road.", 20, UITheme.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vb.add_child(sub)
	_vb.add_child(HSeparator.new())
	var summary := Save.peek()
	if not summary.is_empty():
		var cont := UITheme.button("Continue", _continue)
		_vb.add_child(cont)
		var c: Dictionary = summary.get("courier", {})
		_info = UITheme.label("Courier #%d %s — Zone %d" % [int(c.get("index", 1)), c.get("full_name", "?"), int(summary.get("current_zone", 0)) + 1], 16, UITheme.DIM)
		_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vb.add_child(_info)
	_vb.add_child(UITheme.button("New Road", _new_road))
	_vb.add_child(UITheme.button("Roll of the Fallen", func(): _page("res://ui/roll_of_fallen.tscn")))
	_vb.add_child(UITheme.button("The Message", func(): _page("res://ui/message_page.tscn")))
	_vb.add_child(UITheme.button("Settings", func(): _page("res://ui/settings_menu.tscn")))
	_vb.add_child(UITheme.button("Test Course", func(): get_tree().change_scene_to_file("res://world/test_course.tscn")))
	_vb.add_child(UITheme.button("Quit", func(): get_tree().quit()))
	(_vb.find_children("*", "Button", true, false)[0] as Button).grab_focus()


func _continue() -> void:
	if Save.load_game():
		get_tree().change_scene_to_file(GAME_SCENE)


func _new_road() -> void:
	Game.new_road(-1)
	Save.save_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _page(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	if path.ends_with("roll_of_fallen.tscn") or path.ends_with("message_page.tscn"):
		if Save.has_save() and not Game.is_running:
			Save.load_game()
	add_child(load(path).instantiate())
