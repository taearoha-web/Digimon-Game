class_name GameMenu
extends CanvasLayer
## The in-game menu: character (stat points), bag + equipment, skills,
## quests and settings. Pauses the game while open.

signal closed()
signal title_requested()
## The party raid (RaidData) from the menu: Main opens its keeper's screen.
signal raid_requested()
## The mechanics dungeon (DungeonData) from the menu: Main opens its keeper's screen.
signal dungeon_requested()
## เขาวงกตหนึ่งในใต้หล้า from its board tab: Main sends the hero in.
signal maze_requested()

## The event pages (DragonHunt, WeeklyCollect, LoyKrathong): not in the tab bar, opened
## from their lines in the HUD's event box under the minimap while the event runs.
const EVENT_PAGES := [["hunt", DragonHuntView.TAB_NAME], ["weekly", WeeklyCollect.NAME], ["loyk", LoyKrathongView.TAB_NAME]]
const TABS := [
	["character", "ตัวละคร"], ["inventory", "กระเป๋า"], ["skills", "สกิล"], ["quests", "เควสต์"], ["pass", "ภารกิจ & บัตร"], ["achievements", "ความสำเร็จ"], ["titles", "ตำแหน่ง"], ["mounts", "สัตว์ขี่"], ["league", "ลีกกิลด์"], ["reward", RewardShop.SHOP_NAME], ["maze", MazeBoardView.TAB_NAME], ["settings", "ตั้งค่า"],
]

var is_open := false
var current_tab: StringName = &"inventory"

var _root: Control
var _content: Control
var _tab_buttons: Dictionary = {}
var _selected_index := -1
var _selected_slot := ""
var _detail: VBoxContainer
## Buttons for the selected item, pinned above the scrolling detail text.
var _actions: VBoxContainer
var _item_buttons: Array[Dictionary] = []
## The tab's main scroll list; a rebuild (after a sale, a point spent, ...)
## puts it back where it was instead of jumping to the top.
var _page_scroll: TouchScroll
## Keep each stat's typed quantity when the menu refreshes after allocation.
var _stat_amounts: Dictionary = {}
## Opened from the blacksmith: items can be enhanced and socketed.
var forge_mode := false
## At the forge: the ผสมชุดเซต section (250★ set pieces) shows instead of the bag grid.
var set_craft_open := false
## The divine piece picked per set slot in ผสมชุดเซต (slot -> the live item).
var _set_picks := {}
## The bag tab shows แผงของฉัน (PlayerStallView) instead of the bag; its picked item,
## price and count survive rebuilds in stall_view.
var stall_open := false
var stall_view := {}
## "เลือกหลายชิ้น": bag taps pick gear to sell together; the picked bag indices.
var multi_sell := false
var _multi_pick := {}
## The open ใส่อัญมณี sheet (GemPicker), if any.
var _gem_picker: GemPicker


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
	# The tab column scrolls (many tabs never fit a phone screen in landscape); the close
	# button stays below it, always on screen.
	var column := UIUtil.vbox(8)
	column.custom_minimum_size = Vector2(190, 0)
	row.add_child(column)
	# TouchScroll: a finger drag anywhere on the column scrolls it, even from a button.
	var tab_scroll := TouchScroll.new()
	tab_scroll.name = "TabScroll"
	tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tab_scroll)
	var tabs := UIUtil.vbox(8 if TABS.size() <= 8 else 5)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.add_child(tabs)
	for tab in TABS:
		var b := UIUtil.button(String(tab[1]), &"", Vector2(0, 54 if TABS.size() <= 8 else 46))
		b.pressed.connect(func(): show_tab(StringName(tab[0])))
		tabs.add_child(b)
		_tab_buttons[StringName(tab[0])] = b
	var raid := UIUtil.button(RaidData.SHORT, &"", Vector2(0, 54))
	raid.add_theme_color_override("font_color", Color("ff9aa6"))
	raid.pressed.connect(func():
		close_menu()
		raid_requested.emit())
	tabs.add_child(raid)
	var tomb := UIUtil.button(DungeonData.SHORT, &"", Vector2(0, 54 if TABS.size() <= 8 else 46))
	tomb.add_theme_color_override("font_color", Color("8af0b0"))
	tomb.pressed.connect(func():
		close_menu()
		dungeon_requested.emit())
	tabs.add_child(tomb)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(0, 60))
	close.name = "CloseMenu"
	close.pressed.connect(close_menu)
	column.add_child(close)
	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_content)
	# Room on the right for the corner close button (X) above the content.
	var gutter := Control.new()
	gutter.custom_minimum_size = Vector2(40, 0)
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gutter)
	# A close button in the top-right corner too, always on screen.
	var corner := UIUtil.button("✕", &"PrimaryButton", Vector2(60, 60))
	corner.name = "CloseCorner"
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	corner.offset_left = -62
	corner.offset_right = -2
	corner.offset_top = 2
	corner.offset_bottom = 62
	corner.add_theme_font_size_override("font_size", 30)
	corner.pressed.connect(close_menu)
	frame.add_child(corner)
	Game.profile_changed.connect(_queue_rebuild)
	Game.inventory_changed.connect(_queue_rebuild)
	Game.quest_changed.connect(_queue_rebuild)


## The game keeps running under the menu (the owner's order): the hero goes on hunting
## (auto-hunt, EXP, drops) while the bag, the shop tabs or the board are open; taps on
## the world are held back while it is up (Main._screen_open).
func open_menu(tab: StringName = &"inventory") -> void:
	is_open = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	show_tab(tab)


func close_menu() -> void:
	forge_mode = false
	multi_sell = false
	_multi_pick.clear()
	set_craft_open = false
	_set_picks.clear()
	stall_open = false
	is_open = false
	if _gem_picker != null and is_instance_valid(_gem_picker):
		_gem_picker.queue_free()
	_gem_picker = null
	_build_gen += 1
	_root.visible = false
	# A closed screen keeps nothing: its lists are built again when it opens.
	UIUtil.clear(_content)
	# The menu never pauses (open_menu), so closing it leaves a pause someone else holds
	# (a result screen, the ending) alone.
	AudioManager.play_ui(&"ui_cancel")
	closed.emit()


func show_tab(tab: StringName) -> void:
	_page_scroll = null
	current_tab = tab
	stall_open = false
	multi_sell = false
	_multi_pick.clear()
	_selected_index = -1
	_selected_slot = ""
	_rebuild()



## A long page (the skill page) builds its first rows with the menu and the rest a few a
## frame after, unless it was rebuilt below the top (_rebuild keeps the scroll there).
const FIRST_ROWS := 5
const ROWS_PER_FRAME := 8
var _build_gen := 0
var _slice_build := true


## Several signals usually fire for one action (an upgrade changes the skill points and
## the gold, a sale the bag and the gold); rebuild once, at the end of the frame.
var _rebuild_queued := false


func _queue_rebuild() -> void:
	if not is_open or _rebuild_queued:
		return
	_rebuild_queued = true
	(func():
		_rebuild_queued = false
		if is_open:
			_rebuild()).call_deferred()

func _rebuild() -> void:
	var keep_y := _page_scroll.retained_vertical_position() if is_instance_valid(_page_scroll) else 0
	_page_scroll = null
	for key in _tab_buttons:
		_tab_buttons[key].disabled = key == current_tab
	_mark_pass_tab()
	UIUtil.clear(_content)
	_slice_build = keep_y <= 0
	_build_gen += 1
	match current_tab:
		&"character": _build_character()
		&"inventory":
			if stall_open and not forge_mode:
				_build_stall()
			else:
				_build_inventory()
		&"skills": _build_skills()
		&"quests": _build_quests()
		&"pass": _page_scroll = DailyPassView.build(_content, _queue_rebuild)
		&"achievements": _build_achievements()
		&"titles": _build_titles()
		&"mounts": _build_mounts()
		&"league":
			var page := UIUtil.vbox(8)
			page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_content.add_child(page)
			_page_scroll = LeagueView.build(page, _queue_rebuild) as TouchScroll
		&"reward":
			var page := UIUtil.vbox(8)
			page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_content.add_child(page)
			_page_scroll = RewardShopView.build(page, _queue_rebuild) as TouchScroll
		&"hunt": _page_scroll = DragonHuntView.build(_content, _queue_rebuild)
		&"weekly":
			var page := UIUtil.vbox(8)
			page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_content.add_child(page)
			_page_scroll = WeeklyCollectView.build(page, _queue_rebuild) as TouchScroll
		&"loyk": _page_scroll = LoyKrathongView.build(_content, _queue_rebuild, close_menu)
		&"maze": _page_scroll = MazeBoardView.build(_content, _queue_rebuild, func():
			close_menu()
			maze_requested.emit())
		&"settings": _build_settings()
	if is_instance_valid(_page_scroll):
		_page_scroll.restore_vertical_position(keep_y)


## The "ภารกิจ & บัตร" tab shows a red dot while something is waiting to be claimed.
func _mark_pass_tab() -> void:
	_mark_tab(DailyPassView.TAB_ID, DailyPassView.TAB_NAME, Game.has_profile and DailyPass.claimable() > 0)
	_mark_tab(DragonHuntView.TAB_ID, DragonHuntView.TAB_NAME, Game.has_profile and DragonHunt.claimable() > 0)
	_mark_tab(LoyKrathongView.TAB_ID, LoyKrathongView.TAB_NAME, Game.has_profile and LoyKrathong.on() and LoyKrathong.entry_problem() == "")


