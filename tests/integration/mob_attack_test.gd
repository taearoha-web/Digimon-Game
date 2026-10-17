extends Node3D
## Ordinary monsters have telegraphed, locked, dodgeable moves, capped for the VFX budget.
var checks := 0
var failures := 0

class Victim:
	extends Node3D
	var hits := 0
	var damage := 0.0
	func is_dead() -> bool: return false
	func take_damage(amount: float, _source: Node) -> void:
		hits += 1
		damage += amount

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

func make_actor(id: StringName, target: Victim) -> Actor:
	var actor := Actor.new()
	actor.monster_id = id
	actor.template = MonsterData.get_monster(id)
	actor.stats = {"atk": 100}
	actor.hero = target
	actor._victim = target
	add_child(actor)
	return actor

func begin(actor: Actor) -> MobAttack:
	actor._winding = false
	check(MobAttack.launch(actor), "%s launches" % actor.monster_id)
	var attack := actor.get_child(actor.get_child_count() - 1) as MobAttack
	attack.set_process(false)
	return attack

func _ready() -> void:
	Game.set_process(false)
	var moves := {}
	for id in MonsterData.MONSTERS:
		var template: Dictionary = MonsterData.MONSTERS[id]
		if bool(template.get("boss", false)):
			continue
		check(MobAttack.knows(template), "%s has a normal-monster move" % id)
		moves[String(template.get("behavior", ""))] = true
	check(moves.size() == MobAttack.MOB_MOVES.size(), "all %d moves are used" % MobAttack.MOB_MOVES.size())
	# Bosses keep their own system.
	check(not MobAttack.knows(MonsterData.MONSTERS[&"mush_king"]), "bosses use BossAttack, not MobAttack")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for move in MobAttack.MOB_MOVES:
		for dist in [1.5, 4.0, 7.0]:
			var shots := MobAttack.mob_plan(move, Vector3.ZERO, Vector3.RIGHT, Vector3.RIGHT * dist, rng)
			var tag := "%s@%.1f" % [move, dist]
			check(shots.size() >= 1 and shots.size() <= 3, tag + ": 1..3 circles")
			for shot in shots:
				check(float(shot.at) >= 0.7, tag + ": at least 0.7 s warning")
				check(float(shot.dmg) <= 1.5, tag + ": hit stays near a basic attack")
	await run_runtime()
	Game.has_profile = false
	print("MOB ATTACK: ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)

func run_runtime() -> void:
	var target := Victim.new()
	add_child(target)
	for move in MobAttack.MOB_MOVES:
		var actor := make_actor(&"pink_slime", target)
		actor.template = actor.template.duplicate()
		actor.template["behavior"] = move
		target.position = Vector3(3, 0, 0)
		target.hits = 0
		var attack := begin(actor)
		check(actor._winding and MobAttack.active_count() >= 1, "%s locks the monster and counts toward the cap" % move)
		var locked: Array = attack.shots.map(func(s): return s.pos)
		target.position = Vector3(60, 0, 60)
		for step in 30:
			attack._process(0.1)
		check(attack.shots.map(func(s): return s.pos) == locked, "%s warnings never follow the player" % move)
		check(target.hits == 0, "%s: running away avoids all damage" % move)
		await get_tree().process_frame
		check(not actor._winding, "%s releases the monster" % move)
		# Standing in the warning is punished, once or twice at most, never more than 1.5x per hit.
		target.hits = 0
		target.damage = 0.0
		attack = begin(actor)
		target.position = attack.shots[0].pos
		for step in 30:
			attack._process(0.1)
		check(target.hits >= 1 and target.hits <= BossAttack.MAX_HITS, "%s hits a hero who ignores it (%d)" % [move, target.hits])
		check(target.damage <= 100.0 * 1.5 * BossAttack.MAX_HITS, "%s damage is bounded" % move)
		await get_tree().process_frame
		# Stun and death cancel.
		target.hits = 0
		attack = begin(actor)
		target.position = attack.shots[0].pos
		actor._stun = 1.0
		attack._process(0.1)
		await get_tree().process_frame
		actor._stun = 0.0
		check(target.hits == 0 and not actor._winding, "%s: stun cancels" % move)
		attack = begin(actor)
		actor._dead = true
		attack._process(0.1)
		await get_tree().process_frame
		actor._dead = false
		check(target.hits == 0, "%s: death cancels" % move)
		actor.free()
		await get_tree().process_frame
	check(MobAttack.active_count() == 0, "the active counter returns to zero")
	check(find_children("BossEnemyWarnings", "Node3D", true, false).is_empty(), "warning nodes are released")
	# Lunge actually travels to the locked spot.
	var dasher := make_actor(&"sand_wolf", target)
	target.position = Vector3(5, 0, 0)
	var lunge := begin(dasher)
	for step in 20:
		lunge._process(0.05)
	check(dasher.global_position.x > 3.0, "lunge moves the monster toward the locked circle (%.1f)" % dasher.global_position.x)
	await get_tree().process_frame
	dasher.free()
	# The cap: over the limit a monster falls back to its basic attack.
	var crowd: Array[Actor] = []
	var limit := int(MobAttack.ACTIVE_LIMIT[VfxBudget.quality()])
	for i in limit + 2:
		var m := make_actor(&"forest_orc", target)
		m.position = Vector3(40 + i * 3, 0, 0)
		crowd.append(m)
		MobAttack.launch(m)
	check(MobAttack.active_count() == limit, "no more than %d moves at once (%d)" % [limit, MobAttack.active_count()])
	check(not crowd.back().get_children().any(func(n): return n is MobAttack), "monsters over the cap start no move")
	for m in crowd:
		m.free()
	await get_tree().process_frame
	check(MobAttack.active_count() == 0, "cap frees up when monsters die")
	target.free()
