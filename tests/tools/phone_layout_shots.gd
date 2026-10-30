extends Node
## Phone-size layout review: the field HUD (a Lv.41 mage with eight skills, four party
## members, four buffs in three lanes, a long world-event chip, a two-line daily
## tracker, the world chat full of long lines) at the iPhone canvas sizes, one of them
## with a phone's safe insets, then the BackupScreen with four backups listed. One PNG
## per shot in the out dir; every shot prints its key rects and "COLLISION" lines when
## the chip, the chat, a party card, a minimap marker or a backup row touches what it
## must not. Exit code 1 on a
## collision so CI can run it too.
##   xvfb-run -a -s "-screen 0 2600x1200x24" godot --rendering-driver opengl3 --audio-driver Dummy \
##     --path . res://tests/tools/phone_layout_shots.tscn -- <out_dir>
## With a fresh XDG_DATA_HOME: it writes save slots and backups.

const HUD_SIZES := [Vector2i(1280, 720), Vector2i(1600, 736), Vector2i(1920, 884), Vector2i(2160, 1000), Vector2i(2556, 1179)]
const BACKUP_SIZES := [Vector2i(1600, 736), Vector2i(2556, 1179)]
const EVENT_TEXT := "โบนัสทอง +20% · บอสโลกที่ ทุ่งหญ้ามิสต์วูด 12 นาที"
const TRACKER_TEXT := "เควสต์: กำจัดหมาป่าเงาในทุ่งหญ้า 7/10\nรายวัน: เสร็จ 1/3"
const CHAT_LINES := ["ร้านเปิดแล้ว ยาเลือดราคาถูก ยามานาก็มี แวะมาก่อนออกล่านะทุกคน ลดราคาช่วงนี้เท่านั้น", "กิลด์ Neverdie รับสมาชิกเลเวล 100 ขึ้นไป ทักมาได้เลย", "ขอบคุณที่ช่วยเมื่อกี้นะ", "ใครไปสนามถัดไปบ้าง ไปด้วยกัน"]

var main: Node
var out_dir := "user://shots"
var collisions := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = HUD_SIZES[0]
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	Game.new_profile(&"mage", "ลูน่า")
	Game.profile["level"] = 41
	Game.profile["adv"] = JobData.adv_for_level(41)
	Game.fill_loadout()
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	# Days into the world, when players are online: four of them join the party.
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 2.4 * 86400.0 - WorldPlayers.now()
	var t := WorldPresence.clock()
	for i in WorldPlayers.size():
		if Game.world_party.size() >= Game.PARTY_MAX:
			break
		if bool(WorldPlayers.state(i, t).online):
			Game.party_invite(i, true)
	await main.go(&"meadow", true)
	await get_tree().create_timer(1.0).timeout
	var hero: Hero = main.zone.hero
	# The owner's screen: one own buff, two from friends and a song.
	for pair in [[&"mage", "zenith", false], [&"warrior", "holy_valor", true], [&"mage", "energy_shield", true], [&"bard", "valor_march", true]]:
		var s := ClassData.find_skill(pair[0], pair[1])
		hero.receive_buff(s.fx.buff, s.color, s.name, pair[2], pair[1])
	await get_tree().create_timer(0.3).timeout
	var filled := 0
	for slot in main.hud.skill_slots:
		filled += 0 if slot.skill.is_empty() else 1
	print("fixture: party %d | skills %d | buff chips %d" % [Game.world_party.size(), filled, main.hud._timers._chips.size()])
	if Game.world_party.size() != Game.PARTY_MAX or filled != 8:
		_collide("fixture: wanted %d party members and 8 skills, got %d and %d" % [Game.PARTY_MAX, Game.world_party.size(), filled])
	for line in CHAT_LINES:
		Game.world_chat.emit("ผู้เล่นทดสอบชื่อยาวมาก", line, Color("8ff0ff"))
	for size in HUD_SIZES:
		await _hud_shot(size, Vector4.ZERO)
	await _hud_shot(Vector2i(1920, 884), Vector4(44, 0, 44, 24))
	main.queue_free()
	main = null
	await get_tree().process_frame
	_make_backups()
	for size in BACKUP_SIZES:
		await _backup_shot(size)
	print("phone_layout_shots: %d collisions" % collisions)
	get_tree().quit(1 if collisions > 0 else 0)


