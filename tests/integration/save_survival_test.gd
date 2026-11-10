extends Node
## Save survival: a Dark Lord and a Summoner at Lv.100 ★300 (God step), played through the
## new features with the game's own APIs (world-player party + dragon tomb recruit and
## claim, the keeper's charm and ring, the reward shop's cosmetics and stones, the league
## rounds, a hero-leader pair of the Legendary Guild Wings, chapter 2, the guild hall's
## blessing and notice, star and god skills, ravens / summons, wings pose, the shared
## storage, the stall) must survive save -> reload (slot_info / slot_overview / load_game)
## -> JSON round trip -> the cloud bundle -> the accounts server's validateBundle (node).
## A save with one broken field is salvaged (only that field / item goes), never hidden;
## an unreadable slot shows as damaged (never as empty), is not overwritten by a new hero
## and is never left out of the cloud bundle (which would delete it on the server).
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/integration/save_survival_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func pin(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	GameSettings.load_settings()
	WorldEvents.festival_enabled = false
	WorldPlayers.clear_bonus()
	_reset()
	var heroes := {}
	heroes[3] = _rich_hero(3, &"darklord", "ดากหลอด", WorldPlayers.ALPHA)
	heroes[4] = _rich_hero(4, &"summoner", "ราชาวานร", WorldPlayers.ALPHA)
	for s in heroes:
		_survives(s, heroes[s])
	_cloud(heroes)
	_fuzz()
	_salvage()
	_damaged_slot()
	_backup_lists_damaged()
	_non_finite()
	_recover_hidden()
	WorldPresence.clock_offset = 0.0
	Game.has_profile = false
	print("SAVE SURVIVAL: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _reset() -> void:
	Game.has_profile = false
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
		for extra in [".tmp", ".damaged.json"]:
			if FileAccess.file_exists(Game.save_path(i) + extra):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path(i) + extra))
	SharedStorage.items().clear()
	SharedStorage.migrated().clear()
	SharedStorage.store()
	Game.slot = 1


## Why a profile fails Game._valid_profile: the top-level keys that fail on their own
## (beside the class / level / adv / paragon core), item by item for the item lists.
func _why(raw: Dictionary) -> String:
	var out: PackedStringArray = []
	for p in Game.profile_problems(raw):
		out.append(String(p))
	return ", ".join(out)


