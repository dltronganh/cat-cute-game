class_name KitchenBuilder
extends RefCounted
## Builds the kitchen (+ dining + laundry corner) and the little
## bedroom set used for the bedtime scenes: Blender models
## (art/blender/) placed on invisible collision boxes, plus the
## walls, floor, cloth and lights made in code.
##
## Returns the nodes the day's logic needs in a Dictionary, so
## monday_kitchen.gd only deals with what happens, not with geometry.
## The room stays built from code on purpose: every size and
## jump height is a named constant here that the self-checks can rely on.
##
## Layout (metres, floor y = 0, room from -4 to 4 on X and Z):
##   back wall  (z = -4): fridge (corner), cooking counter, family photo, sink counter under the long window, washing machine (corner)
##   left wall  (x = -4): low wooden sideboard with the table lamp, the door (front-left)
##   middle-right: dining table (top y = 1.0) with a backless stool to climb on
##   front-left: Lộc's bed · front-right: Mèo Xinh's cushion

const ROOM_HALF := 4.0
const WALL_HEIGHT := 2.4
## Height of the invisible fence above the walls (well above any jump).
const BOUNDS_HEIGHT := 8.0
const TABLE_CENTER := Vector3(2.0, 0.0, -1.2)
## 1.0 m: just too high to reach from the floor, so the cat climbs the stool first.
const TABLE_TOP := 1.0
## A backless stool beside the table: nothing to bump into on the way up.
const STOOL_TOP := 0.48
const COUNTER_TOP := 0.9
const WASHER_TOP := 0.85
const DOOR := Vector3(-3.7, 0.0, 1.0)
## Family photo on the back wall, beside the window (local x, y on the wall).
const PHOTO := Vector2(0.35, 0.75)
## Where the bedroom set is built, far away from the kitchen.
const BEDROOM := Vector3(40.0, 0.0, 0.0)

const WOOD := Color("b07a4f")
const WOOD_DARK := Color("8a5a36")

# Interior palette (a Japanese-style home):
# warm wood, bright off-white walls, white tiles, cream cloth, lots of green.
const FLOOR_WOOD := Color("7d5639")
const FLOOR_WOOD_ALT := Color("744f34")
const WALL := Color("cdc3b2")  # warm plaster; toon shading clips anything lighter to pure white
const TILE := Color("e4e0d6")
const CLOTH := Color("ece2cc")
const CABINET := Color("8a5a36")
const POT := Color("b9734c")
const LEAF := Color("6a9459")
const LEAF_LIGHT := Color("8bb072")
## The long window over the sink (back wall, x from WINDOW_X0 to WINDOW_X1).
const WINDOW_X0 := 0.95
const WINDOW_X1 := 3.0
## Kitchen run along the back wall, x ranges.
const STOVE_X0 := -3.1
const STOVE_X1 := -1.3
const SINK_X0 := 0.9
const SINK_X1 := 3.05
## Washing machine in the back-right corner, by the sink (water).
const WASHER := Vector3(3.5, 0.0, -3.5)
## Low wooden sideboard on the left wall, with the table lamp.
const SIDEBOARD := Vector3(-3.65, 0.0, -1.3)
const SIDEBOARD_TOP := 0.75
# Warm kitchen: wooden cabinets, stone tops, dishes on open shelves.
const STONE := Color("b5ada0")
const SHELF_SHADOW := Color("4f3424")
const DISH := Color("e3dccd")
const FRIDGE := Color("cdbfa3")   # warm cream, retro
const WASHER_BODY := Color("c9c0ae")


