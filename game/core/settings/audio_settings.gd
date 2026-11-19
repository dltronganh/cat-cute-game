class_name AudioSettings
extends RefCounted
## The player's two volume choices (music, sound effects), each 0.0–1.0,
## remembered between plays in a ConfigFile (section "audio").
##
## Pure logic: no nodes, so it is unit-tested. The autoload Sound applies the
## values to the audio buses and calls [method save_to] when they change.

## Where the game keeps all player settings (the cat coat lives there too).
const DEFAULT_PATH := "user://settings.cfg"
## Starting levels: music a little under the effects.
const DEFAULT_MUSIC := 0.8
const DEFAULT_SFX := 1.0

## Music volume, 0.0 (off) to 1.0 (full).
var music: float = DEFAULT_MUSIC:
	set(value):
		music = clampf(value, 0.0, 1.0)
## Sound-effect volume, 0.0 (off) to 1.0 (full).
var sfx: float = DEFAULT_SFX:
	set(value):
		sfx = clampf(value, 0.0, 1.0)


## Reads the settings saved at [param path]. A missing or broken file gives
## the defaults; out-of-range values are clamped.
static func load_from(path: String = DEFAULT_PATH) -> AudioSettings:
	var cfg := ConfigFile.new()
	cfg.load(path)  # an error just leaves cfg empty → defaults
	var s := AudioSettings.new()
	s.music = float(cfg.get_value("audio", "music", DEFAULT_MUSIC))
	s.sfx = float(cfg.get_value("audio", "sfx", DEFAULT_SFX))
	return s


## Writes the volumes to [param path], keeping every other setting in the file.
## Returns the ConfigFile error code (OK on success).
func save_to(path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	return cfg.save(path)
