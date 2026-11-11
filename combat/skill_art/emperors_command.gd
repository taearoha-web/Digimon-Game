extends RefCounted
## Dark Lord Lv.96: Emperor's Command (ราชโองการจักรพรรดิ), the Lord's greatest order.
## Golden light falls on the Emperor from above onto a royal seal. On the release a great
## crown of gold and violet descends out of the sky and settles over the Emperor's head, a
## wide ring of eight imperial standards rises round them with banners flying, a pillar of
## gold light flares, golden sparks burst like confetti and two rings of command sweep out;
## every ally reached is crowned by a ring of gold. The standards sink and the crown rises
## away as the order is given. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const ROYAL := Color("e8b64a")
const GOLD_HI := Color("fff0c0")
const GOLD_DK := Color("8a5a18")
const VIOLET := Color("8a4dff")
const VIOLET_DK := Color("3a1a6a")
const CRIMSON := Color("a02040")
const POLE := Color("2a2030")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.12
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, K.column("emperor_fall", [Color(1.0, 0.8, 0.35, 0.0), Color(1.0, 0.85, 0.4, 0.35), Color(1.0, 0.9, 0.55, 0.45), Color(1.0, 0.9, 0.6, 0.0)], 0.7, 16), "EmperorLight", Vector3.ZERO, Vector3(1.4, 7.5, 1.4), Vector3.ZERO, t, {"initial": 0.6, "grow_time": 0.8, "fade_in": 0.4, "decay": 0.9}, {"noise_amt": 0.5, "noise_scale": Vector2(5.0, 1.5), "flow": Vector2(0.0, 2.5), "bias": 0.2, "taper": 0.3, "fres": 0.5})
		K.put(art, K.VEIL, M.sigil("emperor", GOLD_HI, Color(ROYAL, 0.2), 12, 5, 8), "EmperorSeal", Vector3.UP * 0.05, Vector3.ONE * 2.2, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": 0.8, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var throne := c.open(origin, 2.6, "Crown", c.caster)
	if throne:
		K.put(throne, K.SOLID, M.crown("emperor", ROYAL, VIOLET, 9), "EmperorCrown", Vector3.UP * 2.7, Vector3.ONE * 0.55, Vector3.ZERO, 2.5, {"initial": 1.0, "fade_in": 0.02, "spin": 0.9, "decay": 0.72, "front": true}, M.GOLD_LOOK.merged({"slide": Vector3(0, 4.5, 0), "slide_time": 0.35, "slide_ease": -2.5}))
		K.put(throne, K.VEIL, K.column("emperor_pillar", [Color(1.0, 0.78, 0.3, 0.6), Color(1.0, 0.85, 0.45, 0.45), Color(0.8, 0.6, 1.0, 0.18), Color(0.8, 0.6, 1.0, 0.0)], 0.75, 18), "EmperorPillar", Vector3.ZERO, Vector3(1.5, 7.0, 1.5), Vector3.ZERO, 0.8, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.3}, {"opacity": 0.5, "noise_amt": 0.5, "noise_scale": Vector2(6.0, 1.5), "flow": Vector2(0.0, -3.0), "bias": 0.1, "taper": 0.5, "fres": 0.5})
		K.put(throne, K.VEIL, M.sigil("emperor", GOLD_HI, Color(ROYAL, 0.2), 12, 5, 8), "EmperorSealOpen", Vector3.UP * 0.05, Vector3.ONE * 3.6, Vector3.ZERO, 2.4, {"initial": 0.6, "grow_time": 0.2, "fade_in": 0.01, "spin": 0.4, "decay": 0.6, "priority": -1})
		K.put(throne, K.VEIL, K.shock(GOLD_HI, ROYAL, VIOLET), "EmperorHalo", Vector3.UP * 2.75, Vector3.ONE * 0.9, Vector3.ZERO, 2.3, {"initial": 0.3, "grow_time": 0.25, "fade_in": 0.02, "spin": -1.2, "decay": 0.7, "delay": 0.3}, {"opacity": 0.8})
		M.show(throne)
	var court := c.open(origin, 2.6, "Court", c.caster)
	if court:
		K.put(court, K.SOLID, M.standards("emperor", POLE, CRIMSON, ROYAL, 8), "EmperorStandards", Vector3.ZERO, Vector3(3.4, 2.5, 3.4), Vector3.ZERO, 2.5, {"initial": 1.0, "fade_in": 0.01, "decay": 0.65, "spin": -0.12, "delay": 0.08, "cull": 4.0}, M.GOLD_LOOK.merged({"slide": Vector3(0, -2.8, 0), "slide_time": 0.3, "slide_ease": -2.5, "flap": 0.14, "flap_rate": 7.0}))
		K.put(court, K.VEIL, S.sparkles("emperor_confetti", [ROYAL, GOLD_HI, VIOLET, CRIMSON], 30, 6.0, 3.0), "EmperorConfetti", Vector3.UP * 0.8, Vector3.ONE * 1.2, Vector3.ZERO, 2.2, {"cull": 12.0, "decay": 0.8}, {"burst": 1.0, "gravity": 2.0, "drag": 1.4, "life": 2.2})
		K.put(court, K.VEIL, K.shock(ROYAL, GOLD_HI, GOLD_DK), "EmperorRing", Vector3.UP * 0.08, Vector3.ONE * 6.0, Vector3.ZERO, 0.7, {"initial": 0.12, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(court, K.VEIL, K.shock(VIOLET, GOLD_HI, VIOLET_DK), "EmperorRing2", Vector3.UP * 0.1, Vector3.ONE * 4.6, Vector3.ZERO, 0.7, {"initial": 0.12, "grow_time": 0.9, "decay": 0.35, "delay": 0.3}, {"opacity": 0.65})
		M.show(court)
	if c.rich:
		var rays := c.open(origin, 1.6, "Rays", c.caster)
		if rays:
			K.put(rays, K.VEIL, S.spiral("emperor_rise", Color(1.0, 0.82, 0.4, 0.8), Color(0.8, 0.6, 1.0, 0.0), 4, 1.2, 0.6), "EmperorRise", Vector3.UP * 0.1, Vector3(1.6, 4.0, 1.6), Vector3.ZERO, 1.2, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.02, "spin": 5.0, "decay": 0.5})
			K.put(rays, K.GLOW, K.embers("emperor_gold", [ROYAL, GOLD_HI], 26, 4.0, 2.5), "EmperorEmbers", Vector3.UP * 0.4, Vector3.ONE, Vector3.ZERO, 1.6, {"cull": 10.0, "decay": 0.8}, {"burst": 1.0, "gravity": -0.4, "drag": 1.5, "life": 1.6, "opacity": 0.75})
			M.show(rays)
	var team := M.allies(c, 12.0, [1, 2, 4][c.q])
	if not team.is_empty():
		var marks := c.open(origin, 1.4, "Decree", null)
		if marks:
			marks.rotation.y = 0.0
			for i in team.size():
				var at: Vector3 = marks.to_local((team[i] as Node3D).global_position)
				K.put(marks, K.VEIL, K.shock(ROYAL, GOLD_HI, VIOLET), "EmperorDecree%d" % i, at + Vector3.UP * 0.08, Vector3.ONE * 1.6, Vector3.ZERO, 0.9, {"initial": 0.2, "grow_time": 0.8, "decay": 0.4, "delay": 0.15 + 0.05 * i}, {"opacity": 0.8})
			M.show(marks)
	return true
