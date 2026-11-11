extends RefCounted
## Dark Lord Lv.72: Dark Comet (ดาวหางมืด). A rift of violet void opens high in the sky
## beyond the target and a ring of runes marks where the comet will fall. On the release a
## dark comet breaks out of the rift, a black rock veined with violet fire trailing a
## violet tail, and falls on the area in the meteor's own time (impact_delay); it lands in
## a violet crater: dark fire rings it, a column of void smoke erupts, rocks are thrown and
## gold sparks rise, and the smoke hangs a moment before it thins. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const VIOLET := Color("8a4dff")
const VIOLET_HI := Color("e0c8ff")
const VIOLET_DK := Color("1e0a3a")
const MAGENTA := Color("c040ff")
const GOLD := Color("e8b64a")
const ROCK := Color("2a2038")
const VOID_FIRE := [Color(0.35, 0.1, 0.6, 0.9), Color(0.55, 0.2, 0.95, 0.85), Color(0.75, 0.4, 1.0, 0.7), Color(0.9, 0.6, 1.0, 0.45), Color(1.0, 0.8, 1.0, 0.2)]
const SKY := 8.0
const TALL := 9.0


static func _rift(parent: Node3D, point: Vector3) -> Vector3:
	return point + M.away(parent) * 3.5 + Vector3.UP * SKY


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.1
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		var hand := c.local(art, c.hand()) + Vector3(0, 0.3, 0.1)
		K.put(art, K.VEIL, K.sprite(), "CometCall", hand, Vector3.ONE * 0.7, Vector3.ZERO, t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95, "pulse": true}, {"radial": 1.8, "billboard": true, "tint": Color("7a30d0"), "opacity": 0.8})
		K.put(art, K.VEIL, S.spiral("comet_call", Color(0.6, 0.3, 1.0, 0.75), Color(0.9, 0.6, 1.0, 0.0), 3, 1.4, 0.4), "CometCallSpiral", Vector3.UP * 0.1, Vector3(1.3, 2.6, 1.3), Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.2, "spin": 5.0, "decay": 0.9})
		M.show(art)
	var point := Vector3(aim.x, origin.y, aim.z)
	c.fit = K.frame(parent, point, origin, TALL, 3.5)
	var r := M.radius(skill, 6.0) / c.fit
	var sky := c.open(point, t + 0.05, "Rift", null)
	if sky:
		sky.rotation.y = 0.0
		var rift := (_rift(parent, point) - point) / c.fit
		K.put(sky, K.VEIL, S.whirlpool("comet_void", VIOLET_DK, VIOLET, VIOLET_HI), "CometRift", rift, Vector3.ONE * 2.0, Vector3(0.75, 0, 0), t + 0.05, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.2, "spin": 2.5, "decay": 0.97}, {"opacity": 0.9})
		K.put(sky, K.VEIL, M.sigil("comet", VIOLET_HI, Color(VIOLET, 0.18), 9, 4, 9), "CometMark", Vector3.UP * 0.05, Vector3.ONE * r, Vector3.ZERO, t + 0.05, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.2, "spin": -0.6, "decay": 0.95}, {"opacity": 0.45})
		M.show(sky)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var point := Vector3(center.x, origin.y, center.z)
	c.fit = K.frame(parent, point, origin, TALL, 3.5)
	var r := M.radius(skill, 6.0) / c.fit
	var land := maxf(impact_delay, 0.0)
	var fall := c.open(point, land + 2.0, "Fall", null)
	if fall:
		fall.rotation.y = 0.0
		if land > 0.06:
			var from := (_rift(parent, point) - point) / c.fit
			var drop := Vector3.UP * 0.8 - from
			var go := {"initial": 1.0, "travel": drop, "accelerate": true, "fade_in": 0.03, "decay": 0.97}
			K.put(fall, K.SOLID, M.rock("comet", ROCK, MAGENTA), "CometRock", from, Vector3.ONE * 0.9, Vector3(0.4, 0.3, 0.2), land, go.merged({"front": true, "spin": 6.0}), M.DARK_LOOK)
			K.put(fall, K.VEIL, S.tail("comet_tail", Color(0.6, 0.3, 1.0, 0.95), Color(0.2, 0.05, 0.4, 0.4)), "CometTail", from, Vector3(1.6, 5.5, 1.6), M.along(-drop), land, go)
			K.put(fall, K.VEIL, K.sprite(), "CometHalo", from, Vector3.ONE * 1.8, Vector3.ZERO, land, go, {"radial": 1.6, "billboard": true, "tint": Color("7a30d0"), "opacity": 0.75})
			K.put(fall, K.VEIL, S.whirlpool("comet_void", VIOLET_DK, VIOLET, VIOLET_HI), "CometRiftClose", from, Vector3.ONE * 2.0, Vector3(0.75, 0, 0), land + 0.3, {"initial": 1.0, "fade_in": 0.001, "spin": 4.0, "decay": 0.5}, {"opacity": 0.9})
		K.put(fall, K.VEIL, M.scar("comet_crater", VIOLET_DK, MAGENTA, 12), "CometCrater", Vector3.UP * 0.04, Vector3.ONE * r * 0.85, Vector3.ZERO, 1.9, {"initial": 0.4, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "delay": land, "priority": -1})
		K.put(fall, K.VEIL, K.shock(VIOLET, VIOLET_HI, VIOLET_DK), "CometShock", Vector3.UP * 0.1, Vector3.ONE * r, Vector3.ZERO, 0.6, {"initial": 0.12, "grow_time": 0.85, "fade_in": 0.01, "decay": 0.35, "delay": land}, {"opacity": 0.85})
		M.show(fall)
	var blast := c.open(point, land + 2.0, "Crater", null)
	if blast:
		K.put(blast, K.VEIL, K.column("comet_smoke", [Color(0.45, 0.2, 0.8, 0.7), Color(0.35, 0.15, 0.6, 0.55), Color(0.25, 0.1, 0.45, 0.3), Color(0.2, 0.1, 0.35, 0.0)], 1.4, 16), "CometEruption", Vector3.ZERO, Vector3(1.4, 4.5, 1.4), Vector3.ZERO, 0.9, {"initial": 0.4, "grow_time": 0.25, "fade_in": 0.01, "decay": 0.4, "delay": land}, {"noise_amt": 0.7, "noise_scale": Vector2(5.0, 2.0), "flow": Vector2(0.2, -2.5), "bias": 0.2, "taper": 0.7})
		K.put(blast, K.VEIL, M.fire_ring("comet_fire", VOID_FIRE, r * 0.6, 20, 0.3, 1.5), "CometFire", Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 1.6, {"initial": 0.4, "grow_time": 0.2, "fade_in": 0.01, "spin": 0.5, "decay": 0.55, "delay": land}, {"noise_amt": 0.6, "noise_scale": Vector2(4.0, 2.0), "flow": Vector2(0.0, -3.0), "bias": 0.3, "taper": 0.8})
		K.put(blast, K.SOLID, K.debris("comet_rocks", [ROCK, ROCK.lightened(0.25), MAGENTA.darkened(0.3)], 26, 0.32), "CometRocks", Vector3.UP * 0.2, Vector3.ONE, Vector3.ZERO, 1.2, {"cull": 12.0, "decay": 0.9, "delay": land}, M.DARK_LOOK.merged({"burst": 1.0, "gravity": 15.0, "drag": 0.9, "life": 1.2}))
		K.put(blast, K.GLOW, K.embers("comet_gold", [GOLD, MAGENTA, VIOLET_HI], 24, 3.0, 3.0), "CometSparks", Vector3.UP * 0.3, Vector3.ONE, Vector3.ZERO, 1.5, {"cull": 10.0, "decay": 0.8, "delay": land}, {"burst": 1.0, "gravity": 1.5, "drag": 1.4, "life": 1.5, "opacity": 0.8})
		M.show(blast)
	if c.rich:
		var smoke := c.open(point, land + 2.4, "Smoke", null)
		if smoke:
			K.put(smoke, K.SOLID, S.puffs("comet_smoke", Color("6a4a9a"), Color("2a1a4a"), 10, 6.0), "CometPuffs", Vector3.UP * 0.3, Vector3.ONE * 0.55, Vector3.ZERO, 1.8, {"cull": 12.0, "decay": 0.6, "delay": land}, M.DARK_LOOK.merged({"burst": 1.0, "gravity": -0.6, "drag": 2.2, "life": 1.8}))
			K.put(smoke, K.VEIL, K.sprite(), "CometGlow", Vector3.UP * 0.12, Vector3.ONE * r * 0.7, Vector3(-PI / 2, 0, 0), 0.8, {"initial": 0.6, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.3, "delay": land}, {"radial": 1.4, "tint": Color("5a20a0"), "opacity": 0.2})
			M.show(smoke)
	return true
