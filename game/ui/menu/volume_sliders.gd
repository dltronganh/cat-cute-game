class_name VolumeSliders
extends GridContainer
## Two labelled sliders, "Nhạc" (music) and "Tiếng" (sound effects), bound to
## the autoload Sound: moving one changes and saves that volume at once.
## Used by the title menu and the pause menu.
##
## Mouse-only on purpose: sliders never take keyboard focus, so arrow keys and
## Space keep moving the cat.


func _ready() -> void:
	columns = 2
	add_theme_constant_override("h_separation", 16)
	add_theme_constant_override("v_separation", 10)
	_add_row("Nhạc", &"Music")
	_add_row("Tiếng", &"SFX")


func _add_row(title: String, bus: StringName) -> void:
	var label := Label.new()
	label.text = title
	add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(220, 28)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value = Sound.volume(bus)
	slider.value_changed.connect(func(v: float) -> void:
		Sound.set_volume(bus, v)
		if bus == &"SFX":
			Sound.play(&"pop"))  # let the player hear the new level
	add_child(slider)
