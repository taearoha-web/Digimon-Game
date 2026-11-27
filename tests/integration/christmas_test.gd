extends Node
## เทศกาลคริสต์มาสและปีใหม่ (Christmas; headless):
## - the window (1 Dec 2026 00:00 to 2 Jan 2027 23:59 Thai), Christmas night (24 Dec 18:00 -
##   25 Dec 06:00) and the New Year countdown (31 Dec 23:00 - 1 Jan 01:00) to the minute,
##   festival_enabled = false switching it all off;
## - the highlights' EXP +50% added to the evening's x2 (x2.5 / x1.5, never x3);
## - gift boxes drop only in the window and only in the hunting grounds (about 5% a kill,
##   a boss three), and from real kills in a field;
## - opening: the prize table's distribution, one box or all of them, the costume granted
##   once (owned already it is pieces), the bag-full stop;
## - the Santa costume: its pieces, the exchange only in the window, its art and snowflakes;
## - the HUD chip, the events list, the chat answers, the world chat lines;
## - the village dressed only in the window: the tree (the great sakura hidden), lights,
##   snowmen, snow and fireworks (only in the countdown), cheap in nodes and draws.
##   godot --headless --path . res://tests/integration/christmas_test.tscn
var failures := 0
var checks := 0


class LootZone:
	extends Zone
	var items: Array[Dictionary] = []
	func _spawn_loot(item: Dictionary, _gold: int, _from: Vector3) -> void:
		if not item.is_empty():
			items.append(item)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func thai(year: int, month: int, day: int, hour: int, minute := 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}) - WorldPlayers.TZ)


