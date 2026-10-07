extends Node
## The game's root: title → class select → zones. Owns the persistent UI
## (HUD, menu, shop, dialogs, toasts, fade) and moves between zones.

var zone: Zone
var hud: HUD
var menu: GameMenu
var shop: ShopScreen
var trainer: SkillTrainer
var storage: StorageScreen
var warp: WarpScreen
var pvp_screen: PvpScreen
var dialog: DialogBox
var _flash: ColorRect
var title_screen: CanvasLayer
var class_screen: CanvasLayer

var _fade: ColorRect
var _traveling := false


func _ready() -> void:
	GameSettings.load_settings()
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
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 80
	add_child(flash_layer)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	flash_layer.add_child(_flash)
	Game.screen_flash.connect(func(color: Color, strength: float):
		_flash.color = Color(color.r, color.g, color.b, strength)
		create_tween().tween_property(_flash, "color:a", 0.0, 0.35))
	Game.ending_requested.connect(show_ending)
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
	trainer = SkillTrainer.new()
	add_child(trainer)
	storage = StorageScreen.new()
	add_child(storage)
	warp = WarpScreen.new()
	add_child(warp)
	warp.warp_chosen.connect(func(id: StringName): go(id, false, true))
	pvp_screen = PvpScreen.new()
	add_child(pvp_screen)
	pvp_screen.challenge_requested.connect(func(): go(&"pvp", false, true))
	pvp_screen.go_home_requested.connect(func(): go(&"town", false, true))
	dialog = DialogBox.new()
	add_child(dialog)
	Game.leveled_up.connect(_on_level_up)
	Game.paragon_leveled.connect(func(level: int):
		hud.show_banner("ระดับเหนือเลเวล ★%d!" % level)
		Game.say("ได้แต้มพาราก้อน +1 (เมนูตัวละคร)", &"success")
		AudioManager.play_sfx(&"level_up"))
	_show_title()
	# A reloaded browser tab (memory pressure, screen lock) goes straight back in.
	if OS.has_feature("web") and Game.should_resume():
		await get_tree().process_frame
		await _continue(Game.last_slot())
		Game.say("เล่นต่อจากเดิมอัตโนมัติ", &"info")


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


func _show_class_select(slot: int) -> void:
	Game.slot = slot
	if title_screen:
		title_screen.queue_free()
		title_screen = null
	var screen := ClassSelect.new()
	class_screen = screen
	add_child(screen)
	screen.cancelled.connect(_show_title)
	screen.confirmed.connect(func(class_id: StringName, hero_name: String, look: Dictionary):
		Game.new_profile(class_id, hero_name, look)
		screen.queue_free()
		class_screen = null
		hud.visible = true
		Game.playing = true
		await go(&"town", true))


func _continue(slot: int) -> void:
	if not Game.load_game(slot):
		return
	if title_screen:
		title_screen.queue_free()
		title_screen = null
	hud.visible = true
	Game.playing = true
	await go(Game.current_zone if Game.current_zone != &"" else &"town", true)


func _back_to_title() -> void:
	Game.playing = false
	Game.save()
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


## warp = true arrives at the field's start (not at the portal you came through).
func go(zone_id: StringName, instant := false, warping := false) -> void:
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
	Game.save()
	if from_zone != String(zone_id) and not warping:
		Game.profile["spawn_override"] = from_zone
	elif warping:
		Game.profile["spawn_override"] = ""
	var z := Zone.new()
	z.name = "Zone"
	z.zone_id = zone_id
	add_child(z)
	zone = z
	z.travel_requested.connect(func(to: StringName): go(to))
	z.npc_interact.connect(_on_npc)
	z.hero_died.connect(_on_hero_died)
	z.pvp_finished.connect(func(result: Dictionary): pvp_screen.show_result(result))
	z.banner_requested.connect(func(text: String): hud.show_banner(text))
	hud.bind(z)
	hud.visible = true
	Game.save()
	await _fade_to(0.0, 0.45)
	_traveling = false


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, duration)
	await tween.finished


func show_ending() -> void:
	if get_tree().paused:
		return
	var ending := EndingScreen.new()
	add_child(ending)


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
	if menu.is_open or shop.is_open or trainer.is_open or storage.is_open or warp.is_open or pvp_screen.is_open or dialog.is_open or _traveling:
		return
	menu.open_menu(tab)


