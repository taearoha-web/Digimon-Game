class_name TowerScreen
extends CanvasLayer
## The Void Tower keeper: pick a floor to start from, climb, and spend Void
## Shards (re-roll wings, buy legendary gear or a large gem). Also shows the
## result after a climb.

signal climb_requested(start_floor: int)
signal go_home_requested()

var is_open := false
var _root: Control
var _body: Control
var _start_floor := 1
var _wing_box: VBoxContainer
var _shard_label: Label
var _msg: Label


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.1, 0.95)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 30
	panel.offset_top = 12
	panel.offset_right = -30
	panel.offset_bottom = -12
	frame.add_child(panel)
	_body = Control.new()
	panel.add_child(_body)


func open_lobby() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	var best := int(Game.tower().best)
	_start_floor = clampi(_start_floor, 1, maxi(1, best))
	if _start_floor not in TowerData.start_floors(best):
		_start_floor = 1
	_build_lobby()


func close_screen() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false


func _clear() -> void:
	for child in _body.get_children():
		child.queue_free()


func _column() -> VBoxContainer:
	var column := UIUtil.vbox(8)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18
	column.offset_right = -18
	column.offset_top = 12
	column.offset_bottom = -12
	_body.add_child(column)
	return column


func _build_lobby() -> void:
	_clear()
	var t := Game.tower()
	var column := _column()
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var title := UIUtil.label("หอคอยห้วงวิบัติ — ไต่ไม่รู้จบ", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_shard_label = UIUtil.label("ผลึกห้วงวิบัติ  %d" % int(t.shards), &"SubHeaderLabel")
	_shard_label.add_theme_color_override("font_color", Color("c58aff"))
	head.add_child(_shard_label)
	var close := UIUtil.button("ปิด", &"", Vector2(120, 54))
	close.pressed.connect(close_screen)
	head.add_child(close)
	var info := UIUtil.label("ชั้นสูงสุด %d · ปีนมาแล้ว %d ครั้ง\\nทุกชั้นมอนสเตอร์เลเวล 100 เก่งขึ้นเรื่อยๆ ชั้นที่ลงท้าย 0 คือจักรพรรดิห้วงวิบัติพร้อมลูกสมุน · ตายแล้วไม่เสียอะไร เก็บรางวัลที่ได้ไว้ · ชั้น 11, 21, 31... เป็นจุดเริ่มต้นที่ปลดล็อกแล้ว".replace("\\n", "\n") % [int(t.best), int(t.runs)], &"SmallLabel")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(info)
	var row := UIUtil.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	# Left: choose the start floor and climb.
	var left := UIUtil.vbox(8)
	left.custom_minimum_size = Vector2(380, 0)
	row.add_child(left)
	left.add_child(UIUtil.label("เริ่มปีนจากชั้น", &"SubHeaderLabel"))
	var floors := UIUtil.hbox(8)
	var scroll_floors := TouchScroll.new()
	scroll_floors.custom_minimum_size = Vector2(0, 74)
	scroll_floors.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_floors.add_child(floors)
	left.add_child(scroll_floors)
	for f in TowerData.start_floors(int(t.best)):
		var b := UIUtil.button("ชั้น %d" % f, &"PrimaryButton" if f == _start_floor else &"", Vector2(120, 60))
		b.pressed.connect(func():
			_start_floor = f
			_build_lobby())
		floors.add_child(b)
	var blocked := int(Game.profile.level) < TowerData.MIN_LEVEL
	var go := UIUtil.button("ขึ้นหอคอย (ชั้น %d)" % _start_floor, &"PrimaryButton", Vector2(0, 84))
	go.disabled = blocked
	if blocked:
		go.text = "ต้องเลเวล %d" % TowerData.MIN_LEVEL
	go.pressed.connect(func():
		close_screen()
		climb_requested.emit(_start_floor))
	left.add_child(go)
	var rewards := UIUtil.label("รางวัลต่อชั้น: เหรียญ %d × เลขชั้น · ผลึก 1 + ชั้น/10 (บอส +6) · EXP พาราก้อนจากมอนสเตอร์ · ดรอปเกียร์มีดาว / ปีก" % 2500, &"SmallLabel")
	rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(rewards)
	_msg = UIUtil.label("", &"BoldLabel")
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_msg)
	# Right: the shard shop.
	var right := UIUtil.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(UIUtil.label("ร้านผลึกห้วงวิบัติ", &"SubHeaderLabel"))
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := UIUtil.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	list.add_child(_shop_row("หีบเกียร์ตำนาน", "เกียร์เลเวล 100 หรือมีดาว (สูงสุด 20 ดาว) ระดับตำนานขึ้นไป (ลุ้นเทพนิยาย) ของสายอาชีพคุณ", TowerData.COST_GEAR, func(): _buy("gear")))
	list.add_child(_shop_row("อัญมณีเม็ดใหญ่", "สุ่มอัญมณีขนาดใหญ่ 1 เม็ด", TowerData.COST_GEM, func(): _buy("gem")))
	list.add_child(UIUtil.label("สุ่มค่าปีกใหม่ (ชนิดเดิม ค่าสุ่มใหม่ — ผลอาจแย่ลงได้) ราคา %d ผลึก/ครั้ง" % TowerData.COST_REROLL, &"BoldLabel"))
	_wing_box = UIUtil.vbox(6)
	list.add_child(_wing_box)
	_fill_wings()


