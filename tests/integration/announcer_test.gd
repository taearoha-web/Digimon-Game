extends Node
## Server-wide announcements and the living isle (headless):
## - Announcer.broadcast: the kinds, plain one-line text, the world chat's system line;
## - AnnounceBanner: one line at a time, the queue (order, cap, no doubles), the colours,
##   a long line scrolling, the hold switch, its strip clear of the HUD's other pieces;
## - the online relay: the hero's jackpot goes out as fields only, exactly the frame the
##   worker's node test relays (hosting/worker/tests/announce_fixture.json), and the
##   server's frame becomes a Thai line written here; hostile frames change nothing;
## - the world players on the isle: only ★300 ones hunt there, a share of their sessions;
##   their jackpots (IsleLuck) are rare, the same every time they are asked, won by
##   someone really hunting there, announced once, never replayed after a long pause, and
##   the others cheer with the real rate; a Dragon God weapon / wings jackpot is always a
##   piece the winner really dropped (WorldGear) and its gear shows it;
## - what the chat says about the isle is the game's own numbers.
##   godot --headless --path . res://tests/integration/announcer_test.tscn
var failures := 0
var checks := 0


class FakeTransport:
	extends RefCounted
	var sent: Array[String] = []
	func send_text(text: String) -> void:
		sent.append(text)
	func poll() -> Array:
		return []
	func is_open() -> bool:
		return true
	func is_closed() -> bool:
		return false
	func frames(t: String) -> Array:
		var out: Array = []
		for text in sent:
			var d: Variant = JSON.parse_string(text)
			if d is Dictionary and String(d.get("t", "")) == t:
				out.append(d)
		return out


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func at(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


var chat: Array = []


func _ready() -> void:
	Game.set_process(false)
	Online.set_process(false)
	GameSettings.load_settings()
	GameSettings.online_play = true
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	WorldEvents.festival_enabled = false
	Game.new_profile(&"mage", "ลูน่า", FaceKit.default_look())
	Game.profile.level = Game.MAX_LEVEL
	Game.paragon().level = SkyIsleData.ENTRY_STAR
	Game.playing = true
	ZoneData.ensure()
	Game.world_chat.connect(func(speaker: String, text: String, color: Color): chat.append([speaker, text, color]))
	_broadcast()
	await _banner()
	_relay()
	_isle_players()
	_luck()
	_truth()
	WorldPresence.clock_offset = 0.0
	print("ANNOUNCER: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _broadcast() -> void:
	Announcer.reset()
	chat.clear()
	var heard: Array = []
	var sink := func(text: String, kind: String): heard.append([text, kind])
	Announcer.listen(sink)
	Announcer.listen(sink)
	Announcer.broadcast("ลูน่า ได้รับ ดาบเทพมังกร จากเกาะลอยฟ้าเทพมังกร!")
	check(heard.size() == 1 and heard[0][1] == "jackpot", "a listener hears it once, a jackpot by default")
	check(chat.size() == 1 and chat[0][0] == Announcer.SPEAKER and chat[0][1] == heard[0][0] and chat[0][2] == Announcer.COLORS.jackpot, "a gold system line in the world chat")
	Announcer.broadcast("มังกรมาแล้ว", "rare")
	check(heard.size() == 2 and heard[1][1] == "rare" and chat[1][2] == Announcer.COLORS.rare and Announcer.COLORS.rare != Announcer.COLORS.jackpot, "the rare dragon's is jade")
	Announcer.broadcast("x", "gm")
	Announcer.broadcast("", "jackpot")
	Announcer.broadcast("   \n\t ", "rare")
	check(heard.size() == 2 and chat.size() == 2, "an unknown kind or an empty text is not shown")
	Announcer.broadcast("บรรทัดแรก\nบรรทัดสอง\t" + "ก".repeat(400))
	var long := String(heard[2][0])
	check(not long.contains("\n") and not long.contains("\t") and long.length() <= Announcer.TEXT_MAX, "one plain line, at most %d characters (%d)" % [Announcer.TEXT_MAX, long.length()])
	check(Announcer.history.size() == 3 and String(Announcer.history[-1].text) == long, "kept in the history")
	for i in Announcer.LOG_MAX + 5:
		Announcer.show("ข่าว %d" % i, "jackpot")
	check(Announcer.history.size() == Announcer.LOG_MAX, "the history is capped")
	Announcer.unlisten(sink)
	Announcer.broadcast("หลังเลิกฟัง")
	check(heard.size() == 3 + Announcer.LOG_MAX + 5, "a listener that left hears no more")
	check(Announcer.KINDS == ["jackpot", "rare", "crown"], "the three kinds (หนึ่งในใต้หล้า's crown: MazeCrown)")


func _banner() -> void:
	Announcer.reset()
	var strip := AnnounceBanner.new()
	strip.size = Vector2(HUD.ANNOUNCE_WIDTH, AnnounceBanner.HEIGHT)
	strip.position = Vector2(200, 84)
	add_child(strip)
	strip.speed = 6.0
	# The first frames after loading are long ones: let them pass before timing a slide.
	for i in 5:
		await get_tree().process_frame
	check(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE and strip.clip_contents, "the strip takes no touches and clips its line")
	Announcer.broadcast("ก ได้รับ อาวุธเทพมังกร!")
	check(String(strip.current.get("text", "")) == "ก ได้รับ อาวุธเทพมังกร!" and strip.queue.is_empty(), "an announcement starts at once on a free strip")
	check(strip._icon.text == AnnounceBanner.ICONS.jackpot and strip._pill.visible, "a jackpot's star")
	var border := (strip._pill.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	check(border == Announcer.COLORS.jackpot, "gold for a jackpot")
	Announcer.broadcast("มังกรแก้วเจ็ดสี ปรากฏตัวแล้ว!", "rare")
	Announcer.broadcast("ข ได้รับ ปีกเทพมังกร!")
	Announcer.broadcast("ข ได้รับ ปีกเทพมังกร!")
	Announcer.broadcast("ก ได้รับ อาวุธเทพมังกร!")
	check(strip.queue.size() == 2 and String(strip.queue[0].kind) == "rare", "the next ones wait in order; the same line is not queued twice")
	# Once it has slid in it rests inside the strip.
	var area := strip.get_global_rect()
	for i in 400:
		if absf(strip.pill_rect().get_center().x - area.get_center().x) < 2.0:
			break
		await get_tree().process_frame
	var pill := strip.pill_rect()
	check(pill.size.x > 0.0 and pill.position.x >= area.position.x - 1.0 and pill.end.x <= area.end.x + 1.0 and absf(pill.get_center().x - area.get_center().x) < 4.0, "held in the middle of its strip (%s in %s)" % [pill, area])
	for i in 2000:
		if String(strip.current.get("kind", "")) == "rare":
			break
		await get_tree().process_frame
	check(String(strip.current.get("kind", "")) == "rare" and strip._icon.text == AnnounceBanner.ICONS.rare, "then the rare dragon's turn")
	border = (strip._pill.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	check(border == Announcer.COLORS.rare, "jade for the rare dragon")
	for i in 4000:
		if strip.current.is_empty() and strip.queue.is_empty():
			break
		await get_tree().process_frame
	check(strip.current.is_empty() and strip.queue.is_empty() and not strip._pill.visible and strip.shown.size() == 3, "all three were shown, the strip is empty again (%d)" % strip.shown.size())
	# A flood: at most QUEUE_MAX wait.
	strip.hold = true
	for i in AnnounceBanner.QUEUE_MAX + 7:
		Announcer.show("แจ็กพอตที่ %d" % i, "jackpot")
	check(strip.current.is_empty() and strip.queue.size() == AnnounceBanner.QUEUE_MAX, "held back: nothing starts, at most %d wait" % AnnounceBanner.QUEUE_MAX)
	check(String(strip.queue[-1].text).ends_with("%d" % (AnnounceBanner.QUEUE_MAX + 6)), "the newest are kept")
	strip.hold = false
	await get_tree().process_frame
	await get_tree().process_frame
	check(not strip.current.is_empty(), "released: the next one starts")
	strip.queue.clear()
	for i in 2000:
		if strip.current.is_empty():
			break
		await get_tree().process_frame
	# A line wider than the strip scrolls across instead of stopping in the middle.
	strip.size.x = 260.0
	Announcer.show("ผู้เล่นชื่อยาวมาก ได้รับ อาวุธเทพมังกรแห่งตำนานสายฟ้า จากเกาะลอยฟ้าเทพมังกร!", "jackpot")
	await get_tree().process_frame
	check(strip._pill.size.x > strip.size.x, "a long line is wider than a narrow strip")
	var first_x := strip._pill.position.x
	for i in 2000:
		if strip._pill.position.x < 0.0:
			break
		await get_tree().process_frame
	check(strip._pill.position.x < first_x and strip._pill.position.x < 0.0 and strip._pill.visible, "so it scrolls across")
	# Its place on a phone (1558 x 720 canvas): clear of the toasts, the chip, the skills and the chat.
	var frame := Vector2(1558, 720)
	var rect := Rect2((frame.x - HUD.ANNOUNCE_WIDTH) * 0.5, HUD.ANNOUNCE_TOP, HUD.ANNOUNCE_WIDTH, AnnounceBanner.HEIGHT)
	check(rect.end.y + 16.0 <= HUD.BANNER_TOP + 16.0, "above the zone banner")
	AnnounceBanner.band_bottom = rect.end.y + 16.0
	check(ToastLayer.lane_top() >= rect.end.y + 16.0, "the toasts start under a banner that is up")
	AnnounceBanner.band_bottom = 0.0
	check(ToastLayer.lane_top() == ToastLayer.TOP, "and where they always did without one")
	check(not rect.intersects(HUD.event_chip_rect(frame, 0.0, Vector2(420, 90))) and rect.end.y < HUD.TRACKER_TOP, "clear of the tracker and the event chip")
	check(rect.end.y < frame.y * 0.5, "in the top half: nowhere near the skill buttons or the chat")
	strip.queue_free()
	await get_tree().process_frame
	Announcer.show("ไม่มีแถบแล้ว", "jackpot")
	check(true, "an announcement without a banner is harmless")


func _relay() -> void:
	Announcer.reset()
	chat.clear()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hosting/worker/tests/announce_fixture.json"))
	check(fixture is Dictionary and fixture.has("client") and fixture.has("server"), "the fixture both sides' tests read")
	Game.current_zone = SkyIsleData.ID
	var roll := RandomNumberGenerator.new()
	roll.seed = 5
	var weapon := DragonGearData.weapon(&"mage", roll)
	check(SkyIsleLoot.is_jackpot(weapon), "the Dragon God weapon is a jackpot")
	# Offline: shown here, nothing sent.
	SkyIsleLoot.announce(weapon)
	check(Announcer.history.size() == 1 and String(Announcer.history[0].text).contains("ลูน่า") and String(Announcer.history[0].text).contains(ItemData.name_of(weapon)), "offline the hero's jackpot is announced here (%s)" % str(Announcer.history))
	var fake := FakeTransport.new()
	Online.use_transport(fake)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "luna"}, "players": [], "party": null})
	check(Online.is_online() and Online.my_id() == "me", "online with a stand-in socket")
	Announcer.reset()
	SkyIsleLoot.announce(weapon)
	var sent := fake.frames("announce")
	check(sent.size() == 1 and sent[0] == fixture.client, "the hero's jackpot goes out as exactly the frame the worker's test relays (%s)" % str(sent))
	if not sent.is_empty():
		check((sent[0] as Dictionary).keys().all(func(k): return k in ["t", "kind", "what", "cls", "zone"]) and not JSON.stringify(sent[0]).contains("ลูน่า"), "fields only: no text, no name")
	SkyIsleLoot.announce(weapon)
	check(fake.frames("announce").size() == 1, "a second one within the send gap stays here")
	check(Announcer.describe("ใครสักคน ได้รับ ของลึกลับ!").what == "" and Announcer.describe(ItemData.name_of(DragonGearData.wings(&"bard", roll))).what == "wings", "describe names the item's fields, or none")
	# What an AI player or another client got is never sent on.
	Announcer._sent_at = -100000
	Announcer.quietly(func(): SkyIsleLoot.announce(weapon, "คนอื่น"))
	check(fake.frames("announce").size() == 1 and Announcer.relay, "somebody else's news is not relayed")
	Announcer.rare_slain()
	check(fake.frames("announce").size() == 2 and fake.frames("announce")[1] == fixture.rare_client, "the rare dragon's kill goes out as fields too")
	# The server's frame: the line is written here.
	Announcer.reset()
	chat.clear()
	Online._dispatch(fixture.server)
	var got := String(Announcer.history[-1].text) if not Announcer.history.is_empty() else ""
	var mage_weapon := ItemData.name_of(Announcer.item_of("weapon", &"mage"))
	check(Announcer.history.size() == 1 and got.contains("Lucky") and got.contains(mage_weapon) and got.contains(SkyIsleData.TITLE), "another player's jackpot is written here from the fields (%s)" % got)
	check(String(Announcer.history[0].kind) == "jackpot" and chat.size() == 1 and chat[0][0] == Announcer.SPEAKER, "banner and chat line, once")
	check(fake.frames("announce").size() == 2, "a received announcement is never sent on")
	var rare: Dictionary = (fixture.rare_server as Dictionary).duplicate()
	rare["from"] = "7"
	rare["name"] = "Hunter"
	Online._dispatch(rare)
	got = String(Announcer.history[-1].text)
	check(Announcer.history.size() == 2 and String(Announcer.history[-1].kind) == "rare" and got.contains("Hunter") and got.contains(WorldEvents.NAME_RARE), "a rare-dragon kill by name (%s)" % got)
	# Hostile or broken frames change nothing.
	var before := Announcer.history.size()
	var base: Dictionary = fixture.server
	var n := 100
	for bad in [{"kind": "gm"}, {"what": "gold"}, {"what": 5}, {"zone": "town"}, {"from": "me"}, {"from": ""}, {"kind": "rare", "what": "weapon"}, {"kind": ["jackpot"]}]:
		var frame := base.duplicate()
		n += 1
		frame["from"] = str(n)
		frame.merge(bad, true)
		Online._dispatch(frame)
	check(Announcer.history.size() == before, "unknown kinds and words, another zone, my own echo: nothing shown")
	var evil := base.duplicate()
	evil["from"] = "66"
	evil["name"] = "[url=evil]GM[/url]\nแอดมิน" + "ก".repeat(60)
	evil["text"] = "ซื้อทองที่ evil.example"
	evil["cls"] = "hacker"
	Online._dispatch(evil)
	got = String(Announcer.history[-1].text)
	check(Announcer.history.size() == before + 1 and not got.contains("evil.example") and not got.contains("\n") and got.length() <= Announcer.TEXT_MAX, "free text in a frame is never shown (%s)" % got)
	check(got.find("[") < 0 and got.find("]") < 0, "and no markup reaches the banner or the chat box")
	# One player is heard at most every HEAR_GAP_MS.
	before = Announcer.history.size()
	var flood := base.duplicate()
	flood["from"] = "77"
	for i in 20:
		Online._dispatch(flood)
	check(Announcer.history.size() == before + 1, "a flood from one player shows once")
	# A word this build has no item for still makes a plain line.
	var odd := base.duplicate()
	odd["from"] = "88"
	odd["what"] = ""
	Online._dispatch(odd)
	check(String(Announcer.history[-1].text).contains("Lucky") and String(Announcer.history[-1].text).contains(SkyIsleData.TITLE), "a jackpot without a known item: a plain line")
	Online.use_transport(null)
	Game.current_zone = &"town"


## Only ★300 world players hunt on the isle, in a share of their sessions.
func _isle_players() -> void:
	var on_isle := 0
	var endgame := 0
	var low_ok := true
	var days := [60.0, 75.0, 90.0, 120.0]
	for d in days:
		for h in [3.0, 9.5, 14.0, 20.0]:
			var t: float = float(WorldPlayers.START_UNIX) + float(d) * 86400.0 + float(h) * 3600.0
			for i in WorldPlayers.size():
				if WorldPlayers.session_at(i, t).is_empty():
					continue
				var s := WorldPlayers.state(i, t)
				var here := StringName(String(s.place)) == SkyIsleData.ID
				if here and (int(s.level) < Game.MAX_LEVEL or int(s.stars) < SkyIsleData.ENTRY_STAR):
					low_ok = false
				if int(s.level) >= Game.MAX_LEVEL and int(s.stars) >= SkyIsleData.ENTRY_STAR and String(s.doing) in ["hunt", "boss"]:
					endgame += 1
					on_isle += 1 if here else 0
	check(low_ok, "nobody under ★%d is ever on the isle" % SkyIsleData.ENTRY_STAR)
	check(endgame > 30, "★300 world players were found hunting (%d)" % endgame)
	var share := float(on_isle) / float(maxi(1, endgame))
	print("announcer_test: %d of %d hunting ★300 world players are on the isle (%.0f%%)" % [on_isle, endgame, share * 100.0])
	check(share > 0.35 and share < 0.85, "about %d%% of their hunting sessions are on the isle (%.0f%%)" % [WorldPlayers.ISLE_SHARE, share * 100.0])
	check(WorldPlayers.session_zone(0, 0.0, Game.MAX_LEVEL, SkyIsleData.ENTRY_STAR - 1) != SkyIsleData.ID and WorldPlayers.hunting_zone(Game.MAX_LEVEL, SkyIsleData.ENTRY_STAR) == DrownedAbyssData.ID, "the home field's rule is as it was; the isle is a session's choice at ★300")


## The world players' jackpots: rare, the same for everyone, true to who hunts there.
func _luck() -> void:
	IsleLuck.clear()
	# No WorldPresence warms the world players' forging here: a slot may work it out.
	IsleLuck.cold = true
	var t0 := float(WorldPlayers.START_UNIX) + 90.0 * 86400.0
	var first := int(t0 / float(IsleLuck.SLOT))
	var slots := 7 * 86400 / IsleLuck.SLOT
	var usec := Time.get_ticks_usec()
	var events: Array = []
	for n in range(first, first + slots):
		var e := IsleLuck.at_slot(n)
		if not e.is_empty():
			events.append(e)
	var cost := float(Time.get_ticks_usec() - usec) / float(slots)
	var per_hour := float(events.size()) / (7.0 * 24.0)
	print("announcer_test: %d world-player jackpots in a week (%.2f an hour), %.0f usec a slot" % [events.size(), per_hour, cost])
	check(events.size() > 20, "the server is alive: jackpots do happen (%d in a week)" % events.size())
	check(per_hour <= IsleLuck.CHANCE * 3600.0 / float(IsleLuck.SLOT) * 1.25 and per_hour < 2.0, "but rarely: under two an hour (%.2f)" % per_hour)
	var ok := true
	var whats := {}
	var names := {}
	for e in events:
		var s := WorldPlayers.state(int(e.index), float(e.at))
		whats[String(e.what)] = int(whats.get(String(e.what), 0)) + 1
		names[String(e.name)] = true
		# Inside its slot: a rolled jackpot at a second of [start, end); a real drop is read
		# off WorldGear.events(start, end), whose times run start < at <= end (a drop in the
		# slot's last second may be told at its very end, and the next slot never repeats it).
		var slot_start := float(int(e.slot) * IsleLuck.SLOT)
		var slot_end := float((int(e.slot) + 1) * IsleLuck.SLOT)
		if bool(e.get("real", false)):
			ok = ok and float(e.at) > slot_start and float(e.at) <= slot_end
		else:
			ok = ok and float(e.at) >= slot_start and float(e.at) < slot_end
		ok = ok and bool(s.online) and StringName(String(s.place)) == SkyIsleData.ID and int(s.stars) >= SkyIsleData.ENTRY_STAR and String(s.name) == String(e.name)
		ok = ok and SkyIsleLoot.is_jackpot(e.item) and (Announcer.WHATS.jackpot as Array).has(String(e.what))
		ok = ok and (IsleLuck.KINDS + IsleLuck.DRAGON_KINDS).any(func(k): return String(k[0]) == String(e.what) and is_equal_approx(float(k[1]), float(e.rate)))
		if String(e.what) in ["weapon", "wings"]:
			ok = ok and String(e.cls) == String(s.job) and bool(e.get("real", false))
			# The very drop of its own forging (WorldGear), at that second.
			var mine := WorldGear.events(int(e.index), float(e.at) - 1.0, float(e.at)).filter(func(g): return String(g.get("key", "")) == WorldGear.DRAGON and String(g.kind) in ["drop", "spare"] and is_equal_approx(float(g.at), float(e.at)))
			ok = ok and not mine.is_empty() and String(mine[0].slot) == String(e.what) and String(mine[0].item) == ItemData.name_of(e.item)
	check(ok, "each winner is a ★300 world player really hunting on the isle then, with a real jackpot of its own class at the owner's rate")
	var heard_once := {}
	for e in events:
		heard_once["%d|%.3f|%s" % [int(e.index), float(e.at), String(e.what)]] = true
	check(heard_once.size() == events.size(), "no jackpot is told twice, even one at a slot's edge (%d / %d)" % [heard_once.size(), events.size()])
	print("announcer_test: jackpots by kind %s (the weapon and wings are real drops)" % str(whats))
	check(names.size() >= 5, "different players win (%d)" % names.size())
	check(int(whats.get("weapon", 0)) + int(whats.get("wings", 0)) > 0, "the Dragon God's pieces the world players really drop are among them (%s)" % str(whats))
	var rates := {"weapon": SkyIsleLoot.WEAPON_DROP, "wings": SkyIsleLoot.WING_DROP, "fragment": SkyIsleLoot.FRAGMENT_DROP, "egg": SkyIsleLoot.EGG_DROP}
	check((IsleLuck.KINDS + IsleLuck.DRAGON_KINDS).all(func(k): return is_equal_approx(float(rates[String(k[0])]), float(k[1]))), "weighted by the owner's rates")
	# The same for every device: asked again from nothing, the same answers.
	var copy: Array = []
	for e in events:
		copy.append([int(e.slot), float(e.at), int(e.index), String(e.what)])
	IsleLuck.clear()
	var same := true
	for c in copy:
		var e := IsleLuck.at_slot(int(c[0]))
		same = same and not e.is_empty() and float(e.at) == float(c[1]) and int(e.index) == int(c[2]) and String(e.what) == String(c[3])
	check(same, "the same jackpots every time they are worked out")
	# No pattern from slot to slot (a plain string hash would make runs).
	var lucky := 0
	var pairs := 0
	for n in range(first, first + 4000):
		var a := float(WorldEvents.roll("isleluck|%d" % n) % 10000) < IsleLuck.CHANCE * 10000.0
		var b := float(WorldEvents.roll("isleluck|%d" % (n + 1)) % 10000) < IsleLuck.CHANCE * 10000.0
		lucky += 1 if a else 0
		pairs += 1 if a and b else 0
	check(absf(float(lucky) / 4000.0 - IsleLuck.CHANCE) < 0.04 and absf(float(pairs) / 4000.0 - IsleLuck.CHANCE * IsleLuck.CHANCE) < 0.03, "lucky slots come at CHANCE, one after another no more than chance (%d, %d)" % [lucky, pairs])
	check(cost < 20000.0, "working a slot out is cheap (%.0f usec)" % cost)
	if events.is_empty():
		return
	# Announced once as its second passes; cheered by the others; never replayed.
	var e: Dictionary = events[0]
	Announcer.reset()
	chat.clear()
	Announcer.tick(float(e.at) - 3.0)
	check(Announcer.history.filter(func(h): return String(h.kind) == "jackpot").is_empty(), "nothing before its second")
	Announcer.tick(float(e.at) + 1.0)
	var told := Announcer.history.filter(func(h): return String(h.kind) == "jackpot")
	check(told.size() == 1 and String(told[0].text).contains(String(e.name)) and String(told[0].text).contains(ItemData.name_of(e.item)), "announced with the winner's name and the item (%s)" % str(told))
	Announcer.tick(float(e.at) + 2.0)
	Announcer.tick(float(e.at) + 3.0)
	check(Announcer.history.filter(func(h): return String(h.kind) == "jackpot").size() == 1, "once")
	var taken := Announcer.take_luck()
	check(taken.size() == 1 and int(taken[0].index) == int(e.index) and Announcer.take_luck().is_empty(), "handed to the world chat once")
	if events.size() > 2:
		Announcer.reset()
		Announcer.tick(float(events[1].at) - 3.0)
		Announcer.tick(float(events[-1].at) + 30.0)
		check(Announcer.history.filter(func(h): return String(h.kind) == "jackpot").is_empty() and Announcer.take_luck().is_empty(), "a game back from a long pause does not replay what it missed")
	# The others cheer: the winner opens, the rate they quote is the owner's.
	at(float(e.at) + 2.0)
	var online: Array = []
	for i in WorldPlayers.size():
		if not WorldPlayers.session_at(i, float(e.at)).is_empty():
			var s := WorldPlayers.state(i, float(e.at))
			if bool(s.online):
				online.append(s)
	var presence := WorldPresence.new()
	presence._online.assign(online)
	WorldPresence.chat_clock_override = 1000.0
	Announcer._luck.append(e)
	presence._isle_luck()
	var world_lines := presence._queue.filter(func(q): return String(q.channel) == "world")
	check(world_lines.size() >= 2 and int(world_lines[0].state.index) == int(e.index) and float(world_lines[0].at) > 1000.0, "the winner speaks first, a moment after the banner, and others answer (%d lines)" % world_lines.size())
	var rate_text := "%s เปอร์เซ็นต์" % IsleLuck.percent(float(e.rate))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var quoted := 0
	var clean := true
	for k in 60:
		var people := WorldPresence._people(online.filter(func(o): return int(o.index) == int(e.index))[0], online)
		for line in ChatThreads.make("world", people, rng, {"topic": "jackpot", "t": float(e.at), "vars": {"%jrate": IsleLuck.percent(float(e.rate)), "%jitem": ItemData.name_of(e.item)}}):
			check(String(line.get("topic", "jackpot")) == "jackpot", "the forced topic holds")
			for text in line.options:
				clean = clean and not String(text).contains("%")
				if String(text).contains("เปอร์เซ็นต์"):
					quoted += 1
					clean = clean and String(text).contains(rate_text)
	check(clean and quoted > 0, "a quoted rate is the real one (%s, %d lines)" % [rate_text, quoted])
	presence.free()
	WorldPresence.chat_clock_override = -1.0
	# A Dragon God jackpot is on the winner a minute later (its card and fights read
	# WorldGear): the weapon it wears, the dragon wings or the legend pair over them; a
	# fragment or the egg leaves its gear as it is.
	var wears := true
	var real := 0
	for j in events:
		if not (String(j.what) in ["weapon", "wings"]):
			continue
		real += 1
		var gear := WorldGear.gear(int(j.index), float(j.at) + 60.0)
		if String(j.what) == "weapon":
			wears = wears and String(gear.weapon.kind) == "dragon" and String(gear.weapon.name) == ItemData.name_of(j.item)
		else:
			wears = wears and int(gear.wings.tier) in [WorldGear.WTIER_DRAGON, 3]
	check(wears, "each Dragon God jackpot is worn by its winner (%d)" % real)
	IsleLuck.cold = false


## What the chat says about the isle is the game's own numbers.
func _truth() -> void:
	var v := ChatThreads.isle_vars()
	check(v["%isle"] == SkyIsleData.TITLE and v["%islestar"] == str(SkyIsleData.ENTRY_STAR), "the isle's name and gate")
	check(v["%dweapon"] == str(snappedf(SkyIsleLoot.WEAPON_DROP * 100.0, 0.01)) and v["%dwing"] == str(snappedf(SkyIsleLoot.WING_DROP * 100.0, 0.01))
		and v["%dfrag"] == str(snappedf(SkyIsleLoot.FRAGMENT_DROP * 100.0, 0.01)) and v["%degg"] == str(snappedf(SkyIsleLoot.EGG_DROP * 100.0, 0.01)), "the owner's four rates, in percent (%s %s %s %s)" % [v["%dweapon"], v["%dwing"], v["%dfrag"], v["%degg"]])
	check(v["%fragneed"] == str(SkyIsleLoot.COSTUME_FRAGMENTS) and v["%rare"] == WorldEvents.NAME_RARE and v["%raremin"] == str(WorldEvents.RARE_LENGTH / 60)
		and v["%raretimes"] == "%d-%d" % [WorldEvents.RARE_MIN, WorldEvents.RARE_MAX], "the fragments a costume takes and the dragon's schedule")
	var prev := StringName(ZoneData.get_zone(SkyIsleData.ID).get("prev", &""))
	check(not v.has("%isleprev") or v["%isleprev"] == String(ZoneData.get_zone(prev).name), "the way in is the field before it")
	check(ChatThreads.rule_vars(0.0).has("%isle") and ChatThreads.rule_vars(0.0).has("%abyss"), "the rules carry the isle beside the older fields")
	# A world player asked about the isle answers with those numbers.
	var player := {"index": 0, "name": "ทดสอบ", "class": "นักรบ", "level": 100, "stars": 300, "style": "", "doing": "hunt", "place": SkyIsleData.TITLE, "guild": "", "gender": 0, "inParty": false}
	var hero := {"name": "ลูน่า", "class": "นักเวท", "level": 100, "stars": 300}
	for q in ["เกาะลอยฟ้าเทพมังกรดรอปอะไร", "มังกรแก้วเจ็ดสีมาตอนไหน", "เกาะลอยฟ้าเข้ายังไง"]:
		var text := String(ChatBrain.reply({"text": q, "player": player, "hero": hero, "history": [], "t": 0.0, "channel": "direct"}).reply)
		check(text.contains(SkyIsleData.TITLE) and text.contains("★%d" % SkyIsleData.ENTRY_STAR) and text.contains("%s%%" % v["%dweapon"]) and text.contains(WorldEvents.NAME_RARE) and text.contains(v["%raretimes"]), "asked \"%s\": the real gate, rate and dragon (%s)" % [q, text])
		check(text.length() <= 150, "and it fits a bubble (%d)" % text.length())
	check(ChatBrain.help_text("isle") != "" and ChatBrain.help_topic("มังกรแก้ว") == "isle", "the help knows the topic")
	# Conversations about it: every number a line states is one of the constants.
	var allowed := [v["%dweapon"], v["%dwing"], v["%dfrag"], v["%degg"]]
	var rx := RegEx.new()
	rx.compile("([\\d.]+) เปอร์เซ็นต์")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var t := float(WorldPlayers.START_UNIX) + 90.0 * 86400.0 + 14.0 * 3600.0
	at(t)
	var online: Array = []
	for i in WorldPlayers.size():
		if not WorldPlayers.session_at(i, t).is_empty():
			var s := WorldPlayers.state(i, t)
			if bool(s.online):
				online.append(s)
	var lines := 0
	var ok := true
	var star_ok := true
	var said_isle := 0
	for k in 80:
		online.shuffle()
		for line in ChatThreads.make("world", online.slice(0, 4), rng, {"topic": "isle", "t": t}):
			for text in line.options:
				lines += 1
				ok = ok and not String(text).contains("%")
				for m in rx.search_all(String(text)):
					ok = ok and allowed.has(m.get_string(1))
				if String(text).contains(SkyIsleData.TITLE):
					said_isle += 1
				if String(text).contains("ต้อง ★"):
					star_ok = star_ok and String(text).contains("★%d" % SkyIsleData.ENTRY_STAR)
	check(lines > 100 and ok and star_ok and said_isle > 0, "isle talk states only the constants (%d lines, %d naming the isle)" % [lines, said_isle])
	var single := 0
	for s in online:
		if String(s.place) != String(SkyIsleData.ID):
			continue
		for k in 12:
			var text := WorldChat.line_for(s, rng.randi(), t)
			for m in rx.search_all(text):
				if not allowed.has(m.get_string(1)) and WorldChat.ISLE.any(func(l): return text.contains(v["%isleweapon"]) or text.contains(v["%islewings"])):
					ok = false
			single += 1 if text.contains(WorldEvents.NAME_RARE) or text.contains(v["%isleweapon"]) or text.contains(v["%islewings"]) else 0
	check(ok and single > 0, "a player on the isle now and then talks about it, truly (%d lines)" % single)
