class_name GameMenu
extends CanvasLayer
## The in-game menu: character (stat points), bag + equipment, skills,
## quests and settings. Pauses the game while open.

signal closed()
signal title_requested()

const TABS := [
	["character", "ตัวละคร"], ["inventory", "กระเป๋า"], ["skills", "สกิล"], ["quests", "เควสต์"], ["achievements", "ความสำเร็จ"], ["settings", "ตั้งค่า"],
]

var is_open := false
var current_tab: StringName = &"inventory"

var _root: Control
var _content: Control
var _tab_buttons: Dictionary = {}
var _selected_index := -1
var _selected_slot := ""
var _detail: VBoxContainer
## Opened from the blacksmith: items can be enhanced and socketed.
var forge_mode := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_top = 12
	panel.offset_right = -16
	panel.offset_bottom = -12
	frame.add_child(panel)
	var row := UIUtil.hbox(14)
	panel.add_child(row)
	var tabs := UIUtil.vbox(8)
	tabs.custom_minimum_size = Vector2(190, 0)
	row.add_child(tabs)
	for tab in TABS:
		var b := UIUtil.button(String(tab[1]), &"", Vector2(0, 66))
		b.pressed.connect(func(): show_tab(StringName(tab[0])))
		tabs.add_child(b)
		_tab_buttons[StringName(tab[0])] = b
	tabs.add_child(UIUtil.spacer(false))
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(0, 66))
	close.pressed.connect(close_menu)
	tabs.add_child(close)
	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_content)
	Game.profile_changed.connect(func(): if is_open: _rebuild())
	Game.inventory_changed.connect(func(): if is_open: _rebuild())
	Game.quest_changed.connect(func(): if is_open: _rebuild())


func open_menu(tab: StringName = &"inventory") -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	show_tab(tab)


func close_menu() -> void:
	forge_mode = false
	is_open = false
	_root.visible = false
	get_tree().paused = false
	AudioManager.play_ui(&"ui_cancel")
	closed.emit()


func show_tab(tab: StringName) -> void:
	current_tab = tab
	_selected_index = -1
	_selected_slot = ""
	_rebuild()


func _rebuild() -> void:
	for key in _tab_buttons:
		_tab_buttons[key].disabled = key == current_tab
	UIUtil.clear(_content)
	match current_tab:
		&"character": _build_character()
		&"inventory": _build_inventory()
		&"skills": _build_skills()
		&"quests": _build_quests()
		&"achievements": _build_achievements()
		&"settings": _build_settings()


# ---------------------------------------------------------------------------
# Character
# ---------------------------------------------------------------------------

