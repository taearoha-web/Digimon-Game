extends Node3D
## Every ordinary and elite monster of the star regions (★1-200) and of the lotus
## sanctum (★200) has a real signature move of its own (StarMoves / MonsterMove):
## every behaviour they use is implemented and drawn in its own shape, the warning
## comes before the blow and never follows the player, the online cast carries
## circles that cover each shape, the damage stays in the old band, elites hit
## with a bigger version, and stun / death cancel cleanly.
## godot --headless --path . res://tests/integration/star_moves_test.tscn
var checks := 0
var failures := 0

class Victim:
	extends Node3D
	var hits := 0
	var damage := 0.0
	var slowed := 0.0
	func is_dead() -> bool: return false
	func take_damage(amount: float, _source: Node) -> void:
		hits += 1
		damage += amount
	func apply_slow(seconds: float) -> void:
		slowed = maxf(slowed, seconds)

class Actor:
	extends Mob
	func _ready() -> void:
		visual = MonsterVisual.new()
		add_child(visual)
		set_physics_process(false)

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)

func template_of(id: StringName) -> Dictionary:
	return StarMonsters.get_monster(id) if StarMonsters.has(id) else DivineRegionData.monster(id)

func roster() -> Array:
	var out: Array = []
	for list in [StarMonsters.MONSTERS, DivineRegionData.MONSTERS]:
		for id in list:
			if not bool(list[id].get("boss", false)):
				out.append(id)
	return out

func hero_spot(template: Dictionary) -> Vector3:
	# Where the monster starts its attack: ranged ones from 6 m, melee ones within their reach
	# (Mob._chase: 1.5 + 1.2 x body radius).
	var body := clampf(float(template.height) * 0.3, 0.35, 1.2)
	return Vector3(0, 0, 6.0 if String(template.attack) == "ranged" else (1.5 + body * 1.2) * 0.9)

func make_actor(id: StringName, target: Victim) -> Actor:
	var actor := Actor.new()
	actor.monster_id = id
	actor.template = template_of(id)
	actor.stats = {"atk": 100}
	actor.hero = target
	actor._victim = target
	add_child(actor)
	actor.global_position = Vector3.ZERO
	return actor

## Starts the monster's attack the way Mob._begin_attack does.
func begin(actor: Actor) -> MonsterMove:
	actor._winding = false
	if DivineRegionData.has_monster(actor.monster_id):
		DivineAttack.start(actor)
	else:
		StarAttack.start(actor)
	var move: MonsterMove = null
	for child in actor.get_children():
		if child is MonsterMove and not child.is_queued_for_deletion():
			move = child
	if move != null:
		move.set_process(false)
	return move

func run(move: MonsterMove, until: float) -> void:
	while is_instance_valid(move) and not move.is_queued_for_deletion() and move.age < until:
		move._process(0.05)

func shape_sig(p: Dictionary) -> String:
	var bits: Array = []
	for part in p.parts:
		bits.append("%s:%s:%d" % [part.shape, part.fx, int(part.wave)])
	bits.sort()
	return ",".join(bits) + ("|dash" if p.has("dash") else "") + ("|leap" if p.has("leap") else "") + ("|shot" if not (p.get("shots", []) as Array).is_empty() else "")

func plan_for(template: Dictionary, rng_seed := 7) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var h := hero_spot(template)
	return StarMoves.plan(String(template.behavior), bool(template.get("elite", false)), Vector3.ZERO, h.normalized(), h, clampf(float(template.height) * 0.3, 0.35, 1.2), rng)

func _ready() -> void:
	Game.set_process(false)
	GameSettings.quality = 2
	_survey()
	_plans()
	_elites()
	await _live()
	await _sync()
	print("STAR MOVES: ", checks, " checks, ", failures, " failures")
	if failures == 0:
		print("PASS")
	get_tree().quit(failures)

