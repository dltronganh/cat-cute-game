class_name OwnerNpc
extends Node3D
## Bà Hằng: walks in straight lines, holds her phone up for the call to
## Mr. Thanh, chases whoever she blames.
## Her look comes from ToyModels.build_owner.
##
## No physics; she moves with tweens.

## Metres per second when walking (unhurried).
const WALK_SPEED := 1.8

## Metres covered by one full step cycle (left + right), so the steps match the speed.
const STRIDE := 1.1

var _model: Node3D
var _phone: MeshInstance3D
var _arm: Node3D
var _arm_left: Node3D
var _torso: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _on_phone := false
# Walking: measured from how far she actually moved.
var _last_pos := Vector3.ZERO
var _speed := 0.0
var _gait := 0.0
var _time := 0.0


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	var parts := ToyModels.build_owner(_model)
	_phone = parts["phone"]
	_arm = parts["arm_right"]
	_arm_left = parts["arm_left"]
	_torso = parts["torso"]
	_head = parts["head"]
	_legs = parts["legs"]
	_last_pos = global_position


## Legs step, arms swing against the legs, the body bobs and sways a little;
## faster and bigger when she hurries (the chase). Standing: a slow breath.
func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	var moved := global_position - _last_pos
	_last_pos = global_position
	_speed = lerpf(_speed, Vector2(moved.x, moved.z).length() / delta, 0.25)
	var moving := clampf(_speed / WALK_SPEED, 0.0, 1.6)
	_gait = fmod(_gait + delta * _speed / STRIDE, 1.0)
	var step := sin(TAU * _gait)
	_legs[0].rotation.x = step * 0.45 * minf(moving, 1.2)
	_legs[1].rotation.x = -step * 0.45 * minf(moving, 1.2)
	_arm_left.rotation.x = -step * 0.4 * minf(moving, 1.3)
	if not _on_phone:
		_arm.rotation.x = step * 0.4 * minf(moving, 1.3)
	_torso.position.y = absf(step) * 0.03 * minf(moving, 1.0) + sin(_time * 1.8) * 0.004 * (1.0 - minf(moving, 1.0))
	_torso.rotation.z = step * 0.04 * minf(moving, 1.0)        # a little side-to-side sway
	_torso.rotation.x = 0.08 * clampf(moving - 1.0, 0.0, 0.6)    # leans forward when hurrying
	_head.rotation.x = -_torso.rotation.x * 0.7                   # keeps looking ahead


## Walks to [param target] (y is ignored: she stays on the floor).
## Await the returned signal to wait for her to arrive.
func walk_to(target: Vector3, speed: float = WALK_SPEED) -> Signal:
	var flat := Vector3(target.x, 0.0, target.z)
	var d := flat - Vector3(position.x, 0.0, position.z)
	if d.length() > 0.01:
		_model.rotation.y = atan2(d.x, d.z)
	var t := create_tween()
	t.tween_property(self, "position", flat, maxf(0.15, d.length() / speed))
	return t.finished


## Turns to look at [param point].
func face(point: Vector3) -> void:
	var d := point - position
	_model.rotation.y = atan2(d.x, d.z)


## Shows or hides the phone at her ear (and raises her arm to hold it).
func set_on_phone(on: bool) -> void:
	_on_phone = on
	_phone.visible = on
	_arm.rotation.z = 2.4 if on else 0.0
	_arm.rotation.x = 0.0
