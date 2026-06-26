extends Node
class_name Music
## Procedural 8-bit music, synthesized at runtime — no audio files. Three themes,
## all Capcom/Mega-Man inspired, sharing one engine (a fast arpeggio channel faking
## chords, a busy octave-jumping bass, a noise-drum groove, and a melodic hook):
##   "explore" — driving dark-minor stage theme.
##   "title"   — slow, ominous Mega-Man-X-intro dread, over a deep drone + tolls.
##   "boss"    — fast, heavy, dissonant: chromatic descent and diminished arps.
## Routes through the Master bus, so the volume setting controls it. Built once on
## _ready, then loops seamlessly.

@export var volume_db: float = -11.0
@export var autoplay: bool = true
@export var theme: String = "explore"   # "explore" | "title" | "boss"

const RATE := 16000

# --- EXPLORE: heroic-minor stage loop (i-VI-III-VII = Am F C G) ---------------
const PROG := [
	{"root": 0,  "arp": [0, 3, 7, 12]},
	{"root": -4, "arp": [-4, 0, 3, 8]},
	{"root": 3,  "arp": [3, 7, 10, 15]},
	{"root": -2, "arp": [-2, 2, 5, 10]},
	{"root": 0,  "arp": [0, 3, 7, 12]},
	{"root": -4, "arp": [-4, 0, 3, 8]},
	{"root": 3,  "arp": [3, 7, 10, 15]},
	{"root": -2, "arp": [-2, 2, 5, 10]},
]
const BASS_PAT := [0, 12, 7, 0, 12, 0, 7, 5]
const LEAD := [
	[12, 4], [10, 2], [12, 2], [7, 4], [12, 3], [14, 1],
	[15, 4], [14, 2], [12, 2], [8, 6], [-99, 2],
	[10, 4], [12, 2], [10, 2], [7, 4], [10, 4],
	[14, 4], [12, 2], [10, 2], [5, 6], [-99, 2],
	[12, 2], [15, 2], [14, 2], [12, 2], [10, 2], [12, 2], [7, 4],
	[12, 2], [15, 2], [17, 2], [15, 2], [12, 4], [8, 4],
	[15, 2], [14, 2], [12, 2], [10, 2], [7, 4], [10, 4],
	[14, 4], [10, 4], [5, 4], [2, 4],
]

# --- TITLE: ominous, slow. Am - Bb(Neapolitan) - Am - E, with F (dark color) ---
const PROG_TITLE := [
	{"root": 0,  "arp": [0, 3, 7, 12]},     # Am
	{"root": 1,  "arp": [1, 5, 8, 13]},     # Bb (flat-2, dread)
	{"root": 0,  "arp": [0, 3, 7, 12]},     # Am
	{"root": -5, "arp": [-5, -1, 2, 7]},    # E  (G# leading tone)
	{"root": -4, "arp": [-4, 0, 3, 8]},     # F
	{"root": 1,  "arp": [1, 5, 8, 13]},     # Bb
	{"root": 0,  "arp": [0, 3, 7, 12]},     # Am
	{"root": -5, "arp": [-5, -1, 2, 7]},    # E
]
const TITLE_BASS_PAT := [0, 0, 12, 0, 0, 0, 7, 0]
const TITLE_LEAD := [
	[0, 8], [3, 4], [2, 4],                 # A C B
	[1, 8], [5, 4], [1, 4],                 # Bb D Bb  (flat-2)
	[0, 6], [3, 2], [7, 8],                 # A C E
	[7, 8], [6, 4], [7, 4],                 # E Eb E   (tritone color)
	[8, 8], [7, 4], [5, 4],                 # F E D
	[1, 8], [5, 4], [8, 4],                 # Bb D F
	[0, 6], [3, 2], [2, 4], [0, 4],         # A C B A
	[7, 8], [1, 4], [0, 4],                 # E Bb A
]

