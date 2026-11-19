class_name PauseMenu
extends CanvasLayer
## Pause: P or the "Tạm dừng" button freezes the day and shows
## "Tiếp tục", "Chơi lại ngày" and the volumes. P / Esc-free: Esc already
## means "play again" (and Backspace is never used).
##
## The owner decides when pausing is allowed with [method set_allowed]
## (only while the player is in control: cutscene timers keep running
## through a pause, so cutscenes must not be paused).

## The player chose "Chơi lại ngày" from the pause menu.
signal restart_pressed

var _panel: PanelContainer
var _corner_button: Button
var _allowed := false


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS  # must work while the tree is paused
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.make_theme()
	add_child(root)

	# Small corner button, under the coat button (top right).
	_corner_button = Button.new()
	_corner_button.text = "Tạm dừng (P)"
	_corner_button.focus_mode = Control.FOCUS_NONE
	_corner_button.add_theme_font_size_override("font_size", 16)
	_corner_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_corner_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_corner_button.offset_right = -20
	_corner_button.offset_top = 74
	_corner_button.pressed.connect(open)
	root.add_child(_corner_button)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Tạm dừng"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	_button(box, "Tiếp tục", close)
	_button(box, "Chơi lại ngày", func() -> void:
		close()
		restart_pressed.emit())
	box.add_child(VolumeSliders.new())
	_panel.hide()
	set_allowed(false)


## Allows pausing (and shows the corner button) only while [param allowed].
func set_allowed(allowed: bool) -> void:
	_allowed = allowed
	_corner_button.visible = allowed
	if not allowed and is_open():
		close()


## True while the pause panel is showing.
func is_open() -> bool:
	return _panel.visible


## Pauses the game and shows the panel (ignored when pausing is not allowed).
func open() -> void:
	if not _allowed or is_open():
		return
	get_tree().paused = true
	_panel.show()


## Hides the panel and resumes the game.
func close() -> void:
	_panel.hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if is_open():
			close()
		else:
			open()


func _button(parent: Control, text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(260, 0)
	b.pressed.connect(on_press)
	parent.add_child(b)
