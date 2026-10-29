extends Node
## Party members talk and come along (headless): two world players in the hero's party walk
## into the village and the field with the hero (Zone._spawn_party), gather behind the hero
## when it stops in front of a villager, warn when the hero's HP drops under 35% (once: the
## rate limit holds), call the boss when one spawns (another member, the first still on its
## gap), cheer their own level-up, ask to move on when the hero stands about; every line is
## the member's bubble and a world-chat line under its name; the typed orders "รอตรงนี้",
## "ตามมา" and "กลับเมือง" are carried out (PartyTalk.command, Game.STANCE_NAMES stances).
##   godot --headless --path . res://tests/integration/party_talk_test.tscn
var failures := 0
var checks := 0
var main: Node
var chat: Array = []
var toasts: Array = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v


func _ready() -> void:
	WorldPlayers.clear_bonus()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.3)
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	Game.new_profile(&"warrior", "Talk QA", FaceKit.default_look())
	Game.profile.level = 40
	Game.profile.adv = JobData.adv_for_level(40)
	Game.profile.hp = Game.stats_now().max_hp
	Game.world_chat.connect(func(speaker: String, text: String, _c: Color): chat.append([speaker, text]))
	Game.toast.connect(func(text: String, _kind: StringName): toasts.append(text))
	# Weeks into the world, so the members have taken their jobs (below Lv.10 everyone is a Vagabond).
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 40.0 * 86400.0 - WorldPlayers.now()
	var priest := WorldPlayers.first_of(&"priest")
	var mage := WorldPlayers.first_of(&"mage")
	check(Game.party_invite(priest, true) == "" and Game.party_invite(mage, true) == "", "a priest and a mage join the party")
	main.hud.visible = true
	main._traveling = false
	await main.go(&"town", true)
	await _wait(0.6)
	await _town()
	await main.go(&"meadow", true)
	await _wait(0.6)
	await _field()
	print("PARTY TALK: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _members(zone: Zone) -> Array:
	return zone.companions.filter(func(c): return is_instance_valid(c) and c is FieldPlayer and (c as FieldPlayer).party_mode)


## In the village: the members are there, and gather behind the hero at a villager.
func _town() -> void:
	var zone: Zone = main.zone
	var hero: Hero = zone.hero
	check(zone.is_town and _members(zone).size() == 2, "both members walk into the village with the hero (%d)" % _members(zone).size())
	var talk := PartyTalk.current
	check(talk != null and is_instance_valid(talk) and talk.zone == zone, "the party's talk is attached to the village")
	check(not zone.npcs.is_empty(), "the village has villagers")
	if zone.npcs.is_empty():
		return
	var npc: Npc = zone.npcs[0]
	hero.global_position = npc.global_position + Vector3(0, 0.2, 2.0)
	hero.velocity = Vector3.ZERO
	for m in _members(zone):
		(m as FieldPlayer).global_position = hero.global_position + Vector3(3.0, 0.1, -0.6)
	await _wait(2.5)
	check(zone.current_interact.get("npc") == npc, "the hero stands in front of the villager")
	var back := _flat(hero.global_position - npc.global_position).normalized()
	for m in _members(zone):
		var p := m as FieldPlayer
		var d := _flat(p.global_position - hero.global_position)
		check(d.length() >= 1.5 and d.length() <= 3.2 and d.dot(back) > 0.5, "%s gathers 2-3 m behind the hero at the villager (%.1f m)" % [p.member.name, d.length()])
	check(talk.spoken.is_empty(), "nothing to say in the village")


## In the field: the lines by situation, the gaps, the chat and the orders.
func _field() -> void:
	var zone: Zone = main.zone
	var hero: Hero = zone.hero
	hero._invulnerable_until = Time.get_ticks_msec() + 600000
	var members := _members(zone)
	check(not zone.is_town and members.size() == 2, "both members follow the hero into the field (%d)" % members.size())
	var talk := PartyTalk.current
	check(talk != null and is_instance_valid(talk) and talk.zone == zone, "a fresh talk for the field")
	if talk == null or members.size() != 2:
		return
	for node in get_tree().get_nodes_in_group("mobs"):
		node.queue_free()
	await _wait(0.3)
	chat.clear()
	# The hero bleeding: one member says so (the priest offers to heal), once.
	var max_hp := int(hero.stats.max_hp)
	Game.profile.hp = int(max_hp * 0.2)
	await _wait(1.2)
	check(talk.spoken.size() == 1, "a member speaks up when the hero's HP drops under 35%% (%d lines)" % talk.spoken.size())
	if talk.spoken.size() >= 1:
		var first: Array = talk.spoken[0]
		var priest_said := PartyTalk.HERO_LOW_PRIEST.has(first[1])
		check(PartyTalk.HERO_LOW_LINES.has(first[1]) or priest_said, "it is a low-HP line (%s)" % first[1])
		check(priest_said and first[0] == String(Game.party()[0].name), "the priest is the one to say it, promising a heal")
		check(chat.size() == 1 and chat[0][0] == first[0] and chat[0][1] == first[1], "the line reaches the world chat under the member's name")
		var speaker: FieldPlayer = null
		for m in members:
			if String((m as FieldPlayer).member.name) == first[0]:
				speaker = m
		check(speaker != null and is_instance_valid(speaker._bubble), "the line is the member's bubble")
	await _wait(1.6)
	check(talk.spoken.size() == 1, "the rate limit holds: no second line within the window (%d)" % talk.spoken.size())
	Game.profile.hp = max_hp
	# A boss spawns: the other member (the first is on its gap) calls it, after the 4 s gap.
	var boss := Mob.new()
	boss.setup(&"mush_king", 40, hero.global_position + Vector3(6, 0, 0), hero)
	boss.position = boss.home + Vector3(0, 0.3, 0)
	zone.add_child(boss)
	check(boss.is_boss, "the mushroom king is a boss")
	await _wait(0.8)
	check(talk.spoken.size() == 1, "the boss line waits for the 4 s gap")
	await _wait(2.5)
	check(talk.spoken.size() == 2 and PartyTalk.BOSS_LINES.has(talk.spoken[1][1]), "the boss line fires when a boss spawns (%s)" % [talk.spoken])
	check(talk.spoken.size() == 2 and talk.spoken[1][0] != talk.spoken[0][0], "a different member says it: the first is still on its own gap")
	check(chat.size() == 2, "both lines are in the world chat (%d)" % chat.size())
	boss.queue_free()
	await _wait(0.3)
	# A member's level-up and the hero standing about.
	talk.reset_cooldowns()
	Game.party_leveled.emit(1, 41)
	await _wait(0.8)
	check(talk.spoken.size() == 3 and PartyTalk.LEVEL_LINES.has(talk.spoken[2][1]) and talk.spoken[2][0] == String(Game.party()[1].name), "a member cheers its own level-up (%s)" % [talk.spoken.slice(2)])
	talk.reset_cooldowns()
	hero.target = null
	talk._idle = PartyTalk.IDLE_AFTER + 1.0
	await _wait(0.8)
	check(talk.spoken.size() == 4 and PartyTalk.IDLE_LINES.has(talk.spoken[3][1]), "standing about 40 s in a field, the party asks to move on (%s)" % [talk.spoken.slice(3)])
	# Orders typed in the chat.
	check(talk.command("รอตรงนี้") and Game.party().all(func(m): return String(m.stance) == "guard"), "\"รอตรงนี้\": the members hold (stance %s)" % Game.STANCE_NAMES["guard"])
	check(members.all(func(m): return (m as FieldPlayer).hold_at.is_finite()), "they hold where they stand")
	check(PartyTalk.HOLD_LINES.has(talk.spoken[-1][1]), "and say so")
	check(PartyTalk.route("ตามมา") and Game.party().all(func(m): return String(m.stance) == "follow"), "\"ตามมา\": the members regroup (stance %s)" % Game.STANCE_NAMES["follow"])
	check(members.all(func(m): return not (m as FieldPlayer).hold_at.is_finite()), "nobody holds any more")
	toasts.clear()
	check(talk.command("กลับเมือง") and PartyTalk.HOME_LINES.has(talk.spoken[-1][1]), "\"กลับเมือง\": a member says OK")
	check(toasts.size() == 1 and toasts[0].contains("ใบวาร์ป"), "and the hero is told to use the town scroll (%s)" % [toasts])
	check(not talk.command("สวัสดีทุกคน"), "a plain line is not an order")
	check(talk.spoken.size() == 7, "every order was answered once (%d lines)" % talk.spoken.size())
