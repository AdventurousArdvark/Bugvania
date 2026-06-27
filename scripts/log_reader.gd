extends CanvasLayer
class_name LogReader
## A full-screen reader that surfaces when you recover a datalog. Pauses the world,
## displays the entry like a corrupted terminal readout, dismisses on any key.

func show_log(title: String, body: String, accent := Color("#9fd68a")) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # runs while the tree is paused
	layer = 60
	get_tree().paused = true
	var vp := get_viewport().get_visible_rect().size

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var pw := minf(vp.x * 0.62, 640.0)
	var ph := minf(vp.y * 0.6, 420.0)
	var px := (vp.x - pw) * 0.5
	var py := (vp.y - ph) * 0.5

	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.05, 0.05, 0.96)
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	add_child(panel)
	var bar := ColorRect.new()
	bar.color = accent
	bar.position = Vector2(px, py)
	bar.size = Vector2(pw, 3)
	add_child(bar)
	var bar2 := ColorRect.new()
	bar2.color = Color(accent.r, accent.g, accent.b, 0.4)
	bar2.position = Vector2(px, py + ph - 3)
	bar2.size = Vector2(pw, 3)
	add_child(bar2)

	var head := Label.new()
	head.text = "▌ RECOVERED DATA"
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.7))
	head.position = Vector2(px + 22, py + 16)
	add_child(head)

	var ttl := Label.new()
	ttl.text = title
	ttl.add_theme_font_size_override("font_size", 22)
	ttl.add_theme_color_override("font_color", accent)
	ttl.position = Vector2(px + 22, py + 36)
	ttl.size = Vector2(pw - 44, 30)
	add_child(ttl)

	var txt := Label.new()
	txt.text = body
	txt.add_theme_font_size_override("font_size", 16)
	txt.add_theme_color_override("font_color", Color(0.86, 0.9, 0.85))
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.position = Vector2(px + 22, py + 78)
	txt.size = Vector2(pw - 44, ph - 130)
	add_child(txt)

	var foot := Label.new()
	foot.text = "▸ any key"
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color(0.55, 0.6, 0.55))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.position = Vector2(px, py + ph - 26)
	foot.size = Vector2(pw - 20, 20)
	add_child(foot)

func _unhandled_input(event: InputEvent) -> void:
	var dismiss := false
	if event is InputEventKey and event.pressed and not event.echo:
		dismiss = true
	elif event is InputEventJoypadButton and event.pressed:
		dismiss = true
	elif event is InputEventMouseButton and event.pressed:
		dismiss = true
	if dismiss:
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		queue_free()
