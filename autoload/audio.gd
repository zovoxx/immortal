extends Node
## Placeholder audio. Every sound is generated procedurally at startup, unless a real file exists at
## res://audio/sfx/<name>.ogg or .wav — drop files there with the same names to replace them.
## Sound names: footstep_dirt, footstep_stone, footstep_wood, footstep_metal, footstep_sand, land,
## jump, slide, swing, hit, hurt, throw, impact, bell, thunder_warning, thunder, howl, heartbeat,
## pickup, ui_click, fire, rattle, scav_caw, horse, toll_slam, wind_loop, rain_loop, music_loop.

const RATE := 22050
const OVERRIDE_DIR := "res://audio/sfx/"

var streams: Dictionary = {}
var wind_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_rng.seed = 777
	_generate_all()
	wind_player = _make_loop("wind_loop", "SFX")
	rain_player = _make_loop("rain_loop", "SFX")
	music_player = _make_loop("music_loop", "Music")
	Settings.apply_audio()


func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _make_loop(sound: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = streams.get(sound)
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


## Sets a loop's volume (linear 0..1). Starts/stops the player as needed.
func set_loop_volume(p: AudioStreamPlayer, v: float) -> void:
	if p == null:
		return
	if v <= 0.01:
		if p.playing:
			p.stop()
		return
	p.volume_db = linear_to_db(v)
	if not p.playing and p.stream:
		p.play()


func play(sound: String, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	var s: AudioStream = streams.get(sound)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func play_at(sound: String, pos: Vector3, volume_db: float = 0.0, max_distance: float = 60.0, pitch_var: float = 0.08) -> void:
	var s: AudioStream = streams.get(sound)
	var scene := get_tree().current_scene
	if s == null or scene == null or not scene is Node3D:
		play(sound, volume_db - 6.0, pitch_var)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 6.0
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


# =====================================================================
# Synthesis
# =====================================================================

func _generate_all() -> void:
	var gens := {
		"footstep_dirt": func(): return _step(0.09, 900.0, 0.5),
		"footstep_stone": func(): return _step(0.06, 2600.0, 0.7),
		"footstep_wood": func(): return _step_tone(0.08, 220.0),
		"footstep_metal": func(): return _step_tone(0.12, 640.0),
		"footstep_sand": func(): return _step(0.14, 1800.0, 0.3),
		"land": func(): return _thump(0.25, 70.0, 0.9),
		"jump": func(): return _noise_env(0.18, 2500.0, 0.25, 0.02),
		"slide": func(): return _noise_env(0.8, 1400.0, 0.35, 0.05),
		"swing": func(): return _sweep(0.18, 300.0, 1400.0, 0.4),
		"hit": func(): return _thump(0.12, 160.0, 0.8, 0.5),
		"hurt": func(): return _sweep(0.25, 420.0, 180.0, 0.6),
		"throw": func(): return _sweep(0.15, 900.0, 300.0, 0.3),
		"impact": func(): return _thump(0.1, 300.0, 0.6, 0.7),
		"bell": func(): return _bell(2.5, 420.0),
		"thunder_warning": func(): return _crackle(1.5),
		"thunder": func(): return _rumble(3.0),
		"howl": func(): return _howl(2.2),
		"heartbeat": func(): return _heartbeat(),
		"pickup": func(): return _blip(0.12, 880.0, 1320.0),
		"ui_click": func(): return _blip(0.05, 1200.0, 1200.0),
		"fire": func(): return _crackle(1.2, 0.25),
		"rattle": func(): return _rattle(1.0),
		"scav_caw": func(): return _sweep(0.35, 900.0, 500.0, 0.5, 0.4),
		"horse": func(): return _thump(0.18, 90.0, 0.8, 0.3),
		"toll_slam": func(): return _thump(0.5, 50.0, 1.0, 0.6),
		"wind_loop": func(): return _noise_loop(3.0, 500.0),
		"rain_loop": func(): return _noise_loop(2.0, 5000.0),
		"music_loop": func(): return _drone(8.0),
	}
	for sound_name in gens:
		var override := _find_override(sound_name)
		if override:
			streams[sound_name] = override
			continue
		var samples: PackedFloat32Array = gens[sound_name].call()
		var loop: bool = String(sound_name).ends_with("_loop")
		streams[sound_name] = _to_wav(samples, loop)


func _find_override(sound_name: String) -> AudioStream:
	for ext in [".ogg", ".wav", ".mp3"]:
		var p: String = OVERRIDE_DIR + sound_name + ext
		if ResourceLoader.exists(p):
			return load(p) as AudioStream
	return null


func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a


## One-pole low-pass coefficient for a cutoff frequency.
func _lp(cutoff: float) -> float:
	return 1.0 - exp(-TAU * cutoff / RATE)


func _step(dur: float, cutoff: float, gain: float) -> PackedFloat32Array:
	var a := _buf(dur)
	var k := _lp(cutoff)
	var y := 0.0
	for i in a.size():
		var t := float(i) / a.size()
		y += k * (_rng.randf_range(-1, 1) - y)
		a[i] = y * gain * 2.5 * pow(1.0 - t, 3.0)
	return a


func _step_tone(dur: float, freq: float) -> PackedFloat32Array:
	var a := _step(dur, 1500.0, 0.4)
	for i in a.size():
		var t := float(i) / RATE
		a[i] += sin(TAU * freq * t) * 0.35 * exp(-t * 40.0)
	return a


func _thump(dur: float, freq: float, gain: float, noise: float = 0.2) -> PackedFloat32Array:
	var a := _buf(dur)
	var k := _lp(800.0)
	var y := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var env := exp(-t * 10.0 / dur)
		y += k * (_rng.randf_range(-1, 1) - y)
		a[i] = (sin(TAU * freq * t * (1.0 - t)) * (1.0 - noise) + y * noise * 2.0) * env * gain
	return a


func _noise_env(dur: float, cutoff: float, gain: float, attack: float) -> PackedFloat32Array:
	var a := _buf(dur)
	var k := _lp(cutoff)
	var y := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var env := minf(t / attack, 1.0) * (1.0 - float(i) / a.size())
		y += k * (_rng.randf_range(-1, 1) - y)
		a[i] = y * env * gain * 3.0
	return a


func _sweep(dur: float, f0: float, f1: float, gain: float, noise: float = 0.15) -> PackedFloat32Array:
	var a := _buf(dur)
	var phase := 0.0
	for i in a.size():
		var u := float(i) / a.size()
		phase += TAU * lerpf(f0, f1, u) / RATE
		var env := sin(PI * u)
		a[i] = (sin(phase) + _rng.randf_range(-1, 1) * noise) * env * gain
	return a


func _bell(dur: float, f: float) -> PackedFloat32Array:
	var a := _buf(dur)
	var partials := [[1.0, 1.0], [2.76, 0.5], [5.4, 0.25], [8.93, 0.12]]
	for i in a.size():
		var t := float(i) / RATE
		var s := 0.0
		for p in partials:
			s += sin(TAU * f * p[0] * t) * p[1] * exp(-t * (1.2 + p[0] * 0.4))
		a[i] = s * 0.45
	return a


func _crackle(dur: float, gain: float = 0.5) -> PackedFloat32Array:
	var a := _buf(dur)
	var k := _lp(6000.0)
	var y := 0.0
	for i in a.size():
		var u := float(i) / a.size()
		var spark := _rng.randf_range(-1, 1) if _rng.randf() < 0.02 + u * 0.08 else 0.0
		y += k * (spark - y)
		a[i] = (y * 3.0 + sin(TAU * 60.0 * float(i) / RATE) * 0.15 * u) * gain
	return a


func _rumble(dur: float) -> PackedFloat32Array:
	var a := _buf(dur)
	var k := _lp(180.0)
	var y := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var env := minf(t / 0.05, 1.0) * exp(-t * 1.3) * (0.7 + 0.3 * sin(t * 13.0))
		y += k * (_rng.randf_range(-1, 1) - y)
		a[i] = y * env * 6.0
	return a


func _howl(dur: float) -> PackedFloat32Array:
	var a := _buf(dur)
	var phase := 0.0
	for i in a.size():
		var u := float(i) / a.size()
		var t := float(i) / RATE
		var f := 380.0 + 260.0 * sin(PI * minf(u * 1.4, 1.0)) + sin(t * 30.0) * 8.0
		phase += TAU * f / RATE
		a[i] = (sin(phase) * 0.7 + sin(phase * 2.0) * 0.15) * sin(PI * u) * 0.4
	return a


func _heartbeat() -> PackedFloat32Array:
	var a := _buf(0.9)
	for i in a.size():
		var t := float(i) / RATE
		var s := 0.0
		for beat in [0.0, 0.22]:
			var tb: float = t - beat
			if tb >= 0.0:
				s += sin(TAU * 55.0 * tb) * exp(-tb * 22.0)
		a[i] = s * 0.9
	return a


func _blip(dur: float, f0: float, f1: float) -> PackedFloat32Array:
	var a := _buf(dur)
	var phase := 0.0
	for i in a.size():
		var u := float(i) / a.size()
		phase += TAU * lerpf(f0, f1, u) / RATE
		a[i] = sin(phase) * (1.0 - u) * 0.35
	return a


func _rattle(dur: float) -> PackedFloat32Array:
	var a := _buf(dur)
	for i in a.size():
		var t := float(i) / RATE
		var tick := fmod(t, 0.07)
		a[i] = _rng.randf_range(-1, 1) * exp(-tick * 120.0) * 0.6
	return a


func _noise_loop(dur: float, cutoff: float) -> PackedFloat32Array:
	var a := _buf(dur)
	var k := _lp(cutoff)
	var y := 0.0
	for i in a.size():
		y += k * (_rng.randf_range(-1, 1) - y)
		a[i] = y
	# normalise & crossfade the ends for a seamless loop
	var peak := 0.001
	for v in a:
		peak = maxf(peak, absf(v))
	var fade := int(0.1 * RATE)
	for i in a.size():
		a[i] = a[i] / peak * 0.6
	for i in fade:
		var w := float(i) / fade
		a[i] = a[i] * w + a[a.size() - fade + i] * (1.0 - w)
	return a.slice(0, a.size() - fade)


func _drone(dur: float) -> PackedFloat32Array:
	var a := _buf(dur)
	var notes := [110.0, 164.81, 130.81, 146.83]
	for i in a.size():
		var t := float(i) / RATE
		var seg := int(t / (dur / 4.0)) % 4
		var f: float = notes[seg]
		var s := sin(TAU * 55.0 * t) * 0.25 + sin(TAU * f * t) * 0.12 + sin(TAU * f * 1.5 * t) * 0.05
		a[i] = s * (0.8 + 0.2 * sin(TAU * t / dur))
	return a
