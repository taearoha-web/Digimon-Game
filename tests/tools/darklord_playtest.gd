extends Node
## A Lv.100 ★200 Dark Lord hunting a field with a party: the raven attacking on its
## own, every skill cast in turn (Summon warps the party), the cape floating, with a
## screenshot every few seconds and a check that nothing broke.
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/darklord_playtest.tscn -- OUT_DIR [SECONDS] [ZONE]
var main: Node
var raven_hits := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var duration := float(args[1]) if args.size() > 1 else 40.0
	var zone_id := StringName(args[2]) if args.size() > 2 else &"abyss"
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	Game.new_profile(&"darklord", "จักรพรรดิ", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.paragon().level = 200
	Game.profile.attrs = {"str": 400, "int": 150, "dex": 100, "vit": 200}
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for slot in ["weapon", "armor", "helm", "boots"]:
		Game.profile.equip[slot] = StarProgression.item(&"darklord", 200, slot, rng)
	Game.profile.equip["wings"] = StarWingData.item("darklord", rng, 4)
	for skill in ClassData.pool(&"darklord"):
		Game.profile.skills[String(skill.id)] = 5
	Game.fill_loadout()
	Game.party_invite(WorldPlayers.first_of(&"priest"), true)
	Game.party_invite(WorldPlayers.first_of(&"warrior"), true)
	await main.go(zone_id, true)
	var hero: Hero = main.zone.hero
	if not main.zone._camps.is_empty():
		var camp: Dictionary = main.zone._camps[0]
		hero.global_position = Vector3(camp.pos.x, 0.3, camp.pos.y)
	hero._invulnerable_until = Time.get_ticks_msec() + int(duration * 1000) + 5000
	hero.set_wing_mode(HeroVisual.WING_FLY)
	await get_tree().create_timer(1.0).timeout
	hero.set_auto(true)
	hero.set_raven_attack(true)
	var pool := ClassData.pool(&"darklord")
	var cast_index := 0
	var start := Time.get_ticks_msec()
	var k := 0
	var raven_states := {}
	while float(Time.get_ticks_msec() - start) / 1000.0 < duration:
		await get_tree().create_timer(1.5).timeout
		Game.profile.hp = hero.stats.max_hp
		Game.profile.mp = hero.stats.max_mp
		# Walk the party off a little, then cast the next skill (Summon pulls them back).
		var skill: Dictionary = pool[cast_index % pool.size()]
		cast_index += 1
		if String(skill.id) == "summon":
			for ally in get_tree().get_nodes_in_group("companions"):
				ally.global_position = hero.global_position + Vector3(25, 0.3, 0)
		hero.cooldowns.clear()
		hero._cast_until = 0
		if hero.target == null:
			hero.cycle_target()
		hero._cast(skill)
		if String(skill.id) == "summon":
			await get_tree().create_timer(0.8).timeout
			var far := 0
			for ally in get_tree().get_nodes_in_group("companions"):
				if ally.global_position.distance_to(hero.global_position) > 6.0:
					far += 1
			print("SUMMON: allies still far = %d" % far)
		raven_states[hero.raven.state] = true
		var rt: Variant = hero.raven._target_ref.get_ref() if hero.raven._target_ref != null else null
		print("PLAYTEST t=%d cast=%s raven=%s from_lord=%.1f to_target=%.1f kills=%d" % [k, skill.id, hero.raven.state, hero.raven.global_position.distance_to(hero.global_position), hero.raven.global_position.distance_to((rt as Node3D).global_position) if rt is Node3D else -1.0, int(Game.profile.kills)])
		if k % 2 == 0:
			get_viewport().get_texture().get_image().save_png("%s/%02d.png" % [out, k / 2])
		k += 1
	print("RAVEN STATES SEEN: %s strikes=%d" % [raven_states.keys(), hero.raven_strikes])
	get_tree().quit()