func _build_character() -> void:
	var p := Game.profile
	var stats := Game.stats_now()
	var data := Game.class_data()
	var row := UIUtil.hbox(20)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(row)
	var left := UIUtil.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(UIUtil.label("%s  Lv.%d  (%s)" % [p.name, p.level, data.name], &"HeaderLabel"))
	var points := UIUtil.label("แต้มสถานะที่ใช้ได้: %d" % int(p.points), &"SubHeaderLabel")
	left.add_child(points)
	var names := {"str": "STR พลัง", "int": "INT ปัญญา", "dex": "DEX ความคล่อง", "vit": "VIT ความทนทาน"}
	var notes := {"str": "เพิ่มพลังโจมตีของนักรบ", "int": "เพิ่มพลังเวทและ MP", "dex": "เพิ่มคริติคอล หลบหลีก และความเร็วสกิล", "vit": "เพิ่ม HP และพลังป้องกัน"}
	for key in ["str", "int", "dex", "vit"]:
		var line := UIUtil.hbox(10)
		left.add_child(line)
		var label := UIUtil.label("%s  %d" % [names[key], int(stats.attrs[key])], &"BoldLabel")
		label.custom_minimum_size = Vector2(250, 0)
		line.add_child(label)
		var plus := UIUtil.button("+", &"PrimaryButton", Vector2(70, 56))
		plus.disabled = int(p.points) <= 0
		plus.pressed.connect(func(): Game.spend_point(key))
		line.add_child(plus)
		line.add_child(UIUtil.label(notes[key], &"SmallLabel"))
	var right := UIUtil.vbox(6)
	right.custom_minimum_size = Vector2(380, 0)
	row.add_child(right)
	right.add_child(UIUtil.label("ค่าพลัง", &"SubHeaderLabel"))
	for line in [
		["HP", "%d / %d" % [p.hp, stats.max_hp]], ["MP", "%d / %d" % [p.mp, stats.max_mp]],
		["พลังโจมตี", "%d" % int(stats.atk)], ["พลังป้องกัน", "%d" % int(stats.def)],
		["คริติคอล", "%.1f%%" % (float(stats.crit) * 100.0)], ["หลบหลีก", "%.1f%%" % (float(stats.dodge) * 100.0)], ["ความเร็วสกิล", "+%.1f%%" % (float(stats.haste) * 100.0)],
		["EXP", "%d / %d" % [p.exp, HeroStats.exp_to_next(p.level)]], ["สังหารมอนสเตอร์", "%d ตัว" % int(p.kills)],
		["เวลาเล่น", UIUtil.format_play_time(float(p.play_time))],
	]:
		var r := UIUtil.hbox(8)
		var k := UIUtil.label(line[0], &"DimLabel")
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(k)
		r.add_child(UIUtil.label(line[1], &"BoldLabel"))
		right.add_child(r)


# ---------------------------------------------------------------------------
# Inventory & equipment
# ---------------------------------------------------------------------------

func _build_inventory() -> void:
	var row := UIUtil.hbox(14)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(row)
	# Paper doll + equipment slots
	var equip := UIUtil.vbox(6)
	equip.custom_minimum_size = Vector2(240, 0)
	row.add_child(equip)
	var preview := HeroPreview.new(Vector2i(240, 230))
	equip.add_child(preview)
	preview.show_hero(Game.class_id(), Game.profile.equip, "", Game.profile.get("look", {}))
	var slots := GridContainer.new()
	slots.columns = 3
	slots.add_theme_constant_override("h_separation", 6)
	slots.add_theme_constant_override("v_separation", 6)
	equip.add_child(slots)
	for slot in ItemData.SLOTS:
		var item: Variant = Game.profile.equip.get(slot)
		var b := Button.new()
		b.custom_minimum_size = Vector2(74, 74)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 58)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		if item != null:
			b.icon = ItemLook.icon(item)
			b.tooltip_text = ItemData.name_of(item)
			b.modulate = Color.WHITE.lerp(ItemData.color_of(item), 0.35)
		else:
			b.text = ItemData.SLOT_NAMES[slot]
			b.add_theme_font_size_override("font_size", 16)
			b.modulate = Color(1, 1, 1, 0.7)
		b.pressed.connect(func():
			_selected_slot = slot
			_selected_index = -1
			_refresh_detail())
		slots.add_child(b)
	# Bag grid
	var middle := UIUtil.vbox(6)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(middle)
	middle.add_child(UIUtil.label("กระเป๋า (%d/%d)" % [Game.profile.inv.size(), Game.bag_size()], &"SubHeaderLabel"))
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for i in Game.bag_size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(90, 92)
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 56)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		if i < Game.profile.inv.size():
			var item: Dictionary = Game.profile.inv[i]
			b.icon = ItemLook.icon(item)
			b.text = ("×%d" % int(item.count)) if ItemData.is_stackable(item) else ("Lv.%d" % int(item.level))
			b.add_theme_color_override("font_color", ItemData.color_of(item))
			b.add_theme_font_size_override("font_size", 17)
			b.modulate = Color.WHITE.lerp(ItemData.color_of(item), 0.3)
			b.pressed.connect(func():
				_selected_index = i
				_selected_slot = ""
				_refresh_detail())
		else:
			b.disabled = true
		grid.add_child(b)
	var detail_scroll := TouchScroll.new()
	detail_scroll.custom_minimum_size = Vector2(250, 0)
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(detail_scroll)
	_detail = UIUtil.vbox(8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail)
	_refresh_detail()


