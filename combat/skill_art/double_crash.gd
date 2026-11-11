extends RefCounted
## Warrior Lv.68 "Double Crash" (burst): two crushing blows, one after the other. Wind-up:
## the blade is heaved up overhead trailing orange light, pebbles hop off the trembling
## ground and faint fissures glow round the warrior. Release: the first blow slams down in
## front (a vertical crescent into the earth, a ring and a spray of rock); a beat later the
## second crashes from the other shoulder: a ring sweeps the whole area, fissures burst out
## to its edge and a ring of rock shards heaves up round the warrior. Orange, amber, rock.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const ORANGE := Color("ff7a3a")
const AMBER := Color("ffc25a")
const DEEP := Color("6a2410")
const ROCK := Color("6b5a4c")
const DUST := Color("bfa080")
const R := 5.5
## The second blow lands this long after the first.
const SECOND := 0.22


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.15, duration)
	var s := float(skill.get("radius", R)) / R
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	# The heave: an arc of light from behind the shoulder up over the head.
	B.light(art, B.vslash("crash_heave", 1.7, 2.3, 0.15, 0.9, B.a(ORANGE, 0.85), B.a(AMBER, 0.5), Color(0, 0, 0, 0)), "CrashHeave", Vector3.UP * 1.0, Vector3.ONE, t + 0.05, {"sweep": t * 0.8, "soft": 0.7, "hot": B.hot(AMBER), "flick": 0.12, "add": 0.65}, {"fade_in": 0.08, "decay": 0.9}, Vector3(0, PI * 0.5, 0))
	M.cracks(art, "crash_omen", B.a(ORANGE, 0.6), R * 0.75 * s, 0.0, t + 0.05, 8, 31)
	B.bits(art, M.fan("crash_hop", "rock", 14, 0.8, R * 0.7, PI, 0.4, 2.6, [ROCK, ROCK.lightened(0.15)], 0.16, 32, 0.05, 0.1, t * 0.6), "CrashHop", Vector3.ZERO, t + 0.05, {"life": t * 0.8, "gravity": 14.0, "piece": 0.16, "floor_y": 0.05, "shrink": 0.85, "spin": 5.0})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, origin)
	var radius := float(skill.get("radius", R))
	var s := radius / R
	var at := B.ground(origin)
	var front := Vector3(0, 0, 1.8)
	var first := B.open(c, at, 1.0, "CrashA")
	if first == null:
		return false
	# Blow one: down in front.
	B.light(first, B.vslash("crash_slam_a", 2.1, 0.35, -2.4, 1.7, B.a(ORANGE, 0.97), B.a(AMBER, 0.85), B.a(DEEP, 0.9)), "CrashSlamA", Vector3.UP * 1.0, Vector3.ONE, 0.42, {"sweep": 0.06, "tail": 3.5, "soft": 0.6, "hot": B.hot(AMBER), "core": 0.35, "add": 0.65, "gain": 1.15}, {"fade_in": 0.01, "decay": 0.5}, Vector3(0, PI * 0.5, 0.18))
	M.shock(first, "crash_shock_a", ORANGE, radius * 0.55, 0.05, 0.45, 0.24, 0.1)
	M.flash(first, "crash_flash_a", ORANGE, 2.6, 0.05, 0.35)
	M.rubble(first, "crash_rubble_a", [ROCK, ROCK.lightened(0.12), ROCK.darkened(0.2)], 14, 0.2, 1.0, 3.5, 6.0, 0.3, 0.05, 1.0, front, 33)
	# Blow two, a beat later from the other shoulder: the whole area answers.
	var second := B.open(c, at, 1.6, "CrashB")
	if second == null:
		return true
	B.light(second, B.vslash("crash_slam_b", 2.4, 0.4, -2.45, 2.0, B.a(ORANGE, 0.97), B.a(AMBER, 0.9), B.a(DEEP, 0.9)), "CrashSlamB", Vector3.UP * 1.1, Vector3.ONE, 0.45, {"sweep": 0.06, "tail": 3.5, "soft": 0.6, "hot": B.hot(AMBER), "core": 0.35, "add": 0.7, "gain": 1.2}, {"delay": SECOND - 0.07, "fade_in": 0.01, "decay": 0.5}, Vector3(0, PI * 0.5, -0.22))
	M.shock(second, "crash_shock_b", AMBER, radius, SECOND, 0.55, 0.22, 0.11)
	M.cracks(second, "crash_cracks", ORANGE, radius * 0.95, SECOND, 1.35, 9, 34)
	B.body(second, B.spikes_ring("crash_spikes", 11, 2.6, 1.3, ROCK, B.a(ORANGE, 1.0), 0.08, 35), "CrashSpikes", Vector3.ZERO, Vector3.ONE * s, 1.3, {"drop": -1.5, "flight": 0.14, "ease": 1.0, "rim_color": AMBER, "rim": 0.45, "glow_color": ORANGE, "heat": 0.6}, {"delay": SECOND, "decay": 0.7})
	M.dust(second, "crash_dust", DUST, 16, radius * 0.5, radius * 0.9, SECOND + 0.04, 1.3, Vector3.ZERO, 1.0, 36)
	M.sparks(second, "crash_sparks", [ORANGE, AMBER], 22, 0.5, 2.5, 6.0, 5.0, 0.14, SECOND, 0.8, Vector3.ZERO, 7.0, 37)
	return true
