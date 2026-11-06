class_name LeagueView
extends RefCounted
## The weekly guild league page (ลีกกิลด์รายสัปดาห์, GuildLeague), shown in the guild
## registrar (GuildScreen "league") and the game menu (GameMenu "league"): the season's
## time left and castle holder, the table (rank, guild, points, wins, captures, holder),
## last season's champion, the top-three reward to claim and, for the champion's
## members, the secret shop. `refresh` rebuilds the page after a claim or a buy.

const GOLD := Color("ffd84a")


static func build(parent: Control, refresh: Callable) -> Control:
	var t := WorldPresence.clock()
	var w := GuildLeague.week_of(t)
	var mine := Game.guild()
	var scroll := TouchScroll.new()
	scroll.name = "LeagueView"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UIUtil.label("ลีกกิลด์รายสัปดาห์", &"SubHeaderLabel"))
	var left := int(GuildLeague.week_end(w) - t)
	var holder := GuildLeague.holder(w, GuildLeague.real_wars(w), t)
	var info := UIUtil.label("ฤดูกาลนี้ (จันทร์ 00:00 – อาทิตย์ 23:59 เวลาไทย) จบใน %d วัน %d ชม. · ผู้ครองปราสาทตอนนี้: กิลด์ %s — ใครครองปราสาทตอนจบฤดูกาลเป็นแชมป์" % [
		left / 86400, (left % 86400) / 3600, GuildLeague.name_of(holder)], &"SmallLabel")
	info.name = "LeagueInfo"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)
	var rule := UIUtil.label("แต้ม: ชนะ %d · แพ้ %d · ยึดปราสาทครั้งละ %d · ครองปราสาทตอนจบสงคราม %d · ล้มศัตรูทุก %d คน +1 — สงครามกิลด์จริงของคุณนับให้กิลด์ของคุณ" % [
		GuildLeague.WIN, GuildLeague.LOSS, GuildLeague.CAPTURE, GuildLeague.HOLD, GuildLeague.KILLS_PER_POINT], &"SmallLabel")
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(rule)
	box.add_child(_table(GuildLeague.table(w, GuildLeague.real_wars(w), t), holder, mine))
	# Last season: its champion and what it brings.
	var champ := GuildLeague.champion_now(t)
	var last := UIUtil.label("%s แชมป์สัปดาห์ที่แล้ว: กิลด์ %s — สมาชิกได้ป้ายชื่อมงกุฎทอง EXP +%d%% และร้านลับแชมป์ตลอดสัปดาห์นี้" % [
		GuildLeague.CROWN, GuildLeague.name_of(champ), int(GuildLeague.EXP_BONUS * 100.0)], &"BoldLabel")
	last.name = "LeagueChampion"
	last.add_theme_color_override("font_color", GuildLeague.CROWN_COLOR)
	last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(last)
	box.add_child(_reward_card(refresh, mine))
	if GuildLeague.hero_champion(t):
		box.add_child(UIUtil.label("ร้านลับแชมป์ปราสาท (เปิดถึงสิ้นสัปดาห์)", &"SubHeaderLabel"))
		box.add_child(UIUtil.label("ทองของคุณ %s" % GuildScreen._num(int(Game.profile.gold)), &"SmallLabel"))
		for e in GuildLeague.SHOP:
			box.add_child(_shop_card(e, refresh))
	else:
		var closed := UIUtil.label("ร้านลับแชมป์ปราสาท: เปิดให้สมาชิกกิลด์แชมป์เท่านั้น (แก่นเทพหลอมเซต เพชร ยา และตำแหน่ง \"ราชันปราสาท\")", &"SmallLabel")
		closed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(closed)
	return scroll


static func _table(rows: Array[Dictionary], holder: int, mine: int) -> Control:
	var grid := GridContainer.new()
	grid.name = "LeagueTable"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	for head in ["อันดับ", "กิลด์", "แต้ม", "ชนะ-แพ้", "ยึดปราสาท", "ครองปราสาท"]:
		grid.add_child(UIUtil.label(head, &"BoldLabel"))
	for r in rows:
		var g := int(r.g)
		var color := GuildLeague.color_of(g).lerp(Color.WHITE, 0.25)
		var cells := ["%d" % int(r.rank), "%s%s" % [String(r.name), " (กิลด์คุณ)" if g == mine else ""], "%d" % int(r.points),
			"%d-%d" % [int(r.wins), int(r.losses)], "%d" % int(r.captures), GuildLeague.CROWN if g == holder else ""]
		for k in cells.size():
			var cell := UIUtil.label(String(cells[k]), &"BoldLabel" if g == mine or k == 5 else &"")
			cell.add_theme_color_override("font_color", GuildLeague.CROWN_COLOR if k == 5 else (GOLD if g == mine else color))
			if k == 1:
				cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell.name = "Guild_%d" % g
			grid.add_child(cell)
	return grid


static func _reward_card(refresh: Callable, mine: int) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "LeagueReward"
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var reward := GuildLeague.claimable()
	var text := ""
	if mine <= 0:
		text = "เข้ากิลด์เพื่อลุ้นรางวัล 3 อันดับแรกทุกสัปดาห์"
	elif reward.is_empty():
		var w := GuildLeague.week_of(WorldPresence.clock()) - 1
		var rank := GuildLeague.rank_of(w, GuildLeague.real_wars(w), mine)
		text = "สัปดาห์ที่แล้วกิลด์ของคุณได้อันดับ %d" % rank + (" · รับรางวัลแล้ว" if rank <= 3 else " · 3 อันดับแรกได้ทองและเพชรทุกสัปดาห์")
	else:
		text = "สัปดาห์ที่แล้วกิลด์ของคุณได้อันดับ %d! รางวัล: %s" % [int(reward.rank), GuildLeague.reward_text(reward)]
	var label := UIUtil.label(text, &"BoldLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	if not reward.is_empty():
		var claim := UIUtil.button("รับรางวัล", &"PrimaryButton", Vector2(130, 58))
		claim.name = "LeagueClaim"
		claim.pressed.connect(func():
			var result := GuildLeague.claim()
			if result == "ok":
				AudioManager.play_sfx(&"coin")
				Game.say("รับรางวัลลีกกิลด์อันดับ %d: %s" % [int(reward.rank), GuildLeague.reward_text(reward)], &"success")
			else:
				Game.say(result, &"warning")
			refresh.call())
		line.add_child(claim)
	return panel


static func _shop_card(e: Dictionary, refresh: Callable) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var item := GuildLeague.shop_item(e)
	var label := UIUtil.label("%s · ซื้อแล้ว %d/%d" % [GuildLeague.shop_name(e), GuildLeague.shop_bought(String(e.id)), int(e.limit)], &"BoldLabel")
	label.add_theme_color_override("font_color", (ItemData.color_of(item) if not item.is_empty() else GuildLeague.CROWN_COLOR).lerp(Color.WHITE, 0.4))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var problem := GuildLeague.shop_problem(e)
	var buy := UIUtil.button("%s ทอง" % GuildScreen._num(int(e.price)), &"AccentButton", Vector2(170, 54))
	buy.name = "LeagueBuy_%s" % String(e.id)
	buy.disabled = problem != ""
	buy.tooltip_text = problem
	buy.pressed.connect(func():
		var result := GuildLeague.shop_buy(String(e.id))
		if result == "ok":
			AudioManager.play_sfx(&"pickup")
			Game.say("ซื้อ %s จากร้านลับแชมป์แล้ว" % GuildLeague.shop_name(e), &"success")
		else:
			Game.say(result, &"warning")
		refresh.call())
	line.add_child(buy)
	return panel
