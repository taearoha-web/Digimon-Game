class_name WeeklyCollectView
extends RefCounted
## The weekly rare collection's page (สะสมของแรร์, WeeklyCollect) in the game menu
## (GameMenu "weekly"): the week's theme with a live countdown to the Friday 07:40 reset,
## its five pieces (icon, rank, how many the hero carries, about how many an hour of
## hunting finds), the exchange (a card an option: what it takes, what it gives a hero of
## this band, how often it is left this week, "แลก"), the week's top collectors (the hero
## among the AI world players) and the hero's pieces of other themes (when they count
## again). `refresh` rebuilds the page after an exchange.

const TAB_ID := &"weekly"
const ICON := 56.0


static func build(parent: Control, refresh: Callable) -> Control:
	var scroll := TouchScroll.new()
	scroll.name = "WeeklyCollectView"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var t := WorldPresence.clock()
	var head := UIUtil.label(WeeklyCollect.TITLE, &"SubHeaderLabel")
	head.add_theme_color_override("font_color", WeeklyCollect.COLOR)
	box.add_child(head)
	if not WeeklyCollect.on(t):
		var wait := UIUtil.label("เริ่ม %s (เวลาไทย) ทุกสัปดาห์ธีมใหม่ ของแรร์ 5 แบบดรอปจากมอนทุกสนาม แลกรางวัลใหญ่ได้ที่หน้านี้" % WeeklyCollect.date_text(float(WeeklyCollect.START)), &"BoldLabel")
		wait.name = "WeeklyWait"
		wait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(wait)
		return scroll
	var week := WeeklyCollect.week_of(t)
	var th := WeeklyCollect.theme_index(week)
	var theme := WeeklyCollect.theme(week)
	var top := UIUtil.hbox(12)
	box.add_child(top)
	var title := UIUtil.label("ธีมสัปดาห์นี้: %s" % String(theme.name), &"HeaderLabel")
	title.name = "WeeklyTheme"
	title.add_theme_color_override("font_color", Color(theme.color).lightened(0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var clock := UIUtil.chip("", WeeklyCollect.COLOR, 18)
	clock.name = "WeeklyCountdown"
	top.add_child(clock)
	var clock_label: Label = clock.get_child(0)
	var end := WeeklyCollect.week_end(week)
	var tick := func():
		if is_instance_valid(clock_label):
			clock_label.text = "รีเซ็ตใน %s" % WeeklyCollect.left_text(end - WorldPresence.clock())
	tick.call()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(tick)
	box.add_child(timer)
	var tier := WeeklyCollect.hero_tier()
	var how := UIUtil.label("รีเซ็ตทุกวันศุกร์ 07:40 น. (เวลาไทย) รอบนี้ถึง %s · ของแรร์ดรอปจากมอนทุกสนาม ทุกเลเวล อัตราปรับตามความเร็วล่าของสนาม ล่าต่อเนื่องชั่วโมงละราว ๆ %s · มอนอีลีท x%d บอส x%d มอนทองคำ x%d บอสโลก x%d · ชิ้นธีมเก่าไม่หาย ขาย แลกเปลี่ยน วางแผงได้ และใช้แลกได้อีกเมื่อธีมวนกลับมา (ทุก %d สัปดาห์)" % [
		WeeklyCollect.date_text(end), _hourly_text(), int(WeeklyCollect.ELITE), int(WeeklyCollect.BOSS), int(WeeklyCollect.GOLDEN), int(WeeklyCollect.WORLD_BOSS), WeeklyCollect.THEMES.size()], &"SmallLabel")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(how)
	# The five pieces.
	var row := HFlowContainer.new()
	row.name = "WeeklyPieces"
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	box.add_child(row)
	for k in WeeklyCollect.PIECES:
		row.add_child(_piece_card(th, k))
	# The exchange.
	var band := UIUtil.label("แลกของรางวัล · รางวัลตามระดับของคุณ: %s" % WeeklyCollect.TIER_NAMES[tier], &"BoldLabel")
	band.name = "WeeklyTier"
	band.add_theme_color_override("font_color", WeeklyCollect.COLOR.lightened(0.3))
	box.add_child(band)
	for e in WeeklyCollect.OPTIONS:
		box.add_child(_option_card(e, th, tier, refresh))
	# The week's top collectors.
	box.add_child(_leaders(t))
	# Pieces of other themes.
	var others := WeeklyCollect.other_pieces(t)
	if not others.is_empty():
		var old := UIUtil.label("ชิ้นธีมอื่นในกระเป๋า (เก็บไว้แลกได้เมื่อธีมวนกลับมา หรือขาย/แลกเปลี่ยน/วางแผงได้)", &"BoldLabel")
		box.add_child(old)
		for e in others:
			var item: Dictionary = e.item
			var line := UIUtil.hbox(8)
			line.add_child(UIUtil.texture_rect(ItemLook.icon(item), Vector2(36, 36)))
			var at := WeeklyCollect.parse(String(item.id))
			var text := UIUtil.label("%s ×%d · ธีม%s กลับมาสัปดาห์ %s" % [ItemData.name_of(item), int(item.get("count", 1)), String(WeeklyCollect.THEMES[at.x].name),
				WeeklyCollect.date_text(WeeklyCollect.week_start(int(e.back)))], &"SmallLabel")
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.add_child(text)
			box.add_child(line)
	return scroll


## "ธรรมดา 8 · หายาก 4 · ..." pieces an hour at the reference pace (the same in every field).
static func _hourly_text() -> String:
	var parts: PackedStringArray = []
	for k in WeeklyCollect.PIECES:
		var n := 60.0 * WeeklyCollect.REF_PACE / float(WeeklyCollect.RATE[k])
		parts.append("%s %s" % [WeeklyCollect.RANKS[k], String.num(n, 1).trim_suffix(".0")])
	return " · ".join(parts)


static func _piece_card(th: int, k: int) -> Control:
	var item := WeeklyCollect.piece(th, k)
	var color: Color = WeeklyCollect.RANK_COLORS[k]
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "WeeklyPiece_%d" % k
	panel.custom_minimum_size = Vector2(150, 0)
	var col := UIUtil.vbox(2)
	panel.add_child(col)
	var icon := UIUtil.texture_rect(ItemLook.icon(item), Vector2(ICON, ICON))
	icon.name = "WeeklyIcon_%d" % k
	col.add_child(icon)
	var name := UIUtil.label(ItemData.name_of(item), &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	name.add_theme_color_override("font_color", color.lightened(0.25))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name)
	var have := WeeklyCollect.owned(th, k)
	var count := UIUtil.label("%s · มี %d" % [WeeklyCollect.RANKS[k], have], &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	count.name = "WeeklyHave_%d" % k
	count.add_theme_color_override("font_color", Color("8dffb0") if have > 0 else UIPalette.TEXT_MUTED)
	col.add_child(count)
	return panel


static func _option_card(e: Dictionary, th: int, tier: int, refresh: Callable) -> Control:
	var id := String(e.id)
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "WeeklyOption_%s" % id
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	# What it takes: the pieces' icons with have/need.
	var need: Array = e.need
	var cost := UIUtil.hbox(2)
	cost.custom_minimum_size = Vector2(150, 0)
	for k in WeeklyCollect.PIECES:
		if int(need[k]) <= 0:
			continue
		var cell := UIUtil.vbox(0)
		cell.add_child(UIUtil.texture_rect(ItemLook.icon(WeeklyCollect.piece(th, k)), Vector2(30 if id == "set" else 40, 30 if id == "set" else 40)))
		var have := WeeklyCollect.owned(th, k)
		var n := UIUtil.label("%d/%d" % [have, int(need[k])], &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
		n.add_theme_font_size_override("font_size", 14)
		n.add_theme_color_override("font_color", Color("8dffb0") if have >= int(need[k]) else Color("ff8a8a"))
		cell.add_child(n)
		cost.add_child(cell)
	line.add_child(cost)
	var r := WeeklyCollect.rewards(id, tier, String(Game.class_id()))
	var text := UIUtil.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var used := WeeklyCollect.used(id)
	var head := UIUtil.label("%s · แลกแล้ว %d/%d สัปดาห์นี้" % [String(e.name), used, int(e.limit)], &"BoldLabel")
	head.add_theme_color_override("font_color", WeeklyCollect.COLOR.lightened(0.35) if id == "set" else Color("e6ecff"))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(head)
	var gives := UIUtil.label("ได้รับ: %s%s" % [WeeklyCollect.reward_text(r), " · ตำแหน่ง \"นักสะสมของแรร์\" ครั้งแรก" if id == "set" else ""], &"SmallLabel")
	gives.name = "WeeklyGives_%s" % id
	gives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(gives)
	line.add_child(text)
	var problem := WeeklyCollect.problem(id)
	var buy := UIUtil.button("แลก", &"AccentButton", Vector2(120, 54))
	buy.name = "WeeklyBuy_%s" % id
	buy.disabled = problem != ""
	buy.tooltip_text = problem
	buy.pressed.connect(func():
		var result := WeeklyCollect.exchange(id)
		if result == "ok":
			AudioManager.play_sfx(&"confirm_big" if id == "set" else &"coin")
			Game.say("แลก %s แล้ว! %s" % [String(e.name), WeeklyCollect.reward_text(r)], &"success")
		else:
			Game.say(result, &"warning")
		refresh.call())
	line.add_child(buy)
	return panel


static func _leaders(t: float) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "WeeklyLeaders"
	var col := UIUtil.vbox(4)
	panel.add_child(col)
	var head := UIUtil.label("อันดับนักสะสมประจำสัปดาห์ (แต้ม: %s)" % " / ".join(range(WeeklyCollect.PIECES).map(func(k): return "%s %d" % [WeeklyCollect.RANKS[k], WeeklyCollect.POINTS[k]])), &"BoldLabel")
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(head)
	var rows := WeeklyCollect.leaderboard(t)
	var hero_in := false
	for n in rows.size():
		var r: Dictionary = rows[n]
		hero_in = hero_in or bool(r.hero)
		col.add_child(_leader_row(n + 1, r))
	if not hero_in and Game.has_profile:
		col.add_child(_leader_row(WeeklyCollect.hero_rank(t), {"name": String(Game.profile.get("name", "")), "pts": WeeklyCollect.points(t), "hero": true}))
	return panel


static func _leader_row(rank: int, r: Dictionary) -> Control:
	var line := UIUtil.hbox(8)
	line.name = "WeeklyRank_%d" % rank
	var place := UIUtil.label("%d." % rank if rank > 3 else "%d" % rank, &"BoldLabel")
	place.custom_minimum_size = Vector2(44, 0)
	place.add_theme_color_override("font_color", [Color("ffd23a"), Color("dfe6f0"), Color("e0a060")][rank - 1] if rank >= 1 and rank <= 3 else UIPalette.TEXT_MUTED)
	line.add_child(place)
	var name := UIUtil.label(String(r.name) + (" (คุณ)" if bool(r.hero) else ""), &"SmallLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bool(r.hero):
		name.add_theme_color_override("font_color", Color("8dffb0"))
	line.add_child(name)
	var pts := UIUtil.label("%s แต้ม" % PlayerStall.thousands(int(r.pts)), &"SmallLabel")
	pts.add_theme_color_override("font_color", WeeklyCollect.COLOR)
	line.add_child(pts)
	return line
