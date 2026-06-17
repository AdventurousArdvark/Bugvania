extends Node
class_name Audio
## Procedural sound effects. Synthesizes short tone "blips" into AudioStreamWAV
## buffers at runtime, so the prototype has audio feel with zero sound files.
## Call from anywhere: Audio.play("jump"). No-ops safely if no instance exists
## (e.g. running the gym scene without a game manager).

static var _inst: Audio = null

const RATE := 22050
const POOL := 12

# name -> [freq_start, freq_end, duration, waveform, volume]
const SPECS := {
	"jump":        [420.0, 720.0, 0.09, "square", 0.32],
	"double_jump": [620.0, 980.0, 0.08, "square", 0.32],
	"wall_jump":   [520.0, 800.0, 0.08, "square", 0.30],
	"dash":        [320.0, 140.0, 0.14, "saw",    0.38],
	"land":        [240.0, 120.0, 0.06, "sine",   0.40],
	"shoot":       [900.0, 1300.0, 0.05, "square", 0.20],
	"charge_ready":[1300.0, 1300.0, 0.07, "sine",  0.28],
	"charged":     [300.0, 1500.0, 0.20, "saw",    0.38],
	"missile":     [200.0, 110.0, 0.20, "noise",   0.40],
	"hit":         [240.0, 240.0, 0.04, "square",  0.28],
	"enemy_die":   [420.0, 80.0,  0.14, "noise",   0.45],
	"pickup":      [880.0, 1320.0, 0.16, "sine",   0.40],
	"door":        [200.0, 60.0,  0.22, "noise",   0.50],
	"hurt":        [320.0, 120.0, 0.14, "saw",     0.40],
	"die":         [400.0, 60.0,  0.45, "saw",     0.45],
	"boss_hit":    [160.0, 150.0, 0.05, "square",  0.40],
	"boss_die":    [300.0, 40.0,  0.70, "noise",   0.60],
}

var _streams: Dictionary = {}
var _players: Array = []
var _next: int = 0

func _ready() -> void:
	_inst = self
	for name in SPECS:
		var s: Array = SPECS[name]
		_streams[name] = _make(s[0], s[1], s[2], s[3], s[4])
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

static func play(name: String) -> void:
	if _inst != null:
		_inst._play(name)

func _play(name: String) -> void:
	if not _streams.has(name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.play()

func _make(f0: float, f1: float, dur: float, wave: String, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var f := lerpf(f0, f1, float(i) / maxf(n - 1, 1))
		phase += f / RATE
		var w := 0.0
		match wave:
			"sine":   w = sin(phase * TAU)
			"square": w = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"saw":    w = 2.0 * fmod(phase, 1.0) - 1.0
			"noise":  w = randf_range(-1.0, 1.0)
		var atk := minf(1.0, float(i) / (0.004 * RATE))   # short attack, no click
		var dec := pow(1.0 - float(i) / n, 1.4)            # decay to silence
		var v := int(clampf(w * atk * dec * vol, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
