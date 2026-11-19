class_name ChatCloud
extends RefCounted
## An optional helper for the world players' small talk: the account server's Claude chat
## (hosting/worker/chat.mjs) may reword the game's own answer to an open line ("เหงาจัง",
## "ชอบเพลงอะไร"), never more. OFF by default (enabled): the game answers every line
## itself, for free (ChatBrain), and works fully without it.
##
## When it is on (the web page, an account signed in): every line is answered by the game
## first (ChatBrain.LocalTransport). Only open small talk (OPEN_TOPICS: no game facts
## asked) goes out too, at most once every MIN_GAP seconds and DAY_CAP times a Thai day
## on this device (the server keeps its own per-account limits, chat.mjs LIMITS). The
## request carries the facts that are true now (facts_for: the player's sheet, what it is
## doing, its gear, the hero, the events) and the game's own answer. The reply is shown
## only when ChatTruth.grounded holds (every claim true, every number and every game name
## one the facts hold); otherwise, or after WAIT seconds, or on any error, the game's own
## answer is shown. The action always stays the game's own.

## Off unless the owner switches it on (it costs money per message).
static var enabled := false
const MIN_GAP := 20.0
const DAY_CAP := 40
const WAIT := 8.0
## The game's answers of these topics are open small talk (ChatMind / ChatBrain topics).
const OPEN_TOPICS := ["", "sad", "tired", "happy", "love", "cute", "sorry", "laugh", "joke", "praise", "thanks", "howru", "greet"]

static var _last := -INF
static var _day := -1
static var _used := 0

var local := ChatBrain.LocalTransport.new()
## {send(json) -> int, poll(id) -> String}: AiChat.WebTransport on the web page.
var web: Object
## The clock (seconds) the waits are read on; tests move it.
var clock := func() -> float: return Time.get_ticks_msec() / 1000.0
var _jobs := {}


func send(json: String) -> int:
	var id := int(local.send(json))
	var job := {"at": float(clock.call()), "web": -1}
	var body: Variant = JSON.parse_string(json)
	if body is Dictionary and web != null and allowed(body):
		var own := ChatBrain.reply(body)
		if String(own.get("topic", "")) in OPEN_TOPICS and String(own.get("action", "none")) == "none":
			var facts := facts_for(body)
			var ask: Dictionary = (body as Dictionary).duplicate(true)
			ask["facts"] = facts
			ask["gameAnswer"] = String(own.reply)
			job["web"] = int(web.call("send", JSON.stringify(ask)))
			job["facts"] = "\n".join(facts) + "\n" + String(own.reply)
			job["body"] = body
			_spend(float(clock.call()))
	_jobs[id] = job
	return id


func poll(id: int) -> String:
	var mine := local.poll(id)
	if mine == "":
		return ""
	var job: Dictionary = _jobs.get(id, {})
	if int(job.get("web", -1)) < 0:
		_jobs.erase(id)
		return mine
	var raw := str(web.call("poll", int(job.web)))
	if (raw == "" or raw == "null") and float(clock.call()) - float(job.at) < WAIT:
		# The game's own answer waits for the cloud's a few seconds at most.
		local._answers[id] = {"json": mine, "at": 0}
		return ""
	_jobs.erase(id)
	var answer: Variant = JSON.parse_string(raw) if raw != "" and raw != "null" else null
	var own: Variant = JSON.parse_string(mine)
	if not (answer is Dictionary) or (answer as Dictionary).has("error") or not (own is Dictionary):
		return mine
	var reply := String(answer.get("reply", "")).strip_edges().left(ChatMind.MAX)
	var body: Dictionary = job.body
	var p: Dictionary = body.get("player", {})
	var ctx := {"index": int(p.get("index", -1)), "t": float(body.get("t", WorldPresence.clock())), "hero": body.get("hero", {}), "place": String(p.get("place", ""))}
	if reply == "" or not ChatTruth.grounded(reply, String(job.facts), String(body.get("text", "")), ctx):
		return mine
	own["reply"] = reply
	own["cloud"] = true
	return JSON.stringify(own)


## Whether this line may go to the cloud now (on, a direct or world line, within the
## device's gap and daily cap).
static func allowed(body: Dictionary, now := -1.0) -> bool:
	if not enabled:
		return false
	if String(body.get("channel", "direct")) not in ["direct", "world"]:
		return false
	var t := now if now >= 0.0 else Time.get_ticks_msec() / 1000.0
	if t - _last < MIN_GAP:
		return false
	var day := WorldEvents.day_of(WorldPresence.clock())
	if day != _day:
		return true
	return _used < DAY_CAP


static func _spend(now: float) -> void:
	_last = now
	var day := WorldEvents.day_of(WorldPresence.clock())
	if day != _day:
		_day = day
		_used = 0
	_used += 1


## Resets the limits (tests).
static func reset() -> void:
	_last = -INF
	_day = -1
	_used = 0


## What is true right now for the line in `body`, in plain Thai: the player's sheet, what
## it is doing and where, its gear, the hero's sheet and the events (each from the game).
static func facts_for(body: Dictionary) -> PackedStringArray:
	var p: Dictionary = body.get("player", {})
	var h: Dictionary = body.get("hero", {})
	var out := PackedStringArray()
	var lv := int(p.get("level", 1))
	var st := int(p.get("stars", 0))
	out.append("%s %s Lv.%d%s" % [String(p.get("name", "")), String(p.get("class", "")), lv, " ★%d" % st if st > 0 else ""])
	var rng := RandomNumberGenerator.new()
	out.append(ChatMind.doing_text(p, rng))
	if String(p.get("guild", "")) != "":
		out.append("อยู่กิลด์ %s" % String(p.guild))
	var mine := ChatBrain.news_of(body)
	if not mine.is_empty():
		for what in ["gear", "mount", "wings"]:
			out.append(ChatBrain.gear_answer(what, p, mine, rng))
	var hst := int(h.get("level", 1))
	out.append("ฮีโร่ %s %s Lv.%d%s" % [String(h.get("name", "")), String(h.get("class", "")), hst, " ★%d" % int(h.stars) if int(h.get("stars", 0)) > 0 else ""])
	if String(h.get("guild", "")) != "":
		out.append("ฮีโร่อยู่กิลด์ %s" % String(h.guild))
	out.append(ChatFacts.events(float(body.get("t", WorldPresence.clock()))))
	return out