func at(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()
	Christmas.test_time = t


func _ready() -> void:
	Game.set_process(false)
	WorldPlayers.persist = false
	Announcer.relay = false
	Game.new_profile(&"warrior", "Santa QA", FaceKit.default_look())
	Game.profile.level = 60
	ZoneData.ensure()
	_dates()
	_exp()
	_drops()
	_opening()
	_costume()
	_chat()
	await _real_kills()
	await _village()
	await _costume_art()
	WorldPresence.clock_offset = 0.0
	Christmas.test_time = -1.0
	print("CHRISTMAS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _dates() -> void:
	check(float(Christmas.START) == thai(2026, 12, 1, 0) and float(Christmas.END) == thai(2027, 1, 3, 0), "1 Dec 2026 00:00 to 2 Jan 2027 23:59 Thai time")
	check(float(Christmas.NIGHT_START) == thai(2026, 12, 24, 18) and float(Christmas.NIGHT_END) == thai(2026, 12, 25, 6), "Christmas night: 24 Dec 18:00 - 25 Dec 06:00")
	check(float(Christmas.COUNT_START) == thai(2026, 12, 31, 23) and float(Christmas.NEW_YEAR) == thai(2027, 1, 1, 0) and float(Christmas.COUNT_END) == thai(2027, 1, 1, 1), "the countdown: 31 Dec 23:00 - 1 Jan 01:00, midnight between")
	check(not Christmas.on(thai(2026, 11, 30, 23, 59)) and Christmas.on(thai(2026, 12, 1, 0)) and Christmas.on(thai(2027, 1, 2, 23, 59)) and not Christmas.on(thai(2027, 1, 3, 0)), "on to the minute")
	check(not Christmas.night_on(thai(2026, 12, 24, 17, 59)) and Christmas.night_on(thai(2026, 12, 24, 18)) and Christmas.night_on(thai(2026, 12, 25, 5, 59)) and not Christmas.night_on(thai(2026, 12, 25, 6)) and not Christmas.night_on(thai(2026, 12, 23, 20)), "the night, that night only")
	check(not Christmas.countdown_on(thai(2026, 12, 31, 22, 59)) and Christmas.countdown_on(thai(2026, 12, 31, 23)) and Christmas.countdown_on(thai(2027, 1, 1, 0, 59)) and not Christmas.countdown_on(thai(2027, 1, 1, 1)), "the countdown window")
	check(not Christmas.new_year_on(thai(2026, 12, 31, 23, 59)) and Christmas.new_year_on(thai(2027, 1, 1, 0)), "the new year from midnight")
	check(Christmas.burst(thai(2027, 1, 1, 0)) > 0.99 and Christmas.burst(thai(2027, 1, 1, 0, 2)) > 0.0 and Christmas.burst(thai(2027, 1, 1, 0, 4)) == 0.0 and Christmas.burst(thai(2026, 12, 31, 23, 30)) == 0.0, "the big burst right after midnight")
	check(Christmas.fireworks_on(thai(2026, 12, 31, 23, 30)) and not Christmas.fireworks_on(thai(2026, 12, 24, 20)), "fireworks in the countdown only")
	check(not Christmas.on(thai(2026, 11, 24, 20)) and not LoyKrathong.on(thai(2026, 12, 1, 0)) and not WorldEvents.festival3_on(thai(2026, 12, 1, 0)), "no clash with Loy Krathong or the x3 festival")
	check(Christmas.window_text() == "1 ธ.ค. 00:00 - 2 ม.ค. 23:59", "the window as the help prints it (%s)" % Christmas.window_text())
	WorldEvents.festival_enabled = false
	check(not Christmas.on(thai(2026, 12, 10, 12)) and not Christmas.night_on(thai(2026, 12, 24, 20)) and not Christmas.countdown_on(thai(2026, 12, 31, 23, 30)) and not Christmas.decor_on(thai(2026, 12, 10, 12)), "festival_enabled = false: no festival")
	check(Christmas.chip_text(thai(2026, 12, 10, 12)) == "" and Christmas.events(thai(2026, 12, 10, 12)).is_empty(), "and no chip, no events")
	WorldEvents.festival_enabled = true
	Christmas.enabled = false
	check(not Christmas.on(thai(2026, 12, 10, 12)), "its own switch too")
	Christmas.enabled = true


func _exp() -> void:
	# 24 Dec 2026 and 31 Dec 2026 are Thursdays: no weekend, no other festival.
	check(is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 12, 24, 19, 30)), 2.5), "Christmas night in the evening hours: x2 + 50%% = x2.5 (%s)" % WorldEvents.exp_multiplier(thai(2026, 12, 24, 19, 30)))
	check(is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 12, 24, 18, 30)), 1.5) and is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 12, 25, 3)), 1.5), "the rest of the night x1.5")
	check(is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 12, 31, 23, 30)), 1.5) and is_equal_approx(WorldEvents.exp_multiplier(thai(2027, 1, 1, 0, 30)), 1.5), "the countdown x1.5")
	check(is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 12, 25, 6)), 1.0) and is_equal_approx(WorldEvents.exp_multiplier(thai(2027, 1, 1, 1)), 1.0) and is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 12, 20, 12)), 1.0), "nothing outside the highlights")
	check(is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 12, 20, 19, 30)), 2.0), "another evening keeps its plain x2")
	check(RewardShop.event_hours(thai(2026, 12, 25, 3)) and RewardShop.event_hours(thai(2026, 12, 31, 23, 30)), "the highlights are event hours for the reward shop's kill points")
	WorldEvents.festival_enabled = false
	check(is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 12, 24, 19, 30)), 2.0), "the base-rate switch leaves the evening's x2 alone")
	WorldEvents.festival_enabled = true


