extends RefCounted
## Summoner Lv.92: Primal Legion (อสูรป่าดึกดำบรรพ์). The primal drum of the earth: a
## jade fire rings the Summoner's feet over a three-cornered seal and the ground cracks
## green at the three spots where the beasts will rise. On the release a roar of jade
## shock rolls out, and each beast erupts from its spot in a pillar of jade fire, rocks
## flying, great claw rakes torn into the ground and a ring of green flame round it; the
## fires burn down to embers. The creatures (Summon) and their AI are untouched. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const JADE := Color("7aff8a")
const JADE_HI := Color("e0ffd0")
const JADE_DK := Color("1a6a3a")
const AMBER := Color("ffd060")
const ROCK := Color("6a5a40")
const FIRE := [Color(0.25, 0.85, 0.45, 0.9), Color(0.4, 1.0, 0.55, 0.85), Color(0.65, 1.0, 0.6, 0.7), Color(0.85, 1.0, 0.6, 0.45), Color(1.0, 0.95, 0.6, 0.2)]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.15
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, S.flame_ring("primal_feet", FIRE, 10, 0.14, 0.8, 0.5), "PrimalFeetFire", Vector3.ZERO, Vector3(1.3, 1.1, 1.3), Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.2, "spin": 1.5, "decay": 0.9}, {"noise_amt": 0.6, "noise_scale": Vector2(4.0, 2.0), "flow": Vector2(0.0, -3.0), "bias": 0.3, "taper": 0.8})
		K.put(art, K.VEIL, M.sigil("primal", JADE_HI, Color(JADE, 0.22), 3, 1, 3), "PrimalSeal", Vector3.UP * 0.05, Vector3.ONE * 1.8, Vector3.ZERO, t, {"initial": 0.4, "grow_time": 0.7, "fade_in": 0.2, "spin": -1.0, "decay": 0.9})
		M.show(art)
	var spots := c.open(origin, t, "Spots", c.caster)
	if spots:
		spots.rotation.y = 0.0
		var n := int(skill.get("summon", {}).get("count", 3))
		for i in mini(n, 3):
			K.put(spots, K.VEIL, K.cracks("primal_spot", Color(0.22, 0.4, 0.22), JADE, 8, 0.3), "PrimalCrack%d" % i, M.formation(skill, i, n) + Vector3.UP * 0.05, Vector3.ONE * 1.5, Vector3(0, i * 1.3, 0), t, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.92, "delay": 0.04 * i})
		M.show(spots)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var roar := c.open(origin, 1.0, "Roar", c.caster)
	if roar:
		K.put(roar, K.VEIL, K.shock(JADE, JADE_HI, JADE_DK), "PrimalRoar", Vector3.UP * 0.1, Vector3.ONE * 5.2, Vector3.ZERO, 0.6, {"initial": 0.12, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.85})
		K.put(roar, K.VEIL, S.flame_ring("primal_feet", FIRE, 10, 0.14, 0.8, 0.5), "PrimalFeetBlaze", Vector3.ZERO, Vector3(1.6, 1.8, 1.6), Vector3.ZERO, 0.8, {"initial": 1.0, "fade_in": 0.01, "spin": 2.0, "decay": 0.4}, {"noise_amt": 0.6, "noise_scale": Vector2(4.0, 2.0), "flow": Vector2(0.0, -3.0), "bias": 0.3, "taper": 0.8})
		M.show(roar)
	(VfxBudget.carry(func(): _arrive(c))).call_deferred()
	return true


static func _arrive(c: M.Cast) -> void:
	var pack := M.summons(c.parent, c.id, c.origin)
	for i in mini(pack.size(), 3):
		var beast: Node3D = pack[i]
		var at := c.open(beast.global_position, 1.9, "Beast%d" % i, null)
		if not at:
			return
		var lag := 0.06 * i
		var away := (beast.global_position - c.origin) * Vector3(1, 0, 1)
		if away.length_squared() > 0.01:
			at.rotation.y = atan2(away.x, away.z)
		K.put(at, K.VEIL, K.column("primal_fire", FIRE.slice(0, 4), 0.55, 14), "PrimalPillar", Vector3.ZERO, Vector3(1.0, 3.8, 1.0), Vector3.ZERO, 0.65, {"initial": 0.4, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.3, "delay": lag}, {"opacity": 0.55, "fres": 0.6, "noise_amt": 0.75, "noise_scale": Vector2(5.0, 2.0), "flow": Vector2(0.2, -3.5), "bias": 0.15, "taper": 0.9, "hot": JADE_HI, "edge_heat": 0.6})
		K.put(at, K.VEIL, S.rake("primal_claws", Color(0.85, 1.0, 0.8, 0.9), JADE, 3), "PrimalClaws", Vector3(0, 0.2, 0.9), Vector3(1.3, 1.5, 1.3), Vector3.ZERO, 0.5, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.45, "delay": lag + 0.1})
		K.put(at, K.SOLID, K.debris("primal_rocks", [ROCK, ROCK.lightened(0.3), JADE_DK], 18, 0.28), "PrimalRocks", Vector3.UP * 0.2, Vector3.ONE * 0.8, Vector3.ZERO, 1.1, {"cull": 10.0, "decay": 0.9, "delay": lag}, M.STONE_LOOK.merged({"burst": 1.0, "gravity": 16.0, "drag": 1.0, "life": 1.1}))
		K.put(at, K.VEIL, S.flame_ring("primal_ring", FIRE, 12, 0.16, 0.9, 0.55), "PrimalRing", Vector3.ZERO, Vector3(1.9, 1.2, 1.9), Vector3.ZERO, 1.5, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.01, "spin": 1.0, "decay": 0.55, "delay": lag}, {"noise_amt": 0.6, "noise_scale": Vector2(4.0, 2.0), "flow": Vector2(0.0, -3.0), "bias": 0.3, "taper": 0.8})
		K.put(at, K.VEIL, K.cracks("primal_spot", Color(0.22, 0.4, 0.22), JADE, 8, 0.3), "PrimalScar", Vector3.UP * 0.04, Vector3.ONE * 2.0, Vector3(0, i, 0), 1.8, {"initial": 0.7, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "delay": lag, "priority": -1})
		K.put(at, K.GLOW, K.embers("primal_embers", [JADE, JADE_HI, AMBER], 22, 3.0, 2.0), "PrimalEmbers", Vector3.UP * 0.3, Vector3.ONE * 0.8, Vector3.ZERO, 1.7, {"cull": 8.0, "decay": 0.8, "delay": lag}, {"burst": 1.0, "gravity": -0.8, "drag": 1.4, "life": 1.7, "opacity": 0.8})
		M.show(at)