func _refresh_detail() -> void:
	if _detail == null or not is_instance_valid(_detail):
		return
	UIUtil.clear(_detail)
	var item: Variant = null
	if _selected_slot != "":
		item = Game.profile.equip.get(_selected_slot)
	elif _selected_index >= 0 and _selected_index < Game.profile.inv.size():
		item = Game.profile.inv[_selected_index]
	if item == null:
		_detail.add_child(UIUtil.label("แตะไอเทมเพื่อดูรายละเอียด", &"DimLabel"))
		return
	var big := TextureRect.new()
	big.texture = ItemLook.icon(item)
	big.custom_minimum_size = Vector2(0, 72)
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail.add_child(big)
	var title := UIUtil.label(ItemData.name_of(item), &"SubHeaderLabel")
	title.add_theme_color_override("font_color", ItemData.color_of(item))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(title)
	if item.get("kind", "") == "equip":
		_detail.add_child(UIUtil.label("%s • %s • เลเวล %d" % [ItemData.SLOT_NAMES[item.slot], ItemData.RARITY_NAMES[int(item.rarity)], int(item.level)], &"SmallLabel"))
		if item.get("class", "") != "":
			_detail.add_child(UIUtil.label("อาชีพ: " + String(ClassData.get_class_data(StringName(item["class"])).name), &"SmallLabel"))
	for line in ItemData.detail_lines(item):
		var detail_label := UIUtil.label(line, &"BoldLabel" if not line.begins_with("เซ็ต") else &"SmallLabel")
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(detail_label)
	if item.get("kind", "") == "equip" and str(item.get("set", "")) != "":
		var counts := HeroStats.set_counts(Game.profile)
		var set_label := UIUtil.label("สวมอยู่ %d/4 ชิ้น: 2=HP • 3=โจมตี • 4=ป้องกัน+คริ" % int(counts.get(item.set, 0)), &"DimLabel")
		set_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		set_label.custom_minimum_size = Vector2(240, 0)
		_detail.add_child(set_label)
	if forge_mode and item.get("kind", "") == "equip":
		_build_forge_buttons(item)
	if item.get("kind", "") == "equip":
		var problem := Game.equip_problem(item)
		var equipped := _selected_slot != ""
		if equipped:
			var take := UIUtil.button("ถอด", &"", Vector2(0, 60))
			take.pressed.connect(func(): Game.unequip(_selected_slot); _selected_slot = ""; _rebuild())
			_detail.add_child(take)
		else:
			var wear := UIUtil.button("สวมใส่" if problem == "" else problem, &"PrimaryButton", Vector2(0, 60))
			wear.disabled = problem != ""
			wear.pressed.connect(func(): Game.equip_from_bag(_selected_index); _selected_index = -1; _rebuild())
			_detail.add_child(wear)
			_detail.add_child(UIUtil.label("ราคาขาย: %d" % ItemData.sell_price(item), &"SmallLabel"))
			var sell := UIUtil.button("ขาย", &"", Vector2(0, 56))
			sell.pressed.connect(func(): Game.sell_item(_selected_index); _selected_index = -1; _rebuild())
			_detail.add_child(sell)
	elif item.get("kind", "") == "gem":
		_detail.add_child(UIUtil.label("ไปที่ช่างตีเหล็กเพื่อใส่ลงช่องในอาวุธ/ชุด", &"DimLabel"))
		var sell_gem := UIUtil.button("ขาย (%d)" % ItemData.unit_sell_price(item), &"", Vector2(0, 56))
		sell_gem.pressed.connect(func(): Game.sell_item(_selected_index, 1); _selected_index = -1; _rebuild())
		_detail.add_child(sell_gem)
	else:
		var use := UIUtil.button("ใช้", &"PrimaryButton", Vector2(0, 60))
		use.pressed.connect(func(): _use_potion(_selected_index))
		_detail.add_child(use)


