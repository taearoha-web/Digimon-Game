extends RefCounted
## Warrior Lv.72 "Piercing" (chain, 6 foes): the sword becomes a dart of gold light that
## runs through one foe after another. Wind-up: the warrior sets for the thrust, a thin gold
## sight-line reaches out to the first foe and a ring of light closes on the sword. Release:
## the dart zig-zags down the very chain the hit follows (the target, then the nearest foe
## each time), a gold sword run through every foe it reaches with a flare and a ring standing
## round the blade, sparks thrown on; behind it a burning trail and a gold line on the ground
## fade out. Gold, amber, warm white-gold.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const B := preload("res://combat/skill_art/_blade.gd")
const GOLD := Color("ffd27a")
const AMBER := Color("ffa83a")
const PALE := Color("fff0b8")
const DEEP := Color("7a4a10")
## Seconds the dart takes down the whole chain (the hits all land at the release).
const RUN := 0.26
const HOP := 7.0


## The chain the hit follows (hero.gd / companion.gd): the target, then the nearest
## living foe within HOP metres of the last, never one twice.
static func _chain(c: Dictionary) -> Array:
	var out: Array = []
	var current := B.mob_at(c.parent, c.center)
	var tree := (c.parent as Node).get_tree()
	for i in int((c.skill as Dictionary).get("hits", 6)):
		if current == null:
			break
		out.append(current)
		var next: Mob = null
		var best := HOP
		for node in tree.get_nodes_in_group("mobs"):
			var other := node as Mob
			if other and not other.is_dead() and not out.has(other):
				var d := (other.global_position - current.global_position).length()
				if d < best:
					best = d
					next = other
		current = next
	return out


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := B.windup(parent, skill, origin, aim, visual)
	var t := maxf(0.12, duration)
	var art := B.open(c, B.ground(origin), t + 0.05, "Windup")
	if art == null:
		return false
	var reach := clampf(B.flat(aim - origin).length(), 1.5, 9.0)
	B.light(art, B.streak("pierce_sight", 0.12, B.a(GOLD, 0.8), B.a(PALE, 0.95)), "PierceSight", Vector3(0, 1.05, 0.5), Vector3(1, 1, reach), t + 0.05, {"sweep": t * 0.8, "soft": 1.0, "hot": B.hot(GOLD), "add": 0.6}, {"fade_in": 0.1, "decay": 0.9})
	B.light(art, B.hoop("pierce_hoop", B.a(GOLD, 1.0), 0.18), "PierceHoop", Vector3(0, 1.05, 0.7), Vector3.ONE * 0.35, t + 0.05, {"soft": 1.0, "hot": B.hot(PALE), "add": 0.7}, {"initial": 3.0, "grow_time": 0.95, "fade_in": 0.15, "decay": 0.95})
	B.bits(art, B.gather("pierce_gather", "ember", 14, 1.4, 4.0, 0.5, [GOLD, PALE, AMBER], 0.11, 81, 0.7, 1.5), "PierceGather", Vector3(0, 0, 0.4), t + 0.05, {"life": t * 0.9, "gravity": 0.0, "drag": 1.0, "piece": 0.11, "add": 0.8, "shrink": 0.4})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := B.cast(parent, skill, origin, center)
	var chain := _chain(c)
	var start := B.hand(c)
	var points: Array[Vector3] = [start]
	for mob in chain:
		points.append((mob as Mob).global_position + Vector3.UP * 1.0)
	if points.size() < 2:
		points.append(start + (c.fwd as Vector3) * 4.0)
	var at := B.ground(origin)
	var art := B.open(c, at, RUN + 1.2, "Chain")
	if art == null:
		return false
	art.rotation = Vector3.ZERO
	# The path, resampled by length so the sweep runs at one speed; the arrival time of each hop.
	var total := 0.0
	var marks: Array[float] = [0.0]
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
		marks.append(total)
	var path := PackedVector3Array()
	for i in range(1, points.size()):
		var steps := maxi(2, int(points[i].distance_to(points[i - 1]) / 0.4))
		for k in steps:
			path.append(points[i - 1].lerp(points[i], float(k) / float(steps)) - at)
	path.append(points[points.size() - 1] - at)
	var dart := B._st()
	K.ribbon(dart, path, 1.0, B.a(GOLD, 0.97), 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0)
	for i in range(1, points.size()):
		var dir := (points[i] - points[i - 1]).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		K.ribbon(dart, PackedVector3Array([points[i - 1] - at, points[i] - at]), 0.6, B.a(PALE, 0.95), 0.0, 0.0, side, 0.0, marks[i - 1] / total, marks[i] / total)
	B.light(art, K.finish(dart, Vector3.ONE * 0.5, false), "PierceDart", Vector3.ZERO, Vector3.ONE, RUN + 0.5, {"sweep": RUN, "tail": 0.9, "soft": 0.7, "hot": B.hot(PALE), "core": 0.4, "add": 0.75, "gain": 1.15}, {"fade_in": 0.01, "decay": 0.8})
	# What it leaves at each foe: a sword run through, a flare, a ring round the blade, sparks.
	var flares := B._st()
	var swords := K.begin()
	var spray := B._st()
	var ground := B._st()
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	var blade := B.sword(Color("e8d8a8"), GOLD, PALE, Color("6a3a1a"), 0.1)
	for i in range(1, points.size()):
		var when := RUN * marks[i] / total
		var dir := (points[i] - points[i - 1]).normalized()
		var p := points[i] - at
		K.disc(flares, 1.4, B.a(GOLD, 0.95), 0.0, 16, when, dir, p, B.a(AMBER, 0.0), -1.0)
		var ring := PackedVector3Array()
		var u := dir.cross(Vector3.UP).normalized()
		var w := dir.cross(u)
		for k in 25:
			var ang := TAU * float(k) / 24.0
			ring.append(p + (u * cos(ang) + w * sin(ang)) * 1.0)
		K.ribbon(flares, ring, 0.2, B.a(PALE, 1.0), when, 0.0, dir, 0.0)
		# The sword, run through along the hop and out the other side.
		var basis := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
		K.stamp(swords, blade, Transform3D(basis.scaled(Vector3.ONE * 2.4), p - dir * 0.9), when, 0.0)
		K.burst_at(spray, rng, "ember", 7, p - Vector3.UP * 0.6, 0.1, 0.4, 3.5, 3.0, [GOLD, PALE, AMBER], 0.13, when, 0.03, 0.4, 1.0)
		K.ribbon(ground, PackedVector3Array([B.ground(points[i - 1]) - at + Vector3.UP * 0.06, B.ground(points[i]) - at + Vector3.UP * 0.06]), 0.55, B.a(GOLD, 0.85), 0.0, 0.0, Vector3.UP, 0.0, marks[i - 1] / total, marks[i] / total)
	B.light(art, K.finish(flares, Vector3.ONE * 0.5, false), "PierceFlares", Vector3.ZERO, Vector3.ONE, RUN + 0.5, {"soft": 0.8, "hot": B.hot(PALE), "add": 0.7, "flash": 0.32}, {"fade_in": 0.01, "decay": 0.85})
	B.body(art, K.finish(swords, Vector3.ONE), "PierceSwords", Vector3.ZERO, Vector3.ONE, RUN + 0.75, {"rim_color": PALE, "rim": 0.7, "glow_color": GOLD, "heat": 0.8}, {"fade_in": 0.01, "decay": 0.55})
	B.bits(art, K.finish(spray, Vector3.ONE * 8.0, false), "PierceSpray", Vector3.ZERO, RUN + 0.9, {"life": 0.6, "gravity": 7.0, "drag": 1.5, "piece": 0.13, "add": 0.75, "shrink": 0.3})
	B.light(art, K.finish(ground, Vector3.ONE * 0.5, false), "PierceLine", Vector3.ZERO, Vector3.ONE, RUN + 1.15, {"sweep": RUN, "soft": 0.6, "hot": B.hot(GOLD, 0.7), "add": 0.5}, {"fade_in": 0.01, "decay": 0.6})
	return true
