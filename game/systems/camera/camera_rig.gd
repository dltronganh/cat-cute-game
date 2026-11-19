class_name CameraRig
extends Node3D
## Toy-house camera: orthographic, high up in one corner of
## the room, looking down at an angle. rotate_corner(±1) swings it 90° around
## the room; the kitchen listens to [signal yaw_changed] to hide the two walls
## nearest to the camera.
##
## Place the rig at the centre of the room.

## Emitted every frame while the camera turns, with the new yaw in degrees.
signal yaw_changed(yaw_degrees: float)

## Looking down by this many degrees. 38° shows both the floor and table tops.
const PITCH_DEG := -38.0
## Distance from the room centre. Large enough to never clip the walls.
const DISTANCE := 18.0
## Seconds for one 90° turn.
const ROTATE_TIME := 0.35

## Orthographic view height in metres: 11 fits an 8 m room with a margin.
@export var view_size: float = 11.0

var camera: Camera3D
## 0..3, which corner the camera sits in.
var corner: int = 0

var _yaw: float = 45.0
var _tween: Tween


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = view_size
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)
	camera.make_current()  # other cameras (e.g. the bedroom's) may exist in the scene
	_apply_yaw(_yaw)


## Turns the camera to the next (+1) or previous (-1) corner.
func rotate_corner(direction: int) -> void:
	corner = posmod(corner + direction, 4)
	var target := 45.0 + corner * 90.0
	var delta := wrapf(target - _yaw, -180.0, 180.0)  # always the short way round
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply_yaw, _yaw, _yaw + delta, ROTATE_TIME).set_trans(Tween.TRANS_SINE)


## Ground-plane direction the camera looks towards (for "up" on the stick).
func forward_flat() -> Vector3:
	var y := deg_to_rad(_yaw)
	return Vector3(-sin(y), 0.0, -cos(y))


## Ground-plane direction to the camera's right (for "right" on the stick).
func right_flat() -> Vector3:
	var y := deg_to_rad(_yaw)
	return Vector3(cos(y), 0.0, -sin(y))


## Ground-plane direction from the room centre towards the camera.
func toward_camera_flat() -> Vector3:
	return -forward_flat()


func _apply_yaw(yaw: float) -> void:
	_yaw = yaw
	rotation_degrees = Vector3(0.0, _yaw, 0.0)
	var pitch := deg_to_rad(PITCH_DEG)
	# Offset (0, 0, D) tilted by the pitch: up and behind the room centre.
	camera.position = Vector3(0.0, -DISTANCE * sin(pitch), DISTANCE * cos(pitch))
	camera.rotation_degrees = Vector3(PITCH_DEG, 0.0, 0.0)
	yaw_changed.emit(_yaw)
