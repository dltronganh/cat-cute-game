class_name MondayStory
extends Node
## The told parts of Monday (no player control): the start screen and the
## opening (bà Hằng leaves for work), her coming home at 17:00 (dusk, phone
## call to Mr. Thanh, inspection, verdict), the two endings with their
## two-circle close-ups, the punishment night and the "only a dream" replay.
##
## Lives apart from monday_kitchen.gd (the room, the props, the play loop) so
## each file tells one part of the day. Works on the kitchen through [member k].

## The kitchen whose day this is.
var k: MondayKitchen


## Bà Hằng comes home (nap or 17:00): time flies to dusk if the cat napped
## early, she phones Mr. Thanh, inspects the scene thinking aloud, then
## blames Lộc or catches the cat. Ends in [code]Phase.RESULT[/code].
func owner_comes_home() -> void:
	if k.phase != MondayKitchen.Phase.PLAY:
		return
	k.phase = MondayKitchen.Phase.OWNER
	k.cat.input_enabled = false
	k.hud.set_prompt("", "")
	k.hud.show_skin_button(false)  # not during the cutscenes
	var flat_dist := Vector2(k.cat.position.x - k.B.TABLE_CENTER.x, k.cat.position.z - k.B.TABLE_CENTER.z).length()
	k.state[k.Fish.CAT_NEAR_SCENE] = flat_dist < k.NEAR_SCENE
	k.state[k.Fish.CAT_MOUTH_DIRTY] = k.cat.mouth_dirty

	# Napped early? Time flies to 17:00 before she comes home.
	if k.time_left > 0.0:
		k.hud.toast("Zzz... thời gian trôi...")
		Sound.play(&"whoosh", -4.0)
		var t := create_tween()
		t.tween_method(k._show_time_of_day, k.time_left, 0.0, 2.5).set_trans(Tween.TRANS_SINE)
		_dusk(2.5)
		await t.finished
		k.time_left = 0.0
	else:
		_dusk(1.5)

	k.owner_npc.position = k.B.DOOR + Vector3(0.4, 0, 0)
	k.owner_npc.show()
	Sound.play(&"door")
	k.hud.show_thought("Cạch! ...Mẹ về rồi đây!")
	await k.owner_npc.walk_to(k.OWNER_SPOT)
	await k._wait(0.6)
	k.hud.show_thought("Trời đất ơi nhà cửa gì thế này... Khoan, gọi thằng Thanh cái đã.")
	Sound.play(&"phone", -6.0)
	await k._read(1.8)
	# The phone call to Mr. Thanh: a random line, never the same twice in a row.
	k.owner_npc.set_on_phone(true)
	var lines := LineList.load_lines(k.CALL_LINES_PATH)
	k.hud.show_call(lines[LinePicker.pick_index(&"mr_thanh_calls", lines.size(), k._rng)])
	await k._read(3.6)
	k.owner_npc.set_on_phone(false)
	k.hud.show_thought("Rồi, cúp máy. Giờ để mẹ xem nhà...")
	await k._read(1.3)
	k.owner_npc.walk_to(k.B.TABLE_CENTER + Vector3(-0.9, 0, 0.9))

	var verdict := OwnerReasoner.judge(FishCase.build_clues(k.state))
	for thought in verdict.thoughts:
		k.hud.show_thought(thought)
		await k._read(1.7)
	k.hud.hide_thought()
	match verdict.suspect:
		OwnerReasoner.Suspect.DOG:
			await _dog_blamed()
		OwnerReasoner.Suspect.CAT:
			await _cat_caught()
		_:
			k.hud.show_result("\"Ủa, hôm nay ngoan dữ vậy?\"\nMèo Xinh chưa nghịch gì cả.\n\n[Enter] chơi lại")
	k.phase = MondayKitchen.Phase.RESULT


