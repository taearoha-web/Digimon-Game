extends Node3D
## The daily party raid (RaidData, RaidRun, RaidBoss, RaidScreen): entry gating (level,
## party of 3+, two entries a Thai day, the next day resets), three floors that advance
## (floor 2 has its mid-boss), the boss's mechanics (buster on the threat holder that a
## tank takes at half, circles the AI steps out of, adds that shield it, the 50% phase,
## the enrage), a scripted party clearing it from a fixed seed, rewards paid once per
## entry (the first clear's chest, a 250★ set core), a wipe and the hero getting back up.
##   godot --headless --path . res://tests/integration/raid_test.tscn
var checks := 0
var failures := 0
var finished_result: Dictionary = {}


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func _ready() -> void:
	seed(4242)
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.quality = 0
	WorldEvents.festival_enabled = false
	Game.new_profile(&"defender", "Raid QA", {"gender": 0})
	Game.profile.level = 20
	Game.profile.adv = 4
	var day1 := "2026-03-01"
	var day2 := "2026-03-02"

	# --- Gating ------------------------------------------------------------------------
	check(RaidData.entry_block(day1).contains("เลเวล"), "too low a level is turned away (%s)" % RaidData.entry_block(day1))
	Game.profile.level = 100
	Game.paragon()["level"] = 250
	check(RaidData.party_size() == 1 and RaidData.entry_block(day1).contains("ปาร์ตี้"), "alone: a party of 3+ is needed (%s)" % RaidData.entry_block(day1))
	check(RaidData.enter(day1) != "" and RaidData.runs_left(day1) == 2, "a refused entry spends nothing")
	var tank := WorldPlayers.first_of(&"defender")
	var healer := WorldPlayers.first_of(&"priest")
	check(Game.party_invite(tank, true) == "", "a Defender world player joins")
	check(RaidData.entry_block(day1).contains("ปาร์ตี้"), "two people are still too few")
	check(Game.party_invite(healer, true) == "", "a Priest world player joins")
	check(RaidData.party_size() == 3 and RaidData.entry_block(day1) == "", "three people may go in (%s)" % RaidData.entry_block(day1))
	check(RaidData.runs_text(day1) == "เหลือ 2/2 รอบวันนี้", "the keeper shows the day's entries (%s)" % RaidData.runs_text(day1))
	check(RaidData.enter(day1) == "" and RaidData.runs_left(day1) == 1 and RaidData.open_run() != "", "the first entry is spent on the way in")
	check(RaidData.enter(day1) == "" and RaidData.runs_left(day1) == 0, "the second entry")
	check(RaidData.enter(day1).contains("ครบ") and RaidData.runs_text(day1) == "เหลือ 0/2 รอบวันนี้", "no third entry the same day")
	# The raid keeps its day and open run as text flags: the saved hero must still read
	# back (a strict check once hid the whole hero after a reload).
	var spare := Game.SLOT_COUNT
	check(Game._write_profile(Game.profile.duplicate(true), spare), "a hero inside the raid saves")
	var reread := Game._read_slot(spare)
	check(not reread.is_empty() and String(reread.get("name", "")) == "Raid QA", "the hero reads back after entering the raid (not hidden as unreadable)")
	check(String(reread.get("flags", {}).get(RaidData.F_DAY, "")) == day1 and String(reread.get("flags", {}).get(RaidData.F_OPEN, "")) != "", "the raid's text flags survive the save")
	var long_flag := Game.profile.duplicate(true)
	long_flag.flags["junk"] = "x".repeat(Game.FLAG_TEXT_MAX + 1)
	check(not Game._valid_profile(long_flag), "an oversized text flag is still refused")
	DirAccess.remove_absolute(Game.save_path(spare))
	check(RaidData.runs_left(day2) == 2 and RaidData.entry_block(day2) == "", "the next day resets the entries")
	check(RaidData.first_chest_ready(day2), "and the first-clear chest")

	# --- Scaling -----------------------------------------------------------------------
	var weak := RaidData.party_power([{"level": 40, "stars": 0, "atk": 200, "max_hp": 2000, "def": 50}, {"level": 40, "atk": 180, "max_hp": 1800, "def": 40}, {"level": 40, "atk": 150, "max_hp": 1500, "def": 30}])
	var strong := RaidData.party_power([{"level": 100, "stars": 250, "atk": 9000, "max_hp": 90000, "def": 900}, {"level": 100, "stars": 250, "atk": 8000, "max_hp": 80000, "def": 800}, {"level": 100, "stars": 250, "atk": 8500, "max_hp": 85000, "def": 850}])
	var wb := RaidData.monster_stats(weak, "boss")
	var sb := RaidData.monster_stats(strong, "boss")
	check(sb.hp > wb.hp * 10 and sb.atk > wb.atk * 10, "the boss follows the party's power (%s vs %s)" % [wb, sb])
	check(int(wb.level) == 42 and int(sb.level) == 100 + int(250 * 0.45), "the level shown follows level and stars (%d / %d)" % [int(wb.level), int(sb.level)])
	check(RaidData.monster_stats(strong, "trash").hp < RaidData.monster_stats(strong, "mid").hp and RaidData.monster_stats(strong, "mid").hp < sb.hp, "trash < mid-boss < boss")
	check(RaidData.trash_pool(40).size() > 0 and RaidData.mid_boss(40) != &"" and RaidData.trash_pool(100) == RaidData.STAR_POOL, "monster pools for each band")
	var first := RaidData.rewards(100, 250, true, RandomNumberGenerator.new())
	var second := RaidData.rewards(100, 250, false, RandomNumberGenerator.new())
	check(int(first.gold) > int(second.gold) and int(first.exp) > int(second.exp), "the first clear pays more")
	check(_has_item(first.items, SetGearData.CORE) and _count_of(first.items, "purple") > 0 and _count_of(first.items, "feather") > 0, "the 250★ first chest holds a set core, jewels and feathers")

	# --- The run -----------------------------------------------------------------------
	Game.profile.flags.erase(RaidData.F_DAY)
	check(RaidData.enter() == "", "today's entry")
	Game.current_zone = RaidData.ID
	var zone := Zone.new()
	zone.zone_id = RaidData.ID
	zone.raid_seed = 777
	add_child(zone)
	zone.raid_finished.connect(func(r: Dictionary): finished_result = r)
	zone.set_process(false)
	var hero := zone.hero
	hero.set_physics_process(false)
	hero.stats["dodge"] = 0.0
	var run := zone.raid_run
	check(run != null and zone.tower_run == null and zone.is_tower and zone.presence == null, "the raid zone runs a RaidRun, tower-like (no world players)")
	check(zone.has_node("RaidArenaArt") and zone.get_node("RaidArenaArt").get_child_count() >= 4, "the crimson arena is built")
	check(zone.companions.size() == 2, "the two party members came along (%d)" % zone.companions.size())
	for c in zone.companions:
		c.set_physics_process(false)
		c.stats["dodge"] = 0.0
		c.global_position = hero.global_position + Vector3(-8.0 if zone.companions.find(c) == 0 else 8.0, 0.3, 0)
	run.set_process(false)
	run.step(RaidRun.INTRO + 0.1)
	check(run.state == "spawning" and run.floor_no == 1, "after the intro floor 1 spawns")
	var guard := 0
	while run.state == "spawning" and guard < 40:
		run.step(0.016)
		guard += 1
		if run.state == "spawning":
			check(get_tree().get_nodes_in_group("mobs").is_empty(), "a half-built floor cannot be targeted")
	check(run.state == "fight" and run.mobs.size() == RaidData.TRASH[0], "floor 1: %d monsters (%d)" % [RaidData.TRASH[0], run.mobs.size()])
	check(run.status_text().contains("ชั้น 1/3"), "the on-screen line shows the floor (%s)" % run.status_text())
	var trash_hp := int(RaidData.monster_stats(run.power, "trash").hp)
	check(int(run.mobs[0].max_hp) == trash_hp, "floor monsters carry the raid's numbers")
	var exp_before := int(Game.paragon().exp)
	_kill_all(run.mobs, hero)
	run.step(0.016)
	check(run.state == "rest" and run.floor_no == 2, "the cleared floor leads to a rest and floor 2")
	run.step(RaidRun.REST + 0.1)
	guard = 0
	while run.state == "spawning" and guard < 40:
		run.step(0.016)
		guard += 1
	check(run.state == "fight" and run.mid_boss != null and run.mid_boss.is_boss and String(run.mid_boss.template.name).begins_with(RaidData.MID_NAME_PREFIX), "floor 2 has its mid-boss")
	check(run.mobs.size() == RaidData.TRASH[1] + 1, "floor 2: monsters and the mid-boss (%d)" % run.mobs.size())
	_kill_all(run.mobs, hero)
	run.step(0.016)
	check(run.floor_no == 3 and run.state == "rest", "floor 3 next")
	run.step(RaidRun.REST + 0.1)
	guard = 0
	while run.state == "spawning" and guard < 40:
		run.step(0.016)
		guard += 1
	var boss := run.boss
	check(run.state == "fight" and boss != null and RaidBoss.active == boss and boss.is_boss and boss.hostile, "floor 3: the raid boss is up and hostile")
	check(boss.max_hp == int(RaidData.monster_stats(run.power, "boss").hp), "the boss carries the party-scaled HP")
	boss.set_process(false)
	boss.set_physics_process(false)
	check(run.status_text().contains("คลั่งใน"), "the line shows the enrage clock (%s)" % run.status_text())

	# Circles: one on every member; the AI steps out; whoever stays is hit.
	var stay: Companion = zone.companions[1]
	boss.force_special("rain")
	check(boss.telegraphs.size() == 3, "a blood circle on each of the three (%d)" % boss.telegraphs.size())
	check(RaidBoss.danger_escape(stay.global_position).is_finite(), "a member in a circle has a way out")
	var mover: Companion = zone.companions[0]
	var escape := RaidBoss.danger_escape(mover.global_position)
	mover.set_physics_process(true)
	for i in 3:
		mover._physics_process(0.05)
	mover.set_physics_process(false)
	check(Vector3(mover.velocity.x, 0, mover.velocity.z).dot(escape) > 0.5, "the AI walks out of the circle (%s)" % mover.velocity)
	hero.global_position += Vector3(0, 0, 12)
	mover.global_position += escape * 6.0
	var hero_hp := int(Game.profile.hp)
	var stay_hp := stay.hp
	var mover_hp := mover.hp
	boss.tick(RaidBoss.TELEGRAPH + 0.1)
	check(boss.telegraphs.is_empty() and boss._shapes.is_empty(), "the circles land and their meshes go")
	check(stay.hp < stay_hp and int(Game.profile.hp) == hero_hp and mover.hp == mover_hp, "only the one who stayed is hit (%d->%d)" % [stay_hp, stay.hp])
	check(not RaidBoss.danger_escape(stay.global_position).is_finite(), "no danger once landed")

	# Buster: the threat holder takes it; a taunting tank takes half.
	var other: Companion = zone.companions[1]
	other.heal_fraction(1.0)
	mover.heal_fraction(1.0)
	boss._victim = other
	boss._victim_timer = 30.0
	check(RaidBoss.wants_taunt(mover, boss) and not RaidBoss.wants_taunt(other, boss), "a tank wants to provoke while the boss is on someone else")
	mover.target = boss
	var provoke := ClassData.find_skill(&"defender", "provoke")
	check(mover._shape_score(provoke, 1.0, 1.0) >= 8.0, "the AI Defender scores its provoke on the raid boss")
	boss.force_special("buster")
	check(boss.telegraphs.size() == 1 and String(boss.telegraphs[0].kind) == "buster", "the buster aims at the threat holder")
	var before := other.hp
	boss.tick(RaidBoss.TELEGRAPH + 0.1)
	var plain_loss := float(before - other.hp) / float(other.max_hp)
	check(plain_loss > 0.6 and plain_loss < 0.8, "a non-tank loses ~70%% (%.2f)" % plain_loss)
	other.heal_fraction(1.0)
	boss.taunt(mover, 4.0)
	check(boss._victim == mover and boss.is_tank(mover), "the provoke turns the boss and marks the tank")
	boss._cycle = 99.0
	boss.force_special("buster")
	before = mover.hp
	boss.tick(RaidBoss.TELEGRAPH + 0.1)
	var tank_loss := float(before - mover.hp) / float(mover.max_hp)
	check(tank_loss > 0.25 and tank_loss < 0.45, "the tank takes it at half (%.2f)" % tank_loss)
	mover.heal_fraction(1.0)
	other.heal_fraction(1.0)

	# Adds at 75%, a shield while they live.
	boss.take_hit(int(boss.max_hp * 0.26), false, Color.WHITE, hero)
	check(boss.add_waves == 1 and boss.adds.size() == RaidBoss.ADDS and boss.shielded(), "75%%: adds come and shield the boss (%d)" % boss.adds.size())
	var hp_shielded := boss.hp
	boss.take_hit(1000, false, Color.WHITE, hero)
	check(hp_shielded - boss.hp == int(round(1000 * RaidBoss.SHIELD_TAKEN)), "the shield cuts damage (%d)" % (hp_shielded - boss.hp))
	check(run.status_text().contains("สมุน"), "the line says to kill the adds")
	_kill_all(boss.adds, hero)
	boss.tick(0.6)
	check(not boss.shielded(), "the shield breaks when the adds are dead")
	# Phase two at 50%.
	var atk_scale := boss._atk_scale
	boss.take_hit(boss.hp - int(boss.max_hp * 0.49), false, Color.WHITE, hero)
	check(boss.phase == 1 and boss.add_waves == 2 and is_equal_approx(boss._atk_scale, atk_scale * RaidBoss.PHASE_ATK), "50%: phase two, harder, more adds")
	_kill_all(boss.adds, hero)
	# Enrage.
	boss.telegraphs.clear()
	boss._clear_shapes()
	boss.tick(RaidBoss.ENRAGE_TIME)
	check(boss.enraged and boss.phase == 2 and String(boss.template.name).contains("คลั่ง"), "the enrage timer runs out: it goes berserk")
	check(boss._atk_scale >= atk_scale * RaidBoss.PHASE_ATK * RaidBoss.ENRAGE_ATK - 0.01, "and hits far harder")

	# The kill and the rewards.
	_kill_all(boss.adds, hero)
	boss.telegraphs.clear()
	boss._clear_shapes()
	var gold_before := int(Game.profile.gold)
	var cores_before := Game.jewel_count(SetGearData.CORE)
	var purple_before := Game.jewel_count("purple")
	boss.take_hit(boss.hp + 10, false, Color.WHITE, hero)
	run.step(0.016)
	check(run.state == "ending" and bool(run.result.cleared), "the boss falls: cleared")
	var paid: Dictionary = run.result.paid
	check(not paid.is_empty() and bool(paid.first), "the first clear of the day pays the chest")
	check(int(Game.profile.gold) >= gold_before + int(paid.gold), "gold paid")
	check(Game.jewel_count(SetGearData.CORE) == cores_before + 1 and Game.jewel_count("purple") >= purple_before + 6, "set core and jewels in the bag")
	check(int(Game.paragon().exp) != exp_before or int(Game.paragon().level) > 250, "EXP paid")
	check(int(Game.profile.flags.get(RaidData.F_CLEARS, 0)) == 1 and not RaidData.first_chest_ready(), "the clear is counted and the chest is taken")
	var gold_after := int(Game.profile.gold)
	check(RaidData.claim(RandomNumberGenerator.new()).is_empty(), "the same entry cannot be claimed twice")
	run._victory()
	check(int(Game.profile.gold) == gold_after and Game.jewel_count(SetGearData.CORE) == cores_before + 1, "a second victory call pays nothing")
	run.step(RaidRun.END_DELAY + 0.1)
	check(run.state == "done" and not finished_result.is_empty(), "the run ends and tells Main")
	check(RaidBoss.active == null or not is_instance_valid(RaidBoss.active) or RaidBoss.active.is_dead(), "no live raid boss left for the AI to dodge")

	# A second entry the same day: the smaller reward.
	check(RaidData.enter() == "" and RaidData.runs_left() == 0, "the second entry of the day")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var again := RaidData.claim(rng)
	check(not again.is_empty() and not bool(again.first) and int(again.gold) < int(paid.gold), "the second clear pays without the chest")

	# A wipe, and the hero getting back up.
	Game.profile.flags.erase(RaidData.F_DAY)
	RaidData.enter()
	var run2 := RaidRun.new()
	run2.setup(zone, hero, 99)
	zone.add_child(run2)
	run2.set_process(false)
	run2.state = "fight"
	run2.floor_no = 2
	hero._dead = true
	run2._on_hero_died()
	run2.step(RaidRun.REVIVE_DELAY + 0.1)
	check(not hero.is_dead() and run2.hero_falls == 1, "the fallen hero gets up while mates stand")
	var gold_wipe := int(Game.profile.gold)
	hero._dead = true
	for c in zone.companions:
		c._dead = true
	run2.step(0.016)
	check(run2.state == "ending" and not bool(run2.result.cleared) and (run2.result.paid as Dictionary).is_empty(), "nobody standing: a wipe, no reward")
	check(int(Game.profile.gold) == gold_wipe and RaidData.open_run() != "", "a wipe pays nothing")
	check(not hero.is_dead(), "the hero stands again after the wipe (back to town)")
	for c in zone.companions:
		c._dead = false

	# The keeper's screen and the menu entry build.
	var screen := RaidScreen.new()
	add_child(screen)
	screen.open_lobby()
	check(screen.is_open, "the keeper's screen opens")
	var texts: PackedStringArray = []
	for label in screen.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	var all := "\n".join(texts)
	check(all.contains(RaidData.runs_text()) and all.contains(RaidData.BOSS_NAME) and not all.contains("%d") and not all.contains("%s"), "it shows the day's entries and the boss, no broken format")
	screen.show_result(finished_result)
	screen.close_screen()
	get_tree().paused = false
	screen.queue_free()

	zone.queue_free()
	await zone.tree_exited
	await get_tree().process_frame
	print("RAID: %d checks, %d failures" % [checks, failures])
	get_tree().quit(failures)


func _kill_all(list: Array, hero: Hero) -> void:
	for m in list.duplicate():
		if is_instance_valid(m) and not m.is_dead():
			m.take_hit(m.hp + 10, false, Color.WHITE, hero)


func _has_item(items: Array, id: String) -> bool:
	return _count_of(items, id) > 0


func _count_of(items: Array, id: String) -> int:
	var n := 0
	for item in items:
		if String(item.get("id", "")) == id:
			n += int(item.get("count", 1))
	return n
