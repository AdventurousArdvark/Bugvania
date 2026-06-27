extends RefCounted
class_name ModIntro
## PROLOGUE — the husk. A short, quiet opening (the "Ceres station") you wake in and
## crawl rightward out of, into the hive proper. No combat; pure threshold. Flows
## seamlessly into The Hollow Mouth at x = 38T.

const F := "#22201e"
const Wc := "#16140f"

static func build(w: World) -> void:
	var T := w.T
	# I1 — THE HUSK (you wake)
	w.register_room("I1", Rect2(0.0, -8.0 * T, 18.0 * T, 10.0 * T), Vector2(3.0 * T, -T), "intro")
	w.frame(0.0, 18.0 * T, -8.0 * T, 2.0 * T, false, true, 0.0, 0.0, Wc)
	w.slab(0.0, 18.0 * T, 0.0, 2.0 * T, F)
	w.slab(5.0 * T, 8.0 * T, -2.0 * T, 0.0, F)            # the broken shell you climb from
	w.set_spawn("I1", Vector2(3.0 * T, -T))
	w.label(Vector2(2.0 * T, -7.0 * T), "you wake in the dark.")
	w.label(Vector2(2.0 * T, -5.5 * T), "you are hungry.", 11)

	# I2 — THE MOLT (crawl toward the opening)
	w.register_room("I2", Rect2(18.0 * T, -8.0 * T, 20.0 * T, 10.0 * T), Vector2(19.0 * T, -T), "intro")
	w.frame(18.0 * T, 38.0 * T, -8.0 * T, 2.0 * T, true, true, 0.0, 0.0, Wc)
	w.slab(18.0 * T, 38.0 * T, 0.0, 2.0 * T, F)
	w.slab(24.0 * T, 27.0 * T, -2.0 * T, -1.0 * T, F)
	w.label(Vector2(19.0 * T, -7.0 * T), "THE MOLT")
	w.label(Vector2(30.0 * T, -5.0 * T), "the hive opens ahead ▶", 11)