func _drops() -> void:
	var field: Dictionary = ZoneData.get_zone(&"meadow")
	var town: Dictionary = ZoneData.get_zone(&"town")
	var roll := RandomNumberGenerator.new()
	roll.seed = 7
	var inside := thai(2026, 12, 10, 12)
	var n := 0
	var kills := 20000
	for i in kills:
		for item in Christmas.kill_drops(field, false, inside, roll):
			check(String(item.id) == Christmas.GIFT, "a gift box drops")
			n += int(item.count)
	var rate := float(n) / float(kills)
	check(absf(rate - Christmas.GIFT_DROP) < 0.006, "about %s%% a kill, like the Halloween potion (%.4f)" % [ChatFacts.pct(Christmas.GIFT_DROP), rate])
	check(is_equal_approx(Christmas.GIFT_DROP, WorldEvents.HALLOWEEN_DROP), "the Halloween potion's rate")
	var boss := Christmas.kill_drops(field, true, inside, roll)
	check(boss.size() == 1 and int(boss[0].count) == Christmas.GIFT_BOSS, "a boss gives %d boxes" % Christmas.GIFT_BOSS)
	var none := 0
	for i in 3000:
		none += Christmas.kill_drops(field, true, thai(2026, 11, 30, 23), roll).size() + Christmas.kill_drops(field, false, thai(2027, 1, 3, 0, 1), roll).size()
		none += Christmas.kill_drops(town, true, inside, roll).size() + Christmas.kill_drops({}, true, inside, roll).size()
	check(none == 0, "none outside the window, in the village or outside the hunting grounds")
	WorldEvents.festival_enabled = false
	check(Christmas.kill_drops(field, true, inside, roll).is_empty(), "none with festival_enabled = false")
	WorldEvents.festival_enabled = true
	check(ItemData.JEWELS.has(Christmas.GIFT) and ItemData.JEWELS.has(Christmas.PIECE) and ItemData.is_stackable(Christmas.gift()), "the box and the piece are stackables")
	check(Christmas.help(Christmas.GIFT).contains("ชุดซานต้า") and Christmas.help(Christmas.PIECE).contains("30"), "their help in the bag")


func _sum_table() -> float:
	var s := 0.0
	for row in Christmas.GIFT_TABLE:
		s += float(row[1])
	return s


func _opening() -> void:
	check(is_equal_approx(_sum_table(), 1.0), "the prize table adds to 100%%")
	# The distribution of many boxes (gift_prize, a hero without the costume).
	var roll := RandomNumberGenerator.new()
	roll.seed = 2026
	var got := {}
	var n := 40000
	var gold_hi := 0
	for i in n:
		var p := Christmas.gift_prize(1, false, roll)
		var k := "gold"
		if p.has("item"):
			var item: Dictionary = p.item
			k = "costume" if bool(p.get("costume", false)) else ("potion" if String(item.kind) == "potion" else String(item.id))
		else:
			gold_hi = maxi(gold_hi, int(p.gold))
		got[k] = int(got.get(k, 0)) + 1
	var want := {"gold": 0.47, "potion": 0.24, "purple": 0.12, "pink": 0.06, "chaos": 0.028, Christmas.PIECE: 0.08, "costume": 0.002}
	for k in want:
		var share := float(got.get(k, 0)) / float(n)
		check(absf(share - float(want[k])) < maxf(0.006, float(want[k]) * 0.35), "%s about %s%% of the boxes (%.4f)" % [k, ChatFacts.pct(float(want[k])), share])
	check(gold_hi <= int(Christmas.GIFT_GOLD[1] * 1.5) and gold_hi > 0, "small gold for the band (%d)" % gold_hi)
	var owned := 0
	for i in 2000:
		var p := Christmas.gift_prize(1, true, roll)
		check(not bool(p.get("costume", false)), "an owner never rolls the costume again")
		if p.has("item") and String(p.item.id) == Christmas.PIECE and int(p.item.count) == Christmas.COSTUME_REPEAT:
			owned += 1
	check(owned >= 0, "owned, the costume is pieces")
	# Opening from the bag: one, then all; the costume once.
	Game.profile.inv = []
	(RewardShop.data().get("own", []) as Array).erase(Christmas.COSTUME)
	Game.profile.flags.erase(RewardShop.ITEM_FLAG + Christmas.COSTUME)
	check(String(Christmas.open_gifts(1).stopped) != "", "no boxes, nothing opens")
	Game.give_or_store(Christmas.gift(250))
	var gold0 := int(Game.profile.gold)
	var one := Christmas.open_gifts(1, roll)
	check(int(one.opened) == 1 and Game.jewel_count(Christmas.GIFT) == 249, "one box opens")
	check(int(Game.profile.gold) - gold0 == int(one.gold) and (int(one.gold) > 0) != ((one.items as Array).size() > 0), "one prize: gold or an item")
	var all := Christmas.open_gifts(Christmas.OPEN_ALL_MAX, roll)
	check(int(all.opened) == Christmas.OPEN_ALL_MAX and Game.jewel_count(Christmas.GIFT) == 249 - Christmas.OPEN_ALL_MAX, "open all: at most %d a press" % Christmas.OPEN_ALL_MAX)
	# A rigged roll for the costume: given once, then pieces.
	Game.profile.inv = []
	Game.give_or_store(Christmas.gift(2))
	var first := Christmas.open_gifts(1, _lucky())
	check((first.jackpots as Array).size() == 1 and RewardShop.owns(Christmas.COSTUME) and RewardShop.has_item(Christmas.COSTUME), "the rare box holds the Santa costume, into the bag")
	var again := Christmas.open_gifts(1, _lucky())
	check((again.jackpots as Array).is_empty() and Game.jewel_count(Christmas.PIECE) == Christmas.COSTUME_REPEAT, "the costume only once: then %d pieces" % Christmas.COSTUME_REPEAT)
	var costumes := 0
	for item in Game.profile.inv:
		if ItemData.is_costume(item) and String(item.id) == Christmas.COSTUME:
			costumes += 1
	check(costumes == 1, "one costume item (%d)" % costumes)
	Game.profile.inv = []


