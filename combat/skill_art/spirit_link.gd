extends RefCounted
## Summoner Lv.72: Spirit Link (เชื่อมวิญญาณ). Mint spirit wisps spiral in to the Summoner
## and a light gathers at the chest. On the release a ring seal of the spirits opens at the
## feet, a column of motes climbs, and threads of mint light run out to every creature and
## party member the blessing reaches, each blooming into a small star on them; the seal
## pulses once more and the motes drift up. Cosmetic only (the buff is the hero's).
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const MINT := Color("a8ffd0")
const MINT_HI := Color("e8fff4")
const JADE := Color("3fbf8a")
const SKY := Color("9ae8ff")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.12
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, S.spiral("link_in", Color(0.65, 1.0, 0.82, 0.8), Color(0.85, 1.0, 1.0, 0.0), 4, 1.4, 0.3), "LinkGather", Vector3.UP * 0.1, Vector3(1.8, 2.4, 1.8), Vector3.ZERO, t, {"initial": 1.7, "grow_time": 1.0, "fade_in": 0.2, "spin": -7.0, "decay": 0.9})
		K.put(art, K.VEIL, S.twinkle("link_heart", Color(MINT, 0.9), SKY), "LinkHeart", Vector3(0, 1.3, 0.2), Vector3.ONE * 0.8, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.95}, {"billboard": true})
		K.put(art, K.VEIL, M.sigil("link", MINT_HI, Color(MINT, 0.2), 8, 3, 8), "LinkSeal", Vector3.UP * 0.05, Vector3.ONE * 1.4, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": 1.5, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var art := c.open(origin, 1.8, "Bond", c.caster)
	if art:
		K.put(art, K.VEIL, M.sigil("link", MINT_HI, Color(MINT, 0.2), 8, 3, 8), "LinkSealOpen", Vector3.UP * 0.05, Vector3.ONE * 2.6, Vector3.ZERO, 1.7, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.01, "spin": 0.9, "decay": 0.6, "priority": -1})
		K.put(art, K.VEIL, S.spiral("link_rise", Color(0.6, 1.0, 0.8, 0.85), Color(0.75, 0.95, 1.0, 0.0), 3, 1.6, 0.6), "LinkRise", Vector3.UP * 0.1, Vector3(1.2, 3.8, 1.2), Vector3.ZERO, 1.1, {"initial": 0.4, "grow_time": 0.3, "fade_in": 0.02, "spin": 6.0, "decay": 0.45})
		K.put(art, K.VEIL, K.shock(MINT, MINT_HI, JADE), "LinkPulse", Vector3.UP * 0.08, Vector3.ONE * 3.2, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.35}, {"opacity": 0.8})
		K.put(art, K.VEIL, K.shock(SKY, MINT_HI, MINT), "LinkPulse2", Vector3.UP * 0.1, Vector3.ONE * 2.6, Vector3.ZERO, 0.6, {"initial": 0.15, "grow_time": 0.9, "decay": 0.35, "delay": 0.45}, {"opacity": 0.6})
		K.put(art, K.VEIL, S.twinkle("link_heart", Color(MINT, 0.9), SKY), "LinkFlare", Vector3(0, 1.3, 0.15), Vector3.ONE * 1.6, Vector3.ZERO, 0.45, {"initial": 0.4, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.4, "front": true}, {"billboard": true, "opacity": 0.85})
		K.put(art, K.VEIL, K.shock(MINT_HI, MINT, SKY), "LinkHalo", Vector3.UP * 2.45, Vector3.ONE * 0.6, Vector3.ZERO, 1.6, {"initial": 0.3, "grow_time": 0.25, "fade_in": 0.02, "spin": 2.0, "decay": 0.6, "delay": 0.05}, {"opacity": 0.85})
		K.put(art, K.VEIL, S.sparkles("link_motes", [MINT, MINT_HI, SKY], 22, 3.0, 1.6), "LinkMotes", Vector3.UP * 0.5, Vector3.ONE * 0.8, Vector3.ZERO, 1.7, {"cull": 6.0, "decay": 0.8}, {"burst": 1.0, "gravity": -1.0, "drag": 1.8, "life": 1.7})
		M.show(art)
	# The threads of the bond: to every creature and party member it reaches.
	var bonds := M.allies(c, 12.0, [1, 2, 3][c.q])
	if bonds.is_empty():
		return true
	var threads := c.open(origin, 1.2, "Threads", null)
	if threads:
		threads.rotation.y = 0.0
		var from := origin + Vector3.UP * 1.25
		for i in bonds.size():
			var to: Vector3 = (bonds[i] as Node3D).global_position + Vector3.UP * 1.0
			var lag := 0.04 * i
			M.span(threads, K.VEIL, M.beam("link_thread", Color(0.7, 1.0, 0.85, 0.9), Color(0.6, 0.9, 1.0, 0.6), 0.5), "LinkThread%d" % i, from, to, 0.55, 0.9, {"initial": 0.02, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.5, "delay": lag}, {"noise_amt": 0.5, "noise_scale": Vector2(2.0, 6.0), "flow": Vector2(0.0, -4.0), "bias": 0.4, "taper": 0.0})
			K.put(threads, K.VEIL, S.twinkle("link_bloom", Color(MINT, 0.9), SKY), "LinkBloom%d" % i, threads.to_local(to), Vector3.ONE * 0.9, Vector3.ZERO, 0.6, {"initial": 0.2, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.4, "delay": 0.25 + lag}, {"billboard": true})
		M.show(threads)
	return true