## Builds everything under [param root]. Keys of the returned Dictionary:
## walls (Array of [MeshInstance3D, normal, StaticBody3D]), back_wall,
## perches (Array of {"pos": Vector3, "name": String}), bedroom (Node3D), bedroom_camera (Camera3D),
## bedroom_sleepers (Node3D, hidden until the end of the day), bedroom_cat / bedroom_dog (Node3D),
## bedroom_dog_eyes (Array[MeshInstance3D]), bedroom_floor_bed (Node3D, the punishment cushion).
static func build(root: Node3D) -> Dictionary:
	var out := {}
	_environment(root)
	ToyShapes.solid(root, Vector3(ROOM_HALF * 2, 0.2, ROOM_HALF * 2), Vector3(0, -0.1, 0), FLOOR_WOOD)
	_floor_planks(root)
	var walls := []
	for n: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var size := Vector3(ROOM_HALF * 2, WALL_HEIGHT, 0.15) if n.x == 0 else Vector3(0.15, WALL_HEIGHT, ROOM_HALF * 2)
		var body := ToyShapes.solid(root, size, n * ROOM_HALF + Vector3(0, WALL_HEIGHT / 2, 0), WALL)
		walls.append([body.get_child(1), n, body])  # child 0 = collision, 1 = mesh
	out["walls"] = walls
	# Invisible fence on top of every wall, up to BOUNDS_HEIGHT: the room has no
	# ceiling, so without it the cat could jump from the fridge onto a wall top
	# and out of the house.
	var bounds: Array[StaticBody3D] = []
	for n: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var fence_h := BOUNDS_HEIGHT - WALL_HEIGHT
		var size := Vector3(ROOM_HALF * 2 + 0.3, fence_h, 0.15) if n.x == 0 else Vector3(0.15, fence_h, ROOM_HALF * 2 + 0.3)
		bounds.append(_collider(root, size, n * ROOM_HALF + Vector3(0, WALL_HEIGHT + fence_h / 2, 0)))
	out["bounds"] = bounds
	var back_wall: MeshInstance3D = walls[0][0]
	var left_wall: MeshInstance3D = walls[2][0]
	out["back_wall"] = back_wall

	# Layout: the back wall is one kitchen run, like a real kitchen:
	# fridge in the corner → cooking counter → a stretch of wall for the family
	# photo → sink counter under the long window → washing machine in the far
	# corner, by the water. The left wall keeps the front door and a low wooden
	# sideboard with a table lamp. Nothing stands in front of an appliance.
	var perches: Array[Dictionary] = []
	out["sunbeam"] = _window_and_tree(root, back_wall)
	_kitchen_counter(root, back_wall, STOVE_X0, STOVE_X1, true)
	_kitchen_counter(root, back_wall, SINK_X0, SINK_X1, false)
	_fridge(root)
	_washer(root)
	_sideboard(root)
	_plants(root)
	out["lamps"] = _lamps(root)
	for x in [-2.6, -1.8, 1.3, 2.3]:
		perches.append({"pos": Vector3(x, COUNTER_TOP, -3.55), "name": "quầy bếp"})
	perches.append({"pos": Vector3(WASHER.x, WASHER_TOP, WASHER.z), "name": "máy giặt"})
	perches.append({"pos": Vector3(SIDEBOARD.x, SIDEBOARD_TOP, SIDEBOARD.z), "name": "tủ gỗ"})
	# The door (front-left), a child of the left wall so it hides with it.
	_place_model(left_wall, "door", Vector3(0.075, -WALL_HEIGHT / 2, DOOR.z), 90.0)
	# Dining table (Blender model) on the old collision: top + four legs.
	_collider(root, Vector3(1.6, 0.08, 1.0), TABLE_CENTER + Vector3(0, TABLE_TOP - 0.04, 0))
	for dx in [-0.7, 0.7]:
		for dz in [-0.42, 0.42]:
			_collider(root, Vector3(0.08, TABLE_TOP - 0.08, 0.08), TABLE_CENTER + Vector3(dx, (TABLE_TOP - 0.08) / 2, dz))
	_place_model(root, "dining_table", TABLE_CENTER)
	# Tablecloth flap hanging over the front edge: the thread is tied to it, and
	# Lộc pulls it when he runs off with the thread.
	var flap := Node3D.new()
	flap.position = TABLE_CENTER + Vector3(0, TABLE_TOP, 0.51)
	root.add_child(flap)
	_gingham(ToyShapes.box(flap, Vector3(1.64, 0.02, 1.04), Vector3(0, 0.005, -0.51), Color.WHITE), Vector2(48, 20))  # red-white check cloth
	_gingham(ToyShapes.box(flap, Vector3(1.64, 0.3, 0.02), Vector3(0, -0.15, 0.01), Color.WHITE), Vector2(48, 6))    # hanging part
	ToyShapes.box(flap, Vector3(1.64, 0.04, 0.025), Vector3(0, -0.28, 0.012), Color("b84646"))  # red hem
	out["cloth_flap"] = flap
	# Backless stool right beside the table: floor → stool → table.
	var stool := TABLE_CENTER + Vector3(-1.2, 0, 0.1)
	_collider(root, Vector3(0.7, STOOL_TOP, 0.7), stool + Vector3(0, STOOL_TOP / 2, 0))
	_place_model(root, "stool", stool)
	perches.append({"pos": stool + Vector3(0, STOOL_TOP, 0), "name": "ghế đẩu"})
	perches.append({"pos": TABLE_CENTER + Vector3(-0.4, TABLE_TOP, 0.05), "name": "bàn ăn"})
	perches.append({"pos": TABLE_CENTER + Vector3(0.3, TABLE_TOP, 0.05), "name": "bàn ăn"})
	out["perches"] = perches
	_bedroom(root, out)
	return out


