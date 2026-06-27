extends RefCounted
class_name ModIntro
## PROLOGUE — CONTAINMENT. Not a hive: a research facility. You wake strapped to a
## table as a captured specimen (designation THREXNA), the restraints fail, and you
## break out through the wall into the biosphere. Sterile, metallic, alarmed — the
## "Ceres station" before the planet. The first datalog is recovered here.

const F := "#2c3038"     # facility floor (cold metal)
const Wc := "#191d23"    # facility wall

const LOG1 := "Designation: THREXNA. Recovered alive from the impact furrow beyond the perimeter. Non-native — it breathes what would kill us, bleeds at the wrong temperature.\n\nRestraint log, cycle 9: the tissue is rejecting the table. It is learning the locks.\n\n[the remainder of this entry is corrupted]"

static func build(w: World) -> void:
	var T := w.T

	# I1 — CONTAINMENT (you wake on the table)
	w.register_room("I1", Rect2(0.0, -8.0 * T, 18.0 * T, 10.0 * T), Vector2(3.0 * T, -T), "intro")
	w.frame(0.0, 18.0 * T, -8.0 * T, 2.0 * T, false, true, 0.0, 0.0, Wc)
	w.slab(0.0, 18.0 * T, 0.0, 2.0 * T, F)
	w.slab(9.0 * T, 12.0 * T, -T, 0.0, "#3a414b")         # the restraint table you wake on
	w.set_spawn("I1", Vector2(10.0 * T, -2.0 * T))
	# FRAGMENT I — a hull shard in a vent you can only SLIDE under (the prologue gift).
	w.slab(1.0 * T, 4.0 * T, -8.0 * T, -1.4 * T, Wc)      # low overhang: standing height blocked
	var fa := ShipPart.new()
	fa.fragment_id = "frag_vent"
	fa.display_name = "HULL SHARD"
	fa.required = "has_slide"
	fa.position = Vector2(2.4 * T, -0.6 * T)
	w.add_child(fa)
	w.label(Vector2(1.2 * T, -2.3 * T), "slide ◂", 10)
	w.label(Vector2(2.0 * T, -7.0 * T), "CONTAINMENT")
	w.label(Vector2(2.0 * T, -5.5 * T), "the restraints are failing.", 11)
	var dl := Datalog.new()
	dl.log_id = "intro_threxna"
	dl.title = "FIELD LOG // SPECIMEN 7"
	dl.body = LOG1
	dl.accent = Color("#7fd0ff")
	dl.position = Vector2(12.0 * T, -T)
	w.add_child(dl)

	# I2 — THE BREACH (flee toward the broken wall into the planet)
	w.register_room("I2", Rect2(18.0 * T, -8.0 * T, 20.0 * T, 10.0 * T), Vector2(19.0 * T, -T), "intro")
	w.frame(18.0 * T, 38.0 * T, -8.0 * T, 2.0 * T, true, true, 0.0, 0.0, Wc)
	w.slab(18.0 * T, 38.0 * T, 0.0, 2.0 * T, F)
	w.slab(24.0 * T, 27.0 * T, -2.0 * T, -1.0 * T, "#3a414b")   # toppled equipment to climb
	w.label(Vector2(19.0 * T, -7.0 * T), "THE BREACH")
	w.label(Vector2(29.0 * T, -5.0 * T), "the wall is broken. the planet is past it ▶", 10)