## A Lv.100 ★300 God-step hero of class cls in slot s who has used every new feature.
func _rich_hero(s: int, cls: StringName, hero_name: String, g: int) -> Dictionary:
	Game.slot = s
	Game.new_profile(cls, hero_name, FaceKit.default_look())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + s
	# Lv.100 by EXP, then the stars: ★300 and every point spent where the game lets it go.
	Game.add_exp(HeroStats.exp_to_next(1) * 2)
	Game.profile.level = 100
	Game.profile.exp = 0
	var para := Game.paragon()
	para["level"] = 299
	para["points"] = 299
	Game._add_paragon_exp(HeroStats.star_need(299) + 12345)
	check(int(Game.paragon().level) == 300, "%s reached ★300" % hero_name)
	for key in Game.PARAGON_STATS:
		Game.paragon_spend(String(key), 400)
	Game.profile.adv = JobData.GOD_ADV
	# Every skill at its top rank (the God step's art included) and the bar filled.
	for skill in ClassData.pool(cls):
		Game.profile.skills[skill.id] = Game.MAX_SKILL_RANK
	for skill in ClassData.PASSIVES.get(cls, []):
		Game.profile.skills[skill.id] = Game.MAX_SKILL_RANK
	Game.fill_loadout()
	# The full divine set at +10 (the 300-star gear).
	for slot in DivineGearData.SLOTS:
		var piece := DivineGearData.item(String(cls), slot, rng)
		piece["plus"] = 10
		Game.profile.equip[slot] = piece
	# Guild, league rounds (the online guild-war party records the same way) and coins.
	Game.join_guild(g)
	var w := LegendWings.FROM_WEEK + 3
	pin(GuildLeague.week_start(w) + 3600.0)
	var others: Array = []
	for other in WorldPlayers.GUILDS:
		if other != g:
			others.append(other)
	for r in GuildLeague.schedule(w):
		GuildLeague.record_round([g] + others, [6, 0, 0, 0], [120, 10, 10, 10], 0, float(r.at), g)
	pin(GuildLeague.week_end(w) + 60.0)
	GuildLeague.tick()
	# The hero leads the champion guild: the season's pair is minted for it and worn.
	check(Game.hero_leads_guild(g), "%s leads its guild" % hero_name)
	LegendWings.tick()
	if not LegendWings.worn(Game.profile):
		LegendWings.give_to_hero(LegendWings.item(w + s, g))
	check(LegendWings.worn(Game.profile), "%s wears the Legendary Guild Wings" % hero_name)
	# The reward exchange: coins and points, every cosmetic, a few stones, all worn.
	RewardShop.add_coins(20000)
	RewardShop.add_points(5000)
	RewardShop.boss_defeated()
	for tab in ["costume", "trail", "ncol"]:
		for id in RewardShop.catalog(tab):
			RewardShop.buy(tab, String(id))
	for e in RewardShop.STONES:
		RewardShop.buy("stone", String(e.id))
	RewardShop.wear("costume", "celestial")
	RewardShop.wear("trail", "star")
	RewardShop.wear("ncol", "aurora")
	# The party: world players, then the dragon tomb's recruit to a full four.
	var day := GoalsData.today()
	var invited := 0
	for i in WorldPlayers.size():
		if invited >= 1:
			break
		if Game.party_invite(i, true) == "":
			invited += 1
	DungeonData.recruit()
	while DungeonData.party_size() < DungeonData.PARTY_SIZE:
		for i in WorldPlayers.size():
			if not Game.in_party(i) and Game.party_invite(i, true) == "":
				break
	check(DungeonData.enter(day) == "", "%s enters the dragon tomb (%s)" % [hero_name, DungeonData.entry_block(day)])
	DungeonData.claim(rng, 240)
	Game.give_or_store(ItemData.jewel(DungeonData.SCALE, 30))
	var charm := DungeonData.buy("charm", rng)
	var fang := DungeonData.buy("fang", rng)
	DungeonData.buy("feather", rng)
	check(not charm.is_empty() and not fang.is_empty(), "%s exchanged scales for the charm and the ring" % hero_name)
	for wanted in [charm, fang]:
		var at: int = Game.profile.inv.find(wanted)
		if at >= 0:
			Game.equip_from_bag(at)
	# Chapter 2: the quests done, the landmarks seen, the finale's title and aura.
	for id in StoryChapter2.ORDER:
		Game.set_quest(id, "done", 3)
	Game.profile.flags[StoryChapter2.MARKS_FLAG] = 7
	Game.profile.flags[StoryChapter2.DONE_FLAG] = 1
	Game.profile.flags[StoryChapter2.AURA_FLAG] = 1
	Game.check_achievements()
	var k := Achievements.index_of(StoryChapter2.ACH_ID)
	if k >= 0:
		Game.set_title(k)
	# The guild hall: its blessing and the leader's notice (Thai text, at its limit).
	GuildHallData.grant()
	GuildHallData.set_notice("ประกาศกิลด์: รวมพลวันเสาร์ ".repeat(20))
	# The class's own toggles: the Dark Lord's ravens, the wing pose.
	Game.profile.flags["raven_mode"] = 2
	Game.profile.flags["raven_attack"] = 0
	Game.profile.flags["wing_mode"] = 2
	# The shared storage and the stall.
	Game.give_or_store(ItemData.generate(100, cls, rng, 3, "armor"))
	Game.deposit_item(Game.profile.inv.size() - 1)
	Game.withdraw_item(0)
	Game.give_or_store(ItemData.generate(100, cls, rng, 3, "helm"))
	var last: int = Game.profile.inv.size() - 1
	PlayerStall.list_item(last, PlayerStall.clamp_price(Game.profile.inv[last], PlayerStall.fair_price(Game.profile.inv[last])))
	# A day's worth of dailies and kills during the event hours.
	for n in 5:
		Game.report_kill(&"slime")
	Game.daily_progress("raid", 1)
	# Saved inside the tomb with a run open (the page can reload mid-run).
	check(DungeonData.enter(day) == "" and DungeonData.open_run() != "", "%s is inside the tomb on its second entry" % hero_name)
	Game.current_zone = DungeonData.ID
	Game.playing = true
	check(Game.save(), "%s saved" % hero_name)
	Game.playing = false
	Game.current_zone = &"town"
	return Game.profile.duplicate(true)


