extends Node3D
## The 250★ class sets (ชุดเซต, SetGearData): one material, the set core
## ("set_core"), makes any piece of any class at the blacksmith with 20 purple,
## 20 pink and 20 chaos jewels at 50% (a failed try uses everything up). Six
## pieces a class (weapon, armour, helm, boots, ring, amulet), worn from 250★,
## and every stat of a +0 piece beats the best other piece at +10 (the divine
## piece and the mythic 200★ piece at their best rolls) by 10-25%. Two, four and
## six pieces worn give the set bonus; four or more show the class aura.
## Covers stats, the star requirement, costs, odds, bonus, save / load, icons,
## the hero's models and the forge's ผสมชุดเซต section.
##   godot --headless --path . res://tests/integration/set_gear_test.tscn
var checks := 0
var failures := 0
const SAMPLES := 120


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
	_material()
	_catalogue()
	_stats()
	_requirement()
	_craft()
	_odds()
	_bonus()
	_save()
	await _visuals()
	await _forge_menu()
	print("SET GEAR: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func _hero(cls: StringName, stars: int) -> void:
	Game.new_profile(cls, "Set QA", FaceKit.default_look())
	Game.profile.level = Game.MAX_LEVEL
	Game.paragon()["level"] = stars
	Game.profile["inv"] = []
	Game.profile["storage"] = []


func give(id: String, count: int) -> void:
	Game.add_item(ItemData.jewel(id, count))


func clear_jewels() -> void:
	for id in SetGearData.CRAFT_COST:
		var have := Game.jewel_count(id)
		if have > 0:
			Game._spend_jewels(id, have)


func stock(times := 1) -> void:
	for id in SetGearData.CRAFT_COST:
		give(id, int(SetGearData.CRAFT_COST[id]) * times)


func _jewels() -> Dictionary:
	var out := {}
	for id in SetGearData.CRAFT_COST:
		out[id] = Game.jewel_count(id)
	return out


func _set_pieces(list: Array) -> Array:
	return list.filter(func(item): return SetGearData.is_item(item))


func _material() -> void:
	var core := ItemData.jewel(SetGearData.CORE, 3)
	check(SetGearData.CORE == "set_core" and ItemData.JEWELS.has("set_core"), "the set core is a jewel (set_core)")
	check(ItemData.is_stackable(core) and ItemData.name_of(core) == "แก่นเทพหลอมเซต", "it stacks and has its Thai name (%s)" % ItemData.name_of(core))
	check(ItemLook.icon(core) != null and ResourceLoader.exists("res://assets/icons/ui/jewel_set_core.svg"), "it has its own jewel icon")
	check(Game._valid_item(core) and Game._valid_item(JSON.parse_string(JSON.stringify(core))), "the save check accepts set cores")
	check(SetGearData.CRAFT_COST == {"set_core": 1, "purple": 20, "pink": 20, "chaos": 20} and is_equal_approx(SetGearData.CRAFT_CHANCE, 0.5), "a piece costs 1 core + 20 purple + 20 pink + 20 chaos at 50%")
	var text := FileAccess.get_file_as_string("res://ui/game_menu.gd")
	check(text.contains("วัตถุดิบผสมชุดเซต 250 ดาว") and text.contains("SetGearData.CORE"), "the bag explains what the set core is for")


func _catalogue() -> void:
	var looks := {}
	for cls in ClassData.IDS:
		check(SetGearData.THEMES.has(String(cls)) and SetGearData.PALETTES.has(String(cls)) and SetGearData.ENGLISH.has(String(cls)), "%s has a set" % cls)
		for slot in SetGearData.SLOTS:
			var piece := SetGearData.item(String(cls), slot)
			check(not piece.is_empty() and SetGearData.is_item(piece) and SetGearData.valid(piece), "%s %s is a set piece" % [cls, slot])
			check(int(piece.level) == SetGearData.LEVEL and SetGearData.LEVEL == 350 and piece["class"] == String(cls) and int(piece.rarity) == 4, "%s %s: Lv.350 (250★), its class only, mythic" % [cls, slot])
			check(piece.base == (String(ClassData.get_class_data(cls).weapon_kind) if slot == "weapon" else slot), "%s %s base is %s" % [cls, slot, piece.base])
			check(String(piece.name).ends_with(String(SetGearData.THEMES[String(cls)])), "%s %s name %s" % [cls, slot, piece.name])
			check(Game._valid_item(piece), "%s %s passes the save check" % [cls, slot])
			check(not piece.has("star_tier") and String(piece.get("set", "")) == "", "%s %s stays out of the star collections and the old level sets" % [cls, slot])
			var look := ItemLook.look_of(piece)
			check(look.begins_with("set_") and not looks.has(look), "%s %s has its own look (%s)" % [cls, slot, look])
			looks[look] = true
			check(ItemLook.icon(piece) != null, "%s %s has an inventory icon (%s)" % [cls, slot, look])
			check(ItemData.detail_lines(piece).any(func(line): return String(line).contains(SetGearData.set_label(String(cls)))), "%s %s detail names its set" % [cls, slot])
			check(EnhanceFx.can_enhance(piece) == (slot not in ["ring", "amulet"]), "%s %s enhances by the normal forge rules" % [cls, slot])
	check(looks.size() == 60, "60 distinct looks (%d)" % looks.size())
	for id in SetGearData.catalogue().map(func(p): return SetGearData.look_of(p)):
		check(ItemLook.all_icon_ids().has(id), "the icon tool renders %s" % id)


## Per stat, casters' attack counted as magic attack (HeroStats adds both for them).
func _effective(stats: Dictionary, cls: String) -> Dictionary:
	return SetGearData._normalized(stats, cls)


func _stats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 250250
	for cls in ClassData.IDS:
		var c := String(cls)
		for slot in SetGearData.SLOTS:
			var mine := _effective(SetGearData.item(c, slot).stats, c)
			# The best other pieces, sampled the way the game makes them.
			var best := {}
			var sources: Array[Callable] = [func(): return StarProgression.item(cls, 200, slot, rng)]
			if slot in DivineGearData.SLOTS:
				sources.append(func(): return DivineGearData.item(cls, slot, rng))
			for make in sources:
				for i in SAMPLES:
					var stats := _effective((make.call() as Dictionary).stats, c)
					for key in stats:
						best[key] = maxf(float(best.get(key, 0.0)), float(stats[key]))
			var top := SetGearData.top_stats(c, slot)
			for key in top:
				best[key] = maxf(float(best.get(key, 0.0)), float(top[key]))
			for key in best:
				var at_ten := SetGearData.at_plus(key, float(best[key]))
				var ours := float(mine.get(key, 0.0))
				check(ours > at_ten, "%s %s %s: +0 set %.3f beats the best other piece at +10 %.3f" % [c, slot, key, ours, at_ten])
				var ratio := ours / maxf(at_ten, 0.0001)
				check(ratio >= 1.1 and ratio <= 1.25, "%s %s %s: margin %.3f is clear but not absurd" % [c, slot, key, ratio])
			# And at +10 against +10 the set piece is still the best one.
			var plus_ten := SetGearData.item(c, slot)
			plus_ten["plus"] = 10
			var other := DivineGearData.item(cls, slot, rng) if slot in DivineGearData.SLOTS else StarProgression.item(cls, 200, slot, rng)
			other["plus"] = 10
			var a := HeroStats.gear_bonus({"equip": {slot: plus_ten}, "class": c})
			var b := HeroStats.gear_bonus({"equip": {slot: other}, "class": c})
			# A caster's attack and magic attack both feed its attack (HeroStats.compute).
			if SetGearData.caster(c):
				a["matk"] = float(a.matk) + float(a.atk)
				b["matk"] = float(b.matk) + float(b.atk)
				a["atk"] = 0.0
				b["atk"] = 0.0
			for key in ["atk", "def", "hp", "mp", "crit", "matk"]:
				check(float(a[key]) >= float(b[key]), "%s %s %s: the whole stat line wins (%.2f vs %.2f)" % [c, slot, key, float(a[key]), float(b[key])])
	# Example for the report.
	var line := "warrior weapon: "
	for key in SetGearData.top_stats("warrior", "weapon"):
		line += "%s top %.3f -> +10 %.3f -> set %s; " % [key, SetGearData.top_stats("warrior", "weapon")[key], SetGearData.at_plus(key, SetGearData.top_stats("warrior", "weapon")[key]), str(SetGearData.stats_for("warrior", "weapon")[key])]
	print(line)


func _requirement() -> void:
	_hero(&"mage", SetGearData.STARS - 1)
	var staff := SetGearData.item("mage", "weapon")
	var problem := Game.equip_problem(staff)
	check(problem != "" and problem.contains("250"), "249★ cannot wear it (%s)" % problem)
	Game.paragon()["level"] = SetGearData.STARS
	check(Game.equip_problem(staff) == "", "250★ wears it (%s)" % Game.equip_problem(staff))
	Game.profile.level = 99
	check(Game.equip_problem(staff) != "", "below Lv.100 it stays off")
	Game.profile.level = Game.MAX_LEVEL
	check(Game.equip_problem(SetGearData.item("warrior", "armor")) == "สำหรับอาชีพอื่น", "another class's piece is refused")
	Game.add_item(staff)
	check(Game.equip_from_bag(Game.profile.inv.find(staff)) and Game.profile.equip.weapon == staff, "equipped from the bag at 250★")


func _craft() -> void:
	_hero(&"warrior", SetGearData.STARS)
	clear_jewels()
	check(Game.set_piece_problem("weapon").begins_with("วัตถุดิบไม่พอ"), "nothing to craft with (%s)" % Game.set_piece_problem("weapon"))
	check(Game.craft_set_piece("weapon", 0.0).begins_with("วัตถุดิบไม่พอ") and _set_pieces(Game.profile.inv).is_empty(), "no piece without materials")
	check(Game.craft_set_piece("wings", 0.0) != "ok" and Game.craft_set_piece("bogus", 0.0) != "ok", "only the six pieces")
	# One short of any cost refuses and keeps everything.
	for short in SetGearData.CRAFT_COST:
		clear_jewels()
		stock()
		Game._spend_jewels(short, 1)
		var before := _jewels()
		check(Game.craft_set_piece("armor", 0.0) != "ok" and _jewels() == before, "one %s short refuses and spends nothing" % short)
	clear_jewels()
	stock()
	give("set_core", 1)
	var result := Game.craft_set_piece("ring", 0.0)
	var made := _set_pieces(Game.profile.inv)
	check(result == "ok" and made.size() == 1 and made[0].slot == "ring" and SetGearData.item_class(made[0]) == "warrior", "a success makes the warrior's ring (%s)" % result)
	check(_jewels() == {"set_core": 1, "purple": 0, "pink": 0, "chaos": 0}, "it took exactly 1 core + 20 + 20 + 20 (%s)" % str(_jewels()))
	check(made.size() == 1 and made[0].stats == SetGearData.stats_for("warrior", "ring"), "the crafted ring has the set's stats")
	stock()
	Game._spend_jewels("set_core", 1)
	result = Game.craft_set_piece("helm", 0.99)
	check(result == "fail" and _jewels() == {"set_core": 0, "purple": 0, "pink": 0, "chaos": 0}, "a failure uses up every material (%s, %s)" % [result, str(_jewels())])
	check(_set_pieces(Game.profile.inv).size() == 1, "a failure makes nothing")
	# One core makes any piece: every slot from the same material.
	for slot in SetGearData.SLOTS:
		stock()
		check(Game.craft_set_piece(slot, 0.0) == "ok", "the core makes the %s" % slot)
	check(_set_pieces(Game.profile.inv).size() == 7, "seven pieces in the bag")
	check(Game.auto_sell_indices(31, 0).all(func(i): return not SetGearData.is_item(Game.profile.inv[i])), "auto-sell never sells a set piece")
	# A full bag sends the piece to storage (Game.give_or_store); spare jewels keep
	# their stacks so spending them frees no slot.
	stock(2)
	while Game.inventory_free() > 0:
		Game.profile.inv.append(ItemData.generate(10, &"warrior", Game.rng, 0, "boots"))
	check(Game.craft_set_piece("amulet", 0.0) == "ok" and _set_pieces(Game.profile.storage).size() == 1, "a full bag stores the piece")
	# Bag and storage both full: refused before anything is spent.
	while Game.storage().size() < Game.STORAGE_SIZE:
		Game.storage().append(ItemData.generate(10, &"warrior", Game.rng, 0, "boots"))
	stock()
	var before := _jewels()
	var full := Game.craft_set_piece("amulet", 0.0)
	check(full != "ok" and full != "fail" and _jewels() == before, "no room anywhere: refused, nothing spent (%s)" % full)
	# A Vagabond has no set.
	Game.new_profile(ClassData.START, "Set QA", FaceKit.default_look())
	stock()
	check(Game.craft_set_piece("weapon", 0.0) != "ok" and Game.jewel_count("set_core") == 1, "a Vagabond cannot craft a set piece")
	# Each class gets its own pieces from the same material.
	for cls in ClassData.IDS:
		_hero(cls, SetGearData.STARS)
		stock()
		check(Game.craft_set_piece("weapon", 0.0) == "ok" and _set_pieces(Game.profile.inv)[0].base == String(ClassData.get_class_data(cls).weapon_kind), "%s gets its own weapon kind" % cls)


func _odds() -> void:
	_hero(&"archer", SetGearData.STARS)
	clear_jewels()
	stock()
	check(Game.craft_set_piece("boots", 0.4999) == "ok", "a roll under 0.5 succeeds")
	stock()
	check(Game.craft_set_piece("boots", 0.5) == "fail", "a roll of 0.5 fails")
	Game.rng.seed = 4242
	var ok := 0
	var tries := 400
	for i in tries:
		stock()
		Game.profile.inv = Game.profile.inv.filter(func(item): return not SetGearData.is_item(item))
		if Game.craft_set_piece("boots") == "ok":
			ok += 1
	var share := float(ok) / float(tries)
	check(share > 0.43 and share < 0.57, "about half of the random tries succeed (%.3f)" % share)


func _bonus() -> void:
	_hero(&"warrior", SetGearData.STARS)
	check(SetGearData.bonus(0).is_empty() and SetGearData.bonus(1).is_empty(), "no bonus below two pieces")
	check(SetGearData.bonus(2) == {"hp": 0.06} and SetGearData.bonus(3) == {"hp": 0.06}, "two pieces: HP +6%")
	var four := SetGearData.bonus(4)
	check(is_equal_approx(four.hp, 0.06) and is_equal_approx(four.atk, 0.06) and is_equal_approx(four.def, 0.06) and not four.has("crit"), "four pieces add ATK and DEF +6%")
	var six := SetGearData.bonus(6)
	check(is_equal_approx(six.atk, 0.12) and is_equal_approx(six.crit, 0.04) and is_equal_approx(six.crit_dmg, 0.15), "six pieces: ATK +12% in all, crit +4%, crit damage +15%")
	# The same stats worn with and without the set's name: only the bonus differs.
	for count in [1, 2, 3, 4, 5, 6]:
		var worn := {}
		var plain := {}
		for i in count:
			var slot: String = SetGearData.SLOTS[i]
			worn[slot] = SetGearData.item("warrior", slot)
			var copy: Dictionary = worn[slot].duplicate(true)
			copy["set_gear"] = "archer"
			plain[slot] = copy
		Game.profile.equip = worn
		var a := HeroStats.compute(Game.profile)
		Game.profile.equip = plain
		var b := HeroStats.compute(Game.profile)
		var bonus := SetGearData.bonus(count)
		check(int(a.set_gear) == count and int(b.set_gear) == 0, "%d worn pieces are counted (%d)" % [count, int(a.set_gear)])
		check(absf(float(a.max_hp) / float(b.max_hp) - (1.0 + float(bonus.get("hp", 0.0)))) < 0.002, "%d pieces: HP x%.2f (%d vs %d)" % [count, 1.0 + float(bonus.get("hp", 0.0)), a.max_hp, b.max_hp])
		check(is_equal_approx(float(a.atk) / float(b.atk), 1.0 + float(bonus.get("atk", 0.0))), "%d pieces: ATK x%.2f" % [count, 1.0 + float(bonus.get("atk", 0.0))])
		check(is_equal_approx(float(a.def) / float(b.def), 1.0 + float(bonus.get("def", 0.0))), "%d pieces: DEF x%.2f" % [count, 1.0 + float(bonus.get("def", 0.0))])
		check(is_equal_approx(float(a.crit) - float(b.crit), float(bonus.get("crit", 0.0))) and is_equal_approx(float(a.crit_dmg) - float(b.crit_dmg), float(bonus.get("crit_dmg", 0.0))), "%d pieces: crit and crit damage" % count)
	check(HeroStats.set_gear_bonus(Game.profile).is_empty(), "another class's pieces give no bonus")


func _save() -> void:
	_hero(&"bard", SetGearData.STARS)
	clear_jewels()
	give("set_core", 4)
	for slot in SetGearData.SLOTS:
		Game.profile.equip[slot] = SetGearData.item("bard", slot)
	Game.profile.equip.weapon["plus"] = 7
	Game.profile.equip.weapon["gems"] = ["ruby_2"]
	Game.add_item(SetGearData.item("bard", "ring"))
	Game.storage().append(SetGearData.item("bard", "boots"))
	var saved: Dictionary = Game.profile.duplicate(true)
	saved.paragon["level"] = mini(int(saved.paragon.level), Game.PARAGON_MAX)
	check(Game._valid_profile(saved.duplicate(true)), "a profile with set pieces and cores is a valid save")
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	check(parsed is Dictionary and Game._valid_profile((parsed as Dictionary).duplicate(true)), "the JSON round trip is a valid save")
	if parsed is Dictionary:
		var back := Game._repair(parsed)
		check(int(back.equip.weapon.level) == SetGearData.LEVEL and back.equip.weapon.level is int, "the repair keeps Lv.350 (250★) on set pieces")
		check(int(back.equip.weapon.plus) == 7 and back.equip.weapon.gems == ["ruby_2"] and back.equip.weapon.stats == saved.equip.weapon.stats, "plus, gems and stats survive")
		check(SetGearData.worn_count(back.equip, "bard") == 6 and _set_pieces(back.inv).size() == 1 and _set_pieces(back.storage).size() == 1, "worn, bag and storage pieces survive")
		var cores: Array = back.inv.filter(func(item): return item.get("id", "") == "set_core")
		check(cores.size() == 1 and int(cores[0].count) == 4, "the set cores survive")
	# Damaged or forged pieces are refused.
	var piece := SetGearData.item("bard", "armor")
	for change in [{"level": 300}, {"class": "mage"}, {"set_gear": "nobody"}, {"slot": "wings"}, {"base": "sword"}, {"star_tier": 200}, {"set_gear": 5}]:
		var bad: Dictionary = piece.duplicate(true)
		bad.merge(change, true)
		check(not Game._valid_item(bad), "a set piece with %s is refused" % str(change))
	var other := saved.duplicate(true)
	other.inv.append({"kind": "jewel", "id": "set_core", "count": 0})
	check(not Game._valid_profile(other), "an empty set core stack is refused")
	# Through the real save slot (the star level within the save's current cap).
	Game.paragon()["level"] = mini(SetGearData.STARS, Game.PARAGON_MAX)
	Game.slot = 9
	check(Game.save(), "Game.save() writes the profile")
	check(Game.load_game(9), "Game.load_game() reads it back")
	check(SetGearData.worn_count(Game.profile.equip, "bard") == 6 and int(Game.profile.equip.armor.level) == SetGearData.LEVEL and Game.jewel_count("set_core") == 4, "the set and the cores load")
	Game.delete_save(9)


func _visuals() -> void:
	GameSettings.quality = 2
	for cls in ClassData.IDS:
		var c := String(cls)
		var equip := {}
		for slot in SetGearData.SLOTS:
			equip[slot] = SetGearData.item(c, slot)
		var hero := HeroVisual.new()
		add_child(hero)
		hero.setup(cls, "", true, equip, FaceKit.default_look())
		await get_tree().process_frame
		var aura := hero.find_child("SetAura", true, false)
		check(aura != null and String(aura.get_meta("set_aura", "")) == c, "%s: six pieces show the class aura" % c)
		var worn := 0
		for node in hero.find_children("*", "Node3D", true, false):
			if node.has_meta("set_gear"):
				worn += 1
		check(worn >= 7, "%s: the set's models are worn: chest, belt, pauldrons, helm, boots, ring, amulet and the weapon (%d)" % [c, worn])
		var held := false
		for node in hero.find_children("Held_*", "", true, false):
			if String(node.name).begins_with("Held_set_"):
				held = true
		check(held, "%s holds the set weapon" % c)
		var three := {}
		for slot in ["weapon", "armor", "helm"]:
			three[slot] = equip[slot]
		hero.set_equipment(three)
		await get_tree().process_frame
		check(hero.find_child("SetAura", true, false) == null, "%s: three pieces show no aura" % c)
		hero.queue_free()
	# The set's look differs from class to class and from the 200★ divine look.
	var palettes := {}
	for cls in SetGearData.PALETTES:
		palettes[SetGearData.PALETTES[cls].glow.to_html()] = cls
	check(palettes.size() == 10, "ten distinct set glows")
	check(StarGearData.kind_from_look("set_greatshield_defender") == "greatshield" and WeaponKit.build("set_lute_bard").has_meta("set_gear"), "set looks resolve to their weapon kinds")
	check(DarkRaven.look_for(SetGearData.item("darklord", "weapon")) == DarkRaven.Look.DIVINE, "the Dark Lord's raven takes its grandest look")
	await settle()


func _card(menu: GameMenu, slot: String) -> Node:
	return menu.find_child("SetPiece_" + slot, true, false)


func _forge_menu() -> void:
	_hero(&"priest", SetGearData.STARS)
	clear_jewels()
	var toasts: Array[String] = []
	Game.toast.connect(func(text: String, _kind: StringName): toasts.append(text))
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"inventory")
	await settle()
	check(menu.find_child("SetCraftToggle", true, false) == null, "the ผสมชุดเซต button is only at the blacksmith")
	menu.close_menu()
	menu.forge_mode = true
	menu.open_menu(&"inventory")
	await settle()
	var toggle := menu.find_child("SetCraftToggle", true, false) as Button
	check(toggle != null and toggle.text == "ผสมชุดเซต", "the forge has a ผสมชุดเซต button")
	if toggle == null:
		return
	toggle.pressed.emit()
	await settle()
	var section := menu.find_child("SetCraft", true, false)
	check(section != null and menu.find_child("BagScroll", true, false) == null, "the ผสมชุดเซต section replaces the bag grid")
	var head := section.get_child(0) as Label if section != null else null
	check(head != null and head.text == "ผสมชุดเซต", "the section is titled ผสมชุดเซต")
	var intro := menu.find_child("Intro", true, false) as Label
	check(intro != null and intro.text.contains("50%") and intro.text.contains("250") and intro.text.contains(SetGearData.set_label("priest")), "it names the set, 250★ and the 50%% chance (%s)" % (intro.text if intro else ""))
	var cost := menu.find_child("Cost", true, false) as RichTextLabel
	check(cost != null and cost.get_parsed_text().contains("แก่นเทพหลอมเซต 0/1") and cost.get_parsed_text().contains("เพชรม่วง 0/20") and cost.get_parsed_text().contains("เพชรชมพู 0/20") and cost.get_parsed_text().contains("เพชรชาออส 0/20"), "the cost shows owned/needed (%s)" % (cost.get_parsed_text() if cost else ""))
	for slot in SetGearData.SLOTS:
		var card := _card(menu, slot)
		check(card != null, "the %s of the priest's set is listed" % slot)
		if card == null:
			continue
		var title := card.find_child("Title", true, false) as Label
		check(title != null and title.text.contains(SetGearData.item_name("priest", slot)), "%s card names the piece" % slot)
		check((card.find_child("Icon", true, false) as TextureRect).texture != null, "%s card shows the icon" % slot)
		var craft := card.find_child("Craft", true, false) as Button
		check(craft != null and craft.disabled and craft.text.contains("50%"), "%s: ผสม (50%%) is off without materials" % slot)
	stock()
	menu._rebuild()
	await settle()
	cost = menu.find_child("Cost", true, false) as RichTextLabel
	check(cost != null and cost.get_parsed_text().contains("แก่นเทพหลอมเซต 1/1") and cost.get_parsed_text().contains("เพชรชาออส 20/20"), "the cost updates with materials")
	var button := _card(menu, "amulet").find_child("Craft", true, false) as Button
	check(button != null and not button.disabled, "ผสม is on with the materials")
	toasts.clear()
	button.pressed.emit()
	await settle()
	var made := _set_pieces(Game.profile.inv).size()
	check(_jewels() == {"set_core": 0, "purple": 0, "pink": 0, "chaos": 0}, "the press spent the materials")
	check(toasts.size() == 1 and ((made == 1 and toasts[0].begins_with("ผสมชุดเซตสำเร็จ!")) or (made == 0 and toasts[0].begins_with("ผสมชุดเซตพลาด..."))), "a Thai toast tells the result (%s)" % str(toasts))
	check(menu.find_child("SetCraft", true, false) != null, "the section stays open after crafting")
	var back := menu.find_child("SetCraftToggle", true, false) as Button
	check(back != null and back.text == "กลับไปกระเป๋า", "a button leads back to the bag")
	back.pressed.emit()
	await settle()
	check(menu.find_child("BagScroll", true, false) != null and menu.find_child("SetCraft", true, false) == null, "back to the bag grid")
	menu.close_menu()
	check(not menu.set_craft_open and not menu.forge_mode, "closing resets the forge view")
	menu.queue_free()
	await settle()
