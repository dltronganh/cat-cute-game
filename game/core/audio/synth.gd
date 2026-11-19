class_name Synth
extends RefCounted
## A tiny offline synthesizer: turns wave functions into sample buffers and WAV
## streams. Pure logic (no nodes), so it is unit-tested and can run in a tool
## script that bakes the game's sounds to .wav files (tools/bake_audio.ps1).
##
## Conventions: samples are floats in [-1, 1], mono. A "wave" is a Callable
## taking the time in seconds (float) and returning one sample (float).
## Kept in the spirit of the beat beat game's chiptune bank (sound
## effects synthesized for now, music synthesized for good).

## Default sample rate for sound effects (CD quality).
const RATE := 44100

## Length of the fade-out applied to every rendered sound, in seconds.
## Cutting a wave mid-swing makes an audible click; a 3 ms fade hides it.
const FADE_OUT := 0.003


## Renders [param wave] for [param seconds] at [param rate] samples per second.
## Output is clamped to [-1, 1] and fades out over the last [constant FADE_OUT].
static func render(seconds: float, wave: Callable, rate: int = RATE) -> PackedFloat32Array:
	var n := int(seconds * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / rate
		var tail := minf(1.0, (seconds - t) / FADE_OUT)
		out[i] = clampf(float(wave.call(t)), -1.0, 1.0) * tail
	return out


## Packs [param samples] into a 16-bit mono [AudioStreamWAV].
## With [param loop] the whole buffer repeats (used for music).
static func to_wav(samples: PackedFloat32Array, rate: int = RATE, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Scales [param samples] so the loudest sample reaches [param peak].
## Silent buffers are returned unchanged.
static func normalize(samples: PackedFloat32Array, peak: float = 0.9) -> PackedFloat32Array:
	var loudest := 0.0
	for s in samples:
		loudest = maxf(loudest, absf(s))
	if loudest < 0.0001:
		return samples
	var gain := peak / loudest
	var out := samples.duplicate()
	for i in out.size():
		out[i] *= gain
	return out


## Adds one note into [param buffer], starting at [param start] seconds, using
## [param voice] (a Callable taking (time_in_note, frequency) → sample).
## Notes that run past the end wrap around to the start, so a music loop
## rings on seamlessly when it repeats.
static func add_note(buffer: PackedFloat32Array, rate: int, start: float, length: float,
		freq: float, gain: float, voice: Callable) -> void:
	var first := int(start * rate)
	var n := int(length * rate)
	var size := buffer.size()
	for i in n:
		var t := float(i) / rate
		var tail := minf(1.0, (length - t) / 0.02)  # 20 ms release, no click
		var idx := (first + i) % size
		buffer[idx] += float(voice.call(t, freq)) * gain * tail


## Frequency in Hz of a MIDI note number (69 = A4 = 440 Hz, 60 = middle C).
static func midi_hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


# ---------------------------------------------------------------- wave helpers

## Square wave at phase [param ph] (radians): +1 or -1.
static func square(ph: float) -> float:
	return 1.0 if sin(ph) >= 0.0 else -1.0


## Triangle wave at phase [param ph] (radians), softer than a square.
static func triangle(ph: float) -> float:
	return asin(sin(ph)) * 2.0 / PI


## Phase of a tone that starts at [param f0] × (1 + [param bend]) and glides to
## [param f0] with speed [param k] (bigger = faster). Gives "boing" and "meow" shapes.
static func glide(t: float, f0: float, bend: float, k: float) -> float:
	return TAU * (f0 * t + f0 * bend * (1.0 - exp(-k * t)) / k)


## 0 → 1 over 2.5 ms: a fast attack without a click.
static func attack(t: float) -> float:
	return minf(1.0, t * 400.0)


## Deterministic white noise in [-1, 1] for time [param t] (same sound on every
## bake, so baked files only change when a recipe changes).
static func noise(t: float) -> float:
	var x := sin(t * 12_989.8 + 78.233) * 43_758.5453
	return (x - floorf(x)) * 2.0 - 1.0


## A soft piano-like tone: a sine plus quieter 2nd and 3rd harmonics, with a
## quick attack and a long exponential decay. [param t] is time in the note.
static func piano(t: float, freq: float) -> float:
	var ph := TAU * freq * t
	var body := sin(ph) + 0.35 * sin(2.0 * ph) * exp(-t * 3.0) + 0.12 * sin(3.0 * ph) * exp(-t * 6.0)
	return body * exp(-t * 2.2) * minf(1.0, t * 250.0) * 0.6
