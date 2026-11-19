extends Node
## Autoload "Sound": plays the game's sound effects and background music.
##
## Sounds are assets/audio/sfx_cc0/<name>.wav (recorded, CC0) when present, else
## the baked synthesized files in assets/audio/sfx/<name>.wav (names: the keys of
## [constant SoundRecipes.ALL]); music is assets/audio/music/<name>.wav, looping.
## An autoload so the music keeps playing across a scene reload (replay).
##
## Buses, created at startup: "Music" (fades) → "MusicLevel" (the player's music
## volume) → Master, and "SFX" (the player's effects volume) → Master. The
## volumes are set from the menus and saved via AudioSettings.
##
## Usage:  Sound.play(&"meow")   Sound.play(&"step", -8.0, 0.1)   Sound.music(&"dusk")

const SFX_DIR := "res://assets/audio/sfx/"
## Recorded CC0 sounds with the same names (credits: assets/CREDITS.md). Kept
## apart so re-baking the synthesized sounds never overwrites them.
const CC0_DIR := "res://assets/audio/sfx_cc0/"
const MUSIC_DIR := "res://assets/audio/music/"
## How many effects can sound at the same time.
const VOICES := 12
## Default loudness (dB) of the music under the effects.
const MUSIC_DB := -10.0
## Bus level counted as silence during fades.
const SILENT_DB := -50.0

var _streams: Dictionary = {}  # StringName → AudioStream
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _current_tune: StringName = &""
var _fade_tween: Tween
var _music_bus_db := 0.0  # the fade level of the "Music" bus (0 = full)
var _settings: AudioSettings


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # music keeps going while paused
	_make_bus(&"MusicLevel", &"Master")  # the player's music volume
	_make_bus(&"Music", &"MusicLevel")    # fades between tunes
	_make_bus(&"SFX", &"Master")          # the player's effects volume
	_settings = AudioSettings.load_from()
	_apply_volumes()
	for name: StringName in SoundRecipes.ALL:
		# A recorded CC0 sound wins over the synthesized one.
		for dir in [CC0_DIR, SFX_DIR]:
			var path: String = dir + String(name) + ".wav"
			if ResourceLoader.exists(path):
				_streams[name] = load(path)
				break
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)


## Plays sound effect [param name]. [param volume_db] makes it louder or softer;
## [param pitch_jitter] varies the pitch randomly by up to ± that fraction, so
## repeated sounds (steps) do not sound like a machine gun.
func play(name: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.0) -> void:
	if not _streams.has(name):
		push_warning("Sound: no sound named %s" % name)
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Starts tune [param name] (a file in [constant MUSIC_DIR]): the current tune
## fades out, then the new one fades in, [param fade] seconds in all.
## Same tune again: nothing happens.
##
## Why the fades move the "Music" BUS volume and not the player's volume_db:
## on the web Godot plays sounds as browser "samples", and changing an
## AudioStreamPlayer's volume_db while it plays is ignored there
## (AudioServer.set_playback_all_bus_volumes_linear skips sample playbacks).
## A tune started quiet would stay silent forever. Bus volume does reach the
## browser (AudioServer.set_bus_volume_db → set_sample_bus_volume_db).
func music(name: StringName, fade: float = 2.0) -> void:
	if name == _current_tune:
		return
	_current_tune = name
	var stream: AudioStream = load(MUSIC_DIR + String(name) + ".wav")
	_loop_whole(stream)
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	if _music.playing:
		_fade_tween.tween_method(_set_music_bus_db, _music_bus_db, SILENT_DB, fade / 2.0)
		_fade_tween.tween_callback(_music.stop)
	_fade_tween.tween_callback(func() -> void:
		_music.stream = stream
		_music.volume_db = MUSIC_DB  # set BEFORE play(): the web keeps the start volume
		_music.play())
	_fade_tween.tween_method(_set_music_bus_db, SILENT_DB, 0.0, fade / 2.0)


## Fades the music out over [param fade] seconds.
func stop_music(fade: float = 1.5) -> void:
	_current_tune = &""
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_music_bus_db, _music_bus_db, SILENT_DB, fade)
	_fade_tween.tween_callback(_music.stop)


## Name of the tune playing now (empty when none). Used by the checks.
func current_tune() -> StringName:
	return _current_tune if _music.playing else &""


## Sets the player's volume for [param bus] (&"Music" or &"SFX"), 0.0 (off)
## to 1.0 (full), applies it and remembers it for the next play.
func set_volume(bus: StringName, linear: float) -> void:
	if bus == &"Music":
		_settings.music = linear
	else:
		_settings.sfx = linear
	_apply_volumes()
	_settings.save_to()


## The player's volume for [param bus] (&"Music" or &"SFX"), 0.0–1.0.
func volume(bus: StringName) -> float:
	return _settings.music if bus == &"Music" else _settings.sfx


## The player's volume lives on the "MusicLevel" / "SFX" buses; the "Music"
## bus beneath carries the fades, so the two never fight.
func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"MusicLevel"), linear_to_db(maxf(_settings.music, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), linear_to_db(maxf(_settings.sfx, 0.0001)))


func _make_bus(bus: StringName, send_to: StringName) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, send_to)


## Makes [param stream] loop over its whole length with explicit loop points,
## so looping does not depend on the import settings. (On the web, Godot
## restarts the sample itself when it ends rather than using the browser's
## loop flag; checked in the browser: the 18 s day tune starts again.)
func _loop_whole(stream: AudioStream) -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(round(wav.get_length() * wav.mix_rate))


func _set_music_bus_db(db: float) -> void:
	_music_bus_db = db
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), db)
