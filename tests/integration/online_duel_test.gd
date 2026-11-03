extends Node
## A duel with a real player (OnlineDuel + PvpProxy) on fake frames, no network: no
## duels in town; a duel_req asks and answers duel_answer; accepted, a 3-2-1 and a ring
## around the midpoint; the opponent's RemotePlayer carries a Mob proxy the hero's hits
## land on, each sent as pvp_hit at the arena's damage scale (others' hits ignored) with
## a hit flash on the RemotePlayer; an incoming pvp_hit hurts the hero through its own
## defence, capped by BurstGuard; the hero's fall sends duel_over, costs no gold or EXP,
## does not send it home and it gets up in place; leaving the ring 10 s, the zone or the
## connection forfeits; the opponent's forfeit, fall or drop is a win.
##   godot --headless --path . res://tests/integration/online_duel_test.tscn

class FakeSocket:
	extends RefCounted
	var sent: Array = []
	func send_text(text: String) -> void:
		sent.append(JSON.parse_string(text))
	func poll() -> Array:
		return []
	func last() -> Dictionary:
		return sent[-1] if not sent.is_empty() else {}
	func of(type: String) -> Array:
		return sent.filter(func(f): return String(f.get("t", "")) == type)


## The zone the hero stands in (only its banner signal matters here).
class Field:
	extends Node3D
	signal banner_requested(text: String)


## A RemotePlayer stand-in: in group remote_players, counts hit flashes.
class RemoteDouble:
	extends Node3D
	var player_id := ""
	var flashes := 0
	func _ready() -> void:
		add_to_group("remote_players")
	func hit_flash(_color: Color) -> void:
		flashes += 1


