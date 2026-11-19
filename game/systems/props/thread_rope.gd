class_name ThreadRope
extends Node3D
## A soft thread drawn as a chain of thin segments.
##
## - [method set_path]: where the thread lies when it has settled.
## - [method unroll]: it pours out from the start of the path, wriggling,
##   then settles on the path.
## - [method drag_with]: the thread snags on a moving node (Lộc's leg) and
##   becomes a simple rope simulation: the snag point follows the node, the
##   rest of the thread is pulled along segment by segment, with gravity and
##   floor friction. The start stays tied to the tablecloth.
## - [method release]: the node shakes the thread off; it settles where it is.
##
## Positions are in world space; place the node at the origin.

## Number of segments: enough to bend smoothly.
const SEGMENTS := 56
const RADIUS := 0.012
## How strongly it wriggles while falling (metres), and how fast that calms down.
const WIGGLE := 0.07
const SETTLE_TIME := 1.4
## Rope simulation (only while / after being dragged).
const GRAVITY := 9.8
const FLOOR_Y := 0.015
const FLOOR_FRICTION := 0.75  # share of sideways speed lost per frame on the floor
const SOLVER_ITERATIONS := 12
## Height on Lộc where the thread is snagged (his leg).
const SNAG_HEIGHT := 0.1

var _rest: PackedVector3Array = []   # SEGMENTS + 1 evenly spaced points
var _points: PackedVector3Array = []
var _segments: Array[MeshInstance3D] = []
var _reveal := 0.0
var _wiggle := 0.0
var _time := 0.0
var _seg_len := 0.0

# Rope simulation state (Verlet): on once the thread is dragged.
var _simulating := false
var _prev: PackedVector3Array = []
var _drag_node: Node3D = null
var _drag_from := 0
var _tied := 1  # leading points tied to the tablecloth (on the table and down its side)


func _ready() -> void:
	var mat := ToyShapes.material(Color("e05a8a"))
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS
	mesh.bottom_radius = RADIUS
	mesh.height = 1.0
	mesh.radial_segments = 6
	for i in SEGMENTS:
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.material_override = mat
		add_child(m)
		_segments.append(m)
	top_level = true


## Sets where the thread lies once settled. [param points] is a polyline;
## it is resampled into evenly spaced points.
func set_path(points: PackedVector3Array) -> void:
	var lengths: Array[float] = [0.0]
	for i in range(1, points.size()):
		lengths.append(lengths[-1] + points[i].distance_to(points[i - 1]))
	var total: float = lengths[-1]
	_seg_len = total / SEGMENTS
	_rest.clear()
	var j := 1
	for k in SEGMENTS + 1:
		var d := total * k / SEGMENTS
		while j < points.size() - 1 and lengths[j] < d:
			j += 1
		var seg_len: float = lengths[j] - lengths[j - 1]
		var t := 0.0 if seg_len <= 0.0 else (d - lengths[j - 1]) / seg_len
		_rest.append(points[j - 1].lerp(points[j], clampf(t, 0.0, 1.0)))
	_points = _rest.duplicate()


