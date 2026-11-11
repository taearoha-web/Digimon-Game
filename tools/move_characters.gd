extends Node
## Owner tool (.github/workflows/move-characters.yml): moves named characters from one
## account's save bundle into another's free slots, then (optionally) sets guilds and
## leaders in the destination with tools/guild_setup.gd.
##   godot --headless --path . res://tools/move_characters.tscn -- --from a.json --to b.json
##     --names "Hades:darklord,Orochi:darklord" [--assign "Hades:darklord:alpha,..."]
##     --out-from a_slots.json --out-to b_slots.json
## Each out file is {slots, selectedSlot}: the whole slot map of that bundle after the move.

const GuildSetup := preload("res://tools/guild_setup.gd")


func _ready() -> void:
	Game.set_process(false)
	get_tree().quit(_run())


func _arg(name: String) -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--" + name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else ""


func _fail(message: String) -> int:
	printerr("MOVE: ", message)
	return 1


func _run() -> int:
	var src: Variant = JSON.parse_string(FileAccess.get_file_as_string(_arg("from")))
	var dst: Variant = JSON.parse_string(FileAccess.get_file_as_string(_arg("to")))
	if not src is Dictionary or not src.get("slots") is Dictionary or not dst is Dictionary or not dst.get("slots") is Dictionary:
		return _fail("the inputs are not save bundles")
	var result := move(src, dst, _arg("names"))
	if result.has("error"):
		return _fail(String(result.error))
	if _arg("assign").strip_edges() != "":
		var res := GuildSetup.setup(dst, _arg("assign"))
		if res.has("error"):
			return _fail(String(res.error))
		result.lines.append_array(res.lines)
	for pair in [[src, _arg("out-from")], [dst, _arg("out-to")]]:
		var out := FileAccess.open(String(pair[1]), FileAccess.WRITE)
		if out == null:
			return _fail("cannot write " + String(pair[1]))
		out.store_string(JSON.stringify({"slots": pair[0].slots, "selectedSlot": pair[0].get("selectedSlot", 1)}))
		out.close()
	for line in result.lines:
		print("MOVE: ", line)
	return 0


## Moves the characters [param names] ("name:class,...", class "any" for any) from
## [param src] into the first free slots of [param dst], in place. {lines} or {error};
## both bundles untouched on error.
static func move(src: Dictionary, dst: Dictionary, names: String) -> Dictionary:
	var from: Dictionary = (src.slots as Dictionary).duplicate(true)
	var to: Dictionary = (dst.slots as Dictionary).duplicate(true)
	var lines: Array[String] = []
	for part in names.split(",", false):
		var bits := part.strip_edges().split(":")
		if bits.size() != 2:
			return {"error": "each name is name:class, got '%s'" % part}
		var who := bits[0].strip_edges().to_lower()
		var cls := bits[1].strip_edges().to_lower()
		var found: Array[String] = []
		for s in from:
			var hero: Variant = from[s]
			if hero is Dictionary and String(hero.get("name", "")).strip_edges().to_lower() == who and (cls == "any" or String(hero.get("class", "")) == cls):
				found.append(String(s))
		if found.size() != 1:
			return {"error": "expected exactly one %s (%s) in the source, found %d" % [bits[0], cls, found.size()]}
		var free := ""
		for i in range(1, Game.SLOT_COUNT + 1):
			if not to.has(str(i)):
				free = str(i)
				break
		if free == "":
			return {"error": "the destination has no free slot for %s" % bits[0]}
		var hero: Dictionary = from[found[0]]
		if not Game._valid_profile(hero):
			return {"error": "%s does not pass the game's save check" % bits[0]}
		# Leader picks named the old account's slots: the destination's setup sets them again.
		hero.erase("guild_leaders")
		to[free] = hero
		from.erase(found[0])
		lines.append("%s (%s) slot %s -> slot %s" % [hero.name, hero["class"], found[0], free])
	if lines.is_empty():
		return {"error": "nothing to move"}
	src.slots = from
	dst.slots = to
	if not from.has(str(src.get("selectedSlot", 1))):
		var keys := from.keys()
		keys.sort()
		src["selectedSlot"] = int(keys[0]) if not keys.is_empty() else 1
	return {"lines": lines}
