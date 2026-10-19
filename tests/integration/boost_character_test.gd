extends Node
## The owner boost tool: one named character to Lv.100 / ★200 in the best +10 gear.
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

const Boost := preload("res://tools/boost_character.gd")


func _ready() -> void:
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
	Game.profile = hero
	Game.has_profile = true
	var stats := Game.stats_now()
	check(int(hero.hp) == int(stats.max_hp) and int(hero.mp) == int(stats.max_mp), "full HP and MP")
	print("BOOST TEST: %s | %d checks, %d failures | HP %d DEF %d ATK %d" % ["PASS" if failures == 0 else "FAIL", checks, failures, int(stats.max_hp), int(stats.def), int(stats.atk)])
	get_tree().quit(0 if failures == 0 else 1)
