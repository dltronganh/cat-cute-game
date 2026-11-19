class_name CatController
extends CharacterBody3D
## Mèo Xinh: walk, jump up, jump down. Movement is relative to the
## camera, so "up" always walks away from the viewer.
##
## Comfort helpers for the high camera angle:
## - **Jump assist:** the kitchen lists "perches" (named spots on top of
##   furniture). The best reachable one near the cat gets a yellow ring and an
##   on-screen hint; Space jumps along a high arc that lands exactly on it.
##   With no perch in reach, Space is a normal jump.
## - **Silhouette:** when furniture hides the cat, a glowing silhouette shows through.
## - **Blob shadow** under the cat, to judge height.
##
## Collision is a vertical cylinder, so it is the same whichever way the cat
## faces: the cat model never sinks into furniture. The model is
## kept inside that cylinder (except the thin tail tip).
##
## The cat also carries its own evidence: [member mouth_dirty]
## shows a yellow patch on its mouth. No text tells the player about it.


const SPEED := 3.6
## Normal (unassisted) jump: ~1.1 m high with GRAVITY 14.
const JUMP_VELOCITY := 5.6
const GRAVITY := 14.0
const TURN_SPEED := 12.0
## Collision cylinder: the whole model fits inside this radius.
const BODY_RADIUS := 0.3
const BODY_HEIGHT := 0.42
## A perch is reachable from this height above the cat...
const PERCH_MIN_RISE := 0.2
## ...up to this. 0.95 m: counters and the washing machine are reachable from
## the floor; the table (1.0 m) needs the stool first.
const PERCH_MAX_RISE := 0.95
## ...and within this horizontal distance.
const PERCH_MAX_DIST := 1.8
## Assisted jumps fly this much higher than the perch, to clear its edge.
const ASSIST_CLEARANCE := 0.45

## Set by the kitchen; used to turn stick input into world directions.
var camera_rig: CameraRig
## Landing spots: Array of {"pos": Vector3 (top surface), "name": String}.
var perches: Array[Dictionary] = []
## Physics bodies that never hide the cat (the walls: the near ones are hidden).
var occlusion_exclude: Array[RID] = []
## False during cutscenes.
var input_enabled: bool = true
## Name of the perch Space will jump onto right now ("" = none). Read by the HUD.
var target_perch_name: String = ""
## Fish on the cat's mouth. Bà Hằng sees this at once.
var mouth_dirty: bool = false:
	set(value):
		mouth_dirty = value
		if _mouth:
			_mouth.visible = value

var _model: Node3D
var _mouth: MeshInstance3D
var _shadow: MeshInstance3D
var _ray: RayCast3D
var _marker: MeshInstance3D
var _silhouette_mat: StandardMaterial3D
var _target: Dictionary = {}
var _assist_target := Vector3.ZERO
var _assisted_time_left := 0.0  # > 0 while flying an assisted jump
# Animation: the Blender rig's AnimationPlayer, chosen from what the
# cat is actually doing (measured movement, so tweened cutscenes animate too).
var _anim: AnimationPlayer
var _last_pos := Vector3.ZERO
var _was_airborne := false
var _one_shot := ""      # "jump" / "land" playing to the end before going on
var _held_anim := ""     # set by cutscenes (e.g. "cower"): stays until cleared
var _speed := 0.0        # smoothed horizontal speed (m/s)
var _off_floor_steps := 0
var _step_dist := 0.0    # metres walked since the last paw-step sound
## Distance between two paw-step sounds (metres).
const STEP_EVERY := 0.22
var _eyes_closed := false


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = BODY_RADIUS
	cyl.height = BODY_HEIGHT
	shape.shape = cyl
	shape.position.y = BODY_HEIGHT / 2.0
	add_child(shape)
	_build_model()
	_build_shadow()
	_build_marker()
	_last_pos = global_position


# ------------------------------------------------------------------ animation

## Walk below this speed (m/s), run above it.
const RUN_FROM := 1.8
## The speeds the walk and run cycles were animated for (feet roughly planted).
const WALK_SPEED_REF := 0.6
const RUN_SPEED_REF := 3.6


## Picks the animation once per physics step (called at the end of
## _physics_process). Speed is measured from the actual movement, smoothed,
## so tweened cutscenes (the chase) animate too; "airborne" means off the
## floor for a few steps (a single step off a ledge edge is not a jump).
func _update_animation(delta: float) -> void:
	if _anim == null or delta <= 0.0:
		return
	var moved := global_position - _last_pos
	_last_pos = global_position
	_speed = lerpf(_speed, Vector2(moved.x, moved.z).length() / delta, 0.35)
	var speed := _speed
	_off_floor_steps = 0 if is_on_floor() else _off_floor_steps + 1
	var airborne := _off_floor_steps > 2
	if _held_anim != "":
		return
	if airborne and not _was_airborne and _one_shot == "":
		_play("air")
	elif not airborne and _was_airborne:
		_play_once("land")
		Sound.play(&"land", -6.0, 0.1)
	_was_airborne = airborne
	if airborne:
		return
	# Soft paw steps: one every STEP_EVERY metres travelled on the floor.
	_step_dist += speed * delta
	if speed > 0.15 and _step_dist > STEP_EVERY:
		_step_dist = 0.0
		Sound.play(&"step", -14.0, 0.15)
	if _one_shot != "":
		return
	if speed < 0.15:
		_play("idle")
	elif speed < RUN_FROM:
		_play("walk", clampf(speed / WALK_SPEED_REF, 0.6, 2.5))
	else:
		_play("run", clampf(speed / RUN_SPEED_REF, 0.7, 1.5))


