extends Node
## Autoload "Sfx": every sound is synthesized at startup into AudioStreamWAV (16-bit mono, 22050 Hz).
## Each buffer is peak-normalized to PEAK so it never clips; loops (wind, web_tension, ambience_city) are volume-driven.

const RATE: int = 22050
const PEAK: float = 0.8
const POOL_2D: int = 12
const POOL_3D: int = 16

var _streams: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _wind: AudioStreamPlayer
var _tension: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _wind_target: float = 0.0
var _tension_target: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_build_all()
	for i: int in range(POOL_2D):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)
	for i: int in range(POOL_3D):
		var p3: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p3.unit_size = 12.0
		p3.max_distance = 120.0
		add_child(p3)
		_pool3d.append(p3)
	_wind = _make_loop(&"wind")
	_tension = _make_loop(&"web_tension")
	_ambience = _make_loop(&"ambience_city")
	_ambience.volume_db = -18.0


## Playing loops keep their AudioStreamPlayback alive past tree teardown (BUG-001): stop and drop
## every stream on exit so nothing is left for ObjectDB cleanup.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		for c: Node in get_children():
			if c is AudioStreamPlayer:
				(c as AudioStreamPlayer).stop()
				(c as AudioStreamPlayer).stream = null
			elif c is AudioStreamPlayer3D:
				(c as AudioStreamPlayer3D).stop()
				(c as AudioStreamPlayer3D).stream = null
		_streams.clear()


func play(id: StringName, pos: Vector3 = Vector3.INF, pitch_var: float = 0.1) -> void:
	var s: AudioStreamWAV = _streams.get(id) as AudioStreamWAV
	if s == null:
		return
	var pitch: float = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	if pos == Vector3.INF or not pos.is_finite():
		var p: AudioStreamPlayer = _free2d()
		p.stream = s
		p.pitch_scale = pitch
		p.volume_db = -4.0
		p.play()
	else:
		var p3: AudioStreamPlayer3D = _free3d()
		p3.stream = s
		p3.pitch_scale = pitch
		p3.global_position = pos
		p3.play()


## speed in m/s; wind fades in from ~8 m/s and is loudest around 45 m/s.
func set_wind(speed: float) -> void:
	_wind_target = clampf((speed - 8.0) / 37.0, 0.0, 1.0)


func set_tension(t: float) -> void:
	_tension_target = clampf(t, 0.0, 1.0)


func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-delta * 6.0)
	var wl: float = lerpf(db_to_linear(_wind.volume_db) if _wind.volume_db > -79.0 else 0.0, _wind_target, k)
	_wind.volume_db = linear_to_db(maxf(wl, 0.0001)) if wl > 0.0001 else -80.0
	_wind.pitch_scale = 0.7 + _wind_target * 0.6
	var tl: float = lerpf(db_to_linear(_tension.volume_db) if _tension.volume_db > -79.0 else 0.0, _tension_target * 0.5, k)
	_tension.volume_db = linear_to_db(maxf(tl, 0.0001)) if tl > 0.0001 else -80.0


func _make_loop(id: StringName) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = _streams[id]
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _free2d() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _pool2d:
		if not p.playing:
			return p
	return _pool2d[_rng.randi() % _pool2d.size()]


func _free3d() -> AudioStreamPlayer3D:
	for p: AudioStreamPlayer3D in _pool3d:
		if not p.playing:
			return p
	return _pool3d[_rng.randi() % _pool3d.size()]


# ---------- synthesis ----------

func _build_all() -> void:
	_streams[&"thwip"] = _wav(_thwip(), false)
	_streams[&"web_tension"] = _wav(_tension_loop(), true)
	_streams[&"wind"] = _wav(_wind_loop(), true)
	for i: int in range(1, 5):
		_streams[StringName("hit_%d" % i)] = _wav(_hit(i), false)
	_streams[&"footstep"] = _wav(_thud(0.08, 140.0, 0.4), false)
	_streams[&"land"] = _wav(_thud(0.25, 90.0, 0.7), false)
	_streams[&"hero_land"] = _wav(_thud(0.7, 55.0, 1.0), false)
	_streams[&"sense_tingle"] = _wav(_tingle(), false)
	_streams[&"perfect"] = _wav(_chime([880.0, 1320.0, 1760.0], 0.5), false)
	_streams[&"ui_click"] = _wav(_blip(1200.0, 0.04), false)
	_streams[&"ui_select"] = _wav(_chime([660.0, 990.0], 0.18), false)
	_streams[&"explosion"] = _wav(_explosion(), false)
	_streams[&"ambience_city"] = _wav(_ambience_loop(), true)


