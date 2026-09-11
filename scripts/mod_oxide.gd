extends RefCounted
class_name ModOxide
## REGION 2 — THE OXIDE WASTES (x 136..268T, upper elevation, floor surface y=-20T).
## Flows in from the Hollow's Throat exit (right door at -20T) and runs east. It gives
## you STINGER PODS (missiles) and the KICK-TENDON (high jump); its apex, THE GANTRY-THING,
## sheds the CHARGE GLAND (charge beam). Two onward routes are sealed FRONTIERS for now:
## a shaft DOWN to the Molten Marrow, and an east door to the Pale Spire. Both are
## pre-carved where the neighbor will attach, so building those regions needs no rewiring.
##
## Backtrack payoff: with Stinger Pods you can return to the Hollow's Gullet and break the
## missile wall there (frag_gullet_seal) — the world folds back on itself, Super-Metroid style.

const F  := "#3a2f22"     # oxidized floor
const Wc := "#241c14"     # rust wall

const LOG_OXIDE := "SALVAGE LOG // OXIDE\n\nThe machines rotted here before anything living did. Whatever ran this place bled it dry and left the frames standing.\n\nThe labor-castes logged me here under a new word — Vesh'korru. Sky-fallen. They do not sound afraid. They sound like they were expecting me."

const LOG_SLAG := "SALVAGE LOG // THRESHOLD\n\nI took a limb that was not mine. It fits better than it should.\n\nWhen I move now, something in the walls changes pitch — a chorus, rising. One word in it, over and over. Ksirrahk. I do not know the word. I know it is about me."

