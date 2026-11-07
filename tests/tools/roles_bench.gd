extends Node
## What the party-role lookups (ClassRoles) cost a guild war frame: every fighter asks
## every hook twenty times a frame (a busy fight's hits, regeneration and cooldowns),
## timed over 60 frames. Prints the median and p90 of a frame's asks.
##   godot --headless --path . res://tests/tools/roles_bench.tscn


func _ready() -> void:
	WorldEvents.festival_enabled = false
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "Bench")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.hp = Game.stats_now().max_hp
	Game.guildwar_party_chosen = false
	Game.current_zone = &"guildwar"
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	await get_tree().process_frame
	var bodies: Array = m.all_fighters()
	bodies.append(m.hero)
	var mob: Node = bodies[0]
	var times: Array = []
	for frame in 60:
		await get_tree().process_frame
		var t := Time.get_ticks_usec()
		for k in 20:
			for b in bodies:
				ClassRoles.outgoing(b, mob)
				ClassRoles.crit_bonus(b)
				ClassRoles.pierced(b, 100.0)
				ClassRoles.guard(b, 100)
				ClassRoles.cd_rate(b)
				ClassRoles.regen(b, 0.0)
				ClassRoles.after_hit(b, mob, 1)
		times.append(Time.get_ticks_usec() - t)
	times.sort()
	print("ROLES BENCH: %d bodies, %d asks a frame, median %.3f ms, p90 %.3f ms" % [bodies.size(), bodies.size() * 20 * 7, times[30] / 1000.0, times[54] / 1000.0])
	get_tree().quit()
