extends Node
## Every AI Defender in a guild war keeps the Defender's signature buff (เบ่งเลือด) up:
## it is in its two-buff AI kit, a heal that also buffs counts toward the two (it used
## to slip past and fill both buff slots so เบ่งเลือด never went up), and it is the
## first buff the fighter casts.
##   godot --headless --path . res://tests/integration/guild_war_brace_test.tscn
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "Brace QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	check(ClassData.is_buff_skill(ClassData.find_skill(&"defender", "unbreakable")), "a heal that also buffs counts as a buff skill")
	check(ClassData.is_signature(ClassData.find_skill(&"defender", "brace")), "เบ่งเลือด is the Defender's signature")
	for who in ["A", "Zephyr", "Iron Wall", "โล่ทอง"]:
		var kit := ClassData.ai_buff_kit(&"defender", 100, who)
		check(kit.size() == 2 and kit.has("brace"), "AI Defender %s brings เบ่งเลือด plus one buff: %s" % [who, kit])
	Game.current_zone = &"guildwar"
	Game.guildwar_save_checkpoint(4242, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {"gates": [0, 0, 0], "owner": -1})
	Game.guildwar_resuming = true
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	m._timer = 0.05
	for i in 6:
		await get_tree().process_frame
	var defenders := 0
	for f in m.allies + m.enemies:
		if f.fighter_class() != &"defender":
			continue
		defenders += 1
		check(f._try_skill(f, 3.0) and f.cooldowns.has("brace"), "%s casts เบ่งเลือด first: %s" % [f.member.name, f.cooldowns.keys()])
		await get_tree().create_timer(1.5).timeout
		check(BuffBook.contains(f._buff_art.buffs, "brace", false), "%s wears เบ่งเลือด after the cast" % f.member.name)
	check(defenders > 0, "the war has a Defender (%d)" % defenders)
	print("GUILD WAR BRACE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
