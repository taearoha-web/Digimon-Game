extends Node
## Renders the character select (TitleStage + MainMenu) for review: an empty
## platform, four heroes and all ten, at phone, desktop and tablet shapes.
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/title_stage_shots.tscn -- OUT_DIR
## Run with an isolated XDG_DATA_HOME: it writes and deletes the ten save slots.

const SIZES := [Vector2i(1688, 780), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(2400, 960), Vector2i(2520, 900), Vector2i(800, 1000)]
const CLASSES: Array[StringName] = [&"warrior", &"archer", &"mage", &"priest", &"summoner", &"lancer", &"defender", &"assassin", &"darklord", &"warrior"]


func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.load_settings()
	Game.set_process(false)
	for count in [0, 4, 10]:
		for i in range(1, Game.SLOT_COUNT + 1):
			Game.delete_save(i)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in count:
			Game.slot = i + 1
			var look := FaceKit.default_look()
			look["gender"] = i % 2
			look["style"] = i % 3
			Game.new_profile(CLASSES[i], ["Assotix", "ลูน่า", "ไฟร์", "มิรา", "โทโมะ", "ริว", "Bastion", "เงา", "Raven", "เคน"][i], look)
			Game.profile["level"] = [12, 35, 58, 77, 100, 100, 100, 90, 100, 23][i]
			Game.profile["adv"] = 4 if int(Game.profile.level) >= 80 else (2 if int(Game.profile.level) >= 40 else 1)
			if i >= 4:
				Game.paragon().level = [0, 0, 0, 0, 50, 120, 200, 0, 180, 0][i]
				for slot in ["weapon", "armor", "helm", "boots"]:
					Game.profile.equip[slot] = StarProgression.item(CLASSES[i], 100, slot, rng)
			Game.save()
		for size in SIZES:
			get_window().size = size
			var menu := MainMenu.new()
			add_child(menu)
			for f in 30:
				await get_tree().process_frame
			await get_tree().create_timer(0.6).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/stage_%d_%dx%d.png" % [out, count, size.x, size.y])
			print("SHOT %d heroes %s -> %d on stage" % [count, size, menu.stage.heroes.size()])
			menu.queue_free()
			await get_tree().process_frame
			await get_tree().process_frame
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	get_tree().quit()