# --- BOSS: relentless chromatic descent (Am Ab G Gb), diminished arps ----------
const PROG_BOSS := [
	{"root": 0,  "arp": [0, 3, 6, 9]},
	{"root": -1, "arp": [-1, 2, 5, 8]},
	{"root": -2, "arp": [-2, 1, 4, 7]},
	{"root": -3, "arp": [-3, 0, 3, 6]},
	{"root": 0,  "arp": [0, 3, 6, 9]},
	{"root": -1, "arp": [-1, 2, 5, 8]},
	{"root": -2, "arp": [-2, 1, 4, 7]},
	{"root": -3, "arp": [-3, 0, 3, 6]},
]
const BOSS_BASS_PAT := [0, 12, 0, 12, 0, 7, 0, 12]
const BOSS_LEAD := [
	[0, 2], [3, 2], [6, 2], [3, 2], [0, 2], [6, 2], [0, 4],
	[-1, 2], [2, 2], [5, 2], [2, 2], [-1, 4], [5, 4],
	[-2, 2], [1, 2], [4, 2], [1, 2], [-2, 4], [4, 4],
	[-3, 2], [0, 2], [3, 2], [0, 2], [-3, 4], [3, 4],
	[12, 2], [9, 2], [6, 2], [9, 2], [12, 2], [15, 2], [12, 4],
	[11, 2], [8, 2], [5, 2], [8, 2], [11, 4], [5, 4],
	[10, 2], [7, 2], [4, 2], [7, 2], [10, 4], [4, 4],
	[9, 2], [6, 2], [3, 2], [6, 2], [9, 4], [3, 4],
]

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = volume_db
	add_child(_player)
	_player.stream = _build()
	if autoplay:
		_player.play()

func play() -> void:
	if _player != null and not _player.playing:
		_player.play()

func stop() -> void:
	if _player != null:
		_player.stop()

# --- builds ---------------------------------------------------------------

func _build() -> AudioStreamWAV:
	match theme:
		"title": return _build_title()
		"boss": return _build_boss()
		_: return _build_explore()

