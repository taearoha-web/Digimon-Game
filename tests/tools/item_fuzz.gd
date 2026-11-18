extends Node
## Every kind of item the game makes for a ★300 hero (drops, star / divine / set / Dragon
## God gear, sky isle chests and rare drops, weekly collection and Loy Krathong rewards,
## legend wings, costumes, stones) that the game's own save check accepts, written as JSON
## for a differential check against the account server (hosting/accounts validateBundle):
##
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/tools/item_fuzz.tscn -- OUT.json
##
## (2026-11-18: 7718 items, none refused by the server in a bag, worn, on a stall or in
## the shared storage.)

var items: Array = []
var refused := 0


func _add(item: Variant, src: String) -> void:
	if not item is Dictionary or (item as Dictionary).is_empty():
		return
	var parsed: Variant = JSON.parse_string(JSON.stringify(item))
	if Game._valid_item(parsed):
		items.append({"src": src, "item": parsed})
	else:
		refused += 1


func _ready() -> void:
	Game.set_process(false)
	var out_path := OS.get_cmdline_user_args()[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	Game.slot = 1
	Game.new_profile(&"warrior", "fuzz", FaceKit.default_look())
	Game.profile.level = Game.MAX_LEVEL
	Game.profile.paragon = {"level": 300, "exp": 0, "points": 300, "spent": 0, "alloc": {}}
	for cls in ClassData.IDS:
		for slot in ["weapon", "armor", "helm", "boots", "ring", "amulet", "wings"]:
			if slot != "wings":
				for r in 5:
					_add(ItemData.generate(rng.randi_range(1, 100), cls, rng, r, slot), "generate")
			_add(StarProgression.item(cls, 300, slot, rng), "star")
			_add(StarProgression.item(cls, 100, slot, rng), "star100")
			_add(DivineGearData.item(cls, slot, rng), "divine")
			_add(SetGearData.item(String(cls), slot), "set")
		_add(StarWingData.item(String(cls), rng), "starwing")
		for i in 20:
			for it in SkyIsleLoot.rare_drops(cls, rng):
				_add(it, "isle_rare")
			for it in SkyIsleLoot.kill_drops(cls, true, true, 5.0, rng):
				_add(it, "isle_kill")
			for it in SkyIsleLoot.poseidon_drops(cls, true, true, 5.0, rng):
				_add(it, "poseidon")
			_add(SkyIsleLoot.chest_prize(cls, rng).get("item"), "chest")
			for it in DivineGearData.drops(cls, true, true, rng):
				_add(it, "divine_drop")
		for tier in 6:
			for o in WeeklyCollect.OPTIONS:
				for it in WeeklyCollect.rewards(String(o.id), tier, String(cls)).get("items", []):
					_add(it, "wcol_reward")
			for k in 4:
				for it in LoyKrathong.rewards(k, tier, String(cls)).get("items", []):
					_add(it, "lk_reward")
		for i in 10:
			for it in LoyKrathong.rare_roll(rng).get("items", []):
				_add(it, "lk_rare")
	for w in [2967, 2970, 2980]:
		for g in range(1, 5):
			_add(LegendWings.item(w, g), "legend")
	for id in RewardShop.COSTUMES:
		_add(RewardShop.costume_item(id), "costume")
	for e in RewardShop.STONES:
		_add(RewardShop.stone_item(e), "stone")
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(items))
	f.close()
	print("ITEMS: %d valid, %d refused by the game -> %s" % [items.size(), refused, out_path])
	get_tree().quit(0)