## Dice whose first roll lands on the costume's row (the table's last 0.2%).
func _lucky() -> RandomNumberGenerator:
	for s in 200000:
		var r := RandomNumberGenerator.new()
		r.seed = s
		if r.randf() >= 0.9985:
			r.seed = s
			return r
	return RandomNumberGenerator.new()


func _costume() -> void:
	var e: Dictionary = RewardShop.COSTUMES.get(Christmas.COSTUME, {})
	check(not e.is_empty() and String(e.name) == "ชุดซานต้า" and RewardShop.fragments_of(e) == Christmas.COSTUME_PIECES and RewardShop.fragment_id(e) == Christmas.PIECE, "the Santa costume for %d pieces" % Christmas.COSTUME_PIECES)
	(RewardShop.data().get("own", []) as Array).erase(Christmas.COSTUME)
	Game.profile.flags.erase(RewardShop.ITEM_FLAG + Christmas.COSTUME)
	Game.profile.inv = []
	Game.give_or_store(ItemData.jewel(Christmas.PIECE, Christmas.COSTUME_PIECES))
	at(thai(2027, 1, 5, 12))
	check(RewardShop.problem("costume", Christmas.COSTUME) != "", "no exchange after the festival")
	at(thai(2026, 12, 10, 12))
	check(RewardShop.problem("costume", Christmas.COSTUME) == "", "the exchange in the window (%s)" % RewardShop.problem("costume", Christmas.COSTUME))
	check(RewardShop.buy("costume", Christmas.COSTUME) == "ok" and Game.jewel_count(Christmas.PIECE) == 0 and RewardShop.has_item(Christmas.COSTUME), "30 pieces become the costume")
	check(RewardShop.problem("costume", Christmas.COSTUME) == "มีแล้ว", "once a hero")
	check(RewardShop.price_text(e).contains(Christmas.TITLE), "the shop card names the festival")
	var world := false
	for i in 200:
		world = world or String(RewardShop.world_cosmetics(i).cos) == Christmas.COSTUME
	check(not world, "the world players never buy it with coins")
	Game.profile.inv = []