func _shop_row(title: String, desc: String, cost: int, action: Callable) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var info := UIUtil.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	info.add_child(UIUtil.label(title, &"BoldLabel"))
	var d := UIUtil.label(desc, &"SmallLabel")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(d)
	var buy := UIUtil.button("%d ผลึก" % cost, &"PrimaryButton", Vector2(150, 56))
	buy.disabled = int(Game.tower().shards) < cost
	buy.pressed.connect(action)
	line.add_child(buy)
	return panel


func _wings() -> Array:
	var out: Array = []
	if Game.profile.equip.get("wings") is Dictionary:
		out.append(Game.profile.equip["wings"])
	for item in Game.profile.inv:
		if item.get("slot", "") == "wings":
			out.append(item)
	return out


func _fill_wings() -> void:
	UIUtil.clear(_wing_box)
	var wings := _wings()
	if wings.is_empty():
		_wing_box.add_child(UIUtil.label("ยังไม่มีปีก — ปีกดรอปจากบอสขุมนรก/ห้วงจักรวาลวิบัติ/จักรพรรดิในหอคอย", &"DimLabel"))
		return
	for item in wings:
		var panel := UIUtil.panel(&"CardPanel")
		var line := UIUtil.hbox(10)
		panel.add_child(line)
		var icon := TextureRect.new()
		icon.texture = ItemLook.icon(item)
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(icon)
		var info := UIUtil.vbox(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(info)
		var worn := " (สวมอยู่)" if Game.profile.equip.get("wings") == item else ""
		var name_label := UIUtil.label(ItemData.name_of(item) + worn, &"BoldLabel")
		name_label.add_theme_color_override("font_color", ItemData.color_of(item))
		info.add_child(name_label)
		info.add_child(UIUtil.label(", ".join(ItemData.stat_lines(item)), &"SmallLabel"))
		var b := UIUtil.button("สุ่มใหม่", &"", Vector2(120, 52))
		b.disabled = int(Game.tower().shards) < TowerData.COST_REROLL
		b.pressed.connect(func():
			var r := Game.tower_reroll_wings(item)
			_msg.text = "สุ่มค่าปีกใหม่แล้ว: " + ", ".join(ItemData.stat_lines(item)) if r == "ok" else r
			AudioManager.play_sfx(&"level_up" if r == "ok" else &"ui_click")
			_refresh())
		line.add_child(b)
		_wing_box.add_child(panel)


func _buy(kind: String) -> void:
	var r := Game.tower_buy(kind)
	if r.begins_with("ok:"):
		_msg.text = "ได้รับ " + r.trim_prefix("ok:")
		AudioManager.play_sfx(&"pickup")
	else:
		_msg.text = r
	_refresh()


func _refresh() -> void:
	var msg := _msg.text
	_build_lobby()
	_msg.text = msg


func show_result(result: Dictionary) -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	_clear()
	var column := _column()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var heading := UIUtil.label("จบการปีนหอคอย", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_font_size_override("font_size", 64)
	heading.add_theme_color_override("font_color", Color("c58aff"))
	column.add_child(heading)
	column.add_child(UIUtil.label("ถึงชั้น %d  (ผ่านมา %d ชั้น)" % [int(result.floor), int(result.cleared)], &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	if bool(result.new_best):
		var nb := UIUtil.label("สถิติใหม่! ชั้นสูงสุด %d" % int(result.best), &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
		nb.add_theme_color_override("font_color", Color("ffd84a"))
		column.add_child(nb)
	column.add_child(UIUtil.label("รางวัลรอบนี้: เหรียญ +%d · ผลึกห้วงวิบัติ +%d (รวม %d)" % [int(result.gold), int(result.shards), int(Game.tower().shards)], &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := UIUtil.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var again := UIUtil.button("ปีนอีกครั้ง", &"PrimaryButton", Vector2(320, 76))
	again.pressed.connect(func():
		close_screen()
		climb_requested.emit(_start_floor))
	buttons.add_child(again)
	var shop := UIUtil.button("ร้านผลึก", &"", Vector2(240, 76))
	shop.pressed.connect(func():
		is_open = true
		_build_lobby())
	buttons.add_child(shop)
	var home := UIUtil.button("กลับเมือง", &"", Vector2(240, 76))
	home.pressed.connect(func():
		close_screen()
		go_home_requested.emit())
	buttons.add_child(home)
