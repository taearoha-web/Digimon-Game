extends Control
## The HUD portrait (eyes open and closed) for a few heroes: looks, classes and
## outfits, saved side by side.
##   godot --rendering-driver opengl3 --path . res://tests/tools/portrait_preview.tscn -- OUT.png
func _ready() -> void:
	Game.set_process(false)
	var out := OS.get_cmdline_user_args()[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var heroes: Array[Dictionary] = []
	for spec in [[&"vagabond", 0, 0, 1], [&"warrior", 0, 1, 40], [&"priest", 1, 1, 60], [&"mage", 1, 2, 90], [&"defender", 0, 2, 100]]:
		var look := FaceKit.default_look()
		look["gender"] = spec[1]
		ChibiLook.apply_style(look, spec[2])
		var equip := {}
		if int(spec[3]) > 1:
			for slot in ["armor", "helm", "boots"]:
				equip[slot] = ItemData.generate(int(spec[3]), spec[0], rng, 3, slot)
		heroes.append({"class": String(spec[0]), "look": look, "equip": equip})
	heroes.append({"class": "defender", "look": FaceKit.default_look(), "equip": {"armor": DivineGearData.item(&"defender", "armor", rng), "helm": DivineGearData.item(&"defender", "helm", rng)}})
	var size := 192
	var sheet := Image.create(size * heroes.size(), size * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("3a4766"))
	for i in heroes.size():
		var portrait := HeroPortrait.new()
		portrait.custom_minimum_size = Vector2(size, size)
		add_child(portrait)
		portrait.refresh_profile(heroes[i])
		for frame in 120:
			await get_tree().process_frame
			if portrait._shown_key == portrait._wanted_key and portrait._closed != null:
				break
		for row in 2:
			var tex: Texture2D = portrait._open if row == 0 else portrait._closed
			if tex == null:
				continue
			var img := tex.get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blend_rect(img, Rect2i(0, 0, size, size), Vector2i(i * size, row * size))
		portrait.queue_free()
		await get_tree().process_frame
	sheet.save_png(out)
	print("PORTRAITS: ", heroes.size(), " heroes -> ", out)
	get_tree().quit()
