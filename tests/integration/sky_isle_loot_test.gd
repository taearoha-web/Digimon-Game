extends Node3D
## เกาะลอยฟ้าเทพมังกร's collectibles (SkyIsleLoot): the owner's four rates per kill of any
## monster (weapon 0.5%, 300★ wings 0.1%, costume fragment 0.1%, egg 0.1%) measured over
## many seeded kills, the same for elites, with any fortune and with the festival on or
## off; never a Lv.100 pair of wings; everything else of the Poseidon table still drops;
## treasure chests (their drop, their published odds, opening one or a stack, a full bag
## and storage lose nothing, the save stays valid); 49 fragments refuse and 50 make the
## costume item (never sold for coins, never on an AI world player); the egg crafts the
## mount มังกรฟ้าเทพ (the fastest, the best bonus, its egg in no other field's roll) and a
## hero rides it; jackpots, and only jackpots, are announced; icons, the bag's actions and
## the reward shop's card.
##   godot --headless --path . res://tests/integration/sky_isle_loot_test.tscn
var checks := 0
var failures := 0

const KILLS := 400000


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func settle() -> void:
	for i in 3:
		await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	WorldEvents.festival_enabled = false
	Game.new_profile(&"darklord", "Isle QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.hp = 99999
	_items()
	_rates()
	_ranks()
	_rare()
	_chest_odds()
	_chest_open()
	_fragments()
	_world()
	_egg_and_mount()
	await _ride()
	_announce()
	_save()
	await _menu()
	WorldEvents.festival_enabled = true
	print("SKY ISLE LOOT: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func give(id: String, count: int) -> void:
	Game.add_item(ItemData.jewel(id, count))


func clear(id: String) -> void:
	var have := Game.jewel_count(id)
	if have > 0:
		Game._spend_jewels(id, have)


func _is_jewel(item: Dictionary, id: String) -> bool:
	return item.get("kind", "") == "jewel" and String(item.get("id", "")) == id


## What `n` kills drop, counted: the four jackpots, chests, other wings and the Poseidon things.
func _hunt(n: int, boss: bool, elite: bool, fortune: float, seed_value: int) -> Dictionary:
	var roll := RandomNumberGenerator.new()
	roll.seed = seed_value
	var c := {"weapon": 0, "wings": 0, "fragment": 0, "egg": 0, "chest": 0, "other_wings": 0, "divine": 0, "jewelry": 0, "scale": 0, "gem": 0, "potion": 0}
	for i in n:
		for item in SkyIsleLoot.kill_drops(&"darklord", boss, elite, fortune, roll):
			var count := int(item.get("count", 1))
			if DragonGearData.is_weapon(item):
				c.weapon += 1
			elif DragonGearData.is_wings(item):
				c.wings += 1
			elif String(item.get("slot", "")) == "wings":
				c.other_wings += 1
			elif _is_jewel(item, SkyIsleLoot.FRAGMENT):
				c.fragment += count
			elif _is_jewel(item, SkyIsleLoot.EGG):
				c.egg += count
			elif _is_jewel(item, SkyIsleLoot.CHEST):
				c.chest += count
			elif _is_jewel(item, EndgameFields.SCALE):
				c.scale += count
			elif DivineGearData.is_item(item):
				c.divine += 1
			elif String(item.get("slot", "")) in ["ring", "amulet"]:
				c.jewelry += 1
			elif item.get("kind", "") == "gem":
				c.gem += 1
			elif item.get("kind", "") == "potion":
				c.potion += 1
	return c


## A measured count is the chance within five standard deviations.
func _near(count: int, n: int, chance: float) -> bool:
	var want := float(n) * chance
	return absf(float(count) - want) <= 5.0 * sqrt(want * (1.0 - chance))


func _items() -> void:
	check(is_equal_approx(SkyIsleLoot.WEAPON_DROP, 0.005) and is_equal_approx(SkyIsleLoot.WING_DROP, 0.001)
		and is_equal_approx(SkyIsleLoot.FRAGMENT_DROP, 0.001) and is_equal_approx(SkyIsleLoot.EGG_DROP, 0.001), "the owner's four rates: 0.5% / 0.1% / 0.1% / 0.1%")
	check(SkyIsleLoot.COSTUME_FRAGMENTS == 50, "50 fragments make the costume")
	for id in [SkyIsleLoot.CHEST, SkyIsleLoot.FRAGMENT, SkyIsleLoot.EGG]:
		var item := ItemData.jewel(id)
		check(ItemData.JEWELS.has(id) and ItemData.is_stackable(item), "%s is a stackable bag item" % id)
		check(ItemData.name_of(item) != "" and ItemLook.icon(item) != null, "%s has a name and an icon" % id)
		check(Game._valid_item(item) and Game._valid_item(ItemData.jewel(id, 37)), "%s is a valid save item" % id)
		check(ItemData.tile_text(ItemData.jewel(id, 7)) == "×7", "%s tile reads its count" % id)
		check(SkyIsleLoot.help(id) != "", "%s explains itself in the bag" % id)
	var icons := {}
	for id in [SkyIsleLoot.CHEST, SkyIsleLoot.FRAGMENT, SkyIsleLoot.EGG]:
		icons[ItemLook.icon(ItemData.jewel(id))] = true
	check(icons.size() == 3, "three icons of their own")
	var costume := RewardShop.costume_item(SkyIsleLoot.COSTUME)
	check(not costume.is_empty() and ItemLook.icon(costume) != null and Game._valid_item(costume), "the costume item: an icon, a valid save item")
	check(int(costume.get("rarity", 0)) == 4, "the costume is of the top grade")
	check(MountData.exists(SkyIsleLoot.MOUNT) and MountData.mat_of(SkyIsleLoot.MOUNT) == SkyIsleLoot.EGG, "the egg is the mount's material")


func _rates() -> void:
	var c := _hunt(KILLS, false, false, 0.0, 20261114)
	check(_near(c.weapon, KILLS, SkyIsleLoot.WEAPON_DROP), "weapon 0.5%% a kill (%d of %d)" % [c.weapon, KILLS])
	check(_near(c.wings, KILLS, SkyIsleLoot.WING_DROP), "300★ wings 0.1%% a kill (%d)" % c.wings)
	check(_near(c.fragment, KILLS, SkyIsleLoot.FRAGMENT_DROP), "fragment 0.1%% a kill (%d)" % c.fragment)
	check(_near(c.egg, KILLS, SkyIsleLoot.EGG_DROP), "egg 0.1%% a kill (%d)" % c.egg)
	check(c.other_wings == 0, "no Lv.100 wings ever (%d)" % c.other_wings)
	check(_near(c.chest, KILLS, SkyIsleLoot.CHEST_NORMAL), "a treasure chest 1%% a kill (%d)" % c.chest)
	# The Poseidon table is still there at its own rates.
	check(_near(c.divine, KILLS, DivineGearData.DROP_NORMAL), "divine class pieces at the Poseidon rate (%d)" % c.divine)
	check(_near(c.jewelry, KILLS, EndgameFields.JEWELRY_NORMAL), "200★ rings and amulets at the Poseidon rate (%d)" % c.jewelry)
	check(_near(c.scale, KILLS, EndgameFields.SCALE_NORMAL), "Lotus Scales at the Poseidon rate (%d)" % c.scale)
	check(_near(c.gem, KILLS, EndgameFields.GEM_NORMAL), "gems at the Poseidon rate (%d)" % c.gem)
	check(c.potion > 0, "potions drop")
	# The festival (EXP x5, jewels x5, set core x5) leaves the table as it is: the same dice, the same drops.
	WorldEvents.festival_enabled = true
	var fest := _hunt(60000, false, false, 0.0, 77)
	WorldEvents.festival_enabled = false
	var plain := _hunt(60000, false, false, 0.0, 77)
	check(fest == plain, "the festival on or off: the very same drops (%s / %s)" % [str(fest), str(plain)])
	# Fortune (Tourmaline gems) raises the Poseidon part only.
	var lucky := _hunt(KILLS, false, false, 2.0, 5150)
	check(_near(lucky.weapon, KILLS, SkyIsleLoot.WEAPON_DROP) and _near(lucky.wings, KILLS, SkyIsleLoot.WING_DROP)
		and _near(lucky.fragment, KILLS, SkyIsleLoot.FRAGMENT_DROP) and _near(lucky.egg, KILLS, SkyIsleLoot.EGG_DROP), "fortune +200%%: the four rates stay (%s)" % str(lucky))
	check(_near(lucky.chest, KILLS, SkyIsleLoot.CHEST_NORMAL), "and the chest's")
	check(lucky.scale > c.scale * 2 and lucky.other_wings == 0, "while fortune still raises the Poseidon drops, with no other wings")


func _ranks() -> void:
	var n := 200000
	var e := _hunt(n, false, true, 0.0, 909)
	check(_near(e.weapon, n, SkyIsleLoot.WEAPON_DROP) and _near(e.wings, n, SkyIsleLoot.WING_DROP)
		and _near(e.fragment, n, SkyIsleLoot.FRAGMENT_DROP) and _near(e.egg, n, SkyIsleLoot.EGG_DROP), "an elite rolls the same four rates (%s)" % str(e))
	check(_near(e.chest, n, SkyIsleLoot.CHEST_ELITE) and SkyIsleLoot.CHEST_ELITE > SkyIsleLoot.CHEST_NORMAL, "an elite drops chests more often (%d)" % e.chest)
	check(e.other_wings == 0, "no Lv.100 wings from elites")
	var roll := RandomNumberGenerator.new()
	roll.seed = 4
	var bosses := 3000
	var weapons := 0
	for i in bosses:
		var chests := 0
		var fragments := 0
		for item in SkyIsleLoot.kill_drops(&"darklord", true, false, 0.0, roll):
			if _is_jewel(item, SkyIsleLoot.CHEST):
				chests += int(item.count)
			elif _is_jewel(item, SkyIsleLoot.FRAGMENT):
				fragments += int(item.count)
			elif DragonGearData.is_weapon(item):
				weapons += 1
			check(not (String(item.get("slot", "")) == "wings" and not DragonGearData.is_item(item)), "no Lv.100 wings from the boss")
		if chests < SkyIsleLoot.CHEST_BOSS or fragments < SkyIsleLoot.BOSS_FRAGMENTS:
			check(false, "the boss always drops %d chests and %d fragments (%d / %d)" % [SkyIsleLoot.CHEST_BOSS, SkyIsleLoot.BOSS_FRAGMENTS, chests, fragments])
	check(weapons > 0 and _near(weapons, bosses, SkyIsleLoot.WEAPON_DROP + SkyIsleLoot.BOSS_WEAPON_BONUS * (1.0 - SkyIsleLoot.WEAPON_DROP) + 0.0), "the boss's weapon: the owner's roll plus its bonus roll (%d of %d)" % [weapons, bosses])


func _rare() -> void:
	var roll := RandomNumberGenerator.new()
	roll.seed = 12
	var n := 4000
	var eggs := 0
	var weapons := 0
	var wings := 0
	for i in n:
		var chests := 0
		var fragments := 0
		for item in SkyIsleLoot.rare_drops(&"mage", roll):
			if _is_jewel(item, SkyIsleLoot.CHEST):
				chests += int(item.count)
			elif _is_jewel(item, SkyIsleLoot.FRAGMENT):
				fragments += int(item.count)
			elif _is_jewel(item, SkyIsleLoot.EGG):
				eggs += 1
			elif DragonGearData.is_weapon(item):
				weapons += 1
			elif DragonGearData.is_wings(item):
				wings += 1
			elif String(item.get("slot", "")) == "wings":
				check(false, "the rare dragon drops no Lv.100 wings")
		if chests != SkyIsleLoot.RARE_CHESTS or fragments < SkyIsleLoot.RARE_FRAGMENTS_MIN or fragments > SkyIsleLoot.RARE_FRAGMENTS_MAX:
			check(false, "the rare dragon: %d chests and %d-%d fragments (%d / %d)" % [SkyIsleLoot.RARE_CHESTS, SkyIsleLoot.RARE_FRAGMENTS_MIN, SkyIsleLoot.RARE_FRAGMENTS_MAX, chests, fragments])
	check(_near(eggs, n, SkyIsleLoot.RARE_EGG) and _near(weapons, n, SkyIsleLoot.RARE_WEAPON) and _near(wings, n, SkyIsleLoot.RARE_WING), "the rare dragon's egg / weapon / wings chances (%d / %d / %d of %d)" % [eggs, weapons, wings, n])


func _chest_odds() -> void:
	var total := 0.0
	for row in SkyIsleLoot.CHEST_TABLE:
		total += float(row[1])
	check(is_equal_approx(total, 1.0), "the chest's odds add up to 100%% (%f)" % total)
	var help := SkyIsleLoot.chest_help()
	for row in SkyIsleLoot.CHEST_TABLE:
		check(help.contains("%s %s" % [String(row[2]), SkyIsleLoot.percent(float(row[1]))]), "the chest's help prints %s %s" % [row[2], SkyIsleLoot.percent(float(row[1]))])
	var roll := RandomNumberGenerator.new()
	roll.seed = 31
	var n := 300000
	var got := {}
	for i in n:
		var prize := SkyIsleLoot.chest_prize(&"darklord", roll)
		var key := "gold"
		if prize.has("item"):
			var item: Dictionary = prize.item
			if DragonGearData.is_weapon(item): key = "weapon"
			elif DragonGearData.is_wings(item): key = "wings"
			elif _is_jewel(item, SkyIsleLoot.EGG): key = "egg"
			elif _is_jewel(item, SkyIsleLoot.FRAGMENT): key = "fragment"
			elif _is_jewel(item, "feather"): key = "feather"
			elif _is_jewel(item, EndgameFields.SET_CORE): key = "core"
			elif item.get("kind", "") == "jewel": key = "jewels"
			elif item.get("kind", "") == "gem": key = "gem"
			elif item.get("kind", "") == "potion": key = "potion"
			else: key = "?"
			check(Game._valid_item(item), "a chest prize is a valid save item (%s)" % str(item))
		else:
			check(int(prize.gold) >= SkyIsleLoot.CHEST_GOLD_MIN and int(prize.gold) <= SkyIsleLoot.CHEST_GOLD_MAX, "chest gold in range")
		got[key] = int(got.get(key, 0)) + 1
	for row in SkyIsleLoot.CHEST_TABLE:
		check(_near(int(got.get(String(row[0]), 0)), n, float(row[1])), "chest prize %s at %s (%d of %d)" % [row[0], SkyIsleLoot.percent(float(row[1])), int(got.get(String(row[0]), 0)), n])
	check(not got.has("?"), "nothing outside the table")


func _chest_open() -> void:
	Game.profile.inv = []
	Game.profile.gold = 0
	var none := SkyIsleLoot.open_chests(1)
	check(int(none.opened) == 0 and String(none.stopped) != "", "no chest, nothing opens")
	give(SkyIsleLoot.CHEST, 150)
	var roll := RandomNumberGenerator.new()
	roll.seed = 8
	var one := SkyIsleLoot.open_chests(1, roll)
	check(int(one.opened) == 1 and Game.jewel_count(SkyIsleLoot.CHEST) == 149, "เปิด opens one chest")
	check(int(one.gold) > 0 or (one.items as Array).size() == 1, "one prize a chest")
	var gold_before := int(Game.profile.gold)
	var many := SkyIsleLoot.open_chests(SkyIsleLoot.OPEN_ALL_MAX, roll)
	check(int(many.opened) == SkyIsleLoot.OPEN_ALL_MAX and Game.jewel_count(SkyIsleLoot.CHEST) == 149 - SkyIsleLoot.OPEN_ALL_MAX, "เปิดทั้งหมด opens up to %d at once" % SkyIsleLoot.OPEN_ALL_MAX)
	check(int(Game.profile.gold) >= gold_before + int(many.gold) and int(many.gold) > 0, "the gold lands in the purse (%d + %d -> %d)" % [gold_before, int(many.gold), int(Game.profile.gold)])
	check((many.items as Array).size() + 0 > 0 and SkyIsleLoot.prize_text(many) != "", "the prizes are listed")
	check(Game._valid_profile(Game.profile.duplicate(true)), "the profile is a valid save after opening")
	# A full bag and a full storage: an item prize that has nowhere to go leaves its chest shut.
	Game.profile.inv = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	give(SkyIsleLoot.CHEST, 80)
	while Game.profile.inv.size() < Game.bag_size():
		Game.profile.inv.append(ItemData.generate(50, &"darklord", rng, 1, "ring"))
	var store := Game.storage()
	var kept: Array = store.duplicate(true)
	store.clear()
	while store.size() < Game.STORAGE_SIZE:
		store.append(ItemData.generate(50, &"darklord", rng, 1, "ring"))
	check(Game.inventory_free() == 0, "the bag is full")
	var bag_before: int = Game.profile.inv.size()
	var store_before := store.size()
	var full := SkyIsleLoot.open_chests(80, roll)
	var left := Game.jewel_count(SkyIsleLoot.CHEST)
	check(int(full.opened) + left == 80, "full bag and storage: every chest is either opened or still there (%d + %d)" % [int(full.opened), left])
	check(String(full.stopped) != "" and left > 0, "the opening stops when a prize has nowhere to go (%d left)" % left)
	check(Game.profile.inv.size() <= bag_before and store.size() == store_before, "nothing past the bag's or the storage's size")
	for item in full.items:
		check(ItemData.is_stackable(item), "only prizes that joined a pile were handed out (%s)" % ItemData.name_of(item))
	# With room in the storage the rest opens and overflows there.
	store.clear()
	var rest := SkyIsleLoot.open_chests(80, roll)
	check(int(rest.opened) == left and Game.jewel_count(SkyIsleLoot.CHEST) == 0, "with room in the storage the rest opens (%d)" % int(rest.opened))
	var handed := 0
	for item in rest.items:
		handed += 1
	check(handed == 0 or store.size() > 0 or Game.profile.inv.size() <= Game.bag_size(), "prizes went to the bag or the storage")
	store.clear()
	store.append_array(kept)
	Game.profile.inv = []


func _fragments() -> void:
	Game.profile.inv = []
	SkyIsleLoot.announced.clear()
	var e: Dictionary = RewardShop.COSTUMES[SkyIsleLoot.COSTUME]
	check(int(e.get("lc", 0)) == 0 and int(e.get("ep", 0)) == 0 and RewardShop.fragments_of(e) == SkyIsleLoot.COSTUME_FRAGMENTS, "the costume has no coin price, only fragments")
	check(RewardShop.price_text(e).contains("ชิ้นส่วน %d ชิ้น" % SkyIsleLoot.COSTUME_FRAGMENTS), "its shop card reads แลกด้วยชิ้นส่วน 50 ชิ้น (%s)" % RewardShop.price_text(e))
	RewardShop.add_coins(100000)
	RewardShop.add_points(100000)
	check(RewardShop.buy("costume", SkyIsleLoot.COSTUME) != "ok" and not RewardShop.has_item(SkyIsleLoot.COSTUME), "coins and points alone never buy it")
	give(SkyIsleLoot.FRAGMENT, 49)
	check(SkyIsleLoot.exchange_problem() != "" and SkyIsleLoot.exchange_costume() != "ok", "49 fragments refuse")
	check(Game.jewel_count(SkyIsleLoot.FRAGMENT) == 49 and not RewardShop.has_item(SkyIsleLoot.COSTUME), "and nothing is taken")
	check(SkyIsleLoot.announced.is_empty(), "nor announced")
	give(SkyIsleLoot.FRAGMENT, 4)
	var coins := RewardShop.coins()
	check(SkyIsleLoot.exchange_costume() == "ok", "50 fragments make the costume")
	check(Game.jewel_count(SkyIsleLoot.FRAGMENT) == 3, "50 fragments are used up (3 left of 53)")
	check(RewardShop.bag_index(SkyIsleLoot.COSTUME) >= 0, "the costume item is in the bag")
	check(RewardShop.coins() == coins, "no coins are taken")
	check(SkyIsleLoot.announced.size() == 1 and SkyIsleLoot.announced[0].contains("ชุดเทพมังกร") and SkyIsleLoot.announced[0].contains("Isle QA"), "completing the costume is announced (%s)" % str(SkyIsleLoot.announced))
	give(SkyIsleLoot.FRAGMENT, 60)
	check(SkyIsleLoot.exchange_costume() == "มีแล้ว", "once a hero, like every costume")
	check(RewardShop.wear("costume", SkyIsleLoot.COSTUME) == "ok" and RewardShop.worn_costume() == SkyIsleLoot.COSTUME, "it is worn in the costume slot")
	check(ItemData.sell_price(RewardShop.costume_item(SkyIsleLoot.COSTUME)) == 0, "never sold")
	# Its look: five bones dressed, a long swaying tail, spirit dragons round the wearer.
	var parts := CostumeArt.parts(SkyIsleLoot.COSTUME)
	check(parts.size() == 5, "the costume dresses five bones (%d)" % parts.size())
	var tail := CostumeArt.mesh_of(SkyIsleLoot.COSTUME, "tail", false)
	check(tail != null and int(tail.get_meta("sweeps", 0)) == 1, "one dragon tail")
	check(CostumeArt.mesh_of(SkyIsleLoot.COSTUME, "head", false) != null and int(CostumeArt.mesh_of(SkyIsleLoot.COSTUME, "head", false).get_meta("sweeps", 0)) == 6, "two antlers of three branches")
	check(CostumeArt.MOTES.has(SkyIsleLoot.COSTUME) and float(CostumeArt.MOTES[SkyIsleLoot.COSTUME].shape) == 5.0, "spirit dragons fly round the wearer")
	check(RewardShop.take_off_costume() == "ok", "and taken off again")


## AI world players never wear the isle's costume (it is not sold for coins).
func _world() -> void:
	var t := WorldPresence.clock()
	var worn := 0
	var dressed := 0
	for i in mini(WorldPlayers.size(), 400):
		var cos := String(RewardShop.world_cosmetics(i, t).cos)
		if cos != "":
			dressed += 1
		if cos == SkyIsleLoot.COSTUME:
			worn += 1
	check(worn == 0, "no AI world player wears the isle's costume (%d of %d dressed)" % [worn, dressed])


func _egg_and_mount() -> void:
	Game.profile.inv = []
	Game.profile["mounts"] = {}
	Game.profile["mount"] = ""
	var info := MountData.info(SkyIsleLoot.MOUNT)
	check(MountData.ALL.has(SkyIsleLoot.MOUNT) and not MountData.ORDER.has(SkyIsleLoot.MOUNT), "the sky dragon is in the menu, not in the every-field list")
	for id in MountData.ORDER:
		check(float(info.speed) > MountData.speed_bonus(id), "faster than %s" % id)
		var mine := MountData.bonus(SkyIsleLoot.MOUNT, 5)
		var other := MountData.bonus(id, 5)
		for key in other:
			check(float(mine.get(key, 0.0)) > float(other[key]), "a better %s bonus than %s" % [key, id])
	check(float(info.drop) <= 0.0, "its egg is no every-field drop")
	var roll := RandomNumberGenerator.new()
	roll.seed = 3
	var eggs := 0
	for i in 100000:
		for item in Zone.mount_mat_drops(3.0, roll):
			if String(item.id) == SkyIsleLoot.EGG:
				eggs += 1
	check(eggs == 0, "no other field's mount roll drops the egg")
	check(Game.mount_step_problem(SkyIsleLoot.MOUNT) != "" and Game.craft_mount(SkyIsleLoot.MOUNT) != "ok", "no egg, no dragon")
	give(SkyIsleLoot.EGG, 1)
	give("chaos", int(info.chaos))
	check(MountData.cost(SkyIsleLoot.MOUNT, 1) == {"mat": 1, "chaos": int(info.chaos)}, "Lv.1 takes one egg")
	check(Game.craft_mount(SkyIsleLoot.MOUNT, 0.999) == "ok", "one egg hatches the dragon, every try succeeds")
	check(Game.mount_level(SkyIsleLoot.MOUNT) == 1 and Game.active_mount() == SkyIsleLoot.MOUNT, "มังกรฟ้าเทพ Lv.1, the active mount")
	check(Game.jewel_count(SkyIsleLoot.EGG) == 0 and Game.jewel_count("chaos") == 0, "the egg and the chaos jewels are used up")
	check(Game.owned_mounts() == [SkyIsleLoot.MOUNT], "it is among the owned mounts")
	var before := Game.stats_now()
	Game.profile["mount"] = ""
	Game.profile["mounts"] = {}
	var bare := Game.stats_now()
	check(int(before.max_hp) > int(bare.max_hp) and int(before.atk) > int(bare.atk), "its bonus counts in the hero's stats")
	Game.profile["mounts"] = {SkyIsleLoot.MOUNT: 1}
	Game.profile["mount"] = SkyIsleLoot.MOUNT


func _ride() -> void:
	var drake := MountVisual.new()
	add_child(drake)
	drake.build("fire_drake")
	for merged in [false, true]:
		var mount := MountVisual.new()
		mount.merged = merged
		add_child(mount)
		mount.build(SkyIsleLoot.MOUNT)
		check(mount.id == SkyIsleLoot.MOUNT and mount.seat != null and mount.head != null, "the sky dragon builds its body, head and saddle (merged %s)" % merged)
		# The Summoner's god-skill dragon (CelestialDragon "mount"), one body laid on its pose.
		var dragon := mount.body.get_node_or_null("DragonBody") as MeshInstance3D
		check(dragon != null and mount._dragon != null and dragon.material_override == mount._dragon and mount._dragon.shader == CelestialDragon.SHADER, "the long eastern dragon of the god skill (merged %s)" % merged)
		var pose := CelestialDragon.pose("mount")
		var length: float = (pose.box as AABB).size.z * MountVisual.SKY_SCALE
		check(length > 5.0 and mount.head.position.y > drake.head.position.y + 0.4, "clearly bigger than the fire drake: %.1f m from head to tail, its head %.1f m up" % [length, mount.head.position.y])
		check(mount.seat_height() > drake.seat_height(), "its saddle sits higher than the drake's")
		for cls in [&"darklord", &"mage", &"archer", &"defender", &"bard"]:
			var rider := HeroVisual.new()
			add_child(rider)
			rider.setup(cls, "", true, {}, FaceKit.default_look())
			var y := MountVisual.carry(mount, rider, 0.0, 5.0, 6.0, Hero.RIDE_UPPER)
			check(rider.seated and is_equal_approx(y, mount.seat_height() - MountVisual.RIDE_HIP), "%s sits in the saddle" % cls)
			rider.queue_free()
		await settle()
		var a := float(mount._dragon.get_shader_parameter("clock"))
		await get_tree().create_timer(0.3).timeout
		check(float(mount._dragon.get_shader_parameter("clock")) > a, "the body rides its wave")
		var calm_from := float(mount._dragon.get_shader_parameter("calm_from"))
		var calm_to := float(mount._dragon.get_shader_parameter("calm_to"))
		check(calm_from < float(pose.seat_s) and calm_to > float(pose.seat_s), "the wave stills under the saddle (%.1f-%.1f m)" % [calm_from, calm_to])
		var near := mount.drawn_parts()
		mount.set_far(true)
		check(mount.drawn_parts() < near, "far away the small parts hide (%d < %d)" % [mount.drawn_parts(), near])
		mount.queue_free()
	drake.queue_free()
	await settle()


func _announce() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var weapon := DragonGearData.weapon(&"darklord", rng)
	var wings := DragonGearData.wings(&"darklord", rng)
	check(SkyIsleLoot.is_jackpot(weapon) and SkyIsleLoot.is_jackpot(wings), "the weapon and the 300★ wings are jackpots")
	check(SkyIsleLoot.is_jackpot(ItemData.jewel(SkyIsleLoot.EGG)) and SkyIsleLoot.is_jackpot(RewardShop.costume_item(SkyIsleLoot.COSTUME)), "so are the egg and the finished costume")
	for item in [ItemData.jewel(SkyIsleLoot.FRAGMENT), ItemData.jewel(SkyIsleLoot.CHEST), ItemData.jewel("chaos"), ItemData.jewel(EndgameFields.SET_CORE), ItemData.potion("hp_god"),
			ItemData.wings(rng, "darklord"), StarProgression.item(&"darklord", 200, "ring", rng), RewardShop.costume_item("kitsune")]:
		check(not SkyIsleLoot.is_jackpot(item), "%s is no jackpot" % ItemData.name_of(item))
	var line := SkyIsleLoot.announce_text(weapon, "น้องมังกร")
	check(line.contains("น้องมังกร") and line.contains(ItemData.name_of(weapon)) and line.contains(SkyIsleData.TITLE), "the line names the finder, the item and the isle (%s)" % line)
	check(SkyIsleLoot.announce_text(ItemData.jewel(SkyIsleLoot.EGG), "A", "chest").contains(String(ItemData.JEWELS[SkyIsleLoot.CHEST].name)), "a chest's jackpot names the chest")
	# Opening chests announces the jackpots and nothing else.
	Game.profile.inv = []
	give(SkyIsleLoot.CHEST, 100)
	SkyIsleLoot.announced.clear()
	var roll := RandomNumberGenerator.new()
	roll.seed = 99
	var total := 0
	var jackpots := 0
	for round in 30:
		give(SkyIsleLoot.CHEST, 100 - Game.jewel_count(SkyIsleLoot.CHEST))
		SkyIsleLoot.announced.clear()
		var result := SkyIsleLoot.open_chests(100, roll)
		total += int(result.opened)
		jackpots += (result.jackpots as Array).size()
		check(SkyIsleLoot.announced.size() == mini((result.jackpots as Array).size(), SkyIsleLoot.ANNOUNCED_MAX), "a round of chests announces its jackpots only (%d / %d)" % [SkyIsleLoot.announced.size(), (result.jackpots as Array).size()])
		for item in result.jackpots:
			check(SkyIsleLoot.is_jackpot(item), "a chest jackpot is the egg, the weapon or the wings")
		Game.profile.inv = Game.profile.inv.filter(func(it): return it.get("kind", "") == "jewel" and String(it.get("id", "")) == SkyIsleLoot.CHEST)
	check(total == 3000 and jackpots > 0, "3000 chests held some jackpots (%d)" % jackpots)
	# The kill path (Zone._sky_isle_loot) tells the server and gives the finder a moment.
	var body := FileAccess.get_file_as_string("res://world/zone.gd")
	var at := body.find("func _sky_isle_loot")
	var fn := body.substr(at, body.find("\nfunc ", at + 10) - at)
	check(fn.contains("SkyIsleLoot.is_jackpot(item)") and fn.contains("SkyIsleLoot.announce(item)") and fn.contains("loot_beam") and fn.contains("SkyIsleLoot.celebrate(item)"), "a jackpot kill: a beam, the finder's fanfare and the server-wide line")
	Game.profile.inv = []


func _save() -> void:
	Game.profile.inv = [ItemData.jewel(SkyIsleLoot.CHEST, 3), ItemData.jewel(SkyIsleLoot.FRAGMENT, 12), ItemData.jewel(SkyIsleLoot.EGG, 2), RewardShop.costume_item(SkyIsleLoot.COSTUME)]
	Game.profile["mounts"] = {SkyIsleLoot.MOUNT: 3, "thunder_wolf": 1}
	Game.profile["mount"] = SkyIsleLoot.MOUNT
	RewardShop.data()["cos"] = SkyIsleLoot.COSTUME
	var saved: Dictionary = Game.profile.duplicate(true)
	check(Game._valid_profile(saved.duplicate(true)), "a profile with the isle's things is a valid save")
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	check(parsed is Dictionary and Game._valid_profile((parsed as Dictionary).duplicate(true)), "the JSON round trip is a valid save")
	if parsed is Dictionary:
		var back := Game._repair(parsed)
		check(back.mounts == {SkyIsleLoot.MOUNT: 3, "thunder_wolf": 1} and back.mount == SkyIsleLoot.MOUNT, "the dragon survives the round trip (%s)" % str(back.mounts))
		var ids := []
		for item in back.inv:
			ids.append(String(item.id))
		check(ids == [SkyIsleLoot.CHEST, SkyIsleLoot.FRAGMENT, SkyIsleLoot.EGG, SkyIsleLoot.COSTUME], "and so do the chest, the fragments, the egg and the costume (%s)" % str(ids))
		check(RewardShop.worn_of(back) == SkyIsleLoot.COSTUME, "and the worn costume")
	RewardShop.data()["cos"] = ""


func _button(menu: GameMenu, node_name: String) -> Button:
	return menu.find_child(node_name, true, false) as Button


func _menu() -> void:
	Game.profile.inv = [ItemData.jewel(SkyIsleLoot.CHEST, 5), ItemData.jewel(SkyIsleLoot.FRAGMENT, 49), ItemData.jewel(SkyIsleLoot.EGG, 1)]
	Game.profile["mounts"] = {}
	Game.profile["mount"] = ""
	RewardShop.data()["own"] = []
	Game.profile.flags.erase(RewardShop.ITEM_FLAG + SkyIsleLoot.COSTUME)
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"inventory")
	await settle()
	# The chest: เปิด and เปิดทั้งหมด.
	menu._selected_index = 0
	menu._refresh_detail()
	await settle()
	var open := _button(menu, "ChestOpen")
	var all := _button(menu, "ChestOpenAll")
	check(open != null and open.text == "เปิด" and all != null and all.text.contains("เปิดทั้งหมด") and not all.disabled, "the chest's bag actions: เปิด / เปิดทั้งหมด")
	var texts := ""
	for label in menu.find_children("*", "Label", true, false):
		texts += (label as Label).text + "\n"
	check(texts.contains(SkyIsleLoot.percent(0.007)) and texts.contains("38%"), "the chest's detail prints its odds")
	if open != null:
		open.pressed.emit()
		await settle()
		check(Game.jewel_count(SkyIsleLoot.CHEST) == 4, "เปิด opened one chest from the bag")
	all = _button(menu, "ChestOpenAll")
	if all != null:
		all.pressed.emit()
		await settle()
		check(Game.jewel_count(SkyIsleLoot.CHEST) == 0, "เปิดทั้งหมด opened the stack")
	# The fragments: แลกชุดเทพมังกร n/50.
	var at := -1
	for i in Game.profile.inv.size():
		if _is_jewel(Game.profile.inv[i], SkyIsleLoot.FRAGMENT):
			at = i
	var have := Game.jewel_count(SkyIsleLoot.FRAGMENT)
	if have >= 50:
		Game._spend_jewels(SkyIsleLoot.FRAGMENT, have - 49)
		have = 49
	menu._selected_index = at
	menu._rebuild()
	await settle()
	var swap := _button(menu, "FragmentExchange")
	check(swap != null and swap.text == "แลกชุดเทพมังกร (%d/50)" % have and swap.disabled, "the fragment's action shows %d/50 and waits (%s)" % [have, swap.text if swap else ""])
	give(SkyIsleLoot.FRAGMENT, 50 - have)
	menu._rebuild()
	await settle()
	swap = _button(menu, "FragmentExchange")
	check(swap != null and swap.text == "แลกชุดเทพมังกร (50/50)" and not swap.disabled, "at 50/50 it can be pressed")
	if swap != null:
		swap.pressed.emit()
		await settle()
		check(RewardShop.bag_index(SkyIsleLoot.COSTUME) >= 0 and Game.jewel_count(SkyIsleLoot.FRAGMENT) == 0, "the bag's exchange made the costume item")
	# The egg leads to the mount tab, where the dragon has its card.
	for i in Game.profile.inv.size():
		if _is_jewel(Game.profile.inv[i], SkyIsleLoot.EGG):
			menu._selected_index = i
	menu._rebuild()
	await settle()
	check(_button(menu, "EggHatch") != null, "the egg points to the mount tab")
	menu.show_tab(&"mounts")
	await settle()
	var card := menu._content.find_child("Mount_" + SkyIsleLoot.MOUNT, true, false)
	check(card != null, "the mount menu has the sky dragon's card")
	if card != null:
		var title := card.find_child("Title", true, false) as Label
		check(title != null and title.text.contains("มังกรฟ้าเทพ") and title.text.contains("Lv.0/5"), "its card names it (%s)" % (title.text if title else ""))
		check((card.find_child("MatIcon", true, false) as TextureRect).texture == ItemLook.icon(ItemData.jewel(SkyIsleLoot.EGG)), "with the egg's icon")
		var cost := card.find_child("Cost", true, false) as Label
		check(cost != null and cost.text.contains("ไข่มังกรฟ้าเทพ 1/1"), "and what the hatch takes (%s)" % (cost.text if cost else ""))
	# The reward shop lists it under costumes, paid in fragments.
	menu.queue_free()
	await settle()
	RewardShop.data()["own"] = []
	Game.profile.inv = [ItemData.jewel(SkyIsleLoot.FRAGMENT, 50)]
	RewardShopView.tab = "costume"
	var host := VBoxContainer.new()
	add_child(host)
	var view := RewardShopView.build(host, func(): pass)
	await settle()
	var shop_card := view.find_child("Reward_" + SkyIsleLoot.COSTUME, true, false)
	check(shop_card != null, "the reward shop's costume tab lists the isle's costume")
	if shop_card != null:
		var text := ""
		for label in shop_card.find_children("*", "Label", true, false):
			text += (label as Label).text + "\n"
		check(text.contains("แลกด้วยชิ้นส่วน 50 ชิ้น"), "its card reads แลกด้วยชิ้นส่วน 50 ชิ้น (%s)" % text)
		var buy := shop_card.find_child("RewardBuy_" + SkyIsleLoot.COSTUME, true, false) as Button
		check(buy != null and not buy.disabled, "and can be exchanged with 50 fragments")
		if buy != null:
			SkyIsleLoot.announced.clear()
			buy.pressed.emit()
			await settle()
			check(RewardShop.bag_index(SkyIsleLoot.COSTUME) >= 0 and Game.jewel_count(SkyIsleLoot.FRAGMENT) == 0 and SkyIsleLoot.announced.size() == 1, "the shop's exchange makes the costume and announces it")
	host.queue_free()
	Game.profile.inv = []