func _on_level_up(level: int) -> void:
	hud.show_banner("เลเวลอัป! Lv.%d" % level)
	Game.say("ได้แต้มสถานะ +%d และแต้มสกิล +1 (เปิดเมนูเพื่อใช้)" % Game.STAT_POINTS_PER_LEVEL, &"success")
	for skill in Game.skill_pool():
		if int(skill.level) == level:
			if Game.skill_unlocked(skill):
				Game.say("ปลดล็อกสกิลใหม่: %s! (ใส่ในแถบสกิลได้ที่เมนูสกิล)" % skill.name, &"quest")
			else:
				Game.say("สกิล %s ต้อง%s ก่อน — ไปหาปรมาจารย์ผู้เปลี่ยนชะตา" % [skill.name, Game.skill_lock_reason(skill).trim_prefix("ต้อง")], &"quest")
	if Game.class_id() != ClassData.START and Game.adv() < JobData.MAX_ADV and level == Game.next_step_level():
		hud.show_banner("เปลี่ยนอาชีพขั้นต่อไปได้แล้ว!")
		Game.say("สกิลเลเวล %d ขึ้นไปต้องเปลี่ยนอาชีพ ไปหาปรมาจารย์ผู้เปลี่ยนชะตา" % level, &"quest")


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
		"job":
			_talk_job()
		"storage":
			dialog.say("เจ้าของคลัง", "ของที่ยังไม่ใช้ฝากไว้กับข้าได้ปลอดภัย (คลังจุ %d ช่อง) หรือจะจ่ายเหรียญขยายกระเป๋าเพิ่มทีละ %d ช่องก็ได้ ตอนนี้กระเป๋ามี %d ช่อง" % [Game.STORAGE_SIZE, Game.BAG_STEP, Game.bag_size()], [
				{"label": "เปิดคลัง", "action": func(): storage.open_storage()}, {"label": "ไว้ก่อน"}])
		"skill":
			dialog.say("ปรมาจารย์สกิล", "ข้าสอนสกิลให้แรงขึ้นได้สูงสุด 5 ดาว ใช้แต้มสกิลและเหรียญ สกิลใหม่จะปลดล็อกตามเลเวล แล้วเจ้าก็เลือกใส่ 4 ตัวบนแถบสกิลได้ในเมนูสกิล", [
				{"label": "ฝึกสกิล", "action": func(): trainer.open_trainer()}, {"label": "ไว้ก่อน"}])
		"party":
			_talk_party()
		"daily":
			_talk_daily()
		"warp":
			warp.open_warp()
		"pvp":
			pvp_screen.open_lobby()
		"arena":
			dialog.say("ผู้ดูแลสนามประลอง", "ท้าทายสนามประลอง! สู้ 3 รอบ ปราบฝูงมอนสเตอร์แล้วจบด้วยบอส ชนะแล้วได้รางวัลก้อนโต (ชนะครั้งแรกของวันได้เต็ม) พร้อมไหม?", [
				{"label": "เข้าสนาม", "action": func(): go(&"arena")}, {"label": "ไว้ก่อน"}])
		"forge":
			dialog.say("ช่างตีเหล็กหนวดแดง", "ฮ่าๆ มีของดีมาให้ตีไหม? ข้าตีบวกอาวุธเกราะให้แรงขึ้นได้ถึง +10 พลาดก็เสียแค่เหรียญ ของไม่พัง! แล้วถ้ามีอัญมณีก็เอามาฝังช่องให้ได้ด้วย", [
				{"label": "เปิดเตาตี", "action": func():
					menu.forge_mode = true
					_open_menu(&"inventory")}, {"label": "ไว้ก่อน"}])
		"healer":
			var stats := Game.stats_now()
			Game.profile.hp = stats.max_hp
			Game.profile.mp = stats.max_mp
			VfxKit.heal(zone, zone.hero.global_position)
			AudioManager.play_sfx(&"heal")
			dialog.say("ซิสเตอร์เมตตา", "ขอแสงสว่างคุ้มครองเจ้า... HP และ MP ฟื้นเต็มแล้วจ้ะ ไม่ต้องเสียเงินเลย")
		"guide":
			dialog.say("ครูฝึกใจดี", "• แตะปุ่มดาบใหญ่เพื่อล็อกเป้าและโจมตีอัตโนมัติ\n• เริ่มเป็นนักเดินทาง พอถึงเลเวล 10 ไปหาปรมาจารย์ผู้เปลี่ยนชะตาเพื่อเลือกสาย ดาบ/ธนู/เวทย์/บวช\n• สกิลปลดล็อกตามเลเวล เลือกใส่ 4 ตัวบนแถบโค้งได้ที่เมนูสกิล และอัปดาวสกิลที่ปรมาจารย์สกิล\n• เมนูมุมขวาบนใช้อัปแต้มสถานะ จัดแถบสกิล และสวมใส่ไอเทม\n• เสาวาปคริสตัลสีฟ้า (ในเมืองและทุกแมพ) พาไปแมพที่เลเวลถึงหรือกลับเมืองได้ฟรี\n• เข้าประตูแสงทางเหนือเพื่อไปล่ามอนสเตอร์ในทุ่งหญ้า")


