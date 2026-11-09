class_name ProceduralAudio
extends RefCounted

# 低采样率芯片音：与像素风一致，且启动时合成开销可控。
const SAMPLE_RATE := 11025
const BGM_IDS := ["finale"]
const LOOP_IDS := ["pour", "shake", "stir"]
const SFX_IDS := [
	"ui_click", "glass", "ice", "garnish", "splash", "star", "coin",
	"fail", "purchase", "leave", "success", "whoosh", "tutorial",
]


static func build(id: String) -> AudioStreamWAV:
	match id:
		"finale":
			return _build_bgm()
		"pour", "shake", "stir":
			return _build_loop(id)
		_:
			return _build_sfx(id)


static func _build_bgm() -> AudioStreamWAV:
	var beat := 60.0 / 116.0
	var bars := 4
	var total_samples := int(round(float(bars * 4) * beat * SAMPLE_RATE)) + 1
	var buf := PackedFloat32Array()
	buf.resize(total_samples)
	buf.fill(0.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 91027

	var chords: Array = [
		[53, 57, 60, 64], [55, 59, 62, 65], [48, 52, 55, 59], [45, 48, 52, 55],
	]
	var roots := [41, 43, 36, 45]
	var melody: Array = [
		[0, 0.0, 72, 0.75], [0, 1.5, 77, 0.5], [0, 2.5, 81, 0.5], [0, 3.5, 79, 0.6],
		[1, 0.5, 79, 0.5], [1, 1.5, 83, 0.5], [1, 2.5, 81, 0.5], [1, 3.5, 79, 0.5],
		[2, 0.0, 76, 0.75], [2, 1.5, 79, 0.5], [2, 2.5, 84, 0.6], [2, 3.5, 83, 0.5],
		[3, 0.5, 81, 0.5], [3, 1.5, 79, 0.5], [3, 2.5, 76, 0.5], [3, 3.5, 72, 0.7],
	]

	for bar in range(bars):
		var bar_start := float(bar * 4)
		var chord: Array = chords[bar]
		var root: int = roots[bar]

		for note_index in range(3):
			var midi := int(chord[note_index + 1]) if note_index > 0 else int(chord[0])
			_note(buf, (bar_start + 0.0) * beat, beat * 1.85, midi, 0.038, "pad")
			_note(buf, (bar_start + 2.0) * beat, beat * 1.75, midi, 0.032, "pad")

		var bass_pattern := [[0.0, 0.7], [1.5, 0.45], [2.0, 0.65], [3.5, 0.4]]
		var bass_notes := [root, root + 7, root + 12, root + 7]
		for i in range(bass_pattern.size()):
			var entry: Array = bass_pattern[i]
			_note(buf, (bar_start + float(entry[0])) * beat, float(entry[1]) * beat,
				int(bass_notes[i]), 0.2, "bass")

		_drum(buf, bar_start * beat, "kick", 0.15, rng)
		_drum(buf, (bar_start + 2.0) * beat, "kick", 0.12, rng)
		_drum(buf, (bar_start + 1.0) * beat, "snare", 0.055, rng)
		_drum(buf, (bar_start + 3.0) * beat, "snare", 0.055, rng)
		for step in range(8):
			var pos := bar_start + float(step) * 0.5
			if step % 2 == 1:
				pos += 0.08
			_drum(buf, pos * beat, "hat", 0.018, rng)

	for entry in melody:
		var bar := int(entry[0])
		var pos := float(entry[1])
		if absf(pos - floor(pos) - 0.5) < 0.01:
			pos += 0.08
		_note(buf, (float(bar * 4) + pos) * beat, float(entry[3]) * beat,
			int(entry[2]), 0.105, "lead")

	_normalize(buf, 0.72)
	return _to_stream(buf, true)


static func _drum(buf: PackedFloat32Array, start: float, kind: String, gain: float, rng: RandomNumberGenerator) -> void:
	var i0 := int(round(start * SAMPLE_RATE))
	match kind:
		"kick":
			var count := int(0.16 * SAMPLE_RATE)
			var phase := 0.0
			for i in range(count):
				var idx := i0 + i
				if idx < 0 or idx >= buf.size():
					continue
				var t := float(i) / SAMPLE_RATE
				var freq := 92.0 - 46.0 * minf(1.0, t / 0.12)
				phase += TAU * freq / SAMPLE_RATE
				buf[idx] += sin(phase) * exp(-16.0 * t) * gain
		"snare":
			var count := int(0.14 * SAMPLE_RATE)
			var phase := 0.0
			var lp := 0.0
			for i in range(count):
				var idx := i0 + i
				if idx < 0 or idx >= buf.size():
					continue
				var t := float(i) / SAMPLE_RATE
				var noise := rng.randf_range(-1.0, 1.0)
				lp += (noise - lp) * 0.55
				phase += TAU * 186.0 / SAMPLE_RATE
				buf[idx] += (lp * 0.55 + sin(phase) * 0.25) * exp(-20.0 * t) * gain
		"hat":
			var count := int(0.055 * SAMPLE_RATE)
			var previous := 0.0
			for i in range(count):
				var idx := i0 + i
				if idx < 0 or idx >= buf.size():
					continue
				var t := float(i) / SAMPLE_RATE
				var noise := rng.randf_range(-1.0, 1.0)
				var high := noise - previous
				previous = noise
				buf[idx] += high * exp(-70.0 * t) * gain


static func _note(buf: PackedFloat32Array, start: float, duration: float, midi: int, gain: float, kind: String) -> void:
	var i0 := int(round(start * SAMPLE_RATE))
	var count := int(round(duration * SAMPLE_RATE))
	if count <= 0:
		return
	var freq := _midi_freq(midi)
	var phase := 0.0
	var inc := TAU * freq / SAMPLE_RATE
	var attack := maxi(1, int(0.008 * SAMPLE_RATE))
	var release := maxi(1, int(0.035 * SAMPLE_RATE))

	for i in range(count):
		var idx := i0 + i
		if idx < 0:
			continue
		if idx >= buf.size():
			break
		var t := float(i) / SAMPLE_RATE
		var env := 1.0
		match kind:
			"bass":
				env = minf(1.0, float(i) / float(attack)) * exp(-3.1 * t)
			"pad":
				var attack_pad := maxi(1, int(0.07 * SAMPLE_RATE))
				env = minf(1.0, float(i) / float(attack_pad)) * clampf(float(count - i) / float(release), 0.0, 1.0) * 0.8
			"lead":
				env = minf(1.0, float(i) / float(attack)) * exp(-2.4 * t) * clampf(float(count - i) / float(release), 0.0, 1.0)
			"pluck":
				env = minf(1.0, float(i) / float(maxi(1, int(0.004 * SAMPLE_RATE)))) * exp(-9.0 * t)
		var value := 0.0
		match kind:
			"bass":
				value = sin(phase) + 0.28 * sin(phase * 2.0) + 0.1 * sin(phase * 3.0)
			"pad":
				value = sin(phase) + 0.3 * sin(phase * 2.0) + 0.14 * sin(phase * 3.0)
			"lead":
				value = sin(phase) + 0.2 * sin(phase * 2.0) + 0.06 * sin(phase * 3.0)
			"pluck":
				value = sin(phase) + 0.22 * sin(phase * 2.0)
		buf[idx] += value * env * gain
		phase += inc


static func _build_loop(id: String) -> AudioStreamWAV:
	var seconds := 1.0 if id == "pour" else (0.6 if id == "shake" else 0.85)
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * SAMPLE_RATE))
	buf.fill(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)

	match id:
		"pour":
			var lp := 0.0
			for i in range(buf.size()):
				var t := float(i) / SAMPLE_RATE
				var noise := rng.randf_range(-1.0, 1.0)
				lp += (noise - lp) * 0.09
				var wobble := 0.55 + 0.18 * sin(t * TAU * 3.0)
				buf[i] = lp * wobble
			for i in range(9):
				var at := rng.randf_range(0.0, seconds - 0.08)
				_blip(buf, at, 0.05, rng.randf_range(320.0, 620.0), rng.randf_range(620.0, 980.0), 0.05, 0, 40.0)
			_normalize(buf, 0.42)
		"shake":
			var lp := 0.0
			for i in range(buf.size()):
				var t := float(i) / SAMPLE_RATE
				var noise := rng.randf_range(-1.0, 1.0)
				lp += (noise - lp) * 0.3
				var env := 0.5 + 0.5 * sin(t * TAU * 6.0)
				buf[i] = lp * env * 0.5
			for at in [0.02, 0.17, 0.31, 0.44]:
				_blip(buf, at, 0.07, 1680.0, 2280.0, 0.12, 0, 55.0)
				_blip(buf, at + 0.03, 0.06, 2480.0, 2900.0, 0.06, 0, 70.0)
			_normalize(buf, 0.55)
		"stir":
			var lp := 0.0
			for i in range(buf.size()):
				var t := float(i) / SAMPLE_RATE
				var noise := rng.randf_range(-1.0, 1.0)
				lp += (noise - lp) * 0.16
				var env := 0.4 + 0.45 * sin(t * TAU * 2.0)
				buf[i] = lp * env * 0.35
			for at in [0.1, 0.32, 0.55, 0.74]:
				_blip(buf, at, 0.13, 1450.0, 1720.0, 0.045, 0, 24.0)
			_normalize(buf, 0.4)

	_make_loopable(buf, 0.06)
	return _to_stream(buf, true)