## Lộc gets the blame: she chases him around the table like she
## would the cat, he cries "huhu", the circle closes on him, then bedtime.
func _dog_blamed() -> void:
	k.owner_npc.face(k.dog.position)
	Sound.play(&"shout")
	k.hud.show_shout("LỘC!!!")
	await k._read(2.0)
	k.hud.hide_shout()
	await _chase(k.dog, 0.0)
	k.dog.cry(_toward_camera(k.dog))
	Sound.play(&"huhu")
	k.hud.show_emote(k.rig.camera.unproject_position(k.dog.global_position + Vector3(0, 0.5, 0)), "Huhu... không phải con mà...", false, Color("d6eaff"))
	await k._read(1.6)
	k.hud.hide_emotes()
	# Two circles like the fail scene, roles swapped: Lộc crying, then
	# Mèo Xinh on the cushion, grinning at the camera with a happy little hop.
	k.cat.set_eyes_closed(false)  # wakes from the nap to grin
	k.cat.face_point(_toward_camera(k.cat))
	get_tree().create_timer(0.9 + 1.6 * KitchenHud.READ_PACE).timeout.connect(func() -> void:
		k.cat.startle()
		Sound.play(&"hihi"))
	var cam := k.rig.camera
	await k.hud.play_iris(cam.unproject_position(k.dog.global_position + Vector3(0, 0.5, 0)),
		cam.unproject_position(k.cat.global_position + Vector3(0, 0.35, 0)),
		"Hu hu hu... oan cho con quá...", "Hi hi~  Cá ngon ghê á!", Color("d6eaff"), KitchenHud.YELLOW)
	# Bedtime: the three of them in the bedroom.
	(k._room["bedroom_camera"] as Camera3D).make_current()
	k.hud.set_clock("Tối Thứ Hai  ·  22:00")
	k.hud.show_tasks(false)
	await k.hud.fade_to(0.0, 1.2)
	k.hud.toast("Zzz...  Zzz...  Zzz...")
	await k._read(1.6)
	Sound.play(&"win")
	k.hud.show_result("Hết ngày Thứ Hai!  Qua màn.\nLộc bị la, nhưng tối vẫn ngủ chung với Mèo Xinh cạnh bà Hằng.\n[Enter] chơi lại")


## The cat is caught: chase, then two circles: the cat,
## and Lộc looking straight at the camera, gloating.
func _cat_caught() -> void:
	k.owner_npc.face(k.cat.position)
	k.cat.set_eyes_closed(false)  # caught napping: eyes wide open
	Sound.play(&"shout")
	k.hud.show_shout("MÈO XINH!!!")
	await k._read(1.4)
	k.hud.hide_shout()
	await _chase(k.cat, 0.2)
	# The cat's own "huhu" moment: crouched, trembling, all innocent eyes.
	k.cat.cower(_toward_camera(k.cat))
	k.hud.show_emote(k.rig.camera.unproject_position(k.cat.global_position + Vector3(0, 0.35, 0)), "MEOOO! Con có làm gì đâu!", true)
	await k._read(1.6)
	k.hud.hide_emotes()
	k.dog.face(_toward_camera(k.dog))
	# Start gloating just as the second circle opens on him.
	get_tree().create_timer(0.9 + 1.6 * KitchenHud.READ_PACE).timeout.connect(func() -> void:
		k.dog.gloat(_toward_camera(k.dog))
		Sound.play(&"bark", 0.0, 0.1))
	var cam := k.rig.camera
	await k.hud.play_iris(cam.unproject_position(k.cat.global_position + Vector3(0, 0.35, 0)),
		cam.unproject_position(k.dog.global_position + Vector3(0, 0.5, 0)))
	await _punishment_night()


## Late afternoon: the sunlight through the window softens and turns
## golden, and the warm lamps inside come on, over [param seconds].
func _dusk(seconds: float) -> void:
	Sound.music(&"dusk", seconds + 1.0)  # the slower, warmer evening tune
	var t := create_tween().set_parallel(true)
	var sunbeam: SpotLight3D = k._room["sunbeam"]
	t.tween_property(sunbeam, "light_energy", 0.9, seconds)
	t.tween_property(sunbeam, "light_color", Color("ffb36b"), seconds)
	var sun := k.find_child("Sun", true, false) as DirectionalLight3D
	if sun:
		t.tween_property(sun, "light_energy", 0.35, seconds)
		t.tween_property(sun, "light_color", Color("ffd2a1"), seconds)
	for lamp: OmniLight3D in k._room["lamps"]:
		t.tween_property(lamp, "light_energy", lamp.get_meta("dusk_energy", 1.0), seconds)
	# Cool base, warm pools: the room's ambient light and the sky in
	# the window turn dusk-blue, so the warm lamps stand out instead of
	# brightening everything.
	var we: WorldEnvironment = null
	for node in k.get_children():
		if node is WorldEnvironment:
			we = node
	if we:
		t.tween_property(we.environment, "ambient_light_color", Color("8a93b8"), seconds)
		t.tween_property(we.environment, "ambient_light_energy", 0.4, seconds)
	var glass := k.find_child("WindowGlass", true, false) as MeshInstance3D
	if glass:
		t.tween_property(glass.material_override, "albedo_color", Color("6f7db0"), seconds)
	for shade in get_tree().get_nodes_in_group("lamp_shades"):
		var mat := (shade as MeshInstance3D).material_override as StandardMaterial3D
		t.tween_property(mat, "emission_energy_multiplier", shade.get_meta("dusk_glow", 0.5), seconds)


