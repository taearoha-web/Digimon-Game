extends Node
## Owner tool (.github/workflows/guild-setup.yml): puts named characters of one save
## bundle into guilds and makes each the leader of its guild for every character of the
## account (profile.guild_leaders: "@<slot>" for another character, "" for the hero
## itself), optionally giving each of them a mount at a level as the active one.
##   godot --headless --path . res://tools/guild_setup.tscn -- --in bundle.json --out out.json
##     --assign "Hades:darklord:alpha,Orochi:darklord:neverdie" [--mount fire_drake --mount-level 1]
##     [--relook "Hades:darklord,Orochi:darklord"]  (each gets a new look: hair, colours, eyes, outfit
##     all different from one another; the gender stays). --assign may be empty with --relook.
## A guild is its name (alpha, neverdie, titan, 3dlnw) or id (1-4); a class "any" matches any.
## Writes {slots: {...}} with every slot of the bundle (changed or not).

const GUILD_KEYS := {"alpha": WorldPlayers.ALPHA, "neverdie": WorldPlayers.NEVERDIE, "titan": WorldPlayers.TITAN, "3dlnw": WorldPlayers.LNW, "lnw": WorldPlayers.LNW}


func _ready() -> void:
	Game.set_process(false)
	get_tree().quit(_run())


func _arg(name: String) -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--" + name)
	var value: String = args[at + 1] if at >= 0 and at + 1 < args.size() else ""
	return "" if value.begins_with("--") else value


func _fail(message: String) -> int:
	printerr("GUILD: ", message)
	return 1


func _run() -> int:
	var bundle: Variant = JSON.parse_string(FileAccess.get_file_as_string(_arg("in")))
	if not bundle is Dictionary or not bundle.get("slots") is Dictionary:
		return _fail("the input is not a save bundle")
	var mount := _arg("mount").strip_edges()
	if mount == "none":
		mount = ""
	if mount != "" and not MountData.exists(mount):
		return _fail("--mount must be one of %s" % ", ".join(MountData.ORDER))
	var mount_level := 1
	if _arg("mount-level") != "":
		if not _arg("mount-level").is_valid_int() or not int(_arg("mount-level")) in range(1, MountData.MAX_LEVEL + 1):
			return _fail("--mount-level must be 1 to %d" % MountData.MAX_LEVEL)
		mount_level = int(_arg("mount-level"))
	var result := {"lines": []}
	if _arg("assign").strip_edges() != "":
		result = setup(bundle, _arg("assign"), mount, mount_level)
		if result.has("error"):
			return _fail(String(result.error))
	if _arg("relook").strip_edges() != "":
		var looks := relook(bundle, _arg("relook"))
		if looks.has("error"):
			return _fail(String(looks.error))
		result.lines.append_array(looks.lines)
	if result.lines.is_empty():
		return _fail("nothing to do (--assign or --relook)")
	var out := FileAccess.open(_arg("out"), FileAccess.WRITE)
	if out == null:
		return _fail("cannot write " + _arg("out"))
	out.store_string(JSON.stringify({"slots": bundle.slots}))
	out.close()
	for line in result.lines:
		print("GUILD: ", line)
	return 0


