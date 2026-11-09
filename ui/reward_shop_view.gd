class_name RewardShopView
extends RefCounted
## The reward exchange page (ร้านแลกของรางวัล, RewardShop), shown in the game menu
## (GameMenu "reward"), reached from the league page and the keeper ผู้ดูแลรางวัล: the
## hero's league coins and event points with how they are earned, four tabs (costumes,
## walk trails, name colours, power stones), a card an item with its price, "แลก" to buy
## and, for an owned cosmetic, "สวม" / "ถอด" (the wardrobe). `refresh` rebuilds the page
## after a buy or a change of what is worn. The tab stays while the menu is open.

static var tab := "costume"


static func build(parent: Control, refresh: Callable) -> Control:
	var scroll := TouchScroll.new()
	scroll.name = "RewardShopView"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UIUtil.label(RewardShop.SHOP_NAME, &"SubHeaderLabel"))
	var wallet := UIUtil.label("%s %d · %s %d" % [RewardShop.COIN_NAME, RewardShop.coins(), RewardShop.POINT_NAME, RewardShop.points()], &"BoldLabel")
	wallet.name = "RewardWallet"
	wallet.add_theme_color_override("font_color", RewardShop.COIN_COLOR)
	box.add_child(wallet)
	var t := WorldPresence.clock()
	var how := UIUtil.label("%s: ทุกรอบลีกกิลด์ที่ลงสนาม อันดับ 1-4 ได้ %s · ยึดปราสาท +%d ต่อครั้ง · ครองปราสาทตอนจบ +%d · โบนัสสิ้นสัปดาห์ตามอันดับกิลด์ %s (ต้องลงสนามอย่างน้อย 1 รอบ) — %s: ช่วยปราบบอสโลก +%d ต่อวัน · ล่ามอนสเตอร์ช่วง EXP x2 / เทศกาล +%d ต่อตัว วันละไม่เกิน %d (วันนี้เหลือ %d) — ของทุกชิ้นผูกกับตัวละคร ขายหรือส่งต่อไม่ได้" % [
		RewardShop.COIN_NAME, "/".join(RewardShop.PLACE_COINS.map(func(v): return str(v))), RewardShop.CAPTURE_COINS, RewardShop.HOLD_COINS,
		"/".join(RewardShop.WEEK_BONUS.map(func(v): return str(v))), RewardShop.POINT_NAME, RewardShop.BOSS_EP, RewardShop.KILL_EP, RewardShop.KILL_CAP, RewardShop.kill_left(t)], &"SmallLabel")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(how)
	var tabs := UIUtil.hbox(8)
	tabs.name = "RewardTabs"
	box.add_child(tabs)
	for pair in RewardShop.TABS:
		var id := String(pair[0])
		var b := UIUtil.button(String(pair[1]), &"PrimaryButton" if id == tab else &"", Vector2(170, 54))
		b.name = "RewardTab_%s" % id
		b.disabled = id == tab
		b.pressed.connect(func():
			tab = id
			refresh.call())
		tabs.add_child(b)
	match tab:
		"stone":
			box.add_child(UIUtil.label("หินเสริมพลัง: อัญมณีและเพชรตีบวกจากร้าน เป็นของเสริม ไม่ใช่ทางลัด (ของดรอปในสนามเหมือนเดิม) จำกัดจำนวนต่อสัปดาห์ รีเซ็ตวันจันทร์", &"SmallLabel"))
			for e in RewardShop.STONES:
				box.add_child(_stone_card(e, refresh))
		_:
			var note := {"costume": "คอสตูม: ย้อมชุดทั้งตัวพร้อมเครื่องประดับบนหัว ใส่ได้ทุกอาชีพทับเกราะที่สวมอยู่ · สวมได้ครั้งละ 1 ชุด",
				"trail": "เอฟเฟกต์ท่าเดิน: ร่องรอยที่ตามรอยเท้าเวลาเดิน (ปิดเองที่กราฟิกต่ำหรือเมื่อเครื่องหน่วยความจำตึง)",
				"ncol": "สีชื่อ: สีป้ายชื่อเหนือหัว ผู้เล่นคนอื่นที่ออนไลน์เห็นด้วย (สมาชิกราชันปราสาทยังใส่สีมงกุฎทองตามเดิม)"}
			box.add_child(UIUtil.label(String(note.get(tab, "")), &"SmallLabel"))
			var worn := RewardShop.active(tab)
			if worn == "":
				box.add_child(UIUtil.label("ตอนนี้ไม่ได้สวมอะไร", &"DimLabel"))
			for id in RewardShop.catalog(tab):
				box.add_child(_cosmetic_card(tab, String(id), refresh))
	return scroll


