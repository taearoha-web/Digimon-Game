extends Node
## Every world player does its enhancing at the village's blacksmith, like a real player
## (WorldGear's forge trips, WorldPlayers.forge_errand): a + only ever rises while it stands
## at the blacksmith on an "enhance" errand (a stall keeper too), the chat's forge news
## tells of what happened there, the pace of its gear stays what it was before the trips
## (within REL of the reference the forge reached when it forged anywhere), and a member of
## the hero's party whose trip comes due says so in the party chat, goes to the village
## (seen at the blacksmith), and then by a roll of its own comes back or says goodbye.
##   godot --headless --path . res://tests/integration/ai_forge_errand_test.tscn
var failures := 0
var checks := 0
var failed: PackedStringArray = []
var main: Node
const DAY := 86400.0
## How far the gear's pace may stray from the reference.
const REL := 0.1
## The forge's kinds (all done at the blacksmith; the 100★ wings' craft is a wings_up with
## the key "sw", a drop's wings_up has another).
const FORGE_KINDS := ["enhance_ok", "enhance_fail", "set_piece", "set_fail", "wings_fail", "mount_up", "mount_fail"]
## The forge's pace before the trips (WorldGear forging every stretch wherever it was):
## the mean over the players of _work_sample of the + of the five enhanced slots, the set
## pieces, the mount (its place in MountData.ORDER x10 + its level) and the wings tier, at
## these works (probe minutes).
const BY_WORK := {
	150.0: [64.53, 0.0, 11.60, 0.41],
	400.0: [72.80, 0.0, 14.01, 0.93],
	1000.0: [71.98, 0.0, 15.60, 1.98],
	2500.0: [72.89, 4.73, 17.26, 2.04],
	6000.0: [74.87, 6.00, 18.62, 3.02],
	12000.0: [74.98, 6.00, 19.41, 3.82],
	25000.0: [75.00, 6.00, 20.48, 4.00],
}
## The same for the first 60 hardcore roster players by real days: [+, set pieces].
const BY_DAY := {1.0: [71.90, 0.0], 2.0: [73.58, 0.0], 5.0: [73.70, 3.07], 10.0: [74.88, 5.97], 20.0: [74.97, 6.00]}


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		failed.append(message)
		printerr("FAIL: ", message)


