class_name CatSkins
## The coats Mèo Xinh can wear: same model, different colours.
##
## Pure data and logic (no scene, no files), so it is unit-tested. Which skin
## is chosen is saved by the game (see ToyModels.cat_skin).

## Every skin, in the order the "change coat" button cycles through.
const ALL: Array[StringName] = [&"calico", &"white"]
## The skin a new player starts with.
const DEFAULT: StringName = &"calico"

const _NAMES := {&"calico": "Tam thể", &"white": "Trắng"}


## True if [param skin] is a known skin.
static func is_valid(skin: StringName) -> bool:
	return ALL.has(skin)


## The skin after [param skin] in [constant ALL], wrapping around. Unknown
## skins give [constant DEFAULT].
static func next_skin(skin: StringName) -> StringName:
	var i := ALL.find(skin)
	if i < 0:
		return DEFAULT
	return ALL[(i + 1) % ALL.size()]


## The name shown to the player, e.g. "Tam thể".
static func display_name(skin: StringName) -> String:
	return _NAMES.get(skin, _NAMES[DEFAULT])


## The model file exported from Blender for [param skin].
static func model_path(skin: StringName) -> String:
	return "res://assets/models/cat_%s.glb" % (skin if is_valid(skin) else DEFAULT)
