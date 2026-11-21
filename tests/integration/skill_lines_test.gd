extends Node
## Skill lines (ClassData.LINE_FILES): a converted class has exactly 8 bar skills that
## EVOLVE with level. Checks per converted class: 8 lines unlocking at Lv.1/5/10/15/20/
## 30/40/50, each stage at its level (and only with the advancement its level needs),
## the bar slot and the star rank kept across an evolution, an old save's ranks moved
## to the lines with the rest refunded and the bar rebuilt, the AI (rivals, guild
## fighters, companions, world players) using the lines' current stages, 3 passives;
## and a class not converted yet working as before.
## To screenshot the skill menu and the Skill Master (a window, not --headless):
##   godot --path . res://tests/integration/skill_lines_test.tscn -- /abs/folder
var failures := 0
var checks := 0

## Unlock level of each line, in bar order (the plan's slots).
const UNLOCKS := [1, 5, 10, 15, 20, 30, 40, 50]
## The plan per converted class: each line's stages as [id, level].
const PLANS := {
	&"warrior": [
		[["raving", 1], ["triple_impact", 60], ["brandish", 90]],
		[["impact", 5], ["destroyer", 60], ["sword_of_justice", 90]],
		[["brutal_swing", 10], ["cyclone_strike", 60], ["grand_cross", 90]],
		[["roar", 15], ["bone_crash", 60], ["double_crash", 80]],
		[["sword_blast", 20], ["piercing", 60], ["divine_piercing", 90]],
		[["concentration", 30], ["berserker", 60], ["triumph_of_valhalla", 96]],
		[["holy_valor", 40], ["drastic_spirit", 70], ["godly_shield", 90]],
		[["rage_of_zecram", 50], ["gladiator", 100]],
	],
	&"archer": [
		[["wind_arrow", 1], ["perforation", 60], ["lightning_arrow", 90]],
		[["elemental_shot", 5], ["phoenix_shot", 60], ["lethal_sight", 90]],
		[["arrow_of_rage", 10], ["fierce_wind", 60], ["dragon_shot", 90]],
		[["avalanche", 15], ["tempest", 60], ["phoenix_rain", 90]],
		[["ensnare", 20], ["hurricane", 70]],
		[["scout_hawk", 30], ["dionic_sight", 60], ["spirit_of_wind", 90]],
		[["golden_falcon", 40], ["recall_wolverine", 60], ["force_of_nature", 80]],
		[["meteor_arrow", 50]],
	],
	&"mage": [
		[["fire_bolt", 1], ["dead_ray", 60], ["judgment_ray", 90]],
		[["agony", 5], ["slow_speed", 60]],
		[["fire_ball", 10], ["meteo", 60], ["hell_meteor", 90]],
		[["watornado", 15], ["ice_storm", 70]],
		[["flame_wave", 20], ["spirit_burst", 80]],
		[["enchant_weapon", 30], ["silraphim", 60], ["magic_overdrive", 90]],
		[["energy_shield", 40], ["vague", 70]],
		[["thunder_storm", 50], ["armageddon", 100]],
	],
	&"priest": [
		[["holy_bolt", 1], ["judgement_light", 60], ["divine_judgment", 90]],
		[["healing", 5], ["hand_of_god", 60], ["prayer", 90]],
		[["multi_spark", 10], ["vigor_ball", 40], ["seraphim_wrath", 90]],
		[["divine_lightning", 15], ["chain_lightning", 60]],
		[["holy_mind", 20], ["glacial_spike", 60]],
		[["holy_reflection", 30], ["blessing_aura", 64], ["miracle", 96]],
		[["extinction", 40], ["heaven_light", 70], ["last_judgement", 100]],
		[["summon_muspell", 50]],
	],
	&"assassin": [
		[["twin_fang", 1], ["eclipse_fang", 80]],
		[["venom_edge", 5], ["crimson_cut", 60]],
		[["shadow_step", 10], ["throat_slit", 70]],
		[["blade_flurry", 15], ["thousand_cuts", 60], ["abyss_vortex", 90]],
		[["fan_of_knives", 20], ["phantom_legion", 90]],
		[["smoke_bomb", 30], ["midnight_execution", 80]],
		[["killing_focus", 40], ["night_lord", 76], ["shadow_sovereign", 96]],
		[["shadow_dance", 50], ["oblivion_requiem", 100]],
	],
	&"darklord": [
		[["force", 1], ["chaos_strike", 60], ["chaos_sovereign", 90]],
		[["fire_burst", 5], ["fire_scream", 40], ["dark_comet", 80]],
		[["earthshake", 10], ["earth_dominion", 90]],
		[["electric_spike", 15], ["thunder_lord", 70]],
		[["birds", 20], ["raven_storm", 88]],
		[["commanders_aura", 30], ["lord_of_command", 76], ["emperors_command", 96]],
		[["summon", 40]],
		[["infernal_scream", 50], ["imperial_judgment", 100]],
	],
	&"bard": [
		[["staccato_shot", 1], ["heartstring", 60], ["aria_of_ruin", 90]],
		[["valor_march", 5], ["heroic_anthem", 60], ["hymn_of_legends", 96]],
		[["discord", 10], ["shattering_rhapsody", 70], ["grand_dissonance", 90]],
		[["sorrow_note", 15], ["lament", 60]],
		[["echo_chain", 20], ["eternal_echo", 80]],
		[["iron_ballad", 30], ["sanctuary_serenade", 64]],
		[["slumber_lullaby", 40], ["thunder_crescendo", 92]],
		[["grand_finale", 50]],
	],
	&"summoner": [
		[["thorn_shot", 1], ["sylvan_ray", 76]],
		[["vine_lash", 5], ["nature_wrath", 60]],
		[["entangle", 10], ["world_tree", 80]],
		[["spore_burst", 15], ["earth_shatter", 64], ["cataclysm", 96]],
		[["thorn_storm", 20]],
		[["forest_blessing", 30], ["spirit_link", 72], ["gaia_blessing", 88]],
		[["regrowth", 40], ["life_bloom", 60], ["fairy_spirit", 84]],
		[["wolf_pack", 50], ["alpha_wolves", 70], ["primal_legion", 90], ["elder_dragon", 100]],
	],
	&"lancer": [
		[["thrust", 1], ["dragon_tooth", 60], ["sky_pierce", 90]],
		[["stagger", 5], ["hook_strike", 60]],
		[["whirl", 10], ["typhoon_spear", 60], ["gale_cyclone", 90]],
		[["charge_dash", 15], ["vanguard_strike", 70]],
		[["spear_wave", 20], ["dragon_lance", 80]],
		[["wind_stance", 30], ["lancer_rush", 64], ["valkyrie_blessing", 88]],
		[["iron_resolve", 40], ["dragon_stance", 76]],
		[["gungnir", 50], ["ragnarok_lance", 100]],
	],
	&"defender": [
		[["shield_bash", 1], ["aegis_strike", 60], ["judgment_shield", 90]],
		[["brace", 5]],
		[["shield_slam", 10], ["bastion_crush", 70]],
		[["provoke", 15], ["grand_provoke", 72]],
		[["ground_quake", 20], ["titan_quake", 60], ["holy_rampart", 80]],
		[["iron_wall", 30], ["sanctuary_wall", 96]],
		[["thorn_guard", 40], ["unbreakable", 76], ["aegis_of_ages", 88]],
		[["meteor_shield", 50], ["world_bastion", 100]],
	],
	&"muaythai": [
		[["jab_cross", 1], ["flame_hook", 60], ["sun_fist", 90]],
		[["back_elbow", 5], ["flying_knee", 60], ["thunder_elbow", 90]],
		[["ring_throw", 10], ["twin_rings", 60], ["mantra_storm", 90]],
		[["push_kick", 15], ["body_throw", 70], ["earth_kick", 90]],
		[["sweep_kick", 20], ["flame_ring_spin", 60], ["fire_dragon_circle", 80]],
		[["wai_khru", 30], ["ram_muay", 60], ["sacred_mongkhon", 96]],
		[["ring_guard", 40], ["iron_prajiad", 70]],
		[["thousand_ring_fist", 50], ["muay_king", 100]],
	],
}


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func settle() -> void:
	for i in 5:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	await get_tree().process_frame
	for cls in PLANS:
		_check_shape(cls)
		_check_hero(cls)
		_check_ai(cls)
	_check_warrior_migration()
	_check_priest_migration()
	_check_bard_migration()
	_check_darklord_redesign()
	_check_defender_migration()
	_check_summoner_migration()
	_check_unconverted()
	await _check_screens()
	print("skill_lines_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _tier(level: int) -> int:
	return 1 + JobData.adv_for_level(level)


func _check_shape(cls: StringName) -> void:
	check(ClassData.has_lines(cls), "%s has skill lines" % cls)
	var plan: Array = PLANS[cls]
	var ids := ClassData.line_ids(cls)
	check(ids.size() == ClassData.SLOTS, "%s: %d lines" % [cls, ClassData.SLOTS])
	for i in plan.size():
		var stages := ClassData.line_stages(cls, String(plan[i][0][0]))
		check(ids[i] == String(plan[i][0][0]), "%s: line %d is %s" % [cls, i + 1, plan[i][0][0]])
		check(int(plan[i][0][1]) == UNLOCKS[i], "%s: line %d unlocks at Lv.%d" % [cls, i + 1, UNLOCKS[i]])
		check(stages.size() == plan[i].size(), "%s: line %s has %d stages" % [cls, ids[i], plan[i].size()])
		for k in mini(stages.size(), plan[i].size()):
			var stage: Dictionary = stages[k]
			check(String(stage.id) == String(plan[i][k][0]) and int(stage.level) == int(plan[i][k][1]), "%s: stage %d of %s is %s at Lv.%d (got %s Lv.%d)" % [cls, k + 1, ids[i], plan[i][k][0], plan[i][k][1], stage.get("id", ""), int(stage.get("level", 0))])
			check(String(stage.get("skill_line", "")) == ids[i] and ClassData.line_of(cls, String(stage.id)) == ids[i] and ClassData.rank_id(stage) == ids[i], "%s: %s belongs to line %s" % [cls, stage.get("id", ""), ids[i]])
			check(String(stage.get("name", "")) != "" and String(stage.get("desc", "")) != "" and stage.has("shape") and stage.has("icon"), "%s: %s is a whole skill" % [cls, stage.get("id", "")])
	# Every non-star skill of the pool is a stage of a line.
	for skill in ClassData.pool(cls):
		check(skill.has("star") or skill.has("skill_line"), "%s: %s is in a line" % [cls, skill.id])
	check(ClassData.passives(cls).size() == 3, "%s: 3 passives" % cls)


func _check_hero(cls: StringName) -> void:
	var plan: Array = PLANS[cls]
	Game.new_profile(cls, "Lines QA", FaceKit.default_look())
	check(Game.loadout() == ["%s" % plan[0][0][0], "", "", "", "", "", "", ""], "%s: a new hero has its first line on the bar" % cls)
	for level in [1, 5, 10, 15, 20, 30, 40, 50, 59, 60, 70, 80, 90, 96, 100]:
		Game.profile.level = level
		Game.profile.adv = JobData.adv_for_level(level)
		Game.fill_loadout()
		var bar := Game.loadout()
		var skills := Game.loadout_skills()
		for i in plan.size():
			var want := ""
			for stage in plan[i]:
				if level >= int(stage[1]):
					want = String(stage[0])
			if want == "":
				check(String(bar[i]) == "", "%s Lv.%d: slot %d empty before its line unlocks" % [cls, level, i + 1])
				continue
			check(String(bar[i]) == String(plan[i][0][0]), "%s Lv.%d: slot %d holds line %s (got %s)" % [cls, level, i + 1, plan[i][0][0], bar[i]])
			check(String((skills[i] as Dictionary).get("id", "")) == want, "%s Lv.%d: slot %d casts %s (got %s)" % [cls, level, i + 1, want, (skills[i] as Dictionary).get("id", "")])
			check(Game.skill_unlocked(skills[i]), "%s Lv.%d: %s usable" % [cls, level, want])
		var pool_ids := Game.skill_pool().filter(func(s): return not s.has("star")).map(func(s): return String(s.id))
		check(pool_ids.size() == ClassData.SLOTS, "%s Lv.%d: the skill screens list 8 lines" % [cls, level])
	# An evolution waits for the advancement its level needs.
	# (line 1's first evolution: Lv.60 for most classes, Lv.76 for the summoner)
	var evo := int(plan[0][1][1])
	Game.profile.level = evo
	Game.profile.adv = JobData.adv_for_level(evo) - 1
	check(String(Game.loadout_skills()[0].id) == String(plan[0][0][0]), "%s: Lv.60 without the 3rd advancement keeps the first stage" % cls)
	check(Game.evolution_note(Game.loadout_skills()[0]).contains("ต้องเปลี่ยนเป็น"), "%s: the screens say the advancement is missing" % cls)
	Game.profile.adv = JobData.adv_for_level(evo)
	check(String(Game.loadout_skills()[0].id) == String(plan[0][1][0]), "%s: with it the line evolves" % cls)
	# Rank and bar slot belong to the line.
	Game.profile.level = 30
	Game.profile.adv = JobData.adv_for_level(30)
	var line := String(plan[0][0][0])
	Game.profile.skills = {line: 4}
	Game.profile.skill_points = 3
	Game.profile.gold = 1000000
	check(Game.evolution_note(Game.loadout_skills()[0]) == "ขั้น 1/%d • วิวัฒน์ที่ Lv.%d → %s" % [plan[0].size(), int(plan[0][1][1]), ClassData.find_skill(cls, String(plan[0][1][0])).name], "%s: the screens show the next evolution (%s)" % [cls, Game.evolution_note(Game.loadout_skills()[0])])
	check(Game.equip_skill(String(plan[0][0][0]), 3), "%s: move line 1 to slot 4" % cls)
	Game.profile.level = 100
	Game.profile.adv = JobData.adv_for_level(100)
	Game.fill_loadout()
	var top: Dictionary = Game.loadout_skills()[3]
	check(String(top.id) == String(plan[0][-1][0]) and String(Game.loadout()[3]) == line, "%s: the line evolved in place (slot 4, %s)" % [cls, top.get("id", "")])
	check(Game.effective_rank(top) == 4, "%s: the evolved stage keeps the line's 4 stars" % cls)
	check(Game.upgrade_skill(top) and int(Game.profile.skills.get(line, 0)) == 5 and not Game.profile.skills.has(String(top.id)), "%s: upgrading the evolved stage raises the line" % cls)
	check(Game.equip_skill(String(top.id), 0) and String(Game.loadout()[0]) == line, "%s: equipping a stage id puts its line on the bar" % cls)
	check(Game.evolution_note(top).ends_with("ร่างสุดท้าย"), "%s: the last stage says so" % cls)


## The index of the first line of [param plan] whose second stage comes at Lv.60.
func _evolves_at_60(plan: Array) -> int:
	for i in plan.size():
		if plan[i].size() > 1 and int(plan[i][1][1]) == 60:
			return i
	return 0


func _check_ai(cls: StringName) -> void:
	for level in [26, 70, 100]:
		var tier := _tier(level)
		var known := ClassData.pool(cls).filter(func(s): return ClassData.knows(s, level, tier, 0))
		var want := ClassData.kit(cls, level, tier).filter(func(s): return not s.has("star") and int(s.level) <= level)
		check(known.map(func(s): return String(s.id)) .size() == want.size() and want.all(func(s): return known.has(s)), "%s Lv.%d: AI fighters know exactly the lines' current stages" % [cls, level])
		var kit := ClassData.ai_buff_kit(cls, level, "Somchai")
		check(kit.all(func(id): return ClassData.is_line(cls, String(id))), "%s Lv.%d: the AI buff kit holds lines %s" % [cls, level, kit])
		for skill in known:
			if ClassData.is_buff_skill(skill):
				check(ClassData.ai_allows(skill, kit) == kit.has(String(skill.skill_line)), "%s Lv.%d: buff %s allowed by its line" % [cls, level, skill.id])
		var ranks := WorldPlayers.skill_ranks(cls, level, 0)
		check(ranks.keys().all(func(id): return ClassData.is_line(cls, String(id)) or ClassData.find_skill(cls, String(id)).has("star")), "%s Lv.%d: world players rank lines %s" % [cls, level, ranks.keys()])
	# A rival past line 1's first evolution casts the evolved stage, not the first one.
	var first: Dictionary = ClassData.find_skill(cls, ClassData.line_ids(cls)[0])
	var later := int(first.next_level) + 10
	check(not ClassData.knows(first, later, _tier(later), 0) and ClassData.knows(first, 30, _tier(30), 0), "%s: the first stage is cast at Lv.30, replaced by Lv.%d" % [cls, later])


func _check_warrior_migration() -> void:
	Game.new_profile(&"warrior", "Old Save", FaceKit.default_look())
	var data: Dictionary = Game.profile.duplicate(true)
	data.level = 90
	data.adv = JobData.adv_for_level(90)
	data.skill_points = 0
	data.skills = {"raving": 2, "triple_impact": 5, "brandish": 3, "avenging_crash": 4, "swift_axe": 1,
		"weapon_mastery": 3, "melee_mastery": 2, "holy_body": 5, "concentration": 3, "lionfang_cleave": 2}
	data.loadout = ["avenging_crash", "brandish", "destroyer", "swift_axe", "grand_cross", "", "raving", "lionfang_cleave"]
	Game._migrate_skills(data)
	# raving: max(2, 5, 3) = 5, refund 1 + 2; avenging_crash 3, swift_axe 0; melee_mastery
	# max(3, 2), refund 1; holy_body -> physical_training 5.
	check(int(data.skill_points) == 7, "old warrior save: 7 points refunded (got %d)" % int(data.skill_points))
	check(data.skills == {"raving": 5, "melee_mastery": 3, "physical_training": 5, "concentration": 3, "lionfang_cleave": 2}, "old warrior save: ranks moved to the lines %s" % data.skills)
	var bar: Array = data.loadout
	check(String(bar[1]) == "raving" and String(bar[2]) == "impact" and String(bar[4]) == "brutal_swing", "old warrior save: stages became their lines in place %s" % [bar])
	check(String(bar[7]) == "" or String(bar[7]) == "lionfang_cleave" or ClassData.is_line(&"warrior", String(bar[7])), "old warrior save: a star skill may stay %s" % [bar])
	var lines := bar.filter(func(id): return ClassData.is_line(&"warrior", String(id)))
	check(lines.size() == ClassData.SLOTS and bar.count("raving") == 1, "old warrior save: the bar holds the 8 lines, once each %s" % [bar])
	var again := data.duplicate(true)
	Game._migrate_skills(again)
	check(again.skill_points == data.skill_points and again.skills == data.skills and again.loadout == data.loadout, "the move is done once (a second load changes nothing)")
	# The whole save check passes too.
	check(Game._valid_profile(data.duplicate(true)), "a moved old save passes the save check")


## The priest: its heals stay the first stage of their line (AI_ALL_HEALS keeps them by
## line id), merged passives carry their best rank, the dropped heals refund.
func _check_priest_migration() -> void:
	Game.new_profile(&"priest", "Old Priest", FaceKit.default_look())
	var data: Dictionary = Game.profile.duplicate(true)
	data.level = 90
	data.adv = JobData.adv_for_level(90)
	data.skill_points = 0
	data.skills = {"healing": 2, "hand_of_god": 3, "grand_healing": 4, "faith": 3, "divine_grace": 2, "sanctity": 5, "holy_bolt": 1}
	data.loadout = ["grand_healing", "hand_of_god", "holy_bolt", "virtual_life", "", "", "", ""]
	Game._migrate_skills(data)
	# healing max(2, 3), refund 1; grand_healing 3; divine_grace max(3, 2, 5), refund 1 + 2.
	check(int(data.skill_points) == 7, "old priest save: 7 points refunded (got %d)" % int(data.skill_points))
	check(data.skills == {"healing": 3, "divine_grace": 5, "holy_bolt": 1}, "old priest save: ranks moved to the lines %s" % data.skills)
	check(String(data.loadout[1]) == "healing" and String(data.loadout[2]) == "holy_bolt", "old priest save: Hand of God became the heal line in place %s" % [data.loadout])
	check(Game._valid_profile(data.duplicate(true)), "a moved old priest save passes the save check")
	var kit := ClassData.ai_buff_kit(&"priest", 100, "Somchai")
	check(kit.has("healing") and kit.has("holy_reflection"), "an AI Priest at Lv.100 keeps Prayer and Miracle (heals that buff) by line id %s" % [kit])
	check(ClassData.current_stage(&"priest", "healing", 100, 5).id == "prayer", "the heal line ends in Prayer")
## The Bard: its songs are still their lines (the song slots and AI work by line id);
## the self-only stances are gone and their points come back; merged passives keep
## the higher rank.
func _check_bard_migration() -> void:
	for id in ["valor_march", "heroic_anthem", "hymn_of_legends", "iron_ballad", "sanctuary_serenade"]:
		var song := ClassData.find_skill(&"bard", id)
		check(BuffBook.is_song_skill(song), "bard: %s is a song" % id)
	check(ClassData.line_of(&"bard", "hymn_of_legends") == "valor_march" and ClassData.line_of(&"bard", "sanctuary_serenade") == "iron_ballad", "bard: the songs keep their lines (attack / ward)")
	check(ClassData.find_skill(&"bard", "virtuoso").is_empty() and ClassData.find_skill(&"bard", "maestro_fervor").is_empty(), "bard: the stances are gone")
	Game.new_profile(&"bard", "Old Bard", FaceKit.default_look())
	var data: Dictionary = Game.profile.duplicate(true)
	data.level = 80
	data.adv = JobData.adv_for_level(80)
	data.skill_points = 0
	data.skills = {"staccato_shot": 2, "heroic_anthem": 4, "virtuoso": 3, "maestro_fervor": 2, "lute_mastery": 1, "harmonic_power": 4}
	data.loadout = ["virtuoso", "heroic_anthem", "staccato_shot", "maestro_fervor", "", "", "", ""]
	Game._migrate_skills(data)
	# heroic_anthem 4 -> valor_march; virtuoso 3 and maestro_fervor 2 refund 2 + 1;
	# lute_mastery max(1, 4), the rank 1 refunds nothing.
	check(int(data.skill_points) == 3, "old bard save: 3 points refunded (got %d)" % int(data.skill_points))
	check(int(data.skills.get("valor_march", 0)) == 4 and int(data.skills.get("lute_mastery", 0)) == 4 and not data.skills.has("virtuoso") and not data.skills.has("maestro_fervor"), "old bard save: ranks moved to the lines %s" % data.skills)
	check(not (data.loadout as Array).has("virtuoso") and (data.loadout as Array).has("valor_march"), "old bard save: the bar holds the song line, no stance %s" % [data.loadout])
	check(Game._valid_profile(data.duplicate(true)), "a moved old bard save passes the save check")


## The Dark Lord's redesigns: the raven marks its target for the party and a lone
## target takes every raven; Imperial Judgment pulls monsters in instead of pushing.
func _check_darklord_redesign() -> void:
	for id in ["birds", "raven_storm"]:
		var raven := ClassData.find_skill(&"darklord", id)
		check(bool(raven.get("converge", false)) and raven.get("fx", {}).get("raven_mark") is Array, "darklord: %s converges and marks" % id)
	var judgment := ClassData.find_skill(&"darklord", "imperial_judgment")
	check(judgment.fx.has("pull") and not judgment.fx.has("repel"), "darklord: Imperial Judgment pulls, never pushes")
	# The mark: the marking party deals +15% to the target for 5 s, nobody else does.
	var target := Node3D.new()
	add_child(target)
	var hero := Hero.new()
	var other := Node.new()
	check(is_zero_approx(ClassRoles.raven_bonus(hero, target)), "an unmarked target takes no raven bonus")
	ClassRoles.raven_mark(hero, target, ClassData.find_skill(&"darklord", "birds").fx.raven_mark)
	check(is_equal_approx(ClassRoles.raven_bonus(hero, target), 0.15), "the raven's mark: +15%% from the marking party (got %.2f)" % ClassRoles.raven_bonus(hero, target))
	check(is_zero_approx(ClassRoles.raven_bonus(other, target)), "the raven's mark does nothing for someone outside the party")
	var marks: Dictionary = target.get_meta(ClassRoles.RAVEN_META)
	marks["hero"] = [Time.get_ticks_msec() - 1, 0.15]
	check(is_zero_approx(ClassRoles.raven_bonus(hero, target)), "the raven's mark wears off")
	hero.free()
	other.free()
	target.queue_free()


## Old Defender save: เบ่งเลือด keeps its id and stars (its line is "brace"), dropped skills
## refund, merged passives keep the higher rank.
func _check_defender_migration() -> void:
	Game.new_profile(&"defender", "Old Tank", FaceKit.default_look())
	var data: Dictionary = Game.profile.duplicate(true)
	data.level = 90
	data.adv = JobData.adv_for_level(90)
	data.skill_points = 0
	data.skills = {"brace": 4, "shield_wave": 3, "stalwart": 5, "shield_mastery": 2, "aegis_strike": 2, "shield_bash": 1, "iron_wall": 3}
	data.loadout = ["brace", "shield_wave", "aegis_strike", "iron_wall", "", "", "", ""]
	Game._migrate_skills(data)
	# shield_wave refunds 2, stalwart -> shield_mastery max(5, 2) refunds 1, shield_bash
	# max(1, 2) refunds 0.
	check(int(data.skill_points) == 3, "old defender save: 3 points refunded (got %d)" % int(data.skill_points))
	check(data.skills == {"brace": 4, "shield_mastery": 5, "shield_bash": 2, "iron_wall": 3}, "old defender save: ranks moved to the lines %s" % data.skills)
	var bar: Array = data.loadout
	check(bar.count("brace") == 1 and bar.count("shield_bash") == 1 and bar.count("iron_wall") == 1, "old defender save: เบ่งเลือด and the stages' lines stay on the bar %s" % [bar])
	check(ClassData.is_signature(ClassData.find_skill(&"defender", "brace")) and ClassData.is_line(&"defender", "brace"), "เบ่งเลือด is still the signature, by its line id")
	check(Game._valid_profile(data.duplicate(true)), "a moved old defender save passes the save check")


## Old Summoner save: the Fairy Spirit's rank goes to its line (Regrowth), dropped summons
## refund.
func _check_summoner_migration() -> void:
	Game.new_profile(&"summoner", "Old Caller", FaceKit.default_look())
	var data: Dictionary = Game.profile.duplicate(true)
	data.level = 90
	data.adv = JobData.adv_for_level(90)
	data.skill_points = 0
	data.skills = {"fairy_spirit": 4, "regrowth": 2, "life_bloom": 1, "spirit_cat": 3, "gaia_heart": 2, "wild_vitality": 1, "elder_dragon": 3}
	data.loadout = ["spirit_cat", "fairy_spirit", "elder_dragon", "", "", "", "", ""]
	Game._migrate_skills(data)
	# regrowth max(4, 2, 1) refunds 1 + 0, spirit_cat 2, wild_vitality max(2, 1) 0.
	check(int(data.skill_points) == 3, "old summoner save: 3 points refunded (got %d)" % int(data.skill_points))
	check(data.skills == {"regrowth": 4, "wild_vitality": 2, "wolf_pack": 3}, "old summoner save: ranks moved to the lines %s" % data.skills)
	check(String(data.loadout[1]) == "regrowth" and String(data.loadout[2]) == "wolf_pack", "old summoner save: the fairy and the dragon became their lines in place %s" % [data.loadout])
	check(Game._valid_profile(data.duplicate(true)), "a moved old summoner save passes the save check")


func _check_unconverted() -> void:
	for cls in ClassData.IDS:
		if ClassData.has_lines(cls):
			continue
		check(ClassData.kit(cls, 70, 4) == ClassData.pool(cls), "%s (not converted): its kit is its old pool" % cls)
		check(ClassData.passives(cls) == ClassData.PASSIVES.get(cls, []), "%s: its old passives" % cls)
		var ranks := {"x_old": 3}
		check(ClassData.migrate_ranks(cls, ranks) == 0 and ranks == {"x_old": 3}, "%s: no line move" % cls)
		for skill in ClassData.pool(cls):
			check(not skill.has("skill_line") and ClassData.is_current(skill, 1, 1) and ClassData.line_of(cls, String(skill.id)) == String(skill.id), "%s: %s is a plain skill" % [cls, skill.id])
		Game.new_profile(cls, "Old QA", FaceKit.default_look())
		Game.profile.level = 70
		Game.profile.adv = JobData.adv_for_level(70)
		Game.fill_loadout()
		if cls == &"defender":
			continue  # its signature (เบ่งเลือด) is kept on the bar on top of this
		var want := []
		for skill in ClassData.pool(cls):
			if want.size() < ClassData.SLOTS and Game.skill_unlocked(skill):
				want.append(String(skill.id))
		check(Game.loadout() == want, "%s: the bar fills with the first unlocked skills as before" % cls)


func _check_screens() -> void:
	Game.new_profile(&"warrior", "Lines QA", FaceKit.default_look())
	Game.profile.level = 70
	Game.profile.adv = JobData.adv_for_level(70)
	Game.profile.skill_points = 12
	Game.profile.gold = 1000000
	Game.fill_loadout()
	get_window().size = Vector2i(1688, 780)
	get_window().content_scale_size = Vector2i(1688, 780)
	var trainer := SkillTrainer.new()
	add_child(trainer)
	trainer.open_trainer()
	await settle()
	var text := " ".join(trainer._box.find_children("*", "Label", true, false).map(func(l): return String(l.text)))
	check(text.contains("วิวัฒน์ที่ Lv.90 → Brandish") and text.contains("Triple Impact"), "the Skill Master shows the current stage and the next evolution")
	var args := OS.get_cmdline_user_args()
	var shots := args.size() > 0 and DisplayServer.get_name() != "headless"
	if shots:
		DirAccess.make_dir_recursive_absolute(args[0])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0].path_join("skill_master_lines.png"))
	trainer.close_trainer()
	trainer.queue_free()
	await settle()
	var menu := GameMenu.new()
	add_child(menu)
	await settle()
	menu.open_menu(&"skills")
	await settle()
	await settle()
	var menu_text := " ".join(menu.find_children("*", "Label", true, false).map(func(l): return String(l.text)))
	check(menu_text.contains("วิวัฒน์ที่ Lv.90 → Sword of Justice"), "the skill menu shows the next evolution")
	if shots:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0].path_join("skill_menu_lines.png"))
	menu.queue_free()
	await settle()