func _ready() -> void:
	WorldEvents.festival_enabled = false
	WorldPlayers.clear_bonus()
	WorldPlayers.reset_roster()
	WorldGear.clear()
	_trips()
	_only_at_forge()
	_sampled()
	_chat()
	_pace()
	await _party()
	for message in failed:
		print("FAILED: ", message)
	print("AI FORGE ERRAND: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


static func _t(days: float) -> float:
	return float(WorldPlayers.START_UNIX) + days * DAY


## A sample of the world: hardcore roster players, a stall keeper or two, and newcomers.
func _sample() -> Array[int]:
	WorldPlayers.ensure_until(_t(6.0))
	var out: Array[int] = []
	var afk := 0
	for i in WorldPlayers.size():
		var style := String(WorldPlayers.entry(i).style)
		if style == "afk" and afk < 2:
			afk += 1
			out.append(i)
		elif i % 9 == 0:
			out.append(i)
	return out


## The trips: one in each cell of a player's work, inside it, ERRAND_MIN..ERRAND_MAX real
## minutes long at its pace, the same however they are read.
func _trips() -> void:
	var ok := true
	var hold_ok := true
	for i in [0, 3, 7]:
		var every := WorldGear.forge_every(i)
		var rate := WorldPlayers.efficiency(i) * (1.0 + WorldParties.taste(i) * WorldParties.EXP_BONUS)
		for k in 20:
			var win := WorldGear.forge_window(i, k)
			var a := float(win[0])
			var b := float(win[1])
			var cell := WorldGear.forge_cell(i, k)
			var minutes := (b - a) / rate
			ok = ok and a > float(cell[0]) and b < float(cell[0]) + float(cell[1]) and minutes >= WorldPlayers.ERRAND_MIN - 0.01 and minutes <= WorldPlayers.ERRAND_MAX + 0.01
			ok = ok and WorldGear.forge_cell_of(i, (a + b) * 0.5) == k and int(WorldGear.forge_trip_at(i, (a + b) * 0.5)[0]) == k
			ok = ok and int(WorldGear.forge_trip_at(i, a - 0.001 * every)[0]) == -1 and int(WorldGear.forge_trip_at(i, b)[0]) == -1
			# The party EXP stops at the trip's start, and goes on once it is behind it.
			hold_ok = hold_ok and is_equal_approx(WorldGear.forge_hold(i, a - 0.5 * (a - float(cell[0]))), a)
			hold_ok = hold_ok and is_equal_approx(WorldGear.forge_hold(i, (a + b) * 0.5), (a + b) * 0.5)
			hold_ok = hold_ok and WorldGear.forge_hold(i, b + 0.0001) > b
		check(is_equal_approx(float(WorldGear.forge_cell(i, WorldGear.FORGE_EARLY)[1]), every) and is_equal_approx(float(WorldGear.forge_cell(i, 0)[1]), every * 0.5), "a new player's first trips come twice as often")
	check(ok, "each trip lies inside its cell, %.1f-%.1f real minutes long at the player's pace" % [WorldPlayers.ERRAND_MIN, WorldPlayers.ERRAND_MAX])
	check(hold_ok, "party EXP is held at a trip's start and goes on after it")


## Every forge event (the +, the set pieces, the 100★ wings' craft, the mount) of the sample
## over six days falls while its player stands at the blacksmith on an "enhance" errand.
func _only_at_forge() -> void:
	var forged := 0
	var away := 0
	var keepers := 0
	var rose := 0
	var first_bad := ""
	for i in _sample():
		for d in 6:
			for e in WorldGear.events(i, _t(float(d)), _t(float(d + 1))):
				var kind := String(e.kind)
				if kind not in FORGE_KINDS and not (kind == "wings_up" and String(e.get("key", "")) == "sw"):
					continue
				forged += 1
				rose += 1 if kind == "enhance_ok" else 0
				# (The event's moment is read to the second: one at the very end of a session
				# may fall a second after it.)
				var at := float(e.at)
				var here := _at_forge(i, at) or _at_forge(i, at - 1.0)
				if not here:
					away += 1
					if first_bad == "":
						var st := WorldPlayers.state(i, at)
						first_bad = "%s %s at %.0f: %s %s" % [WorldPlayers.entry(i).name, kind, at, st.doing, st.errand]
				elif WorldPlayers.in_town_style(i):
					keepers += 1
	print("ai_forge_errand_test: %d forge events (%d +1), %d away from the blacksmith, %d of stall keepers" % [forged, rose, away, keepers])
	check(forged > 2000 and rose > 500, "the sample forges a lot in six days (%d events, %d +1)" % [forged, rose])
	check(away == 0, "every forging happens at the blacksmith on an enhance errand (%d away: %s)" % [away, first_bad])
	check(keepers > 0, "stall keepers leave their stall to forge at the blacksmith too (%d)" % keepers)


func _at_forge(i: int, at: float) -> bool:
	var s := WorldPlayers.state(i, at)
	if not (String(s.doing) == "errand" and String(s.errand) == "enhance" and String(s.place) == "town"):
		return false
	var sess := WorldPlayers.session_at(i, at)
	var run := WorldPlayers.errand_at(i, float(sess[0]), float(sess[1]), at) if not sess.is_empty() else {}
	return not run.is_empty() and float(run.from) <= at and at < float(run.until)


## The + read off the clock every few seconds: whenever it rose, the player was at the
## blacksmith (the gear a card or a fight reads, not only the events).
func _sampled() -> void:
	var rises := 0
	var away := 0
	var seen := 0
	for i in [0, 9, 18]:
		var t := _t(0.0) + 600.0
		var last := -1
		var last_t := t
		while t < _t(0.0) + 8.0 * 3600.0:
			if WorldPlayers.session_at(i, t).is_empty():
				t += 60.0
				last = -1
				continue
			var g := WorldGear.gear(i, t)
			var sum := 0
			for slot in WorldGear.ENHANCE_SLOTS:
				sum += int((g[slot] as Dictionary).get("plus", 0))
			if last >= 0 and sum > last:
				rises += 1
				var a := WorldPlayers.state(i, last_t)
				var b := WorldPlayers.state(i, t)
				var at_forge := func(s: Dictionary) -> bool: return String(s.doing) == "errand" and String(s.errand) == "enhance"
				if not (at_forge.call(a) or at_forge.call(b)):
					away += 1
			seen += 1 if String(WorldPlayers.state(i, t).errand) == "enhance" else 0
			last = sum
			last_t = t
			t += 5.0
	check(rises > 3 and away == 0, "the worn + read every 5 s only rises at the blacksmith (%d rises, %d away)" % [rises, away])
	check(seen > 0, "the players are seen on their enhance errands (%d samples)" % seen)


## The world chat's forge news (ChatThreads.news: the latest enhance) tells of a + made at
## the blacksmith.
func _chat() -> void:
	var told := 0
	var right := 0
	for i in _sample().slice(0, 30):
		for k in 40:
			var n := ChatThreads.news(i, _t(0.5 + float(k) * 0.1))
			var ok: Dictionary = n.get("enhance_ok", {})
			if ok.is_empty():
				continue
			told += 1
			right += 1 if _at_forge(i, float(ok.at)) or _at_forge(i, float(ok.at) - 1.0) else 0
	check(told > 5 and right == told, "the chat's enhance news is of a + made at the blacksmith (%d / %d)" % [right, told])


## The gear's pace by work (the trips only move when the forging happens) and by real days.
func _pace() -> void:
	# As the reference was read: the world as it runs (the third festival in it).
	WorldEvents.festival_enabled = true
	WorldGear.clear()
	WorldPlayers.ensure_until(_t(20.0))
	var ps: Array[int] = []
	var n_all := WorldPlayers.size()
	for i in range(0, n_all, maxi(1, n_all / 80)):
		ps.append(i)
	for w: float in BY_WORK:
		var got := _work_sample(ps, w)
		var want: Array = BY_WORK[w]
		print("ai_forge_errand_test pace at work %.0f: + %.2f (was %.2f), set %.2f (%.2f), mount %.2f (%.2f), wings %.2f (%.2f)" % [w, got[0], want[0], got[1], want[1], got[2], want[2], got[3], want[3]])
		for k in 4:
			if float(want[k]) > 0.5:
				check(absf(float(got[k]) - float(want[k])) <= REL * float(want[k]), "the forge's pace at work %.0f stays near what it was (%s: %.2f, was %.2f)" % [w, ["+", "set", "mount", "wings"][k], got[k], want[k]])
	var hard: Array[int] = []
	for i in WorldPlayers.ROSTER.size():
		if String(WorldPlayers.entry(i).style) == "hardcore" and not WorldPlayers.entry(i).has("join"):
			hard.append(i)
		if hard.size() >= 60:
			break
	for d: float in BY_DAY:
		var plus := 0.0
		var sets := 0.0
		for i in hard:
			var g := WorldGear.gear(i, _t(d))
			for slot in WorldGear.ENHANCE_SLOTS:
				plus += float(int((g[slot] as Dictionary).get("plus", 0)))
			sets += float(g.set_pieces)
		plus /= float(hard.size())
		sets /= float(hard.size())
		var want: Array = BY_DAY[d]
		print("ai_forge_errand_test pace on day %.0f: + %.2f (was %.2f), set %.2f (%.2f)" % [d, plus, want[0], sets, want[1]])
		check(absf(plus - float(want[0])) <= REL * float(want[0]), "the + on day %.0f stays near what it was (%.2f, was %.2f)" % [d, plus, want[0]])
		# (The set pieces on their steep climb, days 5-10, a little more: one find made
		# between two trips is forged on the next stretch's.)
		if float(want[1]) > 0.5:
			check(absf(sets - float(want[1])) <= 1.5 * REL * float(want[1]), "the set pieces on day %.0f stay near what they were (%.2f, was %.2f)" % [d, sets, want[1]])
	WorldEvents.festival_enabled = false
	WorldGear.clear()


static func _work_sample(ps: Array[int], w: float) -> Array:
	var out := [0.0, 0.0, 0.0, 0.0]
	for i in ps:
		var g := WorldGear.gear_at_work(i, w)
		for slot in WorldGear.ENHANCE_SLOTS:
			out[0] += float(int((g[slot] as Dictionary).get("plus", 0)))
		out[1] += float(g.set_pieces)
		if not (g.mount as Dictionary).is_empty():
			out[2] += float(MountData.ORDER.find(String(g.mount.id)) * 10 + int(g.mount.level))
		out[3] += float(g.wings.tier)
	for k in 4:
		out[k] /= float(ps.size())
	return out


# --- The hero's party ---------------------------------------------------------------

var _party_lines: Array = []


func _on_chat(channel: String, speaker: String, text: String, _color: Color) -> void:
	if channel == "party":
		_party_lines.append([speaker, text])


## Two members whose trips come due soon, one that will come back and one that will not
## (Game.FORGE_BACK's roll), each online for a while yet: [[i, t], [i, t]] or [].
func _members_due() -> Array:
	var t := _t(1.0)
	while t < _t(5.0):
		var found := {}
		# (The fixed roster: the newcomers come and go with the roster read.)
		for i in WorldPlayers.ROSTER.size():
			if WorldPlayers.in_town_style(i) or not WorldParties.party_of(i, t).is_empty():
				continue
			var s := WorldPlayers.session_at(i, t)
			if s.is_empty() or float(s[1]) - t < 3600.0 or WorldPlayers.on_forge_trip(i, t):
				continue
			var w := WorldPlayers.work_at(i, t)
			var start := WorldGear.forge_hold(i, w)
			if start - w > 2.0 or start - w < 0.01:
				continue
			var trip := int(WorldGear.forge_trip_at(i, start)[0])
			var back := hash("forge_back|%s|%d" % [WorldPlayers.entry(i).name, trip]) % 100 < Game.FORGE_BACK
			if not found.has(back):
				found[back] = [i, t]
			if found.size() == 2:
				return [found[true], found[false]]
		t += 1800.0
	return []


func _party() -> void:
	var due := _members_due()
	check(due.size() == 2, "two world players' forge trips come due while they are online")
	if due.size() < 2:
		return
	var back_i: int = due[0][0]
	var bye_i: int = due[1][0]
	var t0: float = due[0][1]
	WorldPresence.enabled = true
	GameSettings.show_world_players = true
	GameSettings.quality = 2
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	Game.channel_chat.connect(_on_chat)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	# (The title screen puts any hero aside: the test's own hero is made once it is gone.)
	Game.new_profile(&"warrior", "ForgeQA", FaceKit.default_look())
	Game.profile.level = 30
	Game.profile.party = []
	Game.playing = true
	WorldPresence.clock_offset = t0 - WorldPlayers.now()
	await main.go(&"meadow", true)
	await get_tree().create_timer(0.5).timeout
	var ja := Game.party_invite(back_i, true)
	var jb := Game.party_invite(bye_i, true)
	check(ja == "" and jb == "", "both join the hero's party (%s %s)" % [ja, jb])
	await get_tree().create_timer(0.5).timeout
	var zone: Zone = main.zone
	check(_companion(zone, back_i) != null and _companion(zone, bye_i) != null, "both walk with the hero in the field")
	# The party's kills: its EXP carries each up to its trip's start and no further (the
	# rest is held), and no + comes of it in the party.
	var t := WorldPresence.clock()
	var before := {}
	for i in [back_i, bye_i]:
		before[i] = WorldPlayers.gear_signature(WorldPlayers.member(i, t))
		var s := WorldPlayers.state(i, t)
		for k in 60:
			WorldPlayers.add_exp(i, 50000.0, int(s.level), int(s.stars))
		check(WorldPlayers.on_forge_trip(i, t) and WorldPlayers.held_work(i) > 0.0, "%s's party EXP stops at its forge trip (the rest held: %.1f)" % [WorldPlayers.entry(i).name, WorldPlayers.held_work(i)])
		check(String(WorldPlayers.gear_signature(WorldPlayers.member(i, t))) == String(before[i]), "%s forged nothing in the party" % WorldPlayers.entry(i).name)
	_party_lines.clear()
	Game.party_refresh(t)
	await get_tree().create_timer(0.5).timeout
	# (Its schedule resumed as it left: read from then on.)
	t = WorldPresence.clock()
	for i in [back_i, bye_i]:
		var name := String(WorldPlayers.entry(i).name)
		var s := WorldPlayers.state(i, t)
		check(not Game.in_party(i) and Game.party_forge.has(i), "%s leaves the party for its forge trip" % name)
		check(_said(name, PartyTalk.FORGE_GO_LINES), "%s says in the party chat it goes to forge (%s)" % [name, _party_lines])
		check(String(s.doing) == "errand" and String(s.errand) == "enhance" and String(s.place) == "town", "%s is on its way to the blacksmith (%s %s)" % [name, s.doing, s.errand])
		check(_companion(zone, i) == null and not _shown(i), "%s is gone from the field" % name)
	check(Game.party_invite(back_i) != "", "asked again while at the blacksmith it says it is forging")
	# The village while they forge: each stands at the blacksmith.
	var run_a := WorldPlayers.errand_at(back_i, float(WorldPlayers.session_at(back_i, t)[0]), float(WorldPlayers.session_at(back_i, t)[1]), t)
	var run_b := WorldPlayers.errand_at(bye_i, float(WorldPlayers.session_at(bye_i, t)[0]), float(WorldPlayers.session_at(bye_i, t)[1]), t)
	check(not run_a.is_empty() and not run_b.is_empty() and float(run_a.until) > t + 60.0 and float(run_b.until) > t + 60.0, "the trips run for some minutes of its own play")
	if run_a.is_empty() or run_b.is_empty():
		return
	var mid := t + 50.0
	WorldPresence.clock_offset = mid - WorldPlayers.now()
	await main.go(&"town", true)
	await get_tree().create_timer(1.5).timeout
	zone = main.zone
	var forge_at := Vector3.INF
	for npc in zone.npcs:
		if "role" in npc and String(npc.role) == "forge":
			forge_at = (npc as Node3D).global_position
	for i in [back_i, bye_i]:
		var p := _runner(i)
		var name := String(WorldPlayers.entry(i).name)
		check(p != null and p.on_errand() and p.errand == "enhance", "%s is seen in the village on its forge errand" % name)
		if p != null:
			var d := Vector2(p.global_position.x - forge_at.x, p.global_position.z - forge_at.z).length()
			check(d < 6.0, "%s stands at the blacksmith (%.1f m)" % [name, d])
	# What it forged there: the + rises between the trip's start and its end, not before.
	for i in [back_i, bye_i]:
		var run := run_a if i == back_i else run_b
		var ev := WorldGear.events(i, t - 3600.0, float(run.until) + 5.0)
		var outside := ev.filter(func(e): return String(e.kind) in FORGE_KINDS and (float(e.at) < float(run.from) or float(e.at) >= float(run.until)))
		check(outside.is_empty(), "%s's forging all falls inside its trip (%d outside)" % [WorldPlayers.entry(i).name, outside.size()])
	# Done: one comes back to keep levelling, the other says goodbye (its own roll).
	var done := maxf(float(run_a.until), float(run_b.until)) + 5.0
	WorldPresence.clock_offset = done - WorldPlayers.now()
	_party_lines.clear()
	Game.party_refresh(done)
	await get_tree().create_timer(0.5).timeout
	var back_name := String(WorldPlayers.entry(back_i).name)
	var bye_name := String(WorldPlayers.entry(bye_i).name)
	check(Game.in_party(back_i) and _said(back_name, PartyTalk.FORGE_BACK_LINES), "%s comes back to the party and says so (%s)" % [back_name, _party_lines])
	check(not Game.in_party(bye_i) and _said(bye_name, PartyTalk.FORGE_BYE_LINES), "%s says goodbye and goes its own way (%s)" % [bye_name, _party_lines])
	check(Game.party_forge.is_empty(), "nobody is left waiting on a forge trip")
	var held := WorldPlayers.held_work(back_i)
	var w_back := WorldPlayers.work_at(back_i, done)
	check(held > 0.0, "the EXP held for the trip waits for the next kills (%.1f)" % held)
	var s2 := WorldPlayers.state(back_i, done)
	WorldPlayers.add_exp(back_i, 1.0, int(s2.level), int(s2.stars))
	check(WorldPlayers.work_at(back_i, done) > w_back and WorldPlayers.held_work(back_i) < held, "after the trip the held EXP is let go (up to the next trip)")
	Game.dismiss_party()
	WorldPresence.clock_offset = 0.0


func _said(name: String, pool: Array) -> bool:
	for line in _party_lines:
		if String(line[0]) == name and pool.has(String(line[1])):
			return true
	return false


func _companion(zone: Zone, i: int) -> FieldPlayer:
	for c in zone.companions:
		var p := c as FieldPlayer
		if p != null and is_instance_valid(p) and p.world_index == i and not p.is_queued_for_deletion():
			return p
	return null


func _shown(i: int) -> bool:
	return _runner(i) != null


func _runner(i: int) -> FieldPlayer:
	for node in get_tree().get_nodes_in_group("world_players"):
		var p := node as FieldPlayer
		if p != null and is_instance_valid(p) and p.world_index == i and not p.is_queued_for_deletion() and not p._leaving:
			return p
	return null