func _chat() -> void:
	var before := thai(2026, 11, 28, 12)
	check(Christmas.chat_answer(-1, before).contains("1 ธ.ค. 00:00") and Christmas.chat_answer(-1, before).contains("2 ม.ค. 23:59") and Christmas.chat_answer(-1, before).contains("24 ธ.ค. 18:00"), "before: the dates (%s)" % Christmas.chat_answer(-1, before))
	var mid := thai(2026, 12, 10, 12)
	check(Christmas.chat_answer(-1, mid).contains("5%") and Christmas.chat_answer(-1, mid).contains("30"), "in the window: the drop and the costume (%s)" % Christmas.chat_answer(-1, mid))
	check(Christmas.chat_answer(-1, thai(2027, 1, 4, 12)).contains("จบ"), "after: over")
	check(Christmas.chat_answer(-1, thai(2026, 12, 24, 20)).contains("06:00") and Christmas.chat_answer(-1, thai(2026, 12, 31, 23, 30)).contains("01:00"), "the highlights' ends")
	for t in [before, mid, thai(2026, 12, 24, 20), thai(2027, 1, 4, 12)]:
		check(Christmas.chat_answer(-1, t).length() <= ChatFacts.MAX, "a chat-sized answer (%d)" % Christmas.chat_answer(-1, t).length())
	check(ChatFacts.jewel_source(Christmas.GIFT, mid) == Christmas.chat_answer(-1, mid), "where the box comes from")
	at(mid)
	var who := {"name": "Tor_Warrior", "class": "สายดาบ", "level": 20, "stars": 0, "doing": "hunt", "place": "ป่าเงาม่วง", "guild": "", "inParty": false}
	var reply := String(ChatBrain.reply({"text": "ชุดซานต้าได้ยังไง", "player": who, "hero": {"name": "QA", "class": "นักเวทย์", "level": 9, "stars": 0}, "history": []}).get("reply", ""))
	check(reply.contains("ซานต้า") and reply.contains("30"), "a world player asked about the Santa costume answers truthfully (%s)" % reply)
	check(Christmas.chip_text(mid).contains(Christmas.TITLE) and Christmas.chip_text(thai(2026, 12, 24, 20)).contains("คืนคริสต์มาส") and Christmas.chip_text(thai(2026, 12, 31, 23, 30)).contains("2027") and Christmas.chip_text(thai(2027, 1, 1, 0, 10)).contains(Christmas.NEW_YEAR_TEXT), "the HUD chip through the window")
	check(Christmas.chip_text(before) == "" and WorldEvents.chip_lines(mid).has(Christmas.chip_text(mid)), "it joins the HUD's lines in the window only")
	var ids := WorldEvents.current(thai(2026, 12, 24, 20)).map(func(e): return String(e.id))
	check(ids.has("xmas") and ids.has("xmas_night") and not ids.has("newyear"), "the events list on Christmas night (%s)" % str(ids))
	ids = WorldEvents.current(thai(2026, 12, 31, 23, 30)).map(func(e): return String(e.id))
	check(ids.has("xmas") and ids.has("newyear"), "and in the countdown")
	check(Christmas.chat_line({"index": 3}, 5, before) == "" and Christmas.chat_line({"index": 3}, 5, mid) != "", "world chat lines in the window only")
	check(Christmas.CHAT_NEW.has(Christmas.chat_line({"index": 3}, 5, thai(2027, 1, 1, 0, 5))), "after midnight they wish a happy new year")


func _real_kills() -> void:
	at(thai(2026, 12, 10, 12))
	Game.current_zone = &"meadow"
	Game.profile["spawn_override"] = ""
	var zone := LootZone.new()
	zone.zone_id = &"meadow"
	zone.layout_seed = 11
	add_child(zone)
	zone.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 1200:
		if zone.is_built:
			break
		await get_tree().process_frame
	var mob: Mob = null
	for node in get_tree().get_nodes_in_group("mobs"):
		if node is Mob and not (node as Mob).is_boss:
			mob = node
			break
	check(mob != null, "the field has monsters")
	if mob != null:
		for i in 1200:
			zone._drop_loot(mob)
		var gifts := zone.items.filter(func(it): return String(it.get("id", "")) == Christmas.GIFT).size()
		check(gifts > 20 and gifts < 110, "real kills in the field drop gift boxes (%d in 1200)" % gifts)
		zone.items.clear()
		at(thai(2027, 1, 4, 12))
		for i in 600:
			zone._drop_loot(mob)
		check(zone.items.filter(func(it): return String(it.get("id", "")) == Christmas.GIFT).is_empty(), "none after the festival")
	zone.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _town(t: float) -> Zone:
	at(t)
	Game.current_zone = &"town"
	Game.profile["spawn_override"] = ""
	var zone := Zone.new()
	zone.zone_id = &"town"
	zone.layout_seed = 5
	add_child(zone)
	zone.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 1500:
		if zone.is_built:
			break
		await get_tree().process_frame
	return zone


