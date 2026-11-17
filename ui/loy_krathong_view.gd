class_name LoyKrathongView
extends RefCounted
## The game menu's "ลอยกระทง" tab (LoyKrathong): the festival's dates with a live countdown,
## the night and the Naga, the four materials (have, an hour's finds), the krathongs (make
## one, float one with a wish: at the pier only, the day's floats left, what each gives
## this hero's band), the pageant (enter once a day, today's outfit score, the stage's
## standings, the result) and the festival costume (pieces and points, exchange).
## `refresh` rebuilds the page; `close` shuts the menu after a float so the krathong is
## seen setting off.

const TAB_ID := &"loyk"
const TAB_NAME := "ลอยกระทง"
const ICON := 52.0

## The wish being typed (kept across the page's rebuilds).
static var wish_text := ""


static func build(content: Control, refresh: Callable, close: Callable = Callable()) -> TouchScroll:
	var scroll := TouchScroll.new()
	scroll.name = "LoyKrathongView"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var t := LoyKrathong.now()
	var top := UIUtil.hbox(12)
	box.add_child(top)
	var title := UIUtil.label(LoyKrathong.TITLE + " ๒๕๖๙", &"HeaderLabel")
	title.add_theme_color_override("font_color", LoyKrathong.COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var clock := UIUtil.chip("", LoyKrathong.COLOR, 18)
	clock.name = "LoykCountdown"
	top.add_child(clock)
	var clock_label: Label = clock.get_child(0)
	var tick := func():
		if is_instance_valid(clock_label):
			clock_label.text = _clock_text(LoyKrathong.now())
	tick.call()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(tick)
	box.add_child(timer)
	var when := UIUtil.label("%s - %s (เวลาไทย) · คืนลอยกระทง อังคาร 24 พ.ย. 19:00-23:00: EXP x2 (รวมกับ EXP x2 ช่วงเย็นเป็น x3 ถึงสามทุ่ม) โคมลอยเต็มฟ้า และ%sขึ้นจากน้ำในทุกแผนที่ล่าตอน 20:00 21:00 22:00 (รอบละ %d นาที)" % [
		LoyKrathong.date_text(float(LoyKrathong.START)), LoyKrathong.date_text(float(LoyKrathong.END)), LoyKrathong.NAGA_NAME, LoyKrathong.NAGA_LENGTH / 60], &"SmallLabel")
	when.name = "LoykWhen"
	when.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(when)
	if t < float(LoyKrathong.START):
		var wait := UIUtil.label("เทศกาลยังไม่เริ่ม เตรียมตัวล่ามอนเก็บใบตองมาทำกระทงกัน!", &"BoldLabel")
		wait.name = "LoykWait"
		box.add_child(wait)
	# The materials.
	box.add_child(_head("วัสดุทำกระทง · ดรอปจากมอนทุกแผนที่ล่าช่วงเทศกาล (อีลีท x3 บอส x10 มอนทองคำ x15 บอสโลก x20)"))
	var mats := HFlowContainer.new()
	mats.name = "LoykMats"
	mats.add_theme_constant_override("h_separation", 8)
	mats.add_theme_constant_override("v_separation", 8)
	box.add_child(mats)
	for k in LoyKrathong.MATS.size():
		mats.add_child(_mat_card(k))
	# The krathongs.
	var left := LoyKrathong.floats_left(t)
	var at_pier := LoyKrathongPier.hero_at_pier()
	box.add_child(_head("ทำกระทงและลอยกระทง · วันนี้ลอยได้อีก %d/%d ใบ · รางวัลตามระดับ: %s" % [left, LoyKrathong.DAILY_FLOATS, WeeklyCollect.TIER_NAMES[WeeklyCollect.hero_tier()]]))
	var wish_row := UIUtil.hbox(8)
	box.add_child(wish_row)
	wish_row.add_child(UIUtil.label("คำอธิษฐาน", &"BoldLabel"))
	var wish := LineEdit.new()
	wish.name = "LoykWish"
	wish.placeholder_text = "เช่น ขอให้ตีบวกติด (ไม่เกิน %d ตัวอักษร)" % LoyKrathong.WISH_MAX
	wish.max_length = LoyKrathong.WISH_MAX
	wish.text = wish_text
	wish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wish.custom_minimum_size = Vector2(0, 52)
	wish.text_changed.connect(func(text: String): wish_text = text)
	wish_row.add_child(wish)
	if not at_pier:
		var go := UIUtil.label("ทำกระทงได้ทุกที่ ส่วนการลอยต้องไปที่ท่าน้ำลอยกระทงในหมู่บ้าน (สระปลาคาร์ป ย่านบ้านพักและสวน)", &"SmallLabel")
		go.name = "LoykGoToPier"
		go.add_theme_color_override("font_color", Color("ffd27a"))
		go.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(go)
	for k in LoyKrathong.KRATHONGS.size():
		box.add_child(_krathong_card(k, at_pier, refresh, close))
	# The pageant.
	box.add_child(_pageant(t, refresh))
	# The costume.
	box.add_child(_costume(t, refresh))
	return scroll


static func _clock_text(t: float) -> String:
	if t < float(LoyKrathong.START):
		return "เริ่มใน %s" % LoyKrathong.left_text(float(LoyKrathong.START) - t)
	if t >= float(LoyKrathong.END):
		return "เทศกาลจบแล้ว"
	if LoyKrathong.night_on(t):
		return "คืนลอยกระทง! เหลือ %s" % LoyKrathong.left_text(float(LoyKrathong.NIGHT_END) - t)
	return "เหลือ %s" % LoyKrathong.left_text(float(LoyKrathong.END) - t)


static func _head(text: String) -> Label:
	var l := UIUtil.label(text, &"BoldLabel")
	l.add_theme_color_override("font_color", LoyKrathong.COLOR.lightened(0.3))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _mat_card(k: int) -> Control:
	var item := LoyKrathong.mat(k)
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "LoykMat_%d" % k
	panel.custom_minimum_size = Vector2(150, 0)
	var col := UIUtil.vbox(2)
	panel.add_child(col)
	col.add_child(UIUtil.texture_rect(ItemLook.icon(item), Vector2(ICON, ICON)))
	var name := UIUtil.label(LoyKrathong.MAT_NAMES[k], &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	name.add_theme_color_override("font_color", ItemData.color_of(item).lightened(0.25))
	col.add_child(name)
	var have := LoyKrathong.owned(LoyKrathong.MATS[k])
	var per := 60.0 * LoyKrathong.REF_PACE / float(LoyKrathong.RATE[k])
	var count := UIUtil.label("%s · มี %d\n~%s ต่อชม." % [LoyKrathong.MAT_RANKS[k], have, String.num(per, 1).trim_suffix(".0")], &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	count.name = "LoykHave_%d" % k
	count.add_theme_color_override("font_color", Color("8dffb0") if have > 0 else UIPalette.TEXT_MUTED)
	col.add_child(count)
	return panel


static func _krathong_card(k: int, at_pier: bool, refresh: Callable, close: Callable) -> Control:
	var e: Dictionary = LoyKrathong.KRATHONGS[k]
	var item := LoyKrathong.krathong(k)
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "LoykKrathong_%d" % k
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	line.add_child(UIUtil.texture_rect(ItemLook.icon(item), Vector2(ICON + 8, ICON + 8)))
	var text := UIUtil.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var have := LoyKrathong.owned(String(e.id))
	var head := UIUtil.label("%s · มี %d ใบ · %d แต้ม" % [String(e.name), have, int(e.pts)], &"BoldLabel")
	head.add_theme_color_override("font_color", (e.color as Color).lightened(0.3))
	text.add_child(head)
	var need := UIUtil.label("ทำจาก: %s" % LoyKrathong.need_text(k), &"SmallLabel")
	need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(need)
	var r := LoyKrathong.rewards(k, WeeklyCollect.hero_tier(), String(Game.class_id()) if Game.has_profile else "warrior")
	var gives := LoyKrathong.reward_text(r)
	if k == LoyKrathong.KRATHONGS.size() - 1:
		gives += " · ลุ้นของแรร์: ไข่มังกรฟ้าเทพ 1% · ชุดลอยกระทง 1% · ชิ้นส่วนชุดเทพมังกร ×3 10% · ชิ้นส่วนชุดลอยกระทง ×1-3"
	var gl := UIUtil.label("ลอยแล้วได้: %s" % gives, &"SmallLabel")
	gl.name = "LoykGives_%d" % k
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(gl)
	var buttons := UIUtil.vbox(4)
	line.add_child(buttons)
	var craft := UIUtil.button("ทำ", &"AccentButton", Vector2(110, 48))
	craft.name = "LoykCraft_%d" % k
	var cp := LoyKrathong.craft_problem(k)
	craft.disabled = cp != ""
	craft.tooltip_text = cp
	craft.pressed.connect(func():
		var result := LoyKrathong.craft(k)
		if result == "ok":
			AudioManager.play_sfx(&"coin")
			Game.say("ทำ%sแล้ว!" % String(e.name), &"success")
		else:
			Game.say(result, &"warning")
		refresh.call())
	buttons.add_child(craft)
	var float_b := UIUtil.button("ลอย", &"PrimaryButton", Vector2(110, 48))
	float_b.name = "LoykFloat_%d" % k
	var fp := LoyKrathong.float_problem(k)
	if fp == "" and not at_pier:
		fp = "ไปลอยที่ท่าน้ำลอยกระทงในหมู่บ้าน"
	float_b.disabled = fp != ""
	float_b.tooltip_text = fp
	float_b.pressed.connect(func():
		var out := LoyKrathong.float_krathong(k, wish_text)
		if String(out.result) == "ok":
			AudioManager.play_sfx(&"confirm_big" if bool(out.get("jackpot", false)) else &"coin")
			var said := "ลอย%sแล้ว%s · ได้ %s" % [String(e.name), (" \"%s\"" % String(out.wish)) if String(out.wish) != "" else "",
				WeeklyCollect.reward_text({"gold": int(out.gold), "items": out["items"]})]
			Game.say(said, &"success")
			wish_text = ""
			if close.is_valid():
				close.call()
				return
		else:
			Game.say(String(out.result), &"warning")
		refresh.call())
	buttons.add_child(float_b)
	return panel


static func _pageant(t: float, refresh: Callable) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "LoykPageant"
	var col := UIUtil.vbox(4)
	panel.add_child(col)
	var head := UIUtil.label(LoyKrathong.PAGEANT_NAME + " ๒๕๖๙", &"SubHeaderLabel")
	head.add_theme_color_override("font_color", Color("ff9ccb"))
	col.add_child(head)
	var gender := LoyKrathong.hero_gender()
	var d := LoyKrathong.peek()
	var entered := int(d.get("pg", 0)) > 0
	if entered:
		gender = int(d.get("pgg", gender))
	var rules := UIUtil.label("ขึ้นเวทีที่เวทีริมสระวันละครั้ง ผู้เล่นทั้งเซิร์ฟโหวตตามความงามของชุด: คอสตูม (ชุดลอยกระทงได้ใจที่สุด) ปีก ระดับและการตีบวกของอุปกรณ์ บวกเสียงเชียร์ของวันนั้น เก็บคะแนนที่ดีที่สุดไว้ · ประกาศผล %s · ผู้ชนะได้ตำแหน่ง \"%s\" (สาว) / \"%s\" (หนุ่ม) ตามตัวละคร" % [
		LoyKrathong.date_text(float(LoyKrathong.RESULT_AT)), LoyKrathong.QUEEN_TITLE, LoyKrathong.KING_TITLE], &"SmallLabel")
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(rules)
	var line := UIUtil.hbox(10)
	col.add_child(line)
	var me := UIUtil.label("ชุดวันนี้ %d/100 คะแนนความงาม · โหวตดีที่สุด %s · ลงประกวดเป็น%s" % [LoyKrathong.hero_splendour(), PlayerStall.thousands(int(d.get("pg", 0))) if entered else "-", "นางนพมาศ" if gender == 1 else "หนุ่มลอยกระทง"], &"BoldLabel")
	me.name = "LoykMyScore"
	me.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	me.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(me)
	var enter := UIUtil.button("ขึ้นเวที", &"PrimaryButton", Vector2(130, 52))
	enter.name = "LoykEnter"
	var why := LoyKrathong.entry_problem(t)
	enter.disabled = why != ""
	enter.tooltip_text = why
	enter.pressed.connect(func():
		var out := LoyKrathong.enter()
		if String(out.result) == "ok":
			AudioManager.play_sfx(&"confirm_big")
			Game.say("เดินแบบบนเวที! ได้ %s โหวต (ดีที่สุด %s) +%d แต้มลอยกระทง" % [PlayerStall.thousands(int(out.votes)), PlayerStall.thousands(int(out.best)), LoyKrathong.ENTRY_POINTS], &"success")
		else:
			Game.say(String(out.result), &"warning")
		refresh.call())
	line.add_child(enter)
	var out := LoyKrathong.result_out(t)
	if out:
		var res := UIUtil.label("ประกาศผลแล้ว! ", &"BoldLabel")
		res.name = "LoykResult"
		var q := LoyKrathong.standings(1)
		var k := LoyKrathong.standings(0)
		res.text += "%s: %s · %s: %s" % [LoyKrathong.QUEEN_TITLE, String(q[0].name) if not q.is_empty() else "-", LoyKrathong.KING_TITLE, String(k[0].name) if not k.is_empty() else "-"]
		res.add_theme_color_override("font_color", UIPalette.GOLD)
		res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(res)
	col.add_child(UIUtil.label(("ผลการประกวด%s" if out else "อันดับตอนนี้: %s") % ("นางนพมาศ" if gender == 1 else "หนุ่มลอยกระทง"), &"BoldLabel"))
	var rows := LoyKrathong.standings(gender)
	var shown := 0
	for row in rows:
		if shown >= 6 and not bool(row.hero):
			continue
		shown += 1
		var l := UIUtil.label("%d. %s — %s โหวต%s" % [int(row.rank), String(row.name), PlayerStall.thousands(int(row.votes)), "  (ฉัน)" if bool(row.hero) else ""], &"BoldLabel" if bool(row.hero) else &"SmallLabel")
		l.name = "LoykRank_%d" % int(row.rank)
		if bool(row.hero):
			l.add_theme_color_override("font_color", UIPalette.GOLD)
		elif int(row.rank) == 1:
			l.add_theme_color_override("font_color", Color("ff9ccb"))
		col.add_child(l)
	return panel


static func _costume(t: float, refresh: Callable) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "LoykCostume"
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var item := RewardShop.costume_item(LoyKrathong.COSTUME)
	line.add_child(UIUtil.texture_rect(ItemLook.icon(item), Vector2(84, 84)))
	var col := UIUtil.vbox(3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(col)
	var e: Dictionary = RewardShop.COSTUMES[LoyKrathong.COSTUME]
	var head := UIUtil.label(String(e.name) + (" · มีแล้ว" if RewardShop.owns(LoyKrathong.COSTUME) else ""), &"BoldLabel")
	head.add_theme_color_override("font_color", LoyKrathong.COLOR)
	col.add_child(head)
	var desc := UIUtil.label(String(e.desc), &"SmallLabel")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)
	var pieces := LoyKrathong.owned(LoyKrathong.PIECE)
	var prog := UIUtil.label("%s %d/%d · แต้มลอยกระทง %d/%d (ลอยกระทง ขึ้นเวที ปราบพญานาค)" % [ItemData.JEWELS[LoyKrathong.PIECE].name, pieces, LoyKrathong.COSTUME_PIECES, LoyKrathong.points(), LoyKrathong.COSTUME_POINTS], &"SmallLabel")
	prog.name = "LoykCostumeProgress"
	prog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(prog)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = maxf(float(pieces) / float(LoyKrathong.COSTUME_PIECES), float(LoyKrathong.points()) / float(LoyKrathong.COSTUME_POINTS))
	col.add_child(bar)
	var buttons := UIUtil.vbox(4)
	line.add_child(buttons)
	for how in [["pieces", "แลกด้วยชิ้นส่วน"], ["points", "แลกด้วยแต้ม"]]:
		var b := UIUtil.button(String(how[1]), &"AccentButton", Vector2(170, 48))
		b.name = "LoykCostume_%s" % String(how[0])
		var why := LoyKrathong.costume_problem(String(how[0]), t)
		b.disabled = why != ""
		b.tooltip_text = why
		b.pressed.connect(func():
			var result := LoyKrathong.exchange_costume(String(how[0]))
			if result == "ok":
				AudioManager.play_sfx(&"confirm_big")
				Game.say("ได้%sแล้ว! ใส่ได้ที่ช่องคอสตูมในกระเป๋า" % String(e.name), &"success")
			else:
				Game.say(result, &"warning")
			refresh.call())
		buttons.add_child(b)
	return panel
