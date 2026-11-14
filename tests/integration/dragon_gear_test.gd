extends Node3D
## The Dragon God's gear of เกาะลอยฟ้าเทพมังกร (DragonGearData): the weapon of every class
## (อาวุธเทพมังกร) and the 300★ wings of every class (ปีกเทพมังกร 300 ดาว; the Dark Lord's:
## the Dragon Emperor's cape). Items and their rolls, the ★299 / ★300 gate, the weapon
## against the 250★ set weapon at every +, the wings against the 100★ pair at +7 and the
## Legendary Guild Wings, the set bonus with the dragon weapon standing in for the set
## weapon, the class line, +15 and sockets, selling / loot / trade rules, the save on
## the client (JSON round trip, repair, a wire look, forged pieces), the icons, and the
## models: held weapon, breath, wings, clips, budget and a clean free at quality 0 and 2.
##   godot --headless --path . res://tests/integration/dragon_gear_test.tscn
var checks := 0
var failures := 0
const SAMPLES := 80


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func settle(frames := 3) -> void:
	for i in frames:
		await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	WorldEvents.festival_enabled = false
	_items()
	_weapon_stats()
	_wing_stats()
	_requirement()
	_set_bonus()
	_forge()
	_rules()
	_save()
	_icons()
	await _visuals()
	print("DRAGON GEAR: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func _hero(cls: StringName, stars: int) -> void:
	Game.new_profile(cls, "Dragon QA", FaceKit.default_look())
	Game.profile.level = Game.MAX_LEVEL
	Game.paragon()["level"] = stars
	Game.profile["inv"] = []
	Game.profile["storage"] = []
	Game.storage().clear()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _set_equip(cls: String) -> Dictionary:
	var equip := {}
	for slot in SetGearData.SLOTS:
		equip[slot] = SetGearData.item(cls, slot)
	return equip


## A piece's stats as the hero gets them at +plus (HeroStats.gear_bonus's own sums).
func _worn(item: Dictionary, plus: int) -> Dictionary:
	var out := {}
	for key in item.stats:
		out[key] = SetGearData.at_plus(key, float(item.stats[key]), plus)
	return out


func _total(stats: Dictionary) -> float:
	var sum := 0.0
	for key in stats:
		sum += float(stats[key]) * (10000.0 if key == "crit" else 1.0)
	return sum


func _items() -> void:
	var rng := _rng(1)
	var names := {}
	for cls in ClassData.IDS:
		var c := String(cls)
		var weapon := DragonGearData.weapon(cls, rng)
		var wings := DragonGearData.wings(cls, rng)
		check(DragonGearData.is_item(weapon) and DragonGearData.is_weapon(weapon) and not DragonGearData.is_wings(weapon), "%s: the weapon carries the dragon mark" % c)
		check(DragonGearData.is_item(wings) and DragonGearData.is_wings(wings) and not DragonGearData.is_weapon(wings), "%s: the wings carry the dragon mark" % c)
		check(String(weapon.base) == String(ClassData.get_class_data(cls).weapon_kind) and String(weapon["class"]) == c, "%s: the weapon is the class's own kind (%s)" % [c, weapon.base])
		check(String(wings.base) == "wings" and String(wings.wing) == c and String(wings["class"]) == c, "%s: the wings are the class's pair" % c)
		for item in [weapon, wings]:
			check(int(item.level) == 400 and int(item.rarity) == 4 and int(item.plus) == 0 and int(item.sockets) == 3 and (item.gems as Array).is_empty(), "%s %s: Lv.400 (★300), mythic grade, +0, three sockets" % [c, item.slot])
			check(not item.has("set_gear") and not item.has("star_tier") and not item.has("collection") and String(item.set) == "", "%s %s: no other tier's keys" % [c, item.slot])
			check(DragonGearData.valid(item) and Game._valid_item(item), "%s %s: a valid save item" % [c, item.slot])
			check(ItemData.color_of(item) == DragonGearData.COLOR, "%s %s: the เทพมังกร colour" % [c, item.slot])
			check(ItemData.gear_class(item) == c and ItemData.tile_text(item) == "ดาว300", "%s %s: class locked, tile reads ดาว300" % [c, item.slot])
			check(String(item.name).contains("เทพมังกร") and not names.has(item.name), "%s %s: its own Thai name (%s)" % [c, item.slot, item.name])
			names[item.name] = true
			var lines := ItemData.detail_lines(item)
			check(lines.any(func(line): return String(line).contains("เกาะลอยฟ้าเทพมังกร")) and lines.any(func(line): return String(line).contains("ดาว 300")), "%s %s: the tooltip names the isle and ★300" % [c, item.slot])
		check(ItemData.detail_lines(weapon).any(func(line): return String(line).begins_with("พลังเทพมังกร")) and ItemData.detail_lines(weapon).any(func(line): return String(line).contains("โบนัสเซต")), "%s: the weapon's tooltip shows its line and the set bonus" % c)
	check(names.size() == 20, "twenty distinct names")
	check(String(DragonGearData.wing_name("darklord")).begins_with("ผ้าคลุม"), "the Dark Lord's is a cape")
	# The contract's stub signatures still answer for an unknown class.
	check(DragonGearData.weapon(&"vagabond", rng).get("dragon") == 1 and DragonGearData.wings(&"", rng).get("dragon") == 1, "an unknown class still gets a piece")
	check(not DragonGearData.is_item({}) and not DragonGearData.is_item(SetGearData.item("mage", "weapon")) and not DragonGearData.is_wings(StarWingData.item("mage", rng)), "other gear is not dragon gear")


func _weapon_stats() -> void:
	var rng := _rng(2)
	for cls in ClassData.IDS:
		var c := String(cls)
		var base := SetGearData.item(c, "weapon")
		var low_ok := true
		var high_ok := true
		var plus_ok := true
		var spread := {}
		for i in SAMPLES:
			var weapon := DragonGearData.weapon(cls, rng)
			low_ok = low_ok and weapon.stats.size() == base.stats.size()
			for key in base.stats:
				var ratio := float(weapon.stats.get(key, 0.0)) / float(base.stats[key])
				low_ok = low_ok and ratio >= 1.15 - 0.0001
				# (Whole numbers round up: a small stat may sit a point over.)
				high_ok = high_ok and ratio <= 1.20 + (0.02 if key == "crit" else 1.5 / float(base.stats[key]))
				for plus in [0, 7, 10, 15]:
					plus_ok = plus_ok and float(_worn(weapon, plus)[key]) > float(_worn(base, plus)[key])
			spread[int(weapon.stats.get("atk", weapon.stats.get("matk", 0)))] = true
		check(low_ok, "%s: every stat of the weapon is at least +15%% over the 250★ set weapon's" % c)
		check(high_ok, "%s: and at most +20%% (a narrow roll)" % c)
		check(plus_ok, "%s: it beats the set weapon in every stat at every equal +" % c)
		check(spread.size() > 5, "%s: the stats are rolled (%d different attacks)" % [c, spread.size()])
		# A +0 dragon weapon does not make a forged +10 set weapon pointless.
		var fresh := DragonGearData.weapon(cls, rng)
		var main := "matk" if base.stats.has("matk") else "atk"
		check(float(_worn(base, 10)[main]) > float(fresh.stats[main]), "%s: a set weapon at +10 still out-hits a fresh +0 dragon weapon" % c)


func _wing_stats() -> void:
	var rng := _rng(3)
	var legend := {"stats": LegendWings.STATS}
	print("  wings, total of stats (crit x10000): class | 100★ best +7 | 300★ +0 (low..high) | legend +0 || 300★ +15 | legend +15")
	for cls in ClassData.IDS:
		var c := String(cls)
		var top := {"stats": DragonGearData.star_wing_top(c)}
		var over_star := true
		var under_legend := true
		var same_keys := true
		var low := INF
		var high := 0.0
		for i in SAMPLES:
			var wings := DragonGearData.wings(cls, rng)
			var star := StarWingData.item(c, rng, 4 if i % 2 == 0 else 3)
			same_keys = same_keys and wings.stats.size() == top.stats.size()
			for key in top.stats:
				same_keys = same_keys and wings.stats.has(key)
				# +0 against the best and against a rolled 100★ pair at +7, as the game sums them.
				over_star = over_star and float(wings.stats.get(key, 0)) > float(_worn(top, 7)[key]) and float(wings.stats.get(key, 0)) > float(_worn(star, 7)[key])
				over_star = over_star and float(wings.stats.get(key, 0)) <= float(_worn(top, 7)[key]) * 1.09
				for plus in [0, 7, 15]:
					under_legend = under_legend and float(_worn(wings, plus)[key]) < float(_worn(legend, plus)[key])
			low = minf(low, _total(wings.stats))
			high = maxf(high, _total(wings.stats))
		check(same_keys, "%s: the wings carry the class's 100★ stats" % c)
		check(over_star, "%s: a +0 pair beats the 100★ pair at +7 in every stat, by 4-8%%" % c)
		check(under_legend, "%s: the Legendary Guild Wings stay ahead in every stat at every equal +" % c)
		var legend_keys := {"stats": {}}
		for key in top.stats:
			legend_keys.stats[key] = LegendWings.STATS[key]
		var star7 := _total(_worn(top, 7))
		var legend0 := _total(legend_keys.stats)
		check(star7 < low and high < legend0, "%s: totals rank 100★ +7 < 300★ +0 < legend +0" % c)
		print("  %-9s | %6d | %6d..%6d | %6d || %6d | %6d" % [c, int(star7), int(low), int(high), int(legend0), int(_wing_top_total(c, 15)), int(_total(_worn(legend_keys, 15)))])
	# The guild wings' own effect stays theirs: no aura on the dragon wings.
	_hero(&"warrior", 300)
	Game.profile.equip["wings"] = DragonGearData.wings(&"warrior", rng)
	check(not bool(HeroStats.compute(Game.profile).legend_aura), "the dragon wings carry no party aura (the guild wings' own effect)")


## The best 300★ pair's total at +plus.
func _wing_top_total(cls: String, plus: int) -> float:
	var ranges := DragonGearData.wing_ranges(cls)
	var stats := {}
	for key in ranges:
		stats[key] = ranges[key][1]
	return _total(_worn({"stats": stats}, plus))


func _requirement() -> void:
	var rng := _rng(4)
	for cls in [&"warrior", &"mage", &"darklord"]:
		_hero(cls, 299)
		var weapon := DragonGearData.weapon(cls, rng)
		var wings := DragonGearData.wings(cls, rng)
		check(Game.equip_problem(weapon).contains("ดาว 300") and Game.equip_problem(wings).contains("ดาว 300"), "%s at ★299: both ask for ดาว 300" % cls)
		Game.add_item(weapon)
		check(not Game.equip_from_bag(Game.profile.inv.find(weapon)) and not is_same(Game.profile.equip.get("weapon"), weapon), "%s at ★299 cannot wear the weapon" % cls)
		Game.paragon()["level"] = 300
		check(Game.equip_problem(weapon) == "" and Game.equip_problem(wings) == "", "%s at ★300: both can be worn" % cls)
		check(Game.equip_from_bag(Game.profile.inv.find(weapon)) and is_same(Game.profile.equip.weapon, weapon), "%s at ★300 wears the weapon" % cls)
		Game.add_item(wings)
		check(Game.equip_from_bag(Game.profile.inv.find(wings)) and is_same(Game.profile.equip.wings, wings), "%s at ★300 wears the wings" % cls)
		check(Game.unequip("wings") and not Game.profile.equip.has("wings"), "%s: the wings come off freely (no lock)" % cls)
	_hero(&"archer", 300)
	check(Game.equip_problem(DragonGearData.weapon(&"mage", rng)) == "สำหรับอาชีพอื่น" and Game.equip_problem(DragonGearData.wings(&"mage", rng)) == "สำหรับอาชีพอื่น", "another class's pieces are not for wearing")
	Game.profile.level = 99
	check(Game.equip_problem(DragonGearData.weapon(&"archer", rng)) != "", "below Lv.100 nothing is worn")


func _set_bonus() -> void:
	var rng := _rng(5)
	for cls in ClassData.IDS:
		var c := String(cls)
		_hero(cls, 300)
		Game.profile.equip = _set_equip(c)
		var with_set := HeroStats.compute(Game.profile)
		Game.profile.equip["weapon"] = DragonGearData.weapon(cls, rng)
		var with_dragon := HeroStats.compute(Game.profile)
		check(SetGearData.worn_count(Game.profile.equip, c) == 6 and int(with_dragon.set_gear) == 6 and int(with_set.set_gear) == 6, "%s: the dragon weapon counts as the set's weapon (6/6)" % c)
		check(HeroStats.set_gear_bonus(Game.profile) == SetGearData.bonus(6), "%s: the whole six-piece bonus stays" % c)
		check(float(with_dragon.atk) > float(with_set.atk) * 1.02 and int(with_dragon.max_hp) > int(with_set.max_hp) and float(with_dragon.def) > float(with_set.def), "%s: attack, HP and defence all rise over the full set (atk %d -> %d)" % [c, int(with_set.atk), int(with_dragon.atk)])
		check(bool(with_dragon.get("dragon_line", false)) and not bool(with_set.get("dragon_line", false)), "%s: the Dragon God's line is on" % c)
		# The line itself: the same weapon without the mark's line (signature off) is weaker in its stat.
		var line: Dictionary = DragonGearData.SIGNATURE[c]
		check(line.size() == 1 and DragonGearData.signature_text(c).begins_with("พลังเทพมังกร: "), "%s: one line (%s)" % [c, DragonGearData.signature_text(c)])
		var key := String(line.keys()[0])
		var gear := HeroStats.gear_bonus(Game.profile)
		check(int(gear.set_gear) == 6, "%s: gear_bonus counts six" % c)
		match key:
			"crit_dmg":
				check(is_equal_approx(float(with_dragon.crit_dmg), float(with_set.crit_dmg) + float(line[key])), "%s: +%d%% crit damage" % [c, int(float(line[key]) * 100.0)])
			"cdr", "lifesteal":
				check(is_equal_approx(float(with_dragon[key]), float(with_set[key]) + float(line[key])), "%s: +%s %s" % [c, str(line[key]), key])
			"crit":
				check(float(with_dragon.crit) > float(with_set.crit) + float(line[key]) - 0.001, "%s: +5%% crit on top of the weapon's own" % c)
			_:
				pass
		# Five set pieces and a dragon weapon of another class: five, and no line.
		var other: StringName = &"mage" if cls != &"mage" else &"warrior"
		Game.profile.equip["weapon"] = DragonGearData.weapon(other, rng)
		check(SetGearData.worn_count(Game.profile.equip, c) == 5 and DragonGearData.signature(Game.profile).is_empty(), "%s: another class's dragon weapon counts for nothing" % c)
		# The dragon weapon alone is one piece of the set, two with one more: the 2-piece bonus.
		Game.profile.equip = {"weapon": DragonGearData.weapon(cls, rng), "ring": SetGearData.item(c, "ring")}
		check(SetGearData.worn_count(Game.profile.equip, c) == 2 and SetGearData.bonus(2).has("hp"), "%s: weapon + ring is the 2-piece bonus" % c)
	# The lines that scale a stat: with and without the weapon's mark.
	for spec in [[&"lancer", "atk"], [&"defender", "def"], [&"priest", "max_hp"]]:
		var cls: StringName = spec[0]
		_hero(cls, 300)
		Game.profile.equip = _set_equip(String(cls))
		var weapon := DragonGearData.weapon(cls, rng)
		Game.profile.equip["weapon"] = weapon
		var on := HeroStats.compute(Game.profile)
		var raw := HeroStats.compute(Game.profile)
		var share := float(DragonGearData.SIGNATURE[String(cls)].values()[0])
		# Recompute what it would be without the line from the pieces: the ratio is the line.
		var plain := weapon.duplicate(true)
		plain.erase("dragon")
		plain["set_gear"] = String(cls)
		Game.profile.equip["weapon"] = plain
		raw = HeroStats.compute(Game.profile)
		check(absf(float(on[spec[1]]) / float(raw[spec[1]]) - (1.0 + share)) < 0.002, "%s: the line is +%d%% %s" % [cls, int(share * 100.0), spec[1]])


func _forge() -> void:
	var rng := _rng(6)
	_hero(&"assassin", 300)
	Game.rng.seed = 77
	for item in [DragonGearData.weapon(&"assassin", rng), DragonGearData.wings(&"assassin", rng)]:
		var slot := String(item.slot)
		Game.profile.equip[slot] = item
		check(EnhanceFx.can_enhance(item), "the %s can be enhanced" % slot)
		var before: Dictionary = item.stats.duplicate()
		var tries := 0
		while int(item.plus) < ItemData.MAX_PLUS and tries < 600:
			for id in ["purple", "pink", "chaos"]:
				if Game.jewel_count(id) < 10:
					Game.add_item(ItemData.jewel(id, 50))
			var result := Game.enhance_item(item)
			if result != "ok" and result != "fail":
				break
			tries += 1
		check(int(item.plus) == ItemData.MAX_PLUS, "the %s goes to +15 (%d tries)" % [slot, tries])
		check(item.stats == before and DragonGearData.valid(item) and Game._valid_item(item), "the %s at +15 keeps its rolled stats and is a valid save" % slot)
		check(Game.enhance_item(item) == "บวกสูงสุดแล้ว", "+15 is the top")
		Game.add_item(ItemData.jewel("drill", 1))
		check(Game.drill_socket(item) == "ok" and int(item.sockets) == 4, "the %s at +15 opens a fourth socket" % slot)
		for i in 4:
			Game.add_item(ItemData.gem("ruby", 2))
			check(Game.socket_gem(item, Game.profile.inv.size() - 1), "gem %d goes into the %s" % [i + 1, slot])
		check((item.gems as Array).size() == 4 and ItemData.resonates(item) and Game._valid_item(item), "four rubies resonate in the %s; still a valid save" % slot)
	var worn := HeroStats.compute(Game.profile)
	check(float(worn.atk) > 0.0 and int(worn.set_gear) == 1, "the stats compute with both worn at +15")
	# The wings are not raw material for the 100★ craft, and the tower re-roll keeps them dragon wings.
	var pair := DragonGearData.wings(&"assassin", rng)
	check(not StarWingData.can_craft(pair) and Game.craft_star_wings(pair) == "ใช้ปีกเลเวล 100 เท่านั้น", "the 100★ wing craft refuses the 300★ wings")
	check(not StarWingData.is_wing(pair) and not StarGearData.is_star(pair) and not LegendWings.is_item(pair), "they are no 100★ or legend pair")
	Game.tower()["shards"] = TowerData.COST_REROLL * 3
	pair["plus"] = 5
	var old_uid := String(pair.uid)
	for i in 3:
		check(Game.tower_reroll_wings(pair) == "ok" and DragonGearData.valid(pair) and int(pair.level) == 400 and int(pair.plus) == 5 and String(pair.uid) == old_uid, "a tower re-roll keeps them 300★ dragon wings in range")
	check(String(pair.name) == DragonGearData.wing_name("assassin"), "and their name")


func _rules() -> void:
	var rng := _rng(7)
	_hero(&"warrior", 300)
	var own := DragonGearData.weapon(&"warrior", rng)
	var other := DragonGearData.weapon(&"bard", rng)
	var wings := DragonGearData.wings(&"bard", rng)
	var junk := ItemData.generate(90, &"warrior", rng, 4, "weapon")
	for item in [own, other, wings, junk]:
		Game.add_item(item)
	var picked := Game.auto_sell_indices(31, 0)
	check(picked.size() == 1 and is_same(Game.profile.inv[picked[0]], junk), "auto-sell takes the mythic junk and never the dragon gear")
	Game.set_sells_other_class(true)
	check(Game.auto_sell_indices(31, 0).size() == 1, "nor with ขายของอาชีพอื่นอัตโนมัติ on")
	check(Game.pickup_sale(other) == 0 and Game.pickup_sale(wings) == 0, "another class's dragon gear is never sold on pickup")
	Game.set_sells_other_class(false)
	Game.set_loot_mask(0)
	check(Game.keeps_loot(own) and Game.keeps_loot(other) and Game.keeps_loot(wings) and not Game.keeps_loot(junk), "the pickup filter always keeps the dragon gear")
	Game.set_loot_mask(31)
	# It trades, sells and goes on a stall like the 250★ set pieces.
	var set_piece := SetGearData.item("warrior", "weapon")
	for item in [own, wings]:
		check(OnlineTrade.tradable(item) == OnlineTrade.tradable(set_piece) and OnlineTrade.tradable(item), "the %s trades like a set piece" % item.slot)
		check(ItemData.sell_price(item) > ItemData.sell_price(set_piece) and PlayerStall.fair_price(item) > 0, "the %s has a price above a set piece's" % item.slot)
	check(Game.storage_lock(own) == Game.storage_lock(set_piece), "the storage treats it like a set piece")
	var at: int = Game.profile.inv.find(own)
	check(Game.deposit_item(at) and Game.storage().has(own), "it goes into the storage")
	check(Game.withdraw_item(Game.storage().find(own)) and Game.profile.inv.has(own), "and comes back out")

	check(DarkRaven.look_for(DragonGearData.weapon(&"darklord", rng)) == DarkRaven.Look.ABYSS, "the Dark Lord's raven keeps its abyss look under the dragon sceptre")


func _save() -> void:
	var rng := _rng(8)
	_hero(&"bard", 300)
	Game.profile.equip = _set_equip("bard")
	var weapon := DragonGearData.weapon(&"bard", rng)
	weapon["plus"] = 9
	weapon["gems"] = ["ruby_2", "topaz_1"]
	Game.profile.equip["weapon"] = weapon
	Game.profile.equip["wings"] = DragonGearData.wings(&"bard", rng)
	Game.add_item(DragonGearData.weapon(&"mage", rng))
	Game.add_item(DragonGearData.wings(&"darklord", rng))
	Game.profile.storage.append(DragonGearData.wings(&"priest", rng))
	var saved: Dictionary = Game.profile.duplicate(true)
	check(Game._valid_profile(saved.duplicate(true)), "a profile wearing and carrying dragon gear is a valid save")
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	check(parsed is Dictionary and Game._valid_profile((parsed as Dictionary).duplicate(true)), "the JSON round trip is a valid save")
	if parsed is Dictionary:
		var back := Game._repair(parsed)
		check(int(back.equip.weapon.level) == 400 and back.equip.weapon.level is int and back.equip.weapon.dragon is int and int(back.equip.weapon.dragon) == 1, "the repair keeps Lv.400 and the mark as ints")
		check(int(back.equip.wings.level) == 400 and DragonGearData.is_wings(back.equip.wings), "and on the wings")
		check(int(back.equip.weapon.plus) == 9 and back.equip.weapon.gems == ["ruby_2", "topaz_1"] and back.equip.weapon.stats == saved.equip.weapon.stats, "plus, gems and stats survive")
		check(SetGearData.worn_count(back.equip, "bard") == 6, "the set still counts six after the round trip")
		check(back.inv.filter(DragonGearData.is_item).size() == 2 and back.storage.filter(DragonGearData.is_item).size() == 1, "bag and storage pieces survive")
	# A look on the wire carries no stats (PlayerLook.WIRE_DROP) and still dresses.
	var wire := PlayerLook.wire_equip(saved.equip)
	check(not wire.weapon.has("stats") and Game._valid_item(wire.weapon) and Game._valid_item(wire.wings), "a wire look's dragon pieces pass the item check")
	var clean := PlayerLook.clean({"class": "bard", "equip": JSON.parse_string(JSON.stringify(wire)), "level": 100, "stars": 300})
	check(clean is Dictionary and DragonGearData.is_weapon((clean as Dictionary).get("equip", {}).get("weapon")) and DragonGearData.is_wings((clean as Dictionary).get("equip", {}).get("wings")), "PlayerLook.clean keeps them")
	# Damaged or forged pieces are refused.
	var piece := DragonGearData.weapon(&"bard", rng)
	var main := "matk" if piece.stats.has("matk") else "atk"
	var strong: Dictionary = piece.stats.duplicate()
	strong[main] = int(strong[main]) * 2
	var weak: Dictionary = piece.stats.duplicate()
	weak[main] = 1
	var extra: Dictionary = piece.stats.duplicate()
	extra["lifesteal"] = 0.5
	for change in [{"level": 300}, {"level": 401}, {"rarity": 3}, {"class": "mage"}, {"class": ""}, {"base": "sword"}, {"slot": "armor"}, {"star_tier": 200},
			{"set_gear": "bard"}, {"collection": "lotus_200"}, {"legend_week": 3000}, {"dragon": 2}, {"dragon": "1"}, {"stats": strong}, {"stats": weak}, {"stats": extra}, {"plus": 16}]:
		var bad: Dictionary = piece.duplicate(true)
		bad.merge(change, true)
		check(not Game._valid_item(bad), "a dragon weapon with %s is refused" % str(change).left(60))
	var pair := DragonGearData.wings(&"bard", rng)
	for change in [{"wing": "mage"}, {"base": "lute"}, {"level": 200}, {"star_tier": 100}, {"stats": {"matk": 99999}}]:
		var bad: Dictionary = pair.duplicate(true)
		bad.merge(change, true)
		check(not Game._valid_item(bad), "dragon wings with %s are refused" % str(change))
	# Through the real save slot.
	Game.slot = 9
	check(Game.save(), "Game.save() writes the profile")
	check(Game.load_game(9), "Game.load_game() reads it back")
	check(DragonGearData.is_weapon(Game.profile.equip.weapon) and int(Game.profile.equip.weapon.level) == 400 and int(Game.profile.equip.weapon.plus) == 9 and DragonGearData.is_wings(Game.profile.equip.wings), "the worn dragon gear loads")
	check(Game.equip_problem(Game.profile.equip.weapon) == "" and int(HeroStats.compute(Game.profile).set_gear) == 6, "and is still wearable with the set bonus")
	Game.delete_save(9)


func _icons() -> void:
	var ids := DragonGearData.icon_ids()
	check(ids.size() == 20, "twenty icon ids")
	var all := ItemLook.all_icon_ids()
	var rng := _rng(9)
	for id in ids:
		check(all.has(id) and ItemLook.icon_for_id(id) != null, "icon %s exists and is listed" % id)
	for cls in ClassData.IDS:
		for item in [DragonGearData.weapon(cls, rng), DragonGearData.wings(cls, rng)]:
			var tex := ItemLook.icon(item)
			check(tex != null and tex.get_width() == 128 and ItemLook.look_of(item).begins_with("dragon_"), "%s %s: its own 128px icon (%s)" % [cls, item.slot, ItemLook.look_of(item)])
	var one := ItemLook.build_icon_node("dragon_wings_mage")
	var two := ItemLook.build_icon_node("dragon_staff_mage")
	check(one != null and two != null, "icon nodes build")
	one.free()
	two.free()


func _mesh_cost(root: Node) -> Dictionary:
	var out := {"surfaces": 0, "triangles": 0, "lights": 0, "gpu": 0, "cpu": 0}
	for node in root.find_children("*", "", true, false):
		if node is Light3D:
			out.lights += 1
		elif node is GPUParticles3D:
			out.gpu += 1
		elif node is CPUParticles3D:
			out.cpu += 1
		elif node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh:
			out.surfaces += (node as MeshInstance3D).mesh.get_surface_count()
			out.triangles += LegendWingMesh.triangles((node as MeshInstance3D).mesh)
	return out


func _visuals() -> void:
	var rng := _rng(10)
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for quality in [2, 0]:
		GameSettings.quality = quality
		for cls in ClassData.IDS:
			var c := String(cls)
			var kind := DragonGearData.weapon_kind(c)
			var look := "dragon_%s_%s" % [kind, c]
			# The weapon model alone.
			var model := WeaponKit.build(look)
			add_child(model)
			var cost := _mesh_cost(model)
			check(model.has_meta("dragon_gear") and String(model.get_meta("weapon_kind")) == kind and StarGearData.kind_from_look(look) == kind, "q%d %s: the look builds its weapon kind" % [quality, c])
			check(int(cost.surfaces) == 2 and int(cost.triangles) > 600 and int(cost.triangles) < 4500 and int(cost.lights) == 0 and int(cost.gpu) == 0 and int(cost.cpu) == 0, "q%d %s: two surfaces, phone-sized, no lights or particles (%d tris)" % [quality, c, int(cost.triangles)])
			var art := model.get_child(0) as MeshInstance3D
			var glow := art.get_surface_override_material(1) as ShaderMaterial
			check(glow != null and glow.shader == DragonGearArt.GLOW_SHADER and is_equal_approx(float(glow.get_shader_parameter("motion")), 0.0 if quality == 0 else 1.0), "q%d %s: the inner glow runs on its shader (%s)" % [quality, c, "still" if quality == 0 else "moving"])
			var breath := DragonGearArt.breath(model)
			check((breath != null) == (quality > 0), "q%d %s: the breath %s" % [quality, c, "shows" if quality > 0 else "is left out"])
			check(DragonGearArt.breath(model, true) == null, "q%d %s: never in a crowd's light dress" % [quality, c])
			model.queue_free()
			# The hero: the set, the dragon weapon and the dragon wings.
			var equip := _set_equip(c)
			equip["weapon"] = DragonGearData.weapon(cls, rng)
			equip["weapon"]["plus"] = 15
			equip["wings"] = DragonGearData.wings(cls, rng)
			var hero := HeroVisual.new()
			add_child(hero)
			hero.setup(cls, "", true, equip, FaceKit.default_look())
			await get_tree().process_frame
			var held := hero.find_children("Held_dragon_*", "", true, false)
			# (The Assassin's twin dagger shares the main one's node name: counted once here.)
			var want_held := 2 if c in ["warrior", "priest", "summoner"] else 1
			check(held.size() == want_held, "q%d %s holds the dragon weapon%s (%d)" % [quality, c, " and its off-hand" if want_held == 2 else "", held.size()])
			var aura := hero.find_child("SetAura", true, false)
			check(quality == 0 or (aura != null and String(aura.get_meta("set_aura", "")) == c), "q%d %s: the set aura stays with the dragon weapon in place" % [quality, c])
			var breaths := hero.find_children("DragonBreath", "", true, false).size()
			check(breaths == (0 if quality == 0 else (2 if c == "assassin" else 1)), "q%d %s: breath shells in the hand: %d" % [quality, c, breaths])
			var wing := hero.find_child("Wings_dragon_" + c, true, false) as DragonWingArt
			check(wing != null, "q%d %s wears the dragon wings" % [quality, c])
			if wing != null:
				var player := wing.get_node_or_null("AnimationPlayer") as AnimationPlayer
				check(player != null and hero._wing_player() == player, "q%d %s: HeroVisual finds the wings' player" % [quality, c])
				var clips := true
				for clip in ["Idle", "Flap", "Glide", "Fold", "Unfold"]:
					clips = clips and player != null and player.has_animation(clip)
				check(clips, "q%d %s: Idle, Flap, Glide, Fold and Unfold" % [quality, c])
				var wing_cost := DragonWingArt.cost(wing)
				var no_fx := _mesh_cost(wing)
				# (The Dark Lord's is CapeArt's three cloth layers plus the small pair.)
				var cape := c == "darklord"
				check(int(wing_cost.surfaces) <= (12 if cape else 8) and int(wing_cost.triangles) > 1200 and int(wing_cost.triangles) < (9000 if cape else 7000), "q%d %s: wings phone-sized: %d surfaces, %d triangles" % [quality, c, int(wing_cost.surfaces), int(wing_cost.triangles)])
				check(int(no_fx.lights) == 0 and int(no_fx.gpu) == 0 and int(no_fx.cpu) == 0, "q%d %s: no lights, no particles in the wings" % [quality, c])
				var right := wing.find_child("WingR", true, false) as MeshInstance3D
				var mat := right.get_surface_override_material(0) as ShaderMaterial if right != null else null
				check(mat != null and mat.shader == DragonWingArt.SHADER and is_equal_approx(float(mat.get_shader_parameter("motion")), 0.0 if quality == 0 else 1.0), "q%d %s: the wing shader %s" % [quality, c, "holds still" if quality == 0 else "sways"])
				check((wing.find_child("DragonCape", true, false) != null) == (c == "darklord"), "q%d %s: %s" % [quality, c, "the Dragon Emperor's cape" if c == "darklord" else "wings, no cape"])
				# The poses HeroVisual asks for.
				var open: Transform3D = right.transform
				hero.set_wing_mode(HeroVisual.WING_FOLD, true)
				check(is_equal_approx(wing.fold, 1.0) and not right.transform.is_equal_approx(open), "q%d %s: folding moves the wings" % [quality, c])
				hero.set_wing_mode(HeroVisual.WING_FLY, true)
				await get_tree().process_frame
				check(hero.flying() and player.current_animation in ["Flap", "Glide", "Unfold"], "q%d %s: flying plays the flap" % [quality, c])
				hero.set_wing_mode(HeroVisual.WING_STAND, true)
			# Nothing additive for the select stage to tone down in the wings; the call is safe.
			TitleStage.soften_glow(hero)
			# A re-dress to the plain set frees the dragon pieces.
			hero.set_equipment(_set_equip(c))
			await get_tree().process_frame
			check(hero.find_children("Held_dragon_*", "", true, false).is_empty() and hero.find_child("Wings_dragon_" + c, true, false) == null and hero.find_children("DragonBreath", "", true, false).is_empty(), "q%d %s: a re-dress frees weapon, breath and wings" % [quality, c])
			hero.queue_free()
			await get_tree().process_frame
		# A crowd's light dress: still wings, no breath.
		var crowd := HeroVisual.new()
		crowd.decor_light = true
		add_child(crowd)
		var crowd_equip := _set_equip("mage")
		crowd_equip["weapon"] = DragonGearData.weapon(&"mage", rng)
		crowd_equip["wings"] = DragonGearData.wings(&"mage", rng)
		crowd.setup(&"mage", "", true, crowd_equip, FaceKit.default_look())
		await get_tree().process_frame
		var crowd_wing := crowd.find_child("WingR", true, false) as MeshInstance3D
		check(crowd.find_children("DragonBreath", "", true, false).is_empty() and crowd_wing != null and is_equal_approx(float((crowd_wing.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("motion")), 0.0), "q%d: a crowd's light dress has no breath and still wings" % quality)
		crowd.queue_free()
		await get_tree().process_frame
	GameSettings.quality = 2
	await settle(4)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	check(orphans_after <= orphans_before, "nothing is left orphaned after freeing (%d -> %d)" % [orphans_before, orphans_after])
	# Ten classes, ten different wing colourings; one shared mesh.
	var seen := {}
	for cls in StarGearData.CLASSES:
		seen[(DragonWingArt.colors(cls).membrane as Color).to_html()] = true
	check(seen.size() == 10 and DragonWingArt.wing_mesh() == DragonWingArt.wing_mesh(), "ten membrane colours over one shared wing mesh")