func _mark_tab(id: StringName, text: String, ready: bool) -> void:
	var b: Button = _tab_buttons.get(id)
	if b == null:
		return
	b.text = text + (" ●" if ready else "")
	for key in ["font_color", "font_disabled_color", "font_hover_color", "font_pressed_color"]:
		if ready:
			b.add_theme_color_override(key, UIPalette.DANGER)
		else:
			b.remove_theme_color_override(key)


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
	var left_scroll := TouchScroll.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(left_scroll)
	_page_scroll = left_scroll
	var left := UIUtil.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)
	left.add_child(UIUtil.label("%s  Lv.%d  (%s)" % [p.name, p.level, data.name], &"HeaderLabel"))
	if String(data.get("title", "")) != "":
		var class_line := UIUtil.label(("✦ ขั้นเทพเจ้า · %s ✦" if Game.is_god() else "ฉายา: %s") % data.title, &"BoldLabel" if Game.is_god() else &"SmallLabel")
		class_line.name = "ClassTitle"
		if Game.is_god():
			class_line.add_theme_color_override("font_color", data.color)
		left.add_child(class_line)
	# The class's party role (ClassRoles) and the roles the party brings right now.
	var role_text := ClassRoles.line(Game.class_id())
	if role_text != "":
		var role_line := UIUtil.label("บทบาทในปาร์ตี้ — " + role_text, &"BoldLabel")
		role_line.name = "ClassRole"
		role_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role_line.add_theme_color_override("font_color", data.color.lerp(Color.WHITE, 0.45))
		left.add_child(role_line)
		var party_classes: Array = [Game.class_id()]
		for m in Game.party():
			party_classes.append(StringName(m["class"]))
		var party_line := UIUtil.label(ClassRoles.summary(party_classes), &"SmallLabel")
		party_line.name = "PartyRoles"
		party_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(party_line)
	# The reward exchange's two currencies (RewardShop), beside the gold.
	var wallet := UIUtil.label("เหรียญ %s · %s %d · %s %d" % [GuildScreen._num(int(p.gold)), RewardShop.COIN_NAME, RewardShop.coins(), RewardShop.POINT_NAME, RewardShop.points()], &"SmallLabel")
	wallet.name = "Wallet"
	wallet.add_theme_color_override("font_color", RewardShop.COIN_COLOR.lerp(Color.WHITE, 0.3))
	wallet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(wallet)
	var points := UIUtil.label("แต้มสถานะที่ใช้ได้: %d" % int(p.points), &"SubHeaderLabel")
	left.add_child(points)
	left.add_child(UIUtil.label("กรอกจำนวนแต้ม แล้วกดเพิ่มที่ค่าสถานะที่ต้องการ", &"SmallLabel"))
	var names := {"str": "STR พลัง", "int": "INT ปัญญา", "dex": "DEX ความคล่อง", "vit": "VIT ความทนทาน"}
	var notes := {"str": "เพิ่มพลังโจมตีของนักรบ (และนักหอกเล็กน้อย)", "int": "เพิ่มพลังเวทและ MP", "dex": "เพิ่มพลังโจมตีของนักธนู/นักหอก คริติคอล หลบหลีก และความเร็วสกิล", "vit": "เพิ่ม HP และพลังป้องกัน"}
	for key in ["str", "int", "dex", "vit"]:
		var block := UIUtil.vbox(3)
		left.add_child(block)
		var line := UIUtil.hbox(10)
		block.add_child(line)
		var label := UIUtil.label("%s  %d" % [names[key], int(stats.attrs[key])], &"BoldLabel")
		label.custom_minimum_size = Vector2(250, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var amount := LineEdit.new()
		amount.name = "StatAmount_" + key
		amount.custom_minimum_size = Vector2(116, 56)
		amount.alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		amount.max_length = 9
		amount.placeholder_text = "จำนวน"
		amount.text = String(_stat_amounts.get(key, "1"))
		amount.editable = int(p.points) > 0
		amount.select_all_on_focus = true
		line.add_child(amount)
		var plus := UIUtil.button("เพิ่ม", &"PrimaryButton", Vector2(100, 56))
		plus.name = "StatAdd_" + key
		line.add_child(plus)
		var note := UIUtil.label(notes[key], &"SmallLabel")
		note.name = "StatNote_" + key
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.add_child(note)
		var validate := func():
			var count := _stat_amount(amount.text)
			plus.disabled = count <= 0 or count > int(p.points)
			note.text = notes[key]
			note.remove_theme_color_override("font_color")
			if int(p.points) > 0 and plus.disabled:
				note.text = "กรอกจำนวนเต็มตั้งแต่ 1 ถึง %d แต้ม" % int(p.points)
				note.add_theme_color_override("font_color", UIPalette.WARNING)
		amount.text_changed.connect(func(text: String):
			_stat_amounts[key] = text
			validate.call())
		if OS.has_feature("web"):
			# Godot 4.3's experimental phone keyboard uses set_text without
			# emitting text_changed. Sync only the focused input while editing.
			var keyboard_sync := Timer.new()
			keyboard_sync.wait_time = 0.05
			amount.add_child(keyboard_sync)
			keyboard_sync.timeout.connect(func():
				if String(_stat_amounts.get(key, "1")) != amount.text:
					_stat_amounts[key] = amount.text
					validate.call())
			amount.focus_entered.connect(keyboard_sync.start)
			amount.focus_exited.connect(keyboard_sync.stop)
		plus.pressed.connect(func(): _apply_stat_amount(key, amount, plus))
		amount.text_submitted.connect(func(_text: String): _apply_stat_amount(key, amount, plus))
		validate.call()
	if int(p.level) >= Game.MAX_LEVEL:
		_build_paragon(left)
	var right := UIUtil.vbox(6)
	right.custom_minimum_size = Vector2(380, 0)
	row.add_child(right)
	right.add_child(UIUtil.label("ค่าพลัง", &"SubHeaderLabel"))
	for line in [
		["HP", "%d / %d" % [p.hp, stats.max_hp]], ["MP", "%d / %d" % [p.mp, stats.max_mp]],
		["พลังโจมตี", "%d" % int(stats.atk)], ["พลังป้องกัน", "%d" % int(stats.def)],
		["คริติคอล", "%.1f%%" % (float(stats.crit) * 100.0)], ["หลบหลีก", "%.1f%%" % (float(stats.dodge) * 100.0)], ["ความเร็วสกิล", "+%.1f%%" % (float(stats.haste) * 100.0)],
		["EXP", _exp_text()], ["สังหารมอนสเตอร์", "%d ตัว" % int(p.kills)],
		["เวลาเล่น", UIUtil.format_play_time(float(p.play_time))],
	]:
		var r := UIUtil.hbox(8)
		var k := UIUtil.label(line[0], &"DimLabel")
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(k)
		r.add_child(UIUtil.label(line[1], &"BoldLabel"))
		right.add_child(r)


## Reject fractions, signs and malformed pasted text instead of rounding them.
static func _stat_amount(text: String) -> int:
	var value := text.strip_edges()
	if value.is_empty() or value.length() > 9:
		return 0
	for digit in value:
		if digit < "0" or digit > "9":
			return 0
	return value.to_int()


func _apply_stat_amount(key: String, amount: LineEdit, plus: Button) -> void:
	if plus.disabled or not amount.is_inside_tree():
		return
	var count := _stat_amount(amount.text)
	_stat_amounts[key] = amount.text
	# Hide the phone keyboard before the profile signal replaces this row.
	plus.disabled = true
	amount.release_focus()
	if Game.spend_point(key, count):
		if not Game.save():
			Game.say("อัปแต้มแล้ว แต่ยังบันทึกไม่ได้ ระบบจะลองบันทึกให้อีกครั้ง", &"warning")
	else:
		_rebuild()


func _exp_text() -> String:
	var p := Game.profile
	if int(p.level) >= Game.MAX_LEVEL:
		var para := Game.paragon()
		if int(para.level) >= Game.PARAGON_MAX:
			return "ระดับสูงสุด ดาว %d" % Game.PARAGON_MAX
		return "ดาว %d  %d / %d" % [int(para.level), int(para.exp), Game.paragon_need()]
	return "%d / %d" % [p.exp, HeroStats.exp_to_next(p.level)]


## Paragon buttons per stat: +1, +5, +10 and 0 = everything that still fits.
const PARAGON_STEPS := [1, 5, 10, 0]


func _spend_paragon(key: String, count: int) -> void:
	if Game.paragon_spend(key, count) and not Game.save():
		Game.say("อัปแต้มแล้ว แต่ยังบันทึกไม่ได้ ระบบจะลองบันทึกให้อีกครั้ง", &"warning")


## Paragon points (after Lv.100): permanent bonuses with a gold refund button.
func _build_paragon(parent: Control) -> void:
	var para := Game.paragon()
	var head := UIUtil.hbox(8)
	head.add_child(UIUtil.star_count(int(para.level), 28, &"SubHeaderLabel"))
	head.add_child(UIUtil.label("ระดับเหนือเลเวล / %d  ·  แต้มที่ใช้ได้ %d" % [Game.PARAGON_MAX, int(para.points)], &"SubHeaderLabel"))
	parent.add_child(head)
	for key in Game.PARAGON_STATS:
		var info: Array = Game.PARAGON_STATS[key]
		var used := int(para.alloc[key])
		var block := UIUtil.vbox(3)
		parent.add_child(block)
		var line := UIUtil.hbox(6)
		block.add_child(line)
		var label := UIUtil.label("%s %d/%d" % [info[0], used, int(info[2])], &"BoldLabel")
		label.custom_minimum_size = Vector2(200, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var room := mini(int(para.points), int(info[2]) - used)
		for step in PARAGON_STEPS:
			# A step larger than what is left spends what is left.
			var count := room if step == 0 else mini(int(step), room)
			var plus := UIUtil.button("สุด" if step == 0 else "+%d" % int(step), &"PrimaryButton", Vector2(68, 52))
			plus.name = "Paragon_%s_%s" % [key, "max" if step == 0 else str(step)]
			plus.disabled = room <= 0
			plus.pressed.connect(func(): _spend_paragon(key, count))
			line.add_child(plus)
		block.add_child(UIUtil.label(String(info[3]).replace("%%", "%"), &"SmallLabel"))
	if int(para.spent) > 0:
		var reset := UIUtil.button("คืนแต้มทั้งหมด (%d เหรียญ)" % Game.paragon_reset_cost(), &"", Vector2(0, 48))
		reset.pressed.connect(func():
			if Game.paragon_reset():
				Game.say("คืนแต้มพาราก้อนแล้ว", &"success")
			else:
				Game.say("เหรียญไม่พอ", &"warning"))
		parent.add_child(reset)
	_build_special(parent)


func _spend_special(key: String, count: int) -> void:
	if Game.special_spend(key, count) and not Game.save():
		Game.say("อัปแต้มแล้ว แต่ยังบันทึกไม่ได้ ระบบจะลองบันทึกให้อีกครั้ง", &"warning")


## The special pool of ★301-★500 (Game.SPECIAL_STATS): a point a star past ★300, 40 a stat,
## its own gold reset. Locked (one line) below ★301.
func _build_special(parent: Control) -> void:
	var para := Game.paragon()
	var box := UIUtil.vbox(4)
	box.name = "SpecialStats"
	parent.add_child(box)
	box.add_child(HSeparator.new())
	var points := Game.special_points()
	box.add_child(UIUtil.label("ค่าสถานะพิเศษ (★%d+)  ·  แต้มพิเศษที่ใช้ได้ %d" % [Game.SPECIAL_FROM, points], &"SubHeaderLabel"))
	if int(para.level) < Game.SPECIAL_FROM:
		var locked := UIUtil.label("ล็อกอยู่: ปลดล็อกที่ดาว %d\nดาว %d-%d ให้แต้มพิเศษดาวละ 1 แต้ม\nดาเมจคริติคอล · เจาะเกราะ · ลดความเสียหาย · ดูดเลือด · ลดคูลดาวน์" % [Game.SPECIAL_FROM, Game.SPECIAL_FROM, Game.PARAGON_MAX], &"SmallLabel")
		locked.name = "SpecialLocked"
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(locked)
		return
	for key in Game.SPECIAL_STATS:
		var info: Array = Game.SPECIAL_STATS[key]
		var used := int(para.special.get(key, 0))
		var line := UIUtil.hbox(6)
		box.add_child(line)
		var label := UIUtil.label("%s %d/%d  (+%s%%)" % [info[0], used, int(info[2]), String.num(float(info[1]) * float(used) * 100.0, 2)], &"BoldLabel")
		label.custom_minimum_size = Vector2(200, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var room := mini(points, int(info[2]) - used)
		for step in PARAGON_STEPS:
			var count := room if step == 0 else mini(int(step), room)
			var plus := UIUtil.button("สุด" if step == 0 else "+%d" % int(step), &"PrimaryButton", Vector2(68, 52))
			plus.name = "Special_%s_%s" % [key, "max" if step == 0 else str(step)]
			plus.disabled = room <= 0
			plus.pressed.connect(func(): _spend_special(key, count))
			line.add_child(plus)
		box.add_child(UIUtil.label(String(info[3]).replace("%%", "%"), &"SmallLabel"))
	if Game.special_spent_of(para.special) > 0:
		var reset := UIUtil.button("คืนแต้มพิเศษทั้งหมด (%d เหรียญ)" % Game.SPECIAL_RESET_COST, &"", Vector2(0, 48))
		reset.name = "SpecialReset"
		reset.pressed.connect(func():
			if Game.special_reset():
				Game.say("คืนแต้มพิเศษแล้ว", &"success")
			else:
				Game.say("เหรียญไม่พอ", &"warning"))
		box.add_child(reset)


# ---------------------------------------------------------------------------
# Inventory & equipment
# ---------------------------------------------------------------------------

func _build_inventory() -> void:
	_item_buttons.clear()
	var row := UIUtil.hbox(14)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(row)
	# Paper doll + equipment slots
	var equip := UIUtil.vbox(6)
	equip.custom_minimum_size = Vector2(240, 0)
	row.add_child(equip)
	var preview := HeroPreview.new(Vector2i(240, 290))
	equip.add_child(preview)
	preview.name = "HeroPreview"
	# The same body as the hero in the world (Hero._look: a save without a look is the boy).
	var look: Dictionary = Game.profile.get("look", {})
	preview.show_hero(Game.class_id(), Game.profile.equip, "", look if look.has("gender") else {"gender": 0}, RewardShop.worn_costume())
	var slots := GridContainer.new()
	slots.columns = 3
	slots.add_theme_constant_override("h_separation", 6)
	slots.add_theme_constant_override("v_separation", 6)
	equip.add_child(slots)
	# The gear slots, then the costume slot beside the wings (RewardShop: a costume item
	# changes the look only, no stats: Game.COSTUME_SLOT stays out of EQUIP_SLOTS).
	for slot in ItemData.EQUIP_SLOTS + [Game.COSTUME_SLOT]:
		var item: Variant = Game.equipped(slot)
		var b := Button.new()
		b.name = "Slot_%s" % slot
		b.custom_minimum_size = Vector2(74, 74)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 58)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		if item != null:
			b.icon = ItemLook.icon(item)
			b.tooltip_text = ItemData.name_of(item)
			_style_item_button(b, ItemData.color_of(item), _selected_slot == slot)
		else:
			b.text = ItemData.SLOT_NAMES[slot]
			b.add_theme_font_size_override("font_size", 16)
			b.modulate = Color(1, 1, 1, 0.7)
		b.pressed.connect(func():
			_selected_slot = slot
			_selected_index = -1
			_refresh_detail())
		slots.add_child(b)
		_item_buttons.append({"button": b, "slot": slot, "index": -1, "color": ItemData.color_of(item) if item != null else UIPalette.TEXT_MUTED})
	if not forge_mode:
		var stall := UIUtil.button("แผงของฉัน %d/%d" % [PlayerStall.lots().size(), PlayerStall.MAX_LOTS], &"", Vector2(0, 58))
		stall.name = "StallButton"
		stall.add_theme_font_size_override("font_size", 19)
		stall.pressed.connect(func(): open_stall())
		equip.add_child(stall)
	# Bag grid
	var middle := UIUtil.vbox(6)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(middle)
	var head := UIUtil.hbox(8)
	middle.add_child(head)
	var count_label := UIUtil.label("กระเป๋า (%d/%d)" % [Game.profile.inv.size(), Game.bag_size()], &"SubHeaderLabel")
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(count_label)
	var auto_sell := UIUtil.button("ขายอัตโนมัติ", &"", Vector2(150, 50))
	auto_sell.add_theme_font_size_override("font_size", 18)
	auto_sell.pressed.connect(_open_auto_sell)
	head.add_child(auto_sell)
	auto_sell.visible = not forge_mode
	var filter := UIUtil.button("ตัวกรองเก็บของ", &"", Vector2(160, 50))
	filter.add_theme_font_size_override("font_size", 18)
	filter.pressed.connect(_open_loot_filter)
	head.add_child(filter)
	filter.visible = not forge_mode
	if forge_mode:
		var toggle := UIUtil.button("กลับไปกระเป๋า" if set_craft_open else "ผสมชุดเซต", &"" if set_craft_open else &"PrimaryButton", Vector2(170, 50))
		toggle.name = "SetCraftToggle"
		toggle.add_theme_font_size_override("font_size", 18)
		toggle.pressed.connect(func():
			set_craft_open = not set_craft_open
			_selected_index = -1
			_selected_slot = ""
			_queue_rebuild())
		head.add_child(toggle)
	if forge_mode and set_craft_open:
		_build_set_craft(middle)
	else:
		_build_bag_grid(middle)
	var side := UIUtil.vbox(8)
	side.custom_minimum_size = Vector2(260, 0)
	row.add_child(side)
	_actions = UIUtil.vbox(6)
	side.add_child(_actions)
	var detail_scroll := TouchScroll.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(detail_scroll)
	_detail = UIUtil.vbox(8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail)
	_refresh_detail()


## The bag's groups in the grid, in this order (any other kind after them).
const BAG_GROUPS := ["potion", "gem", "jewel", "costume", "equip"]


## The bag indices in the order the grid shows them, tidy instead of pickup order:
## potions (as in ItemData.POTIONS), gems by type (ItemData.GEM_ORDER) then size small
## to large, jewels and materials, costumes, then gear; pickup order inside a group
## otherwise. Display only: the bag itself (and every index in it: the selection,
## multi-select, the stall) is unchanged.
static func bag_order(inv: Array) -> Array[int]:
	var keys := []
	var potions: Array = ItemData.POTIONS.keys()
	for i in inv.size():
		var it: Dictionary = inv[i]
		var kind := String(it.get("kind", ""))
		var group := BAG_GROUPS.find(kind)
		var sub := 0
		if kind == "gem":
			sub = ItemData.gem_sort_key(String(it.get("id", "")))
		elif kind == "potion":
			sub = potions.find(String(it.get("id", "")))
		keys.append([group if group >= 0 else BAG_GROUPS.size(), sub, i])
	keys.sort_custom(func(a: Array, b: Array) -> bool:
		for k in 3:
			if int(a[k]) != int(b[k]):
				return int(a[k]) < int(b[k])
		return false)
	var out: Array[int] = []
	for key in keys:
		out.append(int(key[2]))
	return out


## The bag's item grid (the middle column of the inventory).
func _build_bag_grid(middle: VBoxContainer) -> void:
	var hint_row := UIUtil.hbox(8)
	middle.add_child(hint_row)
	var hint := UIUtil.label("แตะอุปกรณ์เพื่อเลือก/ยกเลิก (ขายหลายชิ้น)" if multi_sell else "แตะไอเทมเพื่อเทียบกับอุปกรณ์ที่ใส่", &"SmallLabel")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_row.add_child(hint)
	if not forge_mode:
		var multi := UIUtil.button("เสร็จ" if multi_sell else "เลือกหลายชิ้น", &"PrimaryButton" if multi_sell else &"AccentButton", Vector2(170, 50))
		multi.name = "MultiSellToggle"
		multi.add_theme_font_size_override("font_size", 18)
		multi.pressed.connect(func(): _set_multi_sell(not multi_sell))
		hint_row.add_child(multi)
	var scroll := TouchScroll.new()
	_page_scroll = scroll
	scroll.name = "BagScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var order := bag_order(Game.profile.inv)
	for pos in Game.bag_size():
		var i: int = order[pos] if pos < order.size() else pos
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
			b.text = ItemData.tile_text(item)
			b.add_theme_color_override("font_color", ItemData.color_of(item))
			b.add_theme_font_size_override("font_size", 17)
			_style_item_button(b, ItemData.color_of(item), _selected_index == i)
			b.tooltip_text = "%s · %s" % [ItemData.name_of(item), ItemData.RARITY_NAMES[int(item.get("rarity", 0))]]
			var tag := ItemData.class_tag(item, String(Game.class_id()))
			if tag != "":
				b.tooltip_text += "\n" + tag
				# A small muted mark on the slot: this piece is another class's.
				var mark := Label.new()
				mark.name = "ClassMark"
				mark.text = "อาชีพอื่น"
				mark.add_theme_font_size_override("font_size", 13)
				mark.add_theme_color_override("font_color", ItemData.CLASS_TAG_COLOR)
				mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
				mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
				mark.position = Vector2(6, 2)
				b.add_child(mark)
			if ItemData.is_locked(item):
				# The player's lock (ล็อก): a gold padlock in the tile's top-right corner.
				b.tooltip_text += "\n" + ItemData.LOCK_NOTE
				var padlock := ItemData.lock_badge(22.0)
				padlock.position = Vector2(64, 4)
				b.add_child(padlock)
			var entry := {"button": b, "slot": "", "index": i, "color": ItemData.color_of(item)}
			if multi_sell:
				# Multi-select: a check on the picked tiles; pieces bulk selling never
				# takes (Game.bulk_sell_lock) and everything not gear are dimmed.
				var lock := Game.bulk_sell_lock(item)
				var check := Label.new()
				check.name = "PickMark"
				check.text = "✓"
				check.add_theme_font_size_override("font_size", 26)
				check.add_theme_color_override("font_color", UIPalette.GOLD)
				check.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
				check.add_theme_constant_override("outline_size", 4)
				check.mouse_filter = Control.MOUSE_FILTER_IGNORE
				check.position = Vector2(62, -2)
				check.visible = _multi_pick.has(i)
				b.add_child(check)
				entry["mark"] = check
				if lock != "":
					b.modulate = Color(1, 1, 1, 0.38)
				b.pressed.connect(func():
					if lock != "":
						Game.say("เลือกไม่ได้: %s" % lock, &"warning")
						return
					if _multi_pick.has(i):
						_multi_pick.erase(i)
					else:
						_multi_pick[i] = true
					_refresh_detail())
			else:
				b.pressed.connect(func():
					_selected_index = i
					_selected_slot = ""
					_refresh_detail())
			_item_buttons.append(entry)
		else:
			b.disabled = true
		grid.add_child(b)


## ผสมชุดเซต (at the forge): the six 250★ set pieces of the hero's class, what one
## costs (owned / needed), each piece's own need (SetGearData.requirement_text: the
## divine piece +10 or the Lotus Scales, met or not), a picker when several divine
## pieces fit (the lowest + first, the worn one last and only after a confirmation)
## and the chance; Game.craft_set_piece makes the piece.
func _build_set_craft(middle: VBoxContainer) -> void:
	var scroll := TouchScroll.new()
	_page_scroll = scroll
	scroll.name = "SetCraftScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	var box := UIUtil.vbox(8)
	box.name = "SetCraft"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var cls := String(Game.class_id())
	box.add_child(UIUtil.label("ผสมชุดเซต", &"HeaderLabel"))
	if not SetGearData.THEMES.has(cls):
		var none := UIUtil.label("เลือกอาชีพก่อน แล้วค่อยกลับมาผสมชุดเซตของอาชีพตัวเอง", &"DimLabel")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(none)
		return
	var stars := int(Game.paragon().level)
	var intro := UIUtil.label("%s (%s) · สวมใส่ได้ที่ ดาว %d (ตอนนี้ ดาว %d) · ชิ้นละ %s · อาวุธ/เกราะ/หมวก/รองเท้า ใช้ชุดประจำอาชีพชิ้นเดียวกัน +%d ขึ้นไป · แหวน/สร้อย ใช้%s %d · สำเร็จ %d%% พลาดแล้วแก่นเทพกับเพชรหาย แต่ชุดประจำอาชีพ/เกล็ดยังอยู่" % [SetGearData.set_label(cls), String(SetGearData.ENGLISH[cls]), SetGearData.STARS, stars, SetGearData.cost_text(), SetGearData.DIVINE_PLUS, String(ItemData.JEWELS[SetGearData.SCALE].name), SetGearData.SCALES, int(SetGearData.CRAFT_CHANCE * 100.0)], &"SmallLabel")
	intro.name = "Intro"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	var bonus := UIUtil.label("โบนัสเซต (สวมอยู่ %d/6): %s" % [SetGearData.worn_count(Game.profile.equip, cls), SetGearData.bonus_text()], &"DimLabel")
	bonus.name = "Bonus"
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(bonus)
	var have: PackedStringArray = []
	for id in SetGearData.CRAFT_COST:
		var owned := Game.jewel_count(id)
		var need := int(SetGearData.CRAFT_COST[id])
		have.append("[color=#%s]%s %d/%d[/color]" % ["8dffb0" if owned >= need else "ff8a8a", ItemData.JEWELS[id].name, owned, need])
	var cost := RichTextLabel.new()
	cost.name = "Cost"
	cost.bbcode_enabled = true
	cost.fit_content = true
	cost.scroll_active = false
	cost.text = "มีอยู่ / ต้องใช้ต่อชิ้น: " + " · ".join(have)
	cost.add_theme_font_size_override("normal_font_size", 18)
	box.add_child(cost)
	for slot in SetGearData.SLOTS:
		var piece := SetGearData.item(cls, slot)
		var panel := UIUtil.panel(&"CardPanel")
		panel.name = "SetPiece_" + slot
		box.add_child(panel)
		var line := UIUtil.hbox(10)
		panel.add_child(line)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = ItemLook.icon(piece)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(64, 64)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(icon)
		var col := UIUtil.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(col)
		var title := UIUtil.label("%s · %s" % [String(piece.name), ItemData.SLOT_NAMES[slot]], &"BoldLabel")
		title.name = "Title"
		title.add_theme_color_override("font_color", ItemData.color_of(piece))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(title)
		var stats := UIUtil.label(" · ".join(ItemData.stat_lines(piece)), &"SmallLabel")
		stats.name = "Stats"
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(stats)
		# The piece's own need, green when met.
		var choices := Game.set_divine_choices(slot)
		var need := SetGearData.recipe(cls, slot)
		var met := not choices.is_empty() if String(need.divine_slot) != "" else Game.jewel_count(SetGearData.SCALE) >= int(need.scales)
		var have_text := ("มี %d ชิ้น" % choices.size()) if String(need.divine_slot) != "" else "มี %d/%d" % [Game.jewel_count(SetGearData.SCALE), int(need.scales)]
		var req := RichTextLabel.new()
		req.name = "Need"
		req.bbcode_enabled = true
		req.fit_content = true
		req.scroll_active = false
		req.add_theme_font_size_override("normal_font_size", 16)
		req.text = "%s [color=#%s](%s %s)[/color]" % [SetGearData.requirement_text(cls, slot), "8dffb0" if met else "ff8a8a", "✓" if met else "✗", have_text]
		col.add_child(req)
		var pick: Dictionary = _set_pick(slot, choices)
		if choices.size() > 1:
			var picker := OptionButton.new()
			picker.name = "DivinePick"
			picker.custom_minimum_size = Vector2(0, 48)
			for k in choices.size():
				var c: Dictionary = choices[k]
				picker.add_item("%s +%d · %s" % [String(c.item.get("name", "")), int(c.item.get("plus", 0)), {"bag": "กระเป๋า", "storage": "คลัง", "equip": "สวมอยู่"}[c.where]], k)
				if is_same(c.item, pick):
					picker.select(k)
			picker.item_selected.connect(func(k: int):
				_set_picks[slot] = choices[k].item
				_queue_rebuild())
			col.add_child(picker)
		var worn_pick := not choices.is_empty() and choices.any(func(c): return is_same(c.item, pick) and c.where == "equip")
		var problem := Game.set_piece_problem(slot, pick, true)
		var craft := UIUtil.button(("ผสม (ใช้ชิ้นที่สวม)" if worn_pick else "ผสม (%d%%)" % int(SetGearData.CRAFT_CHANCE * 100.0)), &"PrimaryButton", Vector2(140, 56))
		craft.name = "Craft"
		craft.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		craft.disabled = problem != ""
		craft.tooltip_text = problem
		craft.pressed.connect(func(): _craft_set_piece(slot, pick, worn_pick))
		line.add_child(craft)
	_build_star500_craft(box, cls)


## ผสมชุดเทวาลัย (under the 250★ set on the same page): the seven ★500 pieces of the
## hero's class (Star500Gear), each for แก่นเทวาลัย and gold, a sure success.
func _build_star500_craft(box: VBoxContainer, cls: String) -> void:
	box.add_child(UIUtil.label("ผสม%s (★%d)" % [Star500Gear.set_label(cls), Star500Gear.STARS], &"HeaderLabel"))
	var intro := UIUtil.label("สวมใส่ได้ที่ ดาว %d · %s ดรอปที่%s (บอสดรอปบ่อย) · มีอยู่ %d · ผสมสำเร็จทุกครั้ง · โบนัสเซต: %s" % [Star500Gear.STARS, String(ItemData.JEWELS[Star500Gear.CORE].name), Star500Gear.FIELD, Game.jewel_count(Star500Gear.CORE), Star500Gear.bonus_text()], &"SmallLabel")
	intro.name = "Star500Intro"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	for slot in Star500Gear.SLOTS:
		var piece := Star500Gear.item(cls, slot)
		var panel := UIUtil.panel(&"CardPanel")
		panel.name = "Star500Piece_" + slot
		box.add_child(panel)
		var line := UIUtil.hbox(10)
		panel.add_child(line)
		var icon := TextureRect.new()
		icon.texture = ItemLook.icon(piece)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(64, 64)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(icon)
		var col := UIUtil.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(col)
		var title := UIUtil.label("%s · %s" % [String(piece.name), ItemData.SLOT_NAMES[slot]], &"BoldLabel")
		title.add_theme_color_override("font_color", ItemData.color_of(piece))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(title)
		var stats := UIUtil.label(" · ".join(ItemData.stat_lines(piece)), &"SmallLabel")
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(stats)
		var problem := Star500Gear.craft_problem(slot)
		var need := UIUtil.label("ต้องใช้: " + Star500Gear.cost_text(slot), &"DimLabel")
		need.add_theme_color_override("font_color", Color("8dffb0") if problem == "" else Color("ff8a8a"))
		need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(need)
		var craft := UIUtil.button("ผสม", &"PrimaryButton", Vector2(140, 56))
		craft.name = "Craft"
		craft.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		craft.disabled = problem != ""
		craft.tooltip_text = problem
		craft.pressed.connect(func():
			var result := Star500Gear.craft(slot)
			if result == "ok":
				Game.say("ผสมสำเร็จ! ได้ %s แสงแห่งเทวาลัยเจิดจ้า!" % Star500Gear.item_name(cls, slot), &"success")
				AudioManager.play_sfx(&"level_up")
				Game.screen_flash.emit(Star500Gear.COLOR, 0.3)
			else:
				Game.say(result, &"warning")
			_queue_rebuild())
		line.add_child(craft)


## The divine piece the card of [param slot] uses: the player's pick while it still
## fits, else the default (Game.set_divine_choices: lowest +, the worn one last).
func _set_pick(slot: String, choices: Array[Dictionary]) -> Dictionary:
	var chosen: Variant = _set_picks.get(slot)
	for c in choices:
		if is_same(c.item, chosen):
			return c.item
	_set_picks.erase(slot)
	return choices[0].item if not choices.is_empty() else {}


func _craft_set_piece(slot: String, pick: Dictionary = {}, worn := false) -> void:
	if worn:
		var approved: bool = await ModalDialog.confirm(self, "ใช้ชิ้นที่สวมอยู่?", "%s ที่สวมอยู่จะถูกใช้ผสม%s (ถ้าผสมพลาด ชิ้นนี้ยังอยู่)" % [String(pick.get("name", "")), SetGearData.item_name(String(Game.class_id()), slot)], "ใช้ชิ้นที่สวม", "ยกเลิก", true)
		if not approved:
			return
	var result := Game.craft_set_piece(slot, -1.0, pick, worn)
	match result:
		"ok":
			var cls := String(Game.class_id())
			Game.say("ผสมชุดเซตสำเร็จ! ได้ %s แสงแห่ง%sเจิดจ้า!" % [SetGearData.item_name(cls, slot), SetGearData.set_label(cls)], &"success")
			AudioManager.play_sfx(&"level_up")
			Game.screen_flash.emit(SetGearData.palette(cls).glow, 0.3)
		"fail":
			Game.say("ผสมชุดเซตพลาด... (แก่นเทพกับเพชรสลายหายไป ชุดประจำอาชีพ/เกล็ดบัวดารายังอยู่ ลองใหม่อีกครั้ง)", &"warning")
		_:
			Game.say(result, &"warning")
	_queue_rebuild()


## "Compared with what you wear now": the worn item of the same slot and the
## stat differences (green = better, red = worse).
func _build_compare(item: Dictionary) -> void:
	var slot := String(item.slot)
	var worn: Variant = Game.profile.equip.get(slot)
	_detail.add_child(UIUtil.label("เทียบกับที่ใส่อยู่", &"SubHeaderLabel"))
	var now := HeroStats.gear_bonus({"equip": {slot: worn}} if worn != null else {"equip": {}})
	var then := HeroStats.gear_bonus({"equip": {slot: item}})
	var labels := {"atk": "พลังโจมตี", "matk": "โจมตีเวทย์", "def": "พลังป้องกัน", "hp": "HP", "mp": "MP", "crit": "คริติคอล"}
	var any := false
	for key in ["atk", "matk", "def", "hp", "mp", "crit"]:
		var delta := float(then.get(key, 0.0)) - float(now.get(key, 0.0))
		if absf(delta) < 0.0005:
			continue
		any = true
		var text := "%s %s%s" % [labels[key], "+" if delta > 0.0 else "-", ("%.1f%%" % (absf(delta) * 100.0)) if key == "crit" else str(int(round(absf(delta))))]
		var diff := UIUtil.label(text + (" (ดีกว่า)" if delta > 0.0 else " (แย่กว่า)"), &"BoldLabel")
		diff.add_theme_color_override("font_color", Color("6dff9a") if delta > 0.0 else Color("ff7a8a"))
		_detail.add_child(diff)
	if not any:
		_detail.add_child(UIUtil.label("ค่าพลังเท่ากัน", &"SmallLabel"))
	if worn == null:
		var none := UIUtil.label("(ช่อง%sยังว่างอยู่)" % ItemData.SLOT_NAMES.get(slot, slot), &"SmallLabel")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(none)
		return
	var name_label := UIUtil.label("ที่ใส่อยู่: " + ItemData.name_of(worn), &"SmallLabel")
	name_label.add_theme_color_override("font_color", ItemData.color_of(worn))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(240, 0)
	_detail.add_child(name_label)
	var worn_lines := ItemData.level_text(int(worn.level)) + " · " + " · ".join(ItemData.stat_lines(worn))
	var worn_label := UIUtil.label(worn_lines, &"DimLabel")
	worn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	worn_label.custom_minimum_size = Vector2(240, 0)
	_detail.add_child(worn_label)


func _refresh_detail() -> void:
	for entry in _item_buttons:
		if is_instance_valid(entry.button):
			var selected: bool = (entry.slot != "" and entry.slot == _selected_slot) or (entry.slot == "" and entry.index == _selected_index)
			if multi_sell:
				selected = entry.slot == "" and _multi_pick.has(entry.index)
				if entry.has("mark") and is_instance_valid(entry.mark):
					entry.mark.visible = selected
			_style_item_button(entry.button, entry.color, selected)
	if _detail == null or not is_instance_valid(_detail):
		return
	UIUtil.clear(_detail)
	if _actions != null and is_instance_valid(_actions):
		UIUtil.clear(_actions)
	if multi_sell and not forge_mode:
		_build_multi_sell()
		return
	var item: Variant = null
	if _selected_slot != "":
		item = Game.equipped(_selected_slot)
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
		_detail.add_child(UIUtil.label("%s • %s • ต้องการ %s" % [ItemData.SLOT_NAMES[item.slot], ItemData.RARITY_NAMES[int(item.rarity)], ItemData.level_text(int(item.level))], &"SmallLabel"))
		var tag := ItemData.class_tag(item, String(Game.class_id()))
		if tag != "":
			# Another class's piece (drops come for every class): sell it or set it on the stall.
			var owner := UIUtil.label(tag + " · ขายหรือตั้งขายบนแผงได้", &"SmallLabel")
			owner.name = "ClassTag"
			owner.add_theme_color_override("font_color", ItemData.CLASS_TAG_COLOR)
			owner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail.add_child(owner)
		elif ItemData.gear_class(item) != "":
			_detail.add_child(UIUtil.label("อาชีพ: " + SharedStorage.class_name_of(ItemData.gear_class(item)), &"SmallLabel"))
	elif ItemData.is_costume(item):
		_detail.add_child(UIUtil.label("%s • %s • ใส่ได้ทุกอาชีพ" % [ItemData.SLOT_NAMES[Game.COSTUME_SLOT], ItemData.RARITY_NAMES[clampi(int(item.get("rarity", 1)), 0, 4)]], &"SmallLabel"))
	if _selected_slot == "" and item.get("kind", "") == "equip" and not Game.is_other_class(item):
		_build_compare(item)
	var locked := ItemData.is_locked(item)
	if locked:
		var lock_row := UIUtil.hbox(6)
		lock_row.name = "LockNote"
		lock_row.add_child(ItemData.lock_badge(22.0))
		var lock_label := UIUtil.label(ItemData.LOCK_NOTE, &"SmallLabel")
		lock_label.add_theme_color_override("font_color", ItemData.LOCK_BADGE_COLOR)
		lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lock_row.add_child(lock_label)
		_detail.add_child(lock_row)
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
	# Actions sit above the scrolling text so they never need scrolling to.
	var target: Control = _actions if _actions != null and is_instance_valid(_actions) else _detail
	if item.get("kind", "") == "equip":
		var problem := Game.equip_problem(item)
		var equipped := _selected_slot != ""
		if equipped:
			var take := UIUtil.button("ถอด", &"", Vector2(0, 58))
			take.pressed.connect(func(): Game.unequip(_selected_slot); _selected_slot = ""; _rebuild())
			target.add_child(take)
		else:
			var pair := UIUtil.hbox(6)
			target.add_child(pair)
			var wear := UIUtil.button("สวมใส่" if problem == "" else problem, &"PrimaryButton", Vector2(0, 58))
			wear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wear.clip_text = true
			wear.disabled = problem != ""
			wear.pressed.connect(func(): Game.equip_from_bag(_selected_index); _selected_index = -1; _rebuild())
			pair.add_child(wear)
			var sell := UIUtil.button("ล็อกอยู่" if locked else "ขาย +%d" % ItemData.sell_price(item), &"", Vector2(0, 58))
			sell.name = "GearSell"
			sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sell.disabled = locked
			sell.pressed.connect(func(): _sell_selected(1))
			pair.add_child(sell)
	elif item.get("kind", "") == "jewel":
		var craft := String(item.get("id", "")) in StarWingData.CRAFT_COST
		var for_mount := MountData.mount_of_mat(String(item.get("id", "")))
		var how := UIUtil.label(("วัตถุดิบผสมชุดเซต 250 ดาว: ชิ้นเดียวผสมได้ทุกชิ้นของชุดเซตอาชีพตัวเอง (อาวุธ เกราะ หมวก รองเท้า แหวน สร้อย) ที่ช่างตีเหล็ก ปุ่ม \"ผสมชุดเซต\" ชิ้นละ %s + ชุดประจำอาชีพชิ้นเดียวกัน +%d (แหวน/สร้อยใช้เกล็ดบัวดารา %d) · สำเร็จ %d%% พลาดแล้วแก่นเทพกับเพชรหาย · ดรอปที่วิหารบัวดาราและห้วงสมุทรอสูร" % [SetGearData.cost_text(), SetGearData.DIVINE_PLUS, SetGearData.SCALES, int(SetGearData.CRAFT_CHANCE * 100.0)]) if String(item.get("id", "")) == SetGearData.CORE
			else ("วัตถุดิบแหวนและสร้อยชุดเซต 250 ดาว: ชิ้นละ %d เกล็ด + %s ที่ช่างตีเหล็ก ปุ่ม \"ผสมชุดเซต\" (ผสมพลาดเกล็ดยังอยู่) · ดรอปที่วิหารบัวดาราและห้วงสมุทรอสูร (บอสให้ %d เกล็ดทุกตัว)" % [SetGearData.SCALES, SetGearData.cost_text(), EndgameFields.SCALE_BOSS]) if String(item.get("id", "")) == SetGearData.SCALE
			else SkyIsleLoot.help(String(item.get("id", ""))) if SkyIsleLoot.help(String(item.get("id", ""))) != ""
			else Christmas.help(String(item.get("id", ""))) if Christmas.help(String(item.get("id", ""))) != ""
			else WeeklyCollect.help(String(item.get("id", ""))) if WeeklyCollect.help(String(item.get("id", ""))) != ""
			else Star500Gear.core_help(String(item.get("id", ""))) if Star500Gear.core_help(String(item.get("id", ""))) != ""
			else ("วัตถุดิบสัตว์ขี่ของ%s: ใช้สร้าง/อัปเลเวลที่เมนู สัตว์ขี่ (เลเวล n ใช้ n ชิ้น + เพชรชาออส %d×n เม็ด โอกาสสำเร็จ %s ถ้าพลาดวัตถุดิบกับเพชรจะหายไป)" % [String(MountData.info(for_mount).name), int(MountData.info(for_mount).get("chaos", 0)), MountData.chance_text(for_mount)]) if for_mount != ""
			else ("ใช้ตีปีกที่ช่างตีเหล็ก: ปีกเลเวล 100 + เพชรชาออส 1 เม็ด + ขนนก 1 ขน ได้ปีก 100 ดาวประจำอาชีพ (โอกาส %d%%)" % int(StarWingData.CRAFT_CHANCE * 100.0)) if craft
			else ("เจาะช่องอัญมณีเพิ่มให้อาวุธ/ชุด/ปีก ทีละ 1 ช่อง สูงสุด %d ช่อง (ตีบวก +15 ได้ช่องที่ 4) · กดที่ไอเทมแล้วเลือก \"เจาะช่องอัญมณีเพิ่ม\"" % ItemData.MAX_SOCKETS) if String(item.get("id", "")) == "drill"
			else "ใช้ตีบวกที่ช่างตีเหล็ก: เพชรม่วงตี +1 ถึง +6 (สำเร็จ 100%) · เพชรชมพูตี +7 ถึง +9 (50%) · +10 ใช้เพชรม่วง ชมพู ชาออส อย่างละ 1 (50%) · +11 ถึง +15 เพิ่มอย่างละ 1 ทุกขั้น (45%, 40%, 35%, 30%, 25%)", &"DimLabel")
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(how)
		_build_isle_actions(item, target)
		_add_stack_sell(item, target)
	elif ItemData.is_costume(item):
		# Worn: take it off into the bag. In the bag: put it in the costume slot. Never sold.
		var costume_button := UIUtil.button("ถอด" if _selected_slot != "" else "ใส่", &"" if _selected_slot != "" else &"PrimaryButton", Vector2(0, 58))
		costume_button.name = "CostumeWear"
		if _selected_slot != "":
			costume_button.pressed.connect(func():
				if Game.unequip(Game.COSTUME_SLOT):
					_selected_slot = ""
				_rebuild())
		else:
			costume_button.pressed.connect(func():
				Game.equip_from_bag(_selected_index)
				_selected_index = -1
				_rebuild())
		target.add_child(costume_button)
	elif item.get("kind", "") == "gem":
		_detail.add_child(UIUtil.label("ไปที่ช่างตีเหล็กเพื่อใส่ลงช่องในอาวุธ/ชุด", &"DimLabel"))
		var info := ItemData.gem_info(item)
		if info.size < ItemData.GEM_MAX_SIZE:
			var gem_id := String(item.id)
			# Two fixed lines (never autowrap: a wrapping Button asks for the column's whole
			# height on a phone and hid every other button under it).
			var fuse := UIUtil.button("รวม 3 → %s\n%d%% · %d เหรียญ" % [ItemData.GEM_SIZES[info.size + 1], int(float(ItemData.GEM_FUSE_CHANCE[info.size]) * 100.0), int(ItemData.GEM_FUSE_GOLD[info.size])], &"PrimaryButton", Vector2(0, 66))
			fuse.name = "FuseOne"
			fuse.disabled = int(item.get("count", 1)) < 3 or Game.gem_total(gem_id) < 3
			fuse.clip_text = true
			fuse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fuse.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			fuse.add_theme_font_size_override("font_size", 18)
			fuse.pressed.connect(func():
				var result := Game.fuse_gem(gem_id)
				match result:
					"ok":
						Game.say("รวมอัญมณีสำเร็จ! ได้%s%s" % [ItemData.GEMS[info.type].name, ItemData.GEM_SIZES[info.size + 1]], &"success")
						AudioManager.play_sfx(&"level_up")
					"fail":
						Game.say("รวมอัญมณีพลาด... เสียไป 1 เม็ด", &"warning")
					_:
						Game.say(result, &"warning")
				_selected_index = -1
				_rebuild())
			target.add_child(fuse)
			# Bulk: many tries in one go (a count chooser) or every size up to the top.
			var many := UIUtil.vbox(6)
			many.name = "FuseMany"
			target.add_child(many)
			var times := UIUtil.button("รวมหลายครั้ง / ทั้งหมด", &"AccentButton", Vector2(0, 56))
			times.name = "FuseTimes"
			times.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			times.clip_text = true
			times.add_theme_font_size_override("font_size", 18)
			times.disabled = Game.fuse_gem_max_tries(gem_id) < 1
			times.pressed.connect(func(): _fuse_many(gem_id))
			many.add_child(times)
			var chain := UIUtil.button("รวมต่อจนสุด (ทุกขนาด)", &"", Vector2(0, 56))
			chain.name = "FuseChain"
			chain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chain.clip_text = true
			chain.add_theme_font_size_override("font_size", 18)
			chain.disabled = Game.fuse_gem_max_tries(gem_id) < 1
			chain.pressed.connect(func(): _fuse_chain(gem_id))
			many.add_child(chain)
		_add_stack_sell(item, target)
	else:
		var use := UIUtil.button("ใช้", &"PrimaryButton", Vector2(0, 58))
		use.pressed.connect(func(): _use_potion(_selected_index))
		target.add_child(use)
		if item.get("kind", "") == "potion" and ItemData.unit_sell_price(item) > 0:
			_add_stack_sell(item, target)
	# Any bag thing with a worth can go on the hero's stall (PlayerStall), from any zone.
	if _selected_slot == "" and not forge_mode and PlayerStall.fair_price(item) > 0:
		var stall := UIUtil.button("ตั้งขายบนแผง", &"", Vector2(0, 58))
		stall.name = "StallItem"
		stall.disabled = locked
		var index := _selected_index
		stall.pressed.connect(func(): open_stall(index))
		target.add_child(stall)
	# The player's lock (ItemData.is_locked): no sale, stall, trade or use as a material.
	if ItemData.can_lock(item):
		var lock_button := UIUtil.button("ปลดล็อก" if locked else "ล็อก", &"GhostButton" if locked else &"", Vector2(0, 54))
		lock_button.name = "LockToggle"
		lock_button.pressed.connect(func():
			Game.toggle_item_lock(item)
			_rebuild())
		target.add_child(lock_button)


## The bag actions of เกาะลอยฟ้าเทพมังกร's stackables (SkyIsleLoot): "เปิด" / "เปิดทั้งหมด"
## on a treasure chest, "แลกชุดเทพมังกร (n/50)" on the costume fragments and "ไปหน้าสัตว์ขี่"
## on the egg.
func _build_isle_actions(item: Dictionary, target: Control) -> void:
	match String(item.get("id", "")):
		SkyIsleLoot.CHEST:
			var count := int(item.get("count", 1))
			# One under the other: the menu's close button covers the top right corner.
			var pair := UIUtil.vbox(6)
			pair.name = "ChestActions"
			target.add_child(pair)
			var open := UIUtil.button("เปิด", &"PrimaryButton", Vector2(0, 58))
			open.name = "ChestOpen"
			open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			open.pressed.connect(func(): _open_chests(1))
			pair.add_child(open)
			var all := UIUtil.button("เปิดทั้งหมด (%d)" % mini(count, SkyIsleLoot.OPEN_ALL_MAX), &"AccentButton", Vector2(0, 58))
			all.name = "ChestOpenAll"
			all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			all.disabled = count < 2
			all.pressed.connect(func(): _open_chests(SkyIsleLoot.OPEN_ALL_MAX))
			pair.add_child(all)
		SkyIsleLoot.FRAGMENT:
			var have := SkyIsleLoot.fragments()
			var problem := SkyIsleLoot.exchange_problem()
			var swap := UIUtil.button("แลกชุดเทพมังกร (%d/%d)" % [have, SkyIsleLoot.COSTUME_FRAGMENTS] if problem != "มีแล้ว" else "แลกชุดเทพมังกรแล้ว", &"PrimaryButton", Vector2(0, 58))
			swap.name = "FragmentExchange"
			swap.disabled = problem != ""
			swap.tooltip_text = problem
			swap.pressed.connect(func():
				var result := SkyIsleLoot.exchange_costume()
				if result != "ok":
					Game.say(result, &"warning")
				_selected_index = RewardShop.bag_index(SkyIsleLoot.COSTUME)
				_rebuild())
			target.add_child(swap)
		Christmas.GIFT:
			# The Christmas gift boxes: "เปิด" / "เปิดทั้งหมด" (Christmas.open_gifts).
			var count := int(item.get("count", 1))
			var pair := UIUtil.vbox(6)
			pair.name = "GiftActions"
			target.add_child(pair)
			var open := UIUtil.button("เปิดกล่องของขวัญ", &"PrimaryButton", Vector2(0, 58))
			open.name = "GiftOpen"
			open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			open.pressed.connect(func(): _open_gifts(1))
			pair.add_child(open)
			var all := UIUtil.button("เปิดทั้งหมด (%d)" % mini(count, Christmas.OPEN_ALL_MAX), &"AccentButton", Vector2(0, 58))
			all.name = "GiftOpenAll"
			all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			all.disabled = count < 2
			all.pressed.connect(func(): _open_gifts(Christmas.OPEN_ALL_MAX))
			pair.add_child(all)
		Christmas.PIECE:
			# The Santa costume's pieces: exchanged in the reward shop while the festival runs.
			var problem := RewardShop.problem("costume", Christmas.COSTUME)
			var swap := UIUtil.button("แลกชุดซานต้า (%d/%d)" % [Game.jewel_count(Christmas.PIECE), Christmas.COSTUME_PIECES] if problem != "มีแล้ว" else "มีชุดซานต้าแล้ว", &"PrimaryButton", Vector2(0, 58))
			swap.name = "SantaExchange"
			swap.disabled = problem != ""
			swap.tooltip_text = problem
			swap.pressed.connect(func():
				var result := RewardShop.buy("costume", Christmas.COSTUME)
				if result != "ok":
					Game.say(result, &"warning")
				else:
					Game.say("แลกชุดซานต้าแล้ว! ใส่ได้จากกระเป๋า", &"success")
				_selected_index = RewardShop.bag_index(Christmas.COSTUME)
				_rebuild())
			target.add_child(swap)
		SkyIsleLoot.EGG:
			var hatch := UIUtil.button("ไปหน้าสัตว์ขี่ (ฟัก%s)" % String(MountData.info(SkyIsleLoot.MOUNT).name), &"PrimaryButton", Vector2(0, 58))
			hatch.name = "EggHatch"
			hatch.pressed.connect(func(): show_tab(&"mounts"))
			target.add_child(hatch)


## Opens up to [param count] treasure chests (SkyIsleLoot.open_chests) with a little
## flourish: a gold flash, the chest sound and the prizes read out.
func _open_chests(count: int) -> void:
	var result := SkyIsleLoot.open_chests(count)
	if int(result.opened) > 0:
		AudioManager.play_sfx(&"coin")
		Game.screen_flash.emit(Color("ffd84a"), 0.14)
		Game.say("เปิด%s %d กล่อง: %s" % [String(ItemData.JEWELS[SkyIsleLoot.CHEST].name), int(result.opened), SkyIsleLoot.prize_text(result)], &"success")
		for item in result.jackpots:
			SkyIsleLoot.celebrate(item)
	if String(result.stopped) != "":
		Game.say(String(result.stopped), &"warning")
	# The chest stack may be gone: keep it selected while there are chests left.
	_selected_index = -1
	for i in Game.profile.inv.size():
		var it: Dictionary = Game.profile.inv[i]
		if it.get("kind", "") == "jewel" and String(it.get("id", "")) == SkyIsleLoot.CHEST:
			_selected_index = i
	_rebuild()


## Opens up to [param count] Christmas gift boxes (Christmas.open_gifts): a flash, the
## sound and the prizes read out; the box stack stays selected while boxes are left.
func _open_gifts(count: int) -> void:
	var result := Christmas.open_gifts(count)
	if int(result.opened) > 0:
		AudioManager.play_sfx(&"coin")
		Game.screen_flash.emit(Color("ff6a6a"), 0.12)
		Game.say("เปิด%s %d กล่อง: %s" % [String(ItemData.JEWELS[Christmas.GIFT].name), int(result.opened), SkyIsleLoot.prize_text(result)], &"success")
		for item in result.jackpots:
			SkyIsleLoot.celebrate(item)
	if String(result.stopped) != "":
		Game.say(String(result.stopped), &"warning")
	_selected_index = -1
	for i in Game.profile.inv.size():
		var it: Dictionary = Game.profile.inv[i]
		if it.get("kind", "") == "jewel" and String(it.get("id", "")) == Christmas.GIFT:
			_selected_index = i
	_rebuild()


## Opens แผงของฉัน in the bag tab, with bag slot [param pick] picked to price (-1: none).
## Not in the guild war, the arena, the tower or a duel (PlayerStall.blocked_reason).
func open_stall(pick := -1) -> void:
	var blocked := PlayerStall.blocked_reason()
	if blocked != "":
		Game.say(blocked, &"warning")
		return
	stall_open = true
	current_tab = &"inventory"
	if pick >= 0 and pick < Game.profile.inv.size():
		stall_view = {"pick": pick, "count": 0, "price": 0}
	_selected_index = -1
	_selected_slot = ""
	_rebuild()


func _build_stall() -> void:
	var page := PlayerStallView.new(stall_view)
	page.back_requested.connect(func():
		stall_open = false
		_rebuild())
	_content.add_child(page)


## Sells the selected bag item and keeps the selection on the next one, so a
## row of junk can be sold by tapping "sell" again and again.
func _sell_selected(count: int) -> void:
	if _selected_index < 0 or _selected_index >= Game.profile.inv.size():
		return
	var sold := _selected_index
	var before: int = Game.profile.inv.size()
	# The bag shows its items sorted (bag_order): the next one is the one shown after
	# this tile, not the next raw slot (which can sit anywhere on the screen).
	var order := bag_order(Game.profile.inv)
	var at := order.find(sold)
	Game.sell_item(sold, count)
	if Game.profile.inv.size() == before:
		_rebuild()  # part of a stack sold: the same tile stays picked
		return
	var next := -1
	if at >= 0 and at + 1 < order.size():
		next = order[at + 1]
	elif at > 0:
		next = order[at - 1]
	if next > sold:
		next -= 1  # the slots after the sold one moved up by one
	_selected_index = next if next >= 0 and next < Game.profile.inv.size() else -1
	_rebuild()


func _craft_mount_many(id: String) -> void:
	var info := MountData.info(id)
	var top := Game.mount_max_tries(id)
	if top < 1:
		return
	var level := Game.mount_level(id)
	var cost := MountData.cost(id, level + 1)
	var n: int = await QtyPicker.pick(self, "%s%s ต่อเนื่อง" % ["อัปเลเวล" if level > 0 else "สร้าง", String(info.name)], top,
		func(c: int): return "ลองได้สูงสุด %d ครั้ง · หยุดเองเมื่อสำเร็จจนถึง Lv.%d หรือวัตถุดิบไม่พอ" % [c, MountData.MAX_LEVEL],
		"เริ่ม", 1, null,
		"โอกาสสำเร็จ %s ต่อครั้ง · ครั้งนี้ใช้ %s %d + เพชรชาออส %d (เลเวลสูงขึ้นใช้มากขึ้น) · พลาดแล้ววัตถุดิบกับเพชรหาย" % [MountData.chance_text(id), ItemData.JEWELS[MountData.mat_of(id)].name, int(cost.mat), int(cost.chaos)])
	if n <= 0:
		return
	var r := Game.craft_mount_many(id, n)
	_queue_rebuild()
	if int(r.ok) > 0:
		AudioManager.play_sfx(&"level_up", -4.0)
		Game.screen_flash.emit(info.color, 0.12)
	var text := "ลอง %d ครั้ง สำเร็จ %d พลาด %d · %s Lv.%d → Lv.%d" % [int(r.tries), int(r.ok), int(r.fail), String(info.name), int(r.from), int(r.to)]
	if String(r.stopped) != "" and int(r.tries) < n:
		text += "\nหยุดเพราะ " + String(r.stopped)
	await ModalDialog.info(self, "ผลการอัปสัตว์ขี่", text, "ตกลง")


func _set_multi_sell(on: bool) -> void:
	multi_sell = on
	_multi_pick.clear()
	_selected_index = -1
	_selected_slot = ""
	_rebuild()


## The side panel in "เลือกหลายชิ้น": how many are picked and what they fetch, quick
## picks by grade (never enhanced, socketed or special pieces: Game.bulk_sell_pick),
## clear, and "ขาย n ชิ้น" behind a confirm.
func _build_multi_sell() -> void:
	var picked: Array[int] = []
	var gold := 0
	for i in _multi_pick:
		if int(i) < Game.profile.inv.size():
			picked.append(int(i))
			gold += ItemData.sell_price(Game.profile.inv[int(i)])
	var head := UIUtil.label("เลือกแล้ว %d ชิ้น" % picked.size(), &"SubHeaderLabel")
	head.name = "MultiCount"
	_actions.add_child(head)
	var worth := UIUtil.label("รวม %s เหรียญ" % PlayerStall.thousands(gold), &"BoldLabel")
	worth.name = "MultiGold"
	worth.add_theme_color_override("font_color", UIPalette.GOLD)
	_actions.add_child(worth)
	var sell := UIUtil.button("ขาย %d ชิ้น" % picked.size(), &"DangerButton", Vector2(0, 58))
	sell.name = "MultiSell"
	sell.disabled = picked.is_empty()
	sell.pressed.connect(func(): _confirm_multi_sell())
	_actions.add_child(sell)
	_detail.add_child(UIUtil.label("เลือกด่วน", &"BoldLabel"))
	for r in 3:
		var quick := UIUtil.button("เลือกทั้งหมด ≤ %s (%d)" % [ItemData.RARITY_NAMES[r], Game.bulk_sell_pick(r).size()], &"", Vector2(0, 54))
		quick.name = "MultiPick%d" % r
		quick.add_theme_font_size_override("font_size", 18)
		quick.add_theme_color_override("font_color", ItemData.RARITY_COLORS[r].lightened(0.25))
		quick.pressed.connect(func():
			for i in Game.bulk_sell_pick(r):
				_multi_pick[i] = true
			_refresh_detail())
		_detail.add_child(quick)
	var clear := UIUtil.button("ล้างที่เลือก", &"GhostButton", Vector2(0, 54))
	clear.name = "MultiClear"
	clear.disabled = picked.is_empty()
	clear.pressed.connect(func():
		_multi_pick.clear()
		_refresh_detail())
	_detail.add_child(clear)
	var keep := UIUtil.label("ไม่ถูกเลือกเด็ดขาด: ของที่ล็อก ของที่สวมอยู่ ตีบวกแล้ว ใส่อัญมณี ปีก ชุดเซต/ดาว/เทพ/มังกร · เลือกด่วนไม่เกินเกรดหายาก แตะเลือกเพิ่มทีละชิ้นได้", &"DimLabel")
	keep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(keep)


func _confirm_multi_sell() -> void:
	var picked: Array[int] = []
	var gold := 0
	var by_grade := [0, 0, 0, 0, 0]
	for i in _multi_pick:
		if int(i) < Game.profile.inv.size():
			var item: Dictionary = Game.profile.inv[int(i)]
			picked.append(int(i))
			gold += ItemData.sell_price(item)
			by_grade[clampi(int(item.get("rarity", 0)), 0, 4)] += 1
	if picked.is_empty():
		return
	var parts: Array[String] = []
	for r in 5:
		if by_grade[r] > 0:
			parts.append("%s %d" % [ItemData.RARITY_NAMES[r], by_grade[r]])
	var ok: bool = await ModalDialog.confirm(self, "ขาย %d ชิ้น?" % picked.size(), "%s\nได้ %s เหรียญ · ขายแล้วซื้อคืนไม่ได้" % [" · ".join(parts), PlayerStall.thousands(gold)], "ขายเลย", "ยกเลิก", true)
	if not ok or not multi_sell:
		return
	var result := Game.sell_many(picked)
	_multi_pick.clear()
	if int(result.count) > 0:
		AudioManager.play_sfx(&"coin")
		Game.say("ขาย %d ชิ้น ได้ %s เหรียญ" % [int(result.count), PlayerStall.thousands(int(result.gold))], &"success")
	_rebuild()


## "ขาย" on a stack (potion, gem, jewel): one of it sells at once, a bigger stack opens
## the count chooser (QtyPicker: +1 +10 +100 ทั้งหมด, the total live) and sells the
## count in one go.
func _add_stack_sell(item: Dictionary, target: Control) -> void:
	var unit := ItemData.unit_sell_price(item)
	var stack := int(item.get("count", 1))
	var sell := UIUtil.button("ขาย +%d" % unit if stack <= 1 else "ขาย... (+%d/ชิ้น)" % unit, &"", Vector2(0, 58))
	sell.name = "StackSell"
	sell.clip_text = true
	if ItemData.is_locked(item):
		sell.text = "ล็อกอยู่"
		sell.disabled = true
	sell.pressed.connect(func():
		if ItemData.is_locked(item):
			return
		if stack <= 1:
			_sell_selected(1)
			return
		var index := _selected_index
		var n: int = await QtyPicker.pick(self, "ขาย%s" % ItemData.name_of(item), stack,
			func(c: int): return "ขาย %d ชิ้น ได้ %s เหรียญ (เหลือ %d)" % [c, PlayerStall.thousands(unit * c), stack - c], "ขาย", 1, ItemLook.icon(item))
		if n <= 0 or index != _selected_index or index >= Game.profile.inv.size() or Game.profile.inv[index] != item:
			return
		AudioManager.play_sfx(&"coin")
		Game.say("ขาย%s ×%d ได้ %s เหรียญ" % [ItemData.name_of(item), n, PlayerStall.thousands(unit * n)], &"success")
		_sell_selected(n))
	target.add_child(sell)


## "รวมหลายครั้ง": how many fuse tries (QtyPicker, capped by the gems and the gold),
## then every try rolled at once (Game.fuse_gems_many) and a summary.
func _fuse_many(gem_id: String) -> void:
	var info := ItemData.gem_info({"id": gem_id})
	var top := Game.fuse_gem_max_tries(gem_id)
	if top < 1:
		return
	var chance := float(ItemData.GEM_FUSE_CHANCE[info.size])
	var cost := int(ItemData.GEM_FUSE_GOLD[info.size])
	var have := Game.gem_total(gem_id)
	var next := "%s%s" % [ItemData.GEMS[info.type].name, ItemData.GEM_SIZES[info.size + 1]]
	var n: int = await QtyPicker.pick(self, "รวม%s → %s" % [info.name, next], top, func(c: int):
		var gems := "%d เม็ด" % (3 * c) if chance >= 1.0 else "%d–%d เม็ด" % [mini(c, have), mini(3 * c, have)]
		return "ใช้สูงสุด %s เหรียญ · อัญมณี %s · คาดว่าได้ %s ~%d เม็ด" % [PlayerStall.thousands(cost * c), gems, next, int(round(c * chance))],
		"รวม", top, ItemLook.icon(ItemData.gem(info.type, info.size)),
		"สำเร็จ %d%% ต่อครั้ง · ครั้งละ 3 เม็ด + %s เหรียญ · พลาดเสีย 1 เม็ด (หยุดเองเมื่ออัญมณีหมด)" % [int(chance * 100.0), PlayerStall.thousands(cost)])
	if n <= 0:
		return
	var result := Game.fuse_gems_many(gem_id, n)
	_selected_index = -1
	_rebuild()
	_fuse_report([result])


## "รวมต่อจนสุด": every gem of this kind, size after size up to ตำนาน (after a confirm).
func _fuse_chain(gem_id: String) -> void:
	var info := ItemData.gem_info({"id": gem_id})
	var ok: bool = await ModalDialog.confirm(self, "รวมต่อจนสุด?", "รวม%sทุกเม็ดที่มี แล้วนำผลที่ได้ไปรวมต่อขนาดถัดไปเรื่อย ๆ จนถึง%s ตราบที่อัญมณีและเงินพอ (แต่ละครั้งสุ่มโอกาสจริงแยกกัน พลาดเสีย 1 เม็ด)" % [String(ItemData.GEMS[info.type].name), ItemData.GEM_SIZES[ItemData.GEM_MAX_SIZE]], "รวมเลย", "ยกเลิก")
	if not ok:
		return
	var steps := Game.fuse_gems_chain(gem_id)
	_selected_index = -1
	_rebuild()
	_fuse_report(steps)


func _fuse_report(steps: Array) -> void:
	var lines: Array[String] = []
	var gold := 0
	var any_ok := false
	var stopped := ""
	for r in steps:
		if int(r.tries) <= 0:
			stopped = String(r.stopped)
			continue
		var from := ItemData.gem_info({"id": String(r.get("from_id", _gem_from(String(r.made_id))))})
		var made := ItemData.gem_info({"id": String(r.made_id)})
		lines.append("%s: ผสม %d ครั้ง สำเร็จ %d ได้ %s ×%d · พลาด %d · ใช้ %d เม็ด" % [from.name, int(r.tries), int(r.ok), made.name, int(r.ok), int(r.fail), int(r.used)])
		gold += int(r.gold)
		any_ok = any_ok or int(r.ok) > 0
		if String(r.stopped) != "" and String(r.stopped) != "อัญมณีไม่พอ":
			stopped = String(r.stopped)
	if lines.is_empty():
		Game.say(stopped if stopped != "" else "ไม่มีอัญมณีพอรวม", &"warning")
		return
	lines.append("ใช้เงินรวม %s เหรียญ" % PlayerStall.thousands(gold))
	if stopped != "":
		lines.append("หยุดเพราะ%s" % stopped)
	AudioManager.play_sfx(&"level_up" if any_ok else &"ui_cancel")
	await ModalDialog.info(self, "ผลการรวมอัญมณี", "\n".join(lines), "ตกลง")


func _gem_from(made_id: String) -> String:
	var bits := made_id.split("_")
	return "%s_%d" % [bits[0], maxi(0, int(bits[1]) - 1)]


const LEVEL_STEPS := [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120]


## Auto-sell: pick the grades and a level limit, see what would go, sell it all.
func _open_auto_sell() -> void:
	UIUtil.clear(_content)
	var flags: Dictionary = Game.profile.flags
	var state := {"mask": int(flags.get("autosell_mask", 3)), "level": int(flags.get("autosell_level", 0))}
	var box := UIUtil.vbox(12)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(box)
	box.add_child(UIUtil.label("ขายอัตโนมัติ", &"HeaderLabel"))
	box.add_child(UIUtil.label("1. เลือกเกรดที่จะขาย (เรียงจากต่ำสุดไปสูงสุด)", &"BoldLabel"))
	var grades := UIUtil.hbox(8)
	box.add_child(grades)
	var level_row := UIUtil.hbox(10)
	var level_label := UIUtil.label("", &"SubHeaderLabel")
	var preview := UIUtil.label("", &"BoldLabel")
	var sell := UIUtil.button("", &"PrimaryButton", Vector2(320, 64))
	var refresh := func():
		var picked := Game.auto_sell_indices(int(state.mask), int(state.level))
		var gold := 0
		for i in picked:
			gold += ItemData.sell_price(Game.profile.inv[i])
		level_label.text = "ทุกเลเวล" if int(state.level) == 0 else "ต่ำกว่า Lv.%d" % int(state.level)
		preview.text = "จะขาย %d ชิ้น ได้ %d เหรียญ" % [picked.size(), gold]
		sell.text = "ขาย %d ชิ้น" % picked.size()
		sell.disabled = picked.is_empty()
	for r in 5:
		var chip := _grade_toggle(r, (int(state.mask) >> r) & 1 == 1, "ขาย", "ไม่ขาย")
		chip.toggled.connect(func(on: bool):
			state["mask"] = (int(state.mask) | (1 << r)) if on else (int(state.mask) & ~(1 << r))
			refresh.call())
		grades.add_child(chip)
	box.add_child(UIUtil.label("2. เลเวลของไอเทม", &"BoldLabel"))
	box.add_child(level_row)
	var minus := UIUtil.button("−", &"", Vector2(72, 60))
	var plus := UIUtil.button("+", &"", Vector2(72, 60))
	level_label.custom_minimum_size = Vector2(220, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minus.pressed.connect(func():
		state["level"] = LEVEL_STEPS[maxi(0, LEVEL_STEPS.find(int(state.level)) - 1)]
		refresh.call())
	plus.pressed.connect(func():
		state["level"] = LEVEL_STEPS[mini(LEVEL_STEPS.size() - 1, LEVEL_STEPS.find(int(state.level)) + 1)]
		refresh.call())
	level_row.add_child(minus)
	level_row.add_child(level_label)
	level_row.add_child(plus)
	box.add_child(_other_class_toggle(refresh))
	var keep := UIUtil.label("ไม่ขายเสมอ: ของที่สวมอยู่ ของที่ตีบวกแล้ว ของที่ใส่อัญมณี และปีก · ของอาชีพอื่นเก็บไว้ตั้งขายบนแผง เว้นแต่เปิดขายอัตโนมัติ", &"DimLabel")
	keep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(keep)
	box.add_child(preview)
	var buttons := UIUtil.hbox(10)
	box.add_child(buttons)
	sell.pressed.connect(func():
		Game.auto_sell(int(state.mask), int(state.level))
		_selected_index = -1
		_rebuild())
	buttons.add_child(sell)
	var back := UIUtil.button("กลับ", &"", Vector2(160, 64))
	back.pressed.connect(_rebuild)
	buttons.add_child(back)
	refresh.call()


## Pickup filter: which grades of dropped gear the hero picks up.
func _open_loot_filter() -> void:
	UIUtil.clear(_content)
	var box := UIUtil.vbox(12)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(box)
	box.add_child(UIUtil.label("ตัวกรองเก็บของ", &"HeaderLabel"))
	box.add_child(UIUtil.label("เลือกเกรดอุปกรณ์ที่จะเก็บเมื่อมอนสเตอร์ดรอป (เรียงจากต่ำสุดไปสูงสุด)", &"BoldLabel"))
	var grades := UIUtil.hbox(8)
	box.add_child(grades)
	for r in 5:
		var chip := _grade_toggle(r, (Game.loot_mask() >> r) & 1 == 1, "เก็บ", "ไม่เก็บ")
		chip.toggled.connect(func(on: bool):
			Game.set_loot_mask((Game.loot_mask() | (1 << r)) if on else (Game.loot_mask() & ~(1 << r))))
		grades.add_child(chip)
	var quick := UIUtil.hbox(8)
	box.add_child(quick)
	for spec in [["เก็บทุกเกรด", 31], ["ดี ขึ้นไป", 30], ["หายาก ขึ้นไป", 28], ["ในตำนาน ขึ้นไป", 24]]:
		var b := UIUtil.button(String(spec[0]), &"", Vector2(0, 54))
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			Game.set_loot_mask(int(spec[1]))
			_open_loot_filter())
		quick.add_child(b)
	box.add_child(_other_class_toggle(Callable()))
	var note := UIUtil.label("ยา อัญมณี เหรียญ และปีก เก็บเสมอ · ของเกรดที่ปิดไว้จะไม่ดรอปให้เก็บ (ใช้กับของทุกอาชีพ)", &"DimLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var back := UIUtil.button("กลับ", &"PrimaryButton", Vector2(200, 64))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_rebuild)
	box.add_child(back)


## "ขายของอาชีพอื่นอัตโนมัติ" (Game.sells_other_class, off by default): another class's
## gear is sold when picked up and by the bulk auto-sell; off, it is kept for the stall.
func _other_class_toggle(changed: Callable) -> Control:
	var row := UIUtil.hbox(10)
	var chip := Button.new()
	chip.name = "AutoSellOtherClass"
	chip.toggle_mode = true
	chip.button_pressed = Game.sells_other_class()
	chip.custom_minimum_size = Vector2(150, 56)
	chip.add_theme_font_size_override("font_size", 18)
	chip.text = "เปิด" if chip.button_pressed else "ปิด"
	var label := UIUtil.label("ขายของอาชีพอื่นอัตโนมัติ", &"BoldLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.toggled.connect(func(on: bool):
		Game.set_sells_other_class(on)
		chip.text = "เปิด" if on else "ปิด"
		if changed.is_valid():
			changed.call())
	row.add_child(chip)
	row.add_child(label)
	return row


## A grade chip in its rarity colour that switches between [param on_text] and [param off_text].
func _grade_toggle(rarity: int, on: bool, on_text: String, off_text: String) -> Button:
	var chip := Button.new()
	chip.toggle_mode = true
	chip.custom_minimum_size = Vector2(150, 74)
	chip.add_theme_font_size_override("font_size", 18)
	var color: Color = ItemData.RARITY_COLORS[rarity]
	var paint := func(state: bool):
		chip.text = "%s\n%s" % [ItemData.RARITY_NAMES[rarity], ("✔ " + on_text) if state else ("✖ " + off_text)]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color, 0.85) if state else Color(0.12, 0.14, 0.22, 0.9)
		style.set_corner_radius_all(12)
		style.set_border_width_all(3)
		style.border_color = color
		for key in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			chip.add_theme_stylebox_override(key, style)
		var text_color := Color("1a1a24") if state else color
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			chip.add_theme_color_override(key, text_color)
	chip.button_pressed = on
	paint.call(on)
	chip.toggled.connect(func(state: bool): paint.call(state))
	return chip


## Lv.100 wings + a chaos jewel + a feather: a try at the class's 100★ wings.
func _build_wing_craft(item: Dictionary, spot: Control) -> void:
	var enough := true
	for id in StarWingData.CRAFT_COST:
		enough = enough and Game.jewel_count(id) >= int(StarWingData.CRAFT_COST[id])
	var in_bag := _selected_slot == ""
	var need := UIUtil.label("ตีปีก 100 ดาว: ใช้เพชรชาออส 1 เม็ด + ขนนก 1 ขน · มีเพชรชาออส %d ขนนก %d%s" % [Game.jewel_count("chaos"), Game.jewel_count("feather"), "" if in_bag else " · ถอดปีกเก็บเข้ากระเป๋าก่อน"], &"SmallLabel")
	need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	need.add_theme_color_override("font_color", Color("fff1b8") if enough and in_bag else Color("ff8a8a"))
	spot.add_child(need)
	var btn := UIUtil.button("ตีปีก 100 ดาว  (%d%%)" % int(StarWingData.CRAFT_CHANCE * 100.0), &"PrimaryButton", Vector2(0, 58))
	btn.disabled = not (enough and in_bag)
	btn.pressed.connect(func():
		var result := Game.craft_star_wings(item)
		match result:
			"ok":
				Game.say("ตีปีกสำเร็จ! ได้ %s" % ItemData.name_of(item), &"success")
				AudioManager.play_sfx(&"level_up")
				Game.screen_flash.emit(Color("ffd23f"), 0.3)
			"fail":
				Game.say("ตีปีกพลาด... (เพชรชาออสกับขนนกหายไป ปีกเลเวล 100 ยังอยู่)", &"warning")
			_:
				Game.say(result, &"warning")
		_selected_index = Game.profile.inv.find(item)
		_rebuild())
	spot.add_child(btn)


func _build_forge_buttons(item: Dictionary) -> void:
	var plus := int(item.get("plus", 0))
	# The forge sits with the actions above the scrolling text: tapping it again and
	# again never needs scrolling back down after the screen redraws.
	var spot: Control = _actions if _actions != null and is_instance_valid(_actions) else _detail
	if StarWingData.can_craft(item):
		_build_wing_craft(item, spot)
	if not EnhanceFx.can_enhance(item):
		_detail.add_child(UIUtil.label("แหวนและสร้อยเป็นของวิเศษคงที่ ตีบวกไม่ได้ (ฝังอัญมณีได้)", &"DimLabel"))
	elif plus < ItemData.MAX_PLUS:
		var cost := ItemData.enhance_cost(item)
		var enough := true
		for id in cost:
			enough = enough and Game.jewel_count(id) >= int(cost[id])
		var have := "มีเพชรม่วง %d ชมพู %d" % [Game.jewel_count("purple"), Game.jewel_count("pink")]
		if int(cost.get("chaos", 0)) > 0:
			have += " ชาออส %d" % Game.jewel_count("chaos")
		var need := UIUtil.label("ใช้ %s · %s" % [ItemData.jewel_cost_text(cost), have], &"SmallLabel")
		need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		need.add_theme_color_override("font_color", Color("e8dcff") if enough else Color("ff8a8a"))
		spot.add_child(need)
		# The forge weekend (สุดสัปดาห์ตีบวก): its line, and the odds on the button with it.
		var now := WorldPresence.clock()
		var weekend := WorldEvents.forge_line(now)
		if weekend != "":
			var line := UIUtil.label(weekend, &"BoldLabel")
			line.name = "ForgeWeekend"
			line.add_theme_color_override("font_color", Color("ffd23a"))
			spot.add_child(line)
		var btn := UIUtil.button("ตีบวก +%d  (%d%%)" % [plus + 1, int(round(WorldEvents.enhance_chance_at(plus, now) * 100.0))], &"PrimaryButton", Vector2(0, 58))
		btn.disabled = not enough
		btn.pressed.connect(func():
			var result := Game.enhance_item(item)
			match result:
				"ok":
					var new_plus := int(item.get("plus", 0))
					var g := EnhanceFx.grade(new_plus)
					# A new look step: name it (เรืองแสงจาง, ประกายไฟฟ้า, ...).
					var mood := ""
					if new_plus in EnhanceFx.AURA_STEPS:
						mood = "เอฟเฟกต์ใหม่: %s!" % EnhanceFx.look_name(new_plus, String(item.get("slot", "")))
					Game.say("ตีบวกสำเร็จ! %s %s" % [ItemData.name_of(item), mood], &"success")
					AudioManager.play_sfx(&"level_up")
					if g >= 1:
						Game.screen_flash.emit(EnhanceFx.color_of(new_plus), 0.12 + 0.035 * float(g))
				"fail":
					Game.say("ตีบวกพลาด... (เพชรหายไป ไอเทมยังอยู่ที่ +%d)" % int(item.get("plus", 0)), &"warning")
				_:
					Game.say(result, &"warning")
			# Spent jewels can empty a stack ahead of the piece in the bag: keep the piece selected.
			if _selected_slot == "":
				_selected_index = Game.profile.inv.find(item)
			_rebuild())
		spot.add_child(btn)
	else:
		_detail.add_child(UIUtil.label("ตีบวกสูงสุด +%d แล้ว" % ItemData.MAX_PLUS, &"DimLabel"))
	_build_gem_sockets(item, spot)
	if EnhanceFx.can_enhance(item) and int(item.get("sockets", 0)) < ItemData.max_sockets(item):
		var drill := UIUtil.button("เจาะช่องอัญมณีเพิ่ม (สว่านเจาะ 1 · มี %d)" % Game.jewel_count("drill"), &"", Vector2(0, 52))
		drill.disabled = Game.jewel_count("drill") < 1
		drill.pressed.connect(func():
			var result := Game.drill_socket(item)
			if result == "ok":
				Game.say("เจาะช่องอัญมณีสำเร็จ! (%d ช่อง)" % int(item.sockets), &"success")
				AudioManager.play_sfx(&"level_up")
			else:
				Game.say(result, &"warning")
			_rebuild())
		_detail.add_child(drill)


## The piece's sockets in the forge's side column: one chip per socket (the gem's icon,
## or ว่าง) and "ใส่อัญมณี" opening the GemPicker sheet (gems by type, small to large;
## taking out and the quick fills are there too).
func _build_gem_sockets(item: Dictionary, spot: Control) -> void:
	var sockets := int(item.get("sockets", 0))
	if sockets <= 0:
		return
	var gems: Array = item.get("gems", [])
	var row := UIUtil.hbox(6)
	row.name = "GemSocketChips"
	spot.add_child(row)
	var head := UIUtil.label("ช่องอัญมณี %d/%d" % [gems.size(), sockets], &"BoldLabel")
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(head)
	for k in sockets:
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(40, 40)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.content_margin_left = 3
		sb.content_margin_right = 3
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		if k < gems.size():
			var info := ItemData.gem_info({"id": gems[k]})
			sb.bg_color = UIPalette.CARD.lerp(info.color, 0.22)
			sb.border_color = info.color
			chip.tooltip_text = "%s: %s" % [info.name, ItemData.gem_effect_text(info)]
			chip.add_child(UIUtil.texture_rect(ItemLook.icon(ItemData.gem(info.type, info.size)), Vector2(32, 32)))
		else:
			sb.bg_color = Color(UIPalette.CARD, 0.5)
			sb.border_color = Color(UIPalette.TEXT_MUTED, 0.6)
			chip.tooltip_text = "ช่องว่าง"
		chip.add_theme_stylebox_override("panel", sb)
		row.add_child(chip)
	var free := sockets - gems.size()
	var open := UIUtil.button("ใส่อัญมณี (ว่าง %d ช่อง)" % free if free > 0 else "จัดการอัญมณี / ถอด", &"AccentButton" if free > 0 else &"", Vector2(0, 54))
	open.name = "GemPickerOpen"
	open.add_theme_font_size_override("font_size", 19)
	open.pressed.connect(func(): _open_gem_picker(item))
	spot.add_child(open)


func _open_gem_picker(item: Dictionary) -> void:
	if _gem_picker != null and is_instance_valid(_gem_picker):
		_gem_picker.queue_free()
	_gem_picker = GemPicker.open_for(_root, item)
	_gem_picker.closed.connect(func():
		_gem_picker = null
		# Gems leaving the bag move the piece's index: keep it selected.
		if _selected_slot == "":
			_selected_index = Game.profile.inv.find(item)
		if is_open:
			_rebuild())


func _use_potion(index: int) -> void:
	var item: Dictionary = Game.profile.inv[index]
	var def: Dictionary = ItemData.POTIONS[item.id]
	if def.has("town"):
		if Game.in_duel():
			Game.say("หนีจากการดวลไม่ได้!", &"warning")
			return
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
	_page_scroll = scroll
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UIUtil.label("แถบสกิล: เลือกใส่ได้ %d ช่อง   •   แต้มสกิล %d (ไปอัปที่ปรมาจารย์สกิลในหมู่บ้าน)" % [ClassData.SLOTS, int(Game.profile.skill_points)], &"SubHeaderLabel"))
	var bar_row := UIUtil.hbox(8)
	box.add_child(bar_row)
	var bar: Array = Game.loadout_skills()
	for i in bar.size():
		var slot_panel := UIUtil.panel(&"CardPanel")
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot_content := UIUtil.vbox(4)
		slot_panel.add_child(slot_content)
		if not bar[i].is_empty():
			var portrait := SkillIcons.portrait(bar[i], 44.0)
			portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			slot_content.add_child(portrait)
		var slot_label := UIUtil.label("%d. %s" % [i + 1, bar[i].name if not bar[i].is_empty() else "— ว่าง —"], &"BoldLabel")
		slot_label.clip_text = true
		slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot_content.add_child(slot_label)
		bar_row.add_child(slot_panel)
	# Opening at the top: the rows on screen first, the rest a few a frame after (one
	# long frame on a phone stalled the sound). A rebuild below the top (equipping a
	# skill lower down) is built whole so the page stays where it was.
	var rows: Array = []
	for skill in Game.skill_pool():
		rows.append(_skill_row.bind(skill))
	var passives: Array = Game.passive_pool()
	if not passives.is_empty():
		rows.append(func(): return UIUtil.label("สกิลติดตัว (ทำงานเองตลอด)", &"SubHeaderLabel"))
	for skill in passives:
		rows.append(_passive_row.bind(skill))
	var gen := _build_gen
	var first := rows.size() if not _slice_build else FIRST_ROWS
	for i in mini(first, rows.size()):
		box.add_child(rows[i].call())
	var next := first
	while next < rows.size():
		await get_tree().process_frame
		if gen != _build_gen or not is_open or not is_instance_valid(box):
			return
		for i in range(next, mini(next + ROWS_PER_FRAME, rows.size())):
			box.add_child(rows[i].call())
		next += ROWS_PER_FRAME


func _skill_row(skill: Dictionary) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	line.add_child(SkillIcons.portrait(skill))
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
	var desc := UIUtil.label("%s  •  MP %d  •  คูลดาวน์ %.1f วิ" % [skill.desc, SkillRank.mp(skill, maxi(rank, 1)), SkillRank.cooldown(skill, maxi(rank, 1))], &"SmallLabel")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	var evolve := Game.evolution_note(skill)
	if evolve != "":
		var evo := UIUtil.label(evolve, &"SmallLabel")
		evo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		evo.add_theme_color_override("font_color", UIPalette.GOLD)
		info.add_child(evo)
	var upcoming := SkillRank.next_changes(SkillRank.table(skill), rank)
	if unlocked and not upcoming.is_empty():
		var next := UIUtil.label("อัปเป็นดาว %d ที่ครูฝึกสกิล: %s" % [rank + 1, ",  ".join(upcoming)], &"SmallLabel")
		next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		next.add_theme_color_override("font_color", UIPalette.SUCCESS)
		info.add_child(next)
	var equipped := Game.loadout().find(ClassData.rank_id(skill))
	for slot in ClassData.SLOTS:
		var b := UIUtil.button(str(slot + 1), &"PrimaryButton" if equipped == slot else &"", Vector2(48, 52))
		b.disabled = not unlocked or equipped == slot
		b.pressed.connect(func():
			if Game.equip_skill(skill.id, slot):
				AudioManager.play_ui(&"ui_select"))
		line.add_child(b)
	return panel


func _passive_row(skill: Dictionary) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
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
	return panel


# ---------------------------------------------------------------------------
# Quests
# ---------------------------------------------------------------------------

func _build_quests() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	_page_scroll = scroll
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
		var state := "รับรางวัลแล้ว" if entry.claimed else ("เสร็จแล้ว — ไปรับที่กระดาน" if done else "%d / %d" % [int(entry.progress), target])
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
		var state_text: String = {"new": "ยังไม่ได้รับ", "active": "กำลังทำ", "ready": "เสร็จแล้ว — กลับไปรายงาน", "done": "สำเร็จแล้ว เสร็จแล้ว"}[status]
		var gate := "ดาว %d+" % int(quest.star) if int(quest.get("star", 0)) > 0 else "Lv.%d+" % int(quest.level)
		var title := UIUtil.label("%s  (%s)  — %s" % [quest.name, gate, state_text], &"BoldLabel")
		if status == "done":
			title.add_theme_color_override("font_color", UIPalette.SUCCESS)
		col.add_child(title)
		var detail := UIUtil.label(quest.desc, &"SmallLabel")
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(detail)
		if status == "active" or status == "ready":
			col.add_child(UIUtil.label("ความคืบหน้า: %d / %d  (%s)" % [int(Game.quest_state(id).get("progress", 0)), int(quest.count), MonsterData.get_monster(StringName(quest.target)).name], &"DimLabel"))
		col.add_child(UIUtil.label("รางวัล: EXP %d • เหรียญ %d" % [int(quest.exp), int(quest.gold)], &"DimLabel"))
	# บทที่ 2 (StoryChapter2): the endgame chain from the scholar, ★200 to ★300.
	box.add_child(UIUtil.label("%s (รับจาก%s ข้างเจดีย์ในหมู่บ้าน · ดาว 200-300)" % [StoryChapter2.TITLE, StoryChapter2.role_name("scholar")], &"SubHeaderLabel"))
	for id in StoryChapter2.ORDER:
		var quest := StoryChapter2.get_quest(id)
		var status := StoryChapter2.status(id)
		var panel := UIUtil.panel(&"CardPanel")
		box.add_child(panel)
		var col := UIUtil.vbox(2)
		panel.add_child(col)
		var state_text: String = {"new": "ยังไม่ได้รับ", "active": "กำลังทำ", "ready": "เสร็จแล้ว — กลับไปรายงาน", "done": "สำเร็จแล้ว"}[status]
		var title := UIUtil.label("%s  (ดาว %d+)  — %s" % [quest.name, int(quest.star), state_text], &"BoldLabel")
		if status == "done":
			title.add_theme_color_override("font_color", UIPalette.SUCCESS)
		col.add_child(title)
		var detail := UIUtil.label(quest.desc, &"SmallLabel")
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(detail)
		if status == "active" or status == "ready":
			col.add_child(UIUtil.label("ตอนนี้: %s" % StoryChapter2.objective_text(id), &"DimLabel"))
		var pay := StoryChapter2.reward(id)
		col.add_child(UIUtil.label("รางวัล: EXP %d • เหรียญ %d • วัตถุดิบจากวิหารบัวดาราและห้วงสมุทรอสูร%s" % [int(pay.exp), int(pay.gold), " • ตำแหน่ง \"%s\" และรัศมีดาวเงา" % StoryChapter2.END_TITLE if id == StoryChapter2.FINALE else ""], &"DimLabel"))


# ---------------------------------------------------------------------------
# Achievements
# ---------------------------------------------------------------------------

func _build_achievements() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(scroll)
	_page_scroll = scroll
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
		var title := UIUtil.label("%s%s" % ["(สำเร็จ) " if done else "", ach.name], &"BoldLabel")
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
# Titles (Achievements): the title shown above the hero's head
# ---------------------------------------------------------------------------

func _build_titles() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(scroll)
	_page_scroll = scroll
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var worn := Achievements.title_of(Game.profile)
	box.add_child(UIUtil.label("ตำแหน่ง  %d / %d" % [Achievements.earned(Game.profile).size(), Achievements.TABLE.size()], &"HeaderLabel"))
	box.add_child(UIUtil.label("ตำแหน่งที่ใช้: %s" % (worn if worn != "" else "ไม่มี"), &"SubHeaderLabel"))
	for k in Achievements.TABLE.size():
		var row: Dictionary = Achievements.TABLE[k]
		var done := Achievements.is_earned(row.id, Game.profile)
		var has_title := String(row.title) != ""
		var panel := UIUtil.panel(&"CardPanel")
		box.add_child(panel)
		var line := UIUtil.hbox(10)
		panel.add_child(line)
		var col := UIUtil.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(col)
		var title := UIUtil.label("%s%s" % ["(สำเร็จ) " if done else "", row.name], &"BoldLabel")
		title.add_theme_color_override("font_color", UIPalette.SUCCESS if done else UIPalette.TEXT_MUTED)
		col.add_child(title)
		var detail := UIUtil.label("%s  (%s)" % [row.desc, Achievements.progress(row.id, Game.profile)], &"SmallLabel")
		if not done:
			detail.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
		col.add_child(detail)
		if has_title:
			col.add_child(UIUtil.label("ตำแหน่ง: %s" % Achievements.title_text(row, Game.profile), &"DimLabel"))
		# A timed title (หนึ่งในใต้หล้า, MazeCrown): how long it still lasts, or that it ended.
		var lasts := Achievements.wearable(row, Game.profile)
		if done and bool(row.get("timed", false)):
			var left := UIUtil.label(MazeCrown.left_text(MazeCrown.until_of(Game.profile)) if lasts else "หมดอายุแล้ว — ใส่ได้อีกเมื่อครอง%sอีกครั้ง" % MazeCrown.TITLE_NAME, &"SmallLabel")
			left.name = "TitleLeft_%s" % row.id
			left.add_theme_color_override("font_color", MazeCrown.COLOR if lasts else UIPalette.TEXT_MUTED)
			col.add_child(left)
		if done and has_title and (lasts or Achievements.title_index(Game.profile) == k):
			var wearing := Achievements.title_index(Game.profile) == k
			var b := UIUtil.button("ถอดตำแหน่ง" if wearing else "ใช้ตำแหน่ง", &"" if wearing else &"PrimaryButton", Vector2(150, 56))
			b.pressed.connect(func():
				Game.set_title(-1 if wearing else k)
				_queue_rebuild())
			line.add_child(b)


# ---------------------------------------------------------------------------
# Mounts (MountData): craft / level up (MountData.chance), pick the one the HUD's "ขี่" button rides
# ---------------------------------------------------------------------------

func _build_mounts() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(scroll)
	_page_scroll = scroll
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UIUtil.label("สัตว์ขี่  %d / %d" % [Game.owned_mounts().size(), MountData.ALL.size()], &"HeaderLabel"))
	var how := UIUtil.label("สร้างและอัปเลเวลด้วยวัตถุดิบของแต่ละตัว (ดรอปจากมอนสเตอร์ทุกแผนที่ล่า) + เพชรชาออส · โอกาสสำเร็จต่างกันแต่ละตัว ถ้าพลาดวัตถุดิบกับเพชรจะหายไป เลเวลคงเดิม · ค่าพลังของตัวที่ใช้อยู่นับตลอด ขี่หรือไม่ขี่ก็ได้ · ขี่แล้ววิ่งเร็วขึ้น และสู้บนหลังได้เลย · เพชรชาออสในกระเป๋า %d เม็ด" % Game.jewel_count("chaos"), &"SubHeaderLabel")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(how)
	var active := Game.active_mount()
	for id in MountData.ALL:
		var info := MountData.info(id)
		var level := Game.mount_level(id)
		var owned := level > 0
		var panel := UIUtil.panel(&"CardPanel")
		panel.name = "Mount_" + id
		box.add_child(panel)
		var line := UIUtil.hbox(12)
		panel.add_child(line)
		var swatch := ColorRect.new()
		swatch.name = "Colour"
		swatch.color = info.color
		swatch.custom_minimum_size = Vector2(56, 56)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(swatch)
		var icon := TextureRect.new()
		icon.name = "MatIcon"
		icon.texture = ItemLook.icon(ItemData.jewel(MountData.mat_of(id)))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		icon.position = Vector2(8, 8)
		icon.size = Vector2(40, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.add_child(icon)
		var col := UIUtil.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(col)
		var mark := "(กำลังใช้) " if id == active else ("(มีแล้ว) " if owned else "")
		var title := UIUtil.label("%s%s  Lv.%d/%d" % [mark, String(info.name), level, MountData.MAX_LEVEL], &"BoldLabel")
		title.name = "Title"
		if id == active:
			title.add_theme_color_override("font_color", UIPalette.SUCCESS)
		col.add_child(title)
		var now := UIUtil.label("ตอนนี้: " + (MountData.bonus_text(id, level) if owned else "ยังไม่มี"), &"SmallLabel")
		now.name = "Now"
		now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(now)
		var step := ""
		if level < MountData.MAX_LEVEL:
			var cost := MountData.cost(id, level + 1)
			var next := UIUtil.label("Lv.%d: %s" % [level + 1, MountData.bonus_text(id, level + 1)], &"SmallLabel")
			next.name = "Next"
			next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(next)
			var mats := Game.mount_mats(id)
			var chaos := Game.jewel_count("chaos")
			var price := UIUtil.label("ใช้ %s %d/%d · เพชรชาออส %d/%d · โอกาสสำเร็จ %s" % [ItemData.JEWELS[MountData.mat_of(id)].name, mats, int(cost.mat), chaos, int(cost.chaos), MountData.chance_text(id)], &"SmallLabel")
			price.name = "Cost"
			price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			price.add_theme_color_override("font_color", UIPalette.SUCCESS if Game.mount_step_problem(id) == "" else Color("ff8a7a"))
			col.add_child(price)
		col.add_child(UIUtil.label(String(info.desc), &"DimLabel"))
		var buttons := UIUtil.vbox(6)
		buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(buttons)
		var craft_text := "MAX" if level >= MountData.MAX_LEVEL else ("%s (%s)" % ["อัปเลเวล" if owned else "สร้าง", MountData.chance_text(id)])
		var craft := UIUtil.button(craft_text, &"PrimaryButton", Vector2(150, 56))
		craft.name = "Craft"
		craft.disabled = Game.mount_step_problem(id) != ""
		craft.pressed.connect(func():
			var result := Game.craft_mount(id)
			match result:
				"ok":
					if Game.mount_level(id) == 1:
						Game.say("สร้างสัตว์ขี่สำเร็จ! ได้ %s Lv.1" % String(info.name), &"success")
					else:
						Game.say("อัปเลเวลสำเร็จ! %s Lv.%d" % [String(info.name), Game.mount_level(id)], &"success")
					AudioManager.play_sfx(&"level_up", -4.0)
					Game.screen_flash.emit(info.color, 0.12)
				"fail":
					var lv := Game.mount_level(id)
					Game.say("%sพลาด... (วัตถุดิบกับเพชรชาออสหายไป %s)" % ["สร้าง%s" % String(info.name) if lv == 0 else "อัปเลเวล%s" % String(info.name), "ยังไม่ได้ตัว" if lv == 0 else "ยังอยู่ที่ Lv.%d" % lv], &"warning")
				_:
					Game.say(result, &"warning")
			_queue_rebuild())
		buttons.add_child(craft)
		# Many tries in one go (a count chooser, each try its own roll and cost).
		if level < MountData.MAX_LEVEL and Game.mount_max_tries(id) >= 2:
			var many := UIUtil.button("ทำหลายครั้ง", &"AccentButton", Vector2(150, 52))
			many.name = "CraftMany"
			many.pressed.connect(func(): _craft_mount_many(id))
			buttons.add_child(many)
		if owned and id != active:
			var pick := UIUtil.button("ใช้ตัวนี้", &"", Vector2(150, 56))
			pick.name = "Select"
			pick.pressed.connect(func():
				Game.select_mount(id)
				_queue_rebuild())
			buttons.add_child(pick)


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

func _build_settings() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(scroll)
	_page_scroll = scroll
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
			MemoryGuard.reset_scale_3d(get_tree())
			Game.say("ตั้งคุณภาพ: %s (ต้นไม้และหญ้าจะเปลี่ยนเมื่อเข้าแมพใหม่)" % GameSettings.quality_name(), &"info")
			_rebuild())
		q_line.add_child(qb)
	if GameSettings.quality >= 2:
		# High comes in two modes: sharp (the 3D scale stays at 1.0) or smooth (on a phone
		# the 3D scale follows the frame rate like medium does; the HUD stays crisp).
		var smooth := CheckButton.new()
		smooth.text = "สูง (ลื่น): ลดความละเอียด 3D อัตโนมัติเมื่อเฟรมตก (ปิด = สูง (คมชัด))"
		smooth.button_pressed = GameSettings.high_smooth
		smooth.toggled.connect(func(on: bool):
			GameSettings.high_smooth = on
			GameSettings.save_settings()
			MemoryGuard.reset_scale_3d(get_tree())
			Game.say("คุณภาพ: %s" % GameSettings.quality_name(), &"info"))
		box.add_child(smooth)
	var others := CheckButton.new()
	others.text = "แสดงผู้เล่นคนอื่น (AI) ในแมพ"
	others.button_pressed = GameSettings.show_world_players
	others.toggled.connect(func(on: bool):
		GameSettings.show_world_players = on
		GameSettings.save_settings()
		Game.say("ผู้เล่นคนอื่นในแมพ: %s (มีผลเมื่อเข้าแมพใหม่)" % ("แสดง" if on else "ซ่อน"), &"info"))
	box.add_child(others)
	# Real players (Online): on by default; off keeps this game offline.
	var online := CheckButton.new()
	online.name = "OnlinePlay"
	online.text = "เล่นออนไลน์ (พบผู้เล่นจริงที่เข้าสู่ระบบ แชท ปาร์ตี้ แลกของ ดวล)"
	online.button_pressed = GameSettings.online_play
	online.toggled.connect(func(on: bool):
		Online.set_enabled(on)
		Game.say("เล่นออนไลน์: %s" % ("เปิด (ต้องเข้าสู่ระบบบัญชี)" if on else "ปิด เล่นคนเดียว"), &"info"))
	box.add_child(online)
	var safe := CheckButton.new()
	safe.text = "โหมดภาพปลอดภัย (ไม่มีผู้เล่นคนอื่น/ร้านค้า/แสงโคม ใช้เมื่อจอเป็นสีเดียว)"
	safe.button_pressed = GameSettings.safe_picture
	safe.toggled.connect(func(on: bool):
		GameSettings.safe_picture = on
		GameSettings.save_settings()
		Game.say("โหมดภาพปลอดภัย: %s (มีผลเมื่อเข้าแมพใหม่)" % ("เปิด" if on else "ปิด"), &"info"))
	box.add_child(safe)
	var tap_row := UIUtil.hbox(10)
	box.add_child(tap_row)
	tap_row.add_child(UIUtil.label("แตะที่ตัวศัตรู:", &"BoldLabel"))
	var tap := OptionButton.new()
	tap.name = "TapTargetMode"
	for k in GameSettings.TAP_MODES.size():
		tap.add_item(GameSettings.TAP_MODES[k], k)
	tap.select(GameSettings.tap_target_mode)
	tap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tap.custom_minimum_size = Vector2(0, 52)
	tap.item_selected.connect(func(k: int):
		GameSettings.tap_target_mode = k
		GameSettings.save_settings()
		Game.say("แตะที่ตัวศัตรู: %s" % GameSettings.TAP_MODES[k], &"info"))
	tap_row.add_child(tap)
	var hitstop := CheckButton.new()
	hitstop.text = "ชะลอภาพเมื่อโจมตีหนัก (ปิดเพื่อเล่นต่อเนื่อง)"
	hitstop.button_pressed = GameSettings.combat_hitstop
	hitstop.toggled.connect(func(on: bool):
		GameSettings.combat_hitstop = on
		GameSettings.save_settings())
	box.add_child(hitstop)
	var cutin := CheckButton.new()
	cutin.name = "UltCutIn"
	cutin.text = "ฉากท่าไม้ตาย (แถบชื่อสกิลและภาพช้าเมื่อใช้สกิลดาว 200 / สกิลเทพ)"
	cutin.button_pressed = GameSettings.ult_cutin
	cutin.toggled.connect(func(on: bool):
		GameSettings.ult_cutin = on
		GameSettings.save_settings())
	box.add_child(cutin)
	var shake := CheckButton.new()
	shake.name = "ScreenShake"
	shake.text = "สั่นจอ (กล้องซูมและสั่นตามแรงสกิล ปิดถ้าเวียนหัว)"
	shake.button_pressed = GameSettings.screen_shake
	shake.toggled.connect(func(on: bool):
		GameSettings.screen_shake = on
		GameSettings.save_settings())
	box.add_child(shake)
	var save := UIUtil.button("บันทึกเกม", &"PrimaryButton", Vector2(320, 66))
	save.pressed.connect(func():
		if Game.save():
			Game.say("บันทึกเกมแล้ว", &"success")
		else:
			Game.say("บันทึกไม่สำเร็จ กรุณาสำรองรหัสเซฟ", &"warning"))
	box.add_child(save)
	if OS.has_feature("web"):
		var account := UIUtil.button("บัญชี / เซฟออนไลน์", &"PrimaryButton", Vector2(320, 66))
		account.pressed.connect(Game.open_cloud_account)
		box.add_child(account)
		var report := UIUtil.button("รายงานการหลุด", &"", Vector2(320, 66))
		report.pressed.connect(func():
			JavaScriptBridge.eval("if (window.toonSession) window.toonSession.showReport();", true))
		box.add_child(report)
	# Save backup: the save lives in this browser only, so offer copy / paste.
	var backup := UIUtil.button("สำรอง / นำเข้าเซฟ", &"", Vector2(320, 66))
	backup.pressed.connect(_open_backup)
	box.add_child(backup)
	if Game.ending_unlocked():
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
	edit.custom_minimum_size = Vector2(0, 180)
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text = Game.export_code()
	box.add_child(edit)
	var destination_row := UIUtil.hbox(12)
	box.add_child(destination_row)
	destination_row.add_child(UIUtil.label("นำเข้าไปยังช่อง", &"BoldLabel"))
	var destination := OptionButton.new()
	destination.custom_minimum_size = Vector2(370, 56)
	var suggested := Game.free_slot()
	if suggested <= 0:
		suggested = Game.slot
	for save_slot in range(1, Game.SLOT_COUNT + 1):
		var info := Game.slot_info(save_slot)
		var title := "ช่อง %d · ว่าง" % save_slot if info.is_empty() else ("ช่อง %d · เซฟเสียหาย %s" % [save_slot, info.name] if bool(info.get("damaged", false)) else "ช่อง %d · %s Lv.%d" % [save_slot, info.name, info.level])
		destination.add_item(title, save_slot)
	destination.select(suggested - 1)
	destination_row.add_child(destination)
	var row := UIUtil.hbox(10)
	box.add_child(row)
	var copy := UIUtil.button("คัดลอกรหัส", &"PrimaryButton", Vector2(240, 60))
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(edit.text)
		Game.say("คัดลอกแล้ว", &"success"))
	row.add_child(copy)
	var imp := UIUtil.button("ตรวจสอบและนำเข้า", &"", Vector2(260, 60))
	imp.pressed.connect(func(): _confirm_backup(edit.text, destination.get_selected_id()))
	row.add_child(imp)
	var back := UIUtil.button("กลับ", &"", Vector2(160, 60))
	back.pressed.connect(_rebuild)
	row.add_child(back)


