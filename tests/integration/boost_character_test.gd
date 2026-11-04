extends Node
## The owner boost tool: one named character to Lv.100 / ★200, fully advanced, in the
## best +10 gear; a name the account lacks can be created first.
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

const Boost := preload("res://tools/boost_character.gd")
const BEST := ["weapon", "armor", "helm", "boots", "wings"]


func _ready() -> void:
	WorldEvents.festival_enabled = false
	Game.set_process(false)
	Game.new_profile(&"warrior", "Other", FaceKit.default_look())
	var other: Dictionary = Game.profile.duplicate(true)
	Game.new_profile(&"defender", "Assotix", FaceKit.default_look())
	Game.add_exp(40000)
	var old_weapon: Dictionary = Game.profile.equip.get("weapon", {})
	var level0 := int(Game.profile.level)
	check(level0 > 5 and level0 < 100, "fixture starts part way (Lv.%d)" % level0)
	# The cloud bundle arrives as JSON, so every number is a float.
	var bundle: Dictionary = JSON.parse_string(JSON.stringify({"slots": {"1": other, "3": Game.profile}, "selectedSlot": 3}))
	var untouched: Dictionary = bundle.slots["1"].duplicate(true)
	check(Boost.boost_bundle(bundle.duplicate(true), "Nobody").has("error"), "an unknown name changes nothing")
	check(Boost.boost_bundle(bundle.duplicate(true), "Assotix", "mage").has("error"), "a class mismatch changes nothing")
	var result := Boost.boost_bundle(bundle, "assotix ", "defender")
	check(not result.has("error") and result.get("slot") == "3", "the named defender is found in slot 3 (%s)" % str(result))
	var hero: Dictionary = bundle.slots["3"]
	check(int(hero.level) == 100 and int(hero.paragon.level) == 200, "Lv.100 and 200 stars")
	check(int(hero.adv) == JobData.LEGEND_ADV, "every level advancement is taken, not the ★300 God step (adv %d)" % int(hero.adv))
	check(result.get("created") == false, "an existing character is not reported as new")
	check(int(hero.paragon.points) == 200 and int(hero.paragon.spent) == 0, "all 200 star points are free to spend")
	check(int(hero.points) >= (100 - level0) * Game.STAT_POINTS_PER_LEVEL, "stat points for every level gained")
	check(int(hero.flags.get("star_reward_200", 0)) == 1, "the ★200 milestone reward is paid")
	for key in ItemData.EQUIP_SLOTS:
		var piece: Dictionary = hero.equip.get(key, {})
		check(int(piece.get("plus", 0)) == ItemData.MAX_PLUS, "%s is +10" % key)
		check(String(piece.get("class", "defender")) == "defender" or key in ["ring", "amulet"], "%s is defender gear" % key)
	for key in DivineGearData.SLOTS:
		check(DivineGearData.is_item(hero.equip[key]), "%s is the divine set" % key)
	check(int(hero.equip.ring.rarity) == 4 and int(hero.equip.amulet.rarity) == 4, "mythic ring and amulet")
	check(StarWingData.is_wing(hero.equip.wings) and int(hero.equip.wings.rarity) == 4, "mythic star wings")
	var kept := false
	for piece in hero.inv + hero.get("storage", []):
		if piece is Dictionary and piece.get("uid") == old_weapon.get("uid"):
			kept = true
	check(old_weapon.is_empty() or kept, "the old weapon moves to the bag")
	check(Game._valid_profile(hero), "the result passes the save check")
	check(bundle.slots["1"] == untouched, "other characters are untouched")
	# A hero still in the starter class takes the asked class the game's own way.
	Game.new_profile(ClassData.START, "Assotix", FaceKit.default_look())
	Game.add_exp(9000)
	var starter: Dictionary = JSON.parse_string(JSON.stringify({"slots": {"1": Game.profile}, "selectedSlot": 1}))
	var changed := Boost.boost_bundle(starter, "Assotix", "defender")
	var convert: Dictionary = starter.slots["1"]
	check(not changed.has("error") and String(convert["class"]) == "defender", "a vagabond becomes a defender (%s)" % str(changed))
	check(int(convert.level) == 100 and int(convert.paragon.level) == 200 and DivineGearData.is_item(convert.equip.weapon) and String(convert.equip.weapon["class"]) == "defender", "and gets the same boost")
	check(Game._valid_profile(convert), "the converted hero passes the save check")
	# A name the account has no character for: created in the first free slot, then boosted.
	var roster: Dictionary = JSON.parse_string(JSON.stringify({"slots": {"1": other, "3": Game.profile}, "selectedSlot": 1}))
	var kept_slots: Dictionary = roster.slots.duplicate(true)
	check(Boost.boost_bundle(roster.duplicate(true), "มีดมาร", "assassin").has("error"), "without create an unknown name still changes nothing")
	check(Boost.boost_bundle(roster.duplicate(true), "มีดมาร", "", true).has("error"), "creating needs a class")
	check(Boost.boost_bundle(roster.duplicate(true), "ชื่อยาวเกินสิบสี่ตัวอักษร", "assassin", true).has("error"), "creating refuses a name the creator would")
	var made := Boost.boost_bundle(roster, "มีดมาร", "assassin", true, 0)
	var fresh: Dictionary = roster.slots.get("2", {})
	check(not made.has("error") and made.get("slot") == "2" and made.get("created") == true, "the new character takes free slot 2 (%s)" % str(made))
	check(String(fresh.get("name", "")) == "มีดมาร" and String(fresh.get("class", "")) == "assassin", "named มีดมาร, an assassin")
	check(int(fresh.get("level", 0)) == 100 and int(fresh.get("paragon", {}).get("level", 0)) == 200 and int(fresh.get("adv", 0)) == JobData.LEGEND_ADV, "Lv.100, 200 stars, fully advanced up to legend")
	for key in BEST:
		check(int(fresh.equip[key].get("plus", -1)) == ItemData.MAX_PLUS and String(fresh.equip[key]["class"]) == "assassin", "new %s is assassin gear at +10" % key)
	check(DivineGearData.is_item(fresh.equip.weapon) and StarWingData.is_wing(fresh.equip.wings) and int(fresh.equip.wings.plus) == ItemData.MAX_PLUS, "divine weapon and star wings +10")
	check(int(fresh.equip.ring.plus) == 0 and int(fresh.equip.amulet.plus) == 0 and int(fresh.equip.ring.rarity) == 4 and int(fresh.equip.amulet.rarity) == 4, "mythic ring and amulet at +0")
	check(Game._valid_profile(fresh), "the new character passes the save check")
	check(roster.slots["1"] == kept_slots["1"] and roster.slots["3"] == kept_slots["3"], "the other slots are untouched")
	var every := {}
	for n in range(1, Game.SLOT_COUNT + 1):
		every[str(n)] = other
	var full: Dictionary = JSON.parse_string(JSON.stringify({"slots": every, "selectedSlot": 1}))
	check(Boost.boost_bundle(full, "มีดมาร", "assassin", true).has("error"), "no new character when every slot is taken")
	var again := Boost.boost_bundle(roster, "มีดมาร", "assassin", true, 0)
	check(again.get("slot") == "2" and again.get("created") == false and roster.slots.size() == 3, "running it again boosts the same character, no duplicate")
	# ★300 (the God step too), a Lv.5 fire drake as the active mount, ring and amulet +0.
	Game.new_profile(&"archer", "กาชาปอง", FaceKit.default_look())
	var god: Dictionary = JSON.parse_string(JSON.stringify({"slots": {"1": other, "2": Game.profile}, "selectedSlot": 2}))
	var top := Boost.boost_bundle(god, "กาชาปอง", "", false, 0, Game.PARAGON_MAX, "fire_drake", MountData.MAX_LEVEL)
	var gp: Dictionary = god.slots["2"]
	check(not top.has("error") and int(gp.level) == 100 and int(gp.paragon.level) == Game.PARAGON_MAX, "Lv.100 and ★300 (%s)" % str(top))
	check(int(gp.adv) == JobData.GOD_ADV, "★300 takes the God step too (adv %d)" % int(gp.adv))
	check(String(gp["class"]) == "archer", "no class given keeps the class")
	for key in BEST:
		check(int(gp.equip[key].plus) == 15 and ItemData.MAX_PLUS == 15, "%s +15" % key)
	check(int(gp.equip.ring.plus) == 0 and int(gp.equip.amulet.plus) == 0, "ring and amulet +0")
	check(String(gp.mount) == "fire_drake" and int(gp.mounts.fire_drake) == MountData.MAX_LEVEL, "fire drake Lv.5 is the active mount")
	check(Game._valid_profile(gp), "the ★300 hero passes the save check")
	# A second run with the 250-star set: all six set pieces, the star wings kept.
	var wings_uid := String(gp.equip.wings.get("uid", ""))
	var set_run := Boost.boost_bundle(god, "กาชาปอง", "", false, 0, Game.PARAGON_MAX, "fire_drake", MountData.MAX_LEVEL, "set250")
	var sp: Dictionary = god.slots["2"]
	check(not set_run.has("error"), "the set run works (%s)" % str(set_run))
	for key in SetGearData.SLOTS:
		check(SetGearData.is_item(sp.equip[key]) and SetGearData.item_class(sp.equip[key]) == "archer", "%s is the archer's 250-star set" % key)
		check(int(sp.equip[key].plus) == (0 if key in ["ring", "amulet"] else 15), "%s at +%d" % [key, 0 if key in ["ring", "amulet"] else 15])
	check(String(sp.equip.wings.get("uid", "")) == wings_uid and int(sp.equip.wings.plus) == 15, "the +15 star wings are kept")
	var divine_in_bag := 0
	for piece in sp.inv:
		if piece is Dictionary and DivineGearData.is_item(piece):
			divine_in_bag += 1
	check(divine_in_bag == 4, "the divine pieces moved to the bag (%d)" % divine_in_bag)
	var keep_profile: Dictionary = Game.profile
	Game.profile = sp
	for key in SetGearData.SLOTS:
		check(Game.equip_problem(sp.equip[key]) == "", "the hero may wear the set %s (%s)" % [key, Game.equip_problem(sp.equip[key])])
	Game.profile = keep_profile
	check(Game._valid_profile(sp), "the set hero passes the save check")
	Game.profile = hero
	Game.has_profile = true
	var stats := Game.stats_now()
	check(int(hero.hp) == int(stats.max_hp) and int(hero.mp) == int(stats.max_mp), "full HP and MP")
	print("BOOST TEST: %s | %d checks, %d failures | HP %d DEF %d ATK %d" % ["PASS" if failures == 0 else "FAIL", checks, failures, int(stats.max_hp), int(stats.def), int(stats.atk)])
	get_tree().quit(0 if failures == 0 else 1)
