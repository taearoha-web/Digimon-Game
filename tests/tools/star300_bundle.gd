extends Node
## A full late-game account (ten Lv.100 ★300 God heroes with full bags, Dragon God gear
## worn at +15, sky isle chests / fragments / eggs, the sky dragon mount, costumes as
## items and worn, the weekly collection and Loy Krathong records and stacks, the dragon
## hunt, a legend wings pair, stall lots...) as the exact cloud bundle the game uploads
## (Game.cloud_bundle_json), written to OUT_FILE for the account server's validateBundle:
##
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/tools/star300_bundle.tscn -- OUT.json
##
## (2026-11-18: ~132 kB, ~10,500 JSON nodes, accepted by the server.)

var failures := 0


func _fail(m: String) -> void:
	failures += 1
	printerr("FAIL: ", m)


func _level_to(level: int) -> void:
	var guard := 0
	while int(Game.profile.level) < level and guard < 400:
		Game.add_exp(maxi(1, HeroStats.exp_to_next(int(Game.profile.level)) - int(Game.profile.exp)))
		guard += 1


func _stars_to(stars: int) -> void:
	var guard := 0
	while int(Game.paragon().level) < stars and guard < 600:
		Game.add_exp(maxi(1, Game.paragon_need() - int(Game.paragon().exp)))
		guard += 1


func _ready() -> void:
	Game.set_process(false)
	Game.rng.seed = 300
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if args.size() > 0 else "user://bundle.json"
	var classes := ["warrior", "archer", "mage", "priest", "summoner", "lancer", "defender", "assassin", "darklord", "bard"]
	for i in classes.size():
		_build(StringName(classes[i]), i + 1)
	Game.load_game(1)
	var text := Game.cloud_bundle_json()
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	for i in range(1, 11):
		var raw: Variant = Game._read_slot_json(i)
		if raw is Dictionary and not Game._valid_profile(raw):
			_fail("slot %d refused by the game: %s" % [i, str(Game.profile_problems(raw))])
	print("BUNDLE: %d bytes, %d failures -> %s" % [text.length(), failures, out_path])
	get_tree().quit(0)


