class_name OnlineDuel
extends Node
## A duel with a real player (docs/ONLINE_PROTOCOL.md: duel_req / duel_answer / pvp_hit /
## duel_over). Lives beside the HUD for the whole session; nothing happens offline.
##
## A `duel_req` asks the hero (OnlineAsk) and answers `duel_answer`; never in town (or the
## arena, the guild war, the tower) and only when both stand in the same zone. Once
## accepted both games count 3-2-1 and draw a ring around the point between the two. Then
## the opponent's RemotePlayer carries a PvpProxy (a Mob), so the hero's attacks and
## skills hit it like the arena's Rival: every hit goes out as `pvp_hit` at the arena's
## damage scale (GuildWarData.damage_scale, as Rival.war_scale), and an incoming
## `pvp_hit` lands on the hero through Hero.take_damage (its own defence, dodge, shields)
## with BurstGuard capping it like a Rival's blow, so a duel lasts like an arena duel.
## The hero falling ends it (`duel_over {loser}`): no EXP or gold lost, no trip home, the
## hero gets up where it fell with REVIVE_HP. Ten seconds outside the ring, leaving the
## zone or the connection dropping forfeits; the opponent leaving the game is a win.
## TIME_LIMIT without a fall is a draw. Each side shows the result (banner, toast) and a
## world chat line.

signal started(opponent: String)
## {"result": "win" / "lose" / "draw" / "cancel", "opponent": id, "reason": String}
signal finished(result: Dictionary)

const ASK_SECONDS := 20.0
const COUNTDOWN := 3.0
const RING_RADIUS := 10.0
## Seconds outside the ring before the duel is forfeit.
const RING_GRACE := 10.0
const TIME_LIMIT := 180.0
const REVIVE_DELAY := 2.0
## Share of max HP the loser gets up with.
const REVIVE_HP := 0.3
## A pvp_hit above this many times the hero's max HP is junk and ignored.
const MAX_HIT_FACTOR := 5.0
const NO_DUEL_ZONES: Array[StringName] = [&"town", &"pvp", &"guildwar", &"tower"]
const RING_COLOR := Color("ffcf5a")
const LOG_COLOR := Color("ffb46a")

## True while a duel owns the hero's fall (Zone does not send it home: holds_death).
static var _holding := false

## The opponent's id ("" = no duel); state "" / "count" / "fight".
var opponent := ""
var state := ""
var asking := ""
var hero: Hero
var proxy: PvpProxy
var ring: MeshInstance3D
var center := Vector3.ZERO
var time_left := TIME_LIMIT
## Seconds the hero has been outside the ring.
var out_time := 0.0
## Tests: id -> Node3D instead of Online.remote_node, and the hero to use.
var remote_lookup := Callable()
var hero_lookup := Callable()
## Answers requests with false while this returns true (the trade sets it).
var busy_check := Callable()

var _timer := 0.0
var _count := 0
var _zone: StringName = &""
var _ask_card: Control
var _warned := -1


## Whether a duel is handling the hero's fall right now (Zone checks this).
static func holds_death() -> bool:
	return _holding


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Online.message.connect(_on_message)
	Online.disconnected.connect(func():
		_drop_ask()
		if state != "":
			Game.say("หลุดการเชื่อมต่อ — แพ้การประลองโดยปริยาย", &"warning")
			_end("lose", "disconnect", false))
	Online.player_left.connect(func(id: String):
		if id == opponent and state != "":
			_end("win", "left", false)
		elif id == asking:
			_drop_ask())


func is_active() -> bool:
	return state != ""


## Asks [param id] for a duel (the online player list does the same).
func request(id: String) -> void:
	var problem := duel_problem(id)
	if problem != "":
		Game.say(problem, &"warning")
		return
	Online.send("duel_req", {"to": id})
	Game.say("ส่งคำท้าประลองถึง %s แล้ว" % OnlineTrade.player_name(id), &"info")


func _find_hero() -> Hero:
	if hero_lookup.is_valid():
		return hero_lookup.call() as Hero
	return get_tree().get_first_node_in_group("hero") as Hero


