class_name MondayKitchen
extends Node3D
## Monday (level 1): the fish case from start screen to bedtime, in the
## kitchen + dining + laundry room that KitchenBuilder makes.
##
## The day: Mèo Xinh eats the fish, builds a chain so bà Hằng blames Lộc,
## naps. Bà Hằng comes home, phones Mr. Thanh first (a random silly scolding),
## then inspects. Lộc blamed → all three go to bed.
## Cat caught → chase, two circles with Lộc gloating, punishment night, and
## the replay starts as "only a dream".
##
## The judging is pure logic elsewhere: case rules (game/core/cases/), bà
## Hằng's reasoning (game/core/owner/), her phone lines (game/data/lines/).
## Self-checks and dev keys: dev_checks.gd.

const Fish := preload("res://game/core/cases/fish_case.gd")
const CALL_LINES_PATH := "res://game/data/lines/mr_thanh_calls.json"
const B := preload("res://game/rooms/monday_kitchen/kitchen_builder.gd")

## Real seconds for the whole day (08:00 → 17:00 on the clock).
const DAY_SECONDS := 150.0
const THREAD_Z := -0.3  # where the dropped thread lies across the floor
## The day's task list. No task for washing: the yellow patch is the only hint.
const TASKS: PackedStringArray = ["Ăn vụng cá trên bàn", "Bày hiện trường để bà Hằng hiểu lầm", "Giả ngủ chờ bà Hằng về"]
const TASK_FISH := 0
const TASK_SCENE := 1
const TASK_NAP := 2
const CAT_START := Vector3(-0.5, 0.2, 2.6)
const CAT_CUSHION := Vector3(3.0, 0.0, 3.0)
const DOG_HOME := Vector3(-2.4, 0.0, 2.4)
const BALL_HOME := Vector3(-1.5, 0.15, 1.7)
const BALL_TARGET := Vector3(2.0, 0.15, -2.4)
const OWNER_SPOT := Vector3(-1.8, 0.0, 1.0)  # where bà Hằng stands to make her call
## The cat counts as "near the scene" within this distance of the table.
const NEAR_SCENE := 2.2

enum Phase { PLAY, OWNER, RESULT }

var phase: Phase = Phase.PLAY
## Facts bà Hằng will look at (keys from FishCase).
var state: Dictionary = {}
var time_left: float = DAY_SECONDS

var rig: CameraRig
var cat: CatController
var dog: Dog
var owner_npc: OwnerNpc
var hud: KitchenHud
var interactables: Array[Interactable] = []
## The told scenes of the day (MondayStory).
var story: MondayStory

var _room: Dictionary
var _plate: Node3D
var _fish: Node3D
var _bones: Node3D
var _rope: ThreadRope
var _ball: Node3D
var _ball_use: Interactable
var _dog_busy := false
var _pause: PauseMenu
var _checks: MondayDevChecks
var _rng := RandomNumberGenerator.new()
## Set after the cat was caught: the replay starts with "it was only a dream".
## Static, so it survives reload_current_scene.
static var _wake_from_dream := false
## The opening scene plays once per session (not again on every replay).
static var _opening_seen := false