func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak: float = 0.0001
	for v: float in samples:
		peak = maxf(peak, absf(v))
	var g: float = PEAK / peak
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i] * g, -1.0, 1.0) * 32767.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _env(t: float, a: float, d: float) -> float:
	if t < a:
		return t / a
	return exp(-(t - a) / d)


func _thwip() -> PackedFloat32Array:
	var n: int = int(RATE * 0.22)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var ph: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / RATE
		var cutoff: float = lerpf(0.9, 0.15, t / 0.22)
		lp += (_noise() - lp) * cutoff
		ph += TAU * lerpf(2400.0, 700.0, t / 0.22) / RATE
		out[i] = (lp * 0.8 + sin(ph) * 0.35) * _env(t, 0.004, 0.05)
	return out


func _tension_loop() -> PackedFloat32Array:
	var n: int = RATE  # 1 s; base freq periods fit exactly (110 Hz)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t: float = float(i) / RATE
		out[i] = sin(TAU * 110.0 * t) * 0.5 + sin(TAU * 220.0 * t + sin(TAU * 4.0 * t)) * 0.3 + sin(TAU * 330.0 * t) * 0.1
	return out


func _wind_loop() -> PackedFloat32Array:
	var n: int = RATE * 2
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var a: float = 0.0
	var b: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / RATE
		a += (_noise() - a) * 0.08
		b += (a - b) * 0.3
		var gust: float = 0.7 + 0.3 * sin(TAU * 0.5 * t)  # 0.5 Hz fits the 2 s loop
		out[i] = b * gust
	# crossfade the ends to hide the seam
	var x: int = 2000
	for i: int in range(x):
		var f: float = float(i) / x
		out[i] = out[i] * f + out[n - x + i] * (1.0 - f)
	out.resize(n - x)
	return out


func _hit(variant: int) -> PackedFloat32Array:
	var n: int = int(RATE * 0.18)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var f0: float = 90.0 + variant * 25.0
	var ph: float = 0.0
	var lp: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / RATE
		ph += TAU * f0 * (1.0 + 2.0 * exp(-t * 40.0)) / RATE
		lp += (_noise() - lp) * (0.3 + 0.1 * variant)
		out[i] = (sin(ph) * 0.8 * _env(t, 0.002, 0.06) + lp * _env(t, 0.001, 0.02 + 0.005 * variant))
	return out


func _thud(len_s: float, f0: float, noise_amt: float) -> PackedFloat32Array:
	var n: int = int(RATE * len_s)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var ph: float = 0.0
	var lp: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / RATE
		ph += TAU * f0 * (1.0 + exp(-t * 30.0)) / RATE
		lp += (_noise() - lp) * 0.12
		out[i] = sin(ph) * _env(t, 0.003, len_s * 0.3) + lp * noise_amt * _env(t, 0.002, len_s * 0.2)
	return out


func _tingle() -> PackedFloat32Array:
	var n: int = int(RATE * 0.6)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t: float = float(i) / RATE
		var trem: float = 0.5 + 0.5 * sin(TAU * 28.0 * t)
		out[i] = (sin(TAU * 2600.0 * t) + sin(TAU * 3170.0 * t) * 0.6) * trem * _env(t, 0.02, 0.2)
	return out


func _chime(freqs: Array, len_s: float) -> PackedFloat32Array:
	var n: int = int(RATE * len_s)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t: float = float(i) / RATE
		var v: float = 0.0
		for k: int in range(freqs.size()):
			var st: float = k * 0.05
			if t >= st:
				v += sin(TAU * float(freqs[k]) * (t - st)) * _env(t - st, 0.005, len_s * 0.35)
		out[i] = v
	return out


func _blip(f: float, len_s: float) -> PackedFloat32Array:
	var n: int = int(RATE * len_s)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t: float = float(i) / RATE
		out[i] = sin(TAU * f * t) * _env(t, 0.002, len_s * 0.3)
	return out


func _explosion() -> PackedFloat32Array:
	var n: int = int(RATE * 1.4)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var ph: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / RATE
		lp += (_noise() - lp) * lerpf(0.5, 0.03, minf(t / 0.8, 1.0))
		ph += TAU * 45.0 * (1.0 + exp(-t * 8.0)) / RATE
		out[i] = (lp * 1.2 + sin(ph) * 0.8) * _env(t, 0.005, 0.35)
	return out


func _ambience_loop() -> PackedFloat32Array:
	var n: int = RATE * 4
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / RATE
		lp += (_noise() - lp) * 0.02
		out[i] = lp + sin(TAU * 60.0 * t) * 0.05 + sin(TAU * 0.25 * t) * lp * 0.5
	var x: int = 4000
	for i: int in range(x):
		var f: float = float(i) / x
		out[i] = out[i] * f + out[n - x + i] * (1.0 - f)
	out.resize(n - x)
	return out
