extends Node
## The game's root: title → class select → zones. Owns the persistent UI
## (HUD, menu, shop, dialogs, toasts, fade) and moves between zones.

var zone: Zone
var hud: HUD
var menu: GameMenu
var shop: ShopScreen
var dialog: DialogBox
var title_screen: CanvasLayer
var class_screen: CanvasLayer

var _fade: ColorRect
var _traveling := false


func _ready() -> void:
	InputSetup.ensure_defaults()
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 90
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.03, 0.1, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	fade_layer.add_child(_fade)
	add_child(ToastLayer.new())
	hud = HUD.new()
	hud.visible = false
	add_child(hud)
	hud.menu_requested.connect(_open_menu)
	hud.interact_pressed.connect(func(): if zone: zone.interact())
	menu = GameMenu.new()
	add_child(menu)
	menu.title_requested.connect(_back_to_title)
	shop = ShopScreen.new()
	add_child(shop)
	dialog = DialogBox.new()
	add_child(dialog)
	Game.leveled_up.connect(_on_level_up)
	_show_title()


# ---------------------------------------------------------------------------
# Title / new game
# ---------------------------------------------------------------------------

func _show_title() -> void:
	_clear_zone()
	hud.visible = false
	if class_screen:
		class_screen.queue_free()
		class_screen = null
	var screen := MainMenu.new()
	title_screen = screen
	add_child(screen)
	screen.new_game_pressed.connect(_show_class_select)
	screen.continue_pressed.connect(_continue)


func _show_class_select() -> void:
	if title_screen:
		title_screen.queue_free()
		title_screen = null
	var screen := ClassSelect.new()
	class_screen = screen
	add_child(screen)
	screen.cancelled.connect(_show_title)
	screen.confirmed.connect(func(class_id: StringName, hero_name: String):
		Game.new_profile(class_id, hero_name)
		screen.queue_free()
		class_screen = null
		hud.visible = true
		await go(&"town", true))


func _continue() -> void:
	if not Game.load_game():
		return
	if title_screen:
		title_screen.queue_free()
		title_screen = null
	hud.visible = true
	await go(Game.current_zone if Game.current_zone != &"" else &"town", true)


func _back_to_title() -> void:
	await _fade_to(1.0, 0.3)
	_show_title()
	await _fade_to(0.0, 0.3)


# ---------------------------------------------------------------------------
# Zones
# ---------------------------------------------------------------------------

func _clear_zone() -> void:
	if zone:
		zone.queue_free()
		zone = null


func go(zone_id: StringName, instant := false) -> void:
	if _traveling:
		return
	_traveling = true
	var from_zone := String(Game.current_zone)
	if not instant:
		await _fade_to(1.0, 0.35)
	if dialog.is_open:
		dialog.close()
	_clear_zone()
	await get_tree().process_frame
	Game.current_zone = zone_id
	if from_zone != String(zone_id):
		Game.profile["spawn_override"] = from_zone
	var z := Zone.new()
	z.name = "Zone"
	z.zone_id = zone_id
	add_child(z)
	zone = z
	z.travel_requested.connect(func(to: StringName): go(to))
	z.npc_interact.connect(_on_npc)
	z.hero_died.connect(_on_hero_died)
	hud.bind(z)
	hud.visible = true
	Game.save()
	await _fade_to(0.0, 0.45)
	_traveling = false


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, duration)
	await tween.finished


func _on_hero_died() -> void:
	hud.show_death(true)
	await get_tree().create_timer(2.6).timeout
	var stats := Game.stats_now()
	Game.profile.hp = int(stats.max_hp * 0.5)
	Game.profile.mp = stats.max_mp
	var lost := int(Game.profile.gold * 0.05)
	Game.add_gold(-lost)
	if lost > 0:
		Game.say("เสียเหรียญ %d จากการพ่ายแพ้" % lost, &"warning")
	hud.show_death(false)
	_traveling = false
	await go(&"town")


func use_town_scroll() -> void:
	if zone and not zone.is_town:
		Game.say("ใช้ใบวาร์ป — กลับหมู่บ้าน", &"info")
		await get_tree().create_timer(0.4).timeout
		go(&"town")


func _open_menu(tab: StringName) -> void:
	if menu.is_open or shop.is_open or dialog.is_open or _traveling:
		return
	menu.open_menu(tab)


func _on_level_up(level: int) -> void:
	hud.show_banner("เลเวลอัป! Lv.%d" % level)
	Game.say("ได้แต้มสถานะ +%d และแต้มสกิล +1 (เปิดเมนูเพื่อใช้)" % Game.STAT_POINTS_PER_LEVEL, &"success")
	for skill in Game.class_data().skills:
		if int(skill.level) == level:
			Game.say("ปลดล็อกสกิลใหม่: %s!" % skill.name, &"quest")


