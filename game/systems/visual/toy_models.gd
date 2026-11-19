class_name ToyModels
extends RefCounted
## The characters' looks: rounded, pastel, toy-like figures made of
## spheres and capsules. Every builder puts the figure under [param parent]
## facing +Z, feet at y = 0, and returns the parts that get animated.
##
## Used by CatController, Dog, OwnerNpc and the bedroom scene, so a character
## looks the same everywhere. Change a colour here and it changes everywhere.


const CAT_WHITE := Color("fbf7ef")
const CAT_PINK := Color("ffb3c4")
const INK := Color("2b2140")
## Blender models of Lộc and bà Hằng. Their colours live in the
## Blender scripts (art/blender/build_dog.py, build_owner.py).
const DOG_MODEL := "res://assets/models/dog_loc.glb"
const OWNER_MODEL := "res://assets/models/owner_hang.glb"


## Where the chosen cat coat is remembered between plays.
const SETTINGS_PATH := "user://settings.cfg"

## The coat Mèo Xinh wears, one of CatSkins.ALL. Loaded from
## [constant SETTINGS_PATH] the first time it is needed; change it with
## [method set_cat_skin] so it is saved.
static var cat_skin: StringName = &"":
	get:
		if cat_skin == &"":
			var cfg := ConfigFile.new()
			cfg.load(SETTINGS_PATH)  # missing file = defaults
			var saved := StringName(cfg.get_value("cat", "skin", String(CatSkins.DEFAULT)))
			cat_skin = saved if CatSkins.is_valid(saved) else CatSkins.DEFAULT
		return cat_skin


## Chooses the cat's coat and saves the choice.
static func set_cat_skin(skin: StringName) -> void:
	cat_skin = skin if CatSkins.is_valid(skin) else CatSkins.DEFAULT
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("cat", "skin", String(cat_skin))
	cfg.save(SETTINGS_PATH)


## Mèo Xinh, the model made in Blender (art/blender/build_cat.py)
## in the current [member cat_skin]. Stays inside a 0.3 m radius so it never
## pokes into furniture. Every mesh gets its own toon material as
## material_override (the cat's silhouette pass hangs off those), with the
## coat pattern taken from the model's vertex colours.
## Returns {"mouth": MeshInstance3D (fish stain), "anim": AnimationPlayer (or null)}.
static func build_cat(parent: Node3D) -> Dictionary:
	var model := load_model(CatSkins.model_path(cat_skin), parent)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		# Cycles loop; the one-shots (jump, land, cower) play once and hold.
		for loop_name in ["idle", "walk", "run", "air"]:
			if anim.has_animation(loop_name):
				anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	return {"mouth": model.find_child("MouthStain", true, false) as MeshInstance3D, "anim": anim}


## Closes or opens the cat's eyes: the open eyes (iris, pupil,
## highlights) swap with the "︶" sleeping arcs. [param model] is anything
## containing the cat model (e.g. the node passed to build_cat).
static func set_cat_eyes_closed(model: Node, closed: bool) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(node.name)
		if n.begins_with("EyeClosed"):
			node.visible = closed
		elif n.begins_with("Eye") or n.begins_with("Pupil") or n.begins_with("Shine"):
			node.visible = not closed


## Closes or opens flat disc eyes (flattened into lines when asleep), given an
## "eyes" array from build_dog or build_owner (Lộc and bà Hằng both use it).
static func set_dog_eyes_closed(eyes: Array, closed: bool) -> void:
	for eye: MeshInstance3D in eyes:
		eye.scale.y = 0.15 if closed else 1.0
		for shine in eye.get_parent().get_children():
			# The little white highlight next to each eye only shows when open.
			if shine is MeshInstance3D and shine != eye and shine.position.distance_to(eye.position) < 0.04:
				shine.visible = not closed


