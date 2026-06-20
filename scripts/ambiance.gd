extends CanvasLayer
class_name Ambiance
## Atmosphere layer that sits under the HUD. Holds a faint full-screen color TINT
## that eases toward whatever the current room asks for (call set_tint), plus
## continuous drifting spores and the occasional falling drip. Purely cosmetic.

var tint: Color = Color(0, 0, 0, 0)
var _target: Color = Color(0, 0, 0, 0)
var spores: Array = []      # each: {pos, vel, r, a}
var drips: Array = []       # each: {x, y, len, a, spd}
var _drip_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _view: _View = null

func _ready() -> void:
	add_to_group("ambiance")
	layer = 5
	_rng.randomize()
	_view = _View.new()
	_view._amb = self
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_seed_spores()

func set_tint(c: Color) -> void:
	_target = c

func _seed_spores() -> void:
	var sz := get_viewport().get_visible_rect().size
	for i in 38:
		spores.append({
			"pos": Vector2(_rng.randf() * sz.x, _rng.randf() * sz.y),
			"vel": Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-26.0, -10.0)),
			"r": _rng.randf_range(0.8, 2.2),
			"a": _rng.randf_range(0.12, 0.4),
		})

func _process(delta: float) -> void:
	tint = tint.lerp(_target, clampf(delta * 1.6, 0.0, 1.0))
	var sz := get_viewport().get_visible_rect().size
	for sp in spores:
		sp.pos += sp.vel * delta
		sp.pos.x += sin(Time.get_ticks_msec() / 700.0 + sp.r * 10.0) * 6.0 * delta
		if sp.pos.y < -4.0:
			sp.pos = Vector2(_rng.randf() * sz.x, sz.y + 4.0)
		if sp.pos.x < -4.0:
			sp.pos.x = sz.x + 4.0
		elif sp.pos.x > sz.x + 4.0:
			sp.pos.x = -4.0
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = _rng.randf_range(0.6, 1.8)
		drips.append({
			"x": _rng.randf() * sz.x, "y": _rng.randf() * sz.y * 0.5,
			"len": _rng.randf_range(8.0, 22.0), "a": 0.5,
			"spd": _rng.randf_range(160.0, 300.0),
		})
	for d in drips:
		d.y += d.spd * delta
		d.a -= delta * 0.35
	drips = drips.filter(func(d): return d.a > 0.0 and d.y < sz.y + 30.0)
	_view.queue_redraw()

class _View extends Control:
	var _amb: Ambiance = null
	func _draw() -> void:
		if _amb == null:
			return
		var sz := size
		if _amb.tint.a > 0.002:
			draw_rect(Rect2(Vector2.ZERO, sz), _amb.tint)
		for sp in _amb.spores:
			draw_circle(sp.pos, sp.r, Color(0.85, 0.95, 0.85, sp.a))
		for d in _amb.drips:
			draw_line(Vector2(d.x, d.y), Vector2(d.x, d.y + d.len),
				Color(0.7, 0.85, 0.7, d.a), 1.5)
