class_name MondayDevChecks
extends Node
## Headless self-checks of the Monday kitchen, run by tools/check_prototype.ps1
## (e.g. `godot --headless --path . -- --climbtest`), plus the debug-build
## autoplay keys F9 (winning chain) and F10 (get caught).
##
## Kept apart from the day itself (monday_kitchen.gd) so the game code reads
## as the story it tells. Each check drives the real room through [member k]
## and prints PASS/FAIL lines, then quits with exit code 0 (all passed) or 1.
## Every bug found in play gets a check here, so it cannot come back unnoticed.

## Command-line flag → check. [method run] starts the one that was asked for.
const CHECKS := {
	"--autotest": "autotest_and_quit", "--climbtest": "climbtest", "--walktest": "walktest",
	"--animtest": "animtest", "--shot": "screenshot", "--failtest": "failtest",
	"--keytest": "keytest", "--openingtest": "openingtest", "--escapetest": "escapetest",
	"--menutest": "menutest",
}

## The kitchen being checked.
var k: MondayKitchen


## Starts the check named by a flag in [param args] (the user command-line
## arguments). Returns false when no check was asked for (normal play).
func run(args: PackedStringArray) -> bool:
	for flag: String in CHECKS:
		if flag in args:
			call(CHECKS[flag])
			return true
	return false


## `--autotest`: plays the winning chain, prints the verdict, quits.
func autotest_and_quit() -> void:
	autotest(true)


## `godot --headless --path . -- --autotest`: plays the winning chain by
## using each object in order, prints the verdict and quits (if [param quit]).
func autotest(quit: bool) -> void:
	await get_tree().process_frame
	var by_prompt := {}
	for it in k.interactables:
		by_prompt[it.prompt] = it
	for prompt in ["Ăn vụng cá", "Hất đầu dây cuộn chỉ xuống", "Uống nước, rửa mặt", "Đẩy bóng cho Lộc đuổi"]:
		print("AUTOTEST use: ", prompt)
		by_prompt[prompt].use()
	await k._wait(5.0)  # Lộc runs, catches the thread, drags it; the plate slides and falls
	print("AUTOTEST state before nap: ", k.state)
	by_prompt["Nằm giả ngủ, chờ bà Hằng về"].use()
	while k.phase != MondayKitchen.Phase.RESULT:
		await get_tree().process_frame
	var verdict := OwnerReasoner.judge(FishCase.build_clues(k.state))
	print("AUTOTEST verdict: ", OwnerReasoner.Suspect.keys()[verdict.suspect], "  thoughts: ", verdict.thoughts)
	if quit:
		get_tree().quit()