## Instantiates a model exported from Blender (.glb) under [param parent] and
## gives every mesh its own toon material (the game's look) keeping
## the Blender colours; vertex colours (the cat's coat) are used too.
## Visual only: collision stays with the caller.
static func load_model(path: String, parent: Node3D) -> Node3D:
	var scene := load(path) as PackedScene
	var model := scene.instantiate() as Node3D
	parent.add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var source := mesh.get_active_material(0) as BaseMaterial3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = source.albedo_color if source else Color.WHITE
		mat.roughness = 0.85
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		if (mesh.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0:
			mat.vertex_color_use_as_albedo = true
			mesh.mesh = _coat_in_srgb(mesh.mesh)
			# Soft fur: a light rim along the edges facing the
			# light, tinted by the coat colour, like velvet or plush.
			mat.rim_enabled = true
			mat.rim = FUR_RIM
			mat.rim_tint = FUR_RIM_TINT
		mesh.material_override = mat
	return model


## glTF stores vertex colours (the coat pattern) as linear values, but the
## Compatibility renderer reads vertex colours as sRGB, which made the coat
## darker and harsher than in Blender. Returns a copy with sRGB colours.
## (Cached per mesh, so switching skins does not redo the work.)
static func _coat_in_srgb(source: Mesh) -> ArrayMesh:
	if _srgb_cache.has(source):
		return _srgb_cache[source]
	var out := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in colours.size():
			# COAT_MAX keeps white fur just under the toon "pure white" clip,
			# so it reads as soft white instead of glaring in the sun.
			colours[i] = colours[i].linear_to_srgb() * COAT_MAX
		arrays[Mesh.ARRAY_COLOR] = colours
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_srgb_cache[source] = out
	return out


static var _srgb_cache := {}

## Coat colour multiplier: a warm, slightly darker white. Toon shading
## turns anything lighter than about #cdc3b2 into flat white under the sun.
const COAT_MAX := Color(0.86, 0.84, 0.8)
## Fur rim strength (0–1) and how much it takes the coat colour (0 = white rim).
const FUR_RIM := 0.45
const FUR_RIM_TINT := 0.6


## Lộc. About 0.75 m long. Built like a jointed toy so it can move:
## the legs hang from hip/shoulder pivots, everything else sits on a "torso"
## node that can bob. Returns {"torso": Node3D, "legs": Array[Node3D] (front
## left, front right, back left, back right), "head": Node3D, "tail": Node3D,
## "ears": Array[Node3D], "eyes": Array[MeshInstance3D] (left, right)}.
static func build_dog(parent: Node3D) -> Dictionary:
	# Blender model (art/blender/build_dog.py): one smooth part per
	# joint, each part's origin at its joint, same tree as the old code toy.
	var model := load_model(DOG_MODEL, parent)
	var torso := model.find_child("Torso", true, false) as Node3D
	var head := torso.find_child("Head", true, false) as Node3D
	var legs: Array[Node3D] = []
	for leg_name in ["LegFL", "LegFR", "LegBL", "LegBR"]:
		legs.append(torso.find_child(leg_name) as Node3D)
	var ears: Array[Node3D] = [head.find_child("EarL", true, false) as Node3D, head.find_child("EarR", true, false) as Node3D]
	var eyes: Array[MeshInstance3D] = [head.find_child("EyeL", true, false) as MeshInstance3D, head.find_child("EyeR", true, false) as MeshInstance3D]
	return {"torso": torso, "legs": legs, "head": head, "tail": torso.find_child("Tail", true, false) as Node3D, "ears": ears, "eyes": eyes}


## Bà Hằng, about 1.65 m. Jointed like a toy so she can walk: legs
## from hip pivots, arms from shoulder pivots, the rest on a "torso" node.
## Returns {"torso": Node3D, "legs": Array[Node3D] (left, right),
## "arm_left": Node3D, "arm_right": Node3D, "head": Node3D, "phone": MeshInstance3D}.
static func build_owner(parent: Node3D) -> Dictionary:
	# Blender model (art/blender/build_owner.py): legs are siblings of
	# the torso (so the torso can bob over planted feet); arms and head hang
	# from the torso; every part's origin is its joint.
	var model := load_model(OWNER_MODEL, parent)
	var torso := model.find_child("Torso", true, false) as Node3D
	var head := torso.find_child("Head", true, false) as Node3D
	var legs: Array[Node3D] = [model.find_child("LegL", true, false) as Node3D, model.find_child("LegR", true, false) as Node3D]
	var phone := head.find_child("Phone", true, false) as MeshInstance3D
	phone.visible = false  # only out during the phone call
	return {"torso": torso, "legs": legs, "arm_left": torso.find_child("ArmLeft", true, false) as Node3D,
		"arm_right": torso.find_child("ArmRight", true, false) as Node3D, "head": head, "phone": phone,
		"eyes": [head.find_child("EyeL", true, false), head.find_child("EyeR", true, false)] as Array[MeshInstance3D]}
