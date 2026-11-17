class_name Announcer
extends RefCounted
## Server-wide announcements (a jackpot drop on เกาะลอยฟ้าเทพมังกร, the rare dragon): a
## banner that slides across the top of the HUD (AnnounceBanner: gold for a jackpot, jade
## for the rare dragon, queued when several arrive, with a short fanfare) and a system
## line in the world chat, for everyone playing.
##
## Who hears what:
## - broadcast(text, kind) shows it in this game. A jackpot of the hero's own
##   (SkyIsleLoot.announce) is also told to the real players online: an `announce` frame
##   (docs/ONLINE_PROTOCOL.md) that carries no text at all, only structured fields
##   {kind, what, cls, zone}; the server checks them, rate-limits them and adds the
##   sender's name itself, and every client (receive) writes the Thai text from its own
##   constants (SkyIsleLoot.announce with the item rebuilt from the fields). So the
##   channel cannot carry spam, markup or another player's words.
## - The rare dragon's coming is read off the clock by every game (tick, from the HUD
##   once a second), so nothing is relayed for it; the hero that brings it down tells the
##   server (rare_slain, the same frame with kind "rare").
## - The world players are the server for a hero playing alone: now and then one of them
##   hunting on the isle gets a jackpot (IsleLuck, read off the clock, so every device
##   and every real player sees the same ones) and it is announced the same way; the
##   others cheer in the world chat (WorldPresence takes the events with take_luck).

const KINDS := ["jackpot", "rare"]
## What an `announce` frame may name, by kind (the server keeps the same lists).
const WHATS := {"jackpot": ["", "weapon", "wings", "fragment", "egg", "chest"], "rare": ["slain"]}
const COLORS := {"jackpot": Color("ffd23a"), "rare": Color("7dffd8")}
## The world chat's speaker of a system line (as WorldPresence's server messages).
const SPEAKER := "ประกาศ"
const TEXT_MAX := 120
## The last announcements, newest last (tests and the banner's late joiners).
const LOG_MAX := 20
## A relayed announcement of one player is heard at most this often (the server's own
## limit is tighter; this holds when it is not).
const HEAR_GAP_MS := 1500
## The hero's own jackpots go out at most this often.
const SEND_GAP_MS := 1200
## tick() looks at the world players' luck only across a gap shorter than this (a game
## back from the background does not replay what it missed).
const LUCK_CATCH_UP := 90.0
const GENERIC_JACKPOT := "%s ได้รับของแจ็กพอตจาก%s!"
const RARE_HERE := "%s ปรากฏตัวที่%s! เหลือ %d นาที"
const RARE_SLAIN := "%s ปราบ%sที่%sได้แล้ว!"

## False while the announcement on its way is somebody else's (a world player's, or one
## that came over the network): it is shown here and never sent on.
static var relay := true
## false: tick() tells nothing (tests that count objects must not get a timed banner).
static var ticking := true
static var history: Array = []
static var _sinks: Array[Callable] = []
static var _heard := {}
static var _sent_at := -100000
static var _rare_told := -1
static var _luck_t := -1.0
static var _luck: Array = []
static var _names := {}


## Shows [param text] to everyone. [param kind]: "jackpot" or "rare".
static func broadcast(text: String, kind := "jackpot") -> void:
	var line := clean(text)
	if not KINDS.has(kind) or line == "":
		return
	show(line, kind)
	if relay and kind == "jackpot":
		_send_jackpot(line)


## In this game only: the banner (every listener) and the world chat's system line.
static func show(text: String, kind: String) -> void:
	history.append({"text": text, "kind": kind, "at": Time.get_ticks_msec()})
	while history.size() > LOG_MAX:
		history.pop_front()
	Game.world_chat.emit(SPEAKER, text, COLORS.get(kind, COLORS.jackpot))
	for sink in _sinks.duplicate():
		if sink.is_valid():
			sink.call(text, kind)
		else:
			_sinks.erase(sink)


## The HUD's banner listens here: sink(text, kind).
static func listen(sink: Callable) -> void:
	if not _sinks.has(sink):
		_sinks.append(sink)


static func unlisten(sink: Callable) -> void:
	_sinks.erase(sink)


## One line of plain text: no control characters, at most TEXT_MAX characters.
static func clean(text: String) -> String:
	var out := ""
	for c in text.strip_edges():
		out += " " if c.unicode_at(0) < 32 or c.unicode_at(0) == 127 else c
	return out.strip_edges().left(TEXT_MAX)


## The item an announcement's fields stand for ({} when this build has none such): the
## Dragon God weapon or wings of class `cls`, or one of the isle's stackables.
static func item_of(what: String, cls: StringName) -> Dictionary:
	var roll := RandomNumberGenerator.new()
	roll.seed = hash("announce|%s|%s" % [what, cls])
	var own: StringName = cls if ClassData.IDS.has(cls) else ClassData.IDS[0]
	match what:
		"weapon":
			return DragonGearData.weapon(own, roll)
		"wings":
			return DragonGearData.wings(own, roll)
		"fragment", "egg", "chest":
			var id: String = {"fragment": SkyIsleLoot.FRAGMENT, "egg": SkyIsleLoot.EGG, "chest": SkyIsleLoot.CHEST}[what]
			return ItemData.jewel(id) if ItemData.JEWELS.has(id) else {}
	return {}