func _build_forge_buttons(item: Dictionary) -> void:
	var plus := int(item.get("plus", 0))
	if plus < ItemData.MAX_PLUS:
		_detail.add_child(UIUtil.label("ค่าตี %d เหรียญ" % ItemData.enhance_cost(item), &"DimLabel"))
		var btn := UIUtil.button("ตีบวก +%d  (%d%%)" % [plus + 1, int(ItemData.enhance_chance(plus) * 100.0)], &"PrimaryButton", Vector2(0, 58))
		btn.pressed.connect(func():
			var result := Game.enhance_item(item)
			match result:
				"ok":
					Game.say("ตีบวกสำเร็จ! %s" % ItemData.name_of(item), &"success")
					AudioManager.play_sfx(&"level_up")
				"fail":
					Game.say("ตีบวกพลาด... (เสียแค่เหรียญ ไอเทมไม่หาย)", &"warning")
				_:
					Game.say(result, &"warning")
			_rebuild())
		_detail.add_child(btn)
	var free := int(item.get("sockets", 0)) - (item.get("gems", []) as Array).size()
	if free > 0:
		var seen := {}
		for i in Game.profile.inv.size():
			var gem: Dictionary = Game.profile.inv[i]
			if gem.get("kind", "") == "gem" and not seen.has(gem.id):
				seen[gem.id] = true
				var info := ItemData.gem_info(gem)
				var put := UIUtil.button("ใส่ %s ×%d" % [info.name, int(gem.count)], &"", Vector2(0, 50))
				put.add_theme_color_override("font_color", info.color)
				put.pressed.connect(func():
					if Game.socket_gem(item, i):
						Game.say("ใส่อัญมณีแล้ว", &"success")
					_rebuild())
				_detail.add_child(put)


func _use_potion(index: int) -> void:
	var item: Dictionary = Game.profile.inv[index]
	var def: Dictionary = ItemData.POTIONS[item.id]
	if def.has("town"):
		close_menu()
		var main := get_tree().current_scene
		if main and main.has_method("use_town_scroll"):
			Game.remove_item_at(index)
			main.use_town_scroll()
		return
	Game.use_potion_at(index)
	AudioManager.play_sfx(&"item_use")
	_selected_index = -1
	_rebuild()


# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------

