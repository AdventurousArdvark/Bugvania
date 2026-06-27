extends RefCounted
class_name ModHollow
## REGION 1 — THE HOLLOW MOUTH (x 38..136T). Flows in from the Intro at the floor and
## climbs out the Throat shaft to the upper level, where Glimmerwet begins. The apex,
## THE BURROWER, grants wall-grip; the Throat shaft needs it — the region gates itself.

const F := "#332a24"
const Wc := "#241d18"

static func build(w: World) -> void:
	var T := w.T

	# H1 — THE MAW (connects left to the Intro)
	w.register_room("H1", Rect2(38.0 * T, -9.0 * T, 24.0 * T, 11.0 * T), Vector2(40.0 * T, -T), "hollow")
	w.frame(38.0 * T, 62.0 * T, -9.0 * T, 2.0 * T, true, true, 0.0, 0.0, Wc)
	w.slab(38.0 * T, 62.0 * T, 0.0, 2.0 * T, F)
	w.slab(46.0 * T, 48.0 * T, -2.0 * T, -1.0 * T, F)
	w.label(Vector2(40.0 * T, -8.0 * T), "THE MAW")

	# H2 — THE GULLET (first combat: patroller, flyer, a spike strip)
	w.register_room("H2", Rect2(62.0 * T, -10.0 * T, 26.0 * T, 12.0 * T), Vector2(63.0 * T, -T), "hollow")
	w.frame(62.0 * T, 88.0 * T, -10.0 * T, 2.0 * T, true, true, 0.0, 0.0, Wc)
	w.slab(62.0 * T, 88.0 * T, 0.0, 2.0 * T, F)
	w.slab(66.0 * T, 69.0 * T, -3.0 * T, -2.0 * T, F)
	w.slab(78.0 * T, 81.0 * T, -3.0 * T, -2.0 * T, F)
	var sp := Spikes.new()
	sp.position = Vector2(73.0 * T, -T)
	if "width" in sp:
		sp.set("width", 3.0 * T)
	w.add_child(sp)
	var e := Enemy.new()
	w.add_child(e)
	e.global_position = Vector2(68.0 * T, -3.0 * T)
	e.set("room_bounds", w._rooms["H2"].grow(-T))
	var f := Flyer.new()
	w.add_child(f)
	f.global_position = Vector2(82.0 * T, -6.0 * T)
	f.set("room_bounds", w._rooms["H2"].grow(-T))
	w.label(Vector2(63.0 * T, -9.0 * T), "THE GULLET")

	# H3 — THE CRAW (apex arena; seals until THE BURROWER falls)
	w.register_room("H3", Rect2(88.0 * T, -11.0 * T, 32.0 * T, 13.0 * T), Vector2(89.0 * T, -T), "hollow")
	w.frame(88.0 * T, 120.0 * T, -11.0 * T, 2.0 * T, true, true, 0.0, 0.0, Wc)
	w.slab(88.0 * T, 120.0 * T, 0.0, 2.0 * T, F)
	var burrow := ApexBurrower.new()
	w.add_child(burrow)
	burrow.global_position = Vector2(104.0 * T, -burrow.size.y * 0.5)
	var seal := w.make_seal(Rect2(119.0 * T, -3.0 * T, T, 3.0 * T))
	w.register_apex("H3", burrow, seal, "GRIP-CLAWS", "the walls are yours now")
	w.label(Vector2(89.0 * T, -10.0 * T), "THE CRAW")

	# H4 — THE THROAT (a wall-grip shaft up to the upper level; right door at the top)
	w.register_room("H4", Rect2(120.0 * T, -24.0 * T, 16.0 * T, 26.0 * T), Vector2(121.0 * T, -T), "hollow")
	w.frame(120.0 * T, 136.0 * T, -24.0 * T, 2.0 * T, true, true, 0.0, -20.0 * T, Wc)
	w.slab(120.0 * T, 136.0 * T, 0.0, 2.0 * T, F)
	w.slab(124.0 * T, 125.0 * T, -20.0 * T, 0.0, Wc)         # left grip pillar
	w.slab(129.0 * T, 130.0 * T, -20.0 * T, 0.0, Wc)         # right grip pillar
	w.slab(129.0 * T, 135.0 * T, -20.0 * T, -19.0 * T, F)    # top ledge to the exit door
	w.label(Vector2(121.0 * T, -3.0 * T), "THE THROAT")
	w.label(Vector2(125.5 * T, -10.0 * T), "grip up ▲", 11)