static func _build_sfx(id: String) -> AudioStreamWAV:
	var length := 0.3
	match id:
		"ui_click", "garnish", "star", "tutorial":
			length = 0.4
		"purchase", "success":
			length = 0.9
		"leave":
			length = 0.55
		"splash", "whoosh", "fail", "coin", "glass", "ice":
			length = 0.4
	var buf := PackedFloat32Array()
	buf.resize(int(length * SAMPLE_RATE))
	buf.fill(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)

	match id:
		"ui_click":
			_blip(buf, 0.0, 0.055, 900.0, 720.0, 0.2, 1, 45.0)
		"glass":
			_blip(buf, 0.0, 0.16, 1560.0, 1520.0, 0.16, 0, 18.0)
			_blip(buf, 0.0, 0.12, 2340.0, 2280.0, 0.08, 0, 22.0)
		"ice":
			for at in [0.0, 0.035, 0.075]:
				_blip(buf, at, 0.06, 2200.0 + at * 4000.0, 2600.0, 0.1, 0, 40.0)
			_blip(buf, 0.0, 0.05, 640.0, 520.0, 0.05, 0, 30.0)
		"garnish":
			_blip(buf, 0.0, 0.12, 660.0, 990.0, 0.12, 2, 22.0)
		"splash":
			var lp := 0.0
			for i in range(int(0.3 * SAMPLE_RATE)):
				var t := float(i) / SAMPLE_RATE
				var noise := rng.randf_range(-1.0, 1.0)
				lp += (noise - lp) * 0.2
				buf[i] += lp * exp(-9.0 * t) * 0.35
			_blip(buf, 0.0, 0.22, 520.0, 190.0, 0.1, 0, 8.0)
		"star":
			_blip(buf, 0.0, 0.16, 1046.0, 1046.0, 0.12, 0, 8.0)
			_blip(buf, 0.07, 0.16, 1318.0, 1318.0, 0.11, 0, 8.0)
			_blip(buf, 0.14, 0.22, 1568.0, 1568.0, 0.1, 0, 7.0)
		"coin":
			_blip(buf, 0.0, 0.065, 1320.0, 1320.0, 0.11, 1, 45.0)
			_blip(buf, 0.07, 0.09, 1760.0, 1760.0, 0.1, 1, 35.0)
		"fail":
			_blip(buf, 0.0, 0.14, 392.0, 370.0, 0.1, 2, 14.0)
			_blip(buf, 0.13, 0.24, 311.0, 280.0, 0.11, 2, 9.0)
		"purchase":
			for midi in [72, 76, 79]:
				_blip(buf, 0.0, 0.42, _midi_freq(midi), _midi_freq(midi), 0.07, 0, 7.0)
			_blip(buf, 0.24, 0.35, 1046.0, 1568.0, 0.08, 0, 6.0)
		"leave":
			_blip(buf, 0.0, 0.5, 196.0, 155.0, 0.1, 2, 5.0)
		"success":
			var notes := [60, 64, 67, 72]
			for i in range(notes.size()):
				_blip(buf, float(i) * 0.11, 0.34, _midi_freq(int(notes[i])), _midi_freq(int(notes[i])), 0.1, 0, 7.0)
			for midi in [60, 64, 67, 72]:
				_blip(buf, 0.44, 0.45, _midi_freq(midi), _midi_freq(midi), 0.05, 0, 3.5)
		"whoosh":
			var lp := 0.0
			for i in range(int(0.35 * SAMPLE_RATE)):
				var t := float(i) / SAMPLE_RATE
				var noise := rng.randf_range(-1.0, 1.0)
				lp += (noise - lp) * (0.03 + 0.22 * sin(PI * minf(1.0, t / 0.35)))
				var env := sin(PI * minf(1.0, t / 0.35))
				buf[i] += lp * env * 0.5
		"tutorial":
			_blip(buf, 0.0, 0.3, 1318.0, 1318.0, 0.1, 0, 8.0)
			_blip(buf, 0.08, 0.32, 1760.0, 1760.0, 0.07, 0, 7.0)

	_normalize(buf, 0.6)
	return _to_stream(buf, false)