func _build_skills() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UIUtil.label("แถบสกิล: เลือกใส่ได้ 4 ช่อง   •   แต้มสกิล %d (ไปอัปที่ปรมาจารย์สกิลในหมู่บ้าน)" % int(Game.profile.skill_points), &"SubHeaderLabel"))
	var bar_row := UIUtil.hbox(8)
	box.add_child(bar_row)
	var bar: Array = Game.loadout_skills()
	for i in bar.size():
		var slot_panel := UIUtil.panel(&"CardPanel")
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot_label := UIUtil.label("%d. %s" % [i + 1, bar[i].name if not bar[i].is_empty() else "— ว่าง —"], &"BoldLabel")
		slot_label.clip_text = true
		slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot_panel.add_child(slot_label)
		bar_row.add_child(slot_panel)
	var pool: Array = Game.skill_pool()
	for skill in pool:
		var panel := UIUtil.panel(&"CardPanel")
		box.add_child(panel)
		var line := UIUtil.hbox(10)
		panel.add_child(line)
		var info := UIUtil.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(info)
		var unlocked := Game.skill_unlocked(skill)
		var rank := Game.effective_rank(skill)
		var title_row := UIUtil.hbox(12)
		info.add_child(title_row)
		var title_label := UIUtil.label(String(skill.name), &"BoldLabel")
		if not unlocked:
			title_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
		title_row.add_child(title_label)
		if unlocked:
			title_row.add_child(StarRow.new(rank, Game.MAX_SKILL_RANK, 18.0))
		else:
			title_row.add_child(UIUtil.label(Game.skill_lock_reason(skill), &"SmallLabel"))
		var desc := UIUtil.label("%s  •  MP %d  •  คูลดาวน์ %.0f วิ" % [skill.desc, int(skill.mp), float(skill.cd)], &"SmallLabel")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)
		var equipped := Game.loadout().find(skill.id)
		for slot in ClassData.SLOTS:
			var b := UIUtil.button(str(slot + 1), &"PrimaryButton" if equipped == slot else &"", Vector2(56, 56))
			b.disabled = not unlocked or equipped == slot
			b.pressed.connect(func():
				if Game.equip_skill(skill.id, slot):
					AudioManager.play_ui(&"ui_select"))
			line.add_child(b)
	var passives: Array = Game.passive_pool()
	if not passives.is_empty():
		box.add_child(UIUtil.label("สกิลติดตัว (ทำงานเองตลอด)", &"SubHeaderLabel"))
	for skill in passives:
		var panel := UIUtil.panel(&"CardPanel")
		box.add_child(panel)
		var info := UIUtil.vbox(2)
		panel.add_child(info)
		var unlocked := Game.skill_unlocked(skill)
		var rank := Game.effective_rank(skill)
		var title_row := UIUtil.hbox(12)
		info.add_child(title_row)
		var title_label := UIUtil.label(String(skill.name), &"BoldLabel")
		if not unlocked:
			title_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
		title_row.add_child(title_label)
		if unlocked:
			title_row.add_child(StarRow.new(rank, Game.MAX_SKILL_RANK, 18.0))
		else:
			title_row.add_child(UIUtil.label(Game.skill_lock_reason(skill), &"SmallLabel"))
		info.add_child(UIUtil.label(String(skill.desc), &"SmallLabel"))


# ---------------------------------------------------------------------------
# Quests
# ---------------------------------------------------------------------------

func _build_quests() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UIUtil.label("เควสต์รายวัน (รับรางวัลที่กระดานในหมู่บ้าน)", &"SubHeaderLabel"))
	var reward := GoalsData.reward_for(int(Game.profile.level))
	var streak := Game.daily_streak()
	box.add_child(UIUtil.label("ติดต่อกัน %d วัน • โบนัสรางวัล +%d%% • ทำครบ 3 งานรับหีบรางวัล" % [streak, int(minf(maxf(float(streak) - 1.0, 0.0), 6.0) * 10.0)], &"DimLabel"))
	for entry in Game.daily().quests:
		var template := Game.daily_template(entry.id)
		var target := Game.daily_target(entry)
		var done: bool = int(entry.progress) >= target
		var dpanel := UIUtil.panel(&"CardPanel")
		box.add_child(dpanel)
		var dcol := UIUtil.vbox(2)
		dpanel.add_child(dcol)
		var state := "รับรางวัลแล้ว ✔" if entry.claimed else ("เสร็จแล้ว — ไปรับที่กระดาน" if done else "%d / %d" % [int(entry.progress), target])
		var dtitle := UIUtil.label("%s — %s" % [template.name, state], &"BoldLabel")
		if entry.claimed:
			dtitle.add_theme_color_override("font_color", UIPalette.SUCCESS)
		dcol.add_child(dtitle)
		dcol.add_child(UIUtil.label(String(template.desc) % target, &"SmallLabel"))
		dcol.add_child(UIUtil.label("รางวัล: EXP %d • เหรียญ %d" % [int(reward.exp), int(reward.gold)], &"DimLabel"))
	box.add_child(UIUtil.label("เควสต์เนื้อเรื่อง (รับจากผู้ใหญ่บ้านในหมู่บ้าน)", &"SubHeaderLabel"))
	for id in QuestData.ORDER:
		var quest := QuestData.get_quest(id)
		var status := Game.quest_status(id)
		var panel := UIUtil.panel(&"CardPanel")
		box.add_child(panel)
		var col := UIUtil.vbox(2)
		panel.add_child(col)
		var state_text: String = {"new": "ยังไม่ได้รับ", "active": "กำลังทำ", "ready": "เสร็จแล้ว — กลับไปรายงาน", "done": "สำเร็จแล้ว ✔"}[status]
		var title := UIUtil.label("%s  (Lv.%d+)  — %s" % [quest.name, int(quest.level), state_text], &"BoldLabel")
		if status == "done":
			title.add_theme_color_override("font_color", UIPalette.SUCCESS)
		col.add_child(title)
		var detail := UIUtil.label(quest.desc, &"SmallLabel")
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(detail)
		if status == "active" or status == "ready":
			col.add_child(UIUtil.label("ความคืบหน้า: %d / %d  (%s)" % [int(Game.quest_state(id).get("progress", 0)), int(quest.count), MonsterData.get_monster(StringName(quest.target)).name], &"DimLabel"))
		col.add_child(UIUtil.label("รางวัล: EXP %d • เหรียญ %d" % [int(quest.exp), int(quest.gold)], &"DimLabel"))