static func _environment(root: Node3D) -> void:
	# Daylight: mostly soft, neutral light from outside; the warm
	# glow comes only from the sun patch and, in the evening, the lamps.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2140")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("eef0f2")
	env.ambient_light_energy = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_color = Color("fff6e8")
	sun.light_energy = 0.5  # softer daylight
	sun.shadow_enabled = true
	root.add_child(sun)


## Wooden floor boards (visual only, the floor collision is one box).
static func _floor_planks(root: Node3D) -> void:
	var width := 0.4
	var count := int(ROOM_HALF * 2 / width)
	for i in count:
		if i % 2 == 1:
			var x := -ROOM_HALF + width * (i + 0.5)
			ToyShapes.box(root, Vector3(width - 0.01, 0.004, ROOM_HALF * 2), Vector3(x, 0.002, 0), FLOOR_WOOD_ALT)


## The long window over the sink: wooden frame, two rows of panes;
## sunlight falls through it onto the floor, a tree outside. Returns the
## sun patch light (dimmed and turned golden in the evening).
static func _window_and_tree(root: Node3D, back_wall: MeshInstance3D) -> SpotLight3D:
	var cx := (WINDOW_X0 + WINDOW_X1) / 2.0
	var bottom := COUNTER_TOP + 0.32  # above the tile splashback
	var h := 1.0
	# Frame, panes and sill (Blender model), on the wall so it hides with
	# it. Its glass mesh is named "WindowGlass": it turns dusk-blue in the evening.
	_place_model(back_wall, "window_frame", Vector3(cx, bottom + h / 2 - WALL_HEIGHT / 2, 0.075))
	# Sun patch: soft, not glaring, so it never washes out the white surfaces.
	var sunbeam := SpotLight3D.new()
	sunbeam.name = "Sunbeam"
	sunbeam.light_color = Color("ffe9c2")
	sunbeam.light_energy = 1.6
	sunbeam.spot_range = 12.0
	sunbeam.spot_angle = 26.0
	sunbeam.spot_attenuation = 0.6
	sunbeam.position = Vector3(cx, 4.4, -5.6)
	root.add_child(sunbeam)
	sunbeam.look_at(Vector3(cx - 0.3, 0.0, -1.0))
	# Trees outside, seen through the window and over the wall.
	_place_model(root, "tree_outside", Vector3(3.0, 0.0, -5.6))
	return sunbeam