static func build(w: World) -> void:
	var T := w.T

	# O1 — THE INTAKE (enters from the Hollow Throat at -20T)
	w.register_room("O1", Rect2(136.0 * T, -32.0 * T, 22.0 * T, 14.0 * T), Vector2(139.0 * T, -21.0 * T), "oxide")
	w.frame(136.0 * T, 158.0 * T, -32.0 * T, -18.0 * T, true, true, -20.0 * T, -20.0 * T, Wc)
	w.slab(136.0 * T, 158.0 * T, -20.0 * T, -18.0 * T, F)
	w.slab(144.0 * T, 147.0 * T, -24.0 * T, -23.0 * T, F)          # a step
	var dl := Datalog.new()
	dl.log_id = "oxide_vesh"
	dl.title = "SALVAGE LOG // OXIDE"
	dl.body = LOG_OXIDE
	dl.accent = Color("#d0872f")
	dl.position = Vector2(141.0 * T, -21.0 * T)
	w.add_child(dl)
	w.label(Vector2(138.0 * T, -30.0 * T), "THE INTAKE")

	# O2 — THE STACKS (first combat + STINGER PODS)
	w.register_room("O2", Rect2(158.0 * T, -32.0 * T, 26.0 * T, 14.0 * T), Vector2(160.0 * T, -21.0 * T), "oxide")
	w.frame(158.0 * T, 184.0 * T, -32.0 * T, -18.0 * T, true, true, -20.0 * T, -20.0 * T, Wc)
	w.slab(158.0 * T, 184.0 * T, -20.0 * T, -18.0 * T, F)
	w.slab(163.0 * T, 166.0 * T, -24.0 * T, -23.0 * T, F)
	w.slab(173.0 * T, 178.0 * T, -27.0 * T, -26.0 * T, F)          # ledge for the pods
	var sp := Spikes.new()
	sp.position = Vector2(169.0 * T, -19.0 * T)
	if "width" in sp:
		sp.set("width", 2.0 * T)
	w.add_child(sp)
	var e := Enemy.new()
	w.add_child(e)
	e.global_position = Vector2(167.0 * T, -21.0 * T)
	e.set("room_bounds", w._rooms["O2"].grow(-T))
	var fl := Flyer.new()
	w.add_child(fl)
	fl.global_position = Vector2(179.0 * T, -28.0 * T)
	fl.set("room_bounds", w._rooms["O2"].grow(-T))
	var pods := AbilityPickup.new()
	pods.ability = "has_missiles"
	pods.display_name = "STINGER PODS"
	pods.amount_property = "missiles"
	pods.grant_amount = 15
	pods.color = Color("#d0872f")
	pods.position = Vector2(175.5 * T, -28.0 * T)
	w.add_child(pods)
	w.label(Vector2(160.0 * T, -30.0 * T), "THE STACKS")
	w.label(Vector2(173.0 * T, -28.5 * T), "stinger pods ▲", 10)
	w.label(Vector2(158.0 * T, -22.0 * T), "◂ backtrack: the Gullet's missile wall", 9)

	# O3 — THE FOUNDRY (KICK-TENDON up a grip ledge; a shaft DOWN sealed toward the Marrow)
	w.register_room("O3", Rect2(184.0 * T, -32.0 * T, 30.0 * T, 26.0 * T), Vector2(186.0 * T, -21.0 * T), "oxide")
	w.frame(184.0 * T, 214.0 * T, -32.0 * T, -6.0 * T, true, true, -20.0 * T, -20.0 * T, Wc)
	w.slab(184.0 * T, 208.0 * T, -20.0 * T, -18.0 * T, F)          # upper floor (gap x208..214 = the shaft)
	w.slab(186.0 * T, 187.0 * T, -28.0 * T, -20.0 * T, Wc)         # grip pillar
	w.slab(188.0 * T, 193.0 * T, -27.0 * T, -26.0 * T, F)          # kick-tendon ledge
	var kick := AbilityPickup.new()
	kick.ability = "has_high_jump"
	kick.display_name = "KICK-TENDON"
	kick.color = Color("#d0872f")
	kick.position = Vector2(190.5 * T, -28.0 * T)
	w.add_child(kick)
	w.label(Vector2(186.0 * T, -30.0 * T), "THE FOUNDRY")
	w.label(Vector2(188.0 * T, -28.5 * T), "grip up ▲  kick-tendon", 10)
	# the shaft down: a small landing, then the sealed frontier to the Molten Marrow
	w.slab(206.0 * T, 214.0 * T, -7.0 * T, -6.0 * T, F)            # shaft-bottom landing
	var marrow_gate := FrontierGate.new()
	marrow_gate.to_area = "marrow"
	marrow_gate.size = Vector2(8.0 * T, T)
	marrow_gate.face = 1
	marrow_gate.position = Vector2(210.0 * T, -7.6 * T)            # sealed hatch on the landing
	w.add_child(marrow_gate)
	w.label(Vector2(206.0 * T, -9.0 * T), "▼ shaft: THE MOLTEN MARROW (sealed)", 9)

	# O4 — THE GANTRY (apex arena; seals until THE GANTRY-THING falls)
	w.register_room("O4", Rect2(214.0 * T, -32.0 * T, 32.0 * T, 14.0 * T), Vector2(216.0 * T, -21.0 * T), "oxide")
	w.frame(214.0 * T, 246.0 * T, -32.0 * T, -18.0 * T, true, true, -20.0 * T, -20.0 * T, Wc)
	w.slab(214.0 * T, 246.0 * T, -20.0 * T, -18.0 * T, F)
	var gantry := ApexGantry.new()
	w.add_child(gantry)
	gantry.global_position = Vector2(230.0 * T, -20.0 * T - gantry.size.y * 0.5)
	var seal := w.make_seal(Rect2(245.0 * T, -23.0 * T, T, 3.0 * T))
	w.register_apex("O4", gantry, seal, "CHARGE GLAND", "your beam remembers now")
	w.label(Vector2(216.0 * T, -30.0 * T), "THE GANTRY")

	# O5 — THE SLAG DOOR (eastern frontier toward the Pale Spire)
	w.register_room("O5", Rect2(246.0 * T, -32.0 * T, 22.0 * T, 14.0 * T), Vector2(248.0 * T, -21.0 * T), "oxide")
	w.frame(246.0 * T, 268.0 * T, -32.0 * T, -18.0 * T, true, true, -20.0 * T, -20.0 * T, Wc)
	w.slab(246.0 * T, 268.0 * T, -20.0 * T, -18.0 * T, F)
	var dl2 := Datalog.new()
	dl2.log_id = "oxide_ksirrahk"
	dl2.title = "SALVAGE LOG // THRESHOLD"
	dl2.body = LOG_SLAG
	dl2.accent = Color("#d0872f")
	dl2.position = Vector2(250.0 * T, -21.0 * T)
	w.add_child(dl2)
	var spire_gate := FrontierGate.new()
	spire_gate.to_area = "spire"
	spire_gate.size = Vector2(T, 3.0 * T)
	spire_gate.face = 1
	spire_gate.position = Vector2(267.5 * T, -21.5 * T)            # fills the pre-carved east door
	w.add_child(spire_gate)
	w.label(Vector2(248.0 * T, -30.0 * T), "THE SLAG DOOR")
	w.label(Vector2(256.0 * T, -22.0 * T), "▸ THE PALE SPIRE (sealed)", 9)
