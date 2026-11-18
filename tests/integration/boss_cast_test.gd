extends Node3D
## Every boss special is cast (BossCast): a wind-up that fills the telegraph before the
## first blow, then a release, with its Thai name over the boss. For every BossAttack move
## of every field boss, Poseidon, the Dragon God and the rare prism dragon, the star kings'
## and the lotus queen's first specials, the generic slam, a story boss's moves and a
## kirin's horn charge: the body is posed during the wind-up and no damage lands before
## the release; the release comes at the move's own first impact (timings unchanged); the
## boss is back at rest afterwards (no tilt, no scale, the clip not frozen, not winding,
## no cast left); a stun mid-wind-up snaps it back; a mirror replays the same cast from
## the cast event.
##   godot --headless --path . res://tests/integration/boss_cast_test.tscn
var checks := 0
var failures := 0

const BOSSES := [&"mush_king", &"fire_dragon", &"sand_dragon", &"yeti_king", &"magma_dragon", &"bone_lord",
	&"toad_king", &"storm_dragon", &"gold_dragon", &"abyss_dragon", &"void_emperor", &"tidal_tyrant", &"dragon_god", &"prism_dragon"]
const KINGS := [&"dawn_ancient_stag", &"crystal_horn_king", &"sky_celestial_king", &"eclipse_sovereign", &"lotus_seraph"]

class Victim:
	extends Node3D
	var hits := 0
	var first_hit_ms := -1
	func is_dead() -> bool: return false
	func take_damage(_amount: float, _source: Node) -> void:
		hits += 1
		if first_hit_ms < 0:
			first_hit_ms = Time.get_ticks_msec()
	func apply_slow(_s: float) -> void: pass
	func apply_freeze(_s: float) -> void: pass


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func make_boss(id: StringName, victim: Victim, at := Vector3.ZERO) -> Mob:
	var mob := Mob.new()
	mob.setup(id, 60, at, victim)
	mob.position = at
	mob.is_boss = true
	add_child(mob)
	mob.set_physics_process(false)
	mob.visual.scale = Vector3.ONE
	mob._victim = victim
	mob.hostile = true
	# Past its spawn pop (the visual grows in over 0.4 s).
	await get_tree().create_timer(0.5).timeout
	mob.visual.scale = Vector3.ONE
	return mob


## How far the body is from its rest pose (the node's tilt, lift and scale, plus the
## shader poses of the eastern dragons and the kirin).
func pose_offset(v: MonsterVisual) -> float:
	var off := absf(v.rotation.x) + absf(v.position.y) + (v.scale - Vector3.ONE).length()
	var mat: ShaderMaterial = v.get("mat") as ShaderMaterial if v.get("mat") is ShaderMaterial else null
	if mat != null:
		for key in ["reach", "rise", "rear", "head_pitch", "lunge"]:
			var value: Variant = mat.get_shader_parameter(key)
			if value is float:
				off += absf(float(value))
	return off


func at_rest(mob: Mob) -> bool:
	var v := mob.visual
	var frozen := v.anim != null and v.anim.speed_scale <= 0.01
	return not v.casting and absf(v.rotation.x) < 0.001 and absf(v.position.y) < 0.001 and v.scale.is_equal_approx(Vector3.ONE) \
		and Vector2(v.position.x, v.position.z).length() < 0.001 and not frozen and BossCast.of(mob) == null


## Waits until [param cond] holds (or [param limit] seconds of game time pass).
func wait_for(cond: Callable, limit: float) -> bool:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


