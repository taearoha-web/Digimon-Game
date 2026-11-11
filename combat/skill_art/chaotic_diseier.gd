extends RefCounted
## Dark Lord Lv.60: Chaotic Diseier (พลังโกลาหล 6 สาย). An orb of chaos churns at the
## scepter over a violet hexagram at the Lord's feet. On the release a fan of violet force
## bursts out in front, and each of the six bolts (the real projectiles' flights) flies as
## a violet comet with a twisting dark tail; where a bolt strikes, the chaos folds in on
## itself (a ring collapsing inward), then bursts in sparks over a small violet scar.
## Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const VIOLET := Color("8a4dff")
const VIOLET_HI := Color("e0c8ff")
const VIOLET_DK := Color("2a1050")
const MAGENTA := Color("d050ff")
const GOLD := Color("e8b64a")


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.1
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		var hand := c.local(art, c.hand()) + Vector3(0, 0.1, 0.25)
		K.put(art, K.VEIL, S.spiral("chaos_orb", Color(0.6, 0.3, 1.0, 0.9), Color(0.9, 0.5, 1.0, 0.2), 3, 2.0, 0.5), "ChaosOrb", hand - Vector3.UP * 0.35, Vector3(0.45, 0.7, 0.45), Vector3.ZERO, t, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.1, "spin": 14.0, "decay": 0.95})
		K.put(art, K.VEIL, K.sprite(), "ChaosHeart", hand, Vector3.ONE * 0.55, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95, "pulse": true}, {"radial": 1.8, "billboard": true, "tint": Color("7a30d0"), "opacity": 0.8})
		K.put(art, K.VEIL, M.sigil("chaos", VIOLET_HI, Color(VIOLET, 0.2), 6, 2, 6), "ChaosSeal", Vector3.UP * 0.05, Vector3.ONE * 1.6, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": -1.8, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var art := c.open(origin, 0.8, "Burst", c.caster)
	if art:
		var hand := c.local(art, c.hand()) + Vector3(0, 0.1, 0.3)
		K.put(art, K.VEIL, M.DS.arcs_mesh(), "ChaosFan", hand - Vector3.UP * 0.2, Vector3.ONE * 1.1, Vector3.ZERO, 0.45, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.4}, {"tint": Color("b080ff"), "opacity": 0.8})
		K.put(art, K.VEIL, K.shock(MAGENTA, VIOLET_HI, VIOLET), "ChaosRing", hand, Vector3.ONE * 0.9, Vector3(PI / 2, 0, 0), 0.35, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(art, K.VEIL, S.sparkles("chaos_spit", [VIOLET, MAGENTA, VIOLET_HI], 16, 2.0, 2.0), "ChaosSpit", hand, Vector3.ONE * 0.6, Vector3.ZERO, 0.7, {"cull": 5.0, "decay": 0.7}, {"burst": 1.0, "gravity": 1.0, "drag": 2.5, "life": 0.7})
		K.put(art, K.VEIL, M.sigil("chaos", VIOLET_HI, Color(VIOLET, 0.2), 6, 2, 6), "ChaosSealFlash", Vector3.UP * 0.05, Vector3.ONE * 2.0, Vector3.ZERO, 0.6, {"initial": 0.8, "grow_time": 0.3, "fade_in": 0.01, "spin": -3.0, "decay": 0.4})
		M.show(art)
	return true


## One bolt of chaos: a violet comet with a twisting dark tail.
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, _size: float) -> Node3D:
	var c := M.beat(parent, skill, from)
	var art := c.open(from, seconds + 0.05, "Bolt", null)
	if not art:
		return null
	art.rotation.y = 0.0
	var dir := to - from
	var go := {"initial": 1.0, "travel": dir, "fade_in": 0.02, "decay": 0.96}
	K.put(art, K.VEIL, S.tail("chaos_tail", Color(0.62, 0.32, 1.0, 0.95), Color(0.25, 0.08, 0.45, 0.5)), "ChaosTail", Vector3.ZERO, Vector3(1.1, 2.8, 1.1), M.along(-dir), seconds, go)
	K.put(art, K.VEIL, S.spiral("chaos_twist", Color(0.75, 0.4, 1.0, 0.8), Color(0.3, 0.1, 0.5, 0.0), 2, 2.5, 0.3), "ChaosTwist", Vector3.ZERO, Vector3(0.45, 2.2, 0.45), M.along(-dir), seconds, go)
	K.put(art, K.VEIL, K.sprite(), "ChaosHead", Vector3.ZERO, Vector3.ONE * 0.95, Vector3.ZERO, seconds, go.merged({"front": true}), {"radial": 1.6, "billboard": true, "tint": Color("9a50ff"), "opacity": 0.9})
	M.show(art)
	return art


## The chaos folds in on itself where a bolt lands, then bursts.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, _crit: bool) -> void:
	if not M.contact_ok(String(skill.id), 40):
		return
	var c := M.beat(parent, skill, at)
	var art := c.open(at, 0.9, "Fold", null)
	if not art:
		return
	K.put(art, K.VEIL, K.shock(VIOLET, VIOLET_HI, VIOLET_DK), "ChaosFold", Vector3.ZERO, Vector3.ONE * 1.3, Vector3(0.9, 0, 0), 0.22, {"initial": 2.4, "grow_time": 1.0, "fade_in": 0.01, "decay": 0.8}, {"opacity": 0.85})
	K.put(art, K.VEIL, S.sparkles("chaos_pop", [VIOLET, MAGENTA, VIOLET_HI, GOLD], 16, 3.0, 2.5), "ChaosPop", Vector3.ZERO, Vector3.ONE * 0.85, Vector3.ZERO, 0.7, {"cull": 5.0, "decay": 0.7, "delay": 0.15}, {"burst": 1.0, "gravity": 3.0, "drag": 1.8, "life": 0.7})
	K.put(art, K.VEIL, K.sprite(), "ChaosPopGlow", Vector3.ZERO, Vector3.ONE * 1.5, Vector3.ZERO, 0.35, {"initial": 0.3, "grow_time": 0.5, "fade_in": 0.01, "decay": 0.3, "delay": 0.15}, {"radial": 1.6, "billboard": true, "tint": Color("8040e0"), "opacity": 0.8})
	K.put(art, K.VEIL, K.cracks("chaos_scar", VIOLET_DK, MAGENTA, 7, 0.25), "ChaosScar", Vector3(0, -at.y + 0.04, 0), Vector3.ONE * 1.5, Vector3.ZERO, 0.85, {"initial": 0.5, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.55, "delay": 0.15, "priority": -1})
	M.show(art)