## The opponent's RemotePlayer in this zone (or null).
func remote() -> Node3D:
	if opponent == "":
		return null
	if remote_lookup.is_valid():
		return remote_lookup.call(opponent)
	return Online.remote_node(opponent)


## Why a duel with [param id] cannot happen here and now ("" when it can).
func duel_problem(id: String) -> String:
	if not Game.has_profile or id == "":
		return "ตอนนี้ประลองไม่ได้"
	var h := _find_hero()
	if h == null or not is_instance_valid(h) or h.is_dead():
		return "ตอนนี้ประลองไม่ได้"
	if Game.current_zone == &"town" or h.safe_zone:
		return "ประลองในหมู่บ้านไม่ได้ ออกไปที่ทุ่งก่อน"
	if Game.current_zone in NO_DUEL_ZONES:
		return "ที่นี่ประลองไม่ได้"
	var p: Dictionary = Online.players().get(id, {})
	if p.is_empty() or StringName(String(p.get("zone", ""))) != Game.current_zone:
		return "ต้องอยู่พื้นที่เดียวกันจึงประลองได้"
	return ""


# ---------------------------------------------------------------------------
# Frames
# ---------------------------------------------------------------------------

func _on_message(type: String, data: Dictionary) -> void:
	var from := String(data.get("from", ""))
	match type:
		"duel_req":
			_on_request(from)
		"duel_answer":
			if not bool(data.get("ok", false)):
				Game.say("%s ไม่รับคำท้า" % OnlineTrade.player_name(from), &"warning")
			elif state == "" and duel_problem(from) == "":
				_start(from)
			elif state == "" or opponent != from:
				# Accepted, but this side can no longer fight (moved, in town): call it off.
				Online.send("duel_over", {"loser": Online.my_id(), "reason": "cancel"})
		"pvp_hit":
			if state == "fight" and from == opponent and String(data.get("to", Online.my_id())) in [Online.my_id(), ""]:
				take_pvp_hit(data.get("dmg", 0), bool(data.get("crit", false)))
		"duel_over":
			# The server names the sender as the loser; when a duelist drops, the other gets
			# a duel_over naming the dropped player.
			var loser := String(data.get("loser", from))
			if state != "" and opponent != "" and (from == opponent or loser == opponent):
				if String(data.get("reason", "")) == "cancel":
					_end("cancel", "cancel", false)
				else:
					var why := String(data.get("reason", ""))
					if why == "" and from != opponent:
						why = "disconnect"
					_end("lose" if loser == Online.my_id() else "win", why, false)


func _on_request(from: String) -> void:
	if from == "":
		return
	var problem := duel_problem(from)
	if problem == "" and (state != "" or asking != "" or (busy_check.is_valid() and bool(busy_check.call()))):
		problem = "busy"
	if problem != "":
		Online.send("duel_answer", {"from": from, "ok": false})
		if problem != "busy":
			Game.say("%s ท้าประลอง แต่%s" % [OnlineTrade.player_name(from), problem], &"info")
		return
	asking = from
	var ask := OnlineAsk.find_or_make(self)
	_ask_card = ask.ask("%s ท้าประลองกับคุณ!" % OnlineTrade.player_name(from), "รับคำท้า", "ปฏิเสธ", ASK_SECONDS, answer)


## The hero's answer to the challenge waiting (the prompt's buttons, or a timeout).
func answer(ok: bool) -> void:
	if asking == "":
		return
	var from := asking
	_drop_ask()
	ok = ok and state == "" and duel_problem(from) == ""
	Online.send("duel_answer", {"from": from, "ok": ok})
	if ok:
		_start(from)


func _drop_ask() -> void:
	asking = ""
	OnlineAsk.withdraw(_ask_card)
	_ask_card = null


# ---------------------------------------------------------------------------
# The duel
# ---------------------------------------------------------------------------

