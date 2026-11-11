extends Node
## Owner tool used by .github/workflows/boost-character.yml: raises one named
## character in a saved account bundle to Lv.100 / ★200 (BOOST_STARS; the cap is
## ★300 now, the last hundred are left to play), takes every job advancement it
## can at ★200 (Lv.20-80, fees waived; not the ★300 God step) and dresses it in the best gear of its class (divine
## set, star ring and amulet, mythic star wings), every piece at +10 (the ring and
## amulet at --accessory-plus). Runs the game's own levelling code, so stat
## points, skill points, ★ milestones and gold rewards are the ones the hero
## would earn. With --create, a name no character has yet becomes a new hero in
## the first free slot (made as a Vagabond, then given --class the game's way).
##
##   godot --headless --path . res://tools/boost_character.tscn -- \
##     --in bundle.json --out boosted.json --name Assotix [--class defender] [--create] [--accessory-plus 0] \
##     [--stars 300] [--mount fire_drake --mount-level 5] [--gear set250]
##
## --gear set250 dresses the hero in its class's 250-star set (SetGearData, all six
## pieces, the ring and amulet at --accessory-plus) instead of the divine set and
## 200-star ring and amulet; it needs ★250 (--stars 250 or more).
##
## --stars raises the stars past BOOST_STARS up to Game.PARAGON_MAX (★300 also takes the God
## step). --mount gives that mount (MountData) at --mount-level (1-MountData.MAX_LEVEL) and
## makes it the active one; a mount the hero already has at a higher level keeps it.
##
## Writes {slot, profile, created} for the boosted character only, plus "storage"
## (the bundle's shared storage, SharedStorage) when replaced gear had to go there.
##
## Gear it replaces moves to the bag (or the shared storage); nothing is deleted.

const BEST_SLOTS := ["weapon", "armor", "helm", "boots"]
## Stars the boost gives (below Game.PARAGON_MAX = 300 on purpose).
const BOOST_STARS := 200
const STAR_SLOTS := ["ring", "amulet"]
## The longest name the character creator accepts (ui/class_select.gd).
const NAME_MAX := 14

## The bundle's shared storage while a boost runs (replaced gear past a full bag).
static var _vault: Array = []
static var _vault_used := false


func _ready() -> void:
	Game.set_process(false)
	get_tree().quit(_run())


func _flag(name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + name)


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
	var accessory_plus := ItemData.MAX_PLUS
	if _arg("accessory-plus") != "":
		if not _arg("accessory-plus").is_valid_int() or not int(_arg("accessory-plus")) in range(0, ItemData.MAX_PLUS + 1):
			return _fail("--accessory-plus must be 0 to %d" % ItemData.MAX_PLUS)
		accessory_plus = int(_arg("accessory-plus"))
	var stars := BOOST_STARS
	if _arg("stars") != "":
		if not _arg("stars").is_valid_int() or not int(_arg("stars")) in range(0, Game.PARAGON_MAX + 1):
			return _fail("--stars must be 0 to %d" % Game.PARAGON_MAX)
		stars = int(_arg("stars"))
	var mount := _arg("mount").strip_edges()
	var mount_level := MountData.MAX_LEVEL
	if mount == "none":
		mount = ""
	if mount != "" and not MountData.exists(mount):
		return _fail("--mount must be one of %s" % ", ".join(MountData.ORDER))
	var gear := _arg("gear").strip_edges()
	if gear == "":
		gear = "divine"
	if not gear in ["divine", "set250", "keep"]:
		return _fail("--gear must be divine, set250 or keep")
	if gear == "set250" and stars < SetGearData.STARS:
		return _fail("the 250-star set needs --stars %d or more" % SetGearData.STARS)
	if _arg("mount-level") != "":
		if not _arg("mount-level").is_valid_int() or not int(_arg("mount-level")) in range(1, MountData.MAX_LEVEL + 1):
			return _fail("--mount-level must be 1 to %d" % MountData.MAX_LEVEL)
		mount_level = int(_arg("mount-level"))
	if source == "" or target == "" or wanted == "":
		return _fail("usage: -- --in bundle.json --out boosted.json --name <character> [--class <class>] [--create] [--accessory-plus 0-10]")
	var text := FileAccess.get_file_as_string(source)
	var bundle: Variant = JSON.parse_string(text)
	if not bundle is Dictionary or not bundle.get("slots") is Dictionary:
		return _fail("the input is not a save bundle")
	var result := boost_bundle(bundle, wanted, cls, _flag("create"), accessory_plus, stars, mount, mount_level, gear)
	if result.has("error"):
		return _fail(String(result.error))
	var out := FileAccess.open(target, FileAccess.WRITE)
	if out == null:
		return _fail("cannot write " + target)
	# Only the boosted slot: the other characters stay byte-for-byte as saved.
	var written := {"slot": result.slot, "profile": bundle.slots[result.slot], "created": result.created}
	if bool(result.get("storage", false)):
		written["storage"] = bundle.storage
	out.store_string(JSON.stringify(written))
	out.close()
	var hero: Dictionary = bundle.slots[result.slot]
	print("BOOST: slot %s %s (%s)%s: %s -> Lv.%d ★%d, advancement %d, stat points %d, skill points %d, star points %d" % [
		result.slot, hero.name, hero["class"], " new" if result.created else "", result.before, int(hero.level),
		int(hero.paragon.level), int(hero.adv), int(hero.points), int(hero.skill_points), int(hero.paragon.points)])
	for key in ItemData.EQUIP_SLOTS:
		var piece: Dictionary = hero.equip.get(key, {})
		print("BOOST:   %s: %s +%d" % [key, ItemData.name_of(piece), int(piece.get("plus", 0))])
	if String(hero.get("mount", "")) != "":
		print("BOOST:   mount: %s Lv.%d" % [MountData.info(String(hero.mount)).get("name", hero.mount), int(hero.mounts[hero.mount])])
	return 0


