class_name LinePicker
extends RefCounted
## Picks a random line from a list, never the same line twice in a row.
##
## Used for bà Hằng's phone calls to Mr. Thanh: every time the day
## is replayed she says something new.
## Pure logic, unit tested in tests/core/lines/test_line_picker.gd.
##
## [code]_last_by_key[/code] is a static variable, so it survives
## get_tree().reload_current_scene() (which is how the game restarts a day).

static var _last_by_key: Dictionary = {}


## Returns a random index into a list of [param count] lines, different from
## the index returned last time for the same [param key] (when count > 1).
## [param rng] lets tests use a fixed seed.
static func pick_index(key: StringName, count: int, rng: RandomNumberGenerator) -> int:
	if count <= 0:
		return -1
	var last: int = _last_by_key.get(key, -1)
	var index := rng.randi_range(0, count - 1)
	if count > 1 and index == last:
		index = (index + 1 + rng.randi_range(0, count - 2)) % count
	_last_by_key[key] = index
	return index


## Forgets the history (used by tests).
static func reset() -> void:
	_last_by_key.clear()
