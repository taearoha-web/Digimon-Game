extends RefCounted
## Dark Lord 50 stars: นรกโกลาหล. The Dark Lord drives his staff into the ground: veins
## of ember light crack outward from his feet and the ground darkens; on the first beat
## a ring of crimson hellfire bursts up close round him, on the second a wider wall of
## fire erupts at the rim of the area and black smoke rolls off the scorched ground.
## Compact (two contacts) but hot. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "chaos_inferno"
const FIRE := [Color(1.0, 0.88, 0.5, 0.95), Color(1.0, 0.48, 0.12, 0.95), Color(0.88, 0.13, 0.15, 0.92), Color(0.42, 0.04, 0.2, 0.88), Color(0.15, 0.02, 0.12, 0.8)]
const EMBER := Color("ffb347")
const CRIMSON := Color("e8283a")
const PLUM := Color("4a0c2a")
const LOOK := {"noise_amt": 1.0, "noise_scale": Vector2(5.0, 1.5), "flow": Vector2(0.0, -3.2), "bias": 0.12, "taper": 0.95, "sway": 0.35, "edge_heat": 0.8, "hot": Color(1.0, 0.72, 0.3)}


static func _r(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 6.0)), 3.0, 8.0)


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := _r(skill)
	# Veins of ember light crack out from the staff's point, the ground darkens round them.
	K.put(art, K.VEIL, K.cracks("chaos_veins", Color(0.12, 0.02, 0.04), Color(1.0, 0.55, 0.15), 12, 0.0), "ChaosVeins", Vector3.UP * 0.05, Vector3.ONE * r * 0.7, Vector3.ZERO, time + 0.1, {"initial": 0.08, "grow_time": 0.9, "fade_in": 0.05, "decay": 0.95, "priority": -1})
	K.put(art, K.VEIL, K.area_mark(Color("ff7a2a"), CRIMSON), "ChaosArea", Vector3.UP * 0.07, Vector3.ONE * r, Vector3.ZERO, time + 0.1, {"initial": 0.5, "grow_time": 0.6, "spin": -0.6, "decay": 0.95})
	K.put(art, K.VEIL, S.flame_ring("chaos_feet", FIRE, 8, 0.16, 0.7, 0.45), "ChaosFeetFire", Vector3.UP * 0.02, Vector3(1.3, 1.4, 1.3), Vector3.ZERO, time + 0.06, {"initial": 0.2, "grow_time": 0.7, "fade_in": 0.2, "spin": 2.4, "decay": 0.9}, LOOK)
	K.put(art, K.GLOW, K.sprite(), "ChaosStaffGlow", Vector3(0.35, 1.45, 0.45), Vector3.ONE * 0.9, Vector3.ZERO, time, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.3, "decay": 0.9}, {"radial": 1.6, "billboard": true, "tint": Color("ff7a2a"), "opacity": 0.7})
	if S.rich():
		K.put(art, K.VEIL, S.wash("chaos_dark", Color(0.18, 0.02, 0.06, 0.42), Color(0.3, 0.03, 0.08, 0.3)), "ChaosDarken", Vector3.UP * 0.03, Vector3.ONE * r * 0.95, Vector3.ZERO, time + 0.1, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.4, "decay": 0.9, "priority": -2})
		K.put(art, K.VEIL, S.spiral("chaos_draw", Color(0.95, 0.2, 0.1, 0.75), Color(1.0, 0.6, 0.2, 0.0), 3, 1.1, 0.3), "ChaosDraw", Vector3.UP * 0.1, Vector3(2.2, 1.8, 2.2), Vector3.ZERO, time, {"initial": 1.4, "grow_time": 1.0, "fade_in": 0.2, "spin": -5.0, "decay": 0.85})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := _r(skill)
	if index == 0:
		# The inner ring of hellfire bursts up round the Dark Lord.
		K.put(art, K.VEIL, S.flame_ring("chaos_inner", FIRE, 11, 0.14, 0.95, 0.62), "ChaosInnerFire", Vector3.ZERO, Vector3(r * 0.42, 2.7, r * 0.42), Vector3.ZERO, 0.85, {"initial": 0.35, "grow_time": 0.18, "fade_in": 0.02, "decay": 0.5, "front": true}, LOOK)
		K.put(art, K.VEIL, K.shock(CRIMSON, Color("ffc070"), PLUM), "ChaosShock", Vector3.UP * 0.1, Vector3.ONE * r * 0.62, Vector3.ZERO, 0.45, {"initial": 0.25, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.35}, {"opacity": 0.85})
		K.put(art, K.VEIL, K.cracks("chaos_scar", Color(0.1, 0.01, 0.04), Color(1.0, 0.45, 0.12), 11, 0.3), "ChaosScar", Vector3.UP * 0.05, Vector3.ONE * r * 0.62, Vector3(0, 0.4, 0), 1.6, {"initial": 0.7, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "priority": -1})
		K.put(art, K.VEIL, K.embers("chaos", [EMBER, Color("ff6a2a"), CRIMSON]), "ChaosEmbers", Vector3.UP * 0.3, Vector3.ONE * 1.1, Vector3.ZERO, 1.1, {"cull": 10.0, "decay": 0.9}, {"burst": 1.0, "gravity": -2.0, "drag": 1.5, "life": 1.0})
		K.put(art, K.GLOW, K.sprite(), "ChaosHeat", Vector3.UP * 0.12, Vector3.ONE * r * 0.55, Vector3(-PI / 2, 0, 0), 0.5, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.3}, {"radial": 1.4, "tint": Color("ff5a1f"), "opacity": 0.45})
		return true
	# The outer wall of fire erupts at the rim of the area; smoke rolls off the scorched ground.
	K.put(art, K.VEIL, S.flame_ring("chaos_outer", FIRE, 16, 0.11, 0.85, 0.55), "ChaosOuterFire", Vector3.ZERO, Vector3(r * 0.86, 3.6, r * 0.86), Vector3(0, 0.2, 0), 1.0, {"initial": 0.55, "grow_time": 0.16, "fade_in": 0.02, "decay": 0.5, "front": true}, LOOK)
	K.put(art, K.VEIL, K.column("chaos_wall", [Color(1.0, 0.6, 0.2, 0.75), Color(0.9, 0.15, 0.15, 0.55), Color(0.35, 0.03, 0.18, 0.3), Color(0.2, 0.02, 0.1, 0.0)], 1.08, 28), "ChaosWall", Vector3.ZERO, Vector3(r * 0.86, 2.6, r * 0.86), Vector3.ZERO, 0.8, {"initial": 0.7, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.4}, LOOK.merged({"noise_scale": Vector2(14.0, 1.4), "bias": 0.0, "taper": 1.1}, true))
	K.put(art, K.VEIL, K.shock(CRIMSON, Color("ffc070"), PLUM), "ChaosShockWide", Vector3.UP * 0.1, Vector3.ONE * r * 1.08, Vector3.ZERO, 0.55, {"initial": 0.4, "grow_time": 0.9, "fade_in": 0.02, "decay": 0.35}, {"opacity": 0.85})
	K.put(art, K.VEIL, K.cracks("chaos_rim", Color(0.1, 0.01, 0.04), Color(1.0, 0.4, 0.1), 15, 0.0), "ChaosRimScar", Vector3.UP * 0.045, Vector3.ONE * r * 1.02, Vector3(0, 1.1, 0), 1.9, {"initial": 0.85, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "priority": -1})
	K.put(art, K.VEIL, K.embers("chaos_wide", [EMBER, Color("ff6a2a"), CRIMSON], 34, 3.5, 4.5), "ChaosEmbersWide", Vector3.UP * 0.3, Vector3.ONE * 1.5, Vector3.ZERO, 1.3, {"cull": 14.0, "decay": 0.9}, {"burst": 1.0, "gravity": -2.4, "drag": 1.3, "life": 1.2})
	K.put(art, K.SOLID, K.debris("chaos_rock", [Color("2a1418"), Color("4a1c1c"), Color("7a2a18")], 24, 0.34), "ChaosDebris", Vector3.UP * 0.2, Vector3.ONE * 1.3, Vector3.ZERO, 1.2, {"cull": 14.0, "decay": 0.9}, {"burst": 1.0, "gravity": 15.0, "drag": 1.0, "life": 1.1, "rim_color": Color("ff8a3a"), "rim": 0.7, "shadow_tint": Color(0.5, 0.3, 0.35)})
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var smoke := S.root(parent, point, 2.0, "StarSmoke_" + ID, source)
	if smoke:
		K.put(smoke, K.VEIL, K.column("chaos_smoke", [Color(0.18, 0.06, 0.08, 0.0), Color(0.2, 0.06, 0.1, 0.5), Color(0.12, 0.04, 0.08, 0.35), Color(0.1, 0.03, 0.06, 0.0)], 1.25, 24), "ChaosSmoke", Vector3.ZERO, Vector3(r * 0.8, 3.0, r * 0.8), Vector3.ZERO, 1.8, {"initial": 0.8, "grow_time": 0.5, "fade_in": 0.2, "travel": Vector3.UP * 0.8, "decay": 0.55, "delay": 0.25, "priority": -1}, {"noise_amt": 1.0, "noise_scale": Vector2(9.0, 1.2), "flow": Vector2(0.15, -0.8), "bias": -0.1, "taper": 0.6})
		K.put(smoke, K.VEIL, S.flame_ring("chaos_after", FIRE, 14, 0.07, 0.5, 0.3), "ChaosAfterFlames", Vector3.ZERO, Vector3(r * 0.8, 1.6, r * 0.8), Vector3(0, 0.7, 0), 1.9, {"initial": 0.6, "grow_time": 0.2, "fade_in": 0.1, "decay": 0.5, "delay": 0.4}, LOOK)
		smoke._draw()
	return true