## One counter of the kitchen run: the detailed Blender model
## (wooden carcass, stone top, open shelves with dishes; a hob and
## kettle, or a sink and tap) on an invisible collision box of the same size,
## so the cat lands at COUNTER_TOP as before. On the wall above: cup shelves
## (stove) or a tile splashback (sink); they live on the wall so they hide with it.
static func _kitchen_counter(root: Node3D, back_wall: MeshInstance3D, x0: float, x1: float, stove: bool) -> void:
	var z := -3.6
	var w := x1 - x0
	var cx := (x0 + x1) / 2.0
	_collider(root, Vector3(w + 0.04, COUNTER_TOP, 0.64), Vector3(cx, COUNTER_TOP / 2, z))
	_place_model(root, "counter_stove" if stove else "counter_sink", Vector3(cx, 0, z))
	if stove:
		for y in [1.45, 1.8]:  # two cup shelves (Blender model, cups included)
			_place_model(back_wall, "cup_shelf", Vector3(cx, y - WALL_HEIGHT / 2, 0.075))
	else:
		ToyShapes.box(back_wall, Vector3(w, 0.32, 0.03), Vector3(cx, COUNTER_TOP + 0.16 - WALL_HEIGHT / 2, 0.09), TILE)


## Fridge in the back-left corner: the Blender model (warm cream,
## retro, two doors, wooden handles) on its collision box.
static func _fridge(root: Node3D) -> void:
	var c := Vector3(-3.55, 0.0, -3.55)
	_collider(root, Vector3(0.72, 1.8, 0.66), c + Vector3(0, 0.9, 0))
	_place_model(root, "fridge", c)


## Front-loading washing machine in the back-right corner, by the sink
## (Blender model on its collision box; the cat can jump on it).
static func _washer(root: Node3D) -> void:
	_collider(root, Vector3(0.66, WASHER_TOP, 0.66), WASHER + Vector3(0, WASHER_TOP / 2, 0))
	_place_model(root, "washer", WASHER)
	# Laundry basket a little way along the right wall (not in front of the machine).
	_collider(root, Vector3(0.42, 0.38, 0.5), WASHER + Vector3(0.1, 0.19, 1.9))
	_place_model(root, "laundry_basket", WASHER + Vector3(0.1, 0, 1.9))


