extends Node3D
## The party-buff rule (BuffBook.reaches_party, ClassData.PARTY_BUFF_CLASSES /
## PARTY_BUFF_SKILLS): every class's buffs buff only the caster (and its own summons),
## EXCEPT the Priest's and the Bard's (songs too) and the Defender's เบ่งเลือด, which reach
## the party. Checked for every buff skill of every class (star skills too) through the
## hero's cast, an AI companion's cast and a guild fighter's cast; the descriptions of the
## self buffs promise no team; the summoner's Fairy Spirit still heals the whole party.
##   godot --headless --path . res://tests/integration/party_buff_rule_test.tscn
var failures := 0
var checks := 0


## A party member or a summon that only records what reaches it.
class Mate extends Node3D:
	var got: Array = []
	var healed := 0.0
	func _init(group: String) -> void:
		add_to_group(group)
	func receive_party_buff(_buff: Dictionary, _color: Color, _label := "", skill_id := "") -> void:
		got.append(skill_id)
	func heal_fraction(fraction: float) -> void:
		healed += fraction
	func is_dead() -> bool:
		return false


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## Whether the owner's rule says [param skill] of [param cls] reaches the party.
static func expected(cls: StringName, skill: Dictionary) -> bool:
	if bool(skill.fx.buff.get("self_only", false)):
		return false
	return cls == &"priest" or cls == &"bard" or String(skill.id) == "brace"


static func buff_skills(cls: StringName) -> Array:
	return ClassData.pool(cls).filter(func(s): return s.get("fx", {}) is Dictionary and (s.get("fx", {}) as Dictionary).get("buff") is Dictionary)


