extends Node
## Where is the guild-war commander? Screenshots of the town: start point, the way, and the NPC.
var main: Node
var _n := 0


func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%02d_%s.png" % [out, _n, name]
	_n += 1
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1600, 736)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	Game.new_profile(&"lancer", "ทดสอบ")
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	await main.go(&"town", true)
	await get_tree().create_timer(1.5).timeout
	var zone: Zone = main.zone
	print("START ", zone.hero.global_position)
	await _shot(out, "town_start")
	var target: Node3D = null
	for npc in zone.npcs:
		print("NPC ", npc.role, " ", npc.global_position)
		if npc.role == "guildwar":
			target = npc
	if target == null:
		print("NO GUILDWAR NPC")
		get_tree().quit()
		return
	zone.hero.global_position = target.global_position + Vector3(0, 0.3, 6.0)
	await get_tree().create_timer(1.5).timeout
	await _shot(out, "near_npc")
	zone.hero.global_position = target.global_position + Vector3(0, 0.3, 2.2)
	await get_tree().create_timer(1.5).timeout
	await _shot(out, "at_npc")
	get_tree().quit()
