extends Node3D
## Every field boss has a signature move set; each stays telegraphed, locked and dodgeable.
var checks := 0
var failures := 0

const BOSSES := [&"mush_king", &"fire_dragon", &"sand_dragon", &"yeti_king", &"magma_dragon", &"bone_lord",
	&"toad_king", &"storm_dragon", &"gold_dragon", &"abyss_dragon", &"void_emperor"]

class Victim:
	extends Node3D
	var hits := 0
	var damage := 0.0
	var slowed := 0.0
	func is_dead() -> bool: return false
	func take_damage(amount: float, _source: Node) -> void:
		hits += 1
		damage += amount
	func apply_slow(seconds: float) -> void: slowed = maxf(slowed, seconds)

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
	actor.is_boss = true
	add_child(actor)
	return actor

func begin(actor: Actor) -> BossAttack:
	actor._winding = false
	BossAttack.start(actor)
	var attack := actor.get_child(actor.get_child_count() - 1) as BossAttack
	attack.set_process(false)
	return attack

## The 5 m the hero can cover in the shortest warning must contain a spot no circle reaches.
func has_safe_spot(shots: Array[Dictionary], from: Vector3) -> bool:
	for ix in range(-10, 11):
		for iz in range(-10, 11):
			var p := from + Vector3(ix, 0, iz) * 0.5
			if (p - from).length() > 5.0:
				continue
			var covered := false
			for shot in shots:
				if (p - shot.pos).length() <= float(shot.r) + 0.4:
					covered = true
					break
			if not covered:
				return true
	return false

func run_move(id: StringName, move: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var forward := Vector3.RIGHT
	var origin := Vector3.ZERO
	for hero_dist in [3.0, 7.0]:
		var hero_pos: Vector3 = forward * hero_dist
		var shots := BossAttack.plan(move, origin, forward, hero_pos, forward * 4.0, rng)
		var tag := "%s/%s@%.0f" % [id, move, hero_dist]
		check(shots.size() >= 3 and shots.size() <= 12, tag + ": 3..12 circles (VFX budget)")
		var earliest := 99.0
		var worst := 0.0
		for shot in shots:
			earliest = minf(earliest, float(shot.at))
			worst = maxf(worst, float(shot.dmg))
		check(earliest >= 0.9, tag + ": at least 0.9 s of visible warning")
		check(worst <= 1.6, tag + ": single hit stays within slam-scale damage")
		check(has_safe_spot(shots, hero_pos), tag + ": a safe spot within 5 m of the hero")
	check(BossAttack.MOVES.has(move), move + " is registered")

func _ready() -> void:
	Game.set_process(false)
	for id in BOSSES:
		var template := MonsterData.get_monster(id)
		check(bool(template.get("boss", false)), "%s is a boss" % id)
		check(BossAttack.has_moves(template), "%s has a signature move" % id)
		var second := String(template.get("behavior2", ""))
		check(BossAttack.MOVES.has(second) and second != String(template.behavior), "%s has a distinct phase-2 move" % id)
		run_move(id, String(template.behavior))
		run_move(id, second)
	var names := {}
	for id in BOSSES:
		names[MonsterData.get_monster(id).behavior] = true
		names[MonsterData.get_monster(id).behavior2] = true
	check(names.size() == 22, "22 distinct moves across 11 bosses")
	# Every field-zone boss is covered.
	ZoneData.ensure()
	for zone_id in ZoneData.ZONES:
		var zone: Dictionary = ZoneData.ZONES[zone_id]
		if zone.has("boss") and MonsterData.MONSTERS.has(zone.boss.monster):
			check(BossAttack.has_moves(MonsterData.MONSTERS[zone.boss.monster]), "field boss %s has moves" % zone.boss.monster)
	await run_runtime()
	Game.has_profile = false
	print("BOSS ATTACK: ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)

func run_runtime() -> void:
	var target := Victim.new()
	add_child(target)
	for id in BOSSES:
		var actor := make_actor(id, target)
		actor.position = Vector3.ZERO
		for move in [String(actor.template.behavior), String(actor.template.behavior2)]:
			actor.template = actor.template.duplicate()
			actor.template["behavior"] = move
			actor.template["behavior2"] = ""
			# A hero who runs away from the locked warnings is never hit.
			target.position = Vector3(5, 0, 0)
			target.hits = 0
			var attack := begin(actor)
			check(actor._winding and attack.shots.size() > 0, "%s/%s locks the boss while warning" % [id, move])
			var locked: Array = attack.shots.map(func(s): return s.pos)
			target.position = Vector3(60, 0, 60)
			for step in 40:
				attack._process(0.1)
			check(attack.shots.map(func(s): return s.pos) == locked, "%s/%s warnings never follow the player" % [id, move])
			check(target.hits == 0, "%s/%s leaving the warnings avoids all damage" % [id, move])
			await get_tree().process_frame
			check(not actor._winding, "%s/%s releases the boss after the move" % [id, move])
			# A hero who stands in the first circle takes bounded damage.
			target.hits = 0
			target.damage = 0.0
			target.slowed = 0.0
			attack = begin(actor)
			target.position = attack.shots[0].pos
			for step in 60:
				attack._process(0.1)
			check(target.hits >= 1, "%s/%s hits a hero who ignores the warning" % [id, move])
			check(target.damage <= float(actor.stats.atk) * (BossAttack.MAX_HITS * 1.6 + 10.0 * BossAttack.PUDDLE_DAMAGE), "%s/%s total damage is bounded (%.0f)" % [id, move, target.damage])
			if float(BossAttack.MOVES[move].slow) > 0.0:
				check(target.slowed > 0.0, "%s/%s slows the victim" % [id, move])
			await get_tree().process_frame
			# Stun cancels what has not landed yet.
			target.hits = 0
			attack = begin(actor)
			target.position = attack.shots[0].pos
			actor._stun = 1.0
			attack._process(0.1)
			await get_tree().process_frame
			actor._stun = 0.0
			check(target.hits == 0 and not actor._winding, "%s/%s stun cancels pending shots" % [id, move])
			# Death cancels everything, warnings are freed.
			attack = begin(actor)
			actor._dead = true
			attack._process(0.1)
			await get_tree().process_frame
			actor._dead = false
			check(target.hits == 0, "%s/%s death cancels pending damage" % [id, move])
		actor.free()
		await get_tree().process_frame
	check(find_children("BossEnemyWarnings", "Node3D", true, false).is_empty(), "warning nodes are released")
	# Dispatch + phase alternation through the real Mob entry points.
	var boss := make_actor(&"magma_dragon", target)
	check(BossAttack.pick(boss) == "lava_lines", "phase 0 uses the base move")
	boss.phase = 2
	var picks: Array[String] = []
	for i in 4:
		picks.append(BossAttack.pick(boss))
	check(picks == ["magma_geysers", "lava_lines", "magma_geysers", "lava_lines"], "phase 2 alternates the enraged move")
	target.position = Vector3(4, 0, 0)
	boss.phase = 0
	boss._winding = false
	boss._begin_slam()
	check(boss.get_children().any(func(n): return n is BossAttack) and boss._winding, "_begin_slam dispatches to BossAttack")
	check(boss._slam_timer == Mob.SLAM_INTERVAL, "phase 0-1 keeps the 8 s slam rhythm")
	boss.free()
	# A boss without a behavior keeps the generic slam.
	var plain := make_actor(&"pink_slime", target)
	check(not BossAttack.has_moves(plain.template), "plain monsters have no boss moves")
	plain.free()
	await get_tree().process_frame