## Boosts the one character named [param wanted] (and of class [param cls] when
## given) inside [param bundle], in place. Returns {slot, before, created} or {error}.
## A starter-class (vagabond) hero of that name also matches: it takes the class
## through the game's own class change, as it would at the class trainer. With
## [param create], a name nobody has is made into a new hero in the first free slot.
static func boost_bundle(bundle: Dictionary, wanted: String, cls := "", create := false, accessory_plus := ItemData.MAX_PLUS, stars := BOOST_STARS, mount := "", mount_level := MountData.MAX_LEVEL, gear := "divine") -> Dictionary:
	if not bundle.get("slots") is Dictionary:
		return {"error": "the input is not a save bundle"}
	var found: Array[String] = []
	for key in bundle.slots:
		var hero: Variant = bundle.slots[key]
		if hero is Dictionary and String(hero.get("name", "")).strip_edges().to_lower() == wanted.strip_edges().to_lower():
			var has := String(hero.get("class", ""))
			if cls == "" or has == cls or (has == String(ClassData.START) and ClassData.IDS.has(StringName(cls))):
				found.append(String(key))
	var created := false
	if found.is_empty() and create:
		var made := _create(bundle, wanted, cls)
		if made.has("error"):
			return made
		found.append(String(made.slot))
		created = true
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
	_level_up(stars)
	if cls != "" and Game.class_id() != StringName(cls) and not Game.change_class(StringName(cls)):
		Game.profile = keep[0]
		Game.has_profile = keep[1]
		return {"error": "could not change the class to " + cls}
	_advance()
	_vault = bundle.storage if bundle.get("storage") is Array else []
	_vault_used = false
	# "keep": the worn gear stays as it is (only levels, stars and the mount change).
	if gear != "keep":
		_dress(accessory_plus, gear == "set250")
	if mount != "":
		var owned: Dictionary = Game.profile.get("mounts", {}) if Game.profile.get("mounts") is Dictionary else {}
		owned[mount] = maxi(int(owned.get(mount, 0)), clampi(mount_level, 1, MountData.MAX_LEVEL))
		Game.profile["mounts"] = owned
		Game.profile["mount"] = mount
	var stats := Game.stats_now()
	Game.profile["hp"] = int(stats.max_hp)
	Game.profile["mp"] = int(stats.max_mp)
	var boosted: Dictionary = Game.profile
	Game.profile = keep[0]
	Game.has_profile = keep[1]
	if not Game._valid_profile(boosted):
		return {"error": "the boosted character does not pass the game's save check"}
	bundle.slots[slot_key] = boosted
	if _vault_used:
		bundle["storage"] = _vault
	return {"slot": slot_key, "before": "new" if created else before, "created": created, "storage": _vault_used}


