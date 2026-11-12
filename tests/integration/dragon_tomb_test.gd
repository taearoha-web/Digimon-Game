extends Node3D
## The mechanics dungeon สุสานมังกรโบราณ (DungeonData, DragonRun, DragonBoss, DragonCrystal,
## DungeonRanking, DungeonScreen): entry gating (Lv.100 ★20, a party of exactly four, two
## entries a Thai day), a party formed from online world players (a Defender and a Priest
## first), the scaling, the two packs and the boss, its three mechanics and the AI handling
## them (marked members move apart and take half alone, the Defender taunts the claw and
## takes it at a third, the Priest wards the target, the crystals are targeted and killed,
## the boss heals when they stand too long, the fallen stand at a phase change), the
## enrage, the clear paid once with the material, the weekly ranking posted once through a
## fake server and seeded so it is never empty, the exchange gear that saves, a wipe, the
## keeper's screen and the cleanup.
##   godot --headless --path . res://tests/integration/dragon_tomb_test.tscn
var checks := 0
var failures := 0
var finished_result: Dictionary = {}


## A fake server: records what is sent, answers a GET with one other leader's time and a
## POST with the stored entry.
class FakeLink:
	extends RefCounted
	var sent: Array = []
	var replies := {}
	var seq := 0
	var week := 0

	func send(method: String, path: String, body: String) -> int:
		seq += 1
		sent.append({"method": method, "path": path, "body": body})
		if method == "GET":
			replies[seq] = JSON.stringify({"status": 200, "body": JSON.stringify({"week": week, "times": [{"leader": "u:somebody", "name": "คนอื่น", "secs": 200, "classes": ["warrior", "priest", "defender", "mage"], "at": 1}], "now": 1})})
		else:
			var posted: Variant = JSON.parse_string(body)
			replies[seq] = JSON.stringify({"status": 201, "body": JSON.stringify({"stored": true, "time": posted})})
		return seq

	func poll(id: int) -> String:
		var value: Variant = replies.get(id, "")
		replies.erase(id)
		return str(value)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func _ready() -> void:
	seed(7777)
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.quality = 0
	WorldEvents.festival_enabled = false
	WorldPlayers.persist = false
	DungeonRanking.persist = false
	DungeonRanking.reset()
	Game.new_profile(&"warrior", "Tomb QA", {"gender": 0})
	Game.profile.level = 100
	Game.profile.adv = 4
	var day1 := "2026-03-02"
	var day2 := "2026-03-03"

	# --- Gating ------------------------------------------------------------------------
	check(DungeonData.entry_block(day1).contains("เลเวล 120"), "Lv.100 without the stars is turned away (%s)" % DungeonData.entry_block(day1))
	Game.paragon()["level"] = 60
	check(DungeonData.party_size() == 1 and DungeonData.entry_block(day1).contains("ครบ 4 คน"), "alone: a party of exactly four is needed (%s)" % DungeonData.entry_block(day1))
	check(DungeonData.enter(day1) != "" and DungeonData.runs_left(day1) == 2, "a refused entry spends nothing")
	var tank := WorldPlayers.first_of(&"defender")
	var healer := WorldPlayers.first_of(&"priest")
	var caster := WorldPlayers.first_of(&"mage")
	var extra := WorldPlayers.first_of(&"archer")
	check(Game.party_invite(tank, true) == "" and Game.party_invite(healer, true) == "", "a Defender and a Priest world player join")
	check(DungeonData.entry_block(day1).contains("อีก 1 คน"), "three people are still too few (%s)" % DungeonData.entry_block(day1))
	check(Game.party_invite(caster, true) == "", "a Mage joins")
	check(DungeonData.party_size() == 4 and DungeonData.entry_block(day1) == "", "four may go in (%s)" % DungeonData.entry_block(day1))
	check(DungeonData.has_class(&"defender") and DungeonData.has_class(&"priest") and not DungeonData.has_class(&"bard"), "the party's roles are read")
	check(Game.party_invite(extra, true) == "" and DungeonData.entry_block(day1).contains("พอดี"), "five are too many (%s)" % DungeonData.entry_block(day1))
	Game.party_kick(extra)
	check(DungeonData.runs_text(day1) == "เหลือ 2/2 รอบวันนี้", "the keeper shows the day's entries (%s)" % DungeonData.runs_text(day1))
	check(DungeonData.enter(day1) == "" and DungeonData.runs_left(day1) == 1 and DungeonData.open_run() != "", "the first entry is spent on the way in")
	check(DungeonData.enter(day1) == "" and DungeonData.runs_left(day1) == 0, "the second entry")
	check(DungeonData.enter(day1).contains("ครบ") and DungeonData.runs_text(day1) == "เหลือ 0/2 รอบวันนี้", "no third entry the same day")
	var spare := Game.SLOT_COUNT
	check(Game._write_profile(Game.profile.duplicate(true), spare), "a hero inside the dungeon saves")
	var reread := Game._read_slot(spare)
	check(not reread.is_empty() and String(reread.get("flags", {}).get(DungeonData.F_OPEN, "")) != "", "the dungeon's text flags survive the save")
	DirAccess.remove_absolute(Game.save_path(spare))
	check(DungeonData.runs_left(day2) == 2 and DungeonData.entry_block(day2) == "", "the next day resets the entries")

	# --- A party formed by the keeper (online world players, a Defender and a Priest first)
	Game.dismiss_party()
	var moment := _online_moment()
	check(moment > 0.0, "a moment with online Lv.100 world players of every role exists")
	if moment > 0.0:
		WorldPresence.clock_offset = moment - WorldPlayers.now()
		var joined := DungeonData.recruit()
		check(joined == 3 and DungeonData.party_size() == 4, "the keeper fills the party to four (%d joined)" % joined)
		check(DungeonData.has_class(&"defender") and DungeonData.has_class(&"priest"), "a Defender and a Priest were asked first")
		check(DungeonData.entry_block(day2) == "", "and the party may go in (%s)" % DungeonData.entry_block(day2))
		WorldPresence.clock_offset = 0.0
	Game.dismiss_party()
	for i in [tank, healer, caster]:
		Game.party_invite(i, true)

	# --- Scaling and rewards -------------------------------------------------------------
	var power := RaidData.party_power([{"level": 100, "stars": 60, "atk": 5000, "max_hp": 60000, "def": 600}, {"level": 100, "stars": 60, "atk": 4500, "max_hp": 55000, "def": 700}, {"level": 100, "stars": 60, "atk": 4800, "max_hp": 50000, "def": 500}, {"level": 100, "stars": 60, "atk": 4000, "max_hp": 70000, "def": 900}])
	var bs := DungeonData.monster_stats(power, "boss")
	var cs := DungeonData.monster_stats(power, "crystal")
	var ts := DungeonData.monster_stats(power, "trash")
	check(int(bs.hp) > int(ts.hp) * 10 and int(ts.hp) < int(bs.hp) and int(cs.hp) > 50 and int(cs.atk) == 1, "boss > pack monster; crystals never hit (%s / %s / %s)" % [bs, ts, cs])
	var dps := HeroStats.mitigate(float(power.atk_sum) * RaidData.DPS_PER_ATK, float(bs.def))
	check(absf(float(bs.hp) / (dps * DungeonData.BOSS_TTK * DungeonData.BOSS_HP_MULT) - 1.0) < 0.01, "the boss's HP follows the party's attack")
	var first := DungeonData.rewards(100, 60, true, RandomNumberGenerator.new())
	var later := DungeonData.rewards(100, 60, false, RandomNumberGenerator.new())
	check(_count_of(first.items, DungeonData.SCALE) == DungeonData.FIRST_WEEK_SCALES and _count_of(first.items, "feather") == 1, "the week's first clear drops five scales and a feather")
	var n := _count_of(later.items, DungeonData.SCALE)
	check(n >= DungeonData.SCALE_MIN and n <= DungeonData.SCALE_MAX and int(later.scales) == n, "a later clear drops 1-3 scales (%d)" % n)
	check(ItemData.name_of(ItemData.jewel(DungeonData.SCALE, 1)) == "เกล็ดมังกรโบราณ" and Game._valid_item(ItemData.jewel(DungeonData.SCALE, 3)), "the material is a known jewel the save accepts")

	# --- The exchange gear -------------------------------------------------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var charm := DungeonData.gear("charm", rng)
	var fang := DungeonData.gear("fang", rng)
	check(DungeonData.is_gear(charm) and charm.slot == "amulet" and charm["class"] == "" and int(charm.level) == 120, "the amulet is dungeon gear for any class at Lv.120")
	check(Game._valid_item(charm) and Game._valid_item(fang), "the dungeon gear passes the save's item check")
	check(Game.equip_problem(charm) == "" and Game.equip_problem(fang) == "", "a Lv.100 ★60 hero of any class may wear it (%s)" % Game.equip_problem(charm))
	Game.paragon()["level"] = 10
	check(Game.equip_problem(charm).contains("ดาว"), "below ★20 it cannot be worn")
	Game.paragon()["level"] = 60
	var drop_power := 0
	for i in 20:
		drop_power += _power(ItemData.generate(120, &"warrior", rng, 4, "amulet"))
	drop_power /= 20
	check(_power(charm) > drop_power * 1.2, "the amulet beats an average mythic field drop of its level (%d vs %d)" % [_power(charm), drop_power])
	var stall := {"lots": [{"lot": 1, "price": 100, "item": charm}], "log": [], "next": 2, "tick": 0.0}
	check(PlayerStall.valid(stall), "a stall lot of it is valid")
	var profile_copy := Game.profile.duplicate(true)
	profile_copy["inv"] = [charm, ItemData.jewel(DungeonData.SCALE, 5)]
	profile_copy["storage"] = [fang]
	check(Game._valid_profile(profile_copy), "a save holding the gear and the material is accepted")
	check(DungeonData.buy_block("charm") != "" and DungeonData.buy("charm", rng).is_empty(), "no scales: nothing is exchanged")
	Game.give_or_store(ItemData.jewel(DungeonData.SCALE, 15))
	check(DungeonData.scales() == 15 and DungeonData.buy_block("charm") == "", "with scales the amulet can be exchanged")
	var bought := DungeonData.buy("charm", rng)
	check(DungeonData.is_gear(bought) and DungeonData.scales() == 3 and Game.profile.inv.any(func(it): return it.get("uid", "") == bought.get("uid", "x")), "the exchange takes the scales and puts the amulet in the bag")
	check(DungeonData.buy("fang", rng).is_empty() and DungeonData.scales() == 3, "too few scales for the ring")
	var jewels := DungeonData.buy("chaos", rng)
	check(jewels.get("id", "") == "chaos" and DungeonData.scales() == 1, "materials exchange too")

	# --- The run -------------------------------------------------------------------------
	Game.profile.flags.erase(DungeonData.F_DAY)
	Game.profile.flags.erase(DungeonData.F_WEEK)
	# One pinned day for the whole run, so a run across midnight (CI at 00:00 UTC) stays on one day.
	var run_day := GoalsData.today()
	check(DungeonData.enter(run_day) == "", "today's entry")
	Game.current_zone = DungeonData.ID
	var zone := Zone.new()
	zone.zone_id = DungeonData.ID
	zone.raid_seed = 1234
	add_child(zone)
	zone.dungeon_finished.connect(func(r: Dictionary): finished_result = r)
	zone.set_process(false)
	var hero := zone.hero
	hero.set_physics_process(false)
	hero.stats["dodge"] = 0.0
	var run := zone.dungeon_run
	check(run != null and zone.raid_run == null and zone.tower_run == null and zone.is_tower and zone.presence == null, "the tomb runs a DragonRun, tower-like (no world players)")
	check(zone.has_node("DragonTombArt") and zone.get_node("DragonTombArt").get_child_count() >= 5, "the bone arena is built")
	check(zone.companions.size() == 3, "the three party members came along (%d)" % zone.companions.size())
	var def_ai: Companion = null
	var priest_ai: Companion = null
	var mage_ai: Companion = null
	for c in zone.companions:
		c.set_physics_process(false)
		c.stats["dodge"] = 0.0
		match String(c.member.get("class", "")):
			"defender": def_ai = c
			"priest": priest_ai = c
			"mage": mage_ai = c
	check(def_ai != null and priest_ai != null and mage_ai != null, "a Defender, a Priest and a Mage stand with the hero")
	run.set_process(false)
	run.step(DragonRun.INTRO + 0.1)
	check(run.state == "spawning" and run.stage == 1, "after the intro the first pack spawns")
	var guard := 0
	while run.state == "spawning" and guard < 40:
		run.step(0.016)
		guard += 1
	check(run.state == "fight" and run.mobs.size() == DungeonData.PACK_SIZE[0], "pack 1: %d guardians (%d)" % [DungeonData.PACK_SIZE[0], run.mobs.size()])
	check(run.status_text().contains("ฝูง 1/2"), "the on-screen line shows the pack (%s)" % run.status_text())
	check(String(run.mobs[0].template.name).begins_with("ผู้พิทักษ์สุสาน"), "the guardians are named for the tomb")
	_kill_all(run.mobs, hero)
	run.step(0.016)
	check(run.state == "rest" and run.stage == 2, "the cleared pack leads to a rest and pack 2")
	run.step(DragonRun.REST + 0.1)
	guard = 0
	while run.state == "spawning" and guard < 40:
		run.step(0.016)
		guard += 1
	check(run.state == "fight" and run.mobs.size() == DungeonData.PACK_SIZE[1], "pack 2: %d guardians (%d)" % [DungeonData.PACK_SIZE[1], run.mobs.size()])
	_kill_all(run.mobs, hero)
	run.step(0.016)
	check(run.stage == 3 and run.state == "rest", "the boss is next")
	run.step(DragonRun.REST + 0.1)
	guard = 0
	while run.state == "spawning" and guard < 40:
		run.step(0.016)
		guard += 1
	var boss := run.boss
	check(run.state == "fight" and boss != null and DragonBoss.active == boss and boss.is_boss and boss.hostile, "the dragon is up and hostile")
	check(boss.max_hp == int(DungeonData.monster_stats(run.power, "boss").hp), "the dragon carries the party-scaled HP")
	check(boss.has_defender(), "the dragon sees the party's Defender")
	boss.set_process(false)
	boss.set_physics_process(false)
	check(run.status_text().contains("คลั่งใน"), "the line shows the enrage clock (%s)" % run.status_text())
	var all: Array[Node3D] = [hero, def_ai, priest_ai, mage_ai]

	# Spread: two marked, marked AIs walk apart; alone a mark hurts half, clumped it hurts all.
	_cluster(all, Vector3(4, 0.3, 4))
	boss._rng.seed = 11
	boss.force_special("spread")
	var marked: Array[Node3D] = []
	for t in boss.telegraphs:
		check(String(t.kind) == "mark", "a mark warning")
		marked.append((t.victim as WeakRef).get_ref() as Node3D)
	check(marked.size() == DragonBoss.MARK_COUNT and marked[0] != marked[1], "two different players are marked")
	var marked_ai: Companion = null
	var bystander: Companion = null
	for c in [def_ai, priest_ai, mage_ai]:
		if marked.has(c) and marked_ai == null:
			marked_ai = c
		elif not marked.has(c) and bystander == null:
			bystander = c
	check(marked_ai != null, "a party member is marked")
	if marked_ai != null:
		var escape := DragonBoss.danger_escape(marked_ai.global_position, marked_ai)
		check(escape.is_finite(), "a marked member standing by others has a way out")
		marked_ai.set_physics_process(true)
		for i in 3:
			marked_ai._physics_process(0.05)
		marked_ai.set_physics_process(false)
		check(Vector3(marked_ai.velocity.x, 0, marked_ai.velocity.z).dot(escape) > 0.5, "the marked AI walks away from the others (%s)" % marked_ai.velocity)
		# Walked SPREAD_RADIUS that way it is clear of everyone and stops running.
		marked_ai.global_position += escape * (DragonBoss.SPREAD_RADIUS + 1.5)
		check(_nearest_other(marked_ai, all) >= DragonBoss.SPREAD_RADIUS and not DragonBoss.danger_escape(marked_ai.global_position, marked_ai).is_finite(), "4 m from everyone it is safe and stays (%.1f m)" % _nearest_other(marked_ai, all))
	if bystander != null:
		var other_mark: Node3D = marked[0]
		bystander.global_position = other_mark.global_position + Vector3(1.5, 0, 0)
		var away := DragonBoss.danger_escape(bystander.global_position, bystander)
		check(away.is_finite() and away.dot(Vector3(bystander.global_position.x - other_mark.global_position.x, 0, bystander.global_position.z - other_mark.global_position.z).normalized()) > 0.8, "an unmarked member near a marked one steps away from it")
	# Everyone far apart: only the marked are hurt, each at half.
	_heal_all(all)
	for i in all.size():
		all[i].global_position = Vector3(-12.0 + 8.0 * float(i), 0.3, 6.0)
	var hp_before := _hp_of(all)
	boss.tick(DragonBoss.MARK_TIME + 0.1)
	check(boss.telegraphs.is_empty() and boss._shapes.is_empty() and boss.specials == 1, "the marks land and their meshes go")
	for i in all.size():
		var loss := 1.0 - _hp_of(all)[i] / hp_before[i]
		if marked.has(all[i]):
			check(loss > 0.3 and loss < 0.6, "a marked player alone takes half (%s %.2f)" % [all[i].name, loss])
		else:
			check(is_zero_approx(loss), "an unmarked player far away is untouched (%s %.2f)" % [all[i].name, loss])
	# Clumped: the explosion hurts everyone in reach.
	_heal_all(all)
	_cluster(all, Vector3(2, 0.3, 2))
	boss._cycle = 99.0
	boss.force_special("spread")
	check(boss.telegraphs.size() == 2, "a second spread")
	hp_before = _hp_of(all)
	boss.tick(DragonBoss.MARK_TIME + 0.1)
	var hurt := 0
	for i in all.size():
		if _hp_of(all)[i] < hp_before[i]:
			hurt += 1
	check(hurt == all.size(), "clumped together, every player is hurt by the marks (%d/4)" % hurt)
	_heal_all(all)

	# The claw: the Defender taunts it and takes it at a third; the target side-steps.
	for i in all.size():
		all[i].global_position = boss.global_position + Vector3(-6.0 + 4.0 * float(i), 0.0, 8.0)
	# No buff from the AI's own casting so far: the Priest starts unwarded.
	hero._buffs.clear()
	for c in [def_ai, priest_ai, mage_ai]:
		c._book.buffs.clear()
	check(not DragonBoss.is_warded(priest_ai), "the Priest starts unwarded")
	boss._victim = priest_ai
	boss._victim_timer = 30.0
	boss.force_special("cone")
	check(boss.telegraphs.size() == 1 and String(boss.telegraphs[0].kind) == "cone" and (boss.telegraphs[0].victim as WeakRef).get_ref() == priest_ai, "the claw aims at the boss's target (the Priest)")
	var cone: Dictionary = boss.telegraphs[0]
	check(DragonBoss.wants_taunt(def_ai, boss) and not DragonBoss.wants_taunt(priest_ai, boss), "the Defender wants to taunt the claw off the Priest")
	def_ai.target = boss
	var provoke := ClassData.find_skill(&"defender", "provoke")
	check(def_ai._shape_score(provoke, 1.0, 1.0) >= 8.0, "the AI Defender scores its provoke on the dragon")
	check(DragonBoss.wants_ward(priest_ai), "the Priest wants to ward the unprotected target")
	var ward_skill := ClassData.find_skill(&"priest", "holy_reflection")
	check(priest_ai._shape_score(ward_skill, 1.0, 1.0) >= 9.0, "the AI Priest scores its defence buff while the claw is aimed")
	var side := DragonBoss.danger_escape(priest_ai.global_position, priest_ai)
	check(side.is_finite() and absf(side.dot(cone.dir)) < 0.2, "a non-tank in the cone side-steps out of it")
	boss.taunt(def_ai, 4.0)
	check(boss._victim == def_ai and boss.is_tank(def_ai) and not boss.is_tank(priest_ai), "the provoke turns the dragon and marks the tank")
	check(not DragonBoss.danger_escape(def_ai.global_position, def_ai).is_finite() or not DragonBoss.inside_cone(def_ai.global_position, cone.origin, cone.dir), "the tank does not run from the claw")
	def_ai.global_position = cone.origin + (cone.dir as Vector3) * 5.0 + Vector3(0, 0.3, 0)
	priest_ai.global_position = cone.origin + (cone.dir as Vector3) * 5.0 + side * 7.0 + Vector3(0, 0.3, 0)
	hero.global_position = cone.origin - (cone.dir as Vector3) * 6.0 + Vector3(0, 0.3, 0)
	mage_ai.global_position = hero.global_position + Vector3(2, 0, 0)
	check(DragonBoss.inside_cone(def_ai.global_position, cone.origin, cone.dir) and not DragonBoss.inside_cone(priest_ai.global_position, cone.origin, cone.dir), "the tank stands in the cone, the Priest out of it")
	var def_before := def_ai.hp
	var priest_before := priest_ai.hp
	boss.tick(DragonBoss.CONE_TIME + 0.1)
	var tank_loss := float(def_before - def_ai.hp) / float(def_ai.max_hp)
	check(tank_loss > 0.3 and tank_loss < 0.65, "the taunting Defender takes the claw at a third (%.2f)" % tank_loss)
	check(priest_ai.hp == priest_before, "the Priest who stepped out is untouched")
	_heal_all(all)

	# A warded target survives; an unprotected one falls and waits for a phase change.
	boss._victim = mage_ai
	boss._victim_timer = 30.0
	boss._cycle = 99.0
	boss.force_special("cone")
	cone = boss.telegraphs[0]
	mage_ai.receive_party_buff({"def": 0.45, "secs": 60.0}, Color.WHITE, "Holy Reflection", "holy_reflection")
	check(DragonBoss.is_warded(mage_ai) and not DragonBoss.wants_ward(priest_ai), "the Priest's buff wards the target")
	mage_ai.global_position = cone.origin + (cone.dir as Vector3) * 6.0 + Vector3(0, 0.3, 0)
	hero.global_position = cone.origin + (cone.dir as Vector3) * 8.0 + Vector3(0, 0.3, 0)
	def_ai.global_position = cone.origin - (cone.dir as Vector3) * 6.0 + Vector3(0, 0.3, 0)
	priest_ai.global_position = def_ai.global_position + Vector3(2, 0, 0)
	var mage_before := mage_ai.hp
	# The claw is what is tested: no leftover 2.5 s grace from an earlier revive (a fast
	# machine reaches this within it) and no lucky dodge.
	hero._invulnerable_until = 0
	hero.stats.dodge = 0.0
	boss.tick(DragonBoss.CONE_TIME + 0.1)
	var ward_loss := float(mage_before - mage_ai.hp) / float(mage_ai.max_hp)
	check(ward_loss > 0.45 and ward_loss < 0.95 and not mage_ai.is_dead(), "a warded player survives the claw (%.2f)" % ward_loss)
	check(hero.is_dead() and int(Game.profile.hp) == 0, "an unprotected Warrior in the cone falls")
	run.step(0.5)
	check(hero.is_dead() and run.state == "fight", "the fallen hero waits for a phase change (no timed revive)")
	check(run.status_text().contains("ฟื้น"), "the line says so (%s)" % run.status_text())
	# A fallen companion does not stand up by itself in the tomb either.
	priest_ai._dead = true
	priest_ai._revive_timer = -1.0
	priest_ai.set_physics_process(true)
	priest_ai._physics_process(0.05)
	priest_ai.set_physics_process(false)
	check(priest_ai.is_dead(), "a fallen member waits too")
	_heal_all([def_ai, mage_ai])

	# Without a Defender the claw alternates its target.
	def_ai.member["class"] = "warrior"
	check(not boss.has_defender(), "the party reads as having no Defender")
	boss._cycle = 99.0
	boss.force_special("cone")
	var first_victim: Node3D = (boss.telegraphs[0].victim as WeakRef).get_ref() as Node3D
	boss.telegraphs.clear()
	boss._clear_shapes()
	boss._winding = false
	boss._cycle = 99.0
	boss.force_special("cone")
	var second_victim: Node3D = (boss.telegraphs[0].victim as WeakRef).get_ref() as Node3D
	check(first_victim != second_victim, "the claw goes to someone else each time without a Defender")
	boss.telegraphs.clear()
	boss._clear_shapes()
	boss._winding = false
	def_ai.member["class"] = "defender"

	# The crystals at 70%: invulnerable, the AI switches, the fallen stand again.
	boss.take_hit(int(boss.max_hp * 0.31), false, Color.WHITE, def_ai)
	check(boss.crystal_phases == 1 and boss.shielded() and boss.crystals.size() == DragonBoss.CRYSTALS, "70%%: the dragon raises two crystals and hides (%d)" % boss.crystals.size())
	check(not hero.is_dead() and not priest_ai.is_dead() and run.revives >= 2, "the phase change raises the fallen (%d)" % run.revives)
	var hp_shielded := boss.hp
	boss.take_hit(5000, false, Color.WHITE, def_ai)
	check(boss.hp == hp_shielded, "nothing hurts it behind the crystals")
	check(run.status_text().contains("ศิลา"), "the line says to break the crystals (%s)" % run.status_text())
	var crystal := DragonBoss.priority_target(mage_ai.global_position)
	check(crystal is DragonCrystal and crystal.hostile and String(crystal.template.name) == DungeonData.CRYSTAL_NAME, "a crystal is the priority target")
	mage_ai.target = null
	check(mage_ai._pick_target() == crystal, "the AI switches to the crystal")
	check(crystal.max_hp == int(DungeonData.monster_stats(run.power, "crystal").hp), "crystals carry the dungeon's numbers")
	# Too slow: it heals and raises them again.
	var hp_low := boss.hp
	boss.tick(DragonBoss.CRYSTAL_TIME + 0.1)
	check(boss.heals == 1 and boss.hp == mini(boss.max_hp, hp_low + int(round(boss.max_hp * DragonBoss.CRYSTAL_HEAL))), "crystals left standing: it heals 15%% (%d -> %d)" % [hp_low, boss.hp])
	check(boss.shielded() and boss.crystals.size() == DragonBoss.CRYSTALS and boss.crystals.all(func(c): return is_instance_valid(c) and not c.is_dead()), "and raises fresh crystals")
	check(not is_instance_valid(crystal) or crystal.is_dead() or crystal.is_queued_for_deletion(), "the old crystals are gone")
	# Both broken in time: vulnerable again (a phase change).
	hero._dead = true
	_kill_all(boss.crystals, def_ai)
	boss.tick(0.1)
	check(not boss.shielded() and boss.crystals.is_empty(), "both crystals broken: the dragon can be hurt again")
	check(not hero.is_dead(), "the end of the crystal phase raises the fallen too")
	hp_shielded = boss.hp
	boss.take_hit(1000, false, Color.WHITE, def_ai)
	check(hp_shielded - boss.hp == 1000, "damage lands again")
	check(DragonBoss.priority_target(mage_ai.global_position) == null, "no crystal to target")
	# 35%: the second crystal phase.
	boss.take_hit(boss.hp - int(boss.max_hp * 0.34), false, Color.WHITE, def_ai)
	check(boss.crystal_phases == 2 and boss.shielded(), "35%: the second crystal phase")
	_kill_all(boss.crystals, def_ai)
	boss.tick(0.1)
	check(not boss.shielded(), "broken again")
	boss.take_hit(boss.hp - int(boss.max_hp * 0.1), false, Color.WHITE, def_ai)
	check(boss.crystal_phases == 2 and not boss.shielded(), "no third crystal phase")

	# Enrage.
	var atk_scale := boss._atk_scale
	boss.tick(DragonBoss.ENRAGE_TIME)
	check(boss.enraged and String(boss.template.name).contains("คลั่ง") and is_equal_approx(boss._atk_scale, atk_scale * DragonBoss.ENRAGE_ATK), "the enrage timer runs out: it goes berserk")
	boss.telegraphs.clear()
	boss._clear_shapes()

	# The kill, the rewards and the ranking.
	var link := FakeLink.new()
	link.week = DungeonRanking.week_of()
	DungeonRanking.transport = link
	var gold_before := int(Game.profile.gold)
	var scales_before := DungeonData.scales()
	run.elapsed = 250.0
	boss.take_hit(boss.hp + 10, false, Color.WHITE, hero)
	run.step(0.016)
	check(run.state == "ending" and bool(run.result.cleared) and int(run.result.seconds) == 250, "the dragon falls: cleared in %d s" % int(run.result.get("seconds", 0)))
	var paid: Dictionary = run.result.paid
	check(not paid.is_empty() and bool(paid.first_week) and int(paid.scales) == DungeonData.FIRST_WEEK_SCALES, "the week's first clear pays five scales")
	check(DungeonData.scales() == scales_before + DungeonData.FIRST_WEEK_SCALES and int(Game.profile.gold) >= gold_before + int(paid.gold), "scales and gold paid")
	check(int(Game.profile.flags.get(DungeonData.F_BEST, 0)) == 250 and int(Game.profile.flags.get(DungeonData.F_FAST, 0)) == 1 and bool(run.result.fast), "the best time and the fast-clear flag are kept")
	Achievements.check_all(Game.profile)
	check(Achievements.is_earned("t_dragon_tomb", Game.profile) and Achievements.entry("t_dragon_tomb").title == "ผู้พิชิตสุสานมังกร", "the fast clear earns the title ผู้พิชิตสุสานมังกร")
	check((run.result.classes as Array).size() == 4 and run.result.classes[0] == "warrior", "the party's classes travel with the result (%s)" % str(run.result.classes))
	check(bool(run.result.ranked) and int(DungeonRanking.local_best().secs) == 250, "the clear is this device's best of the week")
	check(not DungeonData.first_of_week_ready(), "the week's first clear is taken")
	check(DungeonData.claim(RandomNumberGenerator.new(), 100).is_empty(), "the same entry cannot be claimed twice")
	var gold_after := int(Game.profile.gold)
	run._victory()
	check(int(Game.profile.gold) == gold_after and DungeonData.scales() == scales_before + DungeonData.FIRST_WEEK_SCALES, "a second victory call pays nothing")
	# The server: one fetch, one post, the answer adopted.
	DungeonRanking.poll()
	DungeonRanking.poll()
	DungeonRanking.poll()
	DungeonRanking.poll()
	var gets := link.sent.filter(func(s): return s.method == "GET")
	var posts := link.sent.filter(func(s): return s.method == "POST")
	check(gets.size() == 1 and String(gets[0].path).begins_with(DungeonRanking.API_TIMES), "the week's times are fetched once (%d)" % gets.size())
	check(posts.size() == 1 and DungeonRanking.posts == 1 and String(posts[0].path) == DungeonRanking.API_TIME, "the clear is posted once (%d)" % posts.size())
	if posts.size() == 1:
		var body: Dictionary = JSON.parse_string(posts[0].body)
		check(int(body.secs) == 250 and int(body.week) == link.week and (body.classes as Array).size() == 4 and String(body.leader).begins_with("local:"), "the post carries the time, the week, the classes and the leader (%s)" % str(body))
	var board := DungeonRanking.board()
	check(board.size() >= 3 and board.size() <= DungeonRanking.TOP, "the board holds seeded parties and the server's (%d)" % board.size())
	check(board.any(func(e): return bool(e.mine) and int(e.secs) == 250) and board.any(func(e): return String(e.leader) == "u:somebody"), "the hero's time and the server's are on the board")
	var sorted := true
	for i in range(1, board.size()):
		if int(board[i].secs) < int(board[i - 1].secs):
			sorted = false
	check(sorted and int(board[0].rank) == 1, "fastest first, ranked")
	check(DungeonRanking.my_rank() > 0, "the hero has a rank (#%d)" % DungeonRanking.my_rank())
	var seeded := DungeonRanking.seeded(link.week)
	check(seeded.size() >= 3 and seeded == DungeonRanking.seeded(link.week) and seeded.all(func(e): return (e.classes as Array).size() == 4 and int(e.secs) >= 150), "the week's seeded parties are deterministic, four classes each")
	check(DungeonRanking.seeded(link.week + 1) != seeded, "another week seeds other parties")
	var sent_before := link.sent.size()
	DungeonRanking.record_clear(300, run.result.classes)
	DungeonRanking.poll()
	check(link.sent.size() == sent_before and int(DungeonRanking.local_best().secs) == 250, "a slower clear changes nothing and posts nothing")
	DungeonRanking.transport = null
	DungeonRanking.record_clear(240, run.result.classes)
	DungeonRanking.poll()
	check(int(DungeonRanking.local_best().secs) == 240 and link.sent.size() == sent_before, "offline: the local best is kept, nothing is sent")
	run.step(DragonRun.END_DELAY + 0.1)
	check(run.state == "done" and not finished_result.is_empty(), "the run ends and tells Main")
	check(DragonBoss.active == null or not is_instance_valid(DragonBoss.active) or DragonBoss.active.is_dead(), "no live dragon left for the AI to read")
	check(get_tree().get_nodes_in_group("mobs").filter(func(m): return m is DragonCrystal and not m.is_dead() and not m.is_queued_for_deletion()).is_empty(), "no crystal left")

	# A second entry the same day: 1-3 scales.
	check(DungeonData.enter(run_day) == "" and DungeonData.runs_left(run_day) == 0, "the second entry of the day")
	var again := DungeonData.claim(rng, 400)
	check(not again.is_empty() and not bool(again.first_week) and int(again.scales) >= 1 and int(again.scales) <= 3, "the second clear drops 1-3 scales")
	check(int(Game.profile.flags.get(DungeonData.F_BEST, 0)) == 250, "a slower clear keeps the best time")

	# A wipe.
	Game.profile.flags.erase(DungeonData.F_DAY)
	DungeonData.enter()
	var run2 := DragonRun.new()
	run2.setup(zone, hero, 99)
	zone.add_child(run2)
	run2.set_process(false)
	run2.state = "fight"
	run2.stage = 3
	run2._started = true
	var gold_wipe := int(Game.profile.gold)
	hero._dead = true
	for c in zone.companions:
		c._dead = true
	run2.step(0.016)
	check(run2.state == "ending" and not bool(run2.result.cleared) and (run2.result.paid as Dictionary).is_empty(), "all four down: a wipe, no reward")
	check(int(Game.profile.gold) == gold_wipe and DungeonData.open_run() != "", "a wipe pays nothing")
	check(not hero.is_dead(), "the hero stands again after the wipe (back to town)")
	for c in zone.companions:
		c._dead = false

	# The keeper's screen: lobby, ranking with class badges, exchange, result.
	var screen := DungeonScreen.new()
	add_child(screen)
	screen.open_lobby()
	check(screen.is_open, "the keeper's screen opens")
	var all_text := _texts(screen)
	check(all_text.contains(DungeonData.runs_text()) and all_text.contains(DungeonData.BOSS_NAME) and all_text.contains("กระจายตัว") and not all_text.contains("%d") and not all_text.contains("%s"), "it shows the entries, the boss and the mechanics, no broken format")
	screen.open_lobby("ranking")
	var chips := screen.find_children("*", "PanelContainer", true, false).filter(func(p): return p.has_meta("class"))
	var rows := DungeonRanking.board().size()
	check(rows > 0 and chips.size() == rows * 4, "every ranked party shows its four class badges (%d chips for %d rows)" % [chips.size(), rows])
	check(_texts(screen).contains("(คุณ)"), "the hero's row is marked")
	screen.open_lobby("shop")
	check(_texts(screen).contains("เครื่องรางมังกร") and _texts(screen).contains("เกล็ดมังกรโบราณของคุณ"), "the exchange lists the dungeon gear")
	screen.show_result(finished_result)
	check(_texts(screen).contains("พิชิตสุสานมังกรโบราณ"), "the result screen")
	screen.close_screen()
	get_tree().paused = false
	screen.queue_free()

	zone.queue_free()
	await zone.tree_exited
	await get_tree().process_frame
	check(DragonBoss.active == null, "cleanup: no dragon left")
	DungeonRanking.transport = null
	print("DRAGON_TOMB: %d checks, %d failures" % [checks, failures])
	get_tree().quit(failures)