func _talk_daily() -> void:
	var speaker := "กระดานเควสต์รายวัน"
	var paid := Game.daily_claim_all()
	var lines: PackedStringArray = []
	for entry in Game.daily().quests:
		var template := Game.daily_template(entry.id)
		var target := Game.daily_target(entry)
		var mark := "✔" if entry.claimed else ("●" if int(entry.progress) >= target else "○")
		lines.append("%s %s — %s (%d/%d)" % [mark, template.name, String(template.desc) % target, int(entry.progress), target])
	var streak := Game.daily_streak()
	if streak > 0:
		lines.append("ติดต่อกัน %d วัน (โบนัสรางวัล +%d%%)  ทำครบทั้ง 3 งานรับหีบรางวัลพิเศษ" % [streak, int(minf(float(streak) - 1.0, 6.0) * 10.0)])
	var text := "\n".join(lines)
	if paid > 0:
		AudioManager.play_sfx(&"quest_complete")
		text = "รับรางวัลแล้ว %d งาน!\n\n%s" % [paid, text]
		Game.save()
	dialog.say(speaker, text)


func _talk_party() -> void:
	var speaker := "นายหน้าเพื่อนร่วมทาง"
	var party := Game.party()
	var text := "ออกผจญภัยคนเดียวมันเหงานะ! ข้ามีนักผจญภัยฝีมือดีให้ร่วมทางด้วย 1 คน เก่งขึ้นตามเลเวลของเจ้า แต่ก็บาดเจ็บและล้มได้เหมือนกัน"
	if not party.is_empty():
		var member: Dictionary = party[0]
		text += "\n\nตอนนี้เจ้าพา %s (%s Lv.%d นิสัย%s) ไปด้วย\nแตะการ์ดเพื่อนที่มุมซ้ายบนเพื่อสลับ ตามติด/บุกลุย/ป้องกัน" % [member.name, ClassData.get_class_data(StringName(member["class"])).name, int(member.level), Game.TRAIT_NAMES.get(String(member.get("trait", "brave")), "กล้าหาญ")]
	var options: Array = [{"label": "เลือกเพื่อน", "action": func(): _pick_party()}]
	if not party.is_empty():
		options.append({"label": "ให้กลับบ้าน", "action": func():
			Game.dismiss_party()
			dialog.say(speaker, "เข้าใจแล้ว ไว้คิดถึงเมื่อไหร่ก็มาหาข้าใหม่นะ")})
	options.append({"label": "ไว้ก่อน"})
	dialog.say(speaker, text, options)


func _pick_party() -> void:
	var speaker := "นายหน้าเพื่อนร่วมทาง"
	var lines: PackedStringArray = []
	var options: Array = []
	for id in ClassData.IDS:
		lines.append("• %s — %s" % [ClassData.get_class_data(id).name, Game.PARTY_BLURBS[id]])
		options.append({"label": String(ClassData.get_class_data(id).name), "action": func():
			Game.recruit(id)
			if zone and zone.hero:
				VfxKit.level_up(zone, zone.hero.global_position)
			var member: Dictionary = Game.party()[0]
			dialog.say(speaker, "ตกลง! %s (%s) จะร่วมทางกับเจ้า เริ่มที่เลเวล %d ดูแลกันดีๆ นะ" % [member.name, ClassData.get_class_data(id).name, int(member.level)])})
	options.append({"label": "ย้อนกลับ", "action": func(): _talk_party()})
	dialog.say(speaker, "เลือกได้ 1 คน (เพื่อนคนเก่าจะกลับบ้านไป):\n" + "\n".join(lines), options)