## Review validated identity and the exact destination before any file changes.
func _confirm_backup(code: String, target_slot: int) -> void:
	var info := Game.preview_import(code)
	if info.is_empty():
		Game.say("รหัสไม่ถูกต้องหรือข้อมูลเซฟเสียหาย", &"warning")
		return
	var existing := Game.slot_info(target_slot)
	var cls := JobData.resolve(StringName(info["class"]), int(info.adv))
	var message := "%s · %s · Lv.%d\nพื้นที่: %s\nเวลาเล่น: %s\n\nปลายทาง: ช่อง %d" % [
		info.name, cls.name, int(info.level), ZoneData.get_zone(StringName(info.zone)).name,
		UIUtil.format_play_time(float(info.play_time)), target_slot]
	if not existing.is_empty():
		message += "\nจะแทนที่ %s (Lv.%d) ในช่องนี้" % [existing.name, int(existing.level)]
	else:
		message += " (ว่าง)"
	var approved: bool = await ModalDialog.confirm(self, "ตรวจสอบเซฟก่อนนำเข้า", message,
		"นำเข้าและเล่นเซฟนี้", "ยกเลิก", not existing.is_empty())
	if not approved:
		return
	if Game.import_code(code, target_slot):
		Game.say("นำเข้าเซฟช่อง %d สำเร็จ!" % target_slot, &"success")
		close_menu()
	else:
		Game.say("นำเข้าไม่สำเร็จ กรุณาตรวจรหัสและพื้นที่จัดเก็บ", &"warning")


## Rarity belongs to the frame; item artwork keeps its original readable colours.
func _style_item_button(button: Button, rarity: Color, selected: bool) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = UIPalette.CARD.lerp(rarity, 0.10 if state == "normal" else 0.20)
		style.border_color = UIPalette.GOLD if selected else Color(rarity, 0.7)
		style.set_border_width_all(3 if selected else 2)
		style.set_corner_radius_all(13)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		button.add_theme_stylebox_override(state, style)