func _resize(size: Vector2i) -> void:
	get_window().size = size
	await get_tree().process_frame
	await get_tree().process_frame


func _hud_shot(size: Vector2i, insets: Vector4) -> void:
	await _resize(size)
	var hud: HUD = main.hud
	var safe: SafeAreaContainer = hud._frame.get_parent()
	if insets != Vector4.ZERO:
		# Desktop reports no safe area; stand in for a phone's notch and home bar.
		safe.add_theme_constant_override("margin_left", int(insets.x) + safe.min_margin)
		safe.add_theme_constant_override("margin_top", int(insets.y) + safe.min_margin)
		safe.add_theme_constant_override("margin_right", int(insets.z) + safe.min_margin)
		safe.add_theme_constant_override("margin_bottom", int(insets.w) + safe.min_margin)
		await get_tree().process_frame
	# Pin the chip and the tracker to long lines; _process would rewrite them.
	hud._event_in = 1.0e9
	hud._event_label.text = EVENT_TEXT
	hud._event_chip.visible = true
	hud._tracker_timer = 1.0e9
	hud._tracker.visible = true
	hud._tracker.text = TRACKER_TEXT
	hud._place_event_chip()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tag := "field_hud_%dx%d" % [size.x, size.y] + ("_safe" if insets != Vector4.ZERO else "")
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(tag + ".png"))
	var chip := hud._event_chip.get_global_rect()
	var named := {"minimap": hud.minimap.get_global_rect(), "tracker": hud._tracker.get_global_rect(),
		"hp": hud.hp_potion.get_global_rect(), "mp": hud.mp_potion.get_global_rect(), "auto": hud.auto_button.get_global_rect(),
		"target": hud.target_button.get_global_rect(), "raven": hud.raven_button.get_global_rect(), "raven_mode": hud.raven_mode_button.get_global_rect(),
		"online": (hud._frame.find_child("OnlineChip", true, false) as Control).get_global_rect(),
		"gold": hud._gold_label.get_parent().get_parent().get_global_rect(), "chat_chip": (hud._frame.find_child("ChatChip", true, false) as Control).get_global_rect()}
	print("%s chip %s | tracker %s | minimap %s | hp %s | online %s | canvas %s" % [tag, chip, named.tracker, named.minimap, named.hp, named.online, get_viewport().get_visible_rect().size])
	for key in named:
		var other: Rect2 = named[key]
		if chip.intersects(other):
			_collide("%s: event chip %s overlaps %s %s" % [tag, chip, key, other])
	if chip.position.x < 0 or chip.end.x > size.x:
		_collide("%s: event chip %s leaves the canvas" % [tag, chip])
	var chat := hud.world_chat.get_global_rect()
	var first := hud.skill_slots[0].get_global_rect().grow(4.0)
	if chat.intersects(first):
		_collide("%s: world chat %s touches the first skill %s" % [tag, chat, first])
	var ring_center := hud.joystick.global_position + Vector2(hud.joystick.rest_offset.x, hud.joystick.size.y + hud.joystick.rest_offset.y)
	var nearest := Vector2(clampf(ring_center.x, chat.position.x, chat.end.x), clampf(ring_center.y, chat.position.y, chat.end.y))
	if nearest.distance_to(ring_center) < hud.joystick.base_radius + 8.0:
		_collide("%s: world chat %s touches the joystick ring at %s" % [tag, chat, ring_center])
	print("%s chat %s | skill1 %s | ring %s" % [tag, chat, first, ring_center])
	# The party cards stand clear of the chat (four members on the owner's phone).
	var shown := 0
	for entry in hud._party_cards:
		var card: Control = entry.card
		if not card.is_visible_in_tree():
			continue
		shown += 1
		var rect := card.get_global_rect()
		if chat.intersects(rect):
			_collide("%s: world chat %s covers party card %d %s" % [tag, chat, shown, rect])
		if rect.end.y > get_viewport().get_visible_rect().size.y:
			_collide("%s: party card %d %s leaves the canvas" % [tag, shown, rect])
	if shown != Game.world_party.size():
		_collide("%s: %d party cards shown for %d members" % [tag, shown, Game.world_party.size()])
	var buffs := hud._timers.get_global_rect()
	print("%s buffs %s | cards %d" % [tag, buffs, shown])
	# Every minimap marker inside the round map (Minimap.drawn holds what the last draw put down).
	var map_rect := hud.minimap.get_global_rect()
	var markers: Array = hud.minimap.drawn
	if markers.is_empty():
		_collide("%s: the minimap drew no markers" % tag)
	var outside := 0
	for mark in markers:
		var at: Vector2 = mark[0]
		var r: float = mark[1]
		if at.distance_to(hud.minimap.size * 0.5) + r > Minimap.RADIUS + 0.5 or not map_rect.encloses(Rect2(map_rect.position + at - Vector2.ONE * r, Vector2.ONE * r * 2.0)):
			outside += 1
			_collide("%s: minimap marker at %s (r %.1f) leaves the round map %s" % [tag, at, r, map_rect])
	print("%s minimap %s | markers %d | outside %d" % [tag, map_rect, markers.size(), outside])
	if insets != Vector4.ZERO:
		for side in ["left", "top", "right", "bottom"]:
			safe.remove_theme_constant_override("margin_" + side)