# ---------------------------------------------------------------------------
# Villagers
# ---------------------------------------------------------------------------

func _on_npc(role: String) -> void:
	if dialog.is_open:
		return
	match role:
		"elder":
			_talk_elder()
		"shop":
			dialog.say("พ่อค้าเก่งกาจ", "ยินดีต้อนรับ! ยา อาวุธ เกราะ มีครบ ของที่เก็บมาก็ขายได้ราคาดีนะ", [
				{"label": "ดูสินค้า", "action": func(): shop.open_shop()}, {"label": "ไว้ก่อน"}])
		"healer":
			var stats := Game.stats_now()
			Game.profile.hp = stats.max_hp
			Game.profile.mp = stats.max_mp
			VfxKit.heal(zone, zone.hero.global_position)
			AudioManager.play_sfx(&"heal")
			dialog.say("ซิสเตอร์เมตตา", "ขอแสงสว่างคุ้มครองเจ้า... HP และ MP ฟื้นเต็มแล้วจ้ะ ไม่ต้องเสียเงินเลย")
		"guide":
			dialog.say("ครูฝึกใจดี", "• แตะปุ่มดาบใหญ่เพื่อล็อกเป้าและโจมตีอัตโนมัติ\n• สกิลทั้ง 4 อยู่บนแถบโค้งรอบปุ่มดาบ ปลดล็อกเมื่อเลเวลถึง\n• เมนูมุมขวาบนใช้อัปแต้มสถานะ อัปสกิล และสวมใส่ไอเทม\n• เข้าประตูแสงทางเหนือเพื่อไปล่ามอนสเตอร์ในทุ่งหญ้า")


func _talk_elder() -> void:
	var quest_id := QuestData.current_quest()
	if quest_id == "":
		dialog.say("ผู้ใหญ่บ้านโชคดี", "เจ้าคือวีรบุรุษของมิสต์วูดอย่างแท้จริง! ตอนนี้ไม่มีเควสต์ใหม่แล้ว แต่เจ้าจะล่ามอนสเตอร์ต่อก็ได้นะ")
		return
	var quest := QuestData.get_quest(quest_id)
	var status := Game.quest_status(quest_id)
	var name_text := "ผู้ใหญ่บ้านโชคดี"
	match status:
		"new":
			if Game.profile.level < int(quest.level) - 1:
				dialog.say(name_text, "งานนี้ยังอันตรายเกินไปสำหรับเจ้า กลับมาเมื่อถึงเลเวล %d นะ" % (int(quest.level) - 1))
				return
			dialog.say(name_text, "เควสต์: %s\n%s\n\nเป้าหมาย: ปราบ %s จำนวน %d ตัว" % [quest.name, quest.desc, MonsterData.get_monster(StringName(quest.target)).name, int(quest.count)], [
				{"label": "รับเควสต์", "action": func():
					Game.set_quest(quest_id, "active", 0)
					Game.say("รับเควสต์: %s" % quest.name, &"quest")}, {"label": "ไว้ก่อน"}])
		"active":
			var progress := int(Game.quest_state(quest_id).get("progress", 0))
			dialog.say(name_text, "ยังไม่เสร็จนะ... %s %d/%d ตัว สู้ๆ!" % [MonsterData.get_monster(StringName(quest.target)).name, progress, int(quest.count)])
		"ready":
			dialog.say(name_text, "เยี่ยมมาก! เจ้าทำได้จริงๆ นี่คือรางวัลสำหรับ \"%s\"" % quest.name, [
				{"label": "รับรางวัล", "action": func(): _reward_quest(quest_id)}])


func _reward_quest(quest_id: String) -> void:
	var quest := QuestData.get_quest(quest_id)
	Game.set_quest(quest_id, "done")
	Game.add_exp(int(quest.exp))
	Game.add_gold(int(quest.gold))
	for entry in quest.items:
		Game.add_item(ItemData.potion(String(entry[0]), int(entry[1])))
	if quest.has("gear"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var item := ItemData.generate(int(quest.gear[0]), Game.class_id(), rng, int(quest.gear[1]), "weapon")
		Game.add_item(item)
		Game.say("ได้รับ %s!" % ItemData.name_of(item), &"quest")
	AudioManager.play_sfx(&"quest_complete")
	Game.say("เควสต์สำเร็จ! EXP +%d เหรียญ +%d" % [int(quest.exp), int(quest.gold)], &"success")
	Game.save()
