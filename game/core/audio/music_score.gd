class_name MusicScore
extends RefCounted
## The two background music loops: a light, happy piano tune for the
## day and a slower, warmer one for the evening, synthesized with [Synth].
## tools/bake_audio.ps1 renders them to assets/audio/music/<name>.wav.
##
## Each tune is written as data: a tempo, a chord progression (bass + chord
## notes as MIDI numbers) and a melody. Loops are seamless: notes that ring
## past the end of the loop wrap around to its start ([method Synth.add_note]).

## Sample rate for music. Lower than effects to keep the files small; a soft
## piano has almost nothing above 11 kHz.
const RATE := 22050

## Tune name → its score. Bars are 4 beats. Melody entries are
## [beat, MIDI note, length in beats]; beat counts from 0 at the loop start.
const TUNES := {
	&"day": {
		"bpm": 104.0,
		# C - Am - F - G, twice; a bright, bouncy left hand.
		"chords": [[48, [60, 64, 67]], [45, [60, 64, 69]], [41, [60, 65, 69]], [43, [59, 62, 67]],
			[48, [60, 64, 67]], [45, [60, 64, 69]], [41, [60, 65, 69]], [43, [59, 62, 67]]],
		"style": "bounce",
		"melody": [
			[0.0, 76, 1.0], [1.0, 79, 0.5], [1.5, 76, 0.5], [2.0, 74, 1.0], [3.0, 72, 1.0],
			[4.0, 72, 1.0], [5.0, 76, 0.5], [5.5, 74, 0.5], [6.0, 72, 1.0], [7.0, 69, 1.0],
			[8.0, 69, 1.0], [9.0, 72, 0.5], [9.5, 74, 0.5], [10.0, 77, 1.0], [11.0, 76, 1.0],
			[12.0, 74, 1.5], [13.5, 71, 0.5], [14.0, 74, 2.0],
			[16.0, 76, 1.0], [17.0, 79, 0.5], [17.5, 81, 0.5], [18.0, 79, 1.0], [19.0, 76, 1.0],
			[20.0, 72, 1.0], [21.0, 74, 0.5], [21.5, 76, 0.5], [22.0, 72, 2.0],
			[24.0, 77, 1.0], [25.0, 76, 0.5], [25.5, 74, 0.5], [26.0, 72, 1.0], [27.0, 69, 1.0],
			[28.0, 71, 1.0], [29.0, 74, 1.0], [30.0, 72, 2.0],
		],
	},
	&"dusk": {
		"bpm": 76.0,
		# Fmaj7 - Em7 - Dm7 - Cmaj7, twice; slow rolled arpeggios.
		"chords": [[41, [57, 60, 64, 65]], [40, [55, 59, 62, 64]], [38, [57, 60, 62, 65]], [36, [55, 59, 60, 64]],
			[41, [57, 60, 64, 65]], [40, [55, 59, 62, 64]], [38, [57, 60, 62, 65]], [36, [55, 59, 60, 64]]],
		"style": "arpeggio",
		"melody": [
			[0.0, 72, 2.0], [2.0, 69, 1.0], [3.0, 71, 1.0], [4.0, 67, 3.0],
			[8.0, 69, 1.5], [9.5, 72, 0.5], [10.0, 74, 2.0], [12.0, 72, 4.0],
			[16.0, 76, 2.0], [18.0, 74, 1.0], [19.0, 72, 1.0], [20.0, 71, 3.0],
			[24.0, 69, 1.5], [25.5, 67, 0.5], [26.0, 69, 2.0], [28.0, 64, 4.0],
		],
	},
}


## Length of tune [param name] in seconds (one full loop).
static func loop_seconds(name: StringName) -> float:
	var tune: Dictionary = TUNES[name]
	return (tune["chords"] as Array).size() * 4.0 * 60.0 / float(tune["bpm"])


## Renders tune [param name] as one seamless loop of samples at [constant RATE].
static func render(name: StringName) -> PackedFloat32Array:
	var tune: Dictionary = TUNES[name]
	var beat := 60.0 / float(tune["bpm"])
	var buffer := PackedFloat32Array()
	buffer.resize(int(loop_seconds(name) * RATE))
	var piano := Callable(Synth, "piano")
	var bar := 0
	for chord: Array in tune["chords"]:
		var start := bar * 4.0 * beat
		var bass: int = chord[0]
		var notes: Array = chord[1]
		if tune["style"] == "bounce":
			# Bass on beats 1 and 3, chord stabs on 2 and 4.
			Synth.add_note(buffer, RATE, start, beat * 1.8, Synth.midi_hz(bass), 0.5, piano)
			Synth.add_note(buffer, RATE, start + 2.0 * beat, beat * 1.8, Synth.midi_hz(bass + 7), 0.4, piano)
			for b in [1.0, 3.0]:
				for n: int in notes:
					Synth.add_note(buffer, RATE, start + b * beat, beat * 0.9, Synth.midi_hz(n), 0.16, piano)
		else:
			# One long bass note, the chord rolled up and down in eighths.
			Synth.add_note(buffer, RATE, start, beat * 4.0, Synth.midi_hz(bass), 0.45, piano)
			var order := notes + [notes[2], notes[1], notes[0], notes[1]]
			for i in 8:
				var n: int = order[i % order.size()]
				Synth.add_note(buffer, RATE, start + i * beat * 0.5, beat * 1.5, Synth.midi_hz(n), 0.14, piano)
		bar += 1
	for m: Array in tune["melody"]:
		Synth.add_note(buffer, RATE, float(m[0]) * beat, float(m[2]) * beat + 0.3, Synth.midi_hz(m[1]), 0.32, piano)
	return Synth.normalize(buffer, 0.8)
