extends Node
## Owner tool used by .github/workflows/boost-character.yml: raises one named
## character in a saved account bundle to Lv.100 / ★200 and dresses it in the
## best gear of its class (divine set, star ring and amulet, mythic star wings),
## every piece at +10. Runs the game's own levelling code, so stat points, skill
## points, ★ milestones and gold rewards are the ones the hero would earn.
##
##   godot --headless --path . res://tools/boost_character.tscn -- \
##     --in bundle.json --out boosted.json --name Assotix [--class defender]
##
## Writes {slot, profile} for the boosted character only.
##
## Gear it replaces moves to the bag (or storage); nothing is deleted.

const BEST_SLOTS := ["weapon", "armor", "helm", "boots"]
const STAR_SLOTS := ["ring", "amulet"]


func _ready() -> void:
	Game.set_process(false)
	get_tree().quit(_run())


func _arg(name: String) -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--" + name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else ""


func _fail(message: String) -> int:
	printerr("BOOST: ", message)
	return 1


func _run() -> int:
	var source := _arg("in")
	var target := _arg("out")
	var wanted := _arg("name").strip_edges()
	var cls := _arg("class").strip_edges().to_lower()
	if source == "" or target == "" or wanted == "":
		return _fail("usage: -- --in bundle.json --out boosted.json --name <character> [--class <class>]")
	var text := FileAccess.get_file_as_string(source)
	var bundle: Variant = JSON.parse_string(text)
	if not bundle is Dictionary or not bundle.get("slots") is Dictionary:
		return _fail("the input is not a save bundle")
	var result := boost_bundle(bundle, wanted, cls)
	if result.has("error"):
		return _fail(String(result.error))
	var out := FileAccess.open(target, FileAccess.WRITE)
	if out == null:
		return _fail("cannot write " + target)
	# Only the boosted slot: the other characters stay byte-for-byte as saved.
	out.store_string(JSON.stringify({"slot": result.slot, "profile": bundle.slots[result.slot]}))
	out.close()
	var hero: Dictionary = bundle.slots[result.slot]
	print("BOOST: slot %s %s (%s): %s -> Lv.%d ★%d, stat points %d, skill points %d, star points %d" % [
		result.slot, hero.name, hero["class"], result.before, int(hero.level),
		int(hero.paragon.level), int(hero.points), int(hero.skill_points), int(hero.paragon.points)])
	for key in ItemData.EQUIP_SLOTS:
		var piece: Dictionary = hero.equip.get(key, {})
		print("BOOST:   %s: %s +%d" % [key, ItemData.name_of(piece), int(piece.get("plus", 0))])
	return 0


## Boosts the one character named [param wanted] (and of class [param cls] when
## given) inside [param bundle], in place. Returns {slot, before} or {error}.
## A starter-class (vagabond) hero of that name also matches: it takes the class
## through the game's own class change, as it would at the class trainer.
static func boost_bundle(bundle: Dictionary, wanted: String, cls := "") -> Dictionary:
	if not bundle.get("slots") is Dictionary:
		return {"error": "the input is not a save bundle"}
	var found: Array[String] = []
	for key in bundle.slots:
		var hero: Variant = bundle.slots[key]
		if hero is Dictionary and String(hero.get("name", "")).strip_edges().to_lower() == wanted.strip_edges().to_lower():
			var has := String(hero.get("class", ""))
			if cls == "" or has == cls or (has == String(ClassData.START) and ClassData.IDS.has(StringName(cls))):
				found.append(String(key))
	if found.size() != 1:
		return {"error": "expected exactly one character named %s%s, found %d" % [wanted, "" if cls == "" else " (" + cls + ")", found.size()]}
	var slot_key := found[0]
	var raw: Dictionary = bundle.slots[slot_key]
	if not Game._valid_profile(raw):
		return {"error": "the saved character does not pass the game's save check"}
	var keep := [Game.profile, Game.has_profile]
	Game.profile = Game._repair(raw.duplicate(true))
	Game.has_profile = true
	var before := "Lv.%d ★%d" % [int(Game.profile.level), int(Game.paragon().level)]
	_level_up()
	if cls != "" and Game.class_id() != StringName(cls) and not Game.change_class(StringName(cls)):
		Game.profile = keep[0]
		Game.has_profile = keep[1]
		return {"error": "could not change the class to " + cls}
	_dress()
	var stats := Game.stats_now()
	Game.profile["hp"] = int(stats.max_hp)
	Game.profile["mp"] = int(stats.max_mp)
	var boosted: Dictionary = Game.profile
	Game.profile = keep[0]
	Game.has_profile = keep[1]
	if not Game._valid_profile(boosted):
		return {"error": "the boosted character does not pass the game's save check"}
	bundle.slots[slot_key] = boosted
	return {"slot": slot_key, "before": before}


static func _level_up() -> void:
	var guard := 0
	while int(Game.profile.level) < Game.MAX_LEVEL and guard < 200:
		Game.add_exp(maxi(1, HeroStats.exp_to_next(int(Game.profile.level)) - int(Game.profile.exp)))
		guard += 1
	while int(Game.paragon().level) < Game.PARAGON_MAX and guard < 600:
		Game.add_exp(maxi(1, Game.paragon_need() - int(Game.paragon().exp)))
		guard += 1


static func _dress() -> void:
	var cls := StringName(Game.profile["class"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(Game.profile.name) + String(cls) + "-boost")
	var gear := {}
	for key in BEST_SLOTS:
		gear[key] = DivineGearData.item(cls, key, rng)
	for key in STAR_SLOTS:
		# The mythic grade of the 200-star piece: the best one that can drop.
		var piece := StarProgression.item(cls, StarProgression.TIERS[-1], key, rng)
		for attempt in 400:
			if int(piece.get("rarity", 0)) >= StarProgression.MYTHIC_RARITY:
				break
			piece = StarProgression.item(cls, StarProgression.TIERS[-1], key, rng)
		gear[key] = piece
	gear["wings"] = StarWingData.item(String(cls), rng, 4)
	for key in gear:
		var piece: Dictionary = gear[key]
		assert(not piece.is_empty(), "no %s for %s" % [key, cls])
		piece["plus"] = ItemData.MAX_PLUS
		var old: Variant = Game.profile.equip.get(key)
		if old is Dictionary and not old.is_empty():
			if not Game.add_item(old):
				var vault := Game.storage()
				if vault.size() < Game.STORAGE_SIZE:
					vault.append(old)
		Game.profile.equip[key] = piece
	Game.clamp_vitals()