## Pours the thread out along its path over [param duration] seconds.
func unroll(duration: float) -> void:
	_reveal = 0.0
	_wiggle = 1.0
	var t := create_tween()
	t.tween_property(self, "_reveal", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_wiggle", 0.0, SETTLE_TIME)


## The thread snags on [param node] at the point closest to [param from_point];
## from now on it is simulated and that point follows the node.
func drag_with(node: Node3D, from_point: Vector3) -> void:
	_drag_node = node
	var best := INF
	for i in _rest.size():
		var d := Vector2(_rest[i].x - from_point.x, _rest[i].z - from_point.z).length()
		if d < best:
			best = d
			_drag_from = i
	# Everything still up on the table or hanging down its side stays tied to the cloth
	# (the simulation has no table to rest on).
	_tied = 1
	while _tied < _drag_from and _rest[_tied].y > 0.6:
		_tied += 1
	_reveal = 1.0
	_wiggle = 0.0
	_prev = _points.duplicate()
	_simulating = true


## The node lets go of the thread (Lộc shakes it off); it settles where it lies.
func release() -> void:
	_drag_node = null


## True while a node is dragging the thread.
func is_dragged() -> bool:
	return _drag_node != null


## The point of the path closest to [param p] (to know where Lộc catches it).
func closest_rest_point(p: Vector3) -> Vector3:
	var best := INF
	var out := p
	for q in _rest:
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < best:
			best = d
			out = q
	return out


func _process(delta: float) -> void:
	if _rest.is_empty():
		return
	_time += delta
	if _simulating:
		_simulate(minf(delta, 1.0 / 30.0))
	else:
		_animate_unroll()
	for i in SEGMENTS:
		_place_segment(_segments[i], _points[i], _points[i + 1])


## Before any drag: the thread pours out along its rest path and wriggles.
func _animate_unroll() -> void:
	var tip := int(_reveal * SEGMENTS)
	for i in _rest.size():
		var p := _rest[mini(i, tip)]  # not yet unrolled: bunched at the tip
		# Wriggle: a travelling sine wave across the thread, strongest near the tip.
		var near_tip := clampf(1.0 - absf(float(i - tip)) / 18.0, 0.25, 1.0)
		var w := WIGGLE * _wiggle * near_tip
		p += Vector3(sin(_time * 9.0 + i * 0.55) * w, 0.0, cos(_time * 7.0 + i * 0.4) * w)
		p.y = maxf(p.y, FLOOR_Y)  # never under the floor
		_points[i] = p


## Verlet rope: move each point by its velocity plus gravity, then pull
## neighbours back to the segment length. The first point stays tied to the
## tablecloth; the snag point follows Lộc while he drags it.
func _simulate(dt: float) -> void:
	for i in _points.size():
		var p := _points[i]
		var v := p - _prev[i]
		if p.y <= FLOOR_Y + 0.001:
			v.x *= 1.0 - FLOOR_FRICTION
			v.z *= 1.0 - FLOOR_FRICTION
		_prev[i] = p
		_points[i] = p + v + Vector3(0.0, -GRAVITY * dt * dt, 0.0)
	for _k in SOLVER_ITERATIONS:
		_pin_ends()
		for i in SEGMENTS:
			var a := _points[i]
			var b := _points[i + 1]
			var d := b - a
			var length := d.length()
			if length <= _seg_len or length < 0.00001:
				continue  # a thread can go slack, it only resists stretching
			var fix := d * ((length - _seg_len) / length) * 0.5
			var a_pinned := _is_pinned(i)
			var b_pinned := _is_pinned(i + 1)
			if a_pinned and b_pinned:
				continue
			if a_pinned:
				_points[i + 1] = b - fix * 2.0
			elif b_pinned:
				_points[i] = a + fix * 2.0
			else:
				_points[i] = a + fix
				_points[i + 1] = b - fix
		for i in _points.size():
			var q := _points[i]
			if q.y < FLOOR_Y:
				q.y = FLOOR_Y
				_points[i] = q
	_pin_ends()


func _is_pinned(i: int) -> bool:
	return i < _tied or (_drag_node != null and i == _drag_from)


func _pin_ends() -> void:
	for i in _tied:
		_points[i] = _rest[i]
	if _drag_node:
		_points[_drag_from] = _drag_node.global_position + Vector3(0.0, SNAG_HEIGHT, 0.0)


func _place_segment(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.0005:
		m.visible = false
		return
	m.visible = true
	var dir := d / length
	# Rotate the cylinder's Y axis onto the segment (straight down needs a special case).
	var basis := Basis(Vector3.RIGHT, PI) if dir.dot(Vector3.UP) < -0.9999 else Basis(Quaternion(Vector3.UP, dir))
	m.global_transform = Transform3D(basis * Basis.from_scale(Vector3(1.0, length, 1.0)), (a + b) * 0.5)
