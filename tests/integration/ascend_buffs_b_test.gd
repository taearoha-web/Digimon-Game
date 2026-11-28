extends Node3D
## The ★500 Ascension buffs of the Priest, Summoner, Defender, Dark Lord and Bard
## (AscendBuffsB), cast for real by the hero (StarSkillSequence) and on its party, and on
## the AI (a party companion, guild war fighters: Rival._resolve / _hit / _tick_status):
##   priest   แสงฟื้นต่อเนื่อง   party: 3% max HP every second, statuses cleansed every 5 s
##   summoner พันธสัญญาไททัน    a Titan for 60 s (meta ascend_titan); every summon +40% ATK /
##                              DEF / HP / speed; summons last 1.5x (old ones stretched)
##   defender ผู้พิทักษ์ทีม      party: the Defender takes 50% of a member's damage (its own
##                              DEF), party DEF +40%; the Defender regenerates 3% a second
##   darklord เพลิงมืดเผาผลาญ   every hit: dark fire 5 s (burn + 15% more damage from all)
##   bard     เสียงสะท้อน        its songs +50% and 2x as long; party attack / run speed +20%
##   godot --headless --path . res://tests/integration/ascend_buffs_b_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
	else:
		print("  ok: ", message)


func _ready() -> void:
	ClassRoles.enabled = false
	Game.set_process(false)
	WorldEvents.festival_enabled = false
	await get_tree().process_frame
	_data()
	await _priest()
	await _defender()
	await _summoner()
	await _darklord()
	await _bard()
	print("ASCEND BUFFS B: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


static func buff_skill(cls: StringName) -> Dictionary:
	return ClassData.find_skill(cls, String(AscendSkillData.IDS[cls][1]))


func _data() -> void:
	var want := {
		&"priest": ["แสงฟื้นต่อเนื่อง", {"regen": 0.03, "cleanse": 5.0}, ["3%", "ทุกวินาที", "ทุก 5 วิ"], true],
		&"summoner": ["พันธสัญญาไททัน", {"titan": true, "summon_boost": 0.4, "summon_life": 1.5}, ["ไททัน", "+40%", "1.5 เท่า"], false],
		&"defender": ["ผู้พิทักษ์ทีม", {"def": 0.4, "aegis": 0.5, "regen": 0.03}, ["50%", "+40%", "3%"], true],
		&"darklord": ["เพลิงมืดเผาผลาญ", {"dark_fire": 5.0, "dark_fire_dps": 0.1, "dark_fire_vuln": 0.15}, ["5 วิ", "10%", "+15%"], false],
		&"bard": ["เสียงสะท้อน", {"aspd": 0.2, "speed": 0.2, "song_boost": 0.5, "song_time": 2.0}, ["50%", "2 เท่า", "+20%"], true],
	}
	for cls in want:
		var skill := buff_skill(cls)
		var buff: Dictionary = skill.fx.buff
		check(String(skill.name) == want[cls][0], "%s buff is named %s" % [cls, want[cls][0]])
		check(float(buff.secs) == 60.0 and not BuffBook.is_song(buff), "%s buff lasts 60 s and is no song" % cls)
		for key in want[cls][1]:
			check(buff.get(key) == want[cls][1][key], "%s buff %s = %s" % [cls, key, str(want[cls][1][key])])
		for n in want[cls][2]:
			check(String(skill.desc).begins_with("สกิลเทวาลัย • ") and String(skill.desc).contains(n), "%s desc says %s" % [cls, n])
		check(BuffBook.reaches_party(buff) == want[cls][3], "%s buff reaches the party = %s" % [cls, want[cls][3]])
		# The mechanic numbers stay put at every skill star.
		var ranked: Dictionary = SkillRank.scaled_fx(skill.fx, 5).buff
		for key in ["regen", "cleanse", "aegis", "summon_boost", "summon_life", "dark_fire", "dark_fire_vuln", "song_boost", "song_time"]:
			if buff.has(key):
				check(is_equal_approx(float(ranked[key]), float(buff[key])), "%s %s stays %s at skill ★5" % [cls, key, str(buff[key])])
	var aegis: Dictionary = buff_skill(&"defender").fx.buff
	for key in ["guard", "shield", "reflect", "hp"]:
		check(not aegis.has(key), "the Defender's old %s is gone" % key)
	check(not buff_skill(&"defender").fx.has("heal"), "the Defender's buff no longer heals 30% on the cast")
	check(is_equal_approx(float(aegis.def), 0.4), "the Defender's DEF +150% is now the party's +40%")
	var shared := BuffBook.party_part(aegis)
	check(shared.has("def") and shared.has("aegis") and not shared.has("regen"), "the party gets the DEF and the guard link, not the Defender's regen")
	var aria := BuffBook.party_part(buff_skill(&"bard").fx.buff)
	check(aria.has("aspd") and aria.has("speed") and not aria.has("song_boost"), "the party gets the aria's attack / run speed, not its song power")


# --- helpers ----------------------------------------------------------------------

func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "Ascend QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = JobData.ASCEND_ADV
	Game.paragon()["level"] = AscendSkillData.STAR
	Game.profile.hp = 99999
	Game.profile.mp = 99999


func _field() -> Node3D:
	var field := Node3D.new()
	add_child(field)
	return field


func _hero(cls: StringName, field: Node3D) -> Hero:
	_profile(cls)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.refresh_stats()
	Game.profile.hp = int(hero.stats.max_hp)
	hero.stats["dodge"] = 0.0
	return hero


## A party companion beside the hero (its own frame off: the test drives it).
func _buddy(hero: Hero, field: Node3D, cls := &"warrior") -> Companion:
	var buddy := Companion.new()
	buddy.hero = hero
	buddy.field = field
	buddy.member = {"class": cls, "name": "QA %s" % cls, "level": 100}
	buddy.stats = {"atk": 100.0, "def": 0.0, "dodge": 0.0, "crit": 0.0, "max_hp": 1000, "max_mp": 100, "speed": 5.0}
	buddy.max_hp = 1000
	buddy.hp = 1000
	field.add_child(buddy)
	buddy.set_physics_process(false)
	buddy.set_process(false)
	buddy.stats["dodge"] = 0.0
	buddy.hp = buddy.max_hp
	buddy.global_position = hero.global_position + Vector3(2, 0, 0)
	return buddy


func _fighter(field: Node3D, cls: StringName, team: int, at: Vector3, hero: Node3D, seed_value: int) -> GuildFighter:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var f := GuildFighter.new()
	f.setup_fighter(GuildWarData.make_fighter(cls, 2, "QA %s %d" % [cls, seed_value], rng), team, hero, at, "[QA]")
	field.add_child(f)
	f.set_physics_process(false)
	f.global_position = at
	f._frozen = false
	f._dodge = 0.0
	f._guard_until = 0
	return f


## The hero casts its ★500 buff for real (Hero._cast_now: the star sequence lands it).
func _cast(hero: Hero, cls: StringName) -> void:
	var skill := buff_skill(cls)
	hero._cast_until = 0
	hero.cooldowns.clear()
	Game.profile.mp = 99999
	check(Game.skill_unlocked(skill), "%s: the buff is unlocked for the Ascended hero" % cls)
	hero._cast_now(skill)
	await _wait(1.3)
	check(BuffBook.contains(hero._buffs, String(skill.id), false), "%s: the cast puts %s on the hero" % [cls, skill.id])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _entry(list: Array, id: String) -> Dictionary:
	for b in list:
		if String((b as Dictionary).get("skill_id", "")) == id and int(b.until) > Time.get_ticks_msec():
			return b
	return {}


func _clear(field: Node3D) -> void:
	field.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# --- the five buffs -----------------------------------------------------------------

func _priest() -> void:
	var field := _field()
	var hero := _hero(&"priest", field)
	var buddy := _buddy(hero, field)
	await get_tree().process_frame
	await _cast(hero, &"priest")
	var id := "halo_of_eternity"
	check(not _entry(buddy._book.buffs, id).is_empty(), "priest: the party member gets the halo")
	# Regeneration: 3% of max HP a second.
	var max_hp := int(hero.stats.max_hp)
	Game.profile.hp = max_hp / 2
	buddy.hp = buddy.max_hp / 2
	AscendBuffsB.tick(hero, 1.0)
	AscendBuffsB.tick(buddy, 1.0)
	check(int(Game.profile.hp) == max_hp / 2 + int(ceil(max_hp * 0.03)), "priest: the hero regenerates 3%% a second (%d -> %d of %d)" % [max_hp / 2, int(Game.profile.hp), max_hp])
	check(buddy.hp == buddy.max_hp / 2 + int(ceil(buddy.max_hp * 0.03)), "priest: the companion regenerates 3%% a second (%d of %d)" % [buddy.hp, buddy.max_hp])
	AscendBuffsB.tick(hero, 2.0)
	check(int(Game.profile.hp) == max_hp / 2 + 3 * int(ceil(max_hp * 0.03)), "priest: one tick each second (3 s -> 9%)")
	# The cleanse: every 5 s (the first came with the first tick).
	var now := Time.get_ticks_msec()
	hero._slow_until = now + 30000
	hero.apply_enemy_debuff("weaken", 0.3, 30.0)
	hero.apply_enemy_debuff("shred", 0.3, 30.0)
	AscendBuffsB.set_player_fire(hero, 10.0, 5.0, 0.15)
	buddy.apply_slow(30.0)
	AscendBuffsB.tick(hero, 1.5)
	AscendBuffsB.tick(buddy, 3.5)
	check(hero.debuff_left("weaken") > 0.0 and hero._slow_until > now, "priest: statuses wait for the next cleanse")
	AscendBuffsB.tick(hero, 1.6)
	AscendBuffsB.tick(buddy, 1.6)
	var t := Time.get_ticks_msec()
	check(hero._slow_until <= t and hero.debuff_left("weaken") == 0.0 and hero.debuff_left("shred") == 0.0, "priest: the hero's slow, weakness and armour crack are cleansed at 5 s")
	check(AscendBuffsB.taken_mult(hero) == 1.0 and hero.get_node_or_null("DarkFire") == null or hero.get_node("DarkFire").is_queued_for_deletion(), "priest: dark fire on the hero is cleansed")
	check(buddy._slow_until <= t, "priest: the companion's slow is cleansed")
	# The AI: a guild war Priest casts it, its mate gets it; it heals and cleanses a fighter.
	var caster := _fighter(field, &"priest", GuildFighter.TEAM_ALLY, Vector3(30, 0, 0), hero, 11)
	var mate := _fighter(field, &"warrior", GuildFighter.TEAM_ALLY, Vector3(32, 0, 0), hero, 12)
	await get_tree().process_frame
	caster._resolve(buff_skill(&"priest"), null, Vector3.ZERO)
	check(not _entry(caster._buff_art.buffs, id).is_empty(), "priest AI: the caster has the halo")
	check(not _entry(mate._buff_art.buffs, id).is_empty(), "priest AI: its party mate gets it")
	mate.hp = mate.max_hp / 2
	var before := mate.hp
	mate._stun = 3.0
	mate._slow = 3.0
	mate.apply_dark_fire(50.0, 5.0, 0.15, null)
	mate.apply_burn(50.0, 5.0)
	mate.apply_shred(0.3, 10.0)
	mate._tick_status(0.0001)
	check(mate._stun == 0.0 and mate._slow == 0.0 and mate.dark_fire_left == 0.0 and mate._burn_time == 0.0 and mate.debuff_left("shred") == 0.0, "priest AI: the fighter's stun, slow, burn, dark fire and armour crack are cleansed")
	mate._tick_status(1.0)
	check(mate.hp >= before + int(ceil(mate.max_hp * 0.03)) - 1, "priest AI: the fighter regenerates 3%% a second (%d -> %d)" % [before, mate.hp])
	await _clear(field)


func _defender() -> void:
	var field := _field()
	var hero := _hero(&"defender", field)
	var buddy := _buddy(hero, field)
	await get_tree().process_frame
	var def_before := float(hero.stats.def)
	Game.profile.hp = int(hero.stats.max_hp) - 1000
	var hp_cast := int(Game.profile.hp)
	await _cast(hero, &"defender")
	var id := "aegis_of_eternity"
	var own := _entry(hero._buffs, id)
	check(int(own.get("aegis_by", 0)) == hero.get_instance_id(), "defender: its own entry names it the guardian")
	check(int(Game.profile.hp) <= hp_cast, "defender: no 30% heal on the cast any more")
	check(float(hero.stats.def) > def_before * 1.35, "defender: its DEF +40%% (%.0f -> %.0f)" % [def_before, float(hero.stats.def)])
	var got := _entry(buddy._book.buffs, id)
	check(int(got.get("aegis_by", 0)) == hero.get_instance_id() and is_equal_approx(float(got.get("def", 0.0)), 0.4) and not got.has("regen"), "defender: the member gets DEF +40% and the guard link, not the regen")
	check(is_equal_approx(buddy._book.total("def"), 0.4), "defender: the member's DEF counts +40%")
	# The guard: the member takes half, the Defender the other half through its own DEF.
	hero.stats["dodge"] = 0.0
	var hp0 := int(Game.profile.hp)
	var armour := float(buddy.stats.def) * (1.0 + buddy._book.total("def"))
	buddy.hp = buddy.max_hp
	buddy.take_damage(400.0, null)
	var member_took := buddy.max_hp - buddy.hp
	var guard_took := hp0 - int(Game.profile.hp)
	var expect_guard := int(round(HeroStats.mitigate(200.0, hero.effective_def())))
	check(member_took == maxi(1, int(round(HeroStats.mitigate(200.0, armour)))), "defender: the member takes half (%d, its DEF on 200 of 400 raw)" % member_took)
	check(absi(guard_took - expect_guard) <= 1 + int(200.0 * BuffBook.GUARD_CAP), "defender: the Defender takes the other half after its own DEF (%d, ~%d)" % [guard_took, expect_guard])
	check(guard_took > 0 and guard_took < 200, "defender: its DEF cut its share (%d < 200)" % guard_took)
	# The Defender itself is never redirected; out of reach nobody is.
	hp0 = int(Game.profile.hp)
	hero.take_damage(400.0, null)
	check(hp0 - int(Game.profile.hp) > 0, "defender: it takes its own blows in full")
	buddy.global_position = hero.global_position + Vector3(AscendBuffsB.AEGIS_REACH + 5.0, 0, 0)
	buddy.hp = buddy.max_hp
	buddy.take_damage(400.0, null)
	check(buddy.max_hp - buddy.hp == maxi(1, int(round(HeroStats.mitigate(400.0, armour)))), "defender: beyond %d m the member takes it all" % int(AscendBuffsB.AEGIS_REACH))
	# Regeneration: the Defender's own 3% a second, never the party's.
	Game.profile.hp = int(hero.stats.max_hp) / 2
	buddy.hp = buddy.max_hp / 2
	AscendBuffsB.tick(hero, 1.0)
	AscendBuffsB.tick(buddy, 1.0)
	check(int(Game.profile.hp) == int(hero.stats.max_hp) / 2 + int(ceil(float(hero.stats.max_hp) * 0.03)), "defender: it regenerates 3% a second")
	check(buddy.hp == buddy.max_hp / 2, "defender: the member does not regenerate")
	# The AI: a guild war Defender guards its party mate the same way.
	var caster := _fighter(field, &"defender", GuildFighter.TEAM_ALLY, Vector3(30, 0, 0), hero, 21)
	var mate := _fighter(field, &"warrior", GuildFighter.TEAM_ALLY, Vector3(32, 0, 0), hero, 22)
	await get_tree().process_frame
	caster._resolve(buff_skill(&"defender"), null, Vector3.ZERO)
	var link := _entry(mate._buff_art.buffs, id)
	check(int(link.get("aegis_by", 0)) == caster.get_instance_id(), "defender AI: its mate is guarded by it")
	check(mate._def_boost >= 1.4 - 0.001, "defender AI: the mate's DEF +40%")
	var c0 := caster.hp
	var m0 := mate.hp
	mate.take_damage(4000.0, null)
	var m_took := m0 - mate.hp
	var c_took := c0 - caster.hp
	check(c_took > 0, "defender AI: the guardian takes a share (%d)" % c_took)
	var solo := int(round(HeroStats.mitigate(4000.0, float(mate.stats.def))))
	check(m_took <= int(ceil(solo * 0.5)) + 1, "defender AI: the mate takes about half (%d of %d)" % [m_took, solo])
	# A hit already cut by the mate's DEF (Mob.take_hit) is split too.
	c0 = caster.hp
	m0 = mate.hp
	mate.take_hit(1000, false, Color.WHITE, hero)
	check(caster.hp < c0 and m0 - mate.hp <= int(ceil(500.0 * mate.war_scale)) + 1, "defender AI: a hero's hit on the mate is split as well")
	await _clear(field)


func _summoner() -> void:
	var field := _field()
	var hero := _hero(&"summoner", field)
	await get_tree().process_frame
	var old := Summon.new()
	old.setup(hero, "qa_wolf", {"kind": "wolf", "count": 1, "secs": 120.0, "interval": 1.0}, 1.0, 0, 1, 1)
	field.add_child(old)
	hero._summons = [old]
	await get_tree().process_frame
	var old_max := old.max_hp
	var old_raw := old._basic_raw()
	await _cast(hero, &"summoner")
	var titan := AscendBuffsB.titan_of(hero)
	check(titan is Summon and titan.has_meta(AscendBuffsB.TITAN_META), "summoner: a Titan stands, carrying meta ascend_titan")
	if titan is Summon:
		var t := titan as Summon
		check(t._kind_id == "titan" and t._visual is TitanVisual, "summoner: the Titan is the code-sculpted giant (TitanVisual)")
		check(absf(t.life - 60.0) < 2.0, "summoner: it lasts the buff's 60 s (%.1f)" % t.life)
		check(t.is_in_group("summons") and not hero._summons.has(t), "summoner: it is a summon outside the summon slots")
		check(t.max_hp > old_max * 2, "summoner: it is far tougher than a creature (%d HP)" % t.max_hp)
	check(old.life > 120.0 + 60.0 - 3.0 and old.has_meta(AscendBuffsB.META_LIFE), "summoner: the summon out at the cast lasts 1.5x (%.1f s left)" % old.life)
	var life_after := old.life
	await _wait(0.4)
	check(is_equal_approx(old.ascend_boost, 0.4), "summoner: the old summon is boosted +40%")
	check(old.max_hp == int(round(old_max * 1.4)), "summoner: its max HP +40%% (%d -> %d)" % [old_max, old.max_hp])
	check(absf(old._basic_raw() / old_raw - 1.4) < 0.01, "summoner: its ATK +40%")
	# Casting again stretches nobody twice.
	hero._cast_until = 0
	hero.cooldowns.clear()
	AscendBuffsB.after_cast(hero, buff_skill(&"summoner").fx.buff.merged({"titan": false}, true))
	check(old.life <= life_after, "summoner: a summon is stretched only once")
	var fresh := Summon.new()
	fresh.setup(hero, "qa_wolf2", {"kind": "wolf", "count": 1, "secs": 120.0, "interval": 1.0}, 1.0, 0, 1, 1)
	check(is_equal_approx(fresh.life, 180.0), "summoner: a summon called during the buff lasts 1.5x (%.0f s)" % fresh.life)
	fresh.free()
	# The AI: an allied guild Summoner's Titan is a Summon, an enemy's a SummonMob.
	var ally := _fighter(field, &"summoner", GuildFighter.TEAM_ALLY, Vector3(30, 0, 0), hero, 31)
	var enemy := _fighter(field, &"summoner", GuildFighter.TEAM_ENEMY, Vector3(-30, 0, 0), hero, 32)
	await get_tree().process_frame
	var spec := {"kind": "wolf", "count": 1, "secs": 120.0, "interval": 1.0}
	var foe_pet := SummonMob.new()
	foe_pet.setup_summon(enemy, "qa_wolf", spec, 1.0, 0, 1, 1)
	field.add_child(foe_pet)
	enemy._summons = [foe_pet]
	await get_tree().process_frame
	var pet_def := float(foe_pet.stats.def)
	ally._resolve(buff_skill(&"summoner"), null, Vector3.ZERO)
	enemy._resolve(buff_skill(&"summoner"), null, Vector3.ZERO)
	var at := AscendBuffsB.titan_of(ally)
	var et := AscendBuffsB.titan_of(enemy)
	check(at is Summon and at.has_meta(AscendBuffsB.TITAN_META), "summoner AI: an allied fighter calls a Titan (Summon)")
	check(et is SummonMob and et.has_meta(AscendBuffsB.TITAN_META) and (et as SummonMob).visual is TitanVisual, "summoner AI: an enemy fighter calls a Titan (SummonMob)")
	check(foe_pet.life > 120.0 + 60.0 - 3.0, "summoner AI: the enemy's summon lasts 1.5x (%.1f)" % foe_pet.life)
	AscendBuffsB.sync_summon(foe_pet, enemy)
	check(is_equal_approx(float(foe_pet.stats.def), pet_def * 1.4) and is_equal_approx(foe_pet._atk_scale, 1.4), "summoner AI: the enemy's summon gets +40% ATK / DEF")
	await _clear(field)


func _darklord() -> void:
	var field := _field()
	var hero := _hero(&"darklord", field)
	await get_tree().process_frame
	var mob := Mob.new()
	mob.setup(&"forest_orc", 100, hero.global_position + Vector3(0, 0, 2.5), hero)
	field.add_child(mob)
	mob.set_physics_process(false)
	mob.hp = 1000000
	mob.max_hp = 1000000
	await get_tree().process_frame
	await _cast(hero, &"darklord")
	check(mob.dark_fire_left == 0.0 and is_equal_approx(mob.taken_mult(), 1.0), "darklord: nothing burns before a hit")
	hero._deal(mob, 1.0, Color.WHITE, &"slash", false)
	check(absf(mob.dark_fire_left - 5.0) < 0.01, "darklord: a hit sets dark fire for 5 s")
	check(mob.get_node_or_null("DarkFire") is AscendBuffsB.DarkFlame, "darklord: a dark-purple flame burns on it")
	check(is_equal_approx(mob.taken_mult(), 1.15), "darklord: it takes +15% damage")
	var hp0 := mob.hp
	mob.take_hit(1000, false, Color.WHITE, null)
	check(hp0 - mob.hp == 1150, "darklord: a hit from anyone else lands 15%% harder (%d)" % (hp0 - mob.hp))
	mob.apply_vulnerable(0.2, 5.0)
	check(is_equal_approx(mob.taken_mult(), 1.35), "darklord: dark fire adds to the dance's vulnerability (one multiplier)")
	mob._vuln = 0.0
	hp0 = mob.hp
	mob._tick_status(0.5)
	var dps := HeroStats.burn_dps(float(hero.stats.atk), 0.1, float(mob.stats.def))
	check(hp0 - mob.hp == maxi(1, int(dps * 0.5 * 1.15)), "darklord: dark fire burns 10%% ATK a second (%d a half-second)" % (hp0 - mob.hp))
	mob._tick_status(4.6)
	check(mob.dark_fire_left == 0.0 and is_equal_approx(mob.taken_mult(), 1.0), "darklord: it ends after 5 s")
	await get_tree().process_frame
	check(mob.get_node_or_null("DarkFire") == null, "darklord: and the flame goes out")
	# The AI: a companion Dark Lord with the buff ignites what it hits.
	var buddy := _buddy(hero, field, &"darklord")
	var crown := buff_skill(&"darklord")
	buddy._book.add(crown.fx.buff, crown.color, crown.name, false, crown.id)
	buddy._deal(mob, 1.0, Color.WHITE, &"slash", false, null)
	check(mob.dark_fire_left > 4.9, "darklord AI: a companion's hit sets dark fire")
	# An enemy guild Dark Lord's hit sets dark fire on the hero (15% more taken).
	var foe := _fighter(field, &"darklord", GuildFighter.TEAM_ENEMY, hero.global_position + Vector3(2, 0, 0), hero, 41)
	await get_tree().process_frame
	foe._resolve(crown, null, Vector3.ZERO)
	check(not _entry(foe._buff_art.buffs, "crown_of_dual_realms").is_empty(), "darklord AI: the fighter casts it on itself")
	hero._buffs.clear()
	hero.refresh_stats()
	hero.stats["dodge"] = 0.0
	foe._hit(hero, 0.1, Color.WHITE)
	check(is_equal_approx(AscendBuffsB.taken_mult(hero), 1.15) and hero.get_node_or_null("DarkFire") != null, "darklord AI: its hit sets dark fire on the hero (+15% taken, the flame)")
	var mate := _fighter(field, &"warrior", GuildFighter.TEAM_ALLY, hero.global_position + Vector3(-2, 0, 0), hero, 42)
	await get_tree().process_frame
	foe._hit(mate, 0.1, Color.WHITE)
	check(mate.dark_fire_left > 4.9 and mate.taken_mult() > 1.14, "darklord AI: and on an enemy fighter")
	await _clear(field)


func _bard() -> void:
	var field := _field()
	var hero := _hero(&"bard", field)
	var buddy := _buddy(hero, field)
	await get_tree().process_frame
	var speed_before := float(hero.stats.speed)
	await _cast(hero, &"bard")
	var id := "aria_of_eternity"
	check(is_equal_approx(AscendBuffsB.attack_rate(hero._buffs), 1.2), "bard: the hero swings 20% faster")
	check(float(hero.stats.speed) > speed_before * 1.19, "bard: the hero runs 20%% faster (%.2f -> %.2f)" % [speed_before, float(hero.stats.speed)])
	var got := _entry(buddy._book.buffs, id)
	check(not got.is_empty() and not got.has("song_boost"), "bard: the party gets the aria (its speed, not its song power)")
	check(is_equal_approx(AscendBuffsB.attack_rate(buddy._book.buffs), 1.2) and is_equal_approx(AscendBuffsB.run_rate(buddy), 1.2), "bard: the companion swings and runs 20% faster")
	# Its songs: +50% and twice as long, for the party too.
	var song := ClassData.find_skill(&"bard", "valor_march")
	hero._apply_self_fx(hero._ranked(song))
	var sung := _entry(hero._buffs, "valor_march")
	var base := SkillRank.buff_value(song.fx.buff, "atk", Game.effective_rank(song))
	check(is_equal_approx(float(sung.get("atk", 0.0)), base * 1.5), "bard: its song is 50%% stronger (ATK %.3f)" % float(sung.get("atk", 0.0)))
	check(is_equal_approx(float(sung.get("total", 0.0)), 120.0), "bard: and lasts twice as long (%.0f s)" % float(sung.get("total", 0.0)))
	var heard := _entry(buddy._book.buffs, "valor_march")
	check(is_equal_approx(float(heard.get("atk", 0.0)), base * 1.5) and is_equal_approx(float(heard.get("total", 0.0)), 120.0), "bard: the party hears the stronger, longer song")
	# The aria itself is no song: songs keep their slots.
	check(BuffBook.songs_of(hero._buffs).size() == 1, "bard: the aria takes no song slot")
	# The AI: a guild war Bard sings under its aria too; its mates swing and run faster.
	var caster := _fighter(field, &"bard", GuildFighter.TEAM_ALLY, Vector3(30, 0, 0), hero, 51)
	var mate := _fighter(field, &"warrior", GuildFighter.TEAM_ALLY, Vector3(32, 0, 0), hero, 52)
	await get_tree().process_frame
	caster._resolve(buff_skill(&"bard"), null, Vector3.ZERO)
	check(is_equal_approx(AscendBuffsB.attack_rate(mate._buff_art.buffs), 1.2) and is_equal_approx(AscendBuffsB.run_rate(mate), 1.2), "bard AI: its mate swings and runs 20% faster")
	caster._resolve(song, null, Vector3.ZERO)
	var ai_song := _entry(caster._buff_art.buffs, "valor_march")
	check(is_equal_approx(float(ai_song.get("atk", 0.0)), float(song.fx.buff.atk) * 1.5), "bard AI: its song is 50% stronger")
	var mate_song := _entry(mate._buff_art.buffs, "valor_march")
	check(is_equal_approx(float(mate_song.get("atk", 0.0)), float(song.fx.buff.atk) * 1.5), "bard AI: its mate hears the stronger song")
	# A swing's interval.
	var attack: Dictionary = mate.class_data.attack
	mate._basic_attack(caster)
	check(mate._attack_timer < float(attack.interval) * 1.6 / 1.19, "bard AI: the mate's swing interval is cut (%.2f s)" % mate._attack_timer)
	await _clear(field)