## Runs one cast started by [param starter] to its end and checks it.
func run_cast(mob: Mob, victim: Victim, label: String, starter: Callable, expect_title := true) -> void:
	victim.hits = 0
	victim.first_hit_ms = -1
	mob._winding = false
	mob._stun = 0.0
	starter.call()
	var cast := BossCast.of(mob)
	check(cast != null, "%s: the special is cast" % label)
	if cast == null:
		return
	var windup := cast.windup
	var start_ms := Time.get_ticks_msec()
	check(mob.visual.casting, "%s: the body is winding up" % label)
	check(not expect_title or cast.title != "", "%s: its Thai name is shown (%s)" % [label, cast.title])
	check(cast.hold_at > 0.0 and cast.hold_at < windup, "%s: a gather then a held pause" % label)
	await wait_for(func(): return not is_instance_valid(cast) or cast.age >= cast.hold_at * 0.9, 6.0)
	if is_instance_valid(cast):
		check(pose_offset(mob.visual) > 0.05, "%s: posed at the top of the wind-up (%.3f)" % [label, pose_offset(mob.visual)])
		check(not cast.released and victim.hits == 0, "%s: nothing lands during the wind-up" % label)
		if cast._banner != null:
			check(cast._banner.text != "" and cast._banner.visible, "%s: the banner rides over the boss" % label)
	await wait_for(func(): return not is_instance_valid(cast) or cast.released, 6.0)
	var released_ms := Time.get_ticks_msec()
	check(not is_instance_valid(cast) or cast.released, "%s: released" % label)
	if is_instance_valid(cast):
		check(absf(cast.released_at - windup) < 0.1, "%s: released at the first blow (%.2f vs %.2f)" % [label, cast.released_at, windup])
	check(victim.first_hit_ms < 0 or victim.first_hit_ms >= start_ms + int(windup * 1000.0 / Engine.time_scale) - 60, "%s: the first hit comes no earlier than the release" % label)
	# The move runs out, then the body is back at rest.
	var ok := await wait_for(func(): return at_rest(mob) and not mob._winding, 8.0)
	check(ok, "%s: back at rest afterwards (casting %s, tilt %.3f, lift %.3f, scale %s, winding %s, cast %s)" % [label, mob.visual.casting, mob.visual.rotation.x, mob.visual.position.y, mob.visual.scale, mob._winding, BossCast.of(mob)])
	check(released_ms >= start_ms, "%s: timing sane" % label)
	for child in mob.get_children():
		if child is BossAttack or child is StarAttack or child is DivineAttack:
			child.free()


