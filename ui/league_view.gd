class_name LeagueView
extends RefCounted
## The weekly guild league page (ลีกกิลด์รายสัปดาห์, GuildLeague), shown in the guild
## registrar (GuildScreen "league") and the game menu (GameMenu "league"): the season's
## time left and castle holder, the table (rank, guild, points, wins, captures, holder)
## and the deciding round's ×2 note, last season's two titles (แชมป์ลีก by points,
## ราชันปราสาท the castle holder after Sunday 21:30) and the emperor who won both, the
## top-three reward (and the emperor's bonus) to claim and, for the Castle King's members,
## the secret shop. `refresh` rebuilds the page after a claim or a buy.

const GOLD := Color("ffd84a")


static func build(parent: Control, refresh: Callable) -> Control:
	var t := WorldPresence.clock()
	var w := GuildLeague.week_of(t)
	# The rounds' official results from the server (GuildLeague / LeagueRounds).
	LeagueRounds.want_fetch()
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
	var info := UIUtil.label("ฤดูกาลนี้ (จันทร์ 00:00 – อาทิตย์ 23:59 เวลาไทย) จบใน %d วัน %d ชม. · ผู้ครองปราสาทตอนนี้: กิลด์ %s — 2 ตำแหน่งทุกสัปดาห์: %s = แต้มรวมอันดับ 1 (รับรางวัลอันดับ 1) · %s = ผู้ครองปราสาทหลังรอบชี้ขาด อาทิตย์ 21:30 (ป้ายมงกุฎ EXP +%d%% ร้านลับ) · ได้ทั้งสองเป็น%s" % [
		left / 86400, (left % 86400) / 3600, GuildLeague.name_of(holder), GuildLeague.LEAGUE_TITLE, GuildLeague.CASTLE_TITLE,
		int(GuildLeague.EXP_BONUS * 100.0), GuildLeague.EMPEROR_TITLE], &"SmallLabel")
	info.name = "LeagueInfo"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)
	var rule := UIUtil.label("4 กิลด์ (Alpha · Neverdie · Titan · 3DLnw) รบกันตามเวลาจริงวันละ 3 รอบ %s ทุกรอบทั้ง 4 กิลด์ชิงปราสาทในสนามเดียวกัน · แต้มตามอันดับ %s · ยึดปราสาทครั้งละ %d · ครองปราสาทตอนจบ %d · ล้มศัตรูทุก %d คน +1 · ผู้ครองปราสาทครองต่อข้ามรอบจนกว่าจะถูกยึด — รอบที่คุณลงสนามหรือชมจนจบนับผลจริง รอบอื่นตัดสินจากกำลังจริงของทุกกิลด์ · ผลของรอบที่จบแล้วบันทึกถาวร เหมือนกันทุกเครื่อง" % [
		GuildWarScreen._slot_list(), " / ".join(GuildLeague.PLACE_POINTS.map(func(v): return str(v))), GuildLeague.CAPTURE, GuildLeague.HOLD, GuildLeague.KILLS_PER_POINT], &"SmallLabel")
	rule.text += " · %s: รอบอาทิตย์ 21:30 แต้มอันดับและแต้มยึดปราสาท ×%d" % [GuildLeague.FINAL_TAG, GuildLeague.FINAL_MULT]
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(rule)
	box.add_child(_table(GuildLeague.table(w, GuildLeague.real_wars(w), t), holder, mine))
	box.add_child(_final_note(w, t))
	# Last season: its two titles (and the emperor) and what they bring.
	var real_last := GuildLeague.real_wars(w - 1)
	var champ := GuildLeague.champion_now(t)
	var league_champ := GuildLeague.league_champion_now(t)
	var last := UIUtil.label("สัปดาห์ที่แล้ว · %s (แต้มรวมอันดับ 1): กิลด์ %s · %s %s (ครองปราสาทหลังรอบชี้ขาด): กิลด์ %s — สมาชิก%sได้ป้ายชื่อมงกุฎทอง EXP +%d%% และร้านลับ%sตลอดสัปดาห์นี้" % [
		GuildLeague.LEAGUE_TITLE, GuildLeague.name_of(league_champ) if league_champ > 0 else "-", GuildLeague.CROWN, GuildLeague.CASTLE_TITLE,
		GuildLeague.name_of(champ), GuildLeague.CASTLE_TITLE, int(GuildLeague.EXP_BONUS * 100.0), GuildLeague.CASTLE_TITLE], &"BoldLabel")
	last.name = "LeagueChampion"
	last.add_theme_color_override("font_color", GuildLeague.CROWN_COLOR)
	last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(last)
	# The season's Legendary Guild Wings (LegendWings): the champion's leader wears them; a
	# champion again hands the new pair to a member.
	var legend := UIUtil.label("%s — %s: มอบให้หัวหน้ากิลด์%s ใส่ทันทีถอดไม่ได้ ทุกค่าสถานะเหนือปีก 100 ดาว +15 พร้อมออร่าปาร์ตี้ +%d%% · แชมป์ซ้ำสัปดาห์ถัดไปหัวหน้าต้องมอบคู่ใหม่ให้สมาชิก" % [
		LegendWings.line_now(), LegendWings.NAME, GuildLeague.LEAGUE_TITLE, int(round(LegendWings.AURA * 100.0))], &"SmallLabel")
	legend.name = "LegendLine"
	legend.add_theme_color_override("font_color", LegendWings.COLOR)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(legend)
	var emperor := GuildLeague.emperor_of(w - 1, real_last)
	var emp_text := "%s: กิลด์ %s ได้ทั้ง%sและ%s — สมาชิกรับ%s และตำแหน่ง \"%s\" พร้อมรางวัลประจำสัปดาห์" % [GuildLeague.EMPEROR_TITLE, GuildLeague.name_of(emperor),
		GuildLeague.LEAGUE_TITLE, GuildLeague.CASTLE_TITLE, GuildLeague.reward_text({"jewels": GuildLeague.EMPEROR_BONUS}), GuildLeague.EMPEROR_TITLE] \
		if emperor > 0 else "%s: ไม่มีกิลด์ที่ได้ทั้ง%sและ%sเมื่อสัปดาห์ที่แล้ว (ได้ทั้งสองรับ%s และตำแหน่ง \"%s\")" % [GuildLeague.EMPEROR_TITLE,
		GuildLeague.LEAGUE_TITLE, GuildLeague.CASTLE_TITLE, GuildLeague.reward_text({"jewels": GuildLeague.EMPEROR_BONUS}), GuildLeague.EMPEROR_TITLE]
	var emp := UIUtil.label(emp_text, &"SmallLabel")
	emp.name = "LeagueEmperor"
	emp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if emperor > 0:
		emp.add_theme_color_override("font_color", GuildLeague.CROWN_COLOR)
	box.add_child(emp)
	box.add_child(_reward_card(refresh, mine))
	if GuildLeague.hero_champion(t):
		box.add_child(UIUtil.label("ร้านลับ%s (เปิดถึงสิ้นสัปดาห์)" % GuildLeague.CASTLE_TITLE, &"SubHeaderLabel"))
		box.add_child(UIUtil.label("ทองของคุณ %s" % GuildScreen._num(int(Game.profile.gold)), &"SmallLabel"))
		for e in GuildLeague.SHOP:
			box.add_child(_shop_card(e, refresh))
	else:
		var closed := UIUtil.label("ร้านลับราชันปราสาท: เปิดให้สมาชิกกิลด์ราชันปราสาทเท่านั้น (แก่นเทพหลอมเซต เพชร ยา และตำแหน่ง \"ราชันปราสาท\")", &"SmallLabel")
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


