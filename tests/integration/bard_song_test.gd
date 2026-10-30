extends Node3D
## The Bard's songs and marks: the song slot beside the two self + two ally slots,
## whom a song reaches (hero, companions, summons, allied guild fighters), stances
## that stay on their caster, shred / weaken on monsters, players and gates, the AI's
## song and mark rules, the Skill Master rows, the star set and the HUD song lane.

## Counts every armour crack that lands, to prove a star skill's lands once per contact.
class CountingMob extends Mob:
	var shreds := 0
	func apply_shred(fraction: float, seconds: float) -> void:
		shreds += 1
		super.apply_shred(fraction, seconds)

var checks := 0
var failures := 0
var field: Node3D
var hero: Hero
var buddy: Companion
var singer: Companion
var wolf: Summon
var mob: Mob


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func settle(frames := 4) -> void:
	for i in frames:
		await get_tree().process_frame


func bard(id: String) -> Dictionary:
	return ClassData.find_skill(&"bard", id)


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	Game.new_profile(&"bard", "Bard Song QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.hp = 999999
	Game.profile.mp = 999999
	_song_slot()
	_skill_rank()
	field = Node3D.new()
	add_child(field)
	hero = Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	await settle()
	await _auras_and_hud()
	await _party()
	_stances()
	_star_set()
	await _monster_marks()
	_gate()
	await _fighters()
	_hero_marks()
	_star_shred_once()
	await _hero_auto()
	await _companion_ai()
	_field_player()
	field.queue_free()
	await field.tree_exited
	await settle()
	var budget := VfxBudget.counters()
	check(budget.decorations == 0 and budget.particles == 0 and budget.lights == 0, "every reservation released after the fight (%s)" % str(budget))
	print("BARD SONG: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## BuffBook: one song per recipient beside the 2 + 2, never evicting or evicted.
func _song_slot() -> void:
	check(BuffBook.SONG_LIMIT == 2 and BuffBook.GROUP_LIMIT == 2 and BuffBook.SONG_FAMILIES == ["attack", "ward"], "two song slots (an attack and a ward song) beside two self and two ally slots")
	var list: Array[Dictionary] = []
	for ally in [false, true]:
		for id in ["a", "b"]:
			list = BuffBook.insert(list, {"atk": 0.2, "secs": 60}, Color.WHITE, id, ally, id, 100)
	list = BuffBook.insert(list, {"atk": 0.15, "song": true, "secs": 60}, Color.WHITE, "march", false, "march", 200)
	check(list.size() == 5 and BuffBook.group_count(list, false, 200) == 2 and BuffBook.group_count(list, true, 200) == 2, "2 self + 2 ally + 1 song coexist")
	list = BuffBook.insert(list, {"def": 0.3, "guard": 0.08, "song": true, "secs": 60}, Color.WHITE, "ballad", true, "ballad", 300)
	check(list.size() == 6 and BuffBook.songs_of(list, 300).size() == 2 and BuffBook.contains(list, "march", false, 300) and BuffBook.contains(list, "ballad", true, 300), "a ward song plays beside an attack song whatever its ally flag")
	check(BuffBook.song_family({"atk": 0.4}) == "attack" and BuffBook.song_family({"def": 0.3}) == "ward" and BuffBook.song_family({"shield": 0.1, "atk": 0.1}) == "ward", "a song's family: ward when it guards, else attack")
	check(not BuffBook.song_slot_free(list, 300) and BuffBook.identity(BuffBook.song_to_replace(list, "attack", 300)) == "march" and BuffBook.identity(BuffBook.song_to_replace(list, "ward", 300)) == "ballad", "each family's slot is taken by its own song")
	list = BuffBook.insert(list, {"atk": 0.3, "secs": 60}, Color.WHITE, "c", false, "c", 400)
	check(list.size() == 6 and not BuffBook.contains(list, "a", false, 400) and BuffBook.contains(list, "a", true, 400) and BuffBook.contains(list, "march", false, 400) and BuffBook.contains(list, "ballad", true, 400), "a third regular buff evicts only the oldest regular one of its group, never a song")
	list = BuffBook.insert(list, {"atk": 0.5, "song": true, "secs": 60}, Color.WHITE, "hymn", false, "hymn", 500)
	check(list.size() == 6 and BuffBook.group_count(list, false, 500) == 2 and BuffBook.group_count(list, true, 500) == 2, "a song never evicts a regular buff")
	check(not BuffBook.contains(list, "march", false, 500) and BuffBook.contains(list, "hymn", false, 500) and BuffBook.contains(list, "ballad", true, 500), "two attack songs never stack: the new one takes over from the old one, the ward song stays")
	list = BuffBook.insert(list, {"atk": 0.4, "song": true, "secs": 60}, Color.WHITE, "anthem", true, "anthem", 600)
	check(list.size() == 6 and BuffBook.songs_of(list, 600).size() == 2 and not BuffBook.contains(list, "hymn", false, 600) and BuffBook.contains(list, "anthem", true, 600), "an attack song from someone else takes over the attack slot too")
	list = BuffBook.insert(list, {"atk": 0.55, "song": true, "secs": 60}, Color.WHITE, "anthem", true, "anthem", 20000)
	var song := BuffBook.song_of(list, 20000)
	check(list.size() == 6 and BuffBook.identity(song) == "anthem" and int(song.until) == 80000 and is_equal_approx(float(song.atk), 0.55), "recasting the song refreshes its strength and minute")
	check(is_equal_approx(BuffBook.song_left_of(list, "anthem", 20000), 60.0) and BuffBook.song_left_of(list, "march", 20000) == 0.0, "each song counts its own time")
	check(is_equal_approx(BuffBook.song_left(list, 20000), 60.0) and BuffBook.song_left(list, 81000) == 0.0 and BuffBook.song_of(list, 81000).is_empty(), "the songs count down and end")
	var songs: Array = []
	var stances: Array = []
	for skill in ClassData.pool(&"bard"):
		if BuffBook.is_song_skill(skill):
			songs.append(String(skill.id))
		elif skill.get("fx", {}).get("buff") is Dictionary and BuffBook.is_self_only(skill.fx.buff):
			stances.append(String(skill.id))
	check(songs == ["valor_march", "iron_ballad", "heroic_anthem", "sanctuary_serenade", "hymn_of_legends"], "the five songs are flagged (%s)" % str(songs))
	check(stances == ["virtuoso", "maestro_fervor"], "the two stances are self-only (%s)" % str(stances))
	var boosted := BuffBook.boost_song(bard("valor_march").fx.buff, 1.15)
	check(is_equal_approx(float(boosted.atk), 0.15 * 1.15) and float(boosted.secs) == 60.0 and boosted.song == true, "boost_song raises numbers, never the minute or the flag")


## Skill Master: the mark rows grow every star; the song / stance flags never scale.
func _skill_rank() -> void:
	for id in ["sorrow_note", "discord", "lament", "shattering_rhapsody", "grand_dissonance", "thunder_crescendo", "grand_finale"]:
		var rows := SkillRank.table(bard(id))
		var found := 0
		for row in rows:
			if not (String(row[0]).begins_with("ลดเกราะศัตรู") or String(row[0]).begins_with("ศัตรูอ่อนแรง")):
				continue
			found += 1
			var values: Array = row[1]
			var grows := true
			for r in range(1, values.size()):
				grows = grows and absi(int(String(values[r]).replace("%", ""))) > absi(int(String(values[r - 1]).replace("%", "")))
			check(grows, "%s %s grows every star %s" % [id, row[0], str(values)])
		check(found == (2 if id in ["grand_dissonance", "grand_finale"] else 1), "%s shows its mark rows" % id)
	var death := SkillRank.table(ClassData.find_skill(&"assassin", "death_mark"))
	check(death.any(func(row): return String(row[0]).begins_with("ลดเกราะศัตรู")), "Death Mark shows its armour crack in the Skill Master")
	var valor := SkillRank.scaled(bard("valor_march"), 5)
	check(valor.fx.buff.song is bool and valor.fx.buff.song == true and float(valor.fx.buff.secs) == 60.0, "★5 song keeps its bool flag and its minute")
	var stance := SkillRank.scaled(bard("virtuoso"), 5)
	check(stance.fx.buff.self_only is bool and stance.fx.buff.self_only == true, "★5 stance keeps its bool flag")
	var crack := SkillRank.scaled(bard("discord"), 5)
	check(is_equal_approx(float(crack.fx.shred[0]), 0.15 * 1.24) and float(crack.fx.shred[1]) == 8.0, "★5 shred +24%%, seconds fixed")
	var cap := SkillRank.scaled(bard("thunder_crescendo"), 5)
	check(float(cap.fx.weaken[0]) <= Mob.WEAKEN_CAP + 0.0001, "★5 weaken stays under its 30%% cap")


## Four regular buffs and a song on the hero: five auras, no particles or lights, and
## the HUD shows the song in its own lane while self / ally still read N/2.
func _auras_and_hud() -> void:
	for id in ["zenith", "energy_shield"]:
		var s := ClassData.find_skill(&"mage", id)
		hero.receive_buff(s.fx.buff, s.color, s.name, false, id)
	for id in ["holy_valor", "forest_blessing"]:
		var s := ClassData.find_skill(&"warrior" if id == "holy_valor" else &"summoner", id)
		hero.receive_buff(s.fx.buff, s.color, s.name, true, id)
	var valor := bard("valor_march")
	hero.receive_buff(valor.fx.buff, valor.color, valor.name, true, "valor_march")
	await settle()
	check(hero._buffs.size() == 5 and hero._auras.size() == 5, "four buffs plus one song give five auras (%d)" % hero._auras.size())
	# The song's arrival puff of notes (BuffAura, medium quality and up) is gone in 0.9 s;
	# what stays is the persistent art.
	await get_tree().create_timer(1.2).timeout
	var budget := VfxBudget.counters()
	check(budget.decorations <= 5 and budget.particles == 0 and budget.lights == 0, "persistent hero art at most four draws plus one song, no particles or lights (%s)" % str(budget))
	var status := hero.timer_status()
	var song_rows := status.filter(func(e): return bool(e.get("song", false)))
	check(song_rows.size() == 1 and String(song_rows[0].glyph) == "note", "timer status marks the song (note glyph)")
	var layer := CanvasLayer.new()
	add_child(layer)
	var bars := TimerBars.new()
	layer.add_child(bars)
	await settle(2)
	bars.update_entries(status, 0.1)
	check(bars._rows.song.visible and bars._rows.song.get_child_count() == 2 and bars._rows.song.get_child(0).text == "เพลง\n1/2", "the song has its own HUD lane (เพลง 1/2)")
	check(bars._rows.self.get_child_count() == 3 and bars._rows.ally.get_child_count() == 3, "self and ally lanes keep two chips each")
	check(bars._rows.self.get_child(0).text == "ใช้เอง\n2/2" and bars._rows.ally.get_child(0).text == "จากเพื่อน\n2/2", "self / ally lanes still read N/2")
	hero._buffs.clear()
	hero._sync_auras(Time.get_ticks_msec())
	bars.update_entries(hero.timer_status(), 0.1)
	check(not bars._rows.song.visible and not bars.visible, "the song lane hides without a song")
	layer.queue_free()


func _companion(cls: StringName, who: String, index: int, at: Vector3) -> Companion:
	var c := Companion.new()
	c.setup({"name": who, "class": cls, "level": 100, "stars": 0, "stance": "follow"}, index, hero, field)
	field.add_child(c)
	c.set_physics_process(false)
	c.global_position = at
	return c


## Whom a song reaches: from the hero every companion and summon (at any distance);
## from an AI Bard the hero, the other companions and the summons.
func _party() -> void:
	buddy = _companion(&"warrior", "Buddy QA", 0, Vector3(40, 0, 0))
	singer = _companion(&"bard", "Singer QA", 1, Vector3(-2, 0, 1))
	wolf = Summon.new()
	wolf.setup(hero, "recall_wolverine", {"kind": "wolf", "count": 1, "secs": 120.0, "interval": 0.9}, 2.0, 0, 1, 1)
	field.add_child(wolf)
	wolf.set_physics_process(false)
	hero._summons.append(wolf)
	await settle()
	hero._apply_self_fx(bard("valor_march"))
	var own := hero.song_entry()
	check(String(own.get("skill_id", "")) == "valor_march" and not bool(own.ally), "the hero plays its own song")
	check(String(BuffBook.song_of(buddy._book.buffs).get("skill_id", "")) == "valor_march", "the hero's song reaches a companion 40 m away")
	check(String(BuffBook.song_of(wolf._book.buffs).get("skill_id", "")) == "valor_march", "the hero's song reaches a summon")
	check(String(BuffBook.song_of(singer._book.buffs).get("skill_id", "")) == "valor_march", "the hero's song reaches the AI Bard too")
	# The AI Bard's song: hero, the other companion and the summon all hear it; it
	# takes over the one song slot of each, the other slots stay as they were.
	var holy := ClassData.find_skill(&"warrior", "holy_valor")
	hero.receive_buff(holy.fx.buff, holy.color, holy.name, false, "holy_valor")
	hero._buffs = hero._buffs.filter(func(b): return not BuffBook.is_song(b))
	singer._apply_self(bard("heroic_anthem"))
	var heard := hero.song_entry()
	check(String(heard.get("skill_id", "")) == "heroic_anthem" and bool(heard.ally) and BuffBook.contains(hero._buffs, "holy_valor", false), "an AI Bard's song reaches the hero beside its own buff")
	check(String(BuffBook.song_of(buddy._book.buffs).get("skill_id", "")) == "heroic_anthem" and BuffBook.song_of(buddy._book.buffs).ally, "an AI Bard's song reaches the other companion (replacing the old song)")
	check(String(BuffBook.song_of(wolf._book.buffs).get("skill_id", "")) == "heroic_anthem", "an AI Bard's song reaches the summons")
	check(String(BuffBook.song_of(singer._book.buffs).get("skill_id", "")) == "heroic_anthem" and not BuffBook.song_of(singer._book.buffs).ally, "the AI Bard holds its own song")
	check(buddy._book.buffs.filter(func(b): return BuffBook.is_song(b)).size() <= BuffBook.SONG_LIMIT, "a companion never holds more than two songs")
	# A non-song buff from an AI member still reaches the hero only.
	var guard := ClassData.find_skill(&"mage", "energy_shield")
	singer._apply_self(guard)
	check(BuffBook.contains(hero._buffs, "energy_shield", true) and not BuffBook.contains(buddy._book.buffs, "energy_shield", true), "other AI buffs stay the hero's only")


## A stance (self_only) stays on its caster, for the hero and for an AI member.
func _stances() -> void:
	for b in [buddy, singer, wolf]:
		b._book.buffs.clear()
	hero._buffs.clear()
	hero._apply_self_fx(bard("virtuoso"))
	check(BuffBook.contains(hero._buffs, "virtuoso", false), "the hero's stance is on the hero")
	check(not BuffBook.contains(buddy._book.buffs, "virtuoso", true) and not BuffBook.contains(wolf._book.buffs, "virtuoso", true), "the hero's stance never reaches the party")
	# Its heal stays on the caster too (a stance is "เฉพาะตัวเอง").
	var buddy_spot: Vector3 = buddy.global_position
	buddy.global_position = hero.global_position + Vector3(1.5, 0, 0)
	buddy.hp = buddy.max_hp / 2
	var hero_hp: int = Game.profile.hp
	Game.profile.hp = hero.stats.max_hp / 2
	hero._apply_self_fx(bard("maestro_fervor"))
	check(buddy.hp == buddy.max_hp / 2, "the hero's stance heal reaches nobody else")
	Game.profile.hp = hero.stats.max_hp / 2
	singer._apply_self(bard("maestro_fervor"))
	check(Game.profile.hp == hero.stats.max_hp / 2, "the AI Bard's stance heal reaches nobody else")
	Game.profile.hp = hero_hp
	buddy.global_position = buddy_spot
	hero._buffs.clear()
	hero._apply_self_fx(bard("virtuoso"))
	check(BuffBook.contains(singer._book.buffs, "maestro_fervor", false), "the AI Bard's stance is on itself")
	check(not BuffBook.contains(hero._buffs, "maestro_fervor", true) and not BuffBook.contains(buddy._book.buffs, "maestro_fervor", true), "the AI Bard's stance takes nobody else's slot")
	check(BuffBook.group_count(hero._buffs, true) == 0 and BuffBook.group_count(hero._buffs, false) == 1, "the hero's slots are untouched by the AI stance")


## The full Bard star set: songs ×1.15 for everyone they reach; stances are not songs.
func _star_set() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for slot in ["weapon", "armor", "helm", "boots"]:
		Game.profile.equip[slot] = StarProgression.item(&"bard", 50, slot, rng)
	check(StarProgression.has_full_set(Game.profile, "bard"), "four Bard star pieces make the set")
	hero._buffs.clear()
	buddy._book.buffs.clear()
	hero._apply_self_fx(bard("valor_march"))
	hero._apply_self_fx(bard("virtuoso"))
	check(is_equal_approx(float(hero.song_entry().atk), 0.15 * Hero.SONG_SET_BOOST) and is_equal_approx(float(hero.song_entry().speed), 0.12 * Hero.SONG_SET_BOOST), "the set makes the hero's song 15% stronger")
	check(is_equal_approx(float(BuffBook.song_of(buddy._book.buffs).atk), 0.15 * Hero.SONG_SET_BOOST), "the boosted song reaches the party")
	var stance: Array = hero._buffs.filter(func(b): return BuffBook.identity(b) == "virtuoso")
	check(stance.size() == 1 and is_equal_approx(float(stance[0].atk), 0.25), "the stance is not boosted")
	Game.profile.equip = {}
	hero._buffs.clear()
	hero._apply_self_fx(bard("valor_march"))
	check(is_equal_approx(float(hero.song_entry().atk), 0.15), "without the set the song is as written")
	hero._buffs.clear()
	hero.refresh_stats()


func _mob(id: StringName, lv: int, at: Vector3) -> Mob:
	var m := Mob.new()
	m.setup(id, lv, at, hero)
	field.add_child(m)
	m.set_physics_process(false)
	m.global_position = at
	return m


func _labels(text: String) -> int:
	var n := 0
	for node in field.get_children():
		if node is Label3D and (node as Label3D).text == text:
			n += 1
	return n


## shred / weaken on monsters: strongest wins, weaker ignored, caps, boss weaken ×0.4,
## expiry gives the stat back, the tag tint, and at most three words a physics frame.
func _monster_marks() -> void:
	# Let the buff names floating so far fade, so the word cap below counts only marks.
	await get_tree().create_timer(1.4).timeout
	mob = _mob(&"forest_orc", 100, Vector3(4, 0, 0))
	await settle(2)
	await get_tree().physics_frame
	var plain: Color = mob._label.modulate
	var base_def := float(mob.stats.def)
	var base_atk := float(mob.stats.atk)
	var words := _labels("เกราะแตก!")
	mob.apply_shred(0.15, 8.0)
	check(is_equal_approx(float(mob.stats.def), base_def * 0.85) and is_equal_approx(mob.debuff_left("shred"), 8.0), "shred cracks DEF 15% for 8 s")
	check(_labels("เกราะแตก!") == words + 1 and mob._label.modulate == Mob.MARK_TINTS[0], "a new crack shows its word and tints the tag")
	mob.apply_shred(0.10, 20.0)
	check(is_equal_approx(float(mob.stats.def), base_def * 0.85) and is_equal_approx(mob.debuff_left("shred"), 8.0), "a weaker crack is ignored while the stronger runs")
	mob.apply_shred(0.25, 4.0)
	check(is_equal_approx(float(mob.stats.def), base_def * 0.75) and is_equal_approx(mob.debuff_left("shred"), 8.0), "a stronger crack takes over and keeps the longer time")
	check(_labels("เกราะแตก!") == words + 1, "a stronger crack within 1.2 s shows no second word")
	mob.apply_shred(0.9, 1.0)
	check(is_equal_approx(float(mob.stats.def), base_def * (1.0 - Mob.SHRED_CAP)), "shred stops at 35%")
	mob.apply_weaken(0.2, 8.0)
	check(is_equal_approx(float(mob.stats.atk), base_atk * 0.8) and is_equal_approx(mob.debuff_left("weaken"), 8.0), "weaken saps ATK 20% for 8 s (every strike reads stats.atk)")
	check(mob._label.modulate == Mob.MARK_TINTS[2], "both marks tint the tag violet")
	mob.apply_weaken(0.9, 1.0)
	check(is_equal_approx(float(mob.stats.atk), base_atk * (1.0 - Mob.WEAKEN_CAP)), "weaken stops at 30%")
	mob._tick_status(8.5)
	check(float(mob.stats.def) == base_def and float(mob.stats.atk) == base_atk and mob.debuff_left("shred") == 0.0 and mob.debuff_left("weaken") == 0.0, "expiry restores DEF and ATK exactly")
	check(mob._label.modulate == plain, "the tag gets its own colour back")
	var boss := _mob(&"forest_orc", 100, Vector3(30, 0, 30))
	boss.is_boss = true
	boss.apply_weaken(0.2, 8.0)
	boss.apply_shred(0.2, 8.0)
	check(is_equal_approx(boss.debuff_left("weaken"), 8.0 * Mob.BOSS_WEAKEN_TIME) and is_equal_approx(boss.debuff_left("shred"), 8.0), "a boss shakes off weaken in 40% of the time, shred in full")
	boss.queue_free()
	# A pack hit at once: at most three words in one physics frame.
	var pack: Array[Mob] = []
	for i in 6:
		pack.append(_mob(&"pink_slime", 20, Vector3(-30 + i * 1.5, 0, 30)))
	await settle(2)
	await get_tree().physics_frame
	words = _labels("อ่อนแรง!")
	for m in pack:
		m.apply_weaken(0.2, 8.0)
	check(_labels("อ่อนแรง!") - words == Mob.MARK_WORDS_PER_FRAME, "at most three mark words a physics frame (%d)" % (_labels("อ่อนแรง!") - words))
	check(pack.all(func(m): return m._label.modulate == Mob.MARK_TINTS[1]), "every monster of the pack is tinted though")
	await get_tree().physics_frame
	words = _labels("อ่อนแรง!")
	pack[4].apply_weaken(0.25, 8.0)
	pack[0].apply_weaken(0.25, 8.0)
	check(_labels("อ่อนแรง!") - words == 1, "next frame: a stronger mark speaks, but not twice in 1.2 s on one monster")
	for m in pack:
		m.queue_free()
	# The Assassin's Death Mark now really cracks the armour (it carried shred for nothing before).
	var marked := _mob(&"forest_orc", 100, Vector3(-30, 0, -4))
	var def0 := float(marked.stats.def)
	hero._deal(marked, 0.001, Color.WHITE, &"impact", false, ClassData.find_skill(&"assassin", "death_mark"))
	check(not marked.is_dead() and is_equal_approx(marked.debuff_left("shred"), 8.0) and is_equal_approx(float(marked.stats.def), def0 * 0.8), "Death Mark cracks the armour 20% for 8 s")
	hero._deal(marked, 0.001, Color.WHITE, &"impact", false, bard("sorrow_note"))
	check(is_equal_approx(marked.debuff_left("weaken"), 6.0), "a Bard note saps the monster it hits")
	marked.queue_free()


## A castle gate cannot be marked, and never looks unmarked to the AI.
func _gate() -> void:
	var gate := CastleGate.new()
	gate.setup_gate(0, Vector3(0, 0, -30), 5000, hero)
	field.add_child(gate)
	gate.global_position = Vector3(0, 0, -30)
	var tint: Color = gate._label.modulate
	gate.apply_shred(0.3, 8.0)
	gate.apply_weaken(0.3, 8.0)
	check(float(gate.stats.def) == 0.0 and float(gate.stats.atk) == 0.0 and gate._label.modulate == tint, "a gate ignores shred and weaken")
	check(gate.debuff_left("shred") == INF and not Mob.lacks_mark(gate, bard("discord").fx, 1.0), "a gate never lacks a mark (the AI does not waste marks on it)")
	gate.queue_free()


func _fighter(cls: StringName, team: int, at: Vector3, seed_value: int) -> GuildFighter:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var f := GuildFighter.new()
	f.setup_fighter(GuildWarData.make_fighter(cls, 2, "QA %s" % cls, rng), team, hero, at, "[QA]")
	field.add_child(f)
	f.set_physics_process(false)
	f.global_position = at
	return f


## Players (guild fighters, arena rivals) feel half a mark for 40% of the time; the
## buff code keeps the crack, expiry and respawn clear it; allied Bard songs reach the hero.
var enemy: GuildFighter

func _fighters() -> void:
	enemy = _fighter(&"bard", GuildFighter.TEAM_ENEMY, Vector3(6, 0, 6), 5)
	await settle()
	var base_def := float(enemy._base_def)
	var team_tint: Color = enemy._label.modulate
	check(Mob.lacks_mark(enemy, bard("discord").fx, 1.0), "an unmarked fighter lacks the mark")
	# Marks only land on a player who can be hurt: not in the countdown, not under the spawn guard.
	enemy._frozen = true
	enemy.apply_shred(0.3, 8.0)
	check(enemy.debuff_left("shred") == 0.0 and float(enemy.stats.def) == base_def, "a fighter in the countdown shrugs off a crack")
	enemy._frozen = false
	enemy._guard_until = Time.get_ticks_msec() + 5000
	enemy.apply_weaken(0.3, 8.0)
	check(enemy.debuff_left("weaken") == 0.0, "a fighter under its spawn guard shrugs off a weaken")
	enemy._guard_until = 0
	enemy.apply_shred(0.3, 8.0)
	check(is_equal_approx(float(enemy.stats.def), base_def * 0.85) and absf(enemy.debuff_left("shred") - 3.2) < 0.05, "a fighter feels half a crack for 40% of the time")
	check(not Mob.lacks_mark(enemy, bard("discord").fx, 1.0), "debuff_left sees a fighter's crack (the AI's marks-up rule works in war)")
	enemy.apply_shred(0.9, 8.0)
	enemy.apply_weaken(0.9, 8.0)
	check(is_equal_approx(float(enemy.stats.def), base_def * (1.0 - Mob.SHRED_CAP * 0.5)) and is_equal_approx(enemy._weaken_now(), Mob.WEAKEN_CAP * 0.5), "player caps: 17.5% crack, 15% weaken")
	check(enemy._label.modulate == team_tint, "a marked fighter's tag keeps its team colour (friend or foe stays readable)")
	enemy._tick(0.1)
	check(is_equal_approx(float(enemy.stats.def), base_def * 0.825), "the crack survives the fighter's tick")
	# While stunned a fighter skips _chase / _tick, but its marks still run out on time.
	var keep_until: float = enemy._rshred_until
	enemy._rshred_until = Time.get_ticks_msec() * 0.001 - 0.01
	enemy._stun = 2.0
	enemy._tick_status(0.1)
	check(enemy.debuff_left("shred") == 0.0 and is_equal_approx(float(enemy.stats.def), base_def), "a stunned fighter's crack still runs out")
	enemy._stun = 0.0
	enemy.apply_shred(0.9, 8.0)
	check(enemy._rshred_until >= keep_until - 0.1, "and a new crack lands again")
	enemy.receive_party_buff({"def": 0.2, "atk": 0.1, "secs": 60.0}, Color.WHITE, "QA", "qa_guard")
	check(is_equal_approx(float(enemy.stats.def), base_def * 1.2 * 0.825), "a buff on a cracked fighter keeps the crack")
	enemy._rshred_until = Time.get_ticks_msec() * 0.001 - 0.01
	enemy._tick(0.1)
	check(is_equal_approx(float(enemy.stats.def), base_def * 1.2) and enemy.debuff_left("shred") == 0.0, "an expired crack gives the DEF back")
	enemy.apply_shred(0.3, 8.0)
	enemy._die()
	enemy.respawn()
	check(enemy.debuff_left("shred") == 0.0 and enemy.debuff_left("weaken") == 0.0 and float(enemy.stats.def) == base_def and enemy._weaken_now() == 0.0, "respawn clears the marks and the buff")
	# The AI of a fighter: a song by the formula, +1.5 for a mark the target lacks.
	enemy._victim = hero
	enemy._buff_until = 0.0
	check(is_equal_approx(enemy._score(bard("hymn_of_legends"), "self", 5.0, 1.0), 6.0 + 0.55 + 0.1 + 0.1), "a fighter scores its songs 6 + atk + crit/2")
	var plain_score := enemy._shape_score(bard("discord"), "blast", 5.0, 1.0)
	check(is_equal_approx(enemy._score(bard("discord"), "blast", 5.0, 1.0), plain_score + 1.5), "a marking skill +1.5 while the target lacks the mark")
	# An allied Bard fighter's song reaches the hero (at most 30 s), never over the hero's own.
	var friend := _fighter(&"bard", GuildFighter.TEAM_ALLY, hero.global_position + Vector3(3, 0, 0), 6)
	var mate := _fighter(&"warrior", GuildFighter.TEAM_ALLY, hero.global_position + Vector3(-3, 0, 0), 7)
	await settle()
	hero._buffs.clear()
	friend._resolve(bard("heroic_anthem"), null, Vector3.ZERO)
	var song := hero.song_entry()
	check(String(song.get("skill_id", "")) == "heroic_anthem" and bool(song.get("ally", false)) and float(song.get("total", 99.0)) <= 30.0, "an allied fighter's song reaches the hero for 30 s at most")
	check(mate._buff_until > 0.0 and mate._atk_boost > 1.3, "and its teammates")
	hero._buffs.clear()
	hero._apply_self_fx(bard("valor_march"))
	friend._resolve(bard("hymn_of_legends"), null, Vector3.ZERO)
	check(String(hero.song_entry().get("skill_id", "")) == "valor_march", "an AI fighter never sings over the hero's own song")
	mate._atk_boost = 1.0
	mate._buff_until = 0.0
	friend._resolve(bard("virtuoso"), null, Vector3.ZERO)
	check(mate._atk_boost == 1.0 and not BuffBook.contains(hero._buffs, "virtuoso", true), "a fighter's stance stays its own")
	friend.queue_free()
	mate.queue_free()
	hero._buffs.clear()


## The hero in the arena / guild war (M2b): half strength, 40% time, strongest wins.
func _hero_marks() -> void:
	var def := float(hero.stats.def)
	check(Mob.lacks_mark(hero, bard("discord").fx, 1.0), "an unmarked hero lacks the mark")
	hero.apply_enemy_debuff("shred", 0.3, 8.0)
	check(is_equal_approx(hero.effective_def(), def * 0.85) and absf(hero.debuff_left("shred") - 3.2) < 0.05, "an enemy Bard cracks the hero's armour at half strength for 40% of the time")
	hero.apply_enemy_debuff("shred", 0.1, 30.0)
	check(is_equal_approx(hero.effective_def(), def * 0.85) and hero.debuff_left("shred") < 3.3, "a weaker crack is ignored")
	hero.apply_enemy_debuff("weaken", 0.9, 8.0)
	check(is_equal_approx(hero._enemy_mark("weaken"), Mob.WEAKEN_CAP * 0.5), "the hero's weaken stops at 15%")
	hero._enemy_shred_until = 0
	hero._enemy_weaken_until = 0
	check(is_equal_approx(hero.effective_def(), def), "the marks wear off")
	# An enemy Bard's strike carries its marks onto the hero.
	enemy._frozen = false
	enemy._hit(hero, 0.001, Color.WHITE, bard("lament").fx)
	check(absf(hero.debuff_left("weaken") - 3.2) < 0.05 and is_equal_approx(hero._enemy_mark("weaken"), 0.1), "an enemy fighter's lament saps the hero (10%)")
	hero._enemy_weaken_until = 0
	enemy.apply_shred(0.3, 8.0)
	enemy.stop_fight()
	check(enemy.debuff_left("shred") == 0.0 and float(enemy.stats.def) == float(enemy._base_def), "a duel's end clears the rival's marks")
	enemy.apply_shred(0.3, 8.0)
	check(enemy.debuff_left("shred") == 0.0 and float(enemy.stats.def) == float(enemy._base_def), "and no mark lands after the end (it would never run out)")
	enemy.queue_free()


## A star skill's crack lands once per contact (through Hero._deal), at its ranked strength.
func _star_shred_once() -> void:
	var dummy := CountingMob.new()
	dummy.setup(&"forest_orc", 100, hero.global_position + Vector3(0, 0, 2.0), hero)
	field.add_child(dummy)
	dummy.set_physics_process(false)
	dummy.global_position = hero.global_position + Vector3(0, 0, 2.0)
	var def0 := float(dummy.stats.def)
	var seq := StarSkillSequence.new()
	seq.skill = SkillRank.scaled(ClassData.find_skill(&"warrior", "crown_breaker"), 5)
	seq.victim_ref = weakref(dummy)
	seq.center = dummy.global_position
	seq.origin = hero.global_position
	seq.forward = Vector3(0, 0, 1)
	seq._hit(hero, 0, 2)
	check(dummy.shreds == 1 and absf(float(dummy.stats.def) - def0 * (1.0 - 0.2 * 1.24)) < 0.01 * def0, "a ★5 star crack lands once, at 24.8%% (%d casts)" % dummy.shreds)
	seq.free()
	dummy.queue_free()


func _bar(ids: Array) -> void:
	var bar: Array = ids.duplicate()
	while bar.size() < ClassData.SLOTS:
		bar.append("")
	Game.profile.loadout = bar
	hero.cooldowns.clear()
	hero._cast_until = 0
	hero._pending = {}
	hero.last_cast_id = ""


## The hero's auto-hunt: the first song on the bar when the slot is empty, never cutting
## a song short (but a healing swap when hurt), and marks that are up wait as a fallback.
func _hero_auto() -> void:
	mob.global_position = hero.global_position + Vector3(0, 0, 4)
	hero.set_target(mob)
	hero._buffs.clear()
	_bar(["valor_march", "heroic_anthem"])
	hero._auto_cast(1.0)
	check(hero.last_cast_id == "valor_march", "auto plays the first song on the bar (%s)" % hero.last_cast_id)
	await get_tree().create_timer(1.6).timeout
	check(String(hero.song_entry().get("skill_id", "")) == "valor_march", "the song is playing")
	_bar(["valor_march", "iron_ballad"])
	hero._auto_cast(1.0)
	check(hero.last_cast_id == "iron_ballad", "a ward song fills the ward slot beside the attack song (%s)" % hero.last_cast_id)
	await get_tree().create_timer(1.6).timeout
	check(BuffBook.songs_of(hero._buffs).size() == 2, "an attack and a ward song play together")
	_bar(["valor_march", "iron_ballad"])
	hero._auto_cast(1.0)
	check(hero.last_cast_id == "", "a running song is never replaced early (%s)" % hero.last_cast_id)
	_bar(["valor_march", "heroic_anthem"])
	hero._auto_cast(1.0)
	check(hero.last_cast_id == "", "a second attack song never goes over the playing one (%s)" % hero.last_cast_id)
	_bar(["valor_march", "sanctuary_serenade"])
	hero._auto_cast(0.3)
	check(hero.last_cast_id == "sanctuary_serenade", "badly hurt, a healing song swaps in (%s)" % hero.last_cast_id)
	await get_tree().create_timer(1.6).timeout
	BuffBook.song_to_replace(hero._buffs, "attack")["until"] = Time.get_ticks_msec() + 2000
	_bar(["heroic_anthem", "sanctuary_serenade"])
	hero._auto_cast(1.0)
	check(hero.last_cast_id == "heroic_anthem", "when the attack song is about to end the next attack song takes over (%s)" % hero.last_cast_id)
	await get_tree().create_timer(1.6).timeout
	# Marks already up: the marking skill waits behind the next skill, and fires when nothing else can.
	mob.apply_shred(0.15, 8.0)
	_bar(["discord", "staccato_shot"])
	hero._auto_cast(1.0)
	check(String(hero._pending.get("id", "")) == "staccato_shot", "a skill whose marks are up waits behind the others (%s)" % hero._pending.get("id", ""))
	_bar(["discord", "staccato_shot"])
	hero.cooldowns["staccato_shot"] = 5.0
	hero._auto_cast(1.0)
	check(String(hero._pending.get("id", "")) == "discord", "and still fires when nothing else can")
	mob._tick_status(9.0)
	_bar(["discord", "staccato_shot"])
	hero._auto_cast(1.0)
	check(String(hero._pending.get("id", "")) == "discord", "an unmarked target gets the mark first")
	# A marking burst opens on a lone monster while it is unmarked.
	_bar(["thunder_crescendo"])
	hero._auto_cast(1.0)
	check(String(hero._pending.get("id", "")) == "thunder_crescendo", "a marking burst is cast on a lone unmarked monster")
	mob.apply_weaken(0.24, 8.0)
	_bar(["thunder_crescendo"])
	hero._auto_cast(1.0)
	check(hero._pending.is_empty(), "but not on a lone monster already sapped")
	mob._tick_status(9.0)
	_bar([])
	hero._buffs.clear()


## The AI Bard companion: sings first (the strongest attack song), never over the
## player's song or a long one, swaps in a healing song when the hero is hurt, then
## marks the target before it plays its notes.
func _companion_ai() -> void:
	singer.target = mob
	singer.global_position = mob.global_position + Vector3(3, 0, 0)
	hero.set_target(mob)
	for b in [buddy, singer, wolf]:
		b._book.buffs.clear()
	hero._buffs.clear()
	var hymn := bard("hymn_of_legends")
	var anthem := bard("heroic_anthem")
	var valor := bard("valor_march")
	check(is_equal_approx(singer._score(hymn, 3.0, 1.0), 7.0 + 0.55 + 0.1 + 0.1) and singer._score(hymn, 3.0, 1.0) > singer._score(anthem, 3.0, 1.0) and singer._score(anthem, 3.0, 1.0) > singer._score(valor, 3.0, 1.0), "the strongest attack song scores highest (7 + atk + crit/2)")
	check(singer._score(bard("iron_ballad"), 3.0, 1.0) < singer._score(valor, 3.0, 1.0), "ward songs wait for a swap")
	hero._apply_self_fx(valor)
	check(singer._score(hymn, 3.0, 1.0) == 0.0, "an AI Bard never replaces the player's own attack song")
	check(singer._score(bard("iron_ballad"), 3.0, 1.0) > 7.0, "but sings a ward song beside it (the ward slot)")
	hero._buffs.clear()
	singer._apply_self(anthem)
	check(singer._score(anthem, 3.0, 1.0) == 0.0, "nor sings a song already playing with 10 s or more left")
	check(singer._score(hymn, 3.0, 1.0) == 0.0, "nor replaces an attack song with 10 s or more left")
	check(singer._score(bard("iron_ballad"), 3.0, 0.3) == 10.0, "the hero badly hurt: a healing song swaps in")
	BuffBook.song_to_replace(hero._buffs, "attack")["until"] = Time.get_ticks_msec() + 5000
	check(singer._score(hymn, 3.0, 1.0) > 7.0, "an attack song about to end makes room for another")
	hero._buffs.clear()
	var note := bard("sorrow_note")
	var plain := singer._shape_score(note, 3.0, 1.0)
	check(singer._score(note, 3.0, 1.0) == 6.5, "a marking skill opens on an unmarked target")
	mob.is_boss = true
	check(singer._score(note, 3.0, 1.0) == 7.0, "+0.5 against a boss")
	mob.is_boss = false
	mob.apply_weaken(0.15, 6.0)
	check(is_equal_approx(singer._score(note, 3.0, 1.0), maxf(0.5, plain - 2.0)), "a marked target makes it wait")
	check(singer._score(bard("virtuoso"), 3.0, 1.0) == 6.0 and singer._score(bard("maestro_fervor"), 3.0, 1.0) == 6.0, "stances score like any own buff")
	mob._tick_status(9.0)
	# Live: the AI Bard sings, then marks.
	singer.mp = 99999.0
	singer.cooldowns.clear()
	singer._cast_until = 0
	check(singer._try_skills(3.0), "the AI Bard picks a skill")
	await get_tree().create_timer(1.8).timeout
	var song := hero.song_entry()
	check(String(song.get("skill_id", "")) == "hymn_of_legends" and bool(song.get("ally", false)), "it sings the Hymn of Legends for the party (%s)" % song.get("skill_id", "-"))
	check(String(BuffBook.song_of(buddy._book.buffs).get("skill_id", "")) == "hymn_of_legends" and String(BuffBook.song_of(wolf._book.buffs).get("skill_id", "")) == "hymn_of_legends", "the whole party hears it")
	singer._cast_until = 0
	check(singer._try_skills(3.0), "the AI Bard picks the next skill")
	await get_tree().create_timer(1.8).timeout
	var families := BuffBook.songs_of(hero._buffs).map(func(b): return BuffBook.song_family(b))
	check(families.size() == 2 and families.has("attack") and families.has("ward"), "it fills the ward slot with a ward song (%s)" % str(families))
	singer._cast_until = 0
	check(singer._try_skills(3.0), "the AI Bard picks the next skill again")
	await get_tree().create_timer(1.8).timeout
	check(mob.debuff_left("weaken") > 0.0 or mob.debuff_left("shred") > 0.0, "then it marks the target")


## A world player hunting alone sings for itself.
func _field_player() -> void:
	var fp := FieldPlayer.new()
	fp.hero = hero
	var valor := bard("valor_march")
	fp._book.add(valor.fx.buff, valor.color, valor.name, false, "valor_march")
	hero._buffs.clear()
	check(fp._song_left() > 50.0 and not fp._hero_sings(), "alone it reads its own song slot")
	fp._buff_allies(valor.fx.buff, valor.color, valor.name, "valor_march")
	check(hero.song_entry().is_empty(), "and its song reaches nobody else")
	fp.free()