## A moment (unix) in the world's second week when a Defender, a Priest and a third Lv.100
## world player are online at once, or -1.
func _online_moment() -> float:
	var day0 := float(WorldPlayers.START_UNIX) + 20.0 * 86400.0
	for step in 48:
		var t := day0 + float(step) * 3600.0
		var have := {}
		var others := 0
		for i in WorldPlayers.size():
			var s := WorldPlayers.state(i, t)
			if not bool(s.online) or int(s.level) < 100:
				continue
			if StringName(s["class"]) in [&"defender", &"priest"] and not have.has(s["class"]):
				have[s["class"]] = true
			else:
				others += 1
		if have.size() == 2 and others >= 1:
			return t
	return -1.0


func _cluster(list: Array, at: Vector3) -> void:
	for i in list.size():
		(list[i] as Node3D).global_position = at + Vector3(0.8 * float(i), 0, 0.6 * float(i % 2))


func _heal_all(list: Array) -> void:
	for n in list:
		if n is Hero:
			Game.profile.hp = Game.stats_now().max_hp
			if (n as Hero).is_dead():
				(n as Hero).revive()
			# No revive grace or lucky dodge in the way of the damage checks that follow.
			(n as Hero)._invulnerable_until = 0
			(n as Hero).stats.dodge = 0.0
		elif n is Companion:
			var c := n as Companion
			if c.is_dead():
				c._dead = false
			c.heal_fraction(1.0)


