class_name KitchenHud
extends CanvasLayer
## Everything 2D on top of the kitchen: clock, task list, key hints,
## action prompt, bà Hằng's thought bubble, the comic-style shout,
## the result card and the two-circle iris-out of the fail scene.
##
## Look (colours, font, frames): UiStyle.

## The player clicked "Chơi lại" on the result card.
signal replay_pressed
## The player clicked the "change coat" button.
signal skin_pressed

const INK := Color("2b2140")
const PAPER := Color("fffaf0")
const YELLOW := Color("ffd166")
const PINK := Color("ff7aa2")
## How long text stays up, as a multiplier on every text pause.
## Bigger = slower. One number for the whole game.
const READ_PACE := 1.5
const FONT_PATH := "res://assets/fonts/Baloo2.ttf"  # OFL, supports Vietnamese

var _clock: Label
var _prompt: Label
var _toast: Label
var _toast_panel: PanelContainer
var _bubble: PanelContainer
var _bubble_text: Label
var _shout: Control
var _shout_text: Label
var _result: PanelContainer
var _result_text: Label
var _iris: ColorRect
var _iris_mat: ShaderMaterial
var _toast_tween: Tween
var _fade: ColorRect
var _stickers: Array[Label] = []
var _root: Control
var _tasks_box: VBoxContainer
var _task_done: Array[bool] = []
var _emotes: Array[Control] = []
var _skin_button: Button


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_root = root

	var top := _panel(root, Vector2(20, 16))
	var top_box := VBoxContainer.new()
	top.add_child(top_box)
	_clock = _label(top_box, "", 26)
	_tasks_box = VBoxContainer.new()
	_tasks_box.add_theme_constant_override("separation", 2)
	top_box.add_child(_tasks_box)

	# Top right: choose Mèo Xinh's coat. Mouse only and never takes
	# keyboard focus, so Space / Enter keep meaning "jump" / "action".
	_skin_button = Button.new()
	_skin_button.focus_mode = Control.FOCUS_NONE
	_skin_button.add_theme_font_size_override("font_size", 18)
	_skin_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skin_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skin_button.offset_left = -20
	_skin_button.offset_right = -20
	_skin_button.offset_top = 16
	_skin_button.pressed.connect(func() -> void: skin_pressed.emit())
	root.add_child(_skin_button)

	var keys := _label(root, "WASD / mũi tên: đi   ·   Space: nhảy   ·   E: hành động   ·   Q / R: xoay camera   ·   P: tạm dừng   ·   Esc: chơi lại", 15)
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	keys.offset_top = -34
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.add_theme_color_override("font_color", PAPER)  # sits on the dark background

	_prompt = _label(root, "", 24)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -120  # room for two lines
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", PAPER)
	_prompt.add_theme_constant_override("outline_size", 8)

	# Story lines during play: at the bottom, in a framed card so they stand out.
	_toast_panel = _panel(root, Vector2.ZERO)
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_panel.offset_top = -135  # just above the action prompt
	_toast_panel.offset_bottom = -135
	var toast_box := StyleBoxFlat.new()
	toast_box.bg_color = Color("fff1c2")
	toast_box.border_color = INK
	toast_box.set_border_width_all(3)
	toast_box.set_corner_radius_all(16)
	toast_box.content_margin_left = 22
	toast_box.content_margin_right = 22
	toast_box.content_margin_top = 8
	toast_box.content_margin_bottom = 10
	toast_box.shadow_color = INK
	toast_box.shadow_size = 1
	toast_box.shadow_offset = Vector2(4, 4)
	_toast_panel.add_theme_stylebox_override("panel", toast_box)
	_toast = _label(_toast_panel, "", 24)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.hide()

	_bubble = _panel(root, Vector2.ZERO)
	_bubble.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_bubble.offset_top = 235  # below the clock + task list panel, which sits top-left
	_bubble.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bubble_text = _label(_bubble, "", 24)
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_text.custom_minimum_size = Vector2(560, 0)
	_bubble.hide()
	# Comic stickers that pop around the bubble while she yells on the phone.
	for s in [["BÙM!", Vector2(-330, 225), -0.3], ["CHÍU!", Vector2(300, 215), 0.25], ["ĐÙNG!", Vector2(320, 305), -0.12]]:
		var l := _label(root, s[0], 30)
		l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		l.position += s[1]
		l.rotation = s[2]
		l.add_theme_color_override("font_color", PINK)
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", 10)
		l.hide()
		_stickers.append(l)

	_build_shout(root)
	_build_iris(root)

	# Result card at the bottom, so it never covers the scene.
	_result = _panel(root, Vector2.ZERO)
	_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_result.offset_top = -40
	_result.offset_bottom = -40
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 14)
	_result.add_child(result_box)
	_result_text = _label(result_box, "", 22)
	_result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# A real button too: keyboard shortcuts can be swallowed by input methods.
	var replay := Button.new()
	replay.text = "Chơi lại"
	replay.add_theme_font_size_override("font_size", 24)
	replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	replay.pressed.connect(func() -> void: replay_pressed.emit())
	result_box.add_child(replay)
	_result.hide()

	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	root.add_child(_fade)
	root.move_child(_result, -1)  # the result card stays above the fade
	root.move_child(_toast_panel, -1)  # story lines must show above the iris and the fade


