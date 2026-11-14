extends Node

# Autoload "Sfx": synthesizes kompang drum hits and UI/game sounds at startup, plays them on pooled players.

const RATE := 22050
const POOL := 12

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var music_player: AudioStreamPlayer
var music_beat := 0.0


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	sounds["tung"] = _drum(170.0, 0.32, 900.0, 0.35)
	sounds["pak"] = _drum(260.0, 0.14, 2400.0, 0.7)
	sounds["hit"] = _mix([_drum(190.0, 0.3, 900.0, 0.35), _drum(260.0, 0.12, 2400.0, 0.5)])
	sounds["perfect"] = _mix([_drum(209.0, 0.3, 900.0, 0.35), _drum(260.0, 0.12, 2400.0, 0.5), _tone(1319.0, 0.25, 0.25)])
	sounds["mate"] = _drum(150.0, 0.2, 900.0, 0.2, 0.35)
	sounds["miss"] = _mix([_tone(140.0, 0.25, 0.4, "saw"), _tone(110.0, 0.25, 0.3, "saw")])
	sounds["bomb"] = _noise(0.9, 3000.0, 0.9)
	sounds["shield"] = _seq([660.0, 990.0], 0.14, "square")
	sounds["fever"] = _seq([523.0, 659.0, 784.0, 1047.0], 0.1, "tri")
	sounds["star"] = _seq([784.0, 988.0, 1175.0], 0.09, "sine")
	sounds["click"] = _tone(600.0, 0.06, 0.25, "square")
	sounds["buy"] = _seq([880.0, 1320.0], 0.09, "square")
	sounds["fail"] = _seq([392.0, 330.0, 262.0, 196.0], 0.2, "saw")
	sounds["win"] = _seq([523.0, 659.0, 784.0, 659.0, 784.0, 1047.0], 0.12, "tri")
	sounds["unlock"] = _seq([392.0, 523.0, 659.0, 784.0, 1047.0, 1319.0], 0.12, "tri")
	sounds["music"] = _music_loop()
	apply_settings()


func apply_settings() -> void:
	var s: Dictionary = Save.settings
	var master := linear_to_db(maxf(0.0001, float(s.master) / 100.0))
	AudioServer.set_bus_volume_db(0, master)
	music_player.volume_db = -80.0 if not s.music_on else linear_to_db(maxf(0.0001, float(s.music) / 100.0)) - 6.0


func play(name: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	if not Save.settings.sfx_on or not sounds.has(name):
		return
	var p := players[next_player]
	next_player = (next_player + 1) % POOL
	p.stream = sounds[name]
	p.volume_db = linear_to_db(maxf(0.0001, volume * float(Save.settings.sfx) / 100.0))
	p.pitch_scale = pitch
	p.play()


func start_music(bpm: float) -> void:
	var stream: AudioStreamWAV = sounds["music"]
	music_player.stream = stream
	music_player.pitch_scale = bpm / 100.0
	apply_settings()
	music_player.play()


func stop_music() -> void:
	music_player.stop()


func pause_music(paused: bool) -> void:
	music_player.stream_paused = paused


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _wave(kind: String, phase: float) -> float:
	var f := fposmod(phase, 1.0)
	match kind:
		"square": return 1.0 if f < 0.5 else -1.0
		"saw": return f * 2.0 - 1.0
		"tri": return absf(f * 4.0 - 2.0) - 1.0
	return sin(phase * TAU)


func _drum_samples(freq: float, dur: float, noise_hz: float, noise_amt: float, gain: float = 0.9) -> PackedFloat32Array:
	var n := int(RATE * (dur + 0.05))
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq)
	var lp := 0.0
	var k := clampf(noise_hz / float(RATE) * 2.0, 0.02, 0.9)
	for i in n:
		var t := float(i) / RATE
		var f := freq * (1.0 + 0.9 * exp(-t * 40.0))
		phase += f / RATE
		var env := exp(-t * (5.0 / dur))
		var nz := rng.randf() * 2.0 - 1.0
		lp += (nz - lp) * k
		out[i] = (sin(phase * TAU) * env + (nz - lp) * noise_amt * exp(-t * 60.0)) * gain
	return out


func _drum(freq: float, dur: float, noise_hz: float, noise_amt: float, gain: float = 0.9) -> AudioStreamWAV:
	return _wav(_drum_samples(freq, dur, noise_hz, noise_amt, gain))


func _tone_samples(freq: float, dur: float, gain: float, kind: String) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = _wave(kind, freq * t) * gain * minf(1.0, t * 200.0) * exp(-t * (3.0 / dur))
	return out


func _tone(freq: float, dur: float, gain: float = 0.3, kind := "tri") -> AudioStreamWAV:
	return _wav(_tone_samples(freq, dur, gain, kind))


func _seq(freqs: Array, step: float, kind: String) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	out.resize(int(RATE * (step * freqs.size() + 0.3)))
	for i in freqs.size():
		var s := _tone_samples(freqs[i], step + 0.25, 0.28, kind)
		var off := int(RATE * step * i)
		for j in s.size():
			if off + j < out.size():
				out[off + j] += s[j]
	return _wav(out)


func _mix(list: Array) -> AudioStreamWAV:
	var longest := 0
	var all: Array[PackedFloat32Array] = []
	for w: AudioStreamWAV in list:
		var s := PackedFloat32Array()
		s.resize(w.data.size() / 2)
		for i in s.size():
			s[i] = float(w.data.decode_s16(i * 2)) / 32000.0
		all.append(s)
		longest = maxi(longest, s.size())
	var out := PackedFloat32Array()
	out.resize(longest)
	for s in all:
		for i in s.size():
			out[i] += s[i] * 0.7
	return _wav(out)


func _noise(dur: float, start_hz: float, gain: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := clampf((start_hz * exp(-t * 5.0)) / float(RATE) * 2.0, 0.01, 0.9)
		lp += ((rng.randf() * 2.0 - 1.0) - lp) * k
		out[i] = lp * gain * exp(-t * 4.0) * 2.0
	return _mix([_wav(out), _drum(80.0, 0.5, 300.0, 0.1, 1.0)])


# One-bar loop at 100 BPM (pitch_scale adjusts to mission bpm): kompang groove plus a bass line.
func _music_loop() -> AudioStreamWAV:
	var spb := 0.6
	var total := int(RATE * spb * 4.0)
	var out := PackedFloat32Array()
	out.resize(total)
	var tung := _drum_samples(170.0, 0.3, 900.0, 0.3, 0.5)
	var pak := _drum_samples(260.0, 0.14, 2400.0, 0.6, 0.35)
	var bass := [110.0, 110.0, 146.8, 123.5]
	for step in 8:
		var off := int(RATE * spb * 0.5 * step)
		var hit: PackedFloat32Array = tung if step % 4 == 0 else (pak if step % 2 == 0 else PackedFloat32Array())
		for j in hit.size():
			if off + j < total:
				out[off + j] += hit[j]
		if step % 2 == 0:
			var b := _tone_samples(bass[step / 2], spb * 0.9, 0.22, "tri")
			for j in b.size():
				if off + j < total:
					out[off + j] += b[j]
	return _wav(out, true)