func _survives(s: int, made: Dictionary) -> void:
	var hero_name := String(made.name)
	var raw := Game._read_slot(s)
	check(not raw.is_empty(), "%s reads back from slot %d" % [hero_name, s])
	var file_text := FileAccess.get_file_as_string(Game.save_path(s))
	print("%s: slot file %d bytes" % [hero_name, file_text.to_utf8_buffer().size()])
	var parsed: Variant = JSON.parse_string(file_text)
	check(parsed is Dictionary and Game._valid_profile(parsed), "%s's slot file is a valid profile (%s)" % [hero_name, _why(parsed) if parsed is Dictionary else "not JSON"])
	check(not Game.slot_info(s).is_empty() and String(Game.slot_info(s).name) == hero_name, "%s is on the character select (slot_info)" % hero_name)
	check(not Game.slot_overview(s).is_empty() and not bool(Game.slot_overview(s).get("damaged", false)), "%s has its slot overview" % hero_name)
	check(Game.load_game(s) and String(Game.profile.name) == hero_name and int(Game.paragon().level) == 300 and int(Game.profile.adv) == JobData.GOD_ADV, "%s loads as the ★300 God step" % hero_name)
	check(LegendWings.worn(Game.profile) and Game.profile.equip.has("amulet") and DungeonData.is_gear(Game.profile.equip.amulet), "%s keeps the wings and the tomb charm" % hero_name)
	check(RewardShop.active("costume") == "celestial" and RewardShop.active("ncol") == "aurora", "%s still wears the shop's cosmetics" % hero_name)
	# Saved again after the load (a repaired profile), then JSON twice over.
	check(Game.save(), "%s saves again after the load" % hero_name)
	var twice: Variant = JSON.parse_string(JSON.stringify(JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(s)))))
	check(twice is Dictionary and Game._valid_profile(twice), "%s survives a double JSON round trip (%s)" % [hero_name, _why(twice) if twice is Dictionary else "?"])
	var repaired: Dictionary = Game._repair((twice as Dictionary).duplicate(true))
	var again: Variant = JSON.parse_string(JSON.stringify(repaired))
	check(again is Dictionary and Game._valid_profile(again), "%s: the repaired profile is valid after JSON (%s)" % [hero_name, _why(again) if again is Dictionary else "?"])
	check(Game.save_code_roundtrip(), "%s's save code round trips" % hero_name)


## The bundle the web page uploads holds both heroes, and the accounts server accepts it.
func _cloud(heroes: Dictionary) -> void:
	var text := Game.cloud_bundle_json()
	var bundle: Variant = JSON.parse_string(text)
	check(bundle is Dictionary and bundle.get("slots") is Dictionary, "the cloud bundle parses")
	if not bundle is Dictionary:
		return
	for s in heroes:
		check((bundle.slots as Dictionary).has(str(s)), "the cloud bundle holds slot %d" % s)
	_server_accepts(text, "the accounts server accepts the bundle")


