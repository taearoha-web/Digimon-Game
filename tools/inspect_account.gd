extends Node
## Owner tool used by .github/workflows/inspect-account.yml: reads a saved account bundle
## and prints every character's power, read-only (nothing is written). One line a slot:
## name, class, level, stars, the guild-war power (GuildWarData.power_of of HeroStats.compute,
## the very number the world players are ranked by), atk / matk / hp / def, every worn
## piece's +, the gems, the wings and the mount; then where it would stand among the
## world players right now.
##
##   godot --headless --path . res://tools/inspect_account.tscn -- --in bundle.json

const SLOTS := ["weapon", "armor", "helm", "boots", "ring", "amulet", "wings"]


func _ready() -> void:
	Game.set_process(false)
	get_tree().quit(_run())


func _arg(name: String) -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--" + name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else ""


func _run() -> int:
	var text := FileAccess.get_file_as_string(_arg("in"))
	var bundle: Variant = JSON.parse_string(text)
	if not bundle is Dictionary or not bundle.get("slots") is Dictionary:
		printerr("INSPECT: no slots in the bundle")
		return 1
	# The world players' powers now, to place each character among them.
	var t := WorldPlayers.now()
	var ai: Array = []
	for i in WorldPlayers.size():
		var e := WorldPlayers.entry(i)
		var p := WorldPlayers.progress_at(i, t)
		var sheet := {"class": String(e["class"]), "name": String(e.name), "level": int(p.level), "stars": int(p.stars), "frac": float(p.frac), "divine_frac": float(p.divine_frac), "after": float(p.get("after", 0.0))}
		ai.append({"name": String(e.name), "power": GuildWarData.power_of(HeroStats.compute(WorldPlayers.profile(sheet)))})
	ai.sort_custom(func(a, b): return a.power > b.power)
	var keys: Array = bundle.slots.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for key in keys:
		var raw: Variant = bundle.slots[key]
		if not raw is Dictionary:
			continue
		var profile: Dictionary = Game._repair((raw as Dictionary).duplicate(true))
		var st := HeroStats.compute(profile)
		var power := GuildWarData.power_of(st)
		var gear := PackedStringArray()
		var gems := 0
		var gem_best := -1
		for slot in SLOTS:
			var item: Variant = (profile.get("equip", {}) as Dictionary).get(slot)
			if not item is Dictionary:
				continue
			gear.append("%s+%d" % [slot, int(item.get("plus", 0))])
			for id in item.get("gems", []):
				gems += 1
				var bits := String(id).split("_")
				if bits.size() == 2:
					gem_best = maxi(gem_best, int(bits[1]))
		var wings: Variant = (profile.get("equip", {}) as Dictionary).get("wings")
		var place := 1
		for r in ai:
			if float(r.power) > power:
				place += 1
		print("INSPECT|slot %s|%s|%s|Lv.%d|★%d|power %d|atk %d|matk %d|hp %d|def %d|%s|gems %d best %s|wings %s|among %d world players: #%d (their #1 %s %d)" % [
			key, String(profile.get("name", "")), String(profile.get("class", "")), int(profile.get("level", 1)),
			int((profile.get("paragon", {}) as Dictionary).get("level", 0)), int(power), int(st.atk), int(st.get("matk", 0)), int(st.max_hp), int(st.def),
			" ".join(gear), gems, ItemData.GEM_SIZES[gem_best] if gem_best >= 0 else "-",
			ItemData.name_of(wings) if wings is Dictionary else "-", ai.size(), place, String(ai[0].name), int(ai[0].power)])
		# What makes the number: the pieces, the 250★ set count, the points, the mount, the job.
		var names := PackedStringArray()
		for slot in SLOTS:
			var it: Variant = (profile.get("equip", {}) as Dictionary).get(slot)
			if it is Dictionary:
				names.append("%s=%s%s [%s]" % [slot, ItemData.name_of(it), " +%d" % int(it.get("plus", 0)), ",".join(PackedStringArray((it.get("gems", []) as Array).map(func(g): return String(g))))])
		var gb := HeroStats.gear_bonus(profile)
		var para: Dictionary = (profile.get("paragon", {}) as Dictionary).get("alloc", {}) if profile.get("paragon") is Dictionary else {}
		print("DETAIL|slot %s|%s|adv %d|attrs %s|free points %d|star alloc %s|star free %d|set250 %d|mount %s Lv.%d|%s" % [
			key, String(profile.get("name", "")), int(profile.get("adv", 0)), JSON.stringify(HeroStats.attributes(profile)), int(profile.get("points", 0)),
			JSON.stringify(para), int((profile.get("paragon", {}) as Dictionary).get("points", 0)), int(gb.get("set_gear", 0)),
			String(profile.get("mount", "")), int((profile.get("mounts", {}) as Dictionary).get(String(profile.get("mount", "")), 0)) if profile.get("mounts") is Dictionary else 0,
			" | ".join(names)])
	return 0
