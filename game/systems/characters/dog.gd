class_name Dog
extends Node3D
## Lộc, the poor dog. Runs after his ball, trips, gets chased, and has a few
## reactions: gloat (when the cat is caught), cry "huhu" (when he is
## blamed), stumble. His tail wags a little all the time.
## No physics: he moves with tweens along straight lines.


## Metres per second when chasing the ball (a bit slower, easier to follow).
const RUN_SPEED := 2.4

## Metres covered by one full trot cycle (all four legs), so the steps match the speed.
const STRIDE := 0.55

var _model: Node3D
var _torso: Node3D
var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _ears: Array[Node3D] = []
var _tween: Tween
var _wag_speed := 6.0
var _time := 0.0
# Movement: measured from how far he actually moved.
var _last_pos := Vector3.ZERO
var _speed := 0.0
var _gait := 0.0          # 0..1 through the trot cycle
var _head_held := false   # crying or gloating: the reaction keeps head and ears posed


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	var parts := ToyModels.build_dog(_model)
	_torso = parts["torso"]
	_legs = parts["legs"]
	_head = parts["head"]
	_tail = parts["tail"]
	_ears = parts["ears"]
	_last_pos = global_position


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	var moved := global_position - _last_pos
	_last_pos = global_position
	_speed = lerpf(_speed, Vector2(moved.x, moved.z).length() / delta, 0.25)
	var moving := clampf(_speed / 1.2, 0.0, 1.0)  # 0 = standing, 1 = full trot
	_gait = fmod(_gait + delta * _speed / STRIDE, 1.0)
	# Trot: diagonal pairs move together (front left + back right, then the others).
	var swing := 0.55 * moving
	for i in _legs.size():
		var phase := 0.0 if i == 0 or i == 3 else 0.5
		_legs[i].rotation.x = sin(TAU * (_gait + phase)) * swing
	# The body bobs twice a cycle; standing still, he breathes slowly.
	var bob := absf(sin(TAU * _gait)) * 0.025 * moving
	var breathe := sin(_time * 2.2) * 0.006 * (1.0 - moving)
	_torso.position.y = bob + breathe
	if not _head_held:
		_head.rotation.x = sin(TAU * _gait * 2.0) * 0.06 * moving + sin(_time * 1.3) * 0.03 * (1.0 - moving)
		for ear in _ears:  # floppy ears trail back and bounce when he runs; a twitch now and then
			var twitch := 0.25 if fmod(_time + ear.position.x, 4.0) < 0.12 else 0.0
			ear.rotation.x = -0.45 * moving + sin(TAU * _gait * 2.0 + 0.6) * 0.25 * moving + twitch
	# Tail: wags faster and wider when he runs (unless crying, see cry()).
	var wag := _wag_speed * (1.0 + moving)
	_tail.rotation.y = sin(_time * wag) * (0.5 if _wag_speed > 0.0 else 0.0)


## Runs in a straight line to [param target], then calls [param on_arrive].
func run_to(target: Vector3, on_arrive: Callable, speed: float = RUN_SPEED) -> void:
	if _tween:
		_tween.kill()
	face(target)
	var flat := Vector3(target.x - position.x, 0.0, target.z - position.z)
	_tween = create_tween()
	_tween.tween_property(self, "position", target, maxf(0.2, flat.length() / speed))
	_tween.tween_callback(on_arrive)


## Turns to look at [param point] (on the ground plane).
func face(point: Vector3) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		_model.rotation.y = atan2(d.x, d.z)


## A little trip when he runs into the thread.
func stumble() -> void:
	var t := create_tween()
	t.tween_property(_model, "rotation:z", 0.5, 0.15)
	t.tween_property(_model, "rotation:z", 0.0, 0.3)


## Looks straight at the camera at [param camera_pos], then bounces with a
## wagging tail and pricked ears: "ha, she caught the cat!".
func gloat(camera_pos: Vector3) -> void:
	face(camera_pos)
	_head_held = true
	_head.rotation.x = -0.25  # chin up, proud
	_wag_speed = 22.0
	for ear in _ears:
		ear.rotation.z = 0.0
	var t := create_tween()
	for i in 3:
		t.tween_property(_model, "position:y", 0.22, 0.14).set_ease(Tween.EASE_OUT)
		t.tween_property(_model, "position:y", 0.0, 0.14).set_ease(Tween.EASE_IN)


## Ears down, head down, a sad little shiver: "huhu".
func cry(camera_pos: Vector3) -> void:
	face(camera_pos)
	_head_held = true
	_wag_speed = 0.0
	_tail.rotation.x = 0.9  # tail tucked
	_head.rotation.x = 0.35  # head down
	for ear in _ears:
		ear.rotation.z = 0.4 * sign(ear.position.x)
	var t := create_tween().set_loops(6)
	t.tween_property(_model, "rotation:z", 0.05, 0.08)
	t.tween_property(_model, "rotation:z", -0.05, 0.08)