static func _blip(buf: PackedFloat32Array, start: float, duration: float, f0: float, f1: float, gain: float, wave: int, decay: float) -> void:
	var i0 := int(round(start * SAMPLE_RATE))
	var count := int(round(duration * SAMPLE_RATE))
	var phase := 0.0
	for i in range(count):
		var idx := i0 + i
		if idx < 0:
			continue
		if idx >= buf.size():
			break
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / float(maxi(1, count))
		var freq := lerpf(f0, f1, progress)
		phase += TAU * freq / SAMPLE_RATE
		var value := sin(phase)
		match wave:
			1:
				value = signf(sin(phase))
			2:
				value = asin(sin(phase)) * 0.6366
			3:
				value = fmod(phase / TAU, 1.0) * 2.0 - 1.0
		var attack := minf(1.0, float(i) / float(maxi(1, int(0.003 * SAMPLE_RATE))))
		var release := clampf(float(count - i) / float(maxi(1, int(0.01 * SAMPLE_RATE))), 0.0, 1.0)
		buf[idx] += value * exp(-decay * t) * attack * release * gain


static func _make_loopable(buf: PackedFloat32Array, fade_seconds: float) -> void:
	var fade := int(fade_seconds * SAMPLE_RATE)
	var n := buf.size()
	if fade <= 0 or n <= fade * 2:
		return
	for i in range(fade):
		var blend := float(i) / float(fade)
		buf[i] = buf[i] * blend + buf[n - fade + i] * (1.0 - blend)
	buf.resize(n - fade)


static func _normalize(buf: PackedFloat32Array, target_peak: float) -> void:
	var peak := 0.0
	for value in buf:
		peak = maxf(peak, absf(value))
	if peak <= 0.0001:
		return
	var scale := target_peak / peak
	for i in range(buf.size()):
		buf[i] *= scale


static func _to_stream(buf: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in range(buf.size()):
		data.encode_s16(i * 2, int(round(clampf(buf[i], -1.0, 1.0) * 32767.0)))
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buf.size()
	return stream


static func _midi_freq(midi: int) -> float:
	return 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)