func _ready() -> void:
	_rng.randomize()
	_setup_input()
	_room = B.build(self)
	rig = CameraRig.new()
	add_child(rig)
	rig.yaw_changed.connect(_update_walls)
	cat = CatController.new()
	cat.camera_rig = rig
	cat.perches = _room["perches"]
	for w in _room["walls"]:
		cat.occlusion_exclude.append((w[2] as StaticBody3D).get_rid())
	for fence: StaticBody3D in _room["bounds"]:  # invisible, never hides the cat
		cat.occlusion_exclude.append(fence.get_rid())
	add_child(cat)
	cat.reset_to(CAT_START)
	dog = Dog.new()
	add_child(dog)
	dog.position = DOG_HOME
	owner_npc = OwnerNpc.new()
	add_child(owner_npc)
	owner_npc.hide()
	_build_props()
	hud = KitchenHud.new()
	hud.replay_pressed.connect(get_tree().reload_current_scene)
	add_child(hud)
	hud.set_tasks(TASKS)
	hud.skin_pressed.connect(_on_change_skin)
	hud.set_skin_label(CatSkins.display_name(ToyModels.cat_skin))
	get_tree().paused = false  # a restart from the pause menu comes in paused
	_pause = PauseMenu.new()
	_pause.restart_pressed.connect(get_tree().reload_current_scene)
	add_child(_pause)
	# The told scenes (opening, coming home, endings) live in monday_story.gd.
	story = MondayStory.new()
	story.k = self
	add_child(story)
	if _wake_from_dream:
		_wake_from_dream = false
		story.dream_wake_up()
	elif not _opening_seen and OS.get_cmdline_user_args().is_empty():
		_opening_seen = true
		story.show_title()
	_update_walls(45.0)
	Sound.music(&"day")  # cross-fades back from the evening tune on a replay
	# Self-checks (tools/check_prototype.ps1) and the F9/F10 dev keys live apart.
	_checks = MondayDevChecks.new()
	_checks.k = self
	add_child(_checks)
	_checks.run(OS.get_cmdline_user_args())


func _process(delta: float) -> void:
	_pause.set_allowed(phase == Phase.PLAY)  # never during cutscenes (their timers ignore pause)
	if phase != Phase.PLAY:
		return
	time_left -= delta
	_show_time_of_day(time_left)
	var near := _nearest_interactable()
	hud.set_prompt(near.prompt if near else "", cat.target_perch_name)
	if time_left <= 0.0:
		story.owner_comes_home()


func _unhandled_input(event: InputEvent) -> void:
	var replay_key := event.is_action_pressed("interact") or event.is_action_pressed("jump")
	if event.is_action_pressed("restart") or (phase == Phase.RESULT and replay_key):
		get_tree().reload_current_scene()
	elif phase == Phase.PLAY and _is_dev_key(event, KEY_F9):
		# Dev only (not in release builds): F9 autoplays the winning chain.
		_checks.autotest(false)
	elif phase == Phase.PLAY and _is_dev_key(event, KEY_F10):
		# Dev only: F10 eats the fish and naps right away (to see the fail scene).
		_checks.autoplay_fail()
	elif event.is_action_pressed("rotate_left") and phase == Phase.PLAY:
		rig.rotate_corner(-1)
	elif event.is_action_pressed("rotate_right") and phase == Phase.PLAY:
		rig.rotate_corner(1)
	elif event.is_action_pressed("interact") and phase == Phase.PLAY:
		var near := _nearest_interactable()
		if near:
			near.use()


## The "change coat" button: next skin, saved, applied at once to
## the cat and to the sleeping cat in the bedroom scene.
func _on_change_skin() -> void:
	ToyModels.set_cat_skin(CatSkins.next_skin(ToyModels.cat_skin))
	cat.rebuild_model()
	var bed_cat: Node3D = _room["bedroom_cat"]
	for child in bed_cat.get_children():
		child.queue_free()
	ToyModels.build_cat(bed_cat)["mouth"].visible = false
	ToyModels.set_cat_eyes_closed(bed_cat, true)
	hud.set_skin_label(CatSkins.display_name(ToyModels.cat_skin))


# ------------------------------------------------------------------ the case

func _on_eat_fish(use: Interactable) -> void:
	use.enabled = false
	_fish.hide()
	_bones.show()
	state[Fish.FISH_EATEN] = true
	cat.mouth_dirty = true  # only the yellow patch shows it
	Sound.play(&"eat")
	hud.toast("Ngon quá! *liếm mép*")
	hud.tick_task(TASK_FISH)


func _on_drop_thread(use: Interactable) -> void:
	use.enabled = false
	_rope.show()
	_rope.unroll(1.8)  # pours over the edge and wriggles out across the floor
	Sound.play(&"thread", -4.0)
	state[Fish.THREAD_DOWN] = true
	hud.toast("Đầu dây buộc vào khăn bàn rơi xuống sàn.")