static func _swatch(color: Color) -> Control:
	var rect := ColorRect.new()
	rect.color = color
	rect.custom_minimum_size = Vector2(28, 28)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


static func _cosmetic_card(p_tab: String, id: String, refresh: Callable) -> Control:
	var e := RewardShop.entry(p_tab, id)
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "Reward_%s" % id
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var color: Color = e.get("cloth", e.get("color", RewardShop.COIN_COLOR))
	line.add_child(_swatch(color))
	var owned := RewardShop.owns(id)
	var worn := RewardShop.active(p_tab) == id
	var state := " · สวมอยู่" if worn else (" · มีแล้ว" if owned else "")
	var label := UIUtil.label("%s%s\n%s" % [String(e.name), state, RewardShop.price_text(e)], &"BoldLabel")
	label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.45))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	if owned:
		var wear := UIUtil.button("ถอด" if worn else "สวม", &"PrimaryButton" if not worn else &"", Vector2(130, 54))
		wear.name = "RewardWear_%s" % id
		wear.pressed.connect(func():
			var result := RewardShop.wear(p_tab, "" if worn else id)
			if result == "ok":
				AudioManager.play_sfx(&"pickup")
			else:
				Game.say(result, &"warning")
			refresh.call())
		line.add_child(wear)
	else:
		var problem := RewardShop.problem(p_tab, id)
		var buy := UIUtil.button("แลก", &"AccentButton", Vector2(130, 54))
		buy.name = "RewardBuy_%s" % id
		buy.disabled = problem != ""
		buy.tooltip_text = problem
		buy.pressed.connect(func():
			var result := RewardShop.buy(p_tab, id)
			if result == "ok":
				AudioManager.play_sfx(&"coin")
				Game.say("แลก %s แล้ว" % String(e.name), &"success")
			else:
				Game.say(result, &"warning")
			refresh.call())
		line.add_child(buy)
	return panel


static func _stone_card(e: Dictionary, refresh: Callable) -> Control:
	var id := String(e.id)
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "Reward_%s" % id
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var item := RewardShop.stone_item(e)
	var label := UIUtil.label("%s · แลกแล้ว %d/%d สัปดาห์นี้\n%s" % [RewardShop.name_of("stone", id), RewardShop.bought(id), int(e.limit), RewardShop.price_text(e)], &"BoldLabel")
	label.add_theme_color_override("font_color", ItemData.color_of(item).lerp(Color.WHITE, 0.4))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var problem := RewardShop.problem("stone", id)
	var buy := UIUtil.button("แลก", &"AccentButton", Vector2(130, 54))
	buy.name = "RewardBuy_%s" % id
	buy.disabled = problem != ""
	buy.tooltip_text = problem
	buy.pressed.connect(func():
		var result := RewardShop.buy("stone", id)
		if result == "ok":
			AudioManager.play_sfx(&"pickup")
			Game.say("แลก %s แล้ว" % RewardShop.name_of("stone", id), &"success")
		else:
			Game.say(result, &"warning")
		refresh.call())
	line.add_child(buy)
	return panel