## Runs a bundle's JSON through hosting/accounts validateBundle (node).
func _server_accepts(text: String, label: String) -> void:
	var dir := OS.get_environment("XDG_DATA_HOME")
	var path := (dir if dir != "" else OS.get_user_data_dir()).path_join("save_survival_bundle.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var script := ProjectSettings.globalize_path("res://tests/integration/save_survival_server.mjs")
	var output: Array = []
	var code := OS.execute("node", [script, path], output, true)
	DirAccess.remove_absolute(path)
	if code == -1 or (output.size() > 0 and String(output[0]).contains("command not found")):
		print("node not found: the server check is skipped")
		return
	check(code == 0, "%s: %s" % [label, output[0] if output.size() > 0 else ""])


## Every validator field against what the game legitimately writes after JSON (floats).
func _fuzz() -> void:
	# A full 100-slot bag, a full shared storage, and a pair of the legendary wings put on:
	# the old wings stay in the bag past its size (LegendWings.give_to_hero).
	Game.load_game(4)
	Game.profile.bag_slots = Game.MAX_BAG
	var rng := RandomNumberGenerator.new()
	while Game.profile.inv.size() < Game.MAX_BAG:
		Game.profile.inv.append(ItemData.generate(100, &"summoner", rng, 2, "boots"))
	while SharedStorage.put(ItemData.generate(100, &"summoner", rng, 2, "helm")):
		pass
	var before: int = Game.profile.inv.size()
	LegendWings.give_to_hero(LegendWings.item(LegendWings.FROM_WEEK + 40, WorldPlayers.ALPHA))
	check(Game.profile.inv.size() == before + 1, "the old pair stays in the full bag (%d)" % Game.profile.inv.size())
	check(Game.save() and Game._valid_profile(JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(4)))), "a bag past its size by the old wings is still a valid hero")
	_server_accepts(JSON.stringify({"slots": {"4": JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(4)))}, "selectedSlot": 4}), "the server accepts the bag past its size")
	# Emoji count as one character in the game (String.length) and on the server.
	check(GuildHallData.set_notice("🐉".repeat(GuildHallData.NOTICE_MAX)) == "ok" and Game.save(), "the leader's notice of %d emoji saves" % GuildHallData.NOTICE_MAX)
	_server_accepts(JSON.stringify({"slots": {"4": JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(4)))}, "selectedSlot": 4}), "the server counts an emoji notice as the game does")
	SharedStorage.items().clear()
	SharedStorage.store()
	Game.load_game(3)
	var base: Dictionary = JSON.parse_string(JSON.stringify(Game.profile))
	var cases := {
		"a text flag at FLAG_TEXT_MAX": func(p): p.flags["x_day"] = "x".repeat(Game.FLAG_TEXT_MAX),
		"a raid run flag": func(p): p.flags["raid_open"] = "2026-11-06#2",
		"stars 300 as a float": func(p): p.paragon["level"] = 300.0,
		"a float crit stat": func(p): p.equip.ring.stats["crit"] = 0.123,
		"the guild hall notice": func(p): p[GuildHallData.NOTICE_KEY] = "ก".repeat(GuildHallData.NOTICE_MAX),
		"a legend wings record": func(p): p[LegendWings.KEY] = {"done": 2970.0, "hold": {"2970": {"g": 1.0, "n": "", "s": 2.0}}, "hand": {"2971": ""}},
		"the shop record as floats": func(p): p[RewardShop.KEY]["lc"] = 10.0,
	}
	for label in cases:
		var p: Dictionary = base.duplicate(true)
		(cases[label] as Callable).call(p)
		check(Game._valid_profile(p), "accepted: %s (%s)" % [label, _why(p)])


## One broken field never hides the hero: the field (or the item) goes, the hero stays.
func _salvage() -> void:
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(4)))
	var broken := good.duplicate(true)
	broken.flags["bad"] = "x".repeat(Game.FLAG_TEXT_MAX + 50)
	broken.look["weird"] = "text"
	(broken.inv as Array).append({"kind": "equip", "slot": "ring", "base": "nothing", "level": 1, "stats": {"zzz": 1}})
	broken.equip["helm"] = {"kind": "equip", "slot": "boots"}
	broken["rshop"] = {"lc": "lots"}
	check(not Game._valid_profile(broken), "the broken save fails the strict check")
	_write_raw(5, JSON.stringify(broken))
	var info := Game.slot_info(5)
	check(not info.is_empty() and String(info.name) == String(good.name) and not bool(info.get("damaged", false)), "the broken hero is still on the character select")
	check(Game.load_game(5), "the broken hero loads")
	check(not Game.profile.flags.has("bad") and not Game.profile.get("look", {}).has("weird"), "only the broken flag and look field went")
	check(int(Game.paragon().level) == 300 and int(Game.profile.adv) == JobData.GOD_ADV and Game.profile.equip.has("wings") and not Game.profile.equip.has("helm"), "the hero, its stars and its other gear stay")
	check(Game.profile.inv.size() == (good.inv as Array).size(), "only the broken item went from the bag")
	check(FileAccess.file_exists(Game.save_path(5) + ".damaged.json"), "the original file is kept aside")
	check(Game.save() and Game._valid_profile(JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(5)))), "the salvaged hero saves clean")


## A slot that cannot be read is shown as damaged, not empty, and nothing overwrites it.
func _damaged_slot() -> void:
	_write_raw(6, "{\"class\": \"nobody\", \"name\": \"ลึกลับ\", \"level\": 100")
	_write_raw(7, JSON.stringify({"class": "no_such_class", "name": "เงา", "level": 100}))
	for s in [6, 7]:
		var info := Game.slot_info(s)
		check(not info.is_empty() and bool(info.get("damaged", false)), "slot %d is shown as damaged, not empty" % s)
		check(bool(Game.slot_overview(s).get("damaged", false)), "slot %d overview is damaged" % s)
		check(Game.free_slot() != s, "a new hero never goes into damaged slot %d" % s)
		check(not Game.load_game(s), "a damaged slot does not load")
	# Not JSON at all: no upload (it would go up without the hero and delete it there).
	check(Game.cloud_bundle_json() == "" and Game.build_cloud_bundle().is_empty(), "an unreadable slot stops the upload instead of sending the account without it")
	Game.delete_save(6)
	# JSON, but no hero can be read from it: it goes up as it is, never left out.
	var bundle: Variant = JSON.parse_string(Game.cloud_bundle_json())
	check(bundle is Dictionary and (bundle.slots as Dictionary).has("7") and String(bundle.slots["7"].name) == "เงา", "the damaged slot goes up as it is, never as missing")
	check((Game.build_cloud_bundle().slots as Dictionary).has("7"), "build_cloud_bundle keeps it too")
	Game.delete_save(7)