func _hp_of(list: Array) -> Array[float]:
	var out: Array[float] = []
	for n in list:
		out.append(float(Game.profile.hp) if n is Hero else float((n as Companion).hp))
	return out


func _nearest_other(who: Node3D, list: Array) -> float:
	var best := INF
	for n in list:
		if n != who:
			best = minf(best, Vector3(who.global_position.x - n.global_position.x, 0, who.global_position.z - n.global_position.z).length())
	return best


func _texts(root: Node) -> String:
	var texts: PackedStringArray = []
	for label in root.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	for button in root.find_children("*", "Button", true, false):
		texts.append((button as Button).text)
	return "\n".join(texts)


func _power(item: Dictionary) -> int:
	var s: Dictionary = item.get("stats", {})
	return int(s.get("hp", 0)) + int(s.get("mp", 0)) + int(s.get("atk", 0)) * 4 + int(s.get("def", 0)) * 4


func _kill_all(list: Array, by: Node) -> void:
	for m in list.duplicate():
		if is_instance_valid(m) and not m.is_dead():
			m.take_hit(m.hp + 10, false, Color.WHITE, by)


func _count_of(items: Array, id: String) -> int:
	var n := 0
	for item in items:
		if String(item.get("id", "")) == id:
			n += int(item.get("count", 1))
	return n