## The deciding round's note under the table (รอบชี้ขาด ×2: Sunday 21:30, GuildLeague.is_final)
## and whether this season's is counted yet.
static func _final_note(w: int, t: float) -> Control:
	var at := GuildLeague.final_slot(w)
	var text := ""
	if GuildLeague.is_final(at):
		var state := "นับแล้ว" if GuildLeague.ended(at, t) else ("กำลังรบ" if t >= float(at) else "ยังไม่เริ่ม")
		text = "%s · รอบอาทิตย์ %s: แต้มอันดับและแต้มยึดปราสาทนับ %d เท่า (แต้มครองปราสาทและแต้มล้มศัตรูนับปกติ) · ผู้ครองปราสาทหลังรอบนี้เป็น%s — %s" % [
			GuildLeague.FINAL_TAG, GuildLeague.clock_text(at), GuildLeague.FINAL_MULT, GuildLeague.CASTLE_TITLE, state]
	else:
		text = "%s · รอบอาทิตย์ %s นับแต้มอันดับและแต้มยึดปราสาท %d เท่า เริ่มตั้งแต่ฤดูกาลหน้า · ผู้ครองปราสาทหลังรอบอาทิตย์ %s เป็น%s" % [
			GuildLeague.FINAL_TAG, GuildLeague.clock_text(at), GuildLeague.FINAL_MULT, GuildLeague.clock_text(at), GuildLeague.CASTLE_TITLE]
	var label := UIUtil.label(text, &"SmallLabel")
	label.name = "LeagueFinal"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", GuildLeague.CROWN_COLOR.lerp(Color.WHITE, 0.3))
	return label


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
		text = "สัปดาห์ที่แล้วกิลด์ของคุณได้อันดับ %d%s! รางวัล: %s" % [int(reward.rank),
			" (%s)" % GuildLeague.LEAGUE_TITLE if int(reward.rank) == 1 else "", GuildLeague.reward_text(reward)]
		if bool(reward.emperor):
			text += " — รวมโบนัส%s" % GuildLeague.EMPEROR_TITLE
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
			Game.say("ซื้อ %s จากร้านลับราชันปราสาทแล้ว" % GuildLeague.shop_name(e), &"success")
		else:
			Game.say(result, &"warning")
		refresh.call())
	line.add_child(buy)
	return panel
