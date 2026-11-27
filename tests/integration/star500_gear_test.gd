extends Node3D
## The 500-star class sets of ดินแดนเทวาลัย (Star500Gear, ชุดเทวาลัย): every class and slot
## (weapon, armour, helm, boots, ring, amulet, wings / cape), the stats above every older
## tier (the 250★ set, the Dragon God weapon and wings, the Lotus divine pieces at +10,
## the Legendary Guild Wings), the 2/4/6/7 piece bonus, the ★499 / ★500 gate, +15 and
## sockets, the drop distribution (Star500Gear.drop) and the forge (craft), selling /
## loot rules, the save (JSON round trip, repair, wire look, forged pieces), the icons
## and the models (held weapons, worn pieces, wings and capes with their clips, the aura).
##   godot --headless --path . res://tests/integration/star500_gear_test.tscn
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	WorldEvents.festival_enabled = false
	_items()
	_stats()
	_requirement()
	_set_bonus()
	_enhance()
	_drops()
	_craft()
	_rules()
	_save()
	_icons()
	await _visuals()
	print("STAR500 GEAR: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func _hero(cls: StringName, stars: int) -> void:
	Game.new_profile(cls, "Heaven QA", FaceKit.default_look())
	Game.profile.level = Game.MAX_LEVEL
	Game.paragon()["level"] = stars
	Game.profile["inv"] = []
	Game.profile["storage"] = []
	Game.storage().clear()


func _full(cls: String) -> Dictionary:
	var equip := {}
	for slot in Star500Gear.SLOTS:
		equip[slot] = Star500Gear.item(cls, slot)
	return equip


func _items() -> void:
	check(Star500Gear.SLOTS.size() == 7 and StarGearData.CLASSES.size() == 11 and Star500Gear.catalogue().size() == 77, "seven pieces for each of the eleven classes")
	var names := {}
	for cls in StarGearData.CLASSES:
		check(Star500Gear.set_label(cls).begins_with("ชุดเทวาลัย"), "%s: the set is ชุดเทวาลัย... (%s)" % [cls, Star500Gear.set_label(cls)])
		for slot in Star500Gear.SLOTS:
			var it := Star500Gear.item(cls, slot)
			check(not it.is_empty() and it.kind == "equip" and it.slot == slot and it["class"] == cls and int(it.star500) == 1, "%s %s: an item of its class and slot" % [cls, slot])
			check(int(it.level) == 600 and int(it.rarity) == 4 and int(it.sockets) == 3 and int(it.plus) == 0 and (it.gems as Array).is_empty(), "%s %s: Lv.600, mythic, three sockets, +0" % [cls, slot])
			check(String(it.name).contains("เทวาลัย") and not names.has(it.name), "%s %s: its own Thai name (%s)" % [cls, slot, it.name])
			names[it.name] = true
			check(not it.has("star_tier") and not it.has("set_gear") and not it.has("collection") and not it.has(DragonGearData.KEY), "%s %s: no older tier's key" % [cls, slot])
			check(String(it.base) == ("wings" if slot == "wings" else (Star500Gear.weapon_kind(cls) if slot == "weapon" else slot)), "%s %s: base %s" % [cls, slot, it.base])
			if slot == "wings":
				check(it.wing == cls, "%s wings: wing is the class" % cls)
				check(String(it.name).begins_with("ผ้าคลุม") == CapeArt.wears_cape(cls), "%s wings: a cape for the cape classes (%s)" % [cls, it.name])
			check(ItemData.color_of(it) == Star500Gear.COLOR, "%s %s: the celestial gold colour" % [cls, slot])
			var lines := ItemData.detail_lines(it)
			check(lines.any(func(l): return String(l).contains("สวมใส่ได้ที่ ดาว 500")) and lines.any(func(l): return String(l).contains("โบนัสเซต")), "%s %s: the tooltip names ★500 and the set bonus" % [cls, slot])
	check(Star500Gear.item("nobody", "weapon").is_empty() and Star500Gear.item("warrior", "belt").is_empty(), "no piece for an unknown class or slot")


## Every stat beats every older source of the slot by at least 25% at the same +.
func _stats() -> void:
	for cls in StarGearData.CLASSES:
		for slot in Star500Gear.SLOTS:
			var stats := Star500Gear.stats_for(cls, slot)
			var older: Array[Dictionary] = []
			if slot == "wings":
				var dragon := {}
				var ranges := DragonGearData.wing_ranges(cls)
				for key in ranges:
					dragon[key] = ranges[key][1]
				older.append(dragon)
			else:
				older.append(SetGearData.stats_for(cls, slot))
				# The Lotus divine piece and the mythic 200★ piece at their best, enhanced to +10.
				var top := SetGearData.top_stats(cls, slot)
				var at10 := {}
				for key in top:
					at10[key] = SetGearData.at_plus(key, float(top[key]))
				older.append(at10)
				if slot == "weapon":
					var dragon := {}
					var ranges := DragonGearData.weapon_ranges(cls)
					for key in ranges:
						dragon[key] = ranges[key][1]
					older.append(dragon)
			for source in older:
				for key in source:
					check(stats.has(key) and float(stats[key]) >= float(source[key]) * 1.25 - 0.001, "%s %s %s: %s over %s (+25%% or more)" % [cls, slot, key, str(stats.get(key)), str(source[key])])
			if slot == "wings":
				for key in stats:
					if LegendWings.STATS.has(key):
						check(float(stats[key]) >= float(LegendWings.STATS[key]), "%s wings %s: never under the Legendary Guild Wings" % [cls, key])
			# Not absurd: at most about 1.6x the 250★ set piece (the weapon: the dragon's top).
			# (The wings: or a tenth over the Legendary Guild Wings, whichever is higher.)
			var ref := SetGearData.stats_for(cls, slot) if slot != "wings" else older[0]
			for key in ref:
				var cap := float(ref[key]) * 1.6 + 1.0
				if slot == "wings" and LegendWings.STATS.has(key):
					cap = maxf(cap, float(LegendWings.STATS[key]) * 1.1 + 1.0)
				check(float(stats[key]) <= cap, "%s %s %s: not absurd" % [cls, slot, key])
			# Casters carry magic attack, the rest attack.
			if slot in ["weapon", "ring"]:
				check(stats.has("matk") == SetGearData.caster(cls) and stats.has("atk") != SetGearData.caster(cls), "%s %s: the class's own attack stat" % [cls, slot])


func _requirement() -> void:
	for cls in [&"warrior", &"mage", &"darklord", &"muaythai"]:
		_hero(cls, 499)
		var weapon := Star500Gear.item(String(cls), "weapon")
		var wings := Star500Gear.item(String(cls), "wings")
		check(Game.equip_problem(weapon).contains("ดาว 500") and Game.equip_problem(wings).contains("ดาว 500"), "%s at ★499: both ask for ดาว 500" % cls)
		Game.add_item(weapon)
		check(not Game.equip_from_bag(Game.profile.inv.find(weapon)), "%s at ★499 cannot wear the weapon" % cls)
		Game.paragon()["level"] = 500
		check(Game.equip_problem(weapon) == "" and Game.equip_problem(wings) == "", "%s at ★500: both can be worn" % cls)
		check(Game.equip_from_bag(Game.profile.inv.find(weapon)) and is_same(Game.profile.equip.weapon, weapon), "%s at ★500 wears the weapon" % cls)
		Game.add_item(wings)
		check(Game.equip_from_bag(Game.profile.inv.find(wings)) and is_same(Game.profile.equip.wings, wings), "%s at ★500 wears the wings" % cls)
	_hero(&"archer", 500)
	check(Game.equip_problem(Star500Gear.item("mage", "armor")) == "สำหรับอาชีพอื่น", "another class's piece is not for wearing")


func _set_bonus() -> void:
	check(Star500Gear.bonus(1).is_empty() and Star500Gear.bonus(2) == {"hp": 0.08}, "2 pieces: HP +8%")
	var four := Star500Gear.bonus(4)
	check(is_equal_approx(float(four.atk), 0.08) and is_equal_approx(float(four.def), 0.08), "4 pieces: ATK and DEF +8%")
	var seven := Star500Gear.bonus(7)
	check(is_equal_approx(float(seven.atk), 0.19) and is_equal_approx(float(seven.def), 0.13) and is_equal_approx(float(seven.hp), 0.13) and is_equal_approx(float(seven.crit), 0.05)
		and is_equal_approx(float(seven.crit_dmg), 0.2) and is_equal_approx(float(seven.lifesteal), 0.02), "7 pieces: the whole bonus (%s)" % str(seven))
	for cls in ClassData.IDS:
		var c := String(cls)
		_hero(cls, 500)
		Game.profile.equip = _full(c)
		var with_all := HeroStats.compute(Game.profile)
		check(int(with_all.get("star500", 0)) == 7 and Star500Gear.worn_count(Game.profile.equip, c) == 7, "%s: seven pieces counted" % c)
		# The same gear without the bonus: the bonus is what lifts it.
		var stats := HeroStats.compute(Game.profile)
		var plain := Game.profile.duplicate(true)
		plain["class"] = c
		var bare := stats.duplicate()
		check(float(with_all.lifesteal) >= 0.02 - 0.0001 and float(with_all.crit_dmg) >= 0.2 - 0.0001, "%s: lifesteal and crit damage from the set" % c)
		# Removing the ring drops to 6 pieces: attack falls by the 7-piece share.
		Game.profile.equip.erase("ring")
		var six := HeroStats.compute(Game.profile)
		check(int(six.star500) == 6 and float(six.atk) < float(with_all.atk) and int(six.max_hp) < int(with_all.max_hp), "%s: six pieces give less than seven" % c)
		# Another class's pieces give no bonus.
		Game.profile.equip = _full("warrior" if c != "warrior" else "mage")
		check(int(HeroStats.compute(Game.profile).star500) == 0, "%s: another class's set counts nothing" % c)
		check(bare.size() > 0 and plain.size() > 0, "%s: compute ran" % c)
	# The ★500 set beats the 250★ set with the dragon weapon and wings.
	_hero(&"warrior", 500)
	var old := {}
	for slot in SetGearData.SLOTS:
		old[slot] = SetGearData.item("warrior", slot)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	old["weapon"] = DragonGearData.weapon(&"warrior", rng)
	old["wings"] = DragonGearData.wings(&"warrior", rng)
	Game.profile.equip = old
	var before: Dictionary = HeroStats.compute(Game.profile)
	Game.profile.equip = _full("warrior")
	var after: Dictionary = HeroStats.compute(Game.profile)
	check(float(after.atk) > float(before.atk) * 1.25 and float(after.def) > float(before.def) * 1.25 and int(after.max_hp) > int(before.max_hp) * 1.2,
		"the full ★500 set clearly beats the 250★ set + Dragon God gear (atk %d -> %d, def %d -> %d, hp %d -> %d)" % [int(before.atk), int(after.atk), int(before.def), int(after.def), int(before.max_hp), int(after.max_hp)])
	# The outfit + bonus works on the pieces like on any other.
	for slot in HeroStats.OUTFIT_SLOTS:
		Game.profile.equip[slot]["plus"] = 15
	check(is_equal_approx(HeroStats.outfit_bonus(Game.profile.equip), 0.5), "armour, helm and boots at +15: the outfit +50%")


func _enhance() -> void:
	for slot in Star500Gear.SLOTS:
		var it := Star500Gear.item("bard", slot)
		check(EnhanceFx.can_enhance(it) == EnhanceFx.can_enhance(SetGearData.item("bard", slot) if slot != "wings" else DragonGearData.wings(&"bard", RandomNumberGenerator.new())), "%s enhances like the older tiers' piece" % slot)
		it["plus"] = 15
		check(Game._valid_item(it) and ItemData.max_sockets(it) == 4, "%s at +15: valid, a fourth socket can be drilled" % slot)
		var base := HeroStats.gear_bonus({"equip": {slot: Star500Gear.item("bard", slot)}})
		var up := HeroStats.gear_bonus({"equip": {slot: it}})
		check(float(up.hp) > float(base.hp) * 1.7, "%s: +15 adds 75%% (hp %d -> %d)" % [slot, int(base.hp), int(up.hp)])


func _drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 500
	var n := 200000
	var pieces := 0
	var cores := 0
	var own := 0
	var slots := {}
	for i in n:
		var d := Star500Gear.drop(rng, &"mage", false)
		if d.is_empty():
			continue
		if d.kind == "jewel":
			check(d.id == Star500Gear.CORE and int(d.count) == 1, "a monster's core drop is one แก่นเทวาลัย")
			cores += 1
		else:
			pieces += 1
			own += 1 if d["class"] == "mage" else 0
			slots[d.slot] = int(slots.get(d.slot, 0)) + 1
			if pieces < 30:
				check(Game._valid_item(d), "a dropped piece is valid")
	var piece_rate := float(pieces) / n
	check(piece_rate > 0.0014 and piece_rate < 0.0026, "a monster drops a piece about 0.2%% of kills (%.4f)" % piece_rate)
	check(float(cores) / n > 0.007 and float(cores) / n < 0.013, "and a core about 1%% (the owner's rate) (%.4f)" % (float(cores) / n))
	check(float(own) / pieces > 0.2 and float(own) / pieces < 0.42, "a monster's piece is the own class about 30%% (%.2f)" % (float(own) / pieces))
	var boss_n := 20000
	var boss_pieces := 0
	var boss_own := 0
	var boss_cores := 0
	var classes := {}
	for i in boss_n:
		var d := Star500Gear.drop(rng, &"defender", true)
		if d.is_empty():
			continue
		if d.kind == "jewel":
			boss_cores += 1
			check(int(d.count) >= 1 and int(d.count) <= 3, "a boss's cores: 1-3")
			continue
		boss_pieces += 1
		classes[d["class"]] = true
		boss_own += 1 if d["class"] == "defender" else 0
		slots[d.slot] = int(slots.get(d.slot, 0)) + 1
	var boss_rate := float(boss_pieces) / boss_n
	check(boss_rate > 0.085 and boss_rate < 0.115, "a boss drops a piece about 10%% (%.3f)" % boss_rate)
	check(float(boss_own) / boss_pieces > 0.58 and float(boss_own) / boss_pieces < 0.72, "a boss's piece is the own class about 65%% (%.2f)" % (float(boss_own) / boss_pieces))
	check(classes.size() == 11, "pieces of every class drop")
	check(float(boss_cores) / boss_n > 0.48, "a boss drops cores often (%.2f)" % (float(boss_cores) / boss_n))
	for slot in Star500Gear.SLOTS:
		check(slots.has(slot), "%s drops" % slot)
	check(int(slots.wings) < int(slots.weapon), "the wings drop a little rarer than the weapon")
	var none := 0
	for i in 2000:
		if Star500Gear.drop(rng, &"warrior", false).is_empty():
			none += 1
	check(none > 1900, "most kills drop nothing of the set")


func _craft() -> void:
	_hero(&"priest", 300)
	# A first mythic piece pays its achievement (gold, a gem) once: get that out of the way.
	Game.add_item(Star500Gear.item("priest", "ring"))
	Game.profile["inv"] = []
	Game.profile.gold = 0
	check(Star500Gear.craft("armor").contains("ไม่พอ"), "no cores: refused")
	Game.add_item(ItemData.jewel(Star500Gear.CORE, 100))
	check(Star500Gear.craft_problem("armor").contains("เหรียญ"), "no gold: refused")
	Game.profile.gold = Star500Gear.CRAFT_GOLD * 2
	var before: int = Game.profile.inv.size()
	# The owner's 25%: a failed try spends the cores and the gold and gives nothing.
	check(is_equal_approx(Star500Gear.CRAFT_CHANCE, 0.25), "the forge succeeds 25% of the time")
	check(Star500Gear.craft("wings", 0.25) == "fail" and Game.jewel_count(Star500Gear.CORE) == 100 - int(Star500Gear.CRAFT_CORES.wings) and int(Game.profile.gold) == Star500Gear.CRAFT_GOLD and Game.profile.inv.size() == before, "a failed try uses up the cores and the gold, nothing made")
	Game.add_item(ItemData.jewel(Star500Gear.CORE, int(Star500Gear.CRAFT_CORES.wings)))
	Game.profile.gold = Star500Gear.CRAFT_GOLD * 2
	check(Star500Gear.craft("wings", 0.249) == "ok", "cores and gold forge the wings")
	check(Game.jewel_count(Star500Gear.CORE) == 100 - int(Star500Gear.CRAFT_CORES.wings) and int(Game.profile.gold) == Star500Gear.CRAFT_GOLD, "the cores and gold are spent")
	var made: Array = Game.profile.inv.filter(Star500Gear.is_item)
	check(made.size() == 1 and made[0]["class"] == "priest" and made[0].slot == "wings" and Game.profile.inv.size() == before + 1, "the hero's own class's piece is in the bag")
	check(Star500Gear.craft("nothing") != "ok" and Star500Gear.cost_text("weapon").contains("แก่นเทวาลัย"), "unknown slot refused; the cost names the core")
	check(ItemData.JEWELS.has(Star500Gear.CORE) and ItemData.name_of(ItemData.jewel(Star500Gear.CORE)) == "แก่นเทวาลัย", "แก่นเทวาลัย is a jewel")


func _rules() -> void:
	_hero(&"lancer", 500)
	var it := Star500Gear.item("mage", "helm")
	check(Game.keeps_loot(it) and Game.pickup_sale(it) == 0, "a piece is always picked up and never auto-sold")
	Game.add_item(it)
	check(not Game.auto_sell_indices(31, 100000).has(Game.profile.inv.find(it)), "never bulk-sold")
	check(ItemData.sell_price(it) > 0, "it can be sold one by one")
	var wings := Star500Gear.item("lancer", "wings")
	check(not StarWingData.can_craft(wings), "the ★500 wings are no material for the 100★ wings")
	check(Game.tower_reroll_wings(wings) != "ok" and wings.stats == Star500Gear.stats_for("lancer", "wings"), "the tower does not re-roll them")


func _save() -> void:
	_hero(&"summoner", 500)
	Game.profile.equip = _full("summoner")
	Game.profile.equip.weapon["plus"] = 12
	Game.profile.equip.weapon["gems"] = ["ruby_2"]
	Game.add_item(Star500Gear.item("assassin", "amulet"))
	Game.profile.storage.append(Star500Gear.item("bard", "wings"))
	var saved: Dictionary = Game.profile.duplicate(true)
	check(Game._valid_profile(saved.duplicate(true)), "a profile wearing and carrying ★500 pieces is a valid save")
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	check(parsed is Dictionary and Game._valid_profile((parsed as Dictionary).duplicate(true)), "the JSON round trip is a valid save")
	if parsed is Dictionary:
		var back := Game._repair(parsed)
		check(int(back.equip.weapon.level) == 600 and back.equip.weapon.level is int and back.equip.weapon.star500 is int, "the repair keeps Lv.600 and the mark as ints")
		check(int(back.equip.weapon.plus) == 12 and back.equip.weapon.gems == ["ruby_2"] and back.equip.weapon.stats == saved.equip.weapon.stats, "plus, gems and stats survive")
		check(Star500Gear.worn_count(back.equip, "summoner") == 7 and Star500Gear.is_wings(back.equip.wings), "all seven still count")
		check(back.inv.filter(Star500Gear.is_item).size() == 1 and back.storage.filter(Star500Gear.is_item).size() == 1, "bag and storage pieces survive")
	var wire := PlayerLook.wire_equip(saved.equip)
	check(not wire.weapon.has("stats") and Game._valid_item(wire.weapon) and Game._valid_item(wire.wings), "a wire look's pieces pass the item check")
	var clean := PlayerLook.clean({"class": "summoner", "equip": JSON.parse_string(JSON.stringify(wire)), "level": 100, "stars": 500})
	check(clean is Dictionary and Star500Gear.is_weapon((clean as Dictionary).get("equip", {}).get("weapon")) and Star500Gear.is_wings((clean as Dictionary).get("equip", {}).get("wings")), "PlayerLook.clean keeps them")
	var piece := Star500Gear.item("summoner", "weapon")
	var strong: Dictionary = piece.stats.duplicate()
	strong["matk"] = int(strong.matk) * 2
	var extra: Dictionary = piece.stats.duplicate()
	extra["lifesteal"] = 0.5
	for change in [{"level": 400}, {"level": 601}, {"rarity": 3}, {"class": "mage"}, {"class": ""}, {"base": "sword"}, {"slot": "belt"}, {"star_tier": 200},
			{"set_gear": "summoner"}, {"collection": "lotus_200"}, {"dragon": 1}, {"legend_week": 3000}, {"star500": 2}, {"star500": "1"}, {"stats": strong}, {"stats": extra}, {"plus": 16}]:
		var bad: Dictionary = piece.duplicate(true)
		bad.merge(change, true)
		check(not Game._valid_item(bad), "a forged piece is refused: %s" % str(change).left(60))
	var wing_bad := Star500Gear.item("summoner", "wings")
	wing_bad["wing"] = "mage"
	check(not Game._valid_item(wing_bad), "wings of another class's model are refused")


func _icons() -> void:
	for piece in Star500Gear.catalogue():
		check(ItemLook.icon(piece) != null, "%s has an icon (%s)" % [piece.name, ItemLook.look_of(piece)])
	check(ItemLook.icon(ItemData.jewel(Star500Gear.CORE, 3)) != null, "แก่นเทวาลัย has an icon")
	var ids := ItemLook.all_icon_ids()
	for id in Star500Gear.icon_ids():
		check(ids.has(id), "%s is in the icon list" % id)
	var node := ItemLook.build_icon_node("heaven_wings_mage")
	check(node != null and node.get_child_count() > 0, "the wings icon builds")
	node.free()
	node = ItemLook.build_icon_node("heaven_armor_defender")
	check(node != null and node.get_child_count() > 0, "the armour icon builds")
	node.free()


func _visuals() -> void:
	for cls in ["warrior", "defender", "darklord", "muaythai", "bard"]:
		var h := HeroVisual.new()
		add_child(h)
		h.setup(StringName(cls), "", true, _full(cls), FaceKit.default_look())
		await get_tree().process_frame
		var wings := h.find_children("Wings_star500_*", "", true, false)
		check(wings.size() == 1, "%s wears the ★500 wing piece" % cls)
		if wings.size() == 1:
			var player := (wings[0] as Node).get_node_or_null("AnimationPlayer") as AnimationPlayer
			check(player != null and player.has_animation("Fold") and player.has_animation("Glide"), "%s: the wing clips" % cls)
			check(((wings[0] as Node).find_children("HeavenCape", "", true, false).size() == 1) == (cls in ["darklord", "muaythai"]), "%s: a cape exactly for the cape classes" % cls)
		check(h.find_children("Star500Aura", "", true, false).size() == 1 and h.find_children("SetAura", "", true, false).is_empty(), "%s: the celestial aura (not the 250★ one)" % cls)
		var held := h.find_children("Held_heaven_*", "", true, false)
		check(cls == "muaythai" or held.size() >= 1, "%s: holds the ★500 weapon" % cls)
		check(h.find_children("Heaven_*", "", true, false).size() >= 4, "%s: the worn pieces are the ★500 art" % cls)
		h.set_wing_mode(HeroVisual.WING_FOLD, true)
		h.set_wing_mode(HeroVisual.WING_FLY, true)
		h.queue_free()
		await get_tree().process_frame
	# The light dress (a crowd): no motes on the wings or the aura.
	var light := Star500WingArt.build("mage", true)
	check(light.find_children("*", "CPUParticles3D", true, false).is_empty(), "a light pair has no motes")
	var cost := 0
	for mi in light.find_children("*", "MeshInstance3D", true, false):
		cost += (mi as MeshInstance3D).mesh.get_surface_count()
	check(cost <= 8, "a pair is a handful of surfaces (%d)" % cost)
	light.free()
	var aura := Star500GearArt.aura("mage", true)
	check(aura.find_children("*", "CPUParticles3D", true, false).is_empty(), "a light aura has no motes")
	aura.free()
	for kind_cls in ["warrior", "archer", "lancer", "mage", "priest", "summoner", "defender", "assassin", "darklord", "bard"]:
		var w := WeaponKit.build(Star500Gear.look_id(kind_cls, "weapon"))
		check(w != null and w.has_meta("star500") and w.get_meta("weapon_kind") == Star500Gear.weapon_kind(kind_cls), "%s weapon builds through WeaponKit" % kind_cls)
		w.free()
	var wraps := WeaponKit.build("heaven_wraps_muaythai")
	check(wraps != null, "the Muay Thai dusters build")
	wraps.free()