var checks := 0
var failures := 0
var socket := FakeSocket.new()
var field: Field
var hero: Hero
var remote: RemoteDouble
var duel: OnlineDuel
var banners: Array = []
var chat: Array = []
var results: Array = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "Duel QA", FaceKit.default_look())
	Game.profile.level = 60
	Game.profile.gold = 7777
	for slot in ItemData.SLOTS:
		Game.profile.equip[slot] = ItemData.generate(60, &"warrior", Game.rng, 2, slot)
	Game.current_zone = &"meadow"
	Game.world_chat.connect(func(speaker: String, text: String, _c: Color): chat.append("%s: %s" % [speaker, text]))
	field = Field.new()
	add_child(field)
	field.banner_requested.connect(func(t: String): banners.append(t))
	hero = Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.global_position = Vector3.ZERO
	remote = RemoteDouble.new()
	remote.player_id = "p2"
	field.add_child(remote)
	remote.global_position = Vector3(6, 0, 0)
	await _frames()
	hero.refresh_stats()
	Game.profile.hp = int(hero.stats.max_hp)
	Online.use_transport(socket)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "qa"}, "party": null, "players": [
		{"id": "p2", "user": "mali_acc", "name": "Mali", "zone": "meadow", "level": 61, "hp": 9000, "max_hp": 10000}]})
	duel = OnlineDuel.new()
	duel.hero_lookup = func(): return hero
	duel.remote_lookup = func(id: String): return remote if id == "p2" else null
	add_child(duel)
	duel.finished.connect(func(r: Dictionary): results.append(r))
	await _town()
	await _accept_and_fight()
	await _incoming()
	await _fall()
	await _forfeits()
	_offline()
	print("ONLINE DUEL: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _town() -> void:
	Game.current_zone = &"town"
	hero.safe_zone = true
	Online._dispatch({"t": "duel_req", "from": "p2"})
	check(socket.last().get("t") == "duel_answer" and socket.last().get("ok") == false and duel.asking == "", "no duels in town: declined at once")
	Game.current_zone = &"meadow"
	hero.safe_zone = false
	# Not in the same zone.
	Online._dispatch({"t": "state", "id": "p2", "zone": "forest"})
	Online._dispatch({"t": "duel_req", "from": "p2"})
	check(socket.last().get("ok") == false and not duel.is_active(), "a challenger in another zone is declined")
	Online._dispatch({"t": "state", "id": "p2", "zone": "meadow"})
	# Declined by the hero.
	Online._dispatch({"t": "duel_req", "from": "p2"})
	check(duel.asking == "p2", "a duel_req asks the hero")
	duel.answer(false)
	check(socket.last().get("t") == "duel_answer" and socket.last().get("ok") == false and not duel.is_active(), "declining sends duel_answer false")


## Accepts p2's challenge and runs the 3-2-1.
func _start_by_request() -> void:
	Online._dispatch({"t": "duel_req", "from": "p2"})
	duel.answer(true)
	duel._timer = 0.0
	await _frames(3)


func _accept_and_fight() -> void:
	Online._dispatch({"t": "duel_req", "from": "p2"})
	await _frames()
	var ask := OnlineAsk.find_or_make(self)
	check(ask.find_child("AskCard", true, false) != null, "the challenge shows a prompt card")
	duel.answer(true)
	check(socket.last().get("t") == "duel_answer" and socket.last().get("from") == "p2" and socket.last().get("ok") == true, "accepting sends duel_answer ok")
	check(duel.state == "count" and duel.opponent == "p2", "the countdown starts")
	check(is_instance_valid(duel.ring) and duel.ring.global_position.distance_to(Vector3(3, 0.08, 0)) < 0.01, "a ring around the midpoint")
	check(OnlineDuel.holds_death(), "the duel owns the hero's fall")
	await get_tree().create_timer(OnlineDuel.COUNTDOWN + 0.3).timeout
	check(banners.has("3") and banners.has("2") and banners.has("1") and banners.has("สู้!!"), "3-2-1 then สู้!! (%s)" % str(banners))
	check(duel.state == "fight" and is_instance_valid(duel.proxy), "the fight is on with a proxy")
	var proxy := duel.proxy
	check(proxy.is_in_group("mobs") and proxy is Mob, "the proxy is a Mob the hero can target")
	check(proxy.global_position.distance_to(remote.global_position) < 0.01, "the proxy rides on the RemotePlayer")
	check(hero.target == proxy, "the hero targets the opponent")
	check(proxy.hp == 9000 and proxy.max_hp == 10000, "the proxy shows the opponent's HP from its state")
	remote.global_position = Vector3(5, 0, 1)
	await _frames()
	check(proxy.global_position.distance_to(remote.global_position) < 0.01, "the proxy follows the RemotePlayer")
	# The hero's hit: out as pvp_hit, scaled like a Rival's war_scale.
	var sent := socket.sent.size()
	proxy.take_hit(100, true, Color.WHITE, hero)
	var hit := socket.last()
	check(socket.sent.size() == sent + 1 and hit.get("t") == "pvp_hit" and hit.get("to") == "p2", "a hit on the proxy sends pvp_hit")
	check(int(hit.get("dmg", 0)) == int(ceil(100.0 * GuildWarData.damage_scale)) and hit.get("crit") == true, "pvp_hit carries the scaled damage (%s)" % str(hit.get("dmg")))
	check(remote.flashes == 1, "the RemotePlayer flashes")
	check(proxy.hp == 9000 and not proxy.is_dead(), "the proxy itself loses nothing (the opponent's game does)")
	# Someone else's hit (a companion) is not the hero's duel.
	var buddy := Node3D.new()
	add_child(buddy)
	sent = socket.sent.size()
	proxy.take_hit(500, false, Color.WHITE, buddy)
	check(socket.sent.size() == sent, "a companion's hit is not sent")
	buddy.queue_free()
	# A real swing of the hero (Hero._deal) goes the same way: raw, the proxy has no defence.
	sent = socket.sent.size()
	hero._deal(proxy, 1.0, Color.WHITE, &"", false)
	var swing := socket.last()
	var top := float(hero.stats.atk) * 1.08 * HeroStats.CRIT_DAMAGE * 3.0 * GuildWarData.damage_scale
	check(socket.sent.size() == sent + 1 and swing.get("t") == "pvp_hit" and int(swing.dmg) >= int(float(hero.stats.atk) * 0.9 * GuildWarData.damage_scale) - 1 and int(swing.dmg) <= int(top), "the hero's attack lands as pvp_hit (%s, atk %s)" % [str(swing.get("dmg")), str(hero.stats.atk)])
	# The opponent's state moves the bar.
	Online._dispatch({"t": "state", "id": "p2", "hp": 4000, "max_hp": 10000})
	await _frames()
	check(proxy.hp == 4000, "the bar follows the opponent's HP")


func _incoming() -> void:
	hero.stats["dodge"] = 0.0
	BurstGuard.forget(hero.get_instance_id())
	var def := hero.effective_def()
	check(def > 0.0, "the hero has defence (%.0f)" % def)
	var max_hp := int(hero.stats.max_hp)
	Game.profile.hp = max_hp
	var dmg := 300
	var expect := maxi(1, int(round(HeroStats.mitigate(float(dmg), def))))
	Online._dispatch({"t": "pvp_hit", "from": "p2", "to": "me", "dmg": dmg, "crit": false})
	var lost := max_hp - int(Game.profile.hp)
	check(lost == expect and lost < dmg, "a pvp_hit hurts the hero through its defence (%d of %d, expected %d)" % [lost, dmg, expect])
	# A huge blow: BurstGuard caps one hit at HIT_CAP of max HP, the window at BURST_CAP.
	BurstGuard.forget(hero.get_instance_id())
	hero._invulnerable_until = 0
	Game.profile.hp = max_hp
	Online._dispatch({"t": "pvp_hit", "from": "p2", "to": "me", "dmg": max_hp * 4, "crit": true})
	lost = max_hp - int(Game.profile.hp)
	check(lost > 0 and lost <= int(max_hp * BurstGuard.HIT_CAP) + 2, "one huge pvp_hit is capped by BurstGuard (%d of %d max)" % [lost, max_hp])
	for i in 4:
		Online._dispatch({"t": "pvp_hit", "from": "p2", "to": "me", "dmg": max_hp * 4})
	lost = max_hp - int(Game.profile.hp)
	check(lost <= int(max_hp * BurstGuard.BURST_CAP) + 6, "a burst is capped too (%d)" % lost)
	# Junk or a stranger's hit does nothing.
	var hp := int(Game.profile.hp)
	Online._dispatch({"t": "pvp_hit", "from": "p3", "to": "me", "dmg": 500})
	Online._dispatch({"t": "pvp_hit", "from": "p2", "to": "me", "dmg": "lots"})
	check(int(Game.profile.hp) == hp, "hits from others or junk are ignored")


func _fall() -> void:
	BurstGuard.forget(hero.get_instance_id())
	var gold := int(Game.profile.gold)
	var exp_before := int(Game.profile.exp)
	var deaths_home := [0]
	hero.died.connect(func(): if not OnlineDuel.holds_death(): deaths_home[0] += 1)
	Game.profile.hp = 1
	Online._dispatch({"t": "pvp_hit", "from": "p2", "to": "me", "dmg": 5000})
	check(hero.is_dead(), "the hero falls")
	var over := socket.of("duel_over")
	check(not over.is_empty() and over[-1].get("loser") == "me", "the fall sends duel_over naming the hero")
	check(deaths_home[0] == 0, "the zone does not send the hero home (holds_death)")
	check(not duel.is_active() and not is_instance_valid(duel.proxy) and not is_instance_valid(duel.ring), "the duel is over: proxy and ring gone")
	check(results[-1].result == "lose", "the result is a loss")
	check(chat.any(func(l): return String(l).contains("Mali ชนะการประลองกับ Duel QA")), "a world chat line names the winner")
	await get_tree().create_timer(OnlineDuel.REVIVE_DELAY + 0.3).timeout
	check(not hero.is_dead() and int(Game.profile.hp) == maxi(1, int(Game.stats_now().max_hp * OnlineDuel.REVIVE_HP)), "the hero gets up in place with some HP (%d)" % int(Game.profile.hp))
	check(int(Game.profile.gold) == gold and int(Game.profile.exp) == exp_before, "no gold or EXP lost")
	check(not OnlineDuel.holds_death(), "afterwards a fall is a normal fall again")
	check(hero.global_position.distance_to(Vector3.ZERO) < 0.01, "where it fell")


func _forfeits() -> void:
	# Out of the ring for RING_GRACE seconds.
	await _start_by_request()
	check(duel.state == "fight", "second duel on")
	hero.global_position = duel.center + Vector3(OnlineDuel.RING_RADIUS + 3.0, 0, 0)
	await _frames()
	check(duel.state == "fight" and duel.out_time > 0.0, "outside the ring the clock runs")
	duel.out_time = OnlineDuel.RING_GRACE - 0.01
	await _frames(3)
	check(not duel.is_active() and socket.last().get("t") == "duel_over" and socket.last().get("reason") == "ring", "10 s out of the ring forfeits")
	check(results[-1].result == "lose", "the ring forfeit is a loss")
	hero.global_position = Vector3.ZERO
	# The opponent falls (its duel_over names itself).
	await _start_by_request()
	Online._dispatch({"t": "duel_over", "from": "p2", "loser": "p2"})
	check(not duel.is_active() and results[-1].result == "win", "the opponent's fall is a win")
	check(chat.any(func(l): return String(l).contains("Duel QA ชนะการประลองกับ Mali")), "the win is in the chat")
	# The opponent drops: the server sends duel_over naming it.
	await _start_by_request()
	Online._dispatch({"t": "duel_over", "loser": "p2"})
	check(not duel.is_active() and results[-1].result == "win", "the server's duel_over for a dropped opponent is a win")
	# The opponent leaves the game.
	await _start_by_request()
	Online._dispatch({"t": "leave", "id": "p2"})
	check(not duel.is_active() and results[-1].result == "win" and results[-1].reason == "left", "the opponent leaving is a win")
	Online._dispatch({"t": "join", "player": {"id": "p2", "user": "mali_acc", "name": "Mali", "zone": "meadow", "level": 61, "hp": 9000, "max_hp": 10000}})
	# My connection drops.
	await _start_by_request()
	Online.disconnected.emit()
	check(not duel.is_active() and results[-1].result == "lose", "a dropped connection forfeits")
	# A zone change.
	await _start_by_request()
	Game.current_zone = &"forest"
	await _frames()
	check(not duel.is_active() and socket.last().get("t") == "duel_over" and socket.last().get("reason") == "left", "leaving the zone forfeits")
	Game.current_zone = &"meadow"
	# My challenge accepted: the duel starts on this side too.
	duel.request("p2")
	check(socket.last().get("t") == "duel_req" and socket.last().get("to") == "p2", "a challenge sends duel_req")
	Online._dispatch({"t": "duel_answer", "from": "p2", "ok": true})
	check(duel.state == "count", "an accepted challenge starts the countdown")
	# The opponent calls it off.
	Online._dispatch({"t": "duel_over", "from": "p2", "loser": "p2", "reason": "cancel"})
	check(not duel.is_active() and results[-1].result == "cancel", "a cancelled duel has no winner")
	# Busy (trading): challenges are declined.
	duel.busy_check = func(): return true
	Online._dispatch({"t": "duel_req", "from": "p2"})
	check(socket.last().get("t") == "duel_answer" and socket.last().get("ok") == false and duel.asking == "", "a challenge while trading is declined")
	duel.busy_check = Callable()
	# The zone hook.
	check(FileAccess.get_file_as_string("res://world/zone.gd").contains("not OnlineDuel.holds_death()"), "Zone leaves a duel's fall to the duel")


func _offline() -> void:
	Online.use_transport(null)
	var sent := socket.sent.size()
	duel.request("p2")
	check(socket.sent.size() == sent and not duel.is_active(), "offline: nothing is sent")
