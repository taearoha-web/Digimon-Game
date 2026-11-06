class_name DailyPassView
extends RefCounted
## The game menu's "ภารกิจ & บัตร" tab (DailyPass): today's quests and this week's with
## progress bars and claim buttons, then the month's pass track (30 tiers) with a claim
## button per reached tier, "รับทั้งหมด" and the time left before each reset.

const TAB_ID := &"pass"
const TAB_NAME := "ภารกิจ & บัตร"


## Builds the page into [param content]; [param changed] is called after a claim.
static func build(content: Control, changed: Callable) -> TouchScroll:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var t := DailyPass.now()
	var s := DailyPass.state(t)
	var head := UIUtil.hbox(10)
	box.add_child(head)
	var title := UIUtil.label("ภารกิจ & บัตรสะสมแต้ม", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var all := UIUtil.button("รับทั้งหมด (%d)" % DailyPass.claimable(t), &"PrimaryButton", Vector2(190, 56))
	all.name = "ClaimAll"
	all.disabled = DailyPass.claimable(t) == 0
	all.pressed.connect(func():
		var n := DailyPass.claim_all()
		if n > 0:
			Game.say("รับรางวัลแล้ว %d รายการ" % n, &"success")
			AudioManager.play_ui(&"ui_confirm")
		changed.call())
	head.add_child(all)
	box.add_child(UIUtil.label("ภารกิจรายวัน — รีเซ็ตในอีก %s" % DailyPass.left_text(t, DailyPass.day_end(t)), &"SubHeaderLabel"))
	for i in (s.dq as Array).size():
		box.add_child(_quest_row("d", i, s.dq[i], changed))
	box.add_child(UIUtil.label("ภารกิจรายสัปดาห์ — รีเซ็ตในอีก %s" % DailyPass.left_text(t, DailyPass.week_end(t)), &"SubHeaderLabel"))
	for i in (s.wq as Array).size():
		box.add_child(_quest_row("w", i, s.wq[i], changed))
	var reached := DailyPass.tiers_reached(int(s.pts))
	box.add_child(UIUtil.label("บัตรสะสมแต้ม (ฟรี) — ขั้น %d / %d" % [reached, DailyPass.TIERS], &"SubHeaderLabel"))
	var into := int(s.pts) - reached * DailyPass.TIER_POINTS
	var info := "แต้มบัตร %d • ขั้นถัดไปอีก %d แต้ม" % [int(s.pts), DailyPass.TIER_POINTS - into] if reached < DailyPass.TIERS else "แต้มบัตร %d • ครบทุกขั้นแล้ว!" % int(s.pts)
	box.add_child(UIUtil.label(info, &"DimLabel"))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.max_value = float(DailyPass.TIER_POINTS)
	bar.value = float(DailyPass.TIER_POINTS if reached >= DailyPass.TIERS else into)
	box.add_child(bar)
	var left := DailyPass.month_end(t) - t
	var reset := UIUtil.label("รีเซ็ตต้นเดือนหน้าในอีก %s — รางวัลที่ไม่ได้รับจะหายไป" % DailyPass.left_text(t, DailyPass.month_end(t)), &"SmallLabel")
	if left <= DailyPass.WARN_DAYS * WorldEvents.DAY:
		reset.add_theme_color_override("font_color", UIPalette.WARNING)
	box.add_child(reset)
	box.add_child(UIUtil.label("รายวันได้ %d แต้ม • รายสัปดาห์ได้ %d แต้ม • ขั้นละ %d แต้ม" % [DailyPass.DAILY_POINTS, DailyPass.WEEKLY_POINTS, DailyPass.TIER_POINTS], &"DimLabel"))
	for tier in range(1, DailyPass.TIERS + 1):
		box.add_child(_tier_row(tier, s, reached, changed))
	return scroll


static func _quest_row(scope: String, index: int, entry: Dictionary, changed: Callable) -> Control:
	var row := DailyPass.template(String(entry.id))
	var weekly := scope == "w"
	var done := int(entry.p) >= int(entry.t)
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var col := UIUtil.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(col)
	var title_label := UIUtil.label(String(row.get("name", entry.id)), &"BoldLabel")
	if bool(entry.c):
		title_label.add_theme_color_override("font_color", UIPalette.SUCCESS)
	col.add_child(title_label)
	var desc := UIUtil.label(String(row.get("desc", "%d")) % int(entry.t), &"SmallLabel")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = float(entry.t)
	bar.value = float(entry.p)
	col.add_child(bar)
	var level := int(Game.profile.level)
	col.add_child(UIUtil.label("%s / %s • +%d แต้มบัตร • เหรียญ %s • EXP %s" % [PlayerStall.thousands(int(entry.p)), PlayerStall.thousands(int(entry.t)),
		DailyPass.WEEKLY_POINTS if weekly else DailyPass.DAILY_POINTS, PlayerStall.thousands(DailyPass.quest_gold(level, weekly)),
		PlayerStall.thousands(DailyPass.quest_exp(level, weekly))], &"DimLabel"))
	var b := UIUtil.button("รับแล้ว" if bool(entry.c) else ("รับรางวัล" if done else "กำลังทำ"), &"PrimaryButton" if done and not bool(entry.c) else &"", Vector2(140, 56))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = bool(entry.c) or not done
	b.pressed.connect(func():
		var why := DailyPass.claim_quest(scope, index)
		if why != "ok":
			Game.say(why, &"warning")
		changed.call())
	line.add_child(b)
	return panel


static func _tier_row(tier: int, s: Dictionary, reached: int, changed: Callable) -> Control:
	var got := DailyPass.is_claimed(s, tier)
	var open := tier <= reached
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var col := UIUtil.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(col)
	var big: bool = bool(DailyPass.tier_reward(tier, Game.profile).title) or (DailyPass.REWARDS[tier - 1] as Dictionary).get("jewel", [""])[0] == "set_core"
	var head := UIUtil.label("ขั้น %d%s  (%d แต้ม)" % [tier, "  ★ รางวัลใหญ่" if big else "", tier * DailyPass.TIER_POINTS], &"BoldLabel")
	head.add_theme_color_override("font_color", UIPalette.SUCCESS if got else (UIPalette.GOLD if big else (UIPalette.TEXT if open else UIPalette.TEXT_MUTED)))
	col.add_child(head)
	var reward := UIUtil.label(DailyPass.reward_text(tier, Game.profile), &"SmallLabel")
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(reward)
	var b := UIUtil.button("รับแล้ว" if got else ("รับ" if open else "ล็อก"), &"PrimaryButton" if open and not got else &"", Vector2(120, 52))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = got or not open
	b.pressed.connect(func():
		var why := DailyPass.claim_tier(tier)
		if why != "ok":
			Game.say(why, &"warning")
		else:
			AudioManager.play_ui(&"ui_confirm")
		changed.call())
	line.add_child(b)
	return panel
