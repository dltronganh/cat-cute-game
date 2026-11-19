class_name SoundRecipes
extends RefCounted
## The game's sound effects as recipes for [Synth]: each one is a
## length and a wave function. tools/bake_audio.ps1 renders them all to
## assets/audio/sfx/<name>.wav; the game only plays the baked files, so a
## recipe can later be replaced by a recorded CC0 file with the same name.
##
## To change a sound: edit its wave function below, run tools/bake_audio.ps1.
## To add one: add a line to [constant ALL] and a [code]_w_<name>[/code] function.

## name → length in seconds. The wave function is [code]_w_<name>[/code].
const ALL := {
	# Mèo Xinh
	&"step": 0.07,       # soft paw on the floor
	&"jump": 0.22,       # little spring up
	&"land": 0.12,       # soft thump
	&"meow": 0.45,       # cute meow (caught, startled)
	&"eat": 0.35,        # nom nom
	&"lap": 0.4,         # drinking water
	&"hihi": 0.6,        # sly giggle
	# Lộc
	&"bark": 0.2,        # happy "gâu"
	&"yelp": 0.25,       # startled by the thread
	&"huhu": 1.2,        # crying
	# Objects
	&"thread": 0.6,      # the thread spool pours down
	&"roll": 0.5,        # ball pushed
	&"slide": 0.8,       # tablecloth dragged
	&"crash": 0.7,       # "CHOANG!" the plate hits the floor
	&"door": 0.3,        # "Cạch!"
	&"phone": 1.0,       # phone ringing
	# Story and interface
	&"shout": 0.6,       # comic "BÙM" under "LỘC!!!"
	&"task": 0.35,       # a task ticked
	&"whoosh": 0.9,      # time flies / circle closes
	&"pop": 0.1,         # a speech bubble appears
	&"win": 1.2,         # day passed
	&"fail": 1.2,        # caught
}


## The wave function of sound [param name] (a Callable: seconds → sample).
static func wave(name: StringName) -> Callable:
	return Callable(SoundRecipes, "_w_" + String(name))


## Renders sound [param name] to samples at [param rate].
static func render(name: StringName, rate: int = Synth.RATE) -> PackedFloat32Array:
	return Synth.render(ALL[name], wave(name), rate)


# ---------------------------------------------------------------- Mèo Xinh

static func _w_step(t: float) -> float:
	# Filtered-sounding noise burst plus a low thud: a soft paw, not a shoe.
	return (Synth.noise(t) * 0.25 * exp(-t * 90.0) + sin(TAU * 110.0 * t) * 0.4 * exp(-t * 60.0)) * Synth.attack(t)


static func _w_jump(t: float) -> float:
	var ph := TAU * (300.0 * t + 900.0 * t * t)  # rising pitch
	return Synth.triangle(ph) * exp(-t * 12.0) * 0.35 * Synth.attack(t)


static func _w_land(t: float) -> float:
	return (sin(Synth.glide(t, 90.0, 1.0, 40.0)) * 0.6 + Synth.noise(t) * 0.2 * exp(-t * 80.0)) * exp(-t * 25.0) * Synth.attack(t)


static func _w_meow(t: float) -> float:
	# "Mi-aaow": pitch rises then falls; an "ee→aa→oo" brightness sweep from
	# mixing the 2nd and 3rd harmonics in and out.
	var f := 620.0 + 380.0 * sin(PI * minf(t / 0.38, 1.0)) - 160.0 * t
	var ph := TAU * f * t
	var bright := sin(PI * minf(t / 0.3, 1.0))
	var s := sin(ph) + 0.5 * bright * sin(2.0 * ph) + 0.25 * bright * sin(3.0 * ph)
	var env := minf(1.0, t * 30.0) * exp(-maxf(0.0, t - 0.25) * 9.0)
	return s * env * 0.35 * (1.0 + 0.08 * sin(TAU * 7.0 * t))


static func _w_eat(t: float) -> float:
	# Three quick "nom"s.
	var lt := fmod(t, 0.11)
	return sin(Synth.glide(lt, 220.0, 0.5, 30.0)) * exp(-lt * 30.0) * 0.45 * Synth.attack(lt)


static func _w_lap(t: float) -> float:
	# Four little laps of water: short bright blips with a pitch drop.
	var lt := fmod(t, 0.1)
	return sin(Synth.glide(lt, 900.0, 0.8, 60.0)) * exp(-lt * 45.0) * 0.3 * Synth.attack(lt)


static func _w_hihi(t: float) -> float:
	# "Hi hi hi": three high, fast-decaying chirps going up.
	var i := mini(int(t / 0.16), 2)
	var lt := t - i * 0.16
	var f: float = [880.0, 988.0, 1175.0][i]
	return Synth.triangle(Synth.glide(lt, f, 0.3, 40.0)) * exp(-lt * 14.0) * 0.3 * Synth.attack(lt)


# ---------------------------------------------------------------- Lộc

static func _w_bark(t: float) -> float:
	# Pitch drop + square buzz + a breath of noise: a small, friendly "gâu".
	var ph := Synth.glide(t, 260.0, 0.7, 25.0)
	var s := 0.55 * Synth.square(ph) * exp(-t * 6.0) + 0.45 * sin(ph) + Synth.noise(t) * 0.15
	return s * exp(-t * 14.0) * 0.4 * Synth.attack(t)


