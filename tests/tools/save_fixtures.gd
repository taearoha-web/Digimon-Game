extends Node
## Writes real game-generated character saves for the account backend's tests.
## Every class the game ships, built the way a player gets there (a Vagabond
## who changes class at Lv.10, levels, hires a companion, wears gear, gems,
## wings, star gear, spends ★ points, plays dailies, duels, the tower, a guild
## war...), then saved by Game.save() and read back exactly as
## Game.build_cloud_bundle() would send it to the account server.
##
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . \
##     res://tests/tools/save_fixtures.tscn -- [OUT_FILE]
##
## OUT_FILE defaults to res://hosting/accounts/tests/fixtures/game_profiles.json.
## hosting/accounts/tests/account.test.mjs replays that file against the server.

const DEFAULT_OUT := "res://hosting/accounts/tests/fixtures/game_profiles.json"
const NAMES := {&"vagabond": "Assotix", &"warrior": "บราโว่", &"archer": "ลูน่า", &"mage": "มิกะ", &"priest": "นีน่า",
	&"summoner": "ไลรา", &"lancer": "เรย์", &"defender": "Assotix", &"assassin": "ยามิ", &"bard": "เมโลดี้"}

var profiles := {}
var failures := 0


func _ready() -> void:
	Game.set_process(false)
	Game.rng.seed = 20261019
	seed(20261019)
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if args.size() > 0 and args[0] != "" else DEFAULT_OUT
	_build_all()
	var payload := {
		"generatedBy": "tests/tools/save_fixtures.gd",
		"saveVersion": Game.SAVE_VERSION,
		"classes": [String(ClassData.START)] + Array(ClassData.IDS).map(func(id): return String(id)),
		"profiles": profiles,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		printerr("SAVE FIXTURES: cannot write ", out_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	print("SAVE FIXTURES: %s | %d profiles, %d failures -> %s" % ["PASS" if failures == 0 else "FAIL", profiles.size(), failures, out_path])
	get_tree().quit(0 if failures == 0 else 1)


func _fail(message: String) -> void:
	failures += 1
	printerr("FAIL: ", message)


## Saves the current hero through Game.save() and keeps what the file holds.
func _keep(key: String) -> void:
	Game.slot = 1 + profiles.size() % Game.SLOT_COUNT
	if not Game.save():
		_fail("%s: Game.save() failed" % key)
		return
	var bundle := Game.build_cloud_bundle()
	var saved: Variant = bundle.slots.get(String.num_int64(Game.slot))
	if not saved is Dictionary or saved.is_empty():
		_fail("%s: the saved slot does not read back" % key)
		return
	if not Game._valid_profile(saved):
		_fail("%s: the game refuses its own save" % key)
	profiles[key] = saved


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


func _first_zone() -> StringName:
	for id in ZoneData.ZONES:
		if id != &"town" and not bool(ZoneData.ZONES[id].get("safe", false)):
			return id
	return &"town"


func _build_all() -> void:
	# A fresh Vagabond with a little progress, as saved after the first fights.
	Game.new_profile(ClassData.START, NAMES[ClassData.START], FaceKit.default_look())
	Game.playing = true
	Game.add_exp(900)
	Game.set_quest("slimes", "active", 3)
	Game.report_kill(&"pink_slime")
	Game.daily_progress("kills", 2)
	_keep("vagabond_lv5")
	for cls in ClassData.IDS:
		_build_line(cls)
		_build_direct(cls)


## A Vagabond who takes the class at the trainer, then plays to Lv.23 and beyond.
func _build_line(cls: StringName) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(cls))
	Game.new_profile(ClassData.START, NAMES.get(cls, "Hero"), FaceKit.random_look(rng))
	Game.current_zone = _first_zone()
	Game.playing = true
	_level_to(ClassData.LINE_LEVEL)
	if not Game.change_class(cls):
		_fail("%s: change_class refused" % cls)
	_level_to(23)
	Game.spend_point("str", 4)
	Game.spend_point("vit", 2)
	Game.add_gold(500000)
	for skill in Game.skill_pool():
		if Game.skill_unlocked(skill):
			Game.upgrade_skill(skill)
	Game.expand_bag()
	# Gear of the class in every slot, worn, with gems and a few enhancement tries.
	for slot in ["weapon", "armor", "helm", "boots", "ring", "amulet"]:
		var piece := ItemData.generate(int(Game.profile.level), cls, rng, 3, slot)
		if Game.add_item(piece):
			Game.equip_from_bag(Game.profile.inv.find(piece))
	var wings := ItemData.wings(rng, String(cls), 2)
	wings["level"] = mini(int(wings.level), int(Game.profile.level))
	if Game.add_item(wings):
		Game.equip_from_bag(Game.profile.inv.find(wings))
	Game.add_item(ItemData.gem("ruby", 1))
	Game.socket_gem(Game.profile.equip.weapon, Game.profile.inv.size() - 1)
	Game.add_item(ItemData.jewel("purple", 8))
	Game.add_item(ItemData.jewel("pink", 2))
	for i in 6:
		Game.enhance_item(Game.profile.equip.armor)
	# Loot in the bag and the warehouse, potions, quests, kills, bosses, dailies.
	for i in 12:
		Game.add_item(ItemData.generate(rng.randi_range(5, 23), cls if i % 2 == 0 else ClassData.IDS[rng.randi() % ClassData.IDS.size()], rng))
	Game.add_item(ItemData.potion("hp_m", 20))
	Game.add_item(ItemData.gem("sapphire", 0, 3))
	Game.deposit_item(Game.profile.inv.size() - 1)
	Game.deposit_item(3)
	Game.set_quest("slimes", "done", 8)
	Game.set_quest("chickens", "active", 4)
	Game.set_quest("mush_king", "ready", 1)
	for i in 30:
		Game.report_kill(&"wild_chicken")
	Game.report_kill(&"mush_king", true)
	Game.boss_pity()["mush_king"] = 2
	Game.daily_progress("kills", 100000)
	Game.daily_progress("zone_kills", 100000)
	Game.daily_progress("boss", 100000)
	Game.daily_progress("gold", 100000)
	Game.daily_progress("skills", 100000)
	Game.daily_claim_all()
	Game.pvp_finish(true, false, {"member": {"level": 20, "class": "warrior"}}, "คู่ซ้อม")
	Game.pvp_finish(false, true, {"member": {"level": 25, "class": "mage"}}, "คู่ซ้อม")
	Game.tower_begin_run()
	Game.tower_floor_cleared(7)
	Game.tower_add_shards(40)
	Game.guildwar_save_checkpoint(123456789, 412.6, false, [3, 1], 4, 1)
	Game.flag_add("gw_played")
	Game.profile.flags["arena_day"] = GoalsData.today()
	Game.profile.flags["wing_mode"] = 1
	Game.set_loot_mask(5)
	Game.profile["spawn_override"] = ""
	Game.profile["deaths"] = 2
	Game.profile["hp"] = maxi(1, int(Game.profile.hp) - 17)
	Game.profile["mp"] = maxi(0, int(Game.profile.mp) - 9)
	_keep("%s_lv23" % cls)

	# The same hero at Lv.100 with ★ levels, star gear, star wings and ★ points spent.
	Game.guildwar_finish(true, 5, 2, 6, 1, "กิลด์เรา", "กิลด์เขา")
	_level_to(Game.MAX_LEVEL)
	_stars_to(104)
	# Two mounts crafted from their drops, the wolf levelled to Lv.2 and the griffin
	# picked (profile "mounts" {id: level} / "mount").
	Game.add_item(ItemData.jewel("wolf_fang", 3))
	Game.add_item(ItemData.jewel("griffin_plume", 1))
	Game.add_item(ItemData.jewel("chaos", 25))
	if Game.craft_mount("thunder_wolf") != "ok" or Game.craft_mount("thunder_wolf") != "ok" or Game.craft_mount("griffin", 0.0) != "ok" or not Game.select_mount("griffin"):
		_fail("%s: mounts" % cls)
	Game.paragon_spend("atk", 30)
	Game.paragon_spend("hp", 25)
	Game.paragon_spend("crit", 10)
	for key in ["weapon", "armor", "helm", "boots", "ring", "amulet"]:
		var star := StarProgression.item(cls, 100, key, rng)
		if not star.is_empty() and Game.add_item(star):
			Game.equip_from_bag(Game.profile.inv.find(star))
	var star_wings := StarWingData.item(String(cls), rng, 4)
	if Game.add_item(star_wings):
		Game.equip_from_bag(Game.profile.inv.find(star_wings))
	var divine := DivineGearData.item(cls, "weapon", rng)
	if not divine.is_empty():
		Game.add_item(divine)
	Game.add_item(ItemData.gem("emerald", 2))
	Game.socket_gem(Game.profile.equip.ring, Game.profile.inv.size() - 1)
	Game.add_item(ItemData.jewel("purple", 12))
	Game.add_item(ItemData.jewel("pink", 12))
	Game.add_item(ItemData.jewel("chaos", 2))
	Game.add_item(ItemData.jewel("feather", 1))
	for i in 10:
		Game.enhance_item(Game.profile.equip.weapon)
	Game.tower_floor_cleared(60)
	Game.tower_buy("gear")
	Game.tower_buy("gem")
	Game.current_zone = &"town"
	_keep("%s_lv100_star" % cls)

	# The same hero at ★300 after the God promotion ("เทพเจ้าแห่ง<อาชีพ>", adv 5).
	_stars_to(Game.PARAGON_MAX)
	# Every Job Master step it skipped (Lv.20/40/60/80), then the God step.
	for i in JobData.MAX_ADV:
		if Game.next_step().is_empty():
			break
		Game.add_gold(Game.next_step_cost())
		Game.advance()
	if not Game.is_god():
		_fail("%s: God promotion refused (%s)" % [cls, Game.advance_problem()])
	Game.paragon_spend("def", 40)
	Game.paragon_spend("haste", 60)
	_keep("%s_god300" % cls)


## The class picked straight at creation (what tools and tests do).
func _build_direct(cls: StringName) -> void:
	Game.new_profile(cls, "ใหม่ %s" % cls, FaceKit.default_look())
	Game.playing = false
	_keep("%s_new" % cls)
