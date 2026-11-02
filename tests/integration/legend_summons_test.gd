extends Node3D
## Legend summons and the Fairy Spirit: rigs with skill clips, the two moves of
## each legend (stun / freeze), the fairy's heal, summons that stand a while but
## fall to a swarm, AI summoners on both sides, and the Wind Drake -> Fairy save move.
##   XDG_DATA_HOME=/tmp/x godot --headless --path . res://tests/integration/legend_summons_test.tscn
var checks := 0
var failures := 0

## A monster that counts hits, stuns and freezes.
class Dummy:
	extends Mob
	var hits := 0
	var stuns := 0
	var freezes := 0
	func _ready() -> void:
		add_to_group("mobs")
		visual = MonsterVisual.new()
		add_child(visual)
		set_physics_process(false)
	func set_targeted(_on: bool) -> void:
		pass
	func take_hit(amount: int, crit: bool, _color := Color.WHITE, _attacker: Node = null) -> bool:
		hits += 1
		hp = maxi(0, hp - amount)
		return false
	func apply_stun(seconds: float) -> void:
		stuns += 1
		_stun = seconds
	func apply_freeze(seconds: float) -> void:
		freezes += 1
		_stun = seconds


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func dummy(at: Vector3) -> Dummy:
	var d := Dummy.new()
	d.template = MonsterData.get_monster(&"forest_orc")
	d.stats = {"hp": 100000, "atk": 10, "def": 0.0, "exp": 0, "gold": 0}
	d.hp = 100000
	d.max_hp = 100000
	d.hostile = true
	add_child(d)
	d.global_position = at
	return d