## Fail night (part A): the cat is punished and sleeps alone on a
## cushion on the floor, while Lộc sleeps on the bed next to bà Hằng and winks.
## The replay then starts with the cat waking up from the dream (part B).
func _punishment_night() -> void:
	var cat_bed: Node3D = k._room["bedroom_cat"]
	cat_bed.position = Vector3(1.35, 0.21, 1.05)  # on the floor cushion at the foot of the bed
	(k._room["bedroom_floor_bed"] as Node3D).show()
	var cam := k._room["bedroom_camera"] as Camera3D
	cam.make_current()
	k.hud.set_clock("Tối Thứ Hai  ·  22:00")
	k.hud.show_tasks(false)
	await k.hud.fade_to(0.0, 1.2)
	await k._wait(0.5)
	# Lộc, comfy in the cat's spot, winks at the camera.
	ToyModels.set_dog_eyes_closed(k._room["bedroom_dog_eyes"], false)  # Lộc is awake and smug
	ToyModels.set_cat_eyes_closed(cat_bed, false)  # the cat grumbles first, then sleeps
	var eye: MeshInstance3D = (k._room["bedroom_dog_eyes"] as Array)[1]
	var wink := create_tween().set_loops(3)
	wink.tween_property(eye, "scale:y", 0.15, 0.12)
	wink.tween_interval(0.35)
	wink.tween_property(eye, "scale:y", 1.0, 0.12)
	wink.tween_interval(0.3)
	var dog_bed: Node3D = k._room["bedroom_dog"]
	k.hud.show_emote(cam.unproject_position(dog_bed.global_position + Vector3(0, 0.2, 0)), "Hí hí~ giường êm ghê á!", true, KitchenHud.YELLOW)
	await k._read(2.2)
	k.hud.hide_emotes()
	k.hud.show_emote(cam.unproject_position(cat_bed.global_position + Vector3(0, 0.1, 0)), "Hừm... mai mình sẽ làm lại!")
	await k._read(2.4)
	k.hud.hide_emotes()
	ToyModels.set_cat_eyes_closed(cat_bed, true)
	MondayKitchen._wake_from_dream = true
	Sound.play(&"fail")
	k.hud.show_result("Bị bắt rồi! Tối nay Mèo Xinh bị phạt ngủ dưới đất.\n[Enter] ngủ một giấc rồi thử lại", true)


## Start screen, first play of a session only: the kitchen idles
## behind it; "Chơi" frees it and starts the opening scene.
func show_title() -> void:
	k.phase = MondayKitchen.Phase.OWNER  # the clock and the controls wait
	k._show_time_of_day(k.time_left)
	k.cat.input_enabled = false
	k.hud.show_skin_button(false)
	var title := TitleMenu.new()
	k.add_child(title)
	title.set_skin_label(CatSkins.display_name(ToyModels.cat_skin))
	title.skin_pressed.connect(func() -> void:
		k._on_change_skin()
		title.set_skin_label(CatSkins.display_name(ToyModels.cat_skin)))
	title.play_pressed.connect(func() -> void:
		title.queue_free()
		opening())


