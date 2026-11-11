extends RefCounted
## Defender Lv.60 "Titan Quake": the defender heaves a titan's shield of amber light up over
## the front, then drives it into the ground; the earth answers in a ripple. Wind-up: the
## spectral titan shield rises, the ground sigil draws in to the defender's feet, embers are
## pulled to the shield. Release: the shield slams down, three rings of stone plates heave
## up out of the ground one after another (inner first) and burn away, an amber quake ring
## rolls out to the edge of the area, fissures glow, rubble and a dust ring are thrown and the
## stars of the stun spin over the field. Bronze, amber and warm stone.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "titan_quake"
const AMBER := Color("ffb06a")
const BRONZE := Color("d9822a")
const CREAM := Color("ffeccb")
const ROCK := Color("5a4a3e")
const STONE := Color("6e5f52")
const DUST := Color("c9ad8a")


static func _shield() -> ArrayMesh:
	return M.solid("tq_shield", M.shield(BRONZE, Color("ffd27a"), CREAM), Vector3(1, 3, 1))


## Three rings of stone plates (radius 1 = the area), each ring a moment after the last.
static func _plates() -> ArrayMesh:
	if M.has("tq_plates"):
		return M.get_mesh("tq_plates")
	var rng := RandomNumberGenerator.new()
	rng.seed = 601
	var st := K.begin()
	var rings := [[0.3, 9], [0.56, 14], [0.82, 19]]
	for k in rings.size():
		var rad: float = rings[k][0]
		var count: int = rings[k][1]
		for i in count:
			var ang := TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / float(count) + float(k) * 0.3
			var dir := Vector3(sin(ang), 0, cos(ang))
			# An irregular slab of stone, its broken edge glowing amber underneath.
			var p := K.Part.new()
			p.add(K.rock(rng, ROCK if (i + k) % 2 == 0 else STONE, 0.18), Transform3D(Basis.IDENTITY.scaled(Vector3(1.25, 0.5, 1.0)), Vector3.ZERO))
			p.ink(AMBER, 0.0, 1.0)
			p.box(Vector3(0, -0.12, 0.42), Vector3(0.8, 0.07, 0.04))
			var size := rng.randf_range(0.1, 0.13) * (0.8 + float(k) * 0.25)
			var tilt := Basis(Vector3(dir.z, 0, -dir.x), -rng.randf_range(0.55, 0.9))
			var basis := tilt * Basis(Vector3.UP, ang + rng.randf_range(-0.2, 0.2))
			K.stamp(st, p, Transform3D(basis.scaled(Vector3.ONE * size), dir * rad * rng.randf_range(0.94, 1.06) + Vector3.UP * 0.02), 0.07 * float(k) + rng.randf() * 0.03, 1.0)
	return M.keep("tq_plates", K.finish(st, Vector3(1, 2, 1)))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, aim), visual)
	if r == null:
		return false
	# The titan shield heaves up over the defender's front.
	G.solid(r, _shield(), "TitanShield", Vector3(0, 1.1, 1.1), Vector3.ONE * 2.1, time + 0.04, {"drop": -0.8, "flight": time * 0.85, "ease": 1.0, "rim_color": CREAM, "rim": 0.9, "glow_color": AMBER, "dim": 0.95}, {"initial": 0.55, "grow_time": 0.6, "fade_in": 0.08, "decay": 0.97}, Vector3(-0.35, 0, 0))
	# The ground sigil draws in to the feet.
	G.flat(r, G.sigil("tq_sigil", AMBER, 2, 24, 6, 0.35), "Sigil", Vector3.UP * 0.05, Vector3.ONE * 4.2, time + 0.04, G.lit(AMBER, 0.5, 0.5), {"initial": 1.6, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95, "spin": -0.8})
	G.bits(r, G.inward("tq_gather", "ember", G.n(18), 1.6, 3.2, [AMBER, CREAM], 0.12, 3.5, 0.3, 0.15, 602, 0.3, 1.8), "Gather", Vector3(0, 0.4, 0.6), time + 0.04, {"life": time, "gravity": 0.0, "drag": 3.5, "piece": 0.12, "add": 0.85, "shrink": 0.6, "spin": 4.0}, {"decay": 0.95})
	G.flat(r, K.glow_disc("tq_shadow", Color(0.14, 0.06, 0.0, 0.5)), "Shadow", Vector3(0, 0.04, 1.2), Vector3(1.5, 1, 1.7), time + 0.04, {"soft": 0.8, "add": 0.0}, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.15, "decay": 0.95})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.yaw(origin, who[1], G.facing(caster)) if who[1] != Vector3.INF else G.facing(caster)
	var radius := float(skill.get("radius", 6.5))
	var feet := Vector3(origin.x, 0.0, origin.z)
	var r := G.open(parent, feet, 1.7, "Skill_%s_quake" % ID, turn, caster)
	if r == null:
		return false
	# The shield driven face-down into the ground ahead, the plates heaving up round it.
	G.solid(r, _plates(), "Plates", Vector3.ZERO, Vector3.ONE * radius, 1.25, {"drop": -1.4 / radius, "flight": 0.16, "ease": 1.0, "rim_color": AMBER, "rim": 0.5, "glow_color": AMBER, "heat": 0.5}, {"fade_in": 0.01, "decay": 0.86})
	M.shock(r, "tq_ring", AMBER, radius * 1.05, 0.0, 0.5, 0.2)
	# The titan shield driven point-first into the ground ahead, half sunk, still glowing.
	G.solid(r, _shield(), "Slam", Vector3(0, -0.55, 1.1), Vector3.ONE * 2.3, 0.75, {"drop": 1.1, "flight": 0.07, "heat": 0.8, "rim_color": CREAM, "rim": 0.8, "glow_color": AMBER}, {"fade_in": 0.01, "decay": 0.6}, Vector3(-0.12, 0, 0))
	M.cracks(r, "tq_cracks", AMBER, radius * 0.75, 0.03, 1.3, 9, 603, 0.07)
	M.rubble(r, "tq_rubble", [ROCK, STONE, ROCK.darkened(0.2)], G.n(22), 0.6, 2.4, 4.2, 6.0, 0.28, 0.02, 1.1, Vector3(0, 0, 1.0), 604)
	M.dust(r, "tq_dust", DUST, G.n(18), radius * 0.45, radius * 0.75, 0.05, 1.2, Vector3.ZERO, 0.95, 605)
	G.done(r)
	if G.extras(1) > 0:
		var stun := G.open(parent, feet, 1.5, "Skill_%s_daze" % ID, turn, caster)
		if stun:
			M.flash(stun, "tq_flash", BRONZE, radius * 0.45, 0.0, 0.35)
			M.shock(stun, "tq_ring_b", BRONZE, radius * 1.15, 0.12, 0.55, 0.12)
			G.daze(stun, Color("ffe070"), Vector3(0, 2.2, 1.4), 0.75, 1.2, 0.12)
			M.sparks(stun, "tq_embers", [AMBER, CREAM, BRONZE], G.n(16), 0.5, radius * 0.5, 2.5, 4.5, 0.12, 0.05, 0.9, Vector3.ZERO, 5.0, 606, 0.1, 0.6)
			G.done(stun)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [AMBER, CREAM], crit)
