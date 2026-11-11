extends RefCounted
## Defender Lv.84 "Judgment Shield": the shield of judgment passes sentence on one foe.
## Wind-up: high over the foe a tall golden shield bearing the scales of justice descends
## out of a halo, a seal of judgment turning under the foe. Release: the shield strikes down
## behind the foe and stands planted, a column of judgment light falls on the foe, the seal
## flares and stamps twice (the verdict), golden shards burst out and rays of the verdict
## run across the ground. Sun gold, ivory and a deep bronze.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "judgment_shield"
const GOLD := Color("ffd860")
const IVORY := Color("fff3cc")
const BRONZE := Color("a8641e")
const SKYGOLD := Color("ffe9a0")
const BEHIND := 1.3
const HIGH := 4.2


## The judgment shield: a heater with the scales of justice inlaid in light.
static func _shield() -> ArrayMesh:
	if M.has("js_shield"):
		return M.get_mesh("js_shield")
	var p := M.shield(Color("e8b030"), IVORY, GOLD)
	p.ink(GOLD.lightened(0.2), 0.0, 1.0)
	# The scales: a beam, a post and two pans, standing proud of the face.
	p.box(Vector3(0, 0.66, 0.1), Vector3(0.42, 0.025, 0.02))
	p.box(Vector3(0, 0.5, 0.1), Vector3(0.025, 0.36, 0.02))
	for s in [-1.0, 1.0]:
		p.tube(Vector3(s * 0.2, 0.66, 0.1), Vector3(s * 0.2, 0.5, 0.1), 0.006, 0.006, 3)
		p.tube(Vector3(s * 0.2 - 0.08, 0.49, 0.1), Vector3(s * 0.2 + 0.08, 0.49, 0.1), 0.02, 0.02, 4, 0.4)
	var st := K.begin()
	K.stamp(st, p)
	return M.keep("js_shield", K.finish(st, Vector3(1, 6, 1)))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var spot := Vector3(aim.x, 0.0, aim.z)
	var r := G.windup(parent, spot, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, spot), visual)
	if r == null:
		return false
	var behind := K.away(r) * BEHIND
	G.solid(r, _shield(), "Descend", behind + Vector3.UP * HIGH, Vector3.ONE * 3.0, time + 0.04, {"drop": 0.5, "flight": time, "ease": 1.0, "rim_color": IVORY, "rim": 1.0, "glow_color": GOLD}, {"initial": 0.7, "grow_time": 0.6, "fade_in": 0.12, "decay": 0.98}, Vector3(0, K.facing(r), 0))
	G.flat(r, G.orbits("js_halo", 1, GOLD, 0.05, 0.0), "Halo", behind + Vector3.UP * (HIGH + 2.9), Vector3.ONE * 1.1, time + 0.04, G.lit(GOLD, 0.6, 0.5), {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.1, "decay": 0.97, "spin": 1.5})
	G.flat(r, G.sigil("js_seal", GOLD, 3, 24, 8, 0.3), "Seal", Vector3.UP * 0.05, Vector3.ONE * 1.8, time + 0.04, G.lit(GOLD, 0.55, 0.5), {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95, "spin": -1.4})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var spot := Vector3(center.x, 0.0, center.z)
	var r := G.open(parent, spot, 1.5, "Skill_%s_verdict" % ID, G.yaw(origin, spot, G.facing(caster)), caster)
	if r == null:
		return false
	var behind := K.away(r) * BEHIND
	# Down behind the foe, point first, and planted.
	G.solid(r, _shield(), "Planted", behind + Vector3.DOWN * 0.35, Vector3.ONE * 3.0, 1.15, {"drop": (HIGH + 0.35) / 3.0, "flight": 0.07, "heat": 0.9, "rim_color": IVORY, "rim": 0.9, "glow_color": GOLD}, {"fade_in": 0.01, "decay": 0.7}, Vector3(0, K.facing(r), 0))
	M.pillar(r, "js_column", GOLD, 3.0, 5.5, 0.0, 0.42)
	M.shock(r, "js_ring", GOLD, 3.2, 0.02, 0.45, 0.2)
	G.flat(r, G.sigil("js_seal", GOLD, 3, 24, 8, 0.3), "Seal", Vector3.UP * 0.05, Vector3.ONE * 2.4, 1.3, G.lit(GOLD, 0.6, 0.5), {"initial": 0.7, "grow_time": 0.15, "fade_in": 0.01, "decay": 0.7, "spin": 0.4})
	G.bits(r, K.burst("js_shards", "shard", G.n(20), 0.2, 0.8, 5.0, 4.0, [GOLD, IVORY, BRONZE], 0.26, 0.04, 841, 0.4, 1.6), "Shards", Vector3.ZERO, 1.0, {"life": 0.85, "gravity": 9.0, "drag": 1.0, "piece": 0.26, "floor_y": 0.06, "add": 0.4, "shrink": 0.7, "spin": 8.0, "hot": Color(1.0, 0.9, 0.5, 0.5)}, {"decay": 0.85})
	M.sparks(r, "js_sparks", [GOLD, SKYGOLD], G.n(14), 0.1, 0.5, 3.0, 4.5, 0.1, 0.0, 0.7, Vector3.ZERO, 6.0, 842, 0.4, 1.4)
	G.done(r)
	if G.extras(1) > 0:
		var stamp := G.open(parent, spot, 1.2, "Skill_%s_stamp" % ID, r.rotation.y, caster)
		if stamp:
			# The verdict stamps a second time; its rays run across the ground.
			M.shock(stamp, "js_ring_b", IVORY, 4.2, 0.16, 0.5, 0.12)
			G.flat(stamp, G.rays("js_rays", 12, GOLD, 0.07), "Rays", Vector3.UP * 0.06, Vector3.ONE * 3.6, 0.9, G.lit(GOLD, 0.6, 0.5, {"sweep": 0.25}), {"delay": 0.12, "fade_in": 0.02, "decay": 0.6})
			M.flash(stamp, "js_flash", BRONZE, 2.0, 0.0, 0.35)
			M.cracks(stamp, "js_cracks", GOLD, 2.6, 0.1, 1.0, 8, 843, 0.07)
			G.done(stamp)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [GOLD, IVORY], crit)