func _start(id: String) -> void:
	hero = _find_hero()
	if hero == null:
		return
	opponent = id
	state = "count"
	_timer = COUNTDOWN
	_count = int(COUNTDOWN) + 1
	_zone = Game.current_zone
	time_left = TIME_LIMIT
	out_time = 0.0
	_warned = -1
	_holding = true
	BurstGuard.forget(hero.get_instance_id())
	var other := remote()
	var at := hero.global_position
	center = (at + other.global_position) * 0.5 if other != null else at
	_make_ring()
	if not hero.died.is_connected(_on_hero_died):
		hero.died.connect(_on_hero_died)
	_banner("ประลองกับ %s" % OnlineTrade.player_name(id))
	Game.say("ประลองกับ %s — อยู่ในวงแหวน ออกนอกวง %d วินาทีถือว่าแพ้" % [OnlineTrade.player_name(id), int(RING_GRACE)], &"quest")
	started.emit(id)


func _make_ring() -> void:
	_free_ring()
	var parent: Node = hero.field if hero.field != null else hero.get_parent()
	if parent == null:
		return
	ring = MeshInstance3D.new()
	ring.name = "DuelRing"
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS - 0.18
	torus.outer_radius = RING_RADIUS + 0.18
	torus.rings = 64
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = MeshKit.toon(RING_COLOR, {"unshaded": true, "emission": 1.4})
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.0, 0.25, 1.0)
	parent.add_child(ring)
	ring.global_position = center + Vector3(0, 0.08, 0)


func _free_ring() -> void:
	if is_instance_valid(ring):
		ring.queue_free()
	ring = null


func _make_proxy() -> void:
	_free_proxy()
	var parent: Node = hero.field if hero.field != null else hero.get_parent()
	proxy = PvpProxy.new()
	proxy.setup_proxy(self, opponent, remote(), hero, Online.players().get(opponent, {}))
	proxy.name = "DuelOpponent"
	parent.add_child(proxy)
	if proxy.remote == null:
		proxy.global_position = center
	proxy.live = true
	hero.set_target(proxy)


func _free_proxy() -> void:
	if is_instance_valid(proxy):
		if is_instance_valid(hero) and hero.target == proxy:
			hero.set_target(null)
		proxy.live = false
		proxy.remove_from_group("mobs")
		proxy.queue_free()
	proxy = null


func _process(delta: float) -> void:
	if state == "":
		return
	if hero == null or not is_instance_valid(hero) or not hero.is_inside_tree() or Game.current_zone != _zone:
		# Left the zone (a warp, a town scroll): that is a forfeit.
		Online.send("duel_over", {"loser": Online.my_id(), "reason": "left"})
		_end("lose", "left", false)
		return
	match state:
		"count":
			_timer -= delta
			var shown := ceili(_timer)
			if shown < _count and shown >= 1:
				_count = shown
				_banner(str(shown))
				AudioManager.play_sfx(&"coin", -2.0)
			if _timer <= 0.0:
				state = "fight"
				_make_proxy()
				_banner("สู้!!")
				AudioManager.play_sfx(&"quest_complete", -2.0)
		"fight":
			time_left -= delta
			if time_left <= 0.0:
				_end("draw", "time", false)
				return
			var d := Vector2(hero.global_position.x - center.x, hero.global_position.z - center.z).length()
			if d > RING_RADIUS:
				out_time += delta
				var left := ceili(RING_GRACE - out_time)
				if left != _warned and left > 0:
					_warned = left
					Game.say("กลับเข้าวงแหวน! อีก %d วินาทีจะแพ้" % left, &"warning")
				if out_time >= RING_GRACE:
					Online.send("duel_over", {"loser": Online.my_id(), "reason": "ring"})
					_end("lose", "ring", false)
			else:
				out_time = 0.0
				_warned = -1


## A hit of the hero on the opponent: sent as pvp_hit at the duel's damage scale (a Thorn
## Guard reflection at half, like against a Rival). Returns the damage sent (0 = none).
func send_hit(amount: int, crit: bool, reflected := false) -> int:
	if state != "fight" or amount <= 0:
		return 0
	var scaled := int(ceil(float(amount) * GuildWarData.damage_scale * (0.5 if reflected else 1.0)))
	Online.send("pvp_hit", {"to": opponent, "dmg": scaled, "crit": crit})
	return scaled


