extends Area2D
class_name Datalog
## A recoverable log in the world. Touch it to record it to the Codex and read it.
## Already-read logs (Codex.has) don't respawn. Silent world; these are the voice.

@export var log_id: String = ""
@export var title: String = "FIELD LOG"
@export var body: String = ""
@export var accent: Color = Color("#9fd68a")

var _t: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2                  # the player
	if Codex.has(log_id):
		queue_free()                    # already recovered — don't show again
		return
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(26, 26)
	cs.shape = rs
	add_child(cs)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.6 + 0.4 * sin(_t * 4.0)
	draw_circle(Vector2.ZERO, 12.0, Color(accent.r, accent.g, accent.b, 0.18 * pulse))
	draw_circle(Vector2.ZERO, 6.0, Color(accent.r, accent.g, accent.b, pulse))
	# a thin data-glyph
	draw_line(Vector2(0, -3), Vector2(0, 3), Color(0.05, 0.06, 0.05, 0.9), 2.0)
	draw_circle(Vector2(0, -5), 1.4, Color(0.05, 0.06, 0.05, 0.9))

func _on_body(b: Node) -> void:
	if not b.is_in_group("player"):
		return
	if Codex.add(log_id, title, body):
		Audio.play("charge_ready")
	set_deferred("monitoring", false)
	_open.call_deferred()

func _open() -> void:
	var r := LogReader.new()
	get_tree().current_scene.add_child(r)
	r.show_log(title, body, accent)
	queue_free()