func _play(anim_name: String, speed_scale := 1.0) -> void:
	_anim.speed_scale = speed_scale
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.15)


func _play_once(anim_name: String) -> void:
	_one_shot = anim_name
	_anim.speed_scale = 1.0
	_anim.play(anim_name, 0.08)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == _one_shot:
		_one_shot = ""
		if anim_name == &"jump":
			_play("air")


## Holds a pose for a cutscene ("cower"...) until [method release_pose].
func hold_pose(anim_name: String) -> void:
	_held_anim = anim_name
	_one_shot = ""
	if _anim:
		_anim.speed_scale = 1.0
		_anim.play(anim_name, 0.1)


## Closes the eyes for sleeping / napping, or opens them.
func set_eyes_closed(closed: bool) -> void:
	_eyes_closed = closed
	ToyModels.set_cat_eyes_closed(_model, closed)


## True while the cat's eyes are closed.
func eyes_closed() -> bool:
	return _eyes_closed


## The animation playing now ("" if the model has none). For dev checks.
func current_animation() -> String:
	return String(_anim.current_animation) if _anim else ""


## Back to the automatic idle/walk/run choice.
func release_pose() -> void:
	_held_anim = ""


func _physics_process(delta: float) -> void:
	velocity.y -= GRAVITY * delta if not is_on_floor() else 0.0
	if _assisted_time_left > 0.0:
		_assisted_time_left -= delta
		if is_on_floor() and velocity.y <= 0.0:
			_assisted_time_left = 0.0  # landed
		else:
			_steer_assisted_jump()
	var input := Vector2.ZERO
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := camera_rig.right_flat() * input.x - camera_rig.forward_flat() * input.y
	if _assisted_time_left <= 0.0:
		if dir.length() > 0.05:
			dir = dir.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), TURN_SPEED * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED * 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, SPEED * 10.0 * delta)
	_pick_target(dir)
	if input_enabled and Input.is_action_just_pressed("jump") and is_on_floor():
		_jump()
	move_and_slide()
	_update_animation(delta)
	_update_shadow()
	_update_silhouette()


## Puts the cat at [param pos], standing still. Does not clean the mouth.
func reset_to(pos: Vector3) -> void:
	position = pos
	velocity = Vector3.ZERO
	_assisted_time_left = 0.0


## Dev checks: picks the best perch while steering towards [param steer] and
## does an assisted jump onto it, exactly as Space would. Returns the perch
## name, or "" if none was in reach (then nothing happens).
func assisted_jump_toward(steer: Vector3) -> String:
	_pick_target(steer)
	if _target.is_empty():
		return ""
	_jump()
	return _target["name"]


## Direction the cat is facing, on the ground plane.
func facing() -> Vector3:
	return Vector3(sin(_model.rotation.y), 0.0, cos(_model.rotation.y))


# ------------------------------------------------------------------ jumping

func _jump() -> void:
	Sound.play(&"jump", -6.0, 0.08)
	if _anim:
		_play_once("jump")
	if _target.is_empty():
		velocity.y = JUMP_VELOCITY
		return
	# Leap straight up to (perch height + clearance); _steer_assisted_jump()
	# only starts moving sideways once the cat is above the perch's edge, so it
	# never bumps into the side of the table or counter.
	_assist_target = _target["pos"]
	var rise := _assist_target.y - position.y
	var apex := maxf(rise, 0.0) + ASSIST_CLEARANCE
	velocity = Vector3(0.0, sqrt(2.0 * GRAVITY * apex), 0.0)
	var flat := Vector3(_assist_target.x - position.x, 0.0, _assist_target.z - position.z)
	_model.rotation.y = atan2(flat.x, flat.z)
	_assisted_time_left = 2.0  # safety timeout; normally ends on landing


## Each frame of an assisted jump: hold still sideways until above the perch
## top, then aim the sideways speed so the fall ends exactly on the perch.
func _steer_assisted_jump() -> void:
	var above := position.y - _assist_target.y
	if above < 0.05:
		if velocity.y > 0.0:
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			_assisted_time_left = 0.0  # fell short (e.g. bumped a shelf): give control back
		return
	# Time left until we fall back down to the perch height.
	var disc := velocity.y * velocity.y + 2.0 * GRAVITY * above
	var time_left := maxf((velocity.y + sqrt(disc)) / GRAVITY, 0.05)
	velocity.x = (_assist_target.x - position.x) / time_left
	velocity.z = (_assist_target.z - position.z) / time_left


