extends Node
## The Dark Lord's Summon (recall the party) is never a reflex: the hero's auto-hunt
## never casts it, the player's own press does; an AI Dark Lord in the party casts it
## only on purpose, when a member has fallen far behind; a rival never does. Imperial
## Judgment's repel throws monsters 3 m clear of the Lord.
##   godot --headless --path . res://tests/integration/lord_summon_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.new_profile(&"darklord", "Summon QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	for skill in ClassData.pool(&"darklord"):
		Game.profile.skills[String(skill.id)] = 1
	Game.profile.party = []
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	await main.go(&"meadow", true)
	await get_tree().create_timer(0.5).timeout
	var hero: Hero = main.zone.hero
	hero._invulnerable_until = Time.get_ticks_msec() + 600000
	check(Game.equip_skill("summon", 0), "Summon can be put on the bar")
	var skills: Array = Game.class_data().skills
	var summon_index := -1
	for i in skills.size():
		if not (skills[i] as Dictionary).is_empty() and String(skills[i].id) == "summon":
			summon_index = i
	check(summon_index >= 0, "Summon is on the Dark Lord's bar")
	# Auto-hunt, badly hurt (Summon also heals 10%), over and over: never Summon.
	var camp: Dictionary = main.zone._camps[0]
	hero.global_position = Vector3(camp.pos.x + 2.0, 0.2, camp.pos.y)
	await get_tree().create_timer(0.3).timeout
	var casts := {}
	for round in 40:
		hero.cooldowns.clear()
		hero._cast_until = 0
		hero._pending = {}
		Game.profile.mp = 99999
		hero.set_target(hero.nearest_mob())
		hero.last_cast_id = ""
		hero._auto_cast(0.3)
		casts[hero.last_cast_id if hero._pending.is_empty() else String(hero._pending.get("id", ""))] = true
	check(not casts.has("summon"), "auto-hunt never casts Summon (cast: %s)" % [casts.keys()])
	# The player's own press does.
	hero.cooldowns.clear()
	hero._cast_until = 0
	Game.profile.mp = 99999
	check(hero.use_skill(summon_index) == "" and float(hero.cooldowns.get("summon", 0.0)) > 0.0, "the player's press casts Summon")
	# An AI Dark Lord in the party: only with a member far behind.
	var idx := WorldPlayers.first_of(&"darklord")
	var m := WorldPlayers.member(idx)
	m["class"] = "darklord"
	m["level"] = 100
	# As Game.party_invite sets it: a new member follows the hero.
	m["stance"] = "follow"
	var lord := FieldPlayer.new()
	lord.party_mode = true
	lord.setup_world(idx, m, hero, main.zone)
	main.zone.add_child(lord)
	lord.remove_from_group("world_players")
	lord.add_to_group("companions")
	await get_tree().create_timer(0.3).timeout
	check(is_instance_valid(lord) and lord.is_inside_tree(), "an AI Dark Lord stands in the party")
	if lord != null:
		var spec := ClassData.find_skill(&"darklord", "summon")
		lord.global_position = hero.global_position + Vector3(2, 0.3, 0)
		await get_tree().physics_frame
		check(lord._shape_score(spec, 2.0, 0.3) == 0.0, "an AI Dark Lord does not Summon a party that is together, even with the hero hurt")
		lord.global_position = hero.global_position + Vector3(Companion.RECALL_DISTANCE + 8.0, 0.3, 0)
		await get_tree().physics_frame
		check(lord._shape_score(spec, 2.0, 1.0) > 0.0, "an AI Dark Lord Summons on purpose when a member is far behind")
		# A member hunting on its own (บุกลุย) is meant to be far: no recall for it.
		m["stance"] = "aggressive"
		check(lord._shape_score(spec, 2.0, 1.0) == 0.0, "no Summon for a member hunting far away at บุกลุย")
		m["stance"] = "follow"
	# Imperial Judgment's repel throws monsters 3 m clear of the Lord, not to its 9 m ring.
	var mob: Mob = hero.nearest_mob()
	if mob != null:
		mob.velocity = Vector3.ZERO
		var center := mob.global_position + Vector3(1.0, 0.0, 0.0)
		mob.shove_out(center, Mob.REPEL_DISTANCE)
		var slide := Vector2(mob.velocity.x, mob.velocity.z).length_squared() / (2.0 * 12.0)
		var lands := 1.0 + slide
		check(absf(lands - (Mob.REPEL_DISTANCE + mob.body_radius())) < 0.05, "a repel throws a monster to 3 m from the Lord (lands %.2f m)" % lands)
	print("LORD SUMMON: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