func _talk_job() -> void:
	var speaker := "ปรมาจารย์ผู้เปลี่ยนชะตา"
	if Game.class_id() == ClassData.START:
		if int(Game.profile.level) < ClassData.LINE_LEVEL:
			dialog.say(speaker, "เจ้ายังเป็นแค่นักเดินทางสินะ ฝึกฝนจนถึงเลเวล %d แล้วมาหาข้า จะได้เลือกสายที่เหมาะกับเจ้า: สายดาบ สายธนู นักเวทย์ หรือนักบวช" % ClassData.LINE_LEVEL)
			return
		var options: Array = []
		for id in ClassData.IDS:
			options.append({"label": String(ClassData.get_class_data(id).name), "action": func(): _show_line(id)})
		options.append({"label": "ไว้ก่อน"})
		dialog.say(speaker, "ถึงเวลาเลือกเส้นทางแล้ว! สายไหนที่ใจเจ้าเรียกหา? (เลือกแล้วเปลี่ยนไม่ได้ ไม่เสียค่าใช้จ่าย)", options)
		return
	if Game.adv() >= JobData.MAX_ADV:
		dialog.say(speaker, "เจ้าคือ \"%s\" — %s ถึงขั้นสูงสุดในตำนานแล้ว ไม่มีอะไรจะสอนอีกแล้วนะ!" % [Game.class_data().name, Game.class_data().title])
		return
	_show_advance()


func _show_line(id: StringName) -> void:
	var data := ClassData.get_class_data(id)
	var lines: PackedStringArray = [data.desc, "สกิลแรกที่จะได้:"]
	var shown := 0
	for skill in ClassData.pool(id):
		if shown >= 4:
			break
		lines.append("• %s (Lv.%d)" % [skill.name, int(skill.level)])
		shown += 1
	var options: Array = [{"label": "เลือกสายนี้", "action": func(): _confirm_line(id)}]
	for other in ClassData.IDS:
		if other != id:
			options.append({"label": "ดู%s" % ClassData.get_class_data(other).name, "action": func(): _show_line(other)})
	options.append({"label": "ไว้ก่อน"})
	dialog.say("ปรมาจารย์ผู้เปลี่ยนชะตา", "\n".join(lines), options)


func _confirm_line(id: StringName) -> void:
	if not Game.change_class(id):
		return
	AudioManager.play_sfx(&"quest_complete")
	hud.show_banner("เลือกสาย: %s!" % ClassData.get_class_data(id).name)
	Game.say("ได้สกิลของสายใหม่แล้ว! เปิดเมนูสกิลเพื่อจัดแถบ และไปหาปรมาจารย์สกิลเพื่ออัปสกิล", &"success")
	await go(&"town", true)
	if zone and zone.hero:
		VfxKit.level_up(zone, zone.hero.global_position)


func _show_advance() -> void:
	var speaker := "ปรมาจารย์ผู้เปลี่ยนชะตา"
	var info := Game.next_step()
	var need := Game.next_step_level()
	if int(Game.profile.level) < need:
		dialog.say(speaker, "ขั้นต่อไปของเจ้าคือ \"%s\" ฝึกฝนจนถึงเลเวล %d แล้วมาหาข้า จะได้สกิลชุดใหม่และพลังที่เพิ่มขึ้น" % [info.name, need])
		return
	var lines: PackedStringArray = ["พร้อมเปลี่ยนอาชีพแล้ว! \"%s\" — %s" % [info.name, info.title], info.desc]
	lines.append("ค่าสถานะเพิ่มทันที: %s  (พลังโจมตี/ป้องกัน/HP เพิ่มตามสาย)" % JobData.attr_text(info.attrs))
	lines.append("ค่าเปลี่ยนอาชีพ %d เหรียญ และได้แต้มสกิล +%d" % [Game.next_step_cost(), int(JobData.TIER_SKILL_POINTS[Game.adv()])])
	dialog.say(speaker, "\n".join(lines), [{"label": "เปลี่ยนอาชีพ", "action": func(): _confirm_advance()}, {"label": "ไว้ก่อน"}])


func _confirm_advance() -> void:
	if int(Game.profile.gold) < Game.next_step_cost():
		dialog.say("ปรมาจารย์ผู้เปลี่ยนชะตา", "เหรียญไม่พอนะ ต้องใช้ %d เหรียญ ไปล่ามอนสเตอร์มาก่อนแล้วกลับมาใหม่" % Game.next_step_cost())
		return
	if not Game.advance():
		return
	VfxKit.level_up(zone, zone.hero.global_position)
	AudioManager.play_sfx(&"quest_complete")
	hud.show_banner("เปลี่ยนอาชีพ: %s!" % Game.class_data().name)
	Game.say("เปลี่ยนอาชีพแล้ว! พลังและค่าสถานะเพิ่มขึ้น ปลดล็อกสกิลชุดใหม่", &"success")
	Game.save()


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
