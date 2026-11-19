class_name ToyShapes
extends RefCounted
## Helpers to build geometry from code: boxes, spheres, capsules, cylinders
## and cones, coloured, optionally with collision. Characters use soft "toon"
## shading for a toy-like look. Real models may replace these later;
## the art direction (rounded, pastel, toy-like) stays.



## A material in the game's style. Toon shading gives flat, cartoon-like
## light and shadow bands.
static func material(color: Color, toon: bool = true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if toon:
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


## A coloured box mesh centred on [param pos]. No collision.
static func box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, color, false)


## A sphere; [param squash] scales it (e.g. Vector3(1, 0.5, 1) for a flat disc).
static func sphere(parent: Node, radius: float, pos: Vector3, color: Color, squash := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var m := _add(parent, mesh, pos, color, true)
	m.scale = squash
	return m


## A capsule standing up along Y; rotate with [param rot_deg] (degrees).
static func capsule(parent: Node, radius: float, height: float, pos: Vector3, color: Color, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 16
	mesh.rings = 6
	var m := _add(parent, mesh, pos, color, true)
	m.rotation_degrees = rot_deg
	return m


## A cylinder (or a cone when [param top_radius] is 0) standing up along Y.
static func cylinder(parent: Node, top_radius: float, bottom_radius: float, height: float, pos: Vector3, color: Color, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 20
	var m := _add(parent, mesh, pos, color, true)
	m.rotation_degrees = rot_deg
	return m


## A coloured box that the cat can stand on / bump into.
static func solid(parent: Node, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	box(body, size, Vector3.ZERO, color)
	return body


static func _add(parent: Node, mesh: Mesh, pos: Vector3, color: Color, toon: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material(color, toon)
	m.position = pos
	parent.add_child(m)
	return m