func _ready() -> void:
	Game.set_process(false)
	await get_tree().process_frame
	_rigs()
	Game.new_profile(&"summoner", "legend")
	Game.profile.level = 90
	var hero := Hero.new()
	add_child(hero)
	hero.field = self
	hero.refresh_stats()
	await _legend_moves(hero)
	await _fairy(hero)
	await _survivability(hero)
	await _ai_summoners(hero)
	_data_and_save()
	hero.queue_free()
	await get_tree().process_frame
	Game.has_profile = false
	print("LEGEND SUMMONS: ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)


## The rebuilt glb files carry every clip, keep the phone budget, and passed the rig check.
func _rigs() -> void:
	for legend in ["wind_king", "poseidon"]:
		var lv := MonsterVisual.new()
		add_child(lv)
		var lk: Dictionary = Summon.KINDS[legend]
		lv.setup(String(lk.model), float(lk.height), float(lk.hover), lk.tint)
		for key in ["idle", "walk", "run", "attack", "hurt", "die", "skill1", "skill2"]:
			check(lv._clips.has(key), "%s has a %s clip" % [legend, key])
		var tris := 0
		for mi in lv.model.find_children("*", "MeshInstance3D", true, false):
			tris += (mi as MeshInstance3D).mesh.get_faces().size() / 3
		check(tris > 0 and tris <= 22000, "%s stays within the phone budget (%d triangles)" % [legend, tris])
		check(lv.model.find_children("*", "Skeleton3D", true, false).size() == 1, "%s is rigged" % legend)
		lv.queue_free()
	var file := FileAccess.open("res://tools/rig/rig_report.json", FileAccess.READ)
	check(file != null, "the rig report exists")
	if file:
		var report: Dictionary = JSON.parse_string(file.get_as_text())
		for name in ["WindKing", "Poseidon"]:
			var r: Dictionary = report.get(name, {})
			check(r.get("clips", []).has("Skill1") and r.get("clips", []).has("Skill2"), "%s report lists the skill clips" % name)
			var stretch: Dictionary = r.get("stretch", {})
			check(float(stretch.get("worst_shear_cm", 99.0)) < 13.0, "%s: no pose changes an edge by 13 cm or more (worst %.1f)" % [name, float(stretch.get("worst_shear_cm", 99.0))])
			for clip in ["Idle", "Walk", "Run"]:
				check(float(stretch.get(clip, {}).get("shear_p999_cm", 99.0)) < 2.5, "%s %s: locomotion keeps the surface still (p99.9 %.1f cm)" % [name, clip, float(stretch.get(clip, {}).get("shear_p999_cm", 99.0))])
			var before: Dictionary = report.get("_shipped_before", {}).get(name, {})
			check(float(stretch.get("Attack", {}).get("shear_max_cm", 99.0)) < float(before.get("Attack", {}).get("shear_max_cm", 0.0)) * 0.5, "%s: the attack tears the cloth less than half as much as the shipped rig" % name)


func _summon_for(hero: Hero, skill_id: String, kind: String) -> Summon:
	var s := Summon.new()
	s.setup(hero, skill_id, {"kind": kind, "count": 1, "secs": 120.0, "interval": 1.0}, 1.0, 0, 1, 1)
	add_child(s)
	s.set_process(false)
	return s


## The king's whirlwind and slam (stun), Poseidon's maelstrom (stun) and ice (freeze).
func _legend_moves(hero: Hero) -> void:
	check(LegendMoves.moves("wind_king").size() == 2 and LegendMoves.moves("poseidon").size() == 2, "each legend has two moves")
	check(float(LegendMoves.moves("wind_king")[1].stun) == 5.0 and float(LegendMoves.moves("poseidon")[0].stun) == 5.0 and float(LegendMoves.moves("poseidon")[1].freeze) == 5.0, "slam and maelstrom stun 5 s, the ice freezes 5 s")
	check(not bool(Summon.KINDS.wind_king.ranged) and bool(Summon.KINDS.poseidon.ranged) and String(Summon.KINDS.poseidon.projectile) == "orb", "the king fights up close, Poseidon throws water balls")
	for legend in ["wind_king", "poseidon"]:
		var s := _summon_for(hero, "moonwolf_pact" if legend == "wind_king" else "eclipse_sovereign", legend)
		s.global_position = Vector3.ZERO
		for move in LegendMoves.moves(legend):
			var d := dummy(Vector3(2.5, 0, 0))
			s._target = d
			for id in s._move_cds:
				s._move_cds[id] = 99.0
			s._move_cds[move.id] = 0.0
			s._cast_until = 0.0
			s._process(0.05)
			check(s._cast_until > 0.0, "%s casts %s" % [legend, move.id])
			check(s._visual.current == String(move.clip), "%s plays its %s clip" % [legend, move.clip])
			await get_tree().create_timer(float(move.impact) + 0.25).timeout
			check(d.hits == 1, "%s %s hits everyone in its area once" % [legend, move.id])
			if move.has("stun"):
				check(d.stuns == 1 and d.freezes == 0, "%s %s stuns" % [legend, move.id])
			elif move.has("freeze"):
				check(d.freezes == 1, "%s %s freezes" % [legend, move.id])
			else:
				check(d.stuns == 0 and d.freezes == 0, "%s %s only hurts" % [legend, move.id])
			check(float(s._move_cds[move.id]) > 0.0, "%s %s goes on cooldown" % [legend, move.id])
			d.free()
		# A far target: no move is cast, the king walks instead.
		var far := dummy(Vector3(20, 0, 0))
		s._target = far
		for id in s._move_cds:
			s._move_cds[id] = 0.0
		s._cast_until = 0.0
		s._process(0.05)
		check(s._cast_until == 0.0, "%s does not cast at a target out of reach" % legend)
		far.free()
		s.free()
	# Freeze on a real monster: held, with the frost text; bosses resist as they do stuns.
	var mob := Mob.new()
	mob.setup(&"forest_orc", 10, Vector3(5, 0, 5), hero)
	add_child(mob)
	mob.apply_freeze(5.0)
	check(mob._stun == 5.0, "a frozen monster is held for the full 5 s")
	var boss := Mob.new()
	boss.setup(&"mush_king", 10, Vector3(8, 0, 8), hero)
	add_child(boss)
	boss.apply_freeze(5.0)
	check(is_equal_approx(boss._stun, 2.0), "a frozen boss resists like a stun (2 s)")
	mob.free()
	boss.free()


## The Fairy Spirit follows and heals: +20% to the summoner, +10% to allies close to her.
func _fairy(hero: Hero) -> void:
	var skill := ClassData.find_skill(&"summoner", "fairy_spirit")
	check(not skill.is_empty() and int(skill.level) == 84 and String(skill.summon.kind) == "fairy", "Fairy Spirit is the Lv.84 summon")
	check(ClassData.find_skill(&"summoner", "wind_drake").is_empty(), "the Wind Drake is gone")
	check(ResourceLoader.exists("res://assets/icons/skills/fairy_spirit.svg"), "the fairy has an icon")
	var f := _summon_for(hero, "fairy_spirit", "fairy")
	await get_tree().process_frame
	check(f.is_fairy() and f._visual is FairyVisual, "the fairy is a tiny fairy girl (FairyVisual)")
	var body: HeroVisual = (f._visual as FairyVisual).hero_visual
	check(body != null and body.has_wings() and body.flying(), "she flies on her wings")
	check(body.current == "Fly_Hover", "she hovers on the fly clip (%s)" % body.current)
	check(f._visual.height < 0.9 and f.scale.x <= 1.0, "she is tiny (%.2f m)" % f._visual.height)
	check(float(Summon.KINDS.fairy.hover) > 1.0 and body.position.y > 1.0, "she hovers above the ground (%.2f m)" % body.position.y)
	check(f.find_children("SummonAura", "Node3D", true, false).size() == 1, "she carries an aura")
	check(f.find_children("Crown", "MeshInstance3D", true, false).size() == 1, "she wears a crown ring")
	check(f._sigil == null, "no rune circle turns on the ground under a flying fairy")
	var spot := f._fairy_spot()
	check(is_equal_approx(spot.length(), Summon.FAIRY_ORBIT), "her spot is %.1f m from her summoner (%.2f)" % [Summon.FAIRY_ORBIT, spot.length()])
	check(f.global_position.distance_to(hero.global_position) > 1.5, "she starts out on her orbit, not on top of the hero")
	hero.global_position = Vector3(10, 0, 0)
	for i in 30:
		f._process(0.1)
	check(f.global_position.distance_to(hero.global_position) < 3.5, "she keeps beside her summoner (%.1f m)" % f.global_position.distance_to(hero.global_position))
	check(body.position.y > 1.0 and absf(f._visual.position.y) < 0.2, "she still hovers after following (%.2f m, bob %.2f)" % [body.position.y, f._visual.position.y])
	var ally := _summon_for(hero, "wolf_pack", "wolf")
	ally.global_position = hero.global_position + Vector3(2, 0, 0)
	ally.hp = int(ally.max_hp * 0.5)
	Game.profile.hp = int(float(hero.stats.max_hp) * 0.5)
	f._heal_timer = 0.0
	f._process(0.1)
	check(Game.profile.hp >= int(float(hero.stats.max_hp) * 0.5) + int(float(hero.stats.max_hp) * 0.2) - 1, "the summoner is healed 20%% (%d / %d)" % [Game.profile.hp, int(hero.stats.max_hp)])
	check(ally.hp >= int(ally.max_hp * 0.6) - 1, "an ally beside her is healed 10%")
	check(is_equal_approx(f._heal_timer, Summon.FAIRY_EVERY), "the next heal is 10 s away")
	f.free()
	ally.free()


## A summon takes at most 20% of its health from one hit and 36% from one pile-on, so it
## stands through a burst and still falls when the burst keeps coming.
func _survivability(hero: Hero) -> void:
	var s := _summon_for(hero, "moonwolf_pact", "wind_king")
	check(s.max_hp > int(float(hero.stats.max_hp) * 1.1), "a legend has more health than a normal summon (%d vs hero %d)" % [s.max_hp, int(hero.stats.max_hp)])
	var w := _summon_for(hero, "wolf_pack", "wolf")
	check(w.max_hp < s.max_hp, "a wolf has less health than a legend")
	# In a war or a duel the attacker fights with a war scale: one hit and one pile-on are capped.
	var fighter := Rival.new()
	fighter.war_scale = 6.0
	BurstGuard.clear()
	s.take_damage(1.0e9, fighter)
	check(s.hp >= int(s.max_hp * 0.8) - 1, "one fighter's hit never takes more than 20%% (%d / %d)" % [s.hp, s.max_hp])
	for i in 12:
		s.take_damage(1.0e9, fighter)
	check(not s.is_dead() and s.hp >= int(s.max_hp * 0.6), "a pile-on inside 2 s stops near 36%% (%d / %d)" % [s.hp, s.max_hp])
	for burst in 3:
		BurstGuard.clear()
		for i in 8:
			s.take_damage(1.0e9, fighter)
	check(s.is_dead(), "kept under fire for three windows, it falls")
	BurstGuard.clear()
	# Monsters in the field still hit in full.
	w.take_damage(1.0e9)
	check(w.is_dead(), "a monster's hit lands in full: a wolf at 0 HP dies")
	fighter.free()
	s.free()
	w.free()


## Rivals, guild fighters and companions of the summoner class use their creatures.
func _ai_summoners(hero: Hero) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var info := GuildWarData.make_fighter(&"summoner", GuildWarData.DIVINE, "Enemy", rng)
	var rival := Rival.new()
	rival.setup_rival(info, Vector3(6, 0, 0), hero, "[x]")
	add_child(rival)
	rival.position = Vector3(6, 0, 0)
	rival.start_fight()
	rival.set_physics_process(false)
	rival.war_scale = 2.0
	var pact := ClassData.find_skill(&"summoner", "moonwolf_pact")
	var treant := ClassData.find_skill(&"summoner", "ancient_treant")
	check(rival._score(pact, "summon", 5.0, 1.0) > 8.0 and rival._score(treant, "summon", 5.0, 1.0) > 8.0, "a rival summoner rates its summons highly")
	check(rival._stars() == 200, "the war rival has 200 stars, so its star summons are allowed")
	rival._summon(pact)
	await get_tree().process_frame
	check(rival._summons.size() == 1 and rival._summons[0] is SummonMob, "the enemy's king is a monster (SummonMob)")
	var king := rival._summons[0] as SummonMob
	check(king.is_in_group("mobs") and not king.is_in_group("summons"), "it stands on the monster side")
	check(king.stats.atk > 0.0 and king.max_hp > 0 and String(king.template.name) == "ราชาวานรวายุ", "it carries its own stats and name")
	check(rival._score(pact, "summon", 5.0, 1.0) == 0.0, "the same skill is not cast again while its creature lives")
	check(king._targets().has(hero), "it fights the hero's side")
	# Its moves warn the hero first, then land war-scaled, capped by BurstGuard like any fighter's hit.
	hero.global_position = king.global_position + Vector3(2, 0, 0)
	Game.profile.hp = int(hero.stats.max_hp)
	# No random dodge: the check is about the slam landing, not the hero's luck.
	hero.stats.dodge = 0.0
	for id in king._move_cds:
		king._move_cds[id] = 0.0
	king.set_physics_process(false)
	king._cast_move(LegendMoves.moves("wind_king")[1], hero)
	check(king._winding, "the slam locks the king while it warns")
	# The blow lands on the move's own timer; wait for it (a hitstop or a busy frame can
	# stretch the game clock past a fixed wait), up to a generous deadline.
	var deadline := Time.get_ticks_msec() + int((float(LegendMoves.moves("wind_king")[1].impact) + 3.0) * 1000.0)
	while Game.profile.hp >= int(hero.stats.max_hp) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(Game.profile.hp < int(hero.stats.max_hp), "the slam lands on the hero (%d / %d)" % [Game.profile.hp, int(hero.stats.max_hp)])
	check(Game.profile.hp >= int(float(hero.stats.max_hp) * 0.79), "one slam never takes more than 20%% of the hero (%d / %d)" % [Game.profile.hp, int(hero.stats.max_hp)])
	# Killed by the hero's side: no EXP, no loot, just gone.
	var exp_before: int = Game.profile.exp
	king.take_hit(king.max_hp, false)
	check(not king.is_dead() and king.hp >= int(king.max_hp * 0.8) - 1, "in a duel the hero's hit on it is capped at 20%% (%d / %d)" % [king.hp, king.max_hp])
	for i in 30:
		if king.is_dead():
			break
		BurstGuard.clear()
		king.take_hit(king.max_hp, false)
	check(king.is_dead() and Game.profile.exp == exp_before, "a slain enemy summon gives nothing")
	BurstGuard.clear()
	# Its summoner falls: the creatures go with it.
	rival._summon(treant)
	await get_tree().process_frame
	check(rival._summons.size() == 1, "the treant is called")
	rival._dismiss_summons()
	check(rival._summons.is_empty(), "dismissed with its summoner")
	rival.stop_fight()
	rival.free()
	# A fighter of our guild calls allies (Summon), the enemy's calls monsters.
	var ally_info := GuildWarData.make_fighter(&"summoner", GuildWarData.DIVINE, "Friend", rng)
	var ally := GuildFighter.new()
	ally.setup_fighter(ally_info, GuildFighter.TEAM_ALLY, hero, Vector3(-6, 0, 0), "[us]")
	add_child(ally)
	ally.start_fight()
	ally._summon(pact)
	await get_tree().process_frame
	check(ally._summons.size() == 1 and ally._summons[0] is Summon and (ally._summons[0] as Summon).is_in_group("summons"), "our guild's summoner calls an ally king")
	var friend := ally._summons[0] as Summon
	check(friend.hero == null and friend._summoner_stats().has("atk"), "the ally king draws its strength from the fighter, not the hero")
	ally._dismiss_summons()
	ally.stop_fight()
	ally.free()
	var enemy := GuildFighter.new()
	enemy.setup_fighter(ally_info, GuildFighter.TEAM_ENEMY, hero, Vector3(6, 0, 0), "[them]")
	add_child(enemy)
	enemy.start_fight()
	enemy._summon(ClassData.find_skill(&"summoner", "fairy_spirit"))
	await get_tree().process_frame
	check(enemy._summons.size() == 1 and enemy._summons[0] is SummonMob and (enemy._summons[0] as SummonMob).is_fairy() and (enemy._summons[0] as SummonMob).is_in_group("gw_team1"), "the rival guild's fairy is an enemy of the hero's team")
	var efairy := enemy._summons[0] as SummonMob
	enemy.hp = int(enemy.max_hp * 0.5)
	efairy._heal_timer = 0.0
	efairy._tick_fairy(0.05)
	check(enemy.hp >= int(enemy.max_hp * 0.7) - 1, "the enemy fairy heals her fighter 20%")
	enemy._dismiss_summons()
	enemy.stop_fight()
	enemy.free()
	# A party companion of the summoner class.
	var buddy := Companion.new()
	buddy.setup({"class": "summoner", "name": "Ally", "level": 90, "exp": 0, "gender": 1}, 0, hero, self)
	add_child(buddy)
	buddy.set_physics_process(false)
	await get_tree().process_frame
	var d := dummy(Vector3(3, 0, 0))
	hero.set_target(d)
	buddy.target = d
	check(buddy._score(treant, 5.0, 1.0) > 8.0, "a summoner companion rates its summons highly")
	buddy.mp = 1000.0
	buddy._summon(treant, 1.0)
	check(buddy._summons.size() == 1 and buddy._summons[0] is Summon, "the companion calls a treant beside the party")
	check(buddy._score(treant, 5.0, 1.0) == 0.0, "and does not call it twice")
	var ct := buddy._summons[0] as Summon
	ct.set_process(false)
	check(ct._summoner_target() == d, "the companion's treant fights the companion's target")
	hero.set_target(null)
	buddy.free()
	d.free()
	await get_tree().process_frame


## Skill data and saves: Wind Drake ranks and bar slots become the Fairy Spirit's.
func _data_and_save() -> void:
	var raw := {"class": "summoner", "level": 90, "skills": {"wind_drake": 4, "thorn_shot": 2}, "loadout": ["thorn_shot", "wind_drake", "", "", "", "", "", ""], "adv": 4, "paragon": {}}
	var repaired := Game._repair(raw.duplicate(true))
	check(int(repaired.skills.get("fairy_spirit", 0)) == 4 and not repaired.skills.has("wind_drake"), "a Wind Drake rank becomes a Fairy Spirit rank")
	check(repaired.loadout[1] == "fairy_spirit", "the bar slot follows")
	check(StarSkillData.DESCS[&"summoner"][0].contains("สกิล 2") and StarSkillData.DESCS[&"summoner"][3].contains("แช่แข็ง"), "the star skill descriptions tell the two moves")
	check(SummonAura.THEME.has("fairy"), "the fairy has her own aura theme")