func _ready() -> void:
	Game.set_process(false)
	GameSettings.quality = 1
	Engine.time_scale = 3.0
	var victim := Victim.new()
	add_child(victim)
	victim.position = Vector3(5, 0, 0)

	# Every BossAttack move of every boss that has them, and its timings untouched.
	for id in BOSSES:
		var mob: Mob = await make_boss(id, victim)
		var moves: Array[String] = [String(mob.template.behavior)]
		if BossAttack.MOVES.has(String(mob.template.get("behavior2", ""))):
			moves.append(String(mob.template.behavior2))
		for move in moves:
			check(BossCast.LOOKS.has(move), "%s has its own cast look" % move)
			await run_cast(mob, victim, "%s %s" % [id, move], func():
				BossAttack.start(mob, move)
				var attack := mob.get_children().filter(func(n): return n is BossAttack).back() as BossAttack
				var first := 99.0
				for shot in attack.shots:
					first = minf(first, float(shot.at))
				var cast := BossCast.of(mob)
				check(cast != null and is_equal_approx(cast.windup, maxf(first, BossCast.MIN_WINDUP)), "%s: the wind-up is the move's own time to its first blow (%.2f)" % [move, first])
				check(cast != null and cast.get_parent() == attack, "%s: the cast belongs to the move (ends with it)" % move)
			)
		mob.queue_free()
		await get_tree().process_frame

	# The star kings' and the lotus queen's first specials (StarAttack / DivineAttack).
	for id in KINGS:
		var mob: Mob = await make_boss(id, victim)
		mob._boss_moves = 0
		await run_cast(mob, victim, "%s first special" % id, func():
			mob._begin_slam()
			var cast := BossCast.of(mob)
			var move := cast.get_parent() if cast != null else null
			check(move is StarAttack or move is DivineAttack, "%s: cast on its own special's node" % id)
			if move != null:
				check(is_equal_approx(cast.windup, float(move.get("contact"))), "%s: wind-up = the special's contact (%.2f)" % [id, float(move.get("contact"))])
		)
		mob.queue_free()
		await get_tree().process_frame

	# The generic slam (a boss with no signature moves).
	var plain: Mob = await make_boss(&"shadow_queen", victim)
	await run_cast(plain, victim, "generic slam", func(): plain._begin_slam(), false)

	# A story boss's moves (StoryBoss, tick-driven): the cast lasts the telegraph, the
	# move's _fire releases it.
	var story := StoryBoss.new()
	story.setup(plain, self, ["nova", "lance", "rain", "veil"])
	story.set_process(false)
	plain.add_child(story)
	for kind in ["nova", "lance", "rain", "veil"]:
		plain._winding = false
		story.force_special(kind)
		var cast := BossCast.of(plain)
		check(cast != null and cast.title == StoryBoss.TITLES[kind] and is_equal_approx(cast.windup, StoryBoss.TELEGRAPH), "story %s: cast for the telegraph with its name" % kind)
		await wait_for(func(): return cast == null or not is_instance_valid(cast) or cast.age > cast.hold_at, 4.0)
		check(pose_offset(plain.visual) > 0.05 and not (is_instance_valid(cast) and cast.released), "story %s: wound up before the blow" % kind)
		story.tick(StoryBoss.TELEGRAPH)
		check(not is_instance_valid(cast) or cast.released, "story %s: _fire releases it" % kind)
		check(await wait_for(func(): return at_rest(plain), 4.0), "story %s: back at rest" % kind)
	story.queue_free()
	plain.queue_free()

	# A stun in the middle of the wind-up cancels the move and snaps the body back.
	var stunned: Mob = await make_boss(&"fire_dragon", victim)
	stunned._winding = false
	BossAttack.start(stunned, "flame_breath")
	await wait_for(func(): return BossCast.of(stunned) != null and BossCast.of(stunned).age > 0.3, 3.0)
	check(stunned.visual.casting and stunned.visual.anim != null, "stun: winding up first")
	stunned.apply_stun(2.0)
	var calm := await wait_for(func(): return at_rest(stunned), 2.0)
	check(calm and is_equal_approx(stunned.visual.anim.speed_scale, 1.0), "stun: the cast ends, the body is at rest, the clip runs again (speed %.2f)" % stunned.visual.anim.speed_scale)
	stunned.queue_free()

	# A death in the middle of the wind-up: the death clip is not left frozen.
	var dying: Mob = await make_boss(&"yeti_king", victim)
	dying._winding = false
	BossAttack.start(dying, "freeze_ring")
	await wait_for(func(): return BossCast.of(dying) != null and BossCast.of(dying).age > BossCast.of(dying).hold_at + 0.05, 3.0)
	dying._die()
	await wait_for(func(): return BossCast.of(dying) == null, 2.0)
	check(dying.visual.anim == null or dying.visual.anim.speed_scale > 0.5, "death: the death clip plays (speed %.2f)" % (dying.visual.anim.speed_scale if dying.visual.anim else 1.0))
	await get_tree().create_timer(0.3).timeout

	# A mirror (another player's game) replays the same cast from the cast event.
	for id in [&"storm_dragon", &"tidal_tyrant", &"dragon_god"]:
		var mirror := MirrorMob.new()
		var template := MonsterData.get_monster(id)
		mirror.setup_mirror(null, 900 + BOSSES.find(id), {"m": String(id), "lv": 60, "x": -6.0, "z": 0.0, "k": "field_boss", "mhp": 1000, "hp": 1000}, victim)
		add_child(mirror)
		mirror.set_physics_process(false)
		await get_tree().create_timer(0.5).timeout
		mirror.visual.scale = Vector3.ONE
		var move := String(template.behavior)
		var clip := String(BossAttack.MOVES[move].get("clip", "attack"))
		mirror.mirror_cast({"c": [[-2.0, 0.0, 2.0, 1.4]], "a": clip, "n": BossAttack.title(move), "bc": move, "w": 1.4})
		var cast := BossCast.of(mirror)
		check(cast != null and cast.key == move and is_equal_approx(cast.windup, 1.4) and cast.title == BossAttack.title(move) and cast.clip == clip, "mirror %s: the same cast (%s)" % [id, cast.key if cast else "none"])
		await wait_for(func(): return cast == null or not is_instance_valid(cast) or cast.age > cast.hold_at * 0.9, 3.0)
		check(pose_offset(mirror.visual) > 0.05, "mirror %s: wound up like the host" % id)
		await wait_for(func(): return cast == null or not is_instance_valid(cast) or cast.released, 3.0)
		check(not is_instance_valid(cast) or absf(cast.released_at - 1.4) < 0.1, "mirror %s: released on time" % id)
		check(await wait_for(func(): return at_rest(mirror), 4.0), "mirror %s: back at rest" % id)
		# An old host's event without a cast key keeps the plain flash.
		mirror.mirror_cast({"c": [[-2.0, 0.0, 2.0, 1.0]], "a": "attack"})
		check(BossCast.of(mirror) == null, "mirror %s: a plain move is not cast" % id)
		mirror.queue_free()

	# The kirin's horn charge (its shader pose) and a world boss's cast through the same path.
	var kirin: Mob = await make_boss(&"cloud_kirin", victim)
	check(kirin.visual is KirinVisual, "the kirin has its sculpted visual")
	await run_cast(kirin, victim, "kirin world stomp", func(): BossCast.begin(kirin, null, "world_stomp", 1.6, {"title": WorldBoss.TITLES.stomp}))
	kirin.queue_free()

	# Every cast key has a look; every BossAttack move a Thai name for its banner.
	for move in BossAttack.MOVES:
		check(BossCast.LOOKS.has(move) and BossCast.look(move).title == BossAttack.title(move), "%s: look and name" % move)
	for key in BossCast.EXTRA:
		check(BossCast.LOOKS.has(key), "%s: a look" % key)
	Engine.time_scale = 1.0
	await get_tree().process_frame
	print("BOSS CAST: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