## Shows the in-game time, e.g. "Thứ Hai · 10:24".
## Shows which coat the cat wears on the "change coat" button.
func set_skin_label(skin_name: String) -> void:
	_skin_button.text = "Lông mèo: %s  (đổi)" % skin_name


## Shows or hides the "change coat" button (hidden during cutscenes).
func show_skin_button(visible_now: bool) -> void:
	_skin_button.visible = visible_now


func set_clock(text: String) -> void:
	_clock.text = text


## The day's task list: a title, then one line with a check box per task.
func set_tasks(tasks: PackedStringArray) -> void:
	for c in _tasks_box.get_children():
		c.queue_free()
	_task_done.clear()
	_label(_tasks_box, "Việc hôm nay:", 18)
	for i in tasks.size():
		_task_done.append(false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_tasks_box.add_child(row)
		var box := Control.new()
		box.custom_minimum_size = Vector2(22, 22)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.draw.connect(_draw_check_box.bind(box, i))
		row.add_child(box)
		_label(row, tasks[i], 18)


## Ticks task [param index] (0-based) with a little pop.
func tick_task(index: int) -> void:
	if index < 0 or index >= _task_done.size() or _task_done[index]:
		return
	_task_done[index] = true
	Sound.play(&"task", -4.0)
	var row := _tasks_box.get_child(index + 1) as HBoxContainer  # child 0 is the title
	var box := row.get_child(0) as Control
	var text := row.get_child(1) as Label
	box.queue_redraw()
	text.add_theme_color_override("font_color", Color(INK, 0.45))
	box.pivot_offset = box.custom_minimum_size / 2.0
	box.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shows or hides the task list under the clock (hidden at night in the
## bedroom: nothing left to do). The clock stays.
func show_tasks(visible_now: bool) -> void:
	_tasks_box.visible = visible_now


## True once task [param index] is ticked.
func is_task_done(index: int) -> bool:
	return index >= 0 and index < _task_done.size() and _task_done[index]


func _draw_check_box(box: Control, index: int) -> void:
	var r := Rect2(Vector2(1, 1), box.custom_minimum_size - Vector2(2, 2))
	box.draw_rect(r, PAPER)
	box.draw_rect(r, INK, false, 2.5)
	if index < _task_done.size() and _task_done[index]:
		box.draw_polyline(PackedVector2Array([Vector2(4, 11), Vector2(9, 17), Vector2(20, 2)]), Color("2fa36b"), 4.0)


## Comic-style speech bubble for a character's feelings: a round
## bubble (or a spiky one for loud feelings) with a tail pointing at
## [param char_pos] (screen position). Drawn above the iris, so it can sit next
## to a character inside a closing circle. Returns the bubble's index.
func show_emote(char_pos: Vector2, text: String, spiky := false, fill := PAPER) -> int:
	Sound.play(&"pop", -6.0, 0.1)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	var label := _label(holder, text, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var text_size := label.get_minimum_size()
	label.size = text_size
	label.position = -text_size / 2.0
	# Bubble above the character, kept on screen.
	var screen := _root.size
	var half := text_size / 2.0 + Vector2(34, 24)
	var center := char_pos + Vector2(0, -(half.y + 120))
	if center.y - half.y < 20:
		center.y = char_pos.y + half.y + 120  # no room above: put it below
	center.x = clampf(center.x, half.x + 16, screen.x - half.x - 16)
	holder.position = center
	# Ellipse (or burst) with a tail spliced in towards the character.
	var n := 36
	var to_char := char_pos - center
	var tail_angle := to_char.angle()
	var k := int(round(wrapf(tail_angle, 0.0, TAU) / TAU * n)) % n
	var pts := PackedVector2Array()
	for i in n:
		if i == k:
			pts.append(to_char - to_char.normalized() * 70.0)  # tail tip stops short of the face
			continue
		var a := TAU * i / n
		var r := 1.0 if not spiky or i % 2 == 0 else 1.2
		pts.append(Vector2(cos(a) * half.x * r, sin(a) * half.y * r))
	var fill_poly := Polygon2D.new()
	fill_poly.polygon = pts
	fill_poly.color = fill
	holder.add_child(fill_poly)
	var outline := Line2D.new()
	pts.append(pts[0])
	outline.points = pts
	outline.width = 4
	outline.default_color = INK
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	holder.add_child(outline)
	holder.move_child(label, -1)
	holder.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(holder, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_emotes.append(holder)
	return _emotes.size() - 1


## Removes every emote bubble.
func hide_emotes() -> void:
	for e in _emotes:
		if is_instance_valid(e):
			e.queue_free()
	_emotes.clear()


## Shows "[E] <prompt>" for the closest usable object and "[Space] Nhảy lên
## <perch>" when a jump-assist target is in reach. Empty strings hide a line.
func set_prompt(prompt: String, jump_target: String) -> void:
	var lines: PackedStringArray = []
	if prompt != "":
		lines.append("[E]  " + prompt)
	if jump_target != "":
		lines.append("[Space]  Nhảy lên " + jump_target)
	_prompt.text = "\n".join(lines)


## A story line in the framed card at the bottom. It stays up long
## enough to read (longer lines stay longer), then fades out.
func toast(text: String) -> void:
	_toast.text = text
	_toast_panel.reset_size()  # shrink-wrap the card around the new line
	_toast_panel.show()
	_toast_panel.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(maxf(1.8, text.length() * 0.055) * READ_PACE)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(_toast_panel.hide)


## Bà Hằng's speech bubble.
func show_thought(text: String) -> void:
	_bubble_text.text = "Bà Hằng:  " + text
	_bubble.show()
	for s in _stickers:  # stickers belong to the phone call only
		s.hide()


func hide_thought() -> void:
	_bubble.hide()
	for s in _stickers:
		s.hide()


## Bà Hằng yelling into the phone at Mr. Thanh, with popping comic stickers.
func show_call(text: String) -> void:
	_bubble_text.text = "Bà Hằng (gọi Mr. Thanh):  " + text
	_bubble.show()
	for i in _stickers.size():
		var s := _stickers[i]
		s.show()
		s.scale = Vector2(0.2, 0.2)
		s.pivot_offset = s.size / 2.0
		var t := create_tween()
		t.tween_interval(0.15 * i)
		t.tween_property(s, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fades the whole screen to [param alpha] (1 = black) over [param time] seconds.
func fade_to(alpha: float, time: float) -> Signal:
	var t := create_tween()
	t.tween_property(_fade, "color:a", alpha, time)
	return t.finished


## Big comic shout with "BÙM!" / "CHÍU!" stickers, popping in.
func show_shout(text: String) -> void:
	_shout_text.text = text
	_shout.show()
	_shout.scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.tween_property(_shout, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_shout() -> void:
	_shout.hide()


## Result card at the bottom of the screen; with [param at_top] it sits at the
## top instead (the punishment night: the floor cushion fills the bottom).
func show_result(text: String, at_top := false) -> void:
	_result_text.text = text
	if at_top:
		_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_result.grow_vertical = Control.GROW_DIRECTION_END
		_result.offset_top = 40
		_result.offset_bottom = 40
	_result.show()
	if _toast_tween:
		_toast_tween.kill()
	_toast_panel.hide()  # the result card takes the bottom of the screen


## Two-circle iris used by both endings: circle A closes on
## the one who got caught, then circle B opens on the one who got away, each
## with a comic emote bubble; then black. Hands over to the fade layer (fully
## black) so the caller can switch scenes and fade back in with [method fade_to].
## Positions are screen positions in canvas units (Camera3D.unproject_position).
## The defaults are the fail scene: the cat caught, Lộc gloating.
func play_iris(a_pos: Vector2, b_pos: Vector2, a_text := "Meo...?!  Con vô tội mà~",
		b_text := "Gâu gâu! Hí hí~", a_fill := PAPER, b_fill := YELLOW) -> void:
	_iris.show()
	_iris_mat.set_shader_parameter("rect_size", _iris.size)
	_iris_mat.set_shader_parameter("center_a", a_pos)
	_iris_mat.set_shader_parameter("center_b", b_pos)
	_iris_mat.set_shader_parameter("radius_b", 0.0)
	Sound.play(&"whoosh", -8.0)
	var t := create_tween()
	t.tween_method(func(r: float) -> void: _iris_mat.set_shader_parameter("radius_a", r), 1600.0, 80.0, 0.9)
	t.tween_callback(func() -> void: show_emote(a_pos, a_text, false, a_fill))
	t.tween_interval(1.6 * READ_PACE)  # let the caught one's face sink in
	t.tween_method(func(r: float) -> void: _iris_mat.set_shader_parameter("radius_b", r), 0.0, 80.0, 0.4)
	t.tween_callback(func() -> void: show_emote(b_pos, b_text, true, b_fill))
	t.tween_interval(2.2 * READ_PACE)  # and the winner's grin
	t.tween_callback(hide_emotes)
	t.tween_method(func(r: float) -> void:
		_iris_mat.set_shader_parameter("radius_a", r)
		_iris_mat.set_shader_parameter("radius_b", r), 80.0, 0.0, 0.4)
	await t.finished
	_fade.color.a = 1.0
	_iris.hide()


# ------------------------------------------------------------------ building

func _make_theme() -> Theme:
	return UiStyle.make_theme()  # one look for HUD and menus


func _panel(parent: Control, pos: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _label(parent: Control, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_shout(root: Control) -> void:
	_shout = Control.new()
	_shout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_shout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shout)
	# Spiky comic burst behind the text.
	var burst := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var r := 230.0 if i % 2 == 0 else 160.0
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * r * 1.35, sin(a) * r * 0.75))
	burst.polygon = pts
	burst.color = YELLOW
	_shout.add_child(burst)
	var outline := Line2D.new()
	pts.append(pts[0])
	outline.points = pts
	outline.width = 6
	outline.default_color = INK
	_shout.add_child(outline)
	_shout_text = _label(_shout, "", 72)
	_shout_text.position = Vector2(-260, -60)
	_shout_text.size = Vector2(520, 120)
	_shout_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shout_text.add_theme_color_override("font_color", PINK)
	_shout_text.add_theme_color_override("font_outline_color", INK)
	_shout_text.add_theme_constant_override("outline_size", 14)
	for sticker in [["BÙM!", Vector2(-330, -150), -0.3], ["CHÍU!", Vector2(200, -160), 0.25], ["ĐÙNG!", Vector2(210, 90), -0.15]]:
		var s := _label(_shout, sticker[0], 34)
		s.position = sticker[1]
		s.rotation = sticker[2]
		s.add_theme_color_override("font_outline_color", PAPER)
		s.add_theme_constant_override("outline_size", 8)
	_shout.hide()


func _build_iris(root: Control) -> void:
	_iris = ColorRect.new()
	_iris.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iris_mat = ShaderMaterial.new()
	_iris_mat.shader = load("res://game/ui/hud/iris.gdshader")
	_iris.material = _iris_mat
	root.add_child(_iris)
	_iris.hide()
