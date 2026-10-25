extends Node
## How the world players fare in a field: for DAYS after the world opened (first busy
## field), the hero waits at the entrance and every fall and kill is counted for SECONDS.
##   godot --headless --path . res://tests/tools/world_field_probe.tscn -- [DAYS] [SECONDS]
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var days := float(args[0]) if args.size() > 0 else 0.05
	var seconds := float(args[1]) if args.size() > 1 else 90.0
	WorldPresence.enabled = true
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	Game.new_profile(&"warrior", "Probe", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.party = []
	# Every field is open to the waiting hero (the star fields need stars).
	Game.paragon().level = 200
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	var t := float(WorldPlayers.START_UNIX) + days * 86400.0
	var zone_id: StringName = &""
	while zone_id == &"":
		var count := {}
		for i in WorldPlayers.size():
			var s := WorldPlayers.state(i, t)
			if bool(s.online) and String(s.place) not in ["", "town"]:
				count[String(s.place)] = int(count.get(String(s.place), 0)) + 1
				if int(count[String(s.place)]) >= 2:
					zone_id = StringName(s.place)
		if zone_id == &"":
			t += 900.0
	WorldPresence.clock_offset = t - WorldPlayers.now()
	await main.go(zone_id, true)
	await get_tree().create_timer(1.0).timeout
	var zone: Zone = main.zone
	zone.hero._invulnerable_until = Time.get_ticks_msec() + 10000000
	var falls := {}
	var kills := [0]
	var bosses := [0]
	for node in get_tree().get_nodes_in_group("mobs"):
		(node as Mob).died.connect(func(m: Mob):
			if m.party_share() <= 0.0:
				kills[0] += 1
				bosses[0] += 1 if m.is_boss else 0)
	var was_dead := {}
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
		zone.hero.global_position = zone.entrance() + Vector3(0, 0.2, 0)
		if OS.get_environment("PROBE_VERBOSE") == "1" and int(elapsed * 2.0) % 20 == 0:
			for node in get_tree().get_nodes_in_group("world_players"):
				var b := node as FieldPlayer
				var near := 1e9
				for m in get_tree().get_nodes_in_group("mobs"):
					near = minf(near, (m as Mob).global_position.distance_to(b.global_position))
				print("  t=%d %s at %s camp %s target %s nearest mob %.1f mobs %d dead %s" % [int(elapsed), b.member.name, b.global_position, b.camp().get("pos", "-"), b.target, near, get_tree().get_nodes_in_group("mobs").size(), b.is_dead()])
		for node in get_tree().get_nodes_in_group("world_players"):
			var bot := node as FieldPlayer
			var dead := bot.is_dead()
			if dead and not bool(was_dead.get(bot.world_index, false)):
				var near_boss := false
				for m in get_tree().get_nodes_in_group("mobs"):
					if (m as Mob).is_boss and (m as Mob).global_position.distance_to(bot.global_position) < 12.0:
						near_boss = true
				falls[bot.member.name] = String(falls.get(bot.member.name, "")) + ("B" if near_boss else "m")
			was_dead[bot.world_index] = dead
		for node in get_tree().get_nodes_in_group("mobs"):
			var mob := node as Mob
			if not mob.died.is_connected(_noop):
				mob.died.connect(_noop)
				mob.died.connect(func(m: Mob):
					if m.party_share() <= 0.0:
						kills[0] += 1)
	var lines := []
	for node in get_tree().get_nodes_in_group("world_players"):
		var bot := node as FieldPlayer
		lines.append("%s Lv%d hp %d/%d atk %d def %d pots %d" % [bot.member.name, int(bot.member.level), bot.hp, bot.max_hp, int(bot.stats.atk), int(bot.stats.def), int(bot.member.get("potions", 0))])
	print("FIELD ", main.zone.zone_id, " day ", days, " kills ", kills[0], " (bosses ", bosses[0], ") falls ", falls)
	for l in lines:
		print("  ", l)
	get_tree().quit()


func _noop(_m: Mob) -> void:
	pass
