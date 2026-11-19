class_name Interactable
extends Node3D
## Something the cat can use with the action button.
##
## The kitchen checks every frame which enabled Interactable is closest to the
## cat and within [member radius]; it shows [member prompt] and calls
## [method use] when the action button is pressed.
## Distance is measured in 3D, so a plate on the table can only be used from
## the table top.


## Emitted when the cat uses this object.
signal used

## Text shown on screen, e.g. "Ăn vụng cá".
var prompt: String = ""
## How close (metres, centre to centre) the cat must be.
var radius: float = 0.9
## Disabled objects are ignored (already used, or not useful right now).
var enabled: bool = true


func _init(p_prompt: String = "", p_radius: float = 0.9) -> void:
	prompt = p_prompt
	radius = p_radius


## Called by the kitchen when the player presses the action button.
func use() -> void:
	used.emit()
