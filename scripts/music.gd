extends Node
class_name Music
## Procedural 8-bit background music, synthesized at runtime — no audio files.
## One looping exploration theme in the dark/dissonant vein: a minor key with a
## flat-2 and tritone for unease, two pulse channels (the second detuned so it
## beats against the first), a triangle bass walking down chromatically, a low
## continuous drone (two detuned oscillators), and a soft heartbeat thud instead
## of hi-hats. Routes through the Master bus, so the volume setting controls it.
##
## Built once on _ready (~1s of synthesis), then loops seamlessly forever.

@export var bpm: float = 76.0
@export var volume_db: float = -11.0
@export var autoplay: bool = true
@export var theme: String = "explore"   # "explore" | "title"

const RATE := 16000                     # lo-fi on purpose; authentic chip grit

# Title theme: a lilting 3/4 waltz in the spirit of a haunted music box — the
# rising-leap-and-turn shape of that famous wizard motif, but bent toward dread
# with a tritone (Eb) and flat-2 (Bb), played high over a deep drone and tolls.
# [semi-from-A, eighth-note units]; -99 = rest. Groups of 6 = one 3/4 bar.
const TITLE_LEAD := [
	[7, 1],                       # pickup: E (the 5th)
	[0, 3], [3, 1], [2, 2],       # A . C B   — the turn
	[0, 2], [7, 3], [5, 1],       # A  E↑  D  — the rising leap
	[3, 2], [2, 2], [0, 2],       # C  B  A   — fall
	[6, 3], [2, 3],               # Eb . B    — TRITONE twist (horror)
	[0, 3], [3, 1], [2, 2],       # A . C B
	[0, 2], [7, 3], [8, 1],       # A  E↑  F  — minor-6th, darker turn
	[6, 2], [5, 2], [3, 2],       # Eb D C    — chromatic descent
	[1, 3], [0, 3],               # Bb . A    — flat-2 lean, sink home
]

# Semitone offsets from A. Dark palette: minor with Bb (flat-2) and Eb (tritone).
# [offset, beats]; offset -99 = rest. Each bar sums to 4 beats; 8 bars = 32 beats.
const LEAD := [
	[0, 2], [3, 1], [2, 1],            # A  C  B
	[5, 2], [3, 1], [1, 1],            # D  C  Bb   <- flat-2 dread
	[0, 1], [-99, 1], [7, 2],          # A  .  E
	[6, 1], [5, 1], [3, 2],            # Eb D  C    <- tritone pull
	[8, 2], [7, 1], [5, 1],            # F  E  D
	[3, 2], [2, 2],                    # C  B
	[0, 1], [3, 1], [7, 2],            # A  C  E
	[1, 2], [0, 2],                    # Bb A       <- lean then resolve
]
const BASS := [
	[0, 2], [0, 2], [-2, 2], [-2, 2],  # A A  G G
	[0, 2], [7, 2], [-4, 2], [-4, 2],  # A E  F F
	[-1, 2], [-1, 2], [-2, 2], [-2, 2],# Ab Ab G G  <- chromatic descent
	[0, 2], [7, 2], [1, 2], [0, 2],    # A E  Bb A
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

# --- synthesis ------------------------------------------------------------

func _freq(base: float, semis: int) -> float:
	return base * pow(2.0, float(semis) / 12.0)

func _env(tn: float, dur: float) -> float:
	# Plucky ADSR so notes never click and the lead has chip "bite".
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

func _build() -> AudioStreamWAV:
	if theme == "title":
		return _build_title()
	return _build_explore()

func _build_explore() -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var total_beats := 0.0
	for ev in LEAD:
		total_beats += float(ev[1])
	var length := total_beats * beat
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)

	# Continuous low drone: a steady root + a quiet fifth (no detuning, so it holds
	# flat instead of wavering). Tuned to whole cycles over the loop -> seamless.
	var ls := float(n) / float(RATE)
	var d1 := roundf(55.0 * ls) / ls
	var d5 := roundf(82.4 * ls) / ls         # fifth, very low
	for i in n:
		var t := float(i) / float(RATE)
		var dr := _tri(d1 * t) * 0.7 + _tri(d5 * t) * 0.2
		buf[i] += dr * 0.16

	# Lead (pulse 1, duty 0.5) + detuned echo (pulse 2, thin duty 0.25).
	_render_voice(buf, LEAD, 220.0, beat, true)
	# Bass (triangle), low.
	_render_voice(buf, BASS, 55.0, beat, false)

	# Heartbeat: a soft low thud at the start of each bar (lub-dub), no hi-hats.
	var bar := beat * 4.0
	var bars := int(roundf(total_beats / 4.0))
	for b in bars:
		_thud(buf, b * bar, 0.0)
		_thud(buf, b * bar + 0.34, -3.0)

	return _to_wav(buf, n)

func _render_voice(buf: PackedFloat32Array, pattern: Array, base: float, beat: float, is_lead: bool) -> void:
	var n := buf.size()
	var pos := 0.0
	for ev in pattern:
		var semis := int(ev[0])
		var dur := float(ev[1]) * beat
		if semis != -99:
			var f := _freq(base, semis)
			var s0 := int(pos * RATE)
			var s1 := mini(n, int((pos + dur) * RATE))
			for i in range(s0, s1):
				var t := float(i) / float(RATE)
				var tn := t - pos
				var e := _env(tn, dur)
				if is_lead:
					buf[i] += _square(f * t, 0.5) * e * 0.24
					buf[i] += _square(f * 0.5 * t, 0.5) * e * 0.09   # clean octave below for body
				else:
					buf[i] += _tri(f * t) * e * 0.22
		pos += dur