func _ready() -> void:
	Game.set_process(false)
	WorldEvents.festival_enabled = false
	_data()
	await _hero_casts()
	await _companion_casts()
	await _guild_fighter_casts()
	await _fairy()
	print("PARTY BUFF RULE: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## The data: which buffs reach the party, and what the self buffs' texts promise.
func _data() -> void:
	var party := 0
	var own := 0
	for cls in ClassData.IDS:
		for skill in buff_skills(cls):
			var want := expected(cls, skill)
			check(BuffBook.reaches_party(skill.fx.buff) == want, "%s %s: reaches the party = %s" % [cls, skill.id, want])
			check(ClassData.is_party_buff_skill(cls, skill) == want, "%s %s: ClassData agrees" % [cls, skill.id])
			if want:
				party += 1
			else:
				own += 1
				var desc := String(skill.desc)
				check(not desc.contains("ทีม") and not desc.contains("ปาร์ตี้"), "%s %s: a self buff promises no team (%s)" % [cls, skill.id, desc])
	check(party >= 8 and own >= 30, "both kinds exist (%d party, %d self)" % [party, own])
	for id in ["iron_wall", "sanctuary_wall", "thorn_guard", "eternal_aegis"]:
		check(not BuffBook.reaches_party(ClassData.find_skill(&"defender", id).fx.buff), "the Defender's %s is its own: only เบ่งเลือด reaches the party" % id)
	var brace := ClassData.find_skill(&"defender", "brace")
	check(BuffBook.party_part(brace.fx.buff).has("hp") and not BuffBook.party_part(brace.fx.buff).has("guard"), "เบ่งเลือด still shares only its max HP")
	for pair in [[&"darklord", "commanders_aura"], [&"darklord", "emperors_command"], [&"darklord", "lords_dominion"], [&"muaythai", "sacred_mongkhon"], [&"muaythai", "vow_of_the_ring"], [&"summoner", "spirit_court"], [&"warrior", "royal_vanguard"], [&"lancer", "aegis_formation"], [&"assassin", "veil_of_night"]]:
		check(not BuffBook.reaches_party(ClassData.find_skill(pair[0], pair[1]).fx.buff), "%s %s is the caster's own" % pair)
	for pair in [[&"priest", "seraph_aegis"], [&"priest", "sacred_sanctuary"], [&"priest", "miracle"], [&"bard", "celestial_stage"], [&"bard", "hymn_of_legends"], [&"bard", "iron_ballad"]]:
		check(BuffBook.reaches_party(ClassData.find_skill(pair[0], pair[1]).fx.buff), "%s %s reaches the party" % pair)
	# The ranked skill (stars grow numbers only) keeps the flag.
	var ranked: Dictionary = SkillRank.scaled_fx(ClassData.find_skill(&"priest", "blessing_aura").fx, 5)
	check(BuffBook.reaches_party(ranked.buff), "a ★5 Priest buff still reaches the party")
	# The class and advancement texts no longer promise team buffs for self-buff classes.
	check(not String(ClassData.get_class_data(&"darklord").desc).contains("เสริมพลังทั้งทีม"), "the Dark Lord's class text: no team buff")
	check(not String(ClassData.get_class_data(&"summoner").desc).contains("เสริมพลังให้ทั้งทีม"), "the Summoner's class text: no team buff")
	check(String(ClassData.get_class_data(&"bard").desc).contains("ทั้งปาร์ตี้"), "the Bard's songs still reach the party")


func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "Rule QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.hp = 99999
	Game.profile.mp = 99999


## The hero's casts (bar skills through _apply_self_fx, star skills the way
## StarSkillSequence casts them): a party member and another's summon get only the party
## buffs; the hero's own summon gets every buff but a stance.
func _hero_casts() -> void:
	_profile(&"warrior")
	var hero := Hero.new()
	add_child(hero)
	hero.field = self
	hero.set_physics_process(false)
	var mate := Mate.new("companions")
	add_child(mate)
	mate.position = Vector3(2, 0, 0)
	var own := Mate.new("summons")
	add_child(own)
	own.position = Vector3(-2, 0, 0)
	var other := Mate.new("summons")
	add_child(other)
	other.position = Vector3(0, 0, 2)
	await get_tree().process_frame
	for cls in ClassData.IDS:
		_profile(cls)
		hero.refresh_stats()
		hero._summons = [own]
		for skill in buff_skills(cls):
			mate.got.clear()
			own.got.clear()
			other.got.clear()
			hero._buffs.clear()
			if skill.has("star"):
				hero.receive_buff(skill.fx.buff, skill.color, skill.name, false, skill.id)
				hero.spread_buff(skill.fx.buff, skill.color, skill.name, skill.id, hero.global_position, 12.0)
			else:
				hero._apply_self_fx(skill)
			var want := expected(cls, skill)
			var id := String(skill.id)
			check(BuffBook.contains(hero._buffs, id, false), "hero %s %s: the caster has it" % [cls, id])
			check(mate.got.has(id) == want, "hero %s %s: a party member %s it" % [cls, id, "gets" if want else "does not get"])
			check(other.got.has(id) == want, "hero %s %s: a party mate's summon %s it" % [cls, id, "gets" if want else "does not get"])
			check(own.got.has(id) == not BuffBook.is_self_only(skill.fx.buff), "hero %s %s: the hero's own summon follows its kit" % [cls, id])
	hero._summons.clear()
	hero.queue_free()
	for n in [mate, own, other]:
		n.queue_free()
	await get_tree().process_frame


## An AI companion's casts: the hero (and the other members) get only the party buffs;
## its own summon gets every buff but a stance.
func _companion_casts() -> void:
	_profile(&"warrior")
	var hero := Hero.new()
	add_child(hero)
	hero.field = self
	hero.set_physics_process(false)
	var mate := Mate.new("companions")
	add_child(mate)
	var own := Mate.new("summons")
	add_child(own)
	await get_tree().process_frame
	for cls in ClassData.IDS:
		var buddy := Companion.new()
		buddy.hero = hero
		buddy.field = self
		buddy.member = {"class": cls, "name": "QA %s" % cls, "level": 100}
		buddy.stats = {"atk": 100.0}
		buddy.max_hp = 1000
		buddy.hp = 1000
		add_child(buddy)
		buddy.set_physics_process(false)
		buddy.set_process(false)
		buddy._summons = [own]
		for skill in buff_skills(cls).filter(func(s): return not s.has("star")):
			hero._buffs.clear()
			mate.got.clear()
			own.got.clear()
			buddy._apply_self(skill)
			var want := expected(cls, skill)
			var id := String(skill.id)
			check(BuffBook.contains(buddy._book.buffs, id, false), "companion %s %s: the caster has it" % [cls, id])
			check(BuffBook.contains(hero._buffs, id, true) == want, "companion %s %s: the hero %s it" % [cls, id, "gets" if want else "does not get"])
			check(mate.got.has(id) == want, "companion %s %s: another party member %s it" % [cls, id, "gets" if want else "does not get"])
			check(own.got.has(id) == not BuffBook.is_self_only(skill.fx.buff), "companion %s %s: its own summon follows its kit" % [cls, id])
		buddy._summons.clear()
		buddy.queue_free()
		await get_tree().process_frame
	hero.queue_free()
	mate.queue_free()
	own.queue_free()
	await get_tree().process_frame


func _fighter(cls: StringName, at: Vector3, hero: Node3D, seed_value: int) -> GuildFighter:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var f := GuildFighter.new()
	f.setup_fighter(GuildWarData.make_fighter(cls, 2, "QA %s %d" % [cls, seed_value], rng), GuildFighter.TEAM_ALLY, hero, at, "[QA]")
	add_child(f)
	f.set_physics_process(false)
	f.global_position = at
	return f


## A guild fighter's casts (guild war, maze, team buffs): its mate gets only the party
## buffs (the hero's party in a war: GuildWarMatch.buff_reaches on top).
func _guild_fighter_casts() -> void:
	_profile(&"warrior")
	var hero := Hero.new()
	add_child(hero)
	hero.field = self
	hero.set_physics_process(false)
	hero.global_position = Vector3(40, 0, 40)
	await get_tree().process_frame
	var mate := _fighter(&"warrior", Vector3(2, 0, 0), hero, 1)
	var seed_value := 10
	for cls in ClassData.IDS:
		var caster := _fighter(cls, Vector3.ZERO, hero, seed_value)
		seed_value += 1
		await get_tree().process_frame
		for skill in buff_skills(cls).filter(func(s): return not s.has("star")):
			mate._atk_boost = 1.0
			mate._def_boost = 1.0
			mate._buff_art.clear(mate)
			caster._resolve(skill, null, Vector3.ZERO)
			var want := expected(cls, skill)
			var id := String(skill.id)
			var on_mate := BuffBook.contains(mate._buff_art.buffs, id, true)
			check(on_mate == want, "fighter %s %s: its mate %s it" % [cls, id, "gets" if want else "does not get"])
			if not want:
				check(mate._atk_boost == 1.0 and mate._def_boost == 1.0, "fighter %s %s: the mate's stats stay" % [cls, id])
		# The AI's upkeep: a self buff is worth no more with the party around.
		for skill in buff_skills(cls).filter(func(s): return not s.has("star") and not BuffBook.is_song_skill(s)):
			if not expected(cls, skill):
				caster._buff_art.clear(caster)
				var with_party := caster._upkeep_score(skill, 5.0)
				check(is_equal_approx(with_party, GuildFighter.UPKEEP_SCORE + 0.01 * float(skill.get("level", 0)) + (2.0 if ClassData.is_signature(skill) else 0.0)) or with_party == 0.0, "fighter %s %s: no party bonus for a self buff (%.2f)" % [cls, skill.id, with_party])
				break
		caster.queue_free()
		await get_tree().process_frame
	mate.queue_free()
	hero.queue_free()
	await get_tree().process_frame


## The summoner's Fairy Spirit is a summon that heals, not a buff: she still heals the
## whole party near her (party members and their summons), not only her summoner.
func _fairy() -> void:
	_profile(&"summoner")
	var hero := Hero.new()
	add_child(hero)
	hero.field = self
	hero.set_physics_process(false)
	hero.refresh_stats()
	await get_tree().process_frame
	var fairy := Summon.new()
	fairy.setup(hero, "fairy_spirit", {"kind": "fairy", "count": 1, "secs": 120.0, "interval": 1.0}, 1.0, 0, 1, 1)
	add_child(fairy)
	fairy.set_process(false)
	await get_tree().process_frame
	var mate := Mate.new("companions")
	add_child(mate)
	mate.global_position = fairy.global_position + Vector3(1.5, 0, 0)
	var mates_summon := Mate.new("summons")
	add_child(mates_summon)
	mates_summon.global_position = fairy.global_position + Vector3(-1.5, 0, 0)
	Game.profile.hp = int(float(hero.stats.max_hp) * 0.5)
	var before := int(Game.profile.hp)
	fairy._heal_timer = 0.0
	fairy._process(0.1)
	check(int(Game.profile.hp) > before, "the fairy heals her summoner (%d -> %d)" % [before, int(Game.profile.hp)])
	# (Her heal on the hero also passes on to the members near the hero: Hero._heal.)
	check(mate.healed >= Summon.FAIRY_ALLY_HEAL - 0.001, "the fairy heals a party member near her (%.2f)" % mate.healed)
	check(is_equal_approx(mates_summon.healed, Summon.FAIRY_ALLY_HEAL), "and a party mate's summon near her (%.2f)" % mates_summon.healed)
	fairy.free()
	mate.queue_free()
	mates_summon.queue_free()
	hero.queue_free()
	await get_tree().process_frame