## Chooses the perch Space will jump onto: reachable height, within range,
## preferring the one closest to where the player is steering (or facing).
func _pick_target(steer: Vector3) -> void:
	_target = {}
	if is_on_floor() and _assisted_time_left <= 0.0 and input_enabled:
		var prefer := steer.normalized() if steer.length() > 0.05 else facing()
		var best_score := INF
		for perch in perches:
			var p: Vector3 = perch["pos"]
			var rise := p.y - position.y
			if rise < PERCH_MIN_RISE or rise > PERCH_MAX_RISE:
				continue
			var flat := Vector3(p.x - position.x, 0.0, p.z - position.z)
			var d := flat.length()
			if d > PERCH_MAX_DIST:
				continue
			# Closer is better; in front of the cat is much better.
			var score := d - 0.9 * (flat.normalized().dot(prefer) if d > 0.05 else 1.0)
			if score < best_score:
				best_score = score
				_target = perch
	target_perch_name = _target.get("name", "")
	_marker.visible = not _target.is_empty()
	if _marker.visible:
		_marker.global_position = (_target["pos"] as Vector3) + Vector3(0, 0.02, 0)


# ------------------------------------------------------------------ visuals

## Caught! (fail scene): turns to [param camera_pos], crouches down small and
## trembles, with big innocent eyes (the HUD adds the speech bubble).
func cower(camera_pos: Vector3) -> void:
	var flat := Vector3(camera_pos.x - global_position.x, 0.0, camera_pos.z - global_position.z)
	if flat.length() > 0.01:
		_model.rotation.y = atan2(flat.x, flat.z)
	hold_pose("cower")  # crouched low, tail drooping (the rig's animation)
	Sound.play(&"meow", 0.0)
	var shake := create_tween().set_loops(10)
	shake.tween_property(_model, "rotation:z", 0.06, 0.06)
	shake.tween_property(_model, "rotation:z", -0.06, 0.06)


## Turns the model to look towards [param target] (e.g. the camera).
func face_point(target: Vector3) -> void:
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() > 0.01:
		_model.rotation.y = atan2(flat.x, flat.z)


## Jolts awake (the "only a dream" wake-up): a quick startled hop of the model.
func startle() -> void:
	var t := create_tween()
	t.tween_property(_model, "position:y", 0.3, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(_model, "position:y", 0.0, 0.18).set_ease(Tween.EASE_IN)


## Rebuilds the cat's look (after the coat changed), keeping where it
## faces and whether its mouth is dirty.
func rebuild_model() -> void:
	var facing_y := _model.rotation.y
	_model.queue_free()
	_build_model()
	_model.rotation.y = facing_y


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	# The look lives in ToyModels; it stays within BODY_RADIUS so nothing pokes into furniture.
	var parts := ToyModels.build_cat(_model)
	# A small yellow patch on the mouth: the only hint that it needs washing.
	_mouth = parts["mouth"]
	_mouth.visible = mouth_dirty
	ToyModels.set_cat_eyes_closed(_model, _eyes_closed)
	_anim = parts["anim"]
	if _anim:
		_anim.animation_finished.connect(_on_animation_finished)
		if _held_anim != "":
			_anim.play(_held_anim)
		else:
			_anim.play("idle")
	# Silhouette pass drawn on top of everything, faded in only when hidden.
	_silhouette_mat = StandardMaterial3D.new()
	_silhouette_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_silhouette_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_silhouette_mat.no_depth_test = true
	_silhouette_mat.render_priority = 1
	_silhouette_mat.albedo_color = Color(1.0, 0.82, 0.4, 0.0)
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh != _mouth:
			(mesh.material_override as StandardMaterial3D).next_pass = _silhouette_mat


func _build_shadow() -> void:
	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, -20, 0)
	_ray.position.y = 0.1
	add_child(_ray)
	_shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = BODY_RADIUS
	disc.bottom_radius = BODY_RADIUS
	disc.height = 0.01
	_shadow.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = mat
	_shadow.top_level = true  # stays flat on the ground, does not follow the jump
	add_child(_shadow)


func _build_marker() -> void:
	_marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.3
	_marker.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffd166")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = mat
	_marker.top_level = true
	_marker.visible = false
	add_child(_marker)


func _update_shadow() -> void:
	_ray.force_raycast_update()
	_shadow.visible = _ray.is_colliding()
	if _shadow.visible:
		_shadow.global_position = _ray.get_collision_point() + Vector3(0, 0.012, 0)


func _update_silhouette() -> void:
	var cam := camera_rig.camera
	var to := global_position + Vector3(0, 0.25, 0)
	var from := to + cam.global_basis.z * 30.0  # orthographic: rays are parallel to the view
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var exclude: Array[RID] = [get_rid()]
	exclude.append_array(occlusion_exclude)
	query.exclude = exclude
	var hidden := not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	var c := _silhouette_mat.albedo_color
	c.a = move_toward(c.a, 0.6 if hidden else 0.0, 0.1)
	_silhouette_mat.albedo_color = c