# ---------------------------------------------------------------------------
# Achievements
# ---------------------------------------------------------------------------

func _build_achievements() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(scroll)
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var done_count := 0
	for ach in GoalsData.ACHIEVEMENTS:
		if Game.profile.get("ach", {}).has(ach.id):
			done_count += 1
	box.add_child(UIUtil.label("ความสำเร็จ  %d / %d" % [done_count, GoalsData.ACHIEVEMENTS.size()], &"HeaderLabel"))
	for ach in GoalsData.ACHIEVEMENTS:
		var done: bool = Game.profile.get("ach", {}).has(ach.id)
		var panel := UIUtil.panel(&"CardPanel")
		box.add_child(panel)
		var col := UIUtil.vbox(2)
		panel.add_child(col)
		var value := mini(Game.achievement_value(ach.check), int(ach.goal))
		var title := UIUtil.label("%s%s" % ["✔ " if done else "", ach.name], &"BoldLabel")
		if done:
			title.add_theme_color_override("font_color", UIPalette.SUCCESS)
		col.add_child(title)
		col.add_child(UIUtil.label("%s  (%d / %d)" % [ach.desc, value, int(ach.goal)], &"SmallLabel"))
		var parts: PackedStringArray = []
		if ach.reward.has("gold"):
			parts.append("เหรียญ %d" % int(ach.reward.gold))
		if ach.reward.has("sp"):
			parts.append("แต้มสกิล %d" % int(ach.reward.sp))
		if ach.reward.has("gem"):
			parts.append("อัญมณี")
		col.add_child(UIUtil.label("รางวัล: " + " • ".join(parts), &"DimLabel"))


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

