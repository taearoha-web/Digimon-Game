extends Node
## The owner's iPhone screen, end game: a Lv.100 ★300 Dark Lord with cape, mount and
## raven, four party members with stars, two own buffs, two from friends and a song,
## a boss as the target, nine-digit gold, the chat full. One PNG per canvas size with a
## phone's insets, and the rects of the left column, the skill row and the right
## column printed for comparison.
##   xvfb-run -a -s "-screen 0 2600x1200x24" godot --rendering-driver opengl3 --audio-driver Dummy \
##     --path . res://tests/tools/hud_phone_shots.tscn -- <out_dir> [left top right bottom insets]
## With a fresh XDG_DATA_HOME: it writes a save slot.

## iPhone 14 Pro sideways (844 x 390 pt) is a 1558 x 720 canvas; 2556 x 1179 its pixels.
const SIZES := [Vector2i(2556, 1179), Vector2i(1600, 736)]
const CHAT_LINES := ["ร้านเปิดแล้ว ยาเลือดราคาถูก แวะมาก่อนออกล่านะทุกคน", "ระวังท่าบอสด้วยนะทุกคน", "ดาวช่วงหลัง 200 ขึ้นช้ามาก"]

var main: Node
var out_dir := "user://hud_shots"
## Canvas units: the notch side, the top, the far side and the home bar.
var insets := Vector4(87, 0, 30, 20)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() >= 5:
		insets = Vector4(float(args[1]), float(args[2]), float(args[3]), float(args[4]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = SIZES[0]
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	Game.new_profile(&"darklord", "ราชาวานร")
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.paragon().level = 300
	Game.profile["gold"] = 113177853
	for skill in ClassData.pool(&"darklord"):
		Game.profile.skills[String(skill.id)] = 5
	for slot in ItemData.SLOTS:
		Game.profile.equip[slot] = StarProgression.item(&"darklord", 200, slot, Game.rng)
	Game.profile.equip["wings"] = StarWingData.item("darklord", Game.rng, 4)
	Game.profile["mounts"] = {String(MountData.ORDER[0]): MountData.MAX_LEVEL}
	Game.profile["mount"] = String(MountData.ORDER[0])
	Game.fill_loadout()
	Game.gold_changed.emit(int(Game.profile.gold))
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 6.0 * 86400.0 - WorldPlayers.now()
	var t := WorldPresence.clock()
	for i in WorldPlayers.size():
		if Game.world_party.size() >= Game.PARTY_MAX:
			break
		if bool(WorldPlayers.state(i, t).online):
			Game.party_invite(i, true)
	await main.go(&"meadow", true)
	await get_tree().create_timer(1.0).timeout
	var hero: Hero = main.zone.hero
	for pair in [[&"darklord", "", false], [&"warrior", "holy_valor", true], [&"mage", "energy_shield", true], [&"bard", "valor_march", true]]:
		var s: Dictionary = {}
		if String(pair[1]) == "":
			for skill in ClassData.pool(&"darklord"):
				if skill.get("fx", {}).has("buff"):
					s = skill
					break
		else:
			s = ClassData.find_skill(pair[0], pair[1])
		if not s.is_empty():
			hero.receive_buff(s.fx.buff, s.color, s.name, pair[2], String(s.id))
	for line in CHAT_LINES:
		Game.world_chat.emit("ราชันอีกา", line, Color("ff9a8a"))
	# A boss as the target: the top bar shows its name and big HP numbers.
	var boss: Mob = null
	var best := INF
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob != null and not mob.is_dead() and mob.global_position.distance_to(hero.global_position) < best:
			best = mob.global_position.distance_to(hero.global_position)
			boss = mob
	if boss != null:
		boss.max_hp = 706030
		boss.hp = 255600
		hero.target = boss
	await get_tree().create_timer(0.5).timeout
	for size in SIZES:
		await _shot(size)
	get_tree().quit()


func _shot(size: Vector2i) -> void:
	get_window().size = size
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: HUD = main.hud
	var safe: SafeAreaContainer = hud._frame.get_parent()
	safe.add_theme_constant_override("margin_left", int(insets.x) + safe.min_margin)
	safe.add_theme_constant_override("margin_top", int(insets.y) + safe.min_margin)
	safe.add_theme_constant_override("margin_right", int(insets.z) + safe.min_margin)
	safe.add_theme_constant_override("margin_bottom", int(insets.w) + safe.min_margin)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var canvas := get_viewport().get_visible_rect().size
	var tag := "hud_%dx%d" % [size.x, size.y]
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(tag + ".png"))
	var column := Rect2()
	for child in hud._status_column.get_children():
		var c := child as Control
		if c != null and c.is_visible_in_tree() and c.size.y > 0.0:
			column = c.get_global_rect() if column.size == Vector2.ZERO else column.merge(c.get_global_rect())
	var skills := hud.skill_slots[0].get_global_rect().merge(hud.skill_slots[hud.skill_slots.size() - 1].get_global_rect())
	print("%s canvas %s | left column %s | skills %s (gap to bottom %.0f) | hp potion %s (gap to right %.0f) | chat %s | target %s | top row %s" % [
		tag, canvas, column, skills, canvas.y - skills.end.y, hud.hp_potion.get_global_rect(), canvas.x - hud.hp_potion.get_global_rect().end.x,
		hud.world_chat.get_global_rect(), hud._target_panel.get_global_rect(), hud._top_row.get_global_rect() if "_top_row" in hud and hud._top_row != null else Rect2()])
