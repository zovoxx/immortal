extends ModalLayer
## "THE SEAL BREAKS" card shown at stations every 25 zones.

var _title: Label
var _text: Label


func _ready() -> void:
	super._ready()
	layer = 17
	_make(Vector2(820, 380))
	_vb.add_child(UITheme.title("THE SEAL BREAKS", 44))
	_title = UITheme.label("", 22, UITheme.DIM)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vb.add_child(_title)
	_text = UITheme.label("", 22, UITheme.INK, true)
	_text.custom_minimum_size = Vector2(780, 160)
	_vb.add_child(_text)
	var b := UITheme.button("Continue", close_modal)
	_vb.add_child(b)
	Events.message_fragment_revealed.connect(_on_revealed)


func _on_revealed(index: int) -> void:
	_title.text = "%s  ·  fragment %d of %d" % [MessageFragments.TITLES[index], index + 1, MessageFragments.TEXT.size()]
	_text.text = MessageFragments.TEXT[index]
	Audio.play("bell", -10.0, 0.0)
	open_modal()
	(_root.find_children("*", "Button", true, false)[0] as Button).grab_focus()