func _make_backups() -> void:
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	for entry in SaveBackup.list():
		SaveBackup._remove_dir(entry.dir)
	# Six heroes in each backup: the opened row then outgrows a 720 px canvas, so the shot
	# also proves the list scrolls.
	var heroes := [[1, &"warrior", "นักรบตัวอย่าง", 42], [2, &"mage", "ลูน่าผู้เรียกเวทย์ชื่อยาว", 100], [3, &"priest", "พระน้อย", 7],
		[4, &"archer", "นักธนู", 18], [5, &"warrior", "ดาบสอง", 66], [6, &"mage", "เวทย์สำรอง", 3]]
	for h in heroes:
		Game.slot = h[0]
		Game.new_profile(h[1], h[2])
		Game.profile["level"] = h[3]
		Game.save()
	SaveBackup.backup_now("daily")
	SaveBackup.backup_now("manual")
	SaveBackup.backup_now("before-restore")
	SaveBackup.backup_now("manual")
	Game.has_profile = false
	print("backups listed: %d" % SaveBackup.list().size())


func _backup_shot(size: Vector2i) -> void:
	await _resize(size)
	var screen := BackupScreen.new()
	add_child(screen)
	screen.open_screen()
	var backups := SaveBackup.list()
	if backups.size() > 0:
		screen._open_dir = backups[0].dir
		screen._rebuild()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tag := "backup_%dx%d" % [size.x, size.y]
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(tag + ".png"))
	var scroll: ScrollContainer = screen._box.get_parent()
	var scroll_rect := scroll.get_global_rect()
	var rows := screen._box.get_children()
	print("%s scroll %s | box height %.0f | rows %d | first row %s" % [tag, scroll_rect, screen._box.size.y, rows.size(), (rows[0] as Control).get_global_rect() if rows.size() > 0 else Rect2()])
	for button in screen._root.find_children("*", "Button", true, false):
		var b := button as Button
		var text_width := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
		var inner := b.size.x - b.get_theme_stylebox("normal").get_minimum_size().x
		if text_width > inner + 0.5:
			_collide("%s: button \"%s\" clips its text (%.0f > %.0f)" % [tag, b.text, text_width, inner])
		var rect := b.get_global_rect()
		if rect.position.x < 0 or rect.end.x > size.x or (not b.is_ancestor_of(scroll) and not scroll.is_ancestor_of(b) and rect.end.y > size.y):
			_collide("%s: button \"%s\" %s leaves the canvas" % [tag, b.text, rect])
	for row in rows:
		var rect := (row as Control).get_global_rect()
		if rect.position.x < scroll_rect.position.x - 0.5 or rect.end.x > scroll_rect.end.x + 0.5:
			_collide("%s: row %s is wider than the list %s" % [tag, rect, scroll_rect])
	# The list must be able to scroll when the rows outgrow it.
	if screen._box.size.y > scroll.size.y + 0.5 and scroll.get_v_scroll_bar().max_value < screen._box.size.y - 0.5:
		_collide("%s: rows overflow the list but it cannot scroll" % tag)
	screen.close_screen()
	screen.queue_free()
	await get_tree().process_frame


func _collide(message: String) -> void:
	collisions += 1
	push_error(message)
	print("COLLISION " + message)