func _build_settings() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(scroll)
	var box := UIUtil.vbox(12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UIUtil.label("ตั้งค่า", &"HeaderLabel"))
	for entry in [["เพลง", "Music"], ["เสียงเอฟเฟกต์", "SFX"]]:
		var line := UIUtil.hbox(14)
		box.add_child(line)
		var label := UIUtil.label(entry[0], &"BoldLabel")
		label.custom_minimum_size = Vector2(220, 0)
		line.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(420, 40)
		var bus := AudioServer.get_bus_index(entry[1])
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus)) if bus >= 0 else 1.0
		slider.value_changed.connect(func(v: float):
			if bus >= 0:
				AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.001))))
		line.add_child(slider)
	# Camera speed
	var cam_line := UIUtil.hbox(14)
	box.add_child(cam_line)
	var cam_label := UIUtil.label("ความเร็วหมุนกล้อง", &"BoldLabel")
	cam_label.custom_minimum_size = Vector2(220, 0)
	cam_line.add_child(cam_label)
	var cam_slider := HSlider.new()
	cam_slider.min_value = 0.4
	cam_slider.max_value = 2.5
	cam_slider.step = 0.1
	cam_slider.value = GameSettings.camera_speed
	cam_slider.custom_minimum_size = Vector2(420, 40)
	cam_slider.value_changed.connect(func(v: float):
		GameSettings.camera_speed = v
		GameSettings.save_settings())
	cam_line.add_child(cam_slider)
	# Graphics quality
	var q_line := UIUtil.hbox(10)
	box.add_child(q_line)
	var q_label := UIUtil.label("คุณภาพกราฟิก", &"BoldLabel")
	q_label.custom_minimum_size = Vector2(220, 0)
	q_line.add_child(q_label)
	for i in 3:
		var qb := UIUtil.button(String(GameSettings.QUALITY_NAMES[i]), &"PrimaryButton" if GameSettings.quality == i else &"", Vector2(180, 56))
		qb.pressed.connect(func():
			GameSettings.quality = i
			GameSettings.save_settings()
			GameSettings.apply_live(get_tree())
			Game.say("ตั้งคุณภาพ: %s (ต้นไม้และหญ้าจะเปลี่ยนเมื่อเข้าแมพใหม่)" % GameSettings.QUALITY_NAMES[i], &"info")
			_rebuild())
		q_line.add_child(qb)
	var vib := CheckButton.new()
	vib.text = "สั่นเมื่อโดนตี (มือถือ)"
	vib.button_pressed = GameSettings.vibration
	vib.toggled.connect(func(on: bool):
		GameSettings.vibration = on
		GameSettings.save_settings())
	box.add_child(vib)
	var save := UIUtil.button("บันทึกเกม", &"PrimaryButton", Vector2(320, 66))
	save.pressed.connect(func():
		Game.save()
		Game.say("บันทึกเกมแล้ว", &"success"))
	box.add_child(save)
	# Save backup: the save lives in this browser only, so offer copy / paste.
	var backup := UIUtil.button("สำรอง / นำเข้าเซฟ", &"", Vector2(320, 66))
	backup.pressed.connect(_open_backup)
	box.add_child(backup)
	if int(Game.profile.flags.get("ending_seen", 0)) > 0:
		var ending := UIUtil.button("ดูตอนจบอีกครั้ง", &"", Vector2(320, 66))
		ending.pressed.connect(func():
			close_menu()
			Game.ending_requested.emit())
		box.add_child(ending)
	var title := UIUtil.button("กลับหน้าหลัก", &"", Vector2(320, 66))
	title.pressed.connect(func():
		Game.save()
		close_menu()
		title_requested.emit())
	box.add_child(title)


## A text box holding the save as a code: copy it somewhere safe, or paste a code and import.
func _open_backup() -> void:
	UIUtil.clear(_content)
	var box := UIUtil.vbox(10)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(box)
	box.add_child(UIUtil.label("สำรองเซฟ", &"HeaderLabel"))
	box.add_child(UIUtil.label("กดค้างที่กล่องข้อความเพื่อคัดลอก เก็บรหัสนี้ไว้ในโน้ต แล้ววางกลับมาเพื่อนำเข้าบนเครื่องไหนก็ได้", &"SmallLabel"))
	var edit := TextEdit.new()
	edit.custom_minimum_size = Vector2(0, 280)
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text = Game.export_code()
	box.add_child(edit)
	var row := UIUtil.hbox(10)
	box.add_child(row)
	var copy := UIUtil.button("คัดลอกรหัส", &"PrimaryButton", Vector2(240, 60))
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(edit.text)
		Game.say("คัดลอกแล้ว", &"success"))
	row.add_child(copy)
	var imp := UIUtil.button("นำเข้าจากกล่อง", &"", Vector2(260, 60))
	imp.pressed.connect(func():
		if Game.import_code(edit.text):
			Game.say("นำเข้าเซฟสำเร็จ!", &"success")
			_rebuild()
		else:
			Game.say("รหัสไม่ถูกต้อง", &"warning"))
	row.add_child(imp)
	var back := UIUtil.button("กลับ", &"", Vector2(160, 60))
	back.pressed.connect(_rebuild)
	row.add_child(back)
