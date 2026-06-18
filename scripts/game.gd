extends CanvasLayer
class_name Game
## Game flow + functionality layer for the demo. In group "game" so the boss/exit
## can call show_complete(). Owns the procedural Audio system. Processes while the
## tree is paused (PROCESS_MODE_ALWAYS) so the pause menu actually works.

var _panel: Control = null
var _title: Label = null
var _buttons: VBoxContainer = null
var _paused: bool = false
var _complete: bool = false
var _reveal_root: Control = null
var _reveal_label: Label = null
var _revealed: Dictionary = {}

func _ready() -> void:
	add_to_group("game")
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(Audio.new())          # spin up procedural sfx
	_build_menu()
	_build_reveal()

func _build_reveal() -> void:
	_reveal_root = Control.new()
	_reveal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_root.visible = false
	add_child(_reveal_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal_root.add_child(dim)
	_reveal_label = Label.new()
	_reveal_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reveal_label.add_theme_font_size_override("font_size", 52)
	_reveal_label.add_theme_color_override("font_color", Color("#d8f0c8"))
	_reveal_root.add_child(_reveal_label)

func _build_menu() -> void:
	_panel = ColorRect.new()
	_panel.color = Color(0, 0, 0, 0.72)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	_title = Label.new()
	_title.text = "PAUSED"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	box.add_child(_title)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	box.add_child(_buttons)
	_add_button("Resume", _resume)
	_add_button("Restart", _restart)
	_add_button("Quit", _quit)

func _add_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 40)
	b.pressed.connect(cb)
	_buttons.add_child(b)

func _input(event: InputEvent) -> void:
	if _complete:
		return
	if not get_tree().get_nodes_in_group("modal").is_empty():
		return                          # the loadout menu is open; let it handle input
	var toggle := false
	if InputMap.has_action("pause") and event.is_action_pressed("pause"):
		toggle = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle = true
	if toggle:
		if _paused:
			_resume()
		else:
			_pause()

func _pause() -> void:
	_paused = true
	_title.text = "PAUSED"
	_show_resume(true)
	_panel.visible = true
	get_tree().paused = true

func _resume() -> void:
	_paused = false
	_panel.visible = false
	get_tree().paused = false

func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _quit() -> void:
	get_tree().quit()

func _show_resume(show: bool) -> void:
	# Resume is the first button; hide it on the complete screen.
	if _buttons.get_child_count() > 0:
		_buttons.get_child(0).visible = show

func show_complete() -> void:
	if _complete:
		return
	_complete = true
	_title.text = "DEMO COMPLETE"
	_show_resume(false)
	_panel.visible = true
	get_tree().paused = true

# First-time pickup flourish: dim + slow-mo + the part name + a sting.
func reveal(key: String, part_name: String) -> void:
	if _revealed.has(key):
		get_tree().call_group("hud", "show_pickup", part_name)
		return
	_revealed[key] = true
	_reveal_label.text = "·  " + str(part_name).to_upper() + "  ·"
	_reveal_root.visible = true
	_reveal_root.modulate.a = 0.0
	Engine.time_scale = 0.12
	Audio.play("pickup")
	Audio.play("charged")
	Rumble.pulse(0.3, 0.5, 0.3)
	for i in 8:
		_reveal_root.modulate.a = float(i + 1) / 8.0
		await get_tree().create_timer(0.02, true, false, true).timeout
	await get_tree().create_timer(0.55, true, false, true).timeout
	for i in 8:
		_reveal_root.modulate.a = 1.0 - float(i + 1) / 8.0
		await get_tree().create_timer(0.02, true, false, true).timeout
	_reveal_root.visible = false
	Engine.time_scale = 1.0
	get_tree().call_group("hud", "show_pickup", part_name)

# Boss arrival card: name fades in, holds, fades out.
func boss_intro(boss_name: String) -> void:
	var vp := get_viewport().get_visible_rect().size
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var lbl := Label.new()
	lbl.text = str(boss_name)
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", Color("#e0577a"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(vp.x, 70)
	lbl.position = Vector2(0, vp.y * 0.30)
	root.add_child(lbl)
	var line := ColorRect.new()
	line.color = Color("#e0577a")
	line.size = Vector2(vp.x * 0.34, 2)
	line.position = Vector2(vp.x * 0.33, vp.y * 0.30 + 66)
	root.add_child(line)
	root.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(root, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(lbl, "position:y", vp.y * 0.28, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.3)
	t.tween_property(root, "modulate:a", 0.0, 0.4)
	t.tween_callback(root.queue_free)