## An invisible box the cat and the characters collide with.
static func _collider(root: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	return body


## Places assets/models/<name>.glb (made by art/blender/build_kitchen.py or
## build_furniture.py) under [param parent] with its origin at [param pos]
## (usually the floor centre of its footprint), front facing +Z, turned
## [param rot_y] degrees and scaled by [param size]. Returns the holder node.
static func _place_model(parent: Node3D, model_name: String, pos: Vector3, rot_y := 0.0, size := 1.0) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rot_y
	holder.scale = Vector3.ONE * size
	parent.add_child(holder)
	ToyModels.load_model("res://assets/models/%s.glb" % model_name, holder)
	return holder


## The mesh called [param mesh_name] inside a placed model (e.g. a lamp shade).
static func _part(model: Node, mesh_name: String) -> MeshInstance3D:
	return model.find_child(mesh_name, true, false) as MeshInstance3D


## Low wooden sideboard on the left wall with a table lamp and a plant.
static func _sideboard(root: Node3D) -> void:
	_collider(root, Vector3(0.5, SIDEBOARD_TOP, 1.3), SIDEBOARD + Vector3(0, SIDEBOARD_TOP / 2, 0))
	_place_model(root, "sideboard", SIDEBOARD, 90.0)  # doors face the room (+X)


## Plants, placed where nothing needs to be reached:
## beside the photo, by the door, the front-right corner, on the sideboard,
## on the window sill and on the fridge.
static func _plants(root: Node3D) -> void:
	# [pot base position, Blender model, scale]
	for p in [[Vector3(-0.95, 0, -3.6), "plant_floor", 0.9], [Vector3(3.55, 0, 2.0), "plant_floor", 1.0],
			[Vector3(-3.55, 0, 2.7), "plant_tall", 1.0], [SIDEBOARD + Vector3(0, SIDEBOARD_TOP, -0.45), "plant_small", 1.0],
			[Vector3(2.75, COUNTER_TOP, -3.78), "plant_small", 0.875], [Vector3(1.9, COUNTER_TOP, -3.8), "plant_small", 0.75],
			[Vector3(-3.45, 1.8, -3.5), "plant_small", 1.125]]:
		_place_model(root, p[1], p[0], 0.0, p[2])


## Warm evening lights. Night lighting follows
## common practice: several small, low, warm lights making soft
## pools, instead of one strong light; shades glow a little themselves so a
## lamp reads as "on" without blasting the table.
## - pendant over the table: wooden shade, bulb hidden, gentle pool;
## - table lamp with a cream shade on the sideboard;
## - a low glow over each kitchen counter (under the wall shelves).
## Off by day; at dusk the kitchen raises each light to its "dusk_energy" and
## each glowing shade (group "lamp_shades") to its "dusk_glow" (metas).
static func _lamps(root: Node3D) -> Array[OmniLight3D]:
	var lamps: Array[OmniLight3D] = []
	# Pendant over the dining table.
	# Origin = centre of the shade; the cord in the model runs up to y 2.8.
	var p := TABLE_CENTER + Vector3(0, 1.75, 0)
	var pendant := _place_model(root, "pendant_lamp", p)
	for mesh: MeshInstance3D in pendant.find_children("*", "MeshInstance3D", true, false):
		_no_shadow(mesh)
	_glowing(_part(pendant, "pendant_lamp_shade"), Color("ffb867"), 0.35)
	lamps.append(_lamp_light(root, p + Vector3(0, -0.25, 0), 0.3, 3.0))
	# Table lamp on the sideboard (origin = the surface it stands on).
	var t := SIDEBOARD + Vector3(0, SIDEBOARD_TOP, 0.3)
	var table_lamp := _place_model(root, "table_lamp", t)
	_glowing(_part(table_lamp, "table_lamp_shade"), Color("ffd08a"), 0.9)
	lamps.append(_lamp_light(root, t + Vector3(0.18, 0.3, 0), 0.7, 3.0))
	# Low warm glow over the counters (like little under-shelf lights).
	for x in [(STOVE_X0 + STOVE_X1) / 2.0, (SINK_X0 + SINK_X1) / 2.0]:
		lamps.append(_lamp_light(root, Vector3(x, COUNTER_TOP + 0.45, -3.45), 0.35, 1.6))
	return lamps


## Red-and-white gingham on a box face: a tiny 2×2 texture tiled
## with nearest filtering (warm white, light red, and red where the stripes
## cross). [param tiles] is the UV scale; a BoxMesh puts each face in a third
## by a half of the UV square, so 48 × 20 gives about 16 × 10 checks a face.
static func _gingham(mesh: MeshInstance3D, tiles: Vector2) -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color("efe6d6"))
	img.set_pixel(1, 0, Color("dc8f8a"))
	img.set_pixel(0, 1, Color("dc8f8a"))
	img.set_pixel(1, 1, Color("b84646"))
	var mat := mesh.material_override as StandardMaterial3D
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(tiles.x, tiles.y, 1.0)


## Makes a lamp shade able to glow softly at dusk (its own light, a little).
static func _glowing(shade: MeshInstance3D, glow: Color, dusk_glow: float) -> void:
	var mat := shade.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = glow
	mat.emission_energy_multiplier = 0.0
	shade.set_meta("dusk_glow", dusk_glow)
	shade.add_to_group("lamp_shades")
	_no_shadow(shade)