## Every behaviour a normal / elite uses has its own move, in a shape of its own.
func _survey() -> void:
	var used := StarMoves.used()
	var sigs := {}
	for move in used:
		check(StarMoves.MOVES.has(move), "%s (used by %s) is implemented" % [move, used[move]])
		var normal_plan := {}
		for id in used[move]:
			var t := template_of(id)
			check(StarMoves.knows(t), "%s knows its move %s" % [id, move])
			if normal_plan.is_empty() or not bool(t.get("elite", false)):
				normal_plan = plan_for(t)
		var sig := shape_sig(normal_plan)
		check(not sigs.has(sig), "%s has a move of its own (%s; same as %s)" % [move, sig, sigs.get(sig, "-")])
		sigs[sig] = move
	for move in ["headbutt", "pollen", "ice_bolt", "wind_bolt", "void_bolt", "lotus_bolt", "divine_slam"]:
		check(used.has(move), "%s is still a monster's behaviour" % move)
	var lotus := [String(DivineRegionData.MONSTERS[&"jade_qilin"].behavior), String(DivineRegionData.MONSTERS[&"lotus_frog"].behavior), String(DivineRegionData.MONSTERS[&"jade_monk"].behavior)]
	check(lotus[0] != lotus[1] and lotus[1] != lotus[2] and lotus[0] != lotus[2], "the jade dragon, the golden frog and the jade monk each have their own move %s" % [lotus])
	var shapes := {}
	for move in StarMoves.MOVES:
		for id in used.get(move, []):
			for part in plan_for(template_of(id)).parts:
				shapes[part.shape] = true
	check(shapes.size() == 4, "warnings come as circles, cones, lanes and rings (%s)" % [shapes.keys()])
	# The kings and the queen keep their own moves.
	for id in [&"dawn_ancient_stag", &"crystal_horn_king", &"sky_celestial_king", &"eclipse_sovereign"]:
		check(not StarMoves.knows(StarMonsters.MONSTERS[id]), "%s keeps its boss moves" % id)
	check(not StarMoves.knows(DivineRegionData.MONSTERS[&"lotus_seraph"]), "the lotus queen keeps her boss moves")

## Warnings, damage band and the online cover, from every monster's own plan.
func _plans() -> void:
	for id in roster():
		var t := template_of(id)
		var elite := bool(t.get("elite", false))
		for s in 3:
			var p := plan_for(t, 11 + s)
			var tag := "%s/%s" % [id, t.behavior]
			check(not p.parts.is_empty() and p.parts.size() <= 6, tag + ": 1..6 warned areas")
			var earliest := 99.0
			for part in p.parts:
				earliest = minf(earliest, float(part.at))
				check(float(part.dmg) <= StarMoves.FIRST_HIT + 0.001, tag + ": one blow stays a basic attack")
				check(float(part.get("tick", 0.0)) <= 0.15, tag + ": hazard ticks are small")
			check(earliest >= (StarMoves.ELITE_WARN if elite else StarMoves.NORMAL_WARN) - 0.001, tag + ": %.2f s of warning first" % earliest)
			var worst := StarMoves.worst_damage(p)
			check(worst >= 0.85 and worst <= (StarMoves.ELITE_TOTAL if elite else StarMoves.NORMAL_TOTAL), tag + ": damage in band (%.2f)" % worst)
			var circles := StarMoves.sync_circles(p.parts)
			check(circles.size() >= p.parts.size() and circles.size() <= 12, tag + ": %d cast circles" % circles.size())
			for part in p.parts:
				var miss := 0
				for x in range(-12, 13):
					for z in range(-6, 19):
						var q := Vector3(x * 0.5, 0, z * 0.5)
						if not StarMoves.inside(part, q):
							continue
						var covered := false
						for c in circles:
							if absf(float(c[2]) - float(part.at)) < 0.001 and ((c[0] as Vector3) - q).length() <= float(c[1]) + 0.05:
								covered = true
								break
						if not covered:
							miss += 1
				check(miss == 0, tag + ": the cast covers the %s (%d points out)" % [part.shape, miss])
			for shot in p.get("shots", []):
				check(float(shot.t1) > float(shot.t0) and float(shot.t0) >= 0.3, tag + ": the projectile flies visibly")

## Elites hit with a bigger version (or an extra phase) of the move.
func _elites() -> void:
	var used := StarMoves.used()
	for move in used:
		var normals: Array = used[move].filter(func(id): return not bool(template_of(id).get("elite", false)))
		for id in used[move]:
			var t := template_of(id)
			if not bool(t.get("elite", false)):
				continue
			var p := plan_for(t)
			var waves := {}
			for part in p.parts:
				waves[int(part.wave)] = true
			check(waves.size() >= 2, "%s: the elite move has a second phase" % id)
			check(StarMoves.ELITE_TH.has(move) or normals.is_empty(), "%s: the elite version is named" % id)
			if normals.is_empty():
				check(StarMoves.worst_damage(p) > 1.0, "%s: an elite-only move hits harder than a normal's" % id)
				continue
			var base := plan_for(template_of(normals[0]))
			check(StarMoves.area(p) > StarMoves.area(base) * 1.2, "%s covers more ground than %s (%.0f vs %.0f m2)" % [id, normals[0], StarMoves.area(p), StarMoves.area(base)])
			check(StarMoves.worst_damage(p) > StarMoves.worst_damage(base), "%s hits harder than %s" % [id, normals[0]])