static func _w_yelp(t: float) -> float:
	var ph := Synth.glide(t, 700.0, -0.4, 10.0)  # bends up
	return (0.6 * sin(ph) + 0.4 * Synth.triangle(2.0 * ph)) * exp(-t * 9.0) * 0.4 * Synth.attack(t)


static func _w_huhu(t: float) -> float:
	# "Hu... hu... hu": three sobs falling in pitch, each with a wobble.
	var i := mini(int(t / 0.4), 2)
	var lt := t - i * 0.4
	var f := 420.0 - i * 40.0 - lt * 120.0
	var ph := TAU * f * lt + 0.6 * sin(TAU * 9.0 * lt)
	return (sin(ph) + 0.3 * sin(2.0 * ph)) * sin(PI * minf(lt / 0.36, 1.0)) * 0.35


# ---------------------------------------------------------------- objects

static func _w_thread(t: float) -> float:
	# Many tiny clicks, thinning out: the spool unrolling.
	var rate := 40.0 * exp(-t * 2.0)
	var lt := fmod(t, 1.0 / maxf(rate, 1.0))
	return Synth.noise(t) * exp(-lt * 400.0) * 0.4


static func _w_roll(t: float) -> float:
	return (Synth.noise(t) * 0.15 + sin(TAU * 80.0 * t) * 0.2) * (1.0 + 0.5 * sin(TAU * 12.0 * t)) * exp(-t * 4.0) * Synth.attack(t)


static func _w_slide(t: float) -> float:
	# Cloth dragged: noise swelling and fading, slightly rough.
	var env := sin(PI * minf(t / 0.8, 1.0))
	return Synth.noise(t) * env * 0.22 * (0.7 + 0.3 * sin(TAU * 23.0 * t))


static func _w_crash(t: float) -> float:
	# "CHOANG!": a noisy hit plus three inharmonic ringing partials (plate).
	var hit := Synth.noise(t) * exp(-t * 30.0) * 0.6
	var ring := sin(TAU * 1240.0 * t) * 0.3 + sin(TAU * 1873.0 * t) * 0.22 + sin(TAU * 2711.0 * t) * 0.15
	return (hit + ring * exp(-t * 6.0)) * Synth.attack(t) * 0.8


static func _w_door(t: float) -> float:
	# "Cạch": two clicks, the latch then the door.
	var a := Synth.noise(t) * exp(-t * 200.0) + sin(TAU * 1800.0 * t) * exp(-t * 90.0) * 0.4
	var lt := maxf(0.0, t - 0.09)
	var b := (Synth.noise(lt) * exp(-lt * 120.0) + sin(TAU * 140.0 * lt) * exp(-lt * 30.0)) if t > 0.09 else 0.0
	return (a * 0.5 + b * 0.6) * Synth.attack(t)


static func _w_phone(t: float) -> float:
	# Old phone trill: two tones alternating 20 times a second, in two bursts.
	var on := 1.0 if fmod(t, 0.5) < 0.4 else 0.0
	var f := 1300.0 if fmod(t, 0.05) < 0.025 else 1600.0
	return sin(TAU * f * t) * on * 0.22


# ---------------------------------------------------------------- story and interface

static func _w_shout(t: float) -> float:
	# Comic "BÙM": a deep pitch drop with a noisy blast on top.
	var boom := sin(Synth.glide(t, 55.0, 2.5, 12.0)) * exp(-t * 5.0)
	var blast := Synth.noise(t) * exp(-t * 14.0) * 0.5
	return (boom * 0.8 + blast) * Synth.attack(t) * 0.8


static func _w_task(t: float) -> float:
	# Two bright notes up (E6, A6): "done!".
	var f := 1318.5 if t < 0.09 else 1760.0
	var lt := t if t < 0.09 else t - 0.09
	return Synth.triangle(TAU * f * t) * exp(-lt * 12.0) * 0.3 * minf(1.0, lt * 600.0)


static func _w_whoosh(t: float) -> float:
	var env := sin(PI * minf(t / 0.9, 1.0))
	var tone := sin(Synth.glide(t, 300.0, 1.5, 3.0)) * 0.15
	return (Synth.noise(t) * 0.25 + tone) * env * env


static func _w_pop(t: float) -> float:
	return sin(Synth.glide(t, 500.0, 1.2, 60.0)) * exp(-t * 40.0) * 0.4 * Synth.attack(t)


static func _w_win(t: float) -> float:
	# C-E-G-C arpeggio up, last note rings.
	var freqs := [523.25, 659.25, 783.99, 1046.5]
	var i := mini(int(t / 0.12), 3)
	var lt := t - i * 0.12
	return Synth.piano(lt, freqs[i]) * 0.9


static func _w_fail(t: float) -> float:
	# "Wah wah": two notes sliding down, a little sad but funny.
	var i := mini(int(t / 0.45), 1)
	var lt := t - i * 0.45
	var f: float = [392.0, 349.2][i] * (1.0 - 0.06 * minf(lt / 0.4, 1.0))
	var ph := TAU * f * lt + 0.4 * sin(TAU * 6.0 * lt)
	return (Synth.triangle(ph) * 0.7 + Synth.square(ph) * 0.15) * exp(-lt * 2.5) * 0.35 * Synth.attack(lt)