## A new Vagabond named [param wanted] in the first free slot, stored as the
## cloud save holds it. Returns {slot} or {error}; the bundle is untouched on error.
static func _create(bundle: Dictionary, wanted: String, cls: String) -> Dictionary:
	var name := wanted.strip_edges()
	if not ClassData.IDS.has(StringName(cls)):
		return {"error": "a new character needs its class (one of %s)" % ", ".join(ClassData.IDS)}
	if name.is_empty() or name.length() > NAME_MAX:
		return {"error": "a character name must be 1 to %d characters" % NAME_MAX}
	var free := ""
	for i in range(1, Game.SLOT_COUNT + 1):
		if not bundle.slots.has(str(i)):
			free = str(i)
			break
	if free == "":
		return {"error": "all %d character slots are taken" % Game.SLOT_COUNT}
	var keep := [Game.profile, Game.has_profile]
	Game.new_profile(ClassData.START, name, FaceKit.default_look())
	bundle.slots[free] = JSON.parse_string(JSON.stringify(Game.profile))
	Game.profile = keep[0]
	Game.has_profile = keep[1]
	return {"slot": free}


static func _level_up(stars := BOOST_STARS) -> void:
	var guard := 0
	while int(Game.profile.level) < Game.MAX_LEVEL and guard < 200:
		Game.add_exp(maxi(1, HeroStats.exp_to_next(int(Game.profile.level)) - int(Game.profile.exp)))
		guard += 1
	while int(Game.paragon().level) < mini(stars, Game.PARAGON_MAX) and guard < 800:
		Game.add_exp(maxi(1, Game.paragon_need() - int(Game.paragon().exp)))
		guard += 1


## Takes every job advancement left it qualifies for (Lv.20/40/60/80; the God step
## needs ★300) at the Job Master's terms,
## with the fee handed over first so the hero's gold is unchanged.
static func _advance() -> void:
	while not Game.next_step().is_empty():
		Game.profile["gold"] = int(Game.profile.gold) + Game.next_step_cost()
		if not Game.advance():
			Game.profile["gold"] = int(Game.profile.gold) - Game.next_step_cost()
			break


static func _dress(accessory_plus := ItemData.MAX_PLUS, set250 := false) -> void:
	var cls := StringName(Game.profile["class"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(Game.profile.name) + String(cls) + "-boost")
	var gear := {}
	for key in BEST_SLOTS:
		gear[key] = SetGearData.item(String(cls), key) if set250 else DivineGearData.item(cls, key, rng)
	for key in STAR_SLOTS:
		if set250:
			gear[key] = SetGearData.item(String(cls), key)
			continue
		# The mythic grade of the 200-star piece: the best one that can drop.
		var piece := StarProgression.item(cls, StarProgression.TIERS[-1], key, rng)
		for attempt in 400:
			if int(piece.get("rarity", 0)) >= StarProgression.MYTHIC_RARITY:
				break
			piece = StarProgression.item(cls, StarProgression.TIERS[-1], key, rng)
		gear[key] = piece
	# Star wings already at the top grade and enhancement are kept (a second run).
	var worn_wings: Variant = Game.profile.equip.get("wings")
	if not (worn_wings is Dictionary and StarWingData.is_wing(worn_wings) and int(worn_wings.get("rarity", 0)) >= 4 and int(worn_wings.get("plus", 0)) >= ItemData.MAX_PLUS):
		gear["wings"] = StarWingData.item(String(cls), rng, 4)
	for key in gear:
		var piece: Dictionary = gear[key]
		assert(not piece.is_empty(), "no %s for %s" % [key, cls])
		piece["plus"] = accessory_plus if key in STAR_SLOTS else ItemData.MAX_PLUS
		var old: Variant = Game.profile.equip.get(key)
		if old is Dictionary and not old.is_empty():
			if not Game.add_item(old):
				if _vault.size() < SharedStorage.MAX_ITEMS:
					_vault.append(old)
					_vault_used = true
		Game.profile.equip[key] = piece
	Game.clamp_vitals()
