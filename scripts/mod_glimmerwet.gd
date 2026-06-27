extends RefCounted
class_name ModGlimmerwet
## REGION 2 — THE GLIMMERWET. Sits on the upper level (floor at y = -20T), entered from
## the top of Hollow's Throat. Cold light, watching things. The apex, THE LANTERN-MOTHER,
## grants the Wing-Segment (double-jump); the exit ledge in THE LEAP needs it.

const F := "#1a2a3a"
const Wc := "#11202e"

static func build(w: World) -> void:
	var T := w.T
	var fl := -20.0 * T          # this region's floor surface (the upper level)

	# W1 — THE GLIMMER (entry from the Throat top)
	w.register_room("W1", Rect2(136.0 * T, fl - 10.0 * T, 26.0 * T, 12.0 * T), Vector2(138.0 * T, fl - T), "glimmerwet")
	w.frame(136.0 * T, 162.0 * T, fl - 10.0 * T, fl + 2.0 * T, true, true, fl, fl, Wc)
	w.slab(136.0 * T, 162.0 * T, fl, fl + 2.0 * T, F)
	var f := Flyer.new()
	w.add_child(f)
	f.global_position = Vector2(150.0 * T, fl - 5.0 * T)
	f.set("room_bounds", w._rooms["W1"].grow(-T))
	w.label(Vector2(138.0 * T, fl - 9.0 * T), "THE GLIMMER")

	# W2 — THE LANTERNS (apex arena; seals until THE LANTERN-MOTHER falls)
	w.register_room("W2", Rect2(162.0 * T, fl - 12.0 * T, 32.0 * T, 14.0 * T), Vector2(163.0 * T, fl - T), "glimmerwet")
	w.frame(162.0 * T, 194.0 * T, fl - 12.0 * T, fl + 2.0 * T, true, true, fl, fl, Wc)
	w.slab(162.0 * T, 194.0 * T, fl, fl + 2.0 * T, F)
	var lan := ApexLantern.new()
	w.add_child(lan)
	lan.global_position = Vector2(178.0 * T, fl - 6.0 * T)
	var seal := w.make_seal(Rect2(193.0 * T, fl - 3.0 * T, T, 3.0 * T))
	w.register_apex("W2", lan, seal, "WING-SEGMENT", "a second beat — you can fly now")
	w.label(Vector2(163.0 * T, fl - 11.0 * T), "THE LANTERNS")

	# W3 — THE LEAP (a block only a double-jump clears; the way onward sits on top)
	w.register_room("W3", Rect2(194.0 * T, fl - 14.0 * T, 26.0 * T, 16.0 * T), Vector2(195.0 * T, fl - T), "glimmerwet")
	w.frame(194.0 * T, 220.0 * T, fl - 14.0 * T, fl + 2.0 * T, true, false, fl, 0.0, Wc)
	w.slab(194.0 * T, 220.0 * T, fl, fl + 2.0 * T, F)
	w.slab(212.0 * T, 220.0 * T, fl - 4.0 * T, fl + 2.0 * T, F)    # tall block: needs double-jump to top
	w.label(Vector2(195.0 * T, fl - 13.0 * T), "THE LEAP")
	w.label(Vector2(206.0 * T, fl - 5.5 * T), "double-jump up ▲", 11)
	w.label(Vector2(212.0 * T, fl - 5.0 * T), "▶ THE MARROW RUN — region 3 (not yet built)", 10)