## Applies [param assign] ("name:class:guild,...") to [param bundle] in place.
## Returns {lines} or {error}; the bundle is untouched on error.
static func setup(bundle: Dictionary, assign: String, mount := "", mount_level := 1) -> Dictionary:
	var slots: Dictionary = (bundle.slots as Dictionary).duplicate(true)
	var leaders := {}  # guild id -> slot key
	var lines: Array[String] = []
	for part in assign.split(",", false):
		var bits := part.strip_edges().split(":")
		if bits.size() != 3:
			return {"error": "each assignment is name:class:guild, got '%s'" % part}
		var who := bits[0].strip_edges().to_lower()
		var cls := bits[1].strip_edges().to_lower()
		var key := bits[2].strip_edges().to_lower()
		var g := int(key) if key.is_valid_int() else int(GUILD_KEYS.get(key, 0))
		if not WorldPlayers.GUILD_NAMES.has(g):
			return {"error": "unknown guild '%s'" % key}
		if leaders.has(g):
			return {"error": "two leaders for %s" % WorldPlayers.guild_name(g)}
		var found: Array[String] = []
		for s in slots:
			var hero: Variant = slots[s]
			if hero is Dictionary and String(hero.get("name", "")).strip_edges().to_lower() == who and (cls == "any" or String(hero.get("class", "")) == cls):
				found.append(String(s))
		if found.size() != 1:
			return {"error": "expected exactly one %s (%s), found %d" % [bits[0], cls, found.size()]}
		var hero: Dictionary = slots[found[0]]
		if int(hero.get("level", 0)) < Game.GUILD_LEVEL:
			return {"error": "%s is under Lv.%d" % [bits[0], Game.GUILD_LEVEL]}
		if not hero.get("flags") is Dictionary:
			hero["flags"] = {}
		var before := int(hero.flags.get(Game.GUILD_FLAG, 0))
		hero.flags[Game.GUILD_FLAG] = g
		hero.flags[Game.GUILD4_FLAG] = 1
		if before > 0 and before != g and hero.get("guild_leaders") is Dictionary:
			(hero.guild_leaders as Dictionary).erase(str(before))
		if mount != "":
			var owned: Dictionary = hero.get("mounts", {}) if hero.get("mounts") is Dictionary else {}
			owned[mount] = maxi(int(owned.get(mount, 0)), mount_level)
			hero["mounts"] = owned
			hero["mount"] = mount
		leaders[g] = found[0]
		lines.append("slot %s %s (%s) -> %s%s" % [found[0], hero.name, hero["class"], WorldPlayers.guild_name(g),
			"" if mount == "" else ", mount %s Lv.%d" % [mount, int(hero.mounts[mount])]])
	if leaders.is_empty():
		return {"error": "nothing to assign"}
	for s in slots:
		var hero: Variant = slots[s]
		if not hero is Dictionary:
			continue
		var picks: Dictionary = hero.get("guild_leaders", {}) if hero.get("guild_leaders") is Dictionary else {}
		for g in leaders:
			picks[str(g)] = "" if String(leaders[g]) == String(s) else Game.alt_pick(int(leaders[g]))
		hero["guild_leaders"] = picks
	for s in slots:
		if slots[s] is Dictionary and not Game._valid_profile(slots[s]):
			return {"error": "slot %s does not pass the game's save check after the change" % s}
	for g in leaders:
		lines.append("%s is led by slot %s for every character" % [WorldPlayers.guild_name(g), leaders[g]])
	bundle.slots = slots
	return {"lines": lines}


## New looks for the named characters ("name:class,...") of [param bundle], in place, each
## different from the others (hair style, hair colour, eye colour and outfit spread out),
## the gender kept. {lines} or {error}.
static func relook(bundle: Dictionary, names: String) -> Dictionary:
	var slots: Dictionary = (bundle.slots as Dictionary).duplicate(true)
	var lines: Array[String] = []
	var n := 0
	for part in names.split(",", false):
		var bits := part.strip_edges().split(":")
		var who := bits[0].strip_edges().to_lower()
		var cls := bits[1].strip_edges().to_lower() if bits.size() > 1 else "any"
		var found: Array[String] = []
		for s in slots:
			var hero: Variant = slots[s]
			if hero is Dictionary and String(hero.get("name", "")).strip_edges().to_lower() == who and (cls == "any" or String(hero.get("class", "")) == cls):
				found.append(String(s))
		if found.size() != 1:
			return {"error": "expected exactly one %s (%s), found %d" % [bits[0], cls, found.size()]}
		var hero: Dictionary = slots[found[0]]
		var old: Dictionary = FaceKit.repair(hero.get("look", {}) if hero.get("look") is Dictionary else {})
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("relook|" + String(hero.name))
		var look := FaceKit.random_look(rng)
		var gender := int(old.gender)
		look["gender"] = gender
		# Spread the parts the eye reads first, one step apart per character.
		look["hair"] = (n * 2 + 1) % FaceKit.option_count("hair", gender)
		look["hair_color"] = (n * 3 + 2) % FaceKit.option_count("hair_color", gender)
		look["eye_color"] = (n * 2 + 1) % FaceKit.option_count("eye_color", gender)
		look["outfit"] = (n + 1) % FaceKit.option_count("outfit", gender)
		ChibiLook.apply_style(look, (n * 2 + 1) % ChibiLook.count("style"))
		hero["look"] = FaceKit.repair(look)
		if not Game._valid_profile(hero):
			return {"error": "%s does not pass the save check with the new look" % bits[0]}
		lines.append("slot %s %s: new look hair %d colour %d eyes %d outfit %d" % [found[0], hero.name, int(hero.look.hair), int(hero.look.hair_color), int(hero.look.eye_color), int(hero.look.outfit)])
		n += 1
	bundle.slots = slots
	return {"lines": lines}
