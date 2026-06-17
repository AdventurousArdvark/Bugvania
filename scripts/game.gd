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

func _ready() -> void:
	add_to_group("game")
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(Audio.new())          # spin up procedural sfx
	_build_menu()

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