func _build(cls: StringName, slot: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = slot * 77
	Game.slot = slot
	Game.new_profile(cls, "ซอนย่า%d" % slot, FaceKit.random_look(rng))
	Game.slot = slot
	Game.playing = true
	Game.current_zone = &"town"
	_level_to(Game.MAX_LEVEL)
	_stars_to(Game.PARAGON_MAX)
	for i in JobData.MAX_ADV:
		if Game.next_step().is_empty():
			break
		Game.add_gold(Game.next_step_cost())
		Game.advance()
	if not Game.is_god():
		_fail("%s: not God (%s)" % [cls, Game.advance_problem()])
	for k in ["atk", "def", "hp", "crit", "haste"]:
		Game.paragon_spend(k, 60)
	while Game.expand_bag():
		Game.add_gold(100000000)
	Game.add_gold(500000000)
	# Dragon God gear worn, +15, gems.
	var w := DragonGearData.weapon(cls, rng)
	var wings := DragonGearData.wings(cls, rng)
	for piece in [w, wings]:
		if Game.add_item(piece):
			Game.equip_from_bag(Game.profile.inv.find(piece))
	Game.add_item(ItemData.jewel("purple", 999))
	Game.add_item(ItemData.jewel("pink", 999))
	Game.add_item(ItemData.jewel("chaos", 999))
	for i in 60:
		Game.enhance_item(Game.profile.equip.weapon)
		Game.enhance_item(Game.profile.equip.wings)
	print(cls, " weapon +", Game.profile.equip.weapon.get("plus"), " wings +", Game.profile.equip.wings.get("plus"))
	# Spare dragon gear in the bag, chests, fragments, eggs.
	Game.add_item(DragonGearData.weapon(cls, rng))
	Game.add_item(DragonGearData.wings(cls, rng))
	Game.add_item(ItemData.jewel(SkyIsleLoot.CHEST, 40))
	Game.add_item(ItemData.jewel(SkyIsleLoot.FRAGMENT, 60))
	Game.add_item(ItemData.jewel(SkyIsleLoot.EGG, 3))
	print(cls, " chests: ", SkyIsleLoot.prize_text(SkyIsleLoot.open_chests(20, rng)))
	print(cls, " dragon costume: ", SkyIsleLoot.exchange_costume())
	print(cls, " sky dragon: ", Game.craft_mount(SkyIsleLoot.MOUNT, 0.0), " ", Game.select_mount(SkyIsleLoot.MOUNT))
	# Reward shop: costumes, trails, colours, stones.
	RewardShop.add_coins(100000)
	RewardShop.add_points(100000)
	for id in ["sakura", "midnight", "kitsune", "seafoam", "royal", "shadow", "celestial"]:
		RewardShop.buy("costume", id)
	for id in RewardShop.TRAILS:
		RewardShop.buy("trail", id)
	for id in RewardShop.NAME_COLORS:
		RewardShop.buy("ncol", id)
	for e in RewardShop.STONES:
		RewardShop.buy("stone", String(e.id))
	RewardShop.wear("trail", "flame")
	RewardShop.wear("ncol", "aurora")
	print(cls, " wear costume: ", RewardShop.wear_from_bag(RewardShop.bag_index("dragon_god")))
	# Weekly collection: record, pieces, exchanges.
	var t := float(WeeklyCollect.START) + 7200.0
	WeeklyCollect.data(t)
	for th in WeeklyCollect.THEMES.size():
		for k in WeeklyCollect.PIECES:
			Game.add_item(WeeklyCollect.piece(th, k, 7))
	var th_now := WeeklyCollect.theme_index(WeeklyCollect.week_of(t))
	for k in WeeklyCollect.PIECES:
		WeeklyCollect.picked(WeeklyCollect.piece(th_now, k, 5))
	for o in WeeklyCollect.OPTIONS:
		print(cls, " wcol ", o.id, ": ", WeeklyCollect.exchange(String(o.id), t))
	# Loy Krathong: record and stacks, krathongs, the costume.
	var lk_t := float(LoyKrathong.START) + 3600.0 * 20.0
	LoyKrathong.data()
	for k in LoyKrathong.MATS.size():
		Game.add_item(LoyKrathong.mat(k, 30))
	for k in 4:
		print(cls, " krathong ", k, ": ", LoyKrathong.craft(k, lk_t))
	Game.add_item(ItemData.jewel(LoyKrathong.PIECE, 40))
	LoyKrathong.add_points(5000)
	print(cls, " lk costume: ", LoyKrathong.exchange_costume("pieces", lk_t))
	# Dragon hunt.
	DragonHunt.state(float(DragonHunt.START) + 3600.0)
	DragonHunt.add_points(3000, "test", float(DragonHunt.START) + 3600.0)
	DragonHunt.claim_all(float(DragonHunt.START) + 3600.0)
	# Guild, league, legend wings record, leaders.
	Game.join_guild(WorldPlayers.ALPHA)
	LegendWings.record()
	if slot == 1:
		LegendWings.give_to_hero(LegendWings.item(LegendWings.FROM_WEEK, WorldPlayers.ALPHA))
	# Stall lots.
	for piece: Dictionary in [ItemData.generate(90, cls, rng, 3, "weapon"), DragonGearData.wings(cls, rng)]:
		if Game.add_item(piece):
			PlayerStall.list_item(Game.profile.inv.find(piece), PlayerStall.fair_price(piece), 0)
	# Fill the bag with drops.
	var guard := 0
	while Game.profile.inv.size() < int(Game.profile.bag_slots) and guard < 200:
		Game.add_item(ItemData.generate(rng.randi_range(80, 100), cls, rng, rng.randi_range(0, 4)))
		guard += 1
	for i in 30:
		Game.report_kill(&"wild_chicken")
	Game.daily_progress("kills", 100000)
	Game.daily_claim_all()
	Game.tower_floor_cleared(60)
	Game.guildwar_save_checkpoint(123, 412.6, false, [3, 1], 4, 1)
	Game.guildwar_finish(true, 5, 2, 6, 1, "Alpha", "Titan")
	if not Game.save():
		_fail("%s: save failed" % cls)
