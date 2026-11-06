extends CanvasLayer
## THE MESSAGE: every fragment revealed so far.

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := UITheme.modal(self, Vector2(940, 620))
	var vb: VBoxContainer = m[1]
	vb.add_child(UITheme.title("THE MESSAGE"))
	var sub := UITheme.label("Sealed. Addressed to whoever stands at the End of the Road. Sender unknown.", 17, UITheme.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(900, 460)
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for i in MessageFragments.TEXT.size():
		if Game.fragments.has(i):
			list.add_child(UITheme.label(MessageFragments.TITLES[i], 22, UITheme.ACCENT))
			var t := UITheme.label(MessageFragments.TEXT[i], 19, UITheme.INK, true)
			t.custom_minimum_size = Vector2(860, 0)
			list.add_child(t)
		else:
			list.add_child(UITheme.label("%s — the seal holds. (Reach Relay %d)" % [MessageFragments.TITLES[i], MessageFragments.zone_for(i)], 19, UITheme.DIM))
	var b := UITheme.button("Close", queue_free)
	vb.add_child(b)
	b.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