## The real thing on a live monster: warned before the blow, dodgeable, bounded, cancelled.
func _live() -> void:
	for id in roster():
		var target := Victim.new()
		add_child(target)
		var actor := make_actor(id, target)
		var t: Dictionary = actor.template
		var tag := "%s/%s" % [id, t.behavior]
		target.global_position = hero_spot(t)
		var move := begin(actor)
		check(move != null, tag + ": the attack runs the monster's own move")
		if move == null:
			actor.queue_free()
			target.queue_free()
			continue
		check(actor._winding, tag + ": the monster is busy with its move")
		var warns := find_children("*", "Node3D", true, false).filter(func(n): return n is MoveFx.Warn)
		check(warns.size() == move.parts.size(), tag + ": every area is drawn when the move starts (%d/%d)" % [warns.size(), move.parts.size()])
		check(not move.sync_circles.is_empty(), tag + ": the move has its online cast")
		var locked: Array = move.parts.map(func(p): return p.pos)
		run(move, move.first_impact - 0.06)
		check(target.hits == 0, tag + ": nothing lands during the warning")
		# Step away: the warnings stay where they were and miss.
		target.global_position = Vector3(40, 0, 40)
		run(move, 9.0)
		check(move.parts.map(func(p): return p.pos) == locked, tag + ": warnings never follow the player")
		check(target.hits == 0, tag + ": leaving the warning avoids every blow")
		check(not actor._winding, tag + ": the monster is free again")
		await get_tree().process_frame
		# Stand still in it.
		actor.global_position = Vector3.ZERO
		target.global_position = hero_spot(t)
		move = begin(actor)
		var worst := StarMoves.worst_damage(move.plan)
		run(move, 9.0)
		check(target.hits >= 1 and target.hits <= StarMoves.MAX_HITS + 4, tag + ": standing in it gets hit (%d)" % target.hits)
		check(target.damage <= 100.0 * worst + 0.5, tag + ": damage bounded (%.0f <= %.0f)" % [target.damage, 100.0 * worst])
		if move.parts.any(func(p): return float(p.get("slow", 0.0)) > 0.0 and StarMoves.inside(p, hero_spot(t))):
			check(target.slowed > 0.0, tag + ": the move slows")
		await get_tree().process_frame
		# Stun and death cancel what has not landed.
		target.hits = 0
		actor.global_position = Vector3.ZERO
		move = begin(actor)
		actor._stun = 1.0
		move._process(0.05)
		await get_tree().process_frame
		check(target.hits == 0 and not actor._winding and not is_instance_valid(move), tag + ": stun cancels")
		actor._stun = 0.0
		move = begin(actor)
		actor._dead = true
		move._process(0.05)
		await get_tree().process_frame
		check(target.hits == 0 and not actor._winding, tag + ": death cancels")
		check(is_equal_approx(actor.visual.position.y, 0.0), tag + ": a leap puts the monster back on the ground")
		actor.queue_free()
		target.queue_free()
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout
	check(find_children("StarMoveWarnings", "Node3D", true, false).is_empty(), "warning nodes are released")
	check(find_children("MoveHazard", "Node3D", true, false).is_empty(), "hazards fade away")

## A hosted move goes out to the party as an ent_event cast.
func _sync() -> void:
	var host := EntitySync.new()
	host.mode = EntitySync.HOST
	host._members = {"p2": true}
	host._tokens = 100.0
	var before := EntitySync.current
	EntitySync.current = host
	for id in [&"sky_oracle", &"eclipse_reaper", &"jade_monk", &"temple_guardian"]:
		var target := Victim.new()
		add_child(target)
		var actor := make_actor(id, target)
		actor.set_meta("eid", 42)
		target.global_position = hero_spot(actor.template)
		host._urgent.clear()
		var move := begin(actor)
		var casts: Array = host._urgent.filter(func(f): return String(f[0]) == "ent_event" and String(f[1].ev) == "cast")
		check(casts.size() == 1, "%s: the move is cast to the party" % id)
		if casts.size() == 1:
			var c: Array = casts[0][1].data.c
			check(c.size() == move.sync_circles.size() and c.size() >= move.parts.size(), "%s: with its %d cover circles" % [id, c.size()])
			if bool(actor.template.get("elite", false)):
				check(String(casts[0][1].data.get("n", "")) == StarMoves.title(actor.template), "%s: and the elite move's name" % id)
		move.queue_free()
		actor.queue_free()
		target.queue_free()
		await get_tree().process_frame
	EntitySync.current = before
	host.free()
