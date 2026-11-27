extends Node
## The world players forge their own gear for real (WorldGear): the same on every device,
## built up from the hero's own drop rates and forge odds, never losing a + but through a
## recorded event, the 250★ set only from ★250 in its order by SetGearData.recipe (each
## weapon / armour / helm / boots piece using up a +10 divine piece, the jewellery Lotus
## Scales; a failed try loses only the core and jewels), and what they wear is what they fight with,
## what their card shows and never what their stall sells. Prints a bench of the cost.
##   godot --headless --path . res://tests/integration/world_gear_test.tscn
var failures := 0
var checks := 0
var failed: PackedStringArray = []
const DAY := 86400.0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		failed.append(message)
		printerr("FAIL: ", message)


func _ready() -> void:
	WorldPlayers.clear_bonus()
	WorldPlayers.reset_roster()
	_api()
	_determinism()
	_progression()
	_set_rules()
	_fighters()
	_views()
	_maps()
	_dragon()
	_bench()
	for message in failed:
		print("FAILED: ", message)
	print("WORLD GEAR: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


static func _t(days: float) -> float:
	return float(WorldPlayers.START_UNIX) + days * DAY


## Players with a schedule from the roster (the newcomers come and go with the clock).
func _players(count: int) -> Array[int]:
	var out: Array[int] = []
	for i in WorldPlayers.ROSTER.size():
		if String(WorldPlayers.entry(i).style) == "hardcore" and not WorldPlayers.entry(i).has("join"):
			out.append(i)
		if out.size() >= count:
			break
	return out


func _api() -> void:
	var i := _players(1)[0]
	var g := WorldGear.gear(i, _t(12.0))
	for slot in ["weapon", "armor", "helm", "boots"]:
		check(g.has(slot) and (g[slot] as Dictionary).has("name") and (g[slot] as Dictionary).has("grade") and (g[slot] as Dictionary).has("plus"), "gear has %s {name, grade, plus}" % slot)
	check((g.wings as Dictionary).has("tier") and (g.wings as Dictionary).has("name"), "gear has wings {tier, name}")
	for key in ["set_pieces", "set_name", "divine_pieces", "divine_plus", "mount"]:
		check(g.has(key), "gear has %s" % key)
	check(g.mount is Dictionary and ((g.mount as Dictionary).is_empty() or ((g.mount as Dictionary).has("name") and (g.mount as Dictionary).has("level"))), "mount is {name, level} or {}")
	var before := WorldGear.gear(i, _t(0.0) - 60.0)
	check(String(before.armor.name) == "" and int(before.weapon.plus) == 0 and int(before.set_pieces) == 0 and (before.mount as Dictionary).is_empty(), "before the world opens it has only what everyone starts with")
	# Its first minutes of play (a hardcore player is past Lv.30 an hour in, with the
	# band's finds: the beginner's weapon is what it sets out with, not what it has then).
	var set_out := _t(0.0)
	while WorldPlayers.played_minutes(i, set_out) <= 0.0 and set_out < _t(2.0):
		set_out += 60.0
	set_out += 5.0 * 60.0
	var early := WorldGear.gear(i, set_out)
	check(WorldPlayers.level_at(i, set_out) <= 10 and String(early.weapon.name).contains("มือใหม่") and int(early.weapon.plus) <= 6, "everyone sets out with the beginner's weapon (Lv.%d: %s)" % [WorldPlayers.level_at(i, set_out), early.weapon])
	var ev := WorldGear.events(i, _t(0.0), _t(12.0))
	check(not ev.is_empty(), "twelve days of play leave events")
	var last := -INF
	var sorted := true
	var inside := true
	var kinds_ok := true
	for e in ev:
		sorted = sorted and float(e.at) >= last
		last = float(e.at)
		inside = inside and float(e.at) > _t(0.0) and float(e.at) <= _t(12.0)
		kinds_ok = kinds_ok and WorldGear.KINDS.has(String(e.kind)) and e.has("slot") and e.has("from") and e.has("to") and e.has("item")
	check(sorted and inside and kinds_ok, "events are oldest first, inside the window, with kind / slot / from / to / item")
	var ok := WorldGear.last_event(i, _t(12.0), "enhance_ok", 12.0 * DAY)
	check(not ok.is_empty() and int(ok.to) == int(ok.from) + 1, "last_event finds the latest enhance (%s)" % ok)
	check(WorldGear.last_event(i, _t(12.0), "enhance_ok", 1.0).is_empty() or float(WorldGear.last_event(i, _t(12.0), "enhance_ok", 1.0).at) > _t(12.0) - 1.0, "last_event keeps to its window")


## The same moment gives the same gear on every device, however it was worked out.
func _determinism() -> void:
	var same := true
	var order := true
	for i in _players(25):
		for d in [1.5, 6.0, 20.0, 45.0]:
			var a := JSON.stringify(WorldGear.gear(i, _t(d)))
			var ea := JSON.stringify(WorldGear.events(i, _t(d) - DAY, _t(d)))
			WorldGear.clear()
			var b := JSON.stringify(WorldGear.gear(i, _t(d)))
			same = same and a == b and ea == JSON.stringify(WorldGear.events(i, _t(d) - DAY, _t(d)))
		# Read late first, then early: the simulation only ever grows, so the early answer holds.
		WorldGear.clear()
		var late := JSON.stringify(WorldGear.gear(i, _t(30.0)))
		var early := JSON.stringify(WorldGear.gear(i, _t(4.0)))
		WorldGear.clear()
		order = order and early == JSON.stringify(WorldGear.gear(i, _t(4.0))) and late == JSON.stringify(WorldGear.gear(i, _t(30.0)))
	check(same, "the same time gives the same gear and events after starting over")
	check(order, "reading a later moment first changes nothing about an earlier one")
	WorldPlayers.reset_roster()
	var i0 := _players(1)[0]
	var a0 := JSON.stringify(WorldGear.gear(i0, _t(9.0)))
	WorldPlayers.reset_roster()
	check(a0 == JSON.stringify(WorldGear.gear(i0, _t(9.0))), "the world worked out from nothing (another device) wears the same")


## Every + is earned at the forge: a slot's + never drops while it keeps its piece, and
## a piece changes only through a recorded find or set forging; failed tries keep the grade.
func _progression() -> void:
	var steady := true
	var recorded := true
	var fail_keeps := true
	var rose := 0
	var fails := 0
	var raised := 0
	for i in _players(30):
		var prev := WorldGear.gear(i, _t(0.0))
		var t_prev := _t(0.0)
		for k in range(1, 120):
			var t := _t(float(k) * 0.4)
			var g := WorldGear.gear(i, t)
			var ev := WorldGear.events(i, t_prev, t)
			for e in ev:
				if String(e.kind) == "enhance_fail":
					fails += 1
					fail_keeps = fail_keeps and int(e.to) == int(e.from)
				raised += 1 if String(e.kind) == "enhance_ok" else 0
			for slot in ["weapon", "armor", "helm", "boots", "ring", "amulet"]:
				var a: Dictionary = prev[slot]
				var b: Dictionary = g[slot]
				if String(a.key) == String(b.key) and String(a.key) != "":
					# The same kind of piece at a lower +: only another piece of it put on.
					if int(b.plus) < int(a.plus):
						var swap := ev.any(func(e): return String(e.slot) == slot and String(e.kind) in ["drop", "divine_piece"])
						steady = steady and swap
						if not swap:
							print("plus dropped ", WorldPlayers.entry(i).name, " ", slot, " ", a, " -> ", b)
					rose += 1 if int(b.plus) > int(a.plus) else 0
				elif String(a.key) != "":
					var why := ev.any(func(e): return String(e.slot) == slot and String(e.kind) in ["drop", "set_piece", "divine_piece"])
					recorded = recorded and why
					if not why:
						print("unrecorded change ", WorldPlayers.entry(i).name, " ", slot, " ", a, " -> ", b)
			if int(g.wings.tier) < int(prev.wings.tier):
				steady = false
			prev = g
			t_prev = t
	check(steady, "a worn piece's + never drops, and wings never go back")
	check(recorded, "every change of piece is a recorded find or forging")
	check(fail_keeps and fails > 0, "failed tries happen (%d) and keep the grade" % fails)
	# (Its forging is done on its trips to the blacksmith, WorldGear.forge_window: a new piece
	# is mostly raised on the trip after it, so a reading a few hours apart sees fewer
	# pieces caught on their way up than when it forged all through a stretch.)
	check(rose > 60 and raised > 1500, "the forge really raises the pieces (%d rises seen, %d +1)" % [rose, raised])
	# Enhance events match the hero's odds overall: about half of +7..+9 tries succeed.
	var ok := 0
	var tried := 0
	for i in _players(40):
		for e in WorldGear.events(i, _t(0.0), _t(40.0)):
			if String(e.kind) in ["enhance_ok", "enhance_fail"] and int(e.from) >= 6 and int(e.from) < 9:
				tried += 1
				ok += 1 if String(e.kind) == "enhance_ok" else 0
	check(tried > 200 and absf(float(ok) / float(tried) - 0.5) < 0.08, "+7..+9 succeed at the forge's 50%% (%d / %d)" % [ok, tried])


## The 250★ set: only from ★250, in SetGearData.SLOTS order, a +10 divine piece used up
## for each weapon / armour / helm / boots piece, scales for the ring and amulet.
func _set_rules() -> void:
	var from_250 := true
	var in_order := true
	var divine_used := true
	var any_piece := 0
	var went_down := 0
	var bank_ok := true
	for i in _players(60):
		var w := WorldPlayers.work_at(i, _t(45.0))
		var sim: WorldGear.Sim = WorldGear._sim(i, w)
		bank_ok = bank_ok and sim.purple >= 0 and sim.pink >= 0 and sim.chaos >= 0 and sim.core >= 0 and sim.scales >= 0 and sim.feather >= 0
		var st: Dictionary = WorldGear._copy(sim.snaps[0])
		for ev in sim.events:
			var kind := String(ev.kind)
			if kind in ["set_piece", "set_fail"]:
				var at_stars := WorldGear._step_of(float(ev.w))
				from_250 = from_250 and at_stars.x >= Game.MAX_LEVEL and at_stars.y >= SetGearData.STARS
				var n := int(st.set)
				in_order = in_order and String(ev.slot) == SetGearData.SLOTS[n] and int(ev.from) == n and int(ev.to) == (n + 1 if kind == "set_piece" else n)
				var tag := String(ev.get("used", "")) if kind == "set_piece" else String(ev.get("kept", ""))
				if DivineGearData.SLOTS.has(String(ev.slot)):
					var worn: Array = st.worn.get(String(ev.slot), ["", 0])
					divine_used = divine_used and tag == "divine_%s" % ev.slot and String(worn[0]) == "divine" and int(worn[1]) >= SetGearData.recipe(String(WorldPlayers.entry(i)["class"]), String(ev.slot)).divine_plus
				else:
					divine_used = divine_used and tag == "scales"
				var was := int(st.divine)
				WorldGear._apply(st, ev)
				any_piece += 1 if kind == "set_piece" else 0
				went_down += 1 if int(st.divine) < was else 0
			else:
				WorldGear._apply(st, ev)
	check(any_piece > 0, "world players forge 250★ set pieces by day 45 (%d)" % any_piece)
	check(from_250, "set pieces are forged only from ★250")
	check(in_order, "set pieces come one by one in the set's order")
	check(divine_used, "each weapon / armour / helm / boots try needs its +10 divine piece, ring and amulet scales (used up on success, kept on a fail)")
	check(went_down > 0, "forging a set piece can leave fewer divine pieces (%d)" % went_down)
	check(bank_ok, "no material is ever spent that was not there")
	# The public event says what was used.
	var seen_used := false
	for i in _players(60):
		for e in WorldGear.events(i, _t(0.0), _t(45.0)):
			if String(e.kind) == "set_piece":
				seen_used = seen_used or String(e.get("used", "")) != ""
	check(seen_used, "a set_piece event says what it used")


## Stronger gear makes a really stronger fighter.
func _fighters() -> void:
	var stronger := true
	var grows := 0
	var count := 0
	for i in _players(20):
		var t := _t(8.0)
		var f := WorldPlayers.fighter(i, t)
		var sheet: Dictionary = (f.profile as Dictionary).duplicate(true)
		var bare: Dictionary = sheet.duplicate(true)
		for slot in bare.equip:
			if (bare.equip[slot] as Dictionary).has("plus"):
				bare.equip[slot]["plus"] = 0
		var with_plus := GuildWarData.power_of(HeroStats.compute(sheet))
		var without := GuildWarData.power_of(HeroStats.compute(bare))
		var any_plus := false
		for slot in sheet.equip:
			any_plus = any_plus or int(sheet.equip[slot].get("plus", 0)) > 0
		if any_plus:
			stronger = stronger and with_plus > without
		count += 1
		var later := float(WorldPlayers.fighter(i, _t(30.0)).power)
		grows += 1 if later > float(f.power) else 0
		# The fighter wears exactly WorldGear's pieces.
		var g := WorldGear.gear(i, t)
		check(String(sheet.equip.weapon.name) == String(g.weapon.name) and int(sheet.equip.weapon.get("plus", 0)) == int(g.weapon.plus), "%s fights with its own weapon" % WorldPlayers.entry(i).name)
	check(stronger, "the forge's + makes the fighter stronger")
	check(grows == count, "fighters grow stronger with their gear and play (%d / %d)" % [grows, count])


## The card, the body (online mirror) and the stall all read the same gear; saves and
## the hero's character change nothing.
func _views() -> void:
	var t := _t(10.0)
	var i := _players(3)[2]
	var g := WorldGear.gear(i, t)
	var m := WorldPlayers.member(i, t)
	check(WorldPlayers.gear_signature(m) == WorldGear.signature_at_work(i, WorldPlayers.work_at(i, t)), "the member sheet wears the gear of its moment")
	check(String(WorldPlayers.equip(m).weapon.name) == String(g.weapon.name), "equip and gear agree")
	var text := PlayerCard.gear_lines(i, t)
	check(text.contains(String(g.weapon.name)) and (int(g.weapon.plus) == 0 or text.contains("+%d" % int(g.weapon.plus))), "the player card shows its real weapon (%s)" % text)
	if not (g.mount as Dictionary).is_empty():
		check(text.contains("%s Lv.%d" % [g.mount.name, int(g.mount.level)]), "the card shows its real mount")
	var mt := WorldPlayers.mount_of(m)
	check((g.mount as Dictionary).is_empty() == mt.is_empty() and (mt.is_empty() or String(mt.id) == String(g.mount.id)), "the body rides the mount it forged")
	# A new character (an old save or a fresh one) and the world file change nothing.
	var before := JSON.stringify(g)
	Game.new_profile(&"warrior", "GearQA", FaceKit.default_look())
	WorldPlayers.store()
	check(before == JSON.stringify(WorldGear.gear(i, t)), "the hero's character and saves leave the world's gear alone")
	# Stall keepers never sell what they wear.
	var clean := true
	var keepers := 0
	for k in WorldPlayers.ROSTER.size():
		if String(WorldPlayers.entry(k).style) != "afk":
			continue
		keepers += 1
		var worn := {}
		for piece in WorldPlayers.equip(WorldPlayers.member(k, t)).values():
			worn["%s|%d" % [piece.name, int(piece.level)]] = true
		for lot in StallStock.full_stock(k, t):
			if String(lot.item.get("kind", "")) == "equip":
				clean = clean and not worn.has("%s|%d" % [lot.item.name, int(lot.item.get("level", 0))])
	check(keepers > 0 and clean, "stall keepers sell their finds, never what they wear")


## From ★200 a player splits its sessions between the drowned abyss and the lotus sanctum.
func _maps() -> void:
	var abyss := 0
	var lotus := 0
	for i in _players(40):
		for k in 60:
			var t := _t(14.0 + float(k) * 0.37)
			var s := WorldPlayers.state(i, t)
			if String(s.doing) in ["hunt", "boss"]:
				if StringName(s.place) == DrownedAbyssData.ID:
					abyss += 1
				elif StringName(s.place) == DivineRegionData.ID:
					lotus += 1
	check(abyss > 20 and lotus > 20, "★200+ players hunt both endgame maps (abyss %d, sanctum %d)" % [abyss, lotus])


## เกาะลอยฟ้าเทพมังกร: the ★300 players really hunt the Dragon God's weapon and wings. Each
## one worn came from a drop event of the player's own isle kills, never below ★300 or
## without isle kills; the counts fit the owner's rates; the forge raises them; the
## weapon stands in for the set's weapon; the card, the fighter and the stall agree.
func _dragon() -> void:
	var t := _t(40.0)
	var holders_w := 0
	var holders_wi := 0
	var raised_w := 0
	var raised_wi := 0
	var own_drop := true
	var none_below := true
	var below := 0
	var isle_players := 0
	var kills := 0.0
	var got_w := 0
	var got_wi := 0
	var want_holders := 0.0
	var set_ok := true
	var no_set_over := true
	var views := true
	var spares := 0
	var pluses: Array[int] = []
	for i in WorldPlayers.size():
		var w := WorldPlayers.work_at(i, t)
		var sim: WorldGear.Sim = WorldGear._sim(i, w)
		var st := WorldGear.state_at_work(i, w)
		var g := WorldGear.gear_at_work(i, w)
		var step := WorldGear._step_of(w)
		var top := WorldGear._step_of(WorldGear._edge(sim.chunks))
		var weapon_key := String(((st.worn as Dictionary).get("weapon", [""]) as Array)[0])
		var wings_key := String(((st.worn as Dictionary).get("wings", [""]) as Array)[0])
		var has_w := weapon_key == WorldGear.DRAGON
		var has_wi := wings_key == WorldGear.DRAGON
		if top.x < Game.MAX_LEVEL or top.y < WorldGear.ISLE_STARS or sim.isle_kills <= 0.0:
			# Never on the isle (as far as its forging has run): nothing of the Dragon God.
			below += 1
			none_below = none_below and not has_w and not has_wi and sim.dragon_weapons == 0 and sim.dragon_wings == 0 and sim.isle_kills == 0.0
			continue
		isle_players += 1
		kills += sim.isle_kills
		got_w += sim.dragon_weapons
		got_wi += sim.dragon_wings
		want_holders += 1.0 - exp(-sim.isle_kills * WorldGear.DRAGON_WEAPON_DROP)
		# Every Dragon God piece of its own, worn or spare, is an event of its own isle kills.
		var first := {}
		var weapon_at := INF
		var found := 0
		for ev in sim.events:
			# (The forge's events name the piece they raise by its key too.)
			if String(ev.get("key", "")) != WorldGear.DRAGON or not (String(ev.kind) in ["drop", "spare"]):
				continue
			found += 1
			var at := WorldGear._step_of(float(ev.w))
			own_drop = own_drop and at.x >= Game.MAX_LEVEL and at.y >= WorldGear.ISLE_STARS
			if String(ev.kind) == "drop":
				own_drop = own_drop and not first.has(String(ev.slot))
				first[String(ev.slot)] = float(ev.w)
				if String(ev.slot) == "weapon":
					weapon_at = float(ev.w)
			else:
				spares += 1
				own_drop = own_drop and first.has(String(ev.slot))
		own_drop = own_drop and found == sim.dragon_weapons + sim.dragon_wings
		own_drop = own_drop and (not has_w or float(first.get("weapon", INF)) <= w) and (not has_wi or float(first.get("wings", INF)) <= w)
		# No set weapon forged and no divine weapon put on over it.
		for ev in sim.events:
			if float(ev.w) > weapon_at and String(ev.slot) == "weapon" and (String(ev.kind) in ["set_piece", "set_fail"] or (String(ev.kind) == "divine_piece" and bool(ev.get("wear", false)))):
				no_set_over = false
		var equip := WorldGear.equip_at_work(i, w)
		set_ok = set_ok and int(g.set_pieces) == SetGearData.worn_count(equip, String(WorldPlayers.entry(i)["class"]))
		if has_w:
			holders_w += 1
			pluses.append(int(g.weapon.plus))
			raised_w += 1 if int(g.weapon.plus) > 0 else 0
			views = views and String(g.weapon.kind) == "dragon" and DragonGearData.is_weapon(equip.weapon) and int(equip.weapon.plus) == int(g.weapon.plus)
			var sheet := WorldPlayers.profile(WorldPlayers.member(i, t))
			views = views and DragonGearData.is_weapon(sheet.equip.weapon) and bool(HeroStats.compute(sheet).get("dragon_line", false))
			views = views and PlayerCard.gear_lines(i, t).contains(String(g.weapon.name))
			views = views and not StallStock.plus_limits(equip).has("weapon")
		if has_wi:
			holders_wi += 1
			raised_wi += 1 if int(g.wings.plus) > 0 else 0
			views = views and int(g.wings.tier) == WorldGear.WTIER_DRAGON and DragonGearData.is_wings(equip.wings)
	var spread := {}
	for p in pluses:
		spread[p] = int(spread.get(p, 0)) + 1
	var want_w := kills * WorldGear.DRAGON_WEAPON_DROP
	var want_wi := kills * WorldGear.DRAGON_WING_DROP
	print("world_gear_test dragon at day 40: %d players on the isle (%.0f isle kills), %d below; weapons dropped %d (%.1f expected), wings %d (%.1f), %d spares; worn weapon %d (%.1f expected holders, %d raised, + %s), wings %d (%d raised)"
		% [isle_players, kills, below, got_w, want_w, got_wi, want_wi, spares, holders_w, want_holders, raised_w, str(spread), holders_wi, raised_wi])
	check(isle_players > 10 and holders_w > 0 and holders_wi > 0, "★300 world players hold the Dragon God weapon (%d) and wings (%d) of their own drops" % [holders_w, holders_wi])
	check(own_drop, "each one came from a drop event of its own isle kills at ★300 (the first worn, the rest spares)")
	check(below > 0 and none_below, "nobody below ★300 or without isle kills has any (%d players)" % below)
	check(absf(float(got_w) - want_w) <= 4.0 * sqrt(want_w) + 2.0, "weapons dropped fit the owner's rate (%d, %.1f expected)" % [got_w, want_w])
	check(absf(float(got_wi) - want_wi) <= 4.0 * sqrt(want_wi) + 2.0, "wings dropped fit the owner's rate (%d, %.1f expected)" % [got_wi, want_wi])
	check(absf(float(holders_w) - want_holders) <= 4.0 * sqrt(maxf(want_holders, 1.0)) + 2.0, "weapon holders fit the chance of at least one drop (%d, %.1f expected)" % [holders_w, want_holders])
	check(raised_w > 0 and raised_wi > 0, "the forge raises the worn Dragon God pieces (weapon %d, wings %d)" % [raised_w, raised_wi])
	check(no_set_over, "no set weapon is forged and no divine weapon put on over the Dragon God weapon")
	check(set_ok, "the set count is the pieces the game counts (the Dragon God weapon stands in for the set's weapon)")
	check(views, "the card, the fighter (with the Dragon God's line), the equip and the stall see the same pieces")
	# The same on another device: worked out again from nothing.
	var some: Array[int] = []
	for i in WorldPlayers.size():
		if WorldGear._sims.has(i) and (WorldGear._sims[i] as WorldGear.Sim).dragon_wings > 0:
			some.append(i)
		if some.size() >= 4:
			break
	var before: Array = []
	for i in some:
		before.append(JSON.stringify(WorldGear.events(i, _t(0.0), t)))
	WorldGear.clear()
	var same := true
	for k in some.size():
		same = same and JSON.stringify(WorldGear.events(some[k], _t(0.0), t)) == before[k]
	check(some.size() > 0 and same, "the same drops on every device (%d players)" % some.size())


## The cost: every player's gear at a moment, worked out from nothing and again; a chat
## line's look-up (gear and a window of events); a frame of warm().
func _bench() -> void:
	var t := _t(40.0)
	var n := WorldPlayers.size()
	WorldGear.clear()
	var t0 := Time.get_ticks_usec()
	for i in n:
		WorldGear.gear(i, t)
	var cold := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for i in n:
		WorldGear.gear(i, t + 30.0)
	var warm := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	var lines := 0
	for k in 200:
		var i := k % n
		ChatThreads.news(i, t + 30.0 + float(k))
		lines += 1
	var line := float(Time.get_ticks_usec() - t0) / float(lines)
	WorldGear.clear()
	# The first object made after freeing a whole world of them (clear(): tests only) is
	# slow in the engine itself; the game never frees them, so that frame is left out.
	WorldGear._new_sim(0)
	var frames := 0
	var worst := 0
	while frames < 5000:
		frames += 1
		var f0 := Time.get_ticks_usec()
		var done := WorldGear.warm(t, 1500)
		var spent := Time.get_ticks_usec() - f0
		worst = maxi(worst, spent)
		if done and frames > n:
			break
	print("BENCH world gear: %d players at day 40: cold %.1f ms (%.2f ms a player), cached %.2f ms; a chat line's news %.0f us; warm() %d frames, worst frame %.2f ms" % [n, cold / 1000.0, cold / 1000.0 / n, warm / 1000.0, line, frames, worst / 1000.0])
	check(warm < cold, "cached reads are cheap")
	check(worst < 10000, "a warm() frame stays near its budget (%.2f ms)" % (worst / 1000.0))
