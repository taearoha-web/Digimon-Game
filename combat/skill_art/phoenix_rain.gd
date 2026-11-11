extends RefCounted
## Archer Lv.88 "Phoenix Rain" (ฝนเพลิงฟีนิกซ์): a phoenix bursts into a rain of fire.
## Cosmetic only. Wind-up: fire wreathes the bow, a phoenix of flame unfolds its wings
## behind the archer and a ring of embers marks the area. Release: the phoenix takes off
## over the field, beating its wings and shedding burning feathers, and bursts in the sky
## over the area; out of the burst falls a rain of fire arrows that land with the real
## hit, each in a puff of flame; the ground scorches, a low ring of fire runs round the
## rim (the burn), embers drift up and fiery feathers float down.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const FIRE := {"c_core": Color("ffe9a0"), "c_mid": Color("ff9a3a"), "c_edge": Color("c8321a")}
const FLAME := {"c_core": Color("fff0b0"), "c_mid": Color("ffb14a"), "c_edge": Color("e04a1a")}
const EMBER := {"c_core": Color("ffe0a0"), "c_mid": Color("ff8a3a"), "c_edge": Color("a02a1a")}
const ASH := {"c_core": Color("3a2420"), "c_mid": Color("ff7a2a"), "c_edge": Color("1a0e0c")}
const BIRD := {"tint": Color("ffb35a"), "ember": Color("ffd27a"), "glow": Color("ffe8b0"), "rim": 0.75, "shadow": Color("b8301a"), "spread": 1.0, "flap": 0.55, "flap_rate": 7.0}
const ARROW := {"tint": Color("ffc87a"), "ember": Color("ff9a3a"), "glow": Color("fff0c0"), "rim": 0.75, "shadow": Color("8a2a1a")}
const PLUME := {"tint": Color("ffb35a"), "ember": Color("ffd88a"), "glow": Color("fff0c0"), "rim": 0.55, "shadow": Color("a03a1a")}
const FLIGHT := 0.28


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 8.5)), 4.0, 10.0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.8, visual)
	var rad := _radius(skill)
	var w := c.toward(origin, aim, duration + 0.12, "Wreath", duration)
	if w:
		var hand := w.to_local(c.hand())
		A.flash(w, hand, 1.3, FIRE, 0.0, duration + 0.1, 0.55, {"grow": duration, "from": 0.2})
		A.helix(w, hand + Vector3(0, -0.6, 0), Vector3(0.7, 0.5, 0.7), FLAME, 0.0, duration + 0.1, 8.0, 0.5)
		# The phoenix unfolds behind the archer.
		var back := w.stage(0.0, -0.6, 0.6)
		A.solid(w, A.mesh("phoenix"), BIRD.merged({"spread": 0.0}), back, Vector3.ONE * 0.62, Vector3.ZERO, 0.0, duration + 0.1,
			{"grow": duration * 0.8, "from": 0.3, "yaw_cam": true, "curves": {"spread": [0.0, 0.0, duration * 0.9, 1.0]}, "fout": 0.05})
	var centre := A.flat(aim)
	var g := c.toward(centre, centre + (centre - origin), duration + 0.7, "Mark", duration)
	if g:
		A.rim(g, Vector3.UP * 0.06, rad, FIRE, 0.0, duration + 0.7, 0.5)
		A.sigil(g, Vector3.UP * 0.05, rad * 0.8, 5.0, EMBER, 0.0, duration + 0.7, duration, 0.35, -0.2)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, impact_delay: float) -> bool:
	var land := maxf(impact_delay, 0.0)
	var rad := _radius(skill)
	var c := A.cast(parent, skill, origin, land + 2.0)
	var centre := A.flat(center)
	var r := c.toward(centre, centre + (centre - origin), land + 1.9, "Rain")
	if not r:
		return true
	var fly := minf(FLIGHT, maxf(land, 0.12))
	var burst_at := maxf(land - fly - 0.04, 0.0)
	var sky := Vector3(0, clampf(GodSkillArt.headroom(r, r.global_position) - 1.5, 3.5, 5.5), 0)
	# The phoenix flies from the archer over the field and bursts in the sky.
	var start := r.to_local(c.origin) + Vector3(0, 2.4, 0)
	if burst_at > 0.05:
		A.solid(r, A.mesh("phoenix"), BIRD, start, Vector3.ONE * 0.62, Vector3.ZERO, 0.0, burst_at + 0.06,
			{"travel": sky - start, "tw": Vector2(0, burst_at), "ease": 2, "yaw_cam": true, "scale_curve": [0.0, 1.0, burst_at, 1.35], "fin": 0.02, "fout": 0.06, "priority": 2})
		if c.has(1):
			A.beam(r, start, sky, 1.1, FLAME, 0.0, burst_at * 2.5, 0.35, 6.0)
	A.flash(r, sky, 4.0, FIRE, burst_at, 0.4, 0.5)
	A.glow(r, 2, sky, Vector3.ONE * 3.2, Vector3.ZERO, FLAME, burst_at, 0.5, 0.5, {"billboard": true, "p1": 10.0, "p2": 0.25})
	# The rain of fire arrows, landing with the real hit.
	var count := c.n(6, 10, 15)
	var spots := A.spots(count, rad * 0.85, 2.3)
	var times := A.delays(count, 0.15, 1.0)
	A.rain(r, K.mesh("light_arrow"), ARROW, spots, times, Vector3(0, -1, 0.1), 1.05, fly, land - fly, 0.25, 6.0, 0.0)
	var landed := []
	for t in times:
		landed.append(float(t) + fly)
	A.puffs(r, Vector3.ZERO, rad * 0.8, c.n(4, 7, 11), FLAME, 1.1, land, 0.7, 0.9, true, 3.0, 0.15)
	A.marks(r, spots, landed, 1.1, FIRE, land - fly, 0.45)
	# The ground burns: scorch, a low ring of fire on the rim, embers rising.
	A.ring(r, Vector3.UP * 0.08, rad * 1.1, FIRE, land, 0.7, 0.55)
	if c.has(0):
		A.fire_wall(r, Vector3.ZERO, rad * 0.95, 0.9, FLAME, land + 0.05, 1.2, 0.7, {"grow": 0.15, "from": 0.6})
	if c.has(1):
		A.scorch(r, Vector3.UP * 0.04, rad * 0.6, ASH, land, 1.5, 3.0)
		A.S.motes(r, Vector3.ZERO, rad * 0.75, c.n(5, 8, 12), EMBER, 0.24, land + 0.1, 0.6, 0.9, 1.8, 9, 4.0)
		A.drift(r, PLUME, sky * 0.7, rad * 0.5, c.n(3, 5, 8), 2.0, 0.42, burst_at, 1.6, Vector3(0.2, 0, 0), 6.0)
	return true
