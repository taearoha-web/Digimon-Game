extends Node
## One guild leader an account (หัวหน้ากิลด์ของบัญชี): two characters (save slots) in one
## guild. The first leads and earns the Legendary Guild Wings; switching to the second
## keeps the first as leader (never the one played, never the AI) and the pair on the
## first; a season closed while the second is played is the leader's, not the AI's nor
## the one played; the second takes the lead only with รับตำแหน่งหัวหน้ากิลด์ and its
## confirm, the first then a member, the wings still the first's. Old saves (every
## character thinking it led, a record naming the one played for another's pair, the AI
## leading a guild the one played is not in) are settled on load, once.
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --audio-driver Dummy --path . res://tests/integration/account_guild_test.tscn
var failures := 0
var checks := 0
var awarded: Array = []
const W0 := LegendWings.FROM_WEEK + 2
const A := 1
const B := 2
const A_NAME := "หัวหน้าตัวจริง"
const B_NAME := "ตัวรอง"


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func pin(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	GameSettings.load_settings()
	WorldEvents.festival_enabled = false
	WorldPlayers.clear_bonus()
	Game.legend_wings_awarded.connect(func(item: Dictionary, _text: String): awarded.append(item))
	_reset()
	_leader_earns_wings()
	_switch_keeps_leader()
	_season_while_other_played()
	_back_to_leader()
	await _take_leadership()
	_old_saves()
	WorldPresence.clock_offset = 0.0
	Game.has_profile = false
	print("ACCOUNT GUILD: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _reset() -> void:
	Game.has_profile = false
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	SharedStorage.items().clear()
	SharedStorage.migrated().clear()
	SharedStorage.store()
	Game.slot = 1
	awarded.clear()


func _hero(for_slot: int, hero_name: String, cls: StringName, stars: int) -> void:
	Game.slot = for_slot
	Game.new_profile(cls, hero_name, FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.paragon()["level"] = stars


## Guild g wins every round of season w on the played hero's record.
func _crown(g: int, w: int) -> void:
	pin(GuildLeague.week_start(w) + 3600.0)
	var others: Array = []
	for other in WorldPlayers.GUILDS:
		if other != g:
			others.append(other)
	for r in GuildLeague.schedule(w):
		GuildLeague.record_round([g] + others, [6, 0, 0, 0], [120, 10, 10, 10], 0, float(r.at), g)
	pin(GuildLeague.week_end(w) + 60.0)


## Every pair of a profile (bag, worn, old storage).
static func _pairs_of(p: Dictionary) -> Array:
	var out: Array = []
	for piece in (p.get("inv", []) as Array) + (p.get("storage", []) as Array) + (p.get("equip", {}) as Dictionary).values():
		if LegendWings.is_item(piece):
			out.append(piece)
	return out


func _file(for_slot: int) -> Dictionary:
	return Game._read_slot(for_slot)


func _no_ai_leads(g: int, why: String) -> void:
	var lead := Game.guild_leader_of(g)
	check(String(lead.kind) != "member" and String(lead.kind) != "none", "%s: no world player (AI) leads %s (%s)" % [why, WorldPlayers.guild_name(g), lead])


## Slot A leads Alpha (it joined first) and the season's close gives it the pair.
func _leader_earns_wings() -> void:
	var alpha := WorldPlayers.ALPHA
	_hero(A, A_NAME, &"warrior", 200)
	check(Game.join_guild(alpha) and Game.hero_leads_guild(alpha), "A joins Alpha and leads it")
	_crown(alpha, W0)
	check(LegendWings.tick(), "the season's close mints the pair")
	var worn: Variant = Game.profile.equip.get("wings")
	check(LegendWings.is_item(worn) and int(worn.legend_week) == W0, "A wears season %d's Legendary Guild Wings" % W0)
	check(awarded.size() == 1, "A got the award once")
	check(Game.save(), "A is saved")


## B joins Alpha after A: A keeps the seat (B does not take it by joining, nor by being played).
func _switch_keeps_leader() -> void:
	var alpha := WorldPlayers.ALPHA
	_hero(B, B_NAME, &"mage", 50)
	check(Game.join_guild(alpha) and Game.guild() == alpha, "B joins Alpha")
	var lead := Game.guild_leader_of(alpha)
	check(String(lead.kind) == "alt" and int(lead.get("slot", 0)) == A and String(lead.name) == A_NAME, "played, B sees A as Alpha's leader (%s)" % [lead])
	check(not Game.hero_leads_guild(alpha), "B does not lead Alpha by joining")
	_no_ai_leads(alpha, "B played")
	check(Game.guild_war_alt_leader(alpha) == A and Game.guild_war_leader(alpha) == A_NAME, "A leads Alpha in the guild war (played by the AI as A, not a world player)")
	check(Game.guild_leader_label(alpha).contains(A_NAME), "the leader line names A (%s)" % Game.guild_leader_label(alpha))
	check(_pairs_of(Game.profile).is_empty(), "B has no Legendary Guild Wings")
	var a_file := _file(A)
	check(_pairs_of(a_file).size() == 1 and LegendWings.is_item((a_file.equip as Dictionary).get("wings")), "A's save still wears its pair")
	check(String((a_file.get("guild_leaders", {}) as Dictionary).get(str(alpha), "x")) == "", "A's save still says A leads")
	check(Game.save(), "B is saved")
	check(Game.load_game(A) and Game.hero_leads_guild(alpha), "switching to A: A leads")
	check(Game.load_game(B) and String(Game.guild_leader_of(alpha).kind) == "alt" and not Game.hero_leads_guild(alpha), "switching back to B: still A leads")
	check(_pairs_of(Game.profile).is_empty() and _pairs_of(_file(A)).size() == 1, "after the switches the pair is still A's only")


## A season Alpha wins while B is played: the pair is the leader A's, recorded so; B gets
## none and no world player wears it.
func _season_while_other_played() -> void:
	var alpha := WorldPlayers.ALPHA
	awarded.clear()
	_crown(alpha, W0 + 1)
	LegendWings.tick()
	var h := LegendWings.hold_of(W0 + 1)
	check(int(h.get("g", 0)) == alpha and String(h.get("n", "")) == Game.alt_pick(A), "B's record gives season %d to A (%s)" % [W0 + 1, h])
	check(awarded.is_empty() and _pairs_of(Game.profile).is_empty(), "B was not given the leader's pair")
	var ai := 0
	for i in WorldPlayers.size():
		if LegendWings.ai_holds(i) and int(LegendWings.ai_item(i).get("legend_week", 0)) == W0 + 1:
			ai += 1
	check(ai == 0, "no world player wears season %d's pair" % (W0 + 1))
	check(LegendWings.holder_label(h).contains(A_NAME), "the holder reads as A (%s)" % LegendWings.holder_label(h))
	check(Game._valid_profile(Game.profile.duplicate(true)) and Game.save(), "B saves with that record")


func _back_to_leader() -> void:
	var alpha := WorldPlayers.ALPHA
	check(Game.load_game(A), "switch to A")
	check(Game.hero_leads_guild(alpha) and Game.guild_alts(alpha).size() == 1, "A leads, B listed as its other character")
	check(LegendWings.is_item(Game.profile.equip.get("wings")) and int(Game.profile.equip.wings.legend_week) == W0, "A still wears its pair")
	check(LegendWings.hold_of(W0).get("n", "x") == "", "A's record names A for its pair")
	check(Game.load_game(B), "switch to B")


func _labels(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		_labels(child, out)


## B takes the lead in the guild screen (asked first); A is a member, its pair stays.
func _take_leadership() -> void:
	var alpha := WorldPlayers.ALPHA
	var screen := GuildScreen.new()
	add_child(screen)
	await _frames(1)
	screen.open_roster()
	await _frames(2)
	var take := screen.find_child("TakeLeaderAlpha", true, false) as Button
	check(take != null and take.text == "รับตำแหน่งหัวหน้ากิลด์" and not take.disabled, "B's guild screen offers รับตำแหน่งหัวหน้ากิลด์")
	check(screen.find_child("TakeLeaderNeverdie", true, false) == null, "not for a guild B is not in")
	if take == null:
		screen.queue_free()
		return
	# Cancel first: nothing changes.
	take.pressed.emit()
	await _frames(2)
	var sheet := screen.find_child("TakeLeaderConfirm", true, false)
	check(sheet != null, "it asks to confirm")
	var texts: Array[String] = []
	if sheet != null:
		_labels(sheet, texts)
	check(texts.any(func(x: String): return x.contains(A_NAME) and x.contains("หัวหน้ากิลด์")), "the confirm names the current leader A")
	var no := screen.find_child("CancelTakeLeader", true, false) as Button
	if no != null:
		no.pressed.emit()
	await _frames(2)
	check(String(Game.guild_leader_of(alpha).kind) == "alt" and not Game.hero_leads_guild(alpha), "cancel: A still leads")
	take = screen.find_child("TakeLeaderAlpha", true, false) as Button
	if take != null:
		take.pressed.emit()
	await _frames(2)
	var yes := screen.find_child("ConfirmTakeLeader", true, false) as Button
	check(yes != null, "the confirm button is there")
	if yes != null:
		yes.pressed.emit()
	await _frames(3)
	check(Game.hero_leads_guild(alpha) and String(Game.guild_leader_of(alpha).kind) == "hero", "confirmed: B leads Alpha")
	var a_file := _file(A)
	check(String((a_file.get("guild_leaders", {}) as Dictionary).get(str(alpha), "")) == Game.alt_pick(B), "A's save now says B leads (%s)" % [a_file.get("guild_leaders")])
	check(_pairs_of(a_file).size() == 1 and _pairs_of(Game.profile).is_empty(), "the pair is still A's, B has none")
	var take2 := screen.find_child("TakeLeaderAlpha", true, false)
	check(take2 == null or take2.is_queued_for_deletion(), "the button is gone once B leads")
	check(not Game.take_guild_leadership(), "taking it again does nothing")
	screen.close_screen()
	screen.queue_free()
	await _frames(2)
	get_tree().paused = false
	check(Game.save(), "B saved as leader")
	check(Game.load_game(A), "switch to A")
	var lead := Game.guild_leader_of(alpha)
	check(not Game.hero_leads_guild(alpha) and String(lead.kind) == "alt" and int(lead.slot) == B, "A is a member now, B leads (%s)" % [lead])
	check(LegendWings.is_item(Game.profile.equip.get("wings")), "A still wears the Legendary Guild Wings")
	check(Game.load_game(B) and Game.hero_leads_guild(alpha), "and B, played again, still leads")


## Saves written before: both thought they led, B's record named B for A's pair; and B
## in another guild saw the AI lead Alpha. A load settles them, once.
func _old_saves() -> void:
	var alpha := WorldPlayers.ALPHA
	var never := WorldPlayers.NEVERDIE
	# Both claim Alpha, B's record names itself for A's pair.
	var a_raw: Dictionary = Game._read_slot_json(A)
	a_raw["guild_leaders"] = {str(alpha): ""}
	Game._write_profile(a_raw, A)
	Game.profile["guild_leaders"] = {str(alpha): ""}
	var hold: Dictionary = LegendWings.record().hold
	hold[str(W0)] = {"g": alpha, "n": "", "s": 1}
	check(Game.save(), "B saved as an old game would")
	check(Game.load_game(B), "B loaded")
	var lead := Game.guild_leader_of(alpha)
	check(String(lead.kind) == "alt" and int(lead.get("slot", 0)) == A, "old saves: the one holding Alpha's wings (A) leads, not the one played (%s)" % [lead])
	check(String(LegendWings.hold_of(W0).get("n", "")) == Game.alt_pick(A), "old record: A's pair is named A's (%s)" % [LegendWings.hold_of(W0)])
	check(String((_file(B).get("guild_leaders", {}) as Dictionary).get(str(alpha), "")) == Game.alt_pick(A), "written at once")
	var before_a := FileAccess.get_file_as_string(Game.save_path(A))
	var before_b := FileAccess.get_file_as_string(Game.save_path(B))
	check(Game.load_game(B) and FileAccess.get_file_as_string(Game.save_path(A)) == before_a and JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(B))).get("guild_leaders") == JSON.parse_string(before_b).get("guild_leaders"), "a second load changes nothing")
	# B in Neverdie with an old record: the old game let Alpha's strongest world player lead.
	Game.profile.flags[Game.GUILD_FLAG] = never
	Game.profile["guild_leaders"] = {str(never): ""}
	check(Game.guild_leader_of(alpha).kind == "member", "an old record: the AI leads Alpha from B's side (as before)")
	check(Game.save() and Game.load_game(B), "B reloaded")
	lead = Game.guild_leader_of(alpha)
	check(String(lead.kind) == "alt" and int(lead.get("slot", 0)) == A, "settled: A leads Alpha while B (Neverdie) is played (%s)" % [lead])
	check(Game.hero_leads_guild(never), "and B leads its own Neverdie")
	check(Game.load_game(A) and Game.hero_leads_guild(alpha) and LegendWings.is_item(Game.profile.equip.get("wings")), "A, played, leads Alpha and wears its pair")