## The opponent's hit landing on the hero: its defence and dodge (Hero.take_damage), and
## BurstGuard like a Rival's blow in the arena.
func take_pvp_hit(dmg: Variant, _crit := false) -> void:
	if not (dmg is int or dmg is float) or hero == null or not is_instance_valid(hero):
		return
	if hero.is_dead():
		return
	var max_hp := maxi(1, int(hero.stats.get("max_hp", 1)))
	var raw := clampf(float(dmg), 0.0, float(max_hp) * MAX_HIT_FACTOR)
	if raw <= 0.0:
		return
	var armour := hero.effective_def()
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, armour))))
	var allowed := BurstGuard.take(hero.get_instance_id(), amount, max_hp)
	if allowed < amount:
		raw *= float(allowed) / float(amount)
	var by: Node = proxy if is_instance_valid(proxy) else null
	if by != null:
		proxy.reflecting = true
	hero.take_damage(raw, by)
	if is_instance_valid(proxy):
		proxy.reflecting = false


func _on_hero_died() -> void:
	if state == "":
		return
	Online.send("duel_over", {"loser": Online.my_id()})
	_end("lose", "fall", true)


## Ends the duel: [param result] for this side; [param fell] the hero is down and gets up
## after REVIVE_DELAY.
func _end(result: String, reason: String, fell: bool) -> void:
	if state == "":
		return
	var id := opponent
	var who := OnlineTrade.player_name(id)
	var me := String(Game.profile.get("name", "คุณ"))
	state = ""
	opponent = ""
	_free_proxy()
	_free_ring()
	if is_instance_valid(hero):
		BurstGuard.forget(hero.get_instance_id())
		if hero.died.is_connected(_on_hero_died):
			hero.died.disconnect(_on_hero_died)
	var why := ""
	match reason:
		"ring": why = " (ออกนอกวงแหวน)"
		"left": why = " (ออกจากการประลอง)"
		"disconnect": why = " (หลุดการเชื่อมต่อ)"
	match result:
		"win":
			_banner("ชนะการประลอง!")
			Game.say("คุณชนะการประลองกับ %s%s" % [who, why], &"success")
			Game.post_chat("world", OnlineTrade.LOG_SPEAKER, "%s ชนะการประลองกับ %s%s" % [me, who, why], LOG_COLOR)
			AudioManager.play_sfx(&"quest_complete")
			if is_instance_valid(hero):
				hero.level_up_fx()
		"lose":
			_banner("พ่ายแพ้ในการประลอง")
			Game.say("คุณแพ้การประลองกับ %s%s — ไม่เสียค่าประสบการณ์" % [who, why], &"warning")
			Game.post_chat("world", OnlineTrade.LOG_SPEAKER, "%s ชนะการประลองกับ %s%s" % [who, me, why], LOG_COLOR)
		"draw":
			_banner("เสมอ!")
			Game.say("หมดเวลา — เสมอกับ %s" % who, &"info")
			Game.post_chat("world", OnlineTrade.LOG_SPEAKER, "%s กับ %s ประลองกันเสมอ" % [me, who], LOG_COLOR)
		"cancel":
			Game.say("การประลองกับ %s ถูกยกเลิก" % who, &"info")
	finished.emit({"result": result, "opponent": id, "reason": reason})
	if fell:
		_revive_later()
	else:
		_holding = false


func _revive_later() -> void:
	var h := hero
	await get_tree().create_timer(REVIVE_DELAY, true).timeout
	_holding = false
	if h == null or not is_instance_valid(h):
		return
	if Game.has_profile:
		var stats := Game.stats_now()
		Game.profile.hp = maxi(1, int(float(stats.max_hp) * REVIVE_HP))
	h.revive()


func _banner(text: String) -> void:
	var field: Node = hero.field if is_instance_valid(hero) else null
	if field != null and field.has_signal("banner_requested"):
		field.emit_signal("banner_requested", text)