## The fields that stand for the item an announcement's text names: {what, cls} (what ""
## when it names none this build knows).
static func describe(text: String) -> Dictionary:
	if _names.is_empty():
		for what in ["weapon", "wings"]:
			for cls in ClassData.IDS:
				var item := item_of(what, cls)
				if not item.is_empty():
					_names[ItemData.name_of(item)] = {"what": what, "cls": String(cls)}
		for what in ["fragment", "egg", "chest"]:
			var item := item_of(what, &"")
			if not item.is_empty():
				_names[ItemData.name_of(item)] = {"what": what, "cls": ""}
	var best := ""
	for name in _names:
		if String(name) != "" and text.contains(String(name)) and String(name).length() > best.length():
			best = String(name)
	return (_names[best] as Dictionary).duplicate() if best != "" else {"what": "", "cls": ""}


## The hero's own jackpot goes to the real players online, as fields only.
static func _send_jackpot(text: String) -> void:
	if not Online.is_online():
		return
	var now := Time.get_ticks_msec()
	if now - _sent_at < SEND_GAP_MS:
		return
	_sent_at = now
	var d := describe(text)
	Online.send("announce", {"kind": "jackpot", "what": String(d.what), "cls": String(d.cls), "zone": String(Online.current_zone())})


## The hero brought the rare dragon down (RareDragon.died): told here and to the server.
static func rare_slain() -> void:
	var who := String(Game.profile.get("name", "")) if Game.has_profile else ""
	show(clean(RARE_SLAIN % [who, WorldEvents.NAME_RARE, SkyIsleData.TITLE]), "rare")
	if Online.is_online():
		Online.send("announce", {"kind": "rare", "what": "slain", "cls": "", "zone": String(Online.current_zone())})


## An `announce` frame from the server {from, user, name, kind, what, cls, zone}: another
## real player's news. Only the fields are read; the text is written here.
static func receive(msg: Dictionary) -> void:
	var from := Online.id_of(msg.get("from"))
	var kind := str(msg.get("kind", ""))
	var what: Variant = msg.get("what", "")
	if from == "" or from == Online.my_id() or not WHATS.has(kind) or not what is String or not (WHATS[kind] as Array).has(what):
		return
	if StringName(str(msg.get("zone", ""))) != SkyIsleData.ID:
		return
	var now := Time.get_ticks_msec()
	if now - int(_heard.get(from, -100000)) < HEAR_GAP_MS:
		return
	if _heard.size() > 200:
		_heard.clear()
	_heard[from] = now
	var who := clean(Online.display_name({"name": msg.get("name", ""), "user": msg.get("user", "")})).replace("[", "(").replace("]", ")").left(Online.NAME_MAX)
	if who == "":
		return
	if kind == "rare":
		show(clean(RARE_SLAIN % [who, WorldEvents.NAME_RARE, SkyIsleData.TITLE]), "rare")
		return
	var item := item_of(String(what), StringName(str(msg.get("cls", ""))))
	if item.is_empty() or not SkyIsleLoot.is_jackpot(item):
		show(clean(GENERIC_JACKPOT % [who, SkyIsleData.TITLE]), "jackpot")
		return
	quietly(func(): SkyIsleLoot.announce(item, who))


## Runs `job` with the relay off: what it announces is shown here only.
static func quietly(job: Callable) -> void:
	var was := relay
	relay = false
	job.call()
	relay = was


## Once a second from the HUD (t: WorldPresence.clock()): the rare dragon's window
## opening is told to everyone, wherever the hero is, and the world players' jackpots
## (IsleLuck) that fell due since the last look.
static func tick(t: float) -> void:
	if not ticking:
		return
	var event := WorldEvents.rare_now(t)
	if not event.is_empty() and int(event.window) != _rare_told:
		_rare_told = int(event.window)
		if not WorldEvents.rare_done(int(event.window)):
			var minutes := maxi(1, int(ceil((float(event.until) - t) / 60.0)))
			show(clean(RARE_HERE % [WorldEvents.NAME_RARE, SkyIsleData.TITLE, minutes]), "rare")
	if _luck_t >= 0.0 and t > _luck_t and t - _luck_t <= LUCK_CATCH_UP:
		for e in IsleLuck.due(_luck_t, t):
			var item: Dictionary = e.item
			var who := String(e.name)
			quietly(func(): SkyIsleLoot.announce(item, who))
			_luck.append(e)
	_luck_t = t
	DragonHunt.tick(t)


## The world players' jackpots announced since the last call (WorldPresence: the others
## cheer in the world chat).
static func take_luck() -> Array:
	var out := _luck
	_luck = []
	return out


## Forgets what was told (tests, a new profile).
static func reset() -> void:
	history.clear()
	_heard.clear()
	_names.clear()
	_luck.clear()
	_sent_at = -100000
	_rare_told = -1
	_luck_t = -1.0
	relay = true
	DragonHunt.reset()