func _backup_lists_damaged() -> void:
	_write_raw(8, JSON.stringify({"class": "darklord", "name": "สำรอง", "level": 100, "flags": {"bad": "x".repeat(200)}}))
	var dir := SaveBackup.backup_now("manual")
	check(dir != "", "a backup is made")
	var listed := false
	for entry in SaveBackup.list():
		if entry.dir == dir and (entry.slots as Dictionary).has("8"):
			listed = true
	check(listed, "the backup lists the slot that failed the strict check")
	Game.delete_save(8)
	check(SaveBackup.restore(dir, 8) and not Game.slot_info(8).is_empty() and String(Game.slot_info(8).name) == "สำรอง", "restoring it salvages the hero")
	Game.delete_save(8)


## Godot writes a NaN / infinite float as a bare nan / inf, which no JSON reader takes:
## such a save is read with 0 there, and the game never writes one again.
func _non_finite() -> void:
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(3)))
	var text := JSON.stringify(good).replace("\"play_time\":", "\"play_time\":nan,\"x_nan\":").replace("\"kills\":", "\"kills\":inf,\"x_inf\":")
	check(JSON.parse_string(text) == null, "the bare nan / inf text is not JSON")
	_write_raw(9, text)
	var info := Game.slot_info(9)
	check(not info.is_empty() and not bool(info.get("damaged", false)) and String(info.name) == String(good.name), "a save with nan / inf is still on the character select")
	check(Game.load_game(9) and int(Game.paragon().level) == 300, "and loads")
	Game.profile["play_time"] = NAN
	Game.profile.flags["boom"] = INF
	check(Game.save(), "a NaN in the profile still saves")
	check(JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(9))) is Dictionary and not Game.slot_info(9).is_empty(), "the file written is JSON the browser and the server can read")
	check(JSON.parse_string(Game.cloud_bundle_json()) is Dictionary, "the cloud bundle stays JSON")
	Game.has_profile = false
	Game.delete_save(9)


## A hero an older build hid and the cloud sync then deleted comes back from the daily
## backup by itself (once), unless a hero of that name and class is already there.
func _recover_hidden() -> void:
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	var good: Dictionary = JSON.parse_string(JSON.stringify(Game.salvage_profile({"class": "summoner", "name": "ราชาวานร", "level": 100})))
	good["flags"] = {"tomb_open": "x".repeat(Game.FLAG_TEXT_MAX + 10), "tomb_runs": 1}
	_write_raw(2, JSON.stringify(good))
	_write_raw(1, JSON.stringify({"class": "darklord", "name": "ดากหลอด", "level": 100, "flags": {"ok": 1}}))
	var dir := SaveBackup.backup_now("daily")
	check(dir != "", "a daily backup holds the hidden hero")
	# The old build left it out of the cloud bundle; the next page start deleted the file
	# (the web page did, not the player: no Game.delete_save).
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path(2)))
	check(Game.slot_info(2).is_empty(), "slot 2 is empty now")
	var back := SaveBackup.recover_hidden()
	check(back == [2] and String(Game.slot_info(2).get("name", "")) == "ราชาวานร" and not bool(Game.slot_info(2).get("damaged", false)), "the hidden hero comes back from the backup by itself (%s)" % [back])
	check(SaveBackup.restored_marker().get("slots", []).has(2), "the restore is marked for the web page's sync")
	Game.delete_save(2)
	check(SaveBackup.recover_hidden().is_empty() and not Game.has_save(2), "deleted again on purpose, it stays deleted")
	Game.delete_save(1)
	check(SaveBackup.recover_hidden().is_empty() and not Game.has_save(1), "a hero readable in its newest backup (shown, so maybe deleted on purpose) is not brought back")
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)


func _write_raw(s: int, text: String) -> void:
	var f := FileAccess.open(Game.save_path(s), FileAccess.WRITE)
	f.store_string(text)
	f.close()