func _count(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _count(child)
	return n


func _village() -> void:
	GameSettings.quality = 1
	var zone: Zone = await _town(thai(2026, 12, 31, 23, 30))
	var town := ChristmasTown.current
	check(zone.is_built and town != null and town.get_parent() == zone, "the village is dressed in the window")
	if town != null:
		var sakura := zone.find_child("GreatSakura", true, false) as Node3D
		check(sakura != null and not sakura.visible, "the great sakura steps aside for the tree")
		check(town.find_child("ChristmasDecor", false, false) != null and town.lights != null and town.bulb_count >= 150, "the tree, the strands and the street strings (%d bulbs)" % town.bulb_count)
		check(town.snow != null and town.snow.mesh.surface_get_array_len(0) == 4 * ChristmasTown.snow_count(), "snow falls (%d flakes at medium)" % ChristmasTown.snow_count())
		check(town.fireworks != null and town.fireworks.visible and town.sign_label.visible and town.sign_label.text.contains("2027"), "fireworks and the countdown sign in the countdown")
		var nodes := _count(town)
		check(nodes <= 24, "few nodes (%d)" % nodes)
		var draws := 0
		for mi in town.find_children("*", "MeshInstance3D", true, false):
			draws += (mi as MeshInstance3D).mesh.get_surface_count()
		check(draws <= 6, "a handful of draws (%d)" % draws)
		# Midnight: the banner and the big burst.
		var banners: Array = []
		zone.banner_requested.connect(func(text: String): banners.append(text))
		at(thai(2027, 1, 1, 0, 0) + 5.0)
		town._update(Christmas.now())
		check(banners.size() == 1 and String(banners[0]).contains(Christmas.NEW_YEAR_TEXT), "midnight: the banner %s" % str(banners))
		check(float((town.fireworks.material_override as ShaderMaterial).get_shader_parameter("boost")) > 0.9 and town.sign_label.text.contains(Christmas.NEW_YEAR_TEXT), "the big burst and the greeting over the plaza")
		town._update(Christmas.now() + 1.0)
		check(banners.size() == 1, "the banner once")
		at(thai(2027, 1, 1, 1, 30))
		town._update(Christmas.now())
		check(not town.fireworks.visible and not town.sign_label.visible, "the fireworks end with the countdown")
	# Quality tiers: fewer flakes at low quality, more at high.
	GameSettings.quality = 0
	var low := ChristmasTown.snow_count()
	GameSettings.quality = 2
	var high := ChristmasTown.snow_count()
	check(low < high and low > 0, "the snow follows the quality (%d / %d)" % [low, high])
	GameSettings.quality = 1
	zone.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# Before the window, and with the festival switched off: the village as it was.
	var plain: Zone = await _town(thai(2026, 11, 28, 12))
	var sak := plain.find_child("GreatSakura", true, false) as Node3D
	check(plain.is_built and ChristmasTown.current == null and sak != null and sak.visible, "no dressing before the window")
	plain.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	WorldEvents.festival_enabled = false
	var off: Zone = await _town(thai(2026, 12, 24, 20))
	check(off.is_built and ChristmasTown.current == null, "none with festival_enabled = false")
	off.queue_free()
	WorldEvents.festival_enabled = true
	await get_tree().process_frame
	await get_tree().process_frame


func _costume_art() -> void:
	check(not CostumeArt.parts(Christmas.COSTUME).is_empty(), "Santa has its own pieces")
	for spec in CostumeArt.parts(Christmas.COSTUME):
		var mesh := CostumeArt.mesh_of(Christmas.COSTUME, String(spec[1]), false)
		check(mesh != null and mesh.get_surface_count() >= 1, "Santa's %s is built" % spec[1])
	check(CostumeArt.MOTES.has(Christmas.COSTUME) and float(CostumeArt.MOTES[Christmas.COSTUME].shape) == 6.0 and float(CostumeArt.MOTES[Christmas.COSTUME].rise) < 0.0, "snowflakes drift down round the wearer")
	check(ItemLook.COSTUME_ICON_VIEW.has(Christmas.COSTUME), "its icon view")
	await get_tree().process_frame