## Lamps hang under the (invisible) ceiling, so the sun can never shine down
## past them: they must not throw sun shadows (otherwise a lamp shade drops a
## shadow on the tablecloth).
static func _no_shadow(mesh: MeshInstance3D) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _lamp_light(root: Node3D, pos: Vector3, dusk_energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = Color("ffc47a")
	light.light_energy = 0.0
	light.omni_range = reach
	light.position = pos
	light.set_meta("dusk_energy", dusk_energy)
	root.add_child(light)
	return light


## A tiny bedroom far away from the kitchen: a bed with bà Hằng, Mèo Xinh and
## Lộc asleep on it, moonlight, and its own camera.
static func _bedroom(root: Node3D, out: Dictionary) -> void:
	var room := Node3D.new()
	room.position = BEDROOM
	root.add_child(room)
	ToyShapes.box(room, Vector3(5, 0.2, 5), Vector3(0, -0.1, 0), Color("4a4a6e"))
	ToyShapes.box(room, Vector3(5, 2.4, 0.15), Vector3(0, 1.2, -2.5), Color("3d3f63"))
	ToyShapes.box(room, Vector3(0.15, 2.4, 5), Vector3(-2.5, 1.2, 0), Color("3d3f63"))
	_place_model(room, "bed", Vector3(0, 0, -0.8))  # mattress top 0.45, blanket top 0.56
	var sleepers := Node3D.new()
	room.add_child(sleepers)
	# Bà Hằng's head (the Blender model's) on the pillow, face up,
	# eyes closed; the blanket covers the rest. Only the head is kept.
	var owner_holder := Node3D.new()
	sleepers.add_child(owner_holder)
	var owner_head: Node3D = ToyModels.build_owner(owner_holder)["head"]
	owner_head.reparent(sleepers, false)
	owner_holder.queue_free()
	owner_head.position = Vector3(0, 0.74, -1.52)
	owner_head.rotation_degrees = Vector3(-80, 0, 0)  # lying on her back, face to the ceiling
	ToyModels.set_dog_eyes_closed([owner_head.find_child("EyeL", true, false), owner_head.find_child("EyeR", true, false)], true)
	out["bedroom_owner_head"] = owner_head
	# Her body is a long bump under the blanket, so she reads as a whole person
	# and the pets look pet-sized next to her (a head alone made them look giant).
	var body := ToyShapes.capsule(sleepers, 0.22, 1.25, Vector3(0, 0.57, -0.74), Color("7d95d0"), Vector3(90, 0, 0))
	body.scale = Vector3(1.25, 1.0, 0.55)
	# Mèo Xinh and Lộc asleep on the blue blanket (so the white cat does not vanish into the white bed),
	# curled up on their side either side of her, at the same scale as in the kitchen.
	var cat := Node3D.new()
	cat.position = Vector3(-0.62, 0.67, -0.25)
	cat.rotation_degrees = Vector3(0, 60, 80)
	sleepers.add_child(cat)
	ToyModels.build_cat(cat)["mouth"].visible = false
	ToyModels.set_cat_eyes_closed(cat, true)  # asleep
	var dog := Node3D.new()
	dog.position = Vector3(0.66, 0.7, -0.05)
	dog.rotation_degrees = Vector3(0, -120, -80)
	dog.scale = Vector3.ONE * 0.85
	sleepers.add_child(dog)
	var dog_parts := ToyModels.build_dog(dog)
	ToyModels.set_dog_eyes_closed(dog_parts["eyes"], true)  # asleep
	# Punishment night: a little cushion on the floor at the foot of the bed,
	# hidden unless the cat was caught.
	var floor_bed := _place_model(room, "floor_cushion", Vector3(1.35, 0, 1.05))  # deep pink: the moonlight right above washes light colours out
	floor_bed.hide()
	var moon := OmniLight3D.new()
	moon.light_color = Color("aab8ff")
	moon.light_energy = 1.5
	moon.omni_range = 6.0
	moon.position = Vector3(1.5, 2.2, 1.5)
	room.add_child(moon)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.0
	room.add_child(cam)
	cam.position = Vector3(4.0, 4.5, 4.0)
	cam.look_at(room.global_position + Vector3(0, 0.4, -0.5))
	out["bedroom"] = room
	out["bedroom_camera"] = cam
	out["bedroom_sleepers"] = sleepers
	out["bedroom_cat"] = cat
	out["bedroom_dog"] = dog
	out["bedroom_dog_eyes"] = dog_parts["eyes"]
	out["bedroom_floor_bed"] = floor_bed