func _new_buf(bars: int, six: float) -> PackedFloat32Array:
	var n := int(float(bars * 16) * six * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	return buf

func _build_explore() -> AudioStreamWAV:
	var six := 60.0 / 150.0 / 4.0
	var buf := _new_buf(PROG.size(), six)
	_render_capcom(buf, buf.size(), PROG, BASS_PAT, LEAD, six, {
		"arp_base": 440.0, "arp_div": 1, "arp_vol": 0.085,
		"bass_base": 110.0, "bass_vol": 0.26,
		"lead_base": 440.0, "lead_vol": 0.2, "drums": "rock"})
	return _to_wav(buf, buf.size())

func _build_title() -> AudioStreamWAV:
	var six := 60.0 / 88.0 / 4.0
	var buf := _new_buf(PROG_TITLE.size(), six)
	var n := buf.size()
	# Deep steady drone bed under the groove, for dread (whole cycles = seamless).
	var ls := float(n) / float(RATE)
	var dsub := roundf(27.5 * ls) / ls
	var d1 := roundf(55.0 * ls) / ls
	for i in n:
		var t := float(i) / float(RATE)
		buf[i] += (_tri(dsub * t) * 0.5 + _tri(d1 * t) * 0.5) * 0.1
	_render_capcom(buf, n, PROG_TITLE, TITLE_BASS_PAT, TITLE_LEAD, six, {
		"arp_base": 220.0, "arp_div": 2, "arp_vol": 0.07,
		"bass_base": 55.0, "bass_vol": 0.24,
		"lead_base": 220.0, "lead_vol": 0.17, "drums": "doom"})
	var length := float(n) / float(RATE)
	_breath(buf, n, length * 0.5 - 0.4, 1.6, 0.12)
	_toll(buf, n, 0.1)
	_toll(buf, n, length * 0.5)
	return _to_wav(buf, n)

func _build_boss() -> AudioStreamWAV:
	var six := 60.0 / 172.0 / 4.0
	var buf := _new_buf(PROG_BOSS.size(), six)
	_render_capcom(buf, buf.size(), PROG_BOSS, BOSS_BASS_PAT, BOSS_LEAD, six, {
		"arp_base": 440.0, "arp_div": 1, "arp_vol": 0.09,
		"bass_base": 110.0, "bass_vol": 0.28,
		"lead_base": 440.0, "lead_vol": 0.2, "drums": "boss"})
	return _to_wav(buf, buf.size())

# --- the shared Capcom section: arp + bass + lead + drums -----------------

func _render_capcom(buf: PackedFloat32Array, n: int, prog: Array, bass_pat: Array, lead: Array, six: float, o: Dictionary) -> void:
	var steps := 16
	var bars := prog.size()
	var adiv := int(o.get("arp_div", 1))
	var abase := float(o.get("arp_base", 440.0))
	var avol := float(o.get("arp_vol", 0.085))
	var bbase := float(o.get("bass_base", 110.0))
	var bvol := float(o.get("bass_vol", 0.26))
	var lbase := float(o.get("lead_base", 440.0))
	var lvol := float(o.get("lead_vol", 0.2))
	var style := str(o.get("drums", "rock"))

	# ARP — fast chord-outline pulses.
	for bar in bars:
		var tones: Array = prog[bar]["arp"]
		var ai := 0
		var s := 0
		while s < steps:
			var semi := int(tones[ai % tones.size()])
			var at := float(bar * steps + s) * six
			_blip_note(buf, n, at, six * float(adiv) * 0.95, _freq(abase, semi), 0.125, avol)
			ai += 1
			s += adiv

	# BASS — octave-jumping eighths under each chord.
	var eighth := six * 2.0
	for bar in bars:
		var root := int(prog[bar]["root"])
		for e in 8:
			var semi := root + int(bass_pat[e])
			var at := float(bar * steps) * six + float(e) * eighth
			_bass_note(buf, n, at, eighth * 0.92, _freq(bbase, semi), bvol)

	# LEAD — the hook (16th-note timing) with an octave-down body.
	var pos := 0.0
	for ev in lead:
		var semis := int(ev[0])
		var dur := float(ev[1]) * six
		if semis != -99:
			var f := _freq(lbase, semis)
			var s0 := int(pos * RATE)
			var s1 := mini(n, int((pos + dur) * RATE))
			for i in range(s0, s1):
				var tt := float(i) / float(RATE)
				var e := _env(tt - pos, dur)
				buf[i] += _square(f * tt, 0.5) * e * lvol
				buf[i] += _square(f * 0.5 * tt, 0.5) * e * lvol * 0.3
		pos += dur

	_render_drums(buf, n, bars, steps, six, style)

func _render_drums(buf: PackedFloat32Array, n: int, bars: int, steps: int, six: float, style: String) -> void:
	for bar in bars:
		var b0 := float(bar * steps) * six
		var kicks: Array
		var snares: Array
		var hat_step := 2
		var hat_gain := 1.0
		match style:
			"doom":
				kicks = [0, 8]
				snares = [4, 12]
				hat_step = 4
				hat_gain = 0.7
			"boss":
				kicks = [0, 4, 8, 12, 14]
				snares = [4, 12]
				hat_step = 1
			_:  # rock
				kicks = [0, 6, 10]
				snares = [4, 12]
		for k in kicks:
			_drum(buf, n, b0 + float(k) * six, "kick", 1.0)
		for sn in snares:
			_drum(buf, n, b0 + float(sn) * six, "snare", 1.0)
		var h := 0
		while h < steps:
			_drum(buf, n, b0 + float(h) * six, "hat", hat_gain)
			h += hat_step

# --- voices & helpers -----------------------------------------------------

func _freq(base: float, semis: int) -> float:
	return base * pow(2.0, float(semis) / 12.0)

func _env(tn: float, dur: float) -> float:
	var a := 0.006
	var d := 0.07
	var s := 0.6
	var r := 0.05
	if tn < a:
		return tn / a
	if tn < a + d:
		return 1.0 - (1.0 - s) * ((tn - a) / d)
	if tn < dur - r:
		return s
	return s * maxf(0.0, (dur - tn) / r)

func _box_env(tn: float) -> float:
	var a := 0.004
	if tn < a:
		return tn / a
	return exp(-(tn - a) * 3.2)

func _blip_note(buf: PackedFloat32Array, n: int, at: float, dur: float, f: float, duty: float, vol: float) -> void:
	var s0 := int(at * RATE)
	var s1 := mini(n, int((at + dur) * RATE))
	for i in range(maxi(0, s0), s1):
		var tt := float(i) / float(RATE)
		buf[i] += _square(f * tt, duty) * _box_env(tt - at) * vol

func _bass_note(buf: PackedFloat32Array, n: int, at: float, dur: float, f: float, vol: float) -> void:
	var s0 := int(at * RATE)
	var s1 := mini(n, int((at + dur) * RATE))
	for i in range(maxi(0, s0), s1):
		var tt := float(i) / float(RATE)
		buf[i] += _tri(f * tt) * _env(tt - at, dur) * vol

func _drum(buf: PackedFloat32Array, n: int, at: float, kind: String, gain: float) -> void:
	var s0 := int(at * RATE)
	if kind == "kick":
		var dur := 0.11
		for i in range(maxi(0, s0), mini(n, s0 + int(dur * RATE))):
			var tn := float(i - s0) / float(RATE)
			var dec := pow(1.0 - tn / dur, 2.0)
			var f := 110.0 - 70.0 * (tn / dur)
			buf[i] += _tri(f * tn) * dec * 0.5 * gain
	elif kind == "snare":
		var dur := 0.12
		for i in range(maxi(0, s0), mini(n, s0 + int(dur * RATE))):
			var tn := float(i - s0) / float(RATE)
			var dec := exp(-tn * 28.0)
			buf[i] += (randf_range(-1.0, 1.0) * 0.7 + _tri(190.0 * tn) * 0.3) * dec * 0.32 * gain
	else:  # hat
		var dur := 0.03
		for i in range(maxi(0, s0), mini(n, s0 + int(dur * RATE))):
			var tn := float(i - s0) / float(RATE)
			buf[i] += randf_range(-1.0, 1.0) * exp(-tn * 90.0) * 0.14 * gain

func _toll(buf: PackedFloat32Array, n: int, at: float) -> void:
	var base := 55.0
	var dur := 3.6
	var s0 := int(at * RATE)
	var partials := [[1.0, 1.0], [1.41, 0.4], [2.0, 0.5], [2.76, 0.34], [5.4, 0.16]]
	for i in range(s0, mini(n, s0 + int(dur * RATE))):
		var tn := float(i - s0) / float(RATE)
		var dec := exp(-tn * 1.4)
		var v := 0.0
		for p in partials:
			v += sin(TAU * base * float(p[0]) * tn) * float(p[1])
		buf[i] += v * dec * 0.11

func _breath(buf: PackedFloat32Array, n: int, center: float, dur: float, vol: float) -> void:
	var s0 := int((center - dur * 0.5) * RATE)
	var s1 := int((center + dur * 0.5) * RATE)
	var mid := float(s0 + s1) * 0.5
	var half := maxf(1.0, float(s1 - s0) * 0.5)
	var lp := 0.0
	for i in range(maxi(0, s0), mini(n, s1)):
		lp = lp * 0.92 + randf_range(-1.0, 1.0) * 0.08
		var amp := 1.0 - absf(float(i) - mid) / half
		buf[i] += lp * clampf(amp, 0.0, 1.0) * vol

func _square(phase: float, duty: float) -> float:
	return 1.0 if fposmod(phase, 1.0) < duty else -1.0

func _tri(phase: float) -> float:
	return 4.0 * absf(fposmod(phase, 1.0) - 0.5) - 1.0

func _to_wav(buf: PackedFloat32Array, n: int) -> AudioStreamWAV:
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var scale := 0.85 / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := int(clampf(buf[i] * scale, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s