func _thud(buf: PackedFloat32Array, at: float, gain_db: float) -> void:
	var n := buf.size()
	var s0 := int(at * RATE)
	var dur := 0.16
	var g := db_to_linear(gain_db) * 0.5
	for i in range(s0, mini(n, s0 + int(dur * RATE))):
		var tn := float(i - s0) / float(RATE)
		var decay := pow(1.0 - tn / dur, 3.0)
		var f := 48.0 - 30.0 * (tn / dur)               # pitch drop
		buf[i] += _tri(f * tn) * decay * g

func _build_title() -> AudioStreamWAV:
	var unit := 0.28                        # slightly slower = heavier dread
	var total_units := 0.0
	for ev in TITLE_LEAD:
		total_units += float(ev[1])
	var length := total_units * unit
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ls := float(n) / float(RATE)

	# Deep drone with a low TRITONE growl (root vs Eb = a menacing roughness, not a
	# slow wobble). Sub + root + octave + tritone. All tuned to whole cycles.
	var dsub := roundf(27.5 * ls) / ls
	var d1 := roundf(55.0 * ls) / ls
	var dtri := roundf(77.78 * ls) / ls      # Eb1 — the growl
	var d8 := roundf(110.0 * ls) / ls
	# A faint high dissonant ring, like tinnitus held in the dark.
	var hi := roundf(1244.5 * ls) / ls       # Eb6, a tritone above the octave
	for i in n:
		var t := float(i) / float(RATE)
		var dr := _tri(dsub * t) * 0.5 + _tri(d1 * t) * 0.55 + _tri(dtri * t) * 0.22 + _tri(d8 * t) * 0.1
		buf[i] += dr * 0.13
		buf[i] += _tri(hi * t) * 0.028

	# Music-box melody + a cursed SHADOW a tritone below it (steady, so it clashes
	# without wavering). The pretty waltz, rung wrong.
	var pos := 0.0
	for ev in TITLE_LEAD:
		var semis := int(ev[0])
		var dur := float(ev[1]) * unit
		if semis != -99:
			var f := _freq(440.0, semis)
			var fshadow := f * pow(2.0, -6.0 / 12.0)   # tritone below
			var s0 := int(pos * RATE)
			var s1 := mini(n, int((pos + dur) * RATE))
			for i in range(s0, s1):
				var tt := float(i) / float(RATE)
				var e := _box_env(tt - pos)
				buf[i] += _tri(f * tt) * e * 0.18                 # music-box body
				buf[i] += _square(f * tt, 0.5) * e * 0.05         # faint chip edge
				buf[i] += _tri(fshadow * tt) * e * 0.06           # cursed tritone shadow
		pos += dur

	# Breathing in the dark, swelling INTO each toll (inhale, then the strike).
	_breath(buf, n, total_units * 0.5 * unit - 0.4, 1.6, 0.16)
	_breath(buf, n, length - 0.4, 1.6, 0.16)
	# Clangorous dissonant tolls.
	_toll(buf, n, total_units * 0.5 * unit)
	_toll(buf, n, 0.12)

	return _to_wav(buf, n)

# Lowpassed noise with a triangular swell — a slow breath/wind in the dark.
func _breath(buf: PackedFloat32Array, n: int, center: float, dur: float, vol: float) -> void:
	var s0 := int((center - dur * 0.5) * RATE)
	var s1 := int((center + dur * 0.5) * RATE)
	var mid := float(s0 + s1) * 0.5
	var half := maxf(1.0, float(s1 - s0) * 0.5)
	var lp := 0.0
	for i in range(maxi(0, s0), mini(n, s1)):
		lp = lp * 0.92 + randf_range(-1.0, 1.0) * 0.08      # muffled rumble
		var amp := 1.0 - absf(float(i) - mid) / half
		buf[i] += lp * clampf(amp, 0.0, 1.0) * vol

# Plucky music-box envelope: near-instant attack, then a ringing exponential decay.
func _box_env(tn: float) -> float:
	var a := 0.004
	if tn < a:
		return tn / a
	return exp(-(tn - a) * 3.2)

# A deep bell-like strike (inharmonic sine partials, long exponential decay).
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

# Slow attack/release so notes breathe like a pad (no periodic wobble).
func _pad_env(tn: float, dur: float) -> float:
	var a := 0.4
	var r := 0.7
	if tn < a:
		return tn / a
	if tn < dur - r:
		return 1.0
	return maxf(0.0, (dur - tn) / r)

func _square(phase: float, duty: float) -> float:
	return 1.0 if fposmod(phase, 1.0) < duty else -1.0

func _tri(phase: float) -> float:
	return 4.0 * absf(fposmod(phase, 1.0) - 0.5) - 1.0

func _to_wav(buf: PackedFloat32Array, n: int) -> AudioStreamWAV:
	# Normalize to avoid clipping, then pack to 16-bit PCM.
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
