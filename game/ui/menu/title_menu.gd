class_name TitleMenu
extends CanvasLayer
## The start screen: the game's name "Mèo Xinh 222" over the
## kitchen, a big "Chơi" button, the coat choice and the volumes.
##
## The kitchen keeps running behind a dim veil, so the first thing a player
## sees is the room they will play in. Enter / E / Space also start the game.
## The scene that owns it decides what happens next (signals below) and frees it.

## The player wants to start (button, Enter, E or Space).
signal play_pressed
## The player clicked the coat button; the owner changes the coat and calls
## [method set_skin_label].
signal skin_pressed

var _skin_button: Button
var _started := false


func _ready() -> void:
	layer = 20  # above the HUD
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiStyle.make_theme()
	add_child(root)

	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(UiStyle.INK, 0.55)
	root.add_child(veil)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	_centered_label(box, "Mèo Xinh 222", 64)
	_centered_label(box, "Ăn vụng cá, rồi bày hiện trường\ncho bà Hằng hiểu lầm.", 20)

	var play := _button(box, "Chơi", 34)
	play.add_theme_stylebox_override("normal", UiStyle.framed(UiStyle.YELLOW, 12))
	play.pressed.connect(_start)
	_skin_button = _button(box, "", 18)
	_skin_button.pressed.connect(func() -> void: skin_pressed.emit())

	var sliders := VolumeSliders.new()
	sliders.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(sliders)
	_centered_label(box, "WASD đi · Space nhảy · E hành động · Q/R xoay · P tạm dừng", 15)


## Shows which coat the cat wears on the coat button.
func set_skin_label(skin_name: String) -> void:
	_skin_button.text = "Lông mèo: %s  (đổi)" % skin_name


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_start()


func _start() -> void:
	if _started:  # a double press must not start the day twice
		return
	_started = true
	Sound.play(&"task")
	play_pressed.emit()


func _button(parent: Control, text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keys keep meaning "play", not "press the focused button"
	b.add_theme_font_size_override("font_size", size)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(260, 0)
	parent.add_child(b)
	return b


func _centered_label(parent: Control, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l