## Opening scene (about 15 s, first play only): bà Hằng leaves for
## work and warns about the fish; the cat eyes it. Tells a new player who is
## who and what the fish is, before the clock starts.
func opening() -> void:
	k.phase = MondayKitchen.Phase.OWNER  # the clock and the controls wait
	k._show_time_of_day(k.time_left)
	k.cat.input_enabled = false
	k.hud.show_skin_button(false)
	k.cat.face_point(k.B.TABLE_CENTER)
	k.owner_npc.position = k.B.TABLE_CENTER + Vector3(-1.0, 0.0, 1.1)
	k.owner_npc.face(k.cat.position)
	k.owner_npc.show()
	await k._wait(0.6)
	k.hud.show_thought("Mẹ đi làm nha! Cá trên bàn là để tối nay ăn đó, cấm đụng vô!")
	await k._read(2.4)
	k.hud.show_thought("Lộc, trông nhà cho mẹ. Mèo Xinh, ngoan nha. 5 giờ chiều mẹ về.")
	await k._read(2.4)
	k.hud.hide_thought()
	await k.owner_npc.walk_to(k.B.DOOR + Vector3(0.4, 0, 0))
	Sound.play(&"door")
	k.owner_npc.hide()
	await k._wait(0.5)
	k.cat.face_point(_toward_camera(k.cat))
	k.hud.show_emote(k.rig.camera.unproject_position(k.cat.global_position + Vector3(0, 0.35, 0)), "Cá... trên bàn...  hí hí~", false, KitchenHud.YELLOW)
	Sound.play(&"hihi")
	await k._read(1.8)
	k.hud.hide_emotes()
	k.hud.toast("Làm theo danh sách việc ở góc trên bên trái nhé!")
	k.hud.show_skin_button(true)
	k.cat.input_enabled = true
	k.phase = MondayKitchen.Phase.PLAY


## Replay after being caught (part B): the cat jolts awake on its
## cushion on Monday morning. "Phew... it was only a dream!"
func dream_wake_up() -> void:
	k.phase = MondayKitchen.Phase.OWNER  # the clock and the controls wait for the wake-up
	k._show_time_of_day(k.time_left)
	k.cat.input_enabled = false
	k.cat.reset_to(k.CAT_CUSHION + Vector3(0, 0.25, 0))
	k.cat.set_eyes_closed(true)  # still asleep
	k.hud.toast("Zzz...")
	await k._wait(1.0)
	k.cat.set_eyes_closed(false)  # jolts awake
	k.cat.startle()
	Sound.play(&"meow", -4.0)
	await k._wait(0.2)
	k.hud.show_emote(k.rig.camera.unproject_position(k.cat.global_position + Vector3(0, 0.35, 0)), "Phù... may quá, chỉ là mơ!")
	await k._read(2.2)
	k.hud.hide_emotes()
	k.hud.toast("Sáng Thứ Hai. Làm lại nào!")
	k.cat.input_enabled = true
	k.phase = MondayKitchen.Phase.PLAY


## Bà Hằng chases [param who] once around the table. [param height] lifts the
## runner's path (the cat's origin sits a bit above the floor).
func _chase(who: Node3D, height: float) -> void:
	var c := k.B.TABLE_CENTER
	var loop: Array[Vector3] = [c + Vector3(1.4, height, 1.3), c + Vector3(1.4, height, -1.0), c + Vector3(-1.7, height, -1.0), c + Vector3(-1.7, height, 1.4), c + Vector3(1.4, height, 1.4)]
	var run := create_tween()
	for p in loop:
		run.tween_callback(func() -> void:
			if who == k.dog:
				k.dog.face(p))
		run.tween_property(who, "position", p, 0.55)
	# She follows the same loop a moment later, then stops BEHIND the runner as
	# seen from the camera, so she never hides the runner's face in the circle.
	var follow := create_tween()
	follow.tween_interval(0.35)
	for p in loop:
		follow.tween_callback(k.owner_npc.face.bind(p))
		follow.tween_property(k.owner_npc, "position", Vector3(p.x, 0.0, p.z), 0.55)
	var last: Vector3 = loop[-1]
	var behind := Vector3(last.x, 0.0, last.z) - k.rig.toward_camera_flat() * 1.1
	follow.tween_property(k.owner_npc, "position", behind, 0.4)
	await run.finished
	await follow.finished
	k.owner_npc.face(who.position)


## A point far towards the camera from [param who], for "look at the camera".
func _toward_camera(who: Node3D) -> Vector3:
	return who.global_position + k.rig.toward_camera_flat() * 5.0