## `godot --headless --path . -- --climbtest`: real physics jumps with the
## assist, from the floor and from the stool. Prints PASS/FAIL per jump, quits.
func climbtest() -> void:
	var tc := k.B.TABLE_CENTER
	var cases := [
		# [start position, steer direction, expected perch, expected landing height]
		[tc + Vector3(-2.3, 0.0, 0.1), Vector3.RIGHT, "ghế đẩu", k.B.STOOL_TOP],
		[null, Vector3.RIGHT, "bàn ăn", k.B.TABLE_TOP],  # null = continue from where we are
		[Vector3(2.4, 0.0, -2.4), Vector3.FORWARD, "quầy bếp", k.B.COUNTER_TOP],
		[Vector3(3.5, 0.0, -2.5), Vector3.FORWARD, "máy giặt", k.B.WASHER_TOP],
		[Vector3(-2.6, 0.0, -1.3), Vector3.LEFT, "tủ gỗ", k.B.SIDEBOARD_TOP],
	]
	var failures := 0
	for c in cases:
		if c[0] != null:
			k.cat.reset_to(c[0])
		for i in 20:  # settle on the ground
			await get_tree().physics_frame
		var got := k.cat.assisted_jump_toward(c[1])
		for i in 120:
			await get_tree().physics_frame
		var ok: bool = got == c[2] and absf(k.cat.position.y - c[3]) < 0.05
		failures += 0 if ok else 1
		print("CLIMBTEST %s  wanted %s @ %.2f, got '%s' @ %.2f" % ["PASS" if ok else "FAIL", c[2], c[3], got, k.cat.position.y])
	print("CLIMBTEST done, %d failed" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Dev check (--escapetest): from the top of the fridge in the back
## corner, the cat keeps jumping into each nearby wall; it must stay inside the
## room (a jump over a wall top once let the cat out of the house).
func escapetest() -> void:
	var failures := 0
	var fridge_top := Vector3(-3.55, 1.9, -3.55)
	for action in ["move_up", "move_left"]:
		k.cat.reset_to(fridge_top)
		for i in 20:
			await get_tree().physics_frame
		Input.action_press(action)
		for hop in 6:
			Input.action_press("jump")
			await get_tree().physics_frame
			Input.action_release("jump")
			for i in 40:
				await get_tree().physics_frame
		Input.action_release(action)
		var p := k.cat.position
		var inside := absf(p.x) < k.B.ROOM_HALF and absf(p.z) < k.B.ROOM_HALF and p.y < k.B.WALL_HEIGHT
		failures += 0 if inside else 1
		print("ESCAPETEST %s  jumping %s from the fridge ends at (%.2f, %.2f, %.2f)" % ["PASS" if inside else "FAIL", action, p.x, p.y, p.z])
	print("ESCAPETEST done, %d failed" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## `godot --headless --path . -- --walktest`: holds each direction for half a
## second and checks the cat really walks. Prints PASS/FAIL, quits.
func walktest() -> void:
	var failures := 0
	for action in ["move_up", "move_right", "move_down", "move_left"]:
		k.cat.reset_to(Vector3(0, 0.1, 1.0))
		for i in 20:
			await get_tree().physics_frame
		var start := k.cat.position
		Input.action_press(action)
		for i in 30:
			await get_tree().physics_frame
		Input.action_release(action)
		var moved := Vector2(k.cat.position.x - start.x, k.cat.position.z - start.z).length()
		var ok := moved > 1.0
		failures += 0 if ok else 1
		print("WALKTEST %s  %s moved %.2f m (y %.2f, on floor %s)" % ["PASS" if ok else "FAIL", action, moved, k.cat.position.y, k.cat.is_on_floor()])
	print("WALKTEST done, %d failed" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Dev check (--keytest): real key presses reach the game. Stands the cat by the
## ball and sends E, then Q, as key events (the headless editor binary is a debug
## build, like the debug web export, so dev-key handling is active too).
func keytest() -> void:
	var failures := 0
	k.cat.reset_to(k.BALL_HOME + Vector3(0.0, 0.1, 0.35))
	for i in 20:
		await get_tree().physics_frame
	var ball_was_ready := k._ball_use.enabled
	_press_key(KEY_E)
	await get_tree().process_frame
	var ok := ball_was_ready and not k._ball_use.enabled
	failures += 0 if ok else 1
	print("KEYTEST %s  E pushes the ball" % ("PASS" if ok else "FAIL"))
	var view_before := k.rig.toward_camera_flat()
	_press_key(KEY_Q)
	for i in 60:
		await get_tree().process_frame
	ok = k.rig.toward_camera_flat().distance_to(view_before) > 0.5
	failures += 0 if ok else 1
	print("KEYTEST %s  Q rotates the camera" % ("PASS" if ok else "FAIL"))
	print("KEYTEST done, %d failed" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Dev check (--menutest): the start screen blocks play until "Chơi";
## then P pauses the day (the clock stops) and P again resumes it.
func menutest() -> void:
	var failures := 0
	k.story.show_title()
	await get_tree().process_frame
	var title := k.find_children("*", "TitleMenu", false, false)
	var ok := title.size() == 1 and k.phase == MondayKitchen.Phase.OWNER and not k.cat.input_enabled
	failures += 0 if ok else 1
	print("MENUTEST %s  start screen up, play waits" % ("PASS" if ok else "FAIL"))
	Engine.time_scale = 8.0
	(title[0] as TitleMenu).play_pressed.emit()
	while k.phase != MondayKitchen.Phase.PLAY:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	ok = not is_instance_valid(title[0]) and k.cat.input_enabled
	failures += 0 if ok else 1
	print("MENUTEST %s  'Chơi' starts the day" % ("PASS" if ok else "FAIL"))
	await get_tree().process_frame
	_press_key(KEY_P)
	var clock_before := k.time_left
	for i in 20:
		await get_tree().process_frame
	ok = get_tree().paused and is_equal_approx(k.time_left, clock_before)
	failures += 0 if ok else 1
	print("MENUTEST %s  P pauses, the clock stops" % ("PASS" if ok else "FAIL"))
	_press_key(KEY_P)
	for i in 20:
		await get_tree().process_frame
	ok = not get_tree().paused and k.time_left < clock_before
	failures += 0 if ok else 1
	print("MENUTEST %s  P again resumes" % ("PASS" if ok else "FAIL"))
	print("MENUTEST done, %d failed" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Dev check: the opening scene ends with bà Hằng gone and the player in
## control, within 30 s of game time (run 8× fast).
func openingtest() -> void:
	Engine.time_scale = 8.0
	var started := Time.get_ticks_msec()
	await k.story.opening()
	var game_seconds := (Time.get_ticks_msec() - started) / 1000.0 * Engine.time_scale
	Engine.time_scale = 1.0
	# The day tune must be playing at full bus level (music was silent on the web).
	var music_ok := Sound.current_tune() == &"day" and AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")) > -1.0
	var ok := k.phase == MondayKitchen.Phase.PLAY and k.cat.input_enabled and not k.owner_npc.visible and game_seconds < 30.0 and music_ok
	print("OPENINGTEST %s  play %s, owner gone %s, music %s, took %.1f s of game time" % ["PASS" if ok else "FAIL", k.phase == MondayKitchen.Phase.PLAY, not k.owner_npc.visible, music_ok, game_seconds])
	get_tree().quit(0 if ok else 1)


func _press_key(key: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


## Dev only: eat the fish and nap without washing, so bà Hằng catches the cat.
func autoplay_fail() -> void:
	for it in k.interactables:
		if it.prompt == "Ăn vụng cá":
			it.use()
	for it in k.interactables:
		if it.prompt == "Nằm giả ngủ, chờ bà Hằng về":
			it.use()


## Dev check (--failtest): plays the losing day to the end (cat caught,
## punishment night) and checks the replay will start with the dream.
func failtest() -> void:
	autoplay_fail()
	var waited := 0.0
	while k.phase != MondayKitchen.Phase.RESULT and waited < 120.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var ok := k.phase == MondayKitchen.Phase.RESULT and MondayKitchen._wake_from_dream and (k._room["bedroom_floor_bed"] as Node3D).visible
	print("FAILTEST %s  result shown %s, dream next %s" % ["PASS" if ok else "FAIL", k.phase == MondayKitchen.Phase.RESULT, MondayKitchen._wake_from_dream])
	get_tree().quit(0 if ok else 1)


## Dev tool (--shot <file.png> [--skin calico|white] [--near]): saves a
## screenshot of the kitchen and quits, so the art can be reviewed in
## the real game without a browser. Needs a window (not --headless). The skin
## is only used for this run, the player's saved choice is not touched.
func screenshot() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[args.find("--shot") + 1]
	if "--skin" in args:
		ToyModels.cat_skin = StringName(args[args.find("--skin") + 1])
		k.cat.rebuild_model()
		k.hud.set_skin_label(CatSkins.display_name(ToyModels.cat_skin))
	k.cat.reset_to(Vector3(0.6, 0.1, 1.6))
	if "--dusk" in args:
		k.story._dusk(0.01)
	if "--near" in args:
		k.rig.camera.size = 2.2  # zoom in on the cat
		k.rig.position = k.cat.position
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT saved ", path)
	get_tree().quit()


## Dev check (--animtest): the cat picks the right animation from
## what it is doing: idle when still, run when moving at full speed, the jump
## or air animation when leaving the floor, idle again after landing.
func animtest() -> void:
	var failures := 0
	k.cat.reset_to(Vector3(0, 0.1, 1.0))
	for i in 30:
		await get_tree().physics_frame
	failures += _anim_check("standing still", ["idle"])
	Input.action_press("move_up")
	for i in 30:
		await get_tree().physics_frame
	failures += _anim_check("running", ["run"])
	Input.action_release("move_up")
	for i in 40:
		await get_tree().physics_frame
	failures += _anim_check("stopped", ["idle"])
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 8:
		await get_tree().physics_frame
	failures += _anim_check("jumping", ["jump", "air"])
	for i in 90:
		await get_tree().physics_frame
	failures += _anim_check("landed", ["idle", "land"])
	print("ANIMTEST done, %d failed" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _anim_check(what: String, allowed: Array) -> int:
	var now := k.cat.current_animation()
	var ok := now in allowed
	print("ANIMTEST %s  %s: playing '%s' (want %s)" % ["PASS" if ok else "FAIL", what, now, allowed])
	return 0 if ok else 1
