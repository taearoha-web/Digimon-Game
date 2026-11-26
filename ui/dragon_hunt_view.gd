class_name DragonHuntView
extends RefCounted
## The game menu's "ล่ามังกรแก้ว" tab (DragonHunt): when the hunt runs (or the next one
## starts), how points are earned (below ★300: the golden monsters), the hero's points with
## a bar, the milestones with a claim button each, and the top hunters, world players and
## the hero together.

const TAB_ID := &"hunt"
const TAB_NAME := "ล่ามังกรแก้ว"


## Builds the page into [param content]; [param changed] is called after a claim.
static func build(content: Control, changed: Callable) -> TouchScroll:
	var scroll := TouchScroll.new()
	scroll.name = "DragonHunt"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var t := DragonHunt.now()
	var n := DragonHunt.index(t)
	var on := DragonHunt.is_on(t)
	var s := DragonHunt.peek(t)
	var head := UIUtil.hbox(10)
	box.add_child(head)
	var title := UIUtil.label("ศึก%s" % DragonHunt.NAME, &"HeaderLabel")
	title.add_theme_color_override("font_color", DragonHunt.COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var all := UIUtil.button("รับทั้งหมด (%d)" % DragonHunt.claimable(t), &"PrimaryButton", Vector2(190, 56))
	all.name = "ClaimAll"
	all.disabled = DragonHunt.claimable(t) == 0
	all.pressed.connect(func():
		var got := DragonHunt.claim_all()
		if got > 0:
			Game.say("รับรางวัลล่ามังกรแล้ว %d ขั้น" % got, &"success")
			AudioManager.play_ui(&"ui_confirm")
		changed.call())
	head.add_child(all)
	var when := ""
	if on:
		when = "กำลังจัด! %s ถึง %s — เหลือ %s" % [DragonHunt.date_text(DragonHunt.start_of(n)), DragonHunt.date_text(DragonHunt.end_of(n)), DailyPass.left_text(t, DragonHunt.end_of(n))]
	else:
		var next := DragonHunt.next_start(t)
		when = "รอบถัดไป %s (อีก %s)%s" % [DragonHunt.date_text(next), DailyPass.left_text(t, next), " — รางวัลที่ถึงแล้วรับได้จนรอบใหม่เริ่ม" if n >= 0 else ""]
	var when_label := UIUtil.label(when, &"SubHeaderLabel")
	when_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(when_label)
	var rules := [
		"• %s มาบ่อยขึ้นสองเท่าตลอดสัปดาห์ที่%s (ดาว %d)" % [WorldEvents.NAME_RARE, SkyIsleData.TITLE, SkyIsleData.ENTRY_STAR],
		"• ปราบมังกรแก้ว (ทีมเราทำดาเมจมากสุด) +%d แต้ม · ช่วยตีแต่ทีมอื่นได้ไป +%d แต้ม (รอบละครั้ง)" % [DragonHunt.RARE_KILL, DragonHunt.RARE_HELP],
		"• ยังไม่ถึงดาว %d? ปราบ%sในทุกแผนที่ล่า +%d แต้มต่อตัว (ทุก 15 นาที)" % [SkyIsleData.ENTRY_STAR, WorldEvents.NAME_GOLDEN, DragonHunt.GOLDEN],
	]
	for line in rules:
		var l := UIUtil.label(line, &"SmallLabel")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	var pts := int(s.pts)
	var last := int(DragonHunt.MILESTONES[-1][0])
	box.add_child(UIUtil.label("แต้มล่าของฉัน %d • ปราบมังกรแก้ว %d ตัว • มอนทองคำ %d ตัว" % [pts, int(s.kills), int(s.golden)], &"BoldLabel"))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.max_value = float(last)
	bar.value = float(mini(pts, last))
	box.add_child(bar)
	box.add_child(UIUtil.label("รางวัลตามแต้ม (ขั้นละครั้ง)", &"SubHeaderLabel"))
	for k in DragonHunt.MILESTONES.size():
		box.add_child(_milestone_row(k, s, changed))
	box.add_child(UIUtil.label("นักล่าแต้มสูงสุด", &"SubHeaderLabel"))
	var rows := DragonHunt.top(t, 10)
	if rows.is_empty():
		box.add_child(UIUtil.label("ยังไม่มีใครล่า — รอศึกเริ่ม", &"DimLabel"))
	for row in rows:
		var line := UIUtil.label("%d. %s — %d แต้ม%s" % [int(row.rank), String(row.name), int(row.pts), "  (ฉัน)" if bool(row.hero) else MazeBoardView.MINE_TAG if bool(row.get("mine", false)) else ""], &"BoldLabel" if bool(row.hero) else &"SmallLabel")
		line.name = "DhuntRank_%d" % int(row.rank)
		if bool(row.hero):
			line.add_theme_color_override("font_color", UIPalette.GOLD)
		elif bool(row.get("mine", false)):
			line.add_theme_color_override("font_color", Color("b8e6c4"))
		box.add_child(line)
	return scroll


static func _milestone_row(k: int, s: Dictionary, changed: Callable) -> Control:
	var need := int(DragonHunt.MILESTONES[k][0])
	var got := DragonHunt.is_claimed(s, k)
	var open := int(s.pts) >= need and int(s.n) >= 0
	var big := bool(DragonHunt.MILESTONES[k][2])
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var col := UIUtil.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(col)
	var head := UIUtil.label("ขั้น %d — %d แต้ม%s" % [k + 1, need, "  ★ รางวัลใหญ่" if big else ""], &"BoldLabel")
	head.add_theme_color_override("font_color", UIPalette.SUCCESS if got else (UIPalette.GOLD if big else (UIPalette.TEXT if open else UIPalette.TEXT_MUTED)))
	col.add_child(head)
	var reward := UIUtil.label(DragonHunt.milestone_text(k), &"SmallLabel")
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(reward)
	var b := UIUtil.button("รับแล้ว" if got else ("รับ" if open else "ล็อก"), &"PrimaryButton" if open and not got else &"", Vector2(120, 52))
	b.name = "Claim%d" % k
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = got or not open
	b.pressed.connect(func():
		var why := DragonHunt.claim(k)
		if why != "ok":
			Game.say(why, &"warning")
		else:
			AudioManager.play_ui(&"ui_confirm")
		changed.call())
	line.add_child(b)
	return panel