func _on_push_ball() -> void:
	if _dog_busy:
		return
	_dog_busy = true
	_ball_use.enabled = false
	var roll := create_tween()
	roll.tween_property(_ball, "position", BALL_TARGET, 1.0).set_ease(Tween.EASE_OUT)
	hud.toast("Lộc! Bóng kìa!")
	Sound.play(&"roll", -4.0)
	get_tree().create_timer(0.3).timeout.connect(Sound.play.bind(&"bark", 0.0, 0.05))
	var will_trip: bool = state.get(Fish.THREAD_DOWN, false) and not state.get(Fish.PLATE_ON_FLOOR, false)
	if will_trip:
		# Where Lộc's straight path from his spot to the ball crosses the thread.
		var t := (THREAD_Z - dog.position.z) / (BALL_TARGET.z - dog.position.z)
		var trip := dog.position.lerp(Vector3(BALL_TARGET.x, 0.0, BALL_TARGET.z), clampf(t, 0.0, 1.0))
		dog.run_to(trip, _on_dog_caught_thread)
	else:
		dog.run_to(Vector3(BALL_TARGET.x, 0.0, BALL_TARGET.z + 0.6), _on_dog_got_ball)


## Lộc runs into the thread and drags it along: the thread pulls the
## tablecloth, the plate slides to the edge and falls next to him.
func _on_dog_caught_thread() -> void:
	# The thread snags his leg; he gets spooked and bolts back towards his bed,
	# AWAY from the table, so the thread really pulls the tablecloth.
	hud.toast("Lộc vướng dây, giật mình bỏ chạy!")
	Sound.play(&"yelp")
	dog.stumble()
	_rope.drag_with(dog, _rope.closest_rest_point(dog.position))
	var away := Vector3(DOG_HOME.x - dog.position.x, 0.0, DOG_HOME.z - dog.position.z).normalized()
	var drag_to := dog.position + away * 1.3
	dog.run_to(drag_to, func() -> void: pass, 1.6)
	# The cloth (and the plate on it) slides towards where the thread pulls.
	var pull_dir := Vector3(dog.position.x - _plate.position.x, 0.0, dog.position.z - _plate.position.z).normalized()
	var flap: Node3D = _room["cloth_flap"]
	var slide := _distance_to_table_edge(_plate.position, pull_dir) + 0.12  # just past the edge
	var pull := create_tween()
	pull.tween_interval(0.3)
	pull.tween_callback(Sound.play.bind(&"slide", -2.0))
	pull.tween_property(flap, "position", flap.position + pull_dir * 0.35, 0.8).set_ease(Tween.EASE_IN)
	pull.parallel().tween_property(_plate, "position", _plate.position + pull_dir * slide, 0.8).set_ease(Tween.EASE_IN)
	await pull.finished
	# Over the edge: the plate falls, following the pull.
	var floor_pos := _plate.position + pull_dir * 0.6
	floor_pos.y = 0.03
	var fall := create_tween()
	fall.tween_property(_plate, "position", floor_pos, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(_plate, "rotation:z", 0.35, 0.7)
	await fall.finished
	Sound.play(&"crash")
	hud.toast("CHOANG!")
	# Lộc shakes the thread off his leg: it stays on the floor as a trail
	# instead of following him everywhere (e.g. during the chase).
	_rope.release()
	state[Fish.PLATE_ON_FLOOR] = true
	hud.tick_task(TASK_SCENE)
	# "Near the plate" is measured, not assumed: he ran off with the thread.
	state[Fish.DOG_NEAR_PLATE] = Vector2(dog.position.x - floor_pos.x, dog.position.z - floor_pos.z).length() < 2.2
	_dog_busy = false


func _on_dog_got_ball() -> void:
	# He brings the ball back to his bed, ready to be pushed again.
	_ball.hide()
	state[Fish.DOG_NEAR_PLATE] = false
	dog.run_to(DOG_HOME, func() -> void:
		_ball.position = BALL_HOME
		_ball.show()
		_ball_use.enabled = true
		_dog_busy = false)


func _on_water() -> void:
	# Same message whether the mouth was dirty or not: no hints.
	cat.mouth_dirty = false
	Sound.play(&"lap", -2.0)
	hud.toast("Uống nước, rửa mặt. Mát ghê.")


func _on_nap() -> void:
	cat.reset_to(CAT_CUSHION + Vector3(0, 0.25, 0))
	cat.set_eyes_closed(true)  # pretending to sleep
	hud.toast("Zzz... (giả ngủ ngoan)")
	hud.tick_task(TASK_NAP)
	story.owner_comes_home()


## How far [param p] (on the table top) can move along [param dir] before it
## leaves the table (the table top is 1.6 × 1.0 m around TABLE_CENTER).
func _distance_to_table_edge(p: Vector3, dir: Vector3) -> float:
	var half := Vector2(0.8, 0.5)
	var best := INF
	if absf(dir.x) > 0.001:
		var edge_x := B.TABLE_CENTER.x + signf(dir.x) * half.x
		best = minf(best, (edge_x - p.x) / dir.x)
	if absf(dir.z) > 0.001:
		var edge_z := B.TABLE_CENTER.z + signf(dir.z) * half.y
		best = minf(best, (edge_z - p.z) / dir.z)
	return maxf(best, 0.0)


## Shows the clock for [param seconds_left] of the day (08:00 → 17:00).
func _show_time_of_day(seconds_left: float) -> void:
	var minutes := int(lerpf(8.0 * 60.0, 17.0 * 60.0, 1.0 - seconds_left / DAY_SECONDS))
	hud.set_clock("Thứ Hai  ·  %02d:%02d   (bà Hằng về lúc 17:00)" % [minutes / 60, minutes % 60])


# ------------------------------------------------------------------ helpers

## True only in debug builds, when [param event] is a fresh press of [param key].
## Must match the exact key: a broader check here once swallowed every key
## (E, Q, R) in debug builds.
func _is_dev_key(event: InputEvent, key: Key) -> bool:
	var k := event as InputEventKey
	return OS.is_debug_build() and k != null and k.pressed and not k.echo and k.physical_keycode == key


## Waits while the player reads a line of text (one shared reading pace).
func _read(seconds: float) -> Signal:
	return _wait(seconds * KitchenHud.READ_PACE)


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout


func _nearest_interactable() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for it in interactables:
		if not it.enabled or not it.is_visible_in_tree():
			continue
		var d := it.global_position.distance_to(cat.global_position + Vector3(0, 0.2, 0))
		if d < it.radius and d < best_d:
			best = it
			best_d = d
	return best


func _add_use(parent: Node3D, prompt: String, offset: Vector3, radius: float, cb: Callable) -> Interactable:
	var it := Interactable.new(prompt, radius)
	it.position = offset
	parent.add_child(it)
	if cb.is_valid():
		it.used.connect(cb)
	interactables.append(it)
	return it


func _update_walls(_yaw: float) -> void:
	var toward := rig.toward_camera_flat()
	for w in _room["walls"]:
		var normal: Vector3 = w[1]
		(w[0] as MeshInstance3D).visible = normal.dot(toward) < 0.1


func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE], "interact": [KEY_E, KEY_ENTER],
		"rotate_left": [KEY_Q], "rotate_right": [KEY_R], "restart": [KEY_ESCAPE], "pause": [KEY_P],  # never Backspace: Vietnamese IMEs inject it
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: Key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)


