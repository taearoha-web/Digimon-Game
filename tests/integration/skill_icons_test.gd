extends Control
## Import/render coverage and real HUD states. Save actual Godot rasterizations
## for a separate contact-sheet review at 44px, 72px and 128px.

var failures: Array[String] = []
var count := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _ready() -> void:
	var output := OS.get_environment("TOON_ICON_QA_OUTPUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	var hashes := {}
	var families: Array[StringName] = [&"vagabond"]
	families.append_array(ClassData.IDS)
	for family in families:
		for skill in ClassData.pool(family):
			var texture := SkillIcons.for_skill(skill)
			check(texture != null, "missing illustration: " + String(skill.id))
			if texture == null:
				continue
			check(texture == SkillIcons.for_skill(skill), "shared texture cache: " + String(skill.id))
			check(texture == SkillIcons.for_name(String(skill.name)), "buff and summon timer identity: " + String(skill.id))
			var img := texture.get_image()
			check(img != null and img.get_size() == Vector2i(192, 192), "import size: " + String(skill.id))
			var hash_value := img.get_data().hex_encode().sha256_text()
			check(not hashes.has(hash_value), "duplicate rendered illustration: %s and %s" % [skill.id, hashes.get(hash_value, "")])
			hashes[hash_value] = skill.id
			check(img.get_pixel(0, 0).a == 0.0 and img.get_pixel(96, 96).a > 0.99, "medallion alpha: " + String(skill.id))
			if not output.is_empty():
				check(img.save_png(output.path_join(String(skill.id) + ".png")) == OK, "save preview: " + String(skill.id))
			count += 1
	check(count == 302, "all 302 active skills covered (252 class skills, 50 star skills: 40 up to 200 stars and ten 300-star god skills)")
	check(SkillIcons.for_skill({}) == null, "empty slot safely returns null")
	check(SkillIcons.for_id("../game") == null, "path is not an icon ID")
	check(SkillIcons.for_id("future_skill") == null, "new skill can use the developer fallback")
	var bg := ColorRect.new()
	bg.color = Color("111c32")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var ids := ["zenith", "energy_shield", "magic_overdrive", "spirit_elemental", "dancing_sword", "ice_storm", "hell_meteor", "armageddon"]
	for row in 3:
		for col in 8:
			var skill: Dictionary = ClassData.pool(&"mage").filter(func(s): return s.id == ids[col])[0]
			var slot := SkillSlot.new()
			slot.radius = 36.0
			slot.size = Vector2(76, 76)
			slot.position = Vector2(30 + col * 108, 30 + row * 130)
			slot.slot_number = col + 1
			slot.cost = int(skill.mp)
			add_child(slot)
			slot.apply(skill, 0.64 if row == 1 else 0.0, 7.0 if row == 1 else 0.0, true, row != 2, 5, col == 4 and row == 0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not output.is_empty():
		get_viewport().get_texture().get_image().save_png(output.path_join("hud-states.png"))
	Game.new_profile(&"mage", "Icon Review", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.loadout = ids
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"skills")
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var portraits := menu.find_children("*", "TextureRect", true, false)
	# Every skill of the mage's pool (its star skills too) plus the eight loadout slots.
	var pool_size := ClassData.pool(&"mage").size()
	check(portraits.size() == pool_size + 8, "menu has %d mage illustrations and 8 loadout illustrations (%d)" % [pool_size, portraits.size()])
	for portrait in portraits:
		check(portrait.texture != null, "menu has no empty illustrated slot")
	if not output.is_empty():
		get_viewport().get_texture().get_image().save_png(output.path_join("skill-menu.png"))
	menu.close_menu()
	menu.queue_free()
	var trainer := SkillTrainer.new()
	add_child(trainer)
	trainer.open_trainer()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(trainer.find_children("*", "TextureRect", true, false).size() == pool_size, "trainer uses the same %d mage illustrations" % pool_size)
	if not output.is_empty():
		get_viewport().get_texture().get_image().save_png(output.path_join("skill-trainer.png"))
	trainer.close_trainer()
	trainer.queue_free()
	await get_tree().process_frame
	for player in AudioManager._ui_pool:
		player.stop()
		player.stream = null
	AudioManager._stream_cache.clear()
	await get_tree().create_timer(0.1).timeout
	Game.has_profile = false
	print("SKILL ICONS: %s | %d unique rasterized icons, 24 real HUD states, %d failures" % ["PASS" if failures.is_empty() else "FAIL", count, failures.size()])
	get_tree().quit(failures.size())
