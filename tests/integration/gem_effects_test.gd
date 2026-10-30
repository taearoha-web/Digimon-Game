extends Node
## The gem overhaul in play: onyx raises the hero's crit damage, pearl heals by a share
## of the damage dealt (one throttled "+N"), opal shortens skill cooldowns, tourmaline
## raises the hero's EXP and drop chances, the 12-gem sets (ruby fury, amethyst
## bulwark, emerald and sapphire regen) switch on in combat, special gems and drills
## drop from ★ fields, field bosses and the world boss bounty, and a worn piece with a
## ตำนาน gem sparkles in its colour.
##   godot --headless --path . res://tests/integration/gem_effects_test.tscn

var checks := 0
var failures := 0
var field: Node3D
var hero: Hero


class LootZone:
	extends Zone
	var items: Array = []
	func _ready() -> void:
		pass
	func _spawn_loot(item: Dictionary, _gold: int, _from: Vector3) -> void:
		if not item.is_empty():
			items.append(item)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	Game.new_profile(&"warrior", "อัญมณีQA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.hp = 999999
	Game.profile.mp = 999999
	field = Node3D.new()
	add_child(field)
	hero = Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	await get_tree().process_frame
	_crit_damage()
	# Floating texts are capped while many are in flight: let the crit numbers fade.
	await _texts_fade()
	_lifesteal()
	_cdr()
	await _fortune()
	await _texts_fade()
	_gem_sets()
	_drops()
	await _glow()
	field.queue_free()
	await get_tree().process_frame
	print("GEM EFFECTS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _texts_fade() -> void:
	await get_tree().create_timer(1.8).timeout


## Wears rarity-3 pieces in [param gems_by_slot] (slot -> gem ids) and recomputes the stats.
func _wear(gems_by_slot: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var equip := {}
	for slot in gems_by_slot:
		var item := ItemData.generate(100, Game.class_id(), rng, 3, slot)
		item["gems"] = gems_by_slot[slot]
		equip[slot] = item
	Game.profile.equip = equip
	hero.refresh_stats()


func _mob(id: StringName, lv: int, at: Vector3, parent: Node = null) -> Mob:
	var m := Mob.new()
	m.setup(id, lv, at, hero)
	(parent if parent != null else field).add_child(m)
	m.set_physics_process(false)
	m.global_position = at
	return m


func _count_labels(prefix: String) -> int:
	var n := 0
	for node in field.get_children():
		if node is Label3D and (node as Label3D).text.begins_with(prefix):
			n += 1
	return n


## Average damage of [param hits] always-critical basic hits on a monster that cannot die.
func _crit_hits(mob: Mob, hits: int) -> float:
	var dealt := 0
	for i in hits:
		var before := mob.hp
		hero._deal(mob, 1.0, Color.WHITE, &"impact", false)
		dealt += before - mob.hp
	return float(dealt) / float(hits)


func _crit_damage() -> void:
	_wear({"weapon": ["onyx_4", "onyx_4", "onyx_4"]})
	var bonus := float(hero.stats.get("crit_dmg", 0.0))
	check(bonus >= 0.3, "onyx gems give crit damage (%.2f)" % bonus)
	check(is_equal_approx(hero.crit_mult(), HeroStats.CRIT_DAMAGE + bonus), "the hero's crits hit x%.2f (CRIT_DAMAGE + crit_dmg)" % hero.crit_mult())
	var mob := _mob(&"forest_orc", 100, Vector3(3, 0, 0))
	mob.max_hp = 1000000000
	mob.hp = mob.max_hp
	hero.stats["crit"] = 1.0
	hero.stats["lifesteal"] = 0.0
	var with_gems := _crit_hits(mob, 60)
	hero.stats["crit_dmg"] = 0.0
	var without := _crit_hits(mob, 60)
	var ratio := with_gems / maxf(without, 1.0)
	var want := (HeroStats.CRIT_DAMAGE + bonus) / HeroStats.CRIT_DAMAGE
	check(absf(ratio - want) < 0.06, "a crit with onyx deals x%.3f the damage of one without (want x%.3f)" % [ratio, want])
	mob.queue_free()


func _lifesteal() -> void:
	_wear({"weapon": ["pearl_4", "pearl_4", "pearl_4"], "armor": ["pearl_4", "pearl_4", "pearl_4"]})
	var share := float(hero.stats.get("lifesteal", 0.0))
	check(share > 0.0 and share <= HeroStats.MAX_LIFESTEAL + 0.0001, "pearl gems give lifesteal, capped (%.3f)" % share)
	var mob := _mob(&"forest_orc", 100, Vector3(3, 0, 1))
	mob.max_hp = 1000000000
	mob.hp = mob.max_hp
	Game.profile.hp = 1
	var labels0 := _count_labels("+")
	var dealt := 0
	for i in 12:
		var before := mob.hp
		hero._deal(mob, 1.0, Color.WHITE, &"impact", false)
		dealt += before - mob.hp
	var healed := int(Game.profile.hp) - 1
	check(healed > 0 and absf(float(healed) - float(dealt) * share) <= 1.0, "the hero heals by its lifesteal share of the damage (%d of %d dealt)" % [healed, dealt])
	var shown := _count_labels("+") - labels0
	check(shown >= 1 and shown <= 2, "the green +N is throttled (%d labels for 12 hits)" % shown)
	# No pearl, no healing.
	hero.stats["lifesteal"] = 0.0
	var hp0 := int(Game.profile.hp)
	hero._deal(mob, 1.0, Color.WHITE, &"impact", false)
	check(int(Game.profile.hp) == hp0, "without lifesteal a hit heals nothing")
	mob.queue_free()
	Game.profile.hp = int(hero.stats.max_hp)


func _cdr() -> void:
	_wear({})
	var skill := {}
	for s in ClassData.pool(Game.class_id()):
		if Game.skill_unlocked(s) and String(s.get("shape", "")) not in ["self", "summon"] and not s.has("star"):
			skill = s
			break
	check(not skill.is_empty(), "the hero has an attack skill to cast")
	if skill.is_empty():
		return
	var base := hero.cooldown_of(skill)
	_wear({"weapon": ["opal_4", "opal_4", "opal_4"], "armor": ["opal_4", "opal_4", "opal_4"]})
	var cdr := float(hero.stats.get("cdr", 0.0))
	check(cdr > 0.0 and cdr <= HeroStats.MAX_CDR + 0.0001, "opal gems give cooldown reduction, capped (%.2f)" % cdr)
	check(is_equal_approx(hero.cooldown_of(skill), base * (1.0 - cdr)), "a skill's cooldown is cut by cdr (%.2f -> %.2f s)" % [base, hero.cooldown_of(skill)])
	# The cooldown the hero starts on a cast is the shortened one.
	var target := _mob(&"forest_orc", 100, hero.global_position + Vector3(0, 0, 2))
	hero.set_target(target)
	Game.profile.mp = 999999
	hero.cooldowns.erase(skill.id)
	hero._cast(skill)
	var started := float(hero.cooldowns.get(skill.id, -1.0))
	check(Game.skill_unlocked(skill) and is_equal_approx(started, base * (1.0 - cdr)), "casting starts the shortened cooldown (%.2f s)" % started)
	hero.set_target(null)
	target.queue_free()


## EXP of one kill of a level-matched monster worth 100 EXP, with [param fortune].
func _kill_exp(zone: LootZone, fortune: float) -> int:
	var mob := _mob(&"forest_orc", 30, Vector3(6, 0, 0), zone)
	mob.stats["exp"] = 100
	hero.stats["fortune"] = fortune
	Game.profile.level = 30
	Game.profile.exp = 0
	zone._on_mob_died(mob)
	mob.queue_free()
	return int(Game.profile.exp)


func _fortune() -> void:
	_wear({"weapon": ["tourmaline_4", "tourmaline_4", "tourmaline_4"], "armor": ["tourmaline_4", "tourmaline_4", "tourmaline_4"]})
	var fortune := float(hero.stats.get("fortune", 0.0))
	check(fortune > 0.0 and fortune <= HeroStats.MAX_FORTUNE + 0.0001, "tourmaline gems give fortune, capped (%.2f)" % fortune)
	var zone := LootZone.new()
	zone.zone_id = &"meadow"
	zone.data = ZoneData.get_zone(&"meadow")
	zone.hero = hero
	field.add_child(zone)
	zone.set_process(false)
	await get_tree().process_frame
	var plain := _kill_exp(zone, 0.0)
	var lucky := _kill_exp(zone, 0.5)
	check(plain > 0 and absi(lucky - int(round(float(plain) * 1.5))) <= 2, "fortune raises the hero's EXP from a kill (%d -> %d)" % [plain, lucky])
	# Drop chances: 2000 meadow kills drop more stat gems with fortune.
	var mob := _mob(&"forest_orc", 30, Vector3(6, 0, 0), zone)
	var counts := []
	for f in [0.0, 0.5]:
		hero.stats["fortune"] = f
		zone.items.clear()
		zone.rng.seed = 404
		for i in 2000:
			zone._drop_loot(mob)
		counts.append(zone.items.filter(func(it): return String(it.get("kind", "")) == "gem").size())
	check(counts[1] > int(float(counts[0]) * 1.25), "fortune raises drop chances (%d -> %d gems in 2000 kills)" % counts)
	check(zone.items.all(func(it): return String(it.get("kind", "")) != "gem" or not bool(ItemData.gem_info(it).special)), "a normal field drops no special gems")
	mob.queue_free()
	zone.queue_free()
	hero.stats["fortune"] = 0.0
	Game.profile.level = 100


func _gem_sets() -> void:
	var rubies := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		rubies[slot] = ["ruby_2", "ruby_2", "ruby_2"]
	_wear(rubies)
	check(String(hero.stats.get("gem_set", "")) == "ruby", "twelve rubies worn make the ruby set (%s)" % String(hero.stats.get("gem_set", "")))
	var max_hp := int(hero.stats.max_hp)
	Game.profile.hp = max_hp
	hero._gem_set_tick(0.1)
	check(not hero._fury_on and is_equal_approx(hero.gem_atk_mult(), 1.0), "fury sleeps at full HP")
	var notes0 := _count_labels("เลือดเดือด!")
	Game.profile.hp = int(max_hp * 0.2)
	hero._gem_set_tick(0.1)
	check(hero._fury_on and is_equal_approx(hero.gem_atk_mult(), 1.0 + HeroStats.GEM_SET_FURY), "under 30% HP the ruby set gives +25% ATK")
	check(_count_labels("เลือดเดือด!") - notes0 == 1, "the fury note shows once when it switches on")
	Game.profile.hp = int(max_hp * 0.8)
	hero._gem_set_tick(0.1)
	check(not hero._fury_on and is_equal_approx(hero.gem_atk_mult(), 1.0), "healed above 30% fury switches off")
	Game.profile.hp = int(max_hp * 0.2)
	hero._gem_set_tick(0.1)
	check(hero._fury_on and _count_labels("เลือดเดือด!") - notes0 == 1, "fury back on: the note waits for its cooldown")
	# Amethyst bulwark: +20% DEF under 50% HP.
	hero.stats["gem_set"] = "amethyst"
	Game.profile.hp = max_hp
	var def_full := hero.effective_def()
	Game.profile.hp = int(max_hp * 0.4)
	hero._gem_set_tick(0.1)
	check(hero._bulwark_on and is_equal_approx(hero.effective_def(), def_full * (1.0 + HeroStats.GEM_SET_BULWARK)) and not hero._fury_on, "under 50% HP the amethyst set gives +20% DEF")
	check(_count_labels("ป้อมปราการ!") == 1, "the bulwark note shows")
	# Emerald: 2% max HP every 5 s in combat; nothing out of combat.
	hero.stats["gem_set"] = "emerald"
	hero._gem_regen_time = 0.0
	Game.profile.hp = int(max_hp * 0.4)
	hero._since_hurt = 10.0
	hero._gem_set_tick(5.1)
	check(int(Game.profile.hp) == int(max_hp * 0.4), "the emerald set does not heal out of combat")
	hero._since_hurt = 0.5
	hero._gem_set_tick(4.0)
	var hp_mid := int(Game.profile.hp)
	hero._gem_set_tick(1.1)
	check(hp_mid == int(max_hp * 0.4) and int(Game.profile.hp) - hp_mid == int(max_hp * 0.02), "the emerald set heals 2%% max HP every 5 s in combat (+%d)" % (int(Game.profile.hp) - hp_mid))
	# Sapphire: 2% max MP every 3 s.
	hero.stats["gem_set"] = "sapphire"
	hero._gem_regen_time = 0.0
	var max_mp := int(hero.stats.max_mp)
	Game.profile.mp = int(max_mp * 0.3)
	hero._gem_set_tick(3.05)
	check(int(Game.profile.mp) - int(max_mp * 0.3) == maxi(1, int(max_mp * 0.02)), "the sapphire set restores 2% max MP every 3 s")
	_wear({})
	Game.profile.hp = int(hero.stats.max_hp)


func _drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var tally := func(source: StringName, fortune: float, n: int) -> Dictionary:
		var out := {"special": 0, "drill": 0, "sizes": {}, "bad": 0}
		for i in n:
			for item in Zone.gem_bonus_drops(source, fortune, rng):
				if String(item.kind) == "jewel" and String(item.id) == "drill":
					out.drill += int(item.count)
				elif String(item.kind) == "gem" and bool(ItemData.gem_info(item).special):
					out.special += 1
					out.sizes[int(ItemData.gem_info(item).size)] = true
				else:
					out.bad += 1
		return out
	var star: Dictionary = tally.call(&"star", 0.0, 100000)
	check(star.special > 700 and star.special < 1300 and star.sizes.keys().all(func(s): return s <= 1) and star.bad == 0, "★-field monsters drop special gems (size 0-1) at about 1%% (%d / 100000)" % star.special)
	check(star.drill > 180 and star.drill < 420, "★-field monsters drop drills at about 0.3%% (%d / 100000)" % star.drill)
	var lucky: Dictionary = tally.call(&"star", 0.5, 100000)
	check(lucky.special > int(star.special * 1.3), "fortune raises the special gem chance (%d -> %d)" % [star.special, lucky.special])
	var boss: Dictionary = tally.call(&"field_boss", 0.0, 4000)
	check(boss.special > 850 and boss.special < 1150 and boss.sizes.keys().all(func(s): return s >= 1 and s <= 2), "field bosses drop a special gem (size 1-2) 25%% of the time (%d / 4000)" % boss.special)
	check(boss.drill > 680 and boss.drill < 920, "field bosses drop a drill 20%% of the time (%d / 4000)" % boss.drill)
	var world: Dictionary = tally.call(&"world_boss", 0.0, 400)
	check(world.special == 400 and world.sizes.keys().all(func(s): return s >= 2 and s <= 3), "the world boss bounty always pays a special gem (size 2-3)")
	check(world.drill >= 400 and world.drill <= 800 and world.drill > 450, "the world boss bounty always pays 1-2 drills (%d in 400)" % world.drill)
	check(Zone.gem_bonus_drops(&"", 0.5, rng).is_empty(), "ordinary monsters get no special drop roll")
	check(ItemData.name_of(ItemData.jewel("drill")) == "สว่านเจาะ", "the drill is a forge jewel")
	# Stat gems: never special; สมบูรณ์แบบ (size 3) only from Lv.80+ monsters or ★ fields.
	var perfect := {"low": 0, "high": 0, "star": 0}
	var special_seen := false
	for i in 4000:
		for key in perfect:
			var gem := Zone.random_stat_gem(50 if key != "high" else 90, 1, key == "star", rng)
			var info := ItemData.gem_info(gem)
			special_seen = special_seen or bool(info.special)
			if int(info.size) == 3:
				perfect[key] += 1
	check(not special_seen, "random stat gems never roll a special gem")
	check(perfect.low == 0 and perfect.high > 120 and perfect.high < 290 and perfect.star > 120 and perfect.star < 290, "สมบูรณ์แบบ gems drop at 5%% from Lv.80+ and ★ fields only (%s)" % str(perfect))


func _glow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var equip := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		equip[slot] = ItemData.generate(60, &"warrior", rng, 3, slot)
		equip[slot]["gems"] = ["ruby_3"]
	equip.armor["gems"] = ["ruby_1", "pearl_4"]
	equip.weapon["gems"] = ["onyx_4"]
	check(EnhanceFx.legend_gem_color(equip.armor) == ItemData.GEMS.pearl.color and EnhanceFx.legend_gem_color(equip.helm).a == 0.0, "a piece's sparkle colour is its ตำนาน gem's")
	var v := HeroVisual.new()
	add_child(v)
	v.setup(&"warrior", "", true, equip, FaceKit.default_look())
	await get_tree().process_frame
	var sparkles := v.find_children("GemSparkle*", "CPUParticles3D", true, false)
	var slots := sparkles.map(func(p): return String(p.get_meta("gem_glow", "")))
	slots.sort()
	check(slots == ["armor", "weapon"], "only pieces with a ตำนาน gem sparkle (%s)" % str(slots))
	check(sparkles.all(func(p): return v._body_nodes.has(p)), "the sparkles are kept with the outfit")
	var armor_spark: CPUParticles3D = sparkles.filter(func(p): return p.get_meta("gem_glow") == "armor")[0] if not sparkles.is_empty() else null
	check(armor_spark != null and ((armor_spark.mesh as QuadMesh).material as StandardMaterial3D).albedo_color.is_equal_approx(ItemData.GEMS.pearl.color.lightened(0.25)), "the armour sparkles in pearl white")
	equip.armor["gems"] = ["ruby_1"]
	equip.weapon["gems"] = []
	v.set_equipment(equip)
	await get_tree().process_frame
	check(v.find_children("GemSparkle*", "CPUParticles3D", true, false).is_empty(), "a re-dress without ตำนาน gems frees the sparkles")
	v.queue_free()
	equip.armor["gems"] = ["pearl_4"]
	var far := HeroVisual.new()
	far.decor_light = true
	add_child(far)
	far.setup(&"warrior", "", true, equip, FaceKit.default_look())
	await get_tree().process_frame
	check(far.find_children("GemSparkle*", "CPUParticles3D", true, false).is_empty(), "other players (decor_light) get no gem sparkle")
	far.queue_free()
	GameSettings.quality = 0
	var low := HeroVisual.new()
	add_child(low)
	low.setup(&"warrior", "", true, equip, FaceKit.default_look())
	await get_tree().process_frame
	check(low.find_children("GemSparkle*", "CPUParticles3D", true, false).is_empty(), "quality 0 gets no gem sparkle")
	low.queue_free()
	GameSettings.quality = 2
	await get_tree().process_frame