# ------------------------------------------------------------------ the day's objects

## An empty node at [param pos] under the kitchen: holds a prop's model and
## its use point.
func _holder(pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	return node


func _build_props() -> void:
	var tc := B.TABLE_CENTER
	# Plate with a fish on the (clothed) table.
	_plate = Node3D.new()
	_plate.position = tc + Vector3(0.35, B.TABLE_TOP + 0.03, -0.1)
	add_child(_plate)
	# Plate, fish and bones are Blender models sharing the plate's origin.
	B._place_model(_plate, "plate", Vector3.ZERO)
	_fish = B._place_model(_plate, "fish", Vector3.ZERO)  # hides as one piece once eaten
	_bones = B._place_model(_plate, "fish_bones", Vector3.ZERO)
	_bones.hide()
	var eat := _add_use(_plate, "Ăn vụng cá", Vector3(0, 0.05, 0), 0.75, Callable())
	eat.used.connect(_on_eat_fish.bind(eat))

	# Spool of thread near the table's front edge; its loose end is tied to the cloth.
	var spool_pos := tc + Vector3(-0.45, B.TABLE_TOP + 0.09, 0.3)
	var spool := _holder(spool_pos)
	B._place_model(spool, "spool", Vector3(0, -0.08, 0))  # model origin = its bottom
	var drop := _add_use(spool, "Hất đầu dây cuộn chỉ xuống", Vector3.ZERO, 0.75, Callable())
	drop.used.connect(_on_drop_thread.bind(drop))
	# The thread's settled path: spool → over the edge → down the cloth → across the floor,
	# right across the way Lộc runs to his ball (it pours out and wriggles).
	_rope = ThreadRope.new()
	add_child(_rope)
	var edge_x := tc.x - 0.45
	var edge_z := tc.z + 0.52
	_rope.set_path(PackedVector3Array([
		spool_pos, Vector3(edge_x, B.TABLE_TOP + 0.02, edge_z), Vector3(edge_x, B.TABLE_TOP - 0.28, edge_z + 0.03),
		Vector3(edge_x - 0.05, 0.02, edge_z + 0.25), Vector3(0.9, 0.02, THREAD_Z), Vector3(0.0, 0.02, THREAD_Z + 0.08),
		Vector3(-0.9, 0.02, THREAD_Z - 0.06), Vector3(-1.8, 0.02, THREAD_Z + 0.05)]))
	_rope.hide()

	# Lộc's bed (a soft round cushion) and ball.
	B._place_model(self, "dog_bed", DOG_HOME + Vector3(-0.3, 0, 0.4))
	_ball = _holder(BALL_HOME)
	B._place_model(_ball, "ball", Vector3.ZERO)  # origin = the ball's centre
	_ball_use = _add_use(_ball, "Đẩy bóng cho Lộc đuổi", Vector3.ZERO, 0.8, _on_push_ball)

	# Lộc's water bowl: drink / wash your face.
	# (Use points stay where the old shapes' centres were; the models sit on the floor.)
	var bowl := _holder(Vector3(-2.5, 0.06, -2.6))
	B._place_model(bowl, "water_bowl", Vector3(0, -0.06, 0))
	_add_use(bowl, "Uống nước, rửa mặt", Vector3.ZERO, 0.8, _on_water)

	# Mèo Xinh's cushion: pretend to sleep and wait for bà Hằng.
	var cushion := _holder(CAT_CUSHION + Vector3(0, 0.07, 0))
	B._place_model(cushion, "cat_cushion", Vector3(0, -0.07, 0))
	_add_use(cushion, "Nằm giả ngủ, chờ bà Hằng về", Vector3.ZERO, 0.85, _on_nap)

	# Easter egg: family photo on the back wall (hides with the wall).
	var back_wall: MeshInstance3D = _room["back_wall"]
	var photo := Node3D.new()
	photo.position = Vector3(B.PHOTO.x, B.PHOTO.y - B.WALL_HEIGHT / 2, 0.1)
	back_wall.add_child(photo)
	B._place_model(photo, "photo_frame", Vector3(0, 0, -0.025))  # back on the wall surface
	_add_use(photo, "Ngắm ảnh cả nhà", Vector3(0, -0.45, 0.3), 0.9,
		func() -> void: hud.toast("Mèo Xinh, Lộc, bà Hằng và Mr. Thanh. Ai cũng cười... trừ Lộc."))

