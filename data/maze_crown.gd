class_name MazeCrown
extends RefCounted
## หนึ่งในใต้หล้า: the weekly crown of เขาวงกตหนึ่งในใต้หล้า (MazeWar). Whoever kills the most
## there in a week (MazeWar.champion, read once the week is over) holds, from the week's
## end until the end of the following week (MazeWar.week_end(week + 1)):
## - the title "หนึ่งในใต้หล้า" (Achievements ACH_ID, a timed title: worn only while its
##   record's `until` is ahead; shown above the head grander than any other: gold, a
##   pulsing glow, a crown each side, make_plate / attach_plate),
## - the costume "เทพราชันหนึ่งในใต้หล้า" (RewardShop.COSTUMES COSTUME_ID, CostumeArt): an item
##   {kind: "costume", id, rarity, expires} whose `expires` is the crown's end. While worn
##   the costume slot keeps that end in rshop.cx. It cannot be sold, traded, set on a
##   stall or consigned (as every costume), nor put in the shared storage (deposit_lock):
##   it stays with the hero who won it.
## At or after the end (expire, from settle on load and every half minute while playing)
## the costume goes from wherever it is (bag, old storage, shared storage, costume slot,
## a stall lot), the title comes off, each with a Thai notice; the title stays earned in
## the achievements list, wearable again when the hero wins again. A second win while
## the crown is still held renews it: the same costume's `expires` and the title move on
## to the new end (never a second costume).
##
## The hero's record profile.mcrown (valid_record / repair, accounts.js validMazeCrown):
## {done: the last ended week worked out (-1 none yet), until: the title's end (unix, 0
## never), wins: weeks won, last: the last week won (-1 none)}. `done` makes settle
## idempotent across reloads: a week is granted, announced and toasted once.
##
## The holder for display (holder): the champion of the week that ended last, the hero or
## a world player (`index`); a world player who holds it wears the costume
## (RewardShop.world_cosmetics) and the title over its name (FieldPlayer, PlayerCard, the
## stall) for that week, like LegendWings' week-long pairs.

const TITLE_NAME := "หนึ่งในใต้หล้า"
const COSTUME_ID := "maze_sovereign"
const COSTUME_NAME := "เทพราชันหนึ่งในใต้หล้า"
const KEY := "mcrown"
const ACH_ID := "t_maze_crown"
const CROWN := "♛"
## The plate's gold, its dark rim and the glow round it.
const COLOR := Color("ffdc5a")
const EDGE := Color("5a2200")
const GLOW := Color(1.0, 0.58, 0.1)
const ANNOUNCE_TEXT := "%s %s ครองหนึ่งในใต้หล้าประจำสัปดาห์ด้วย %d ศพ!"
const WON_TEXT := "%s คุณครองหนึ่งในใต้หล้าประจำสัปดาห์ด้วย %d ศพ! ได้ตำแหน่ง \"%s\" และชุด%s (ใส่ให้แล้ว) ถึงสิ้นสัปดาห์หน้า"
const RENEW_TEXT := "%s ครองหนึ่งในใต้หล้าต่ออีกสัปดาห์ด้วย %d ศพ! ตำแหน่งและชุด%sต่ออายุถึงสิ้นสัปดาห์หน้า"
const LOST_TEXT := "ตำแหน่งหนึ่งในใต้หล้าส่งต่อให้ %s แล้ว (%d ศพ) — ชิงคืนได้ที่%s"
const COSTUME_GONE := "ชุด%sหมดอายุ หายไปแล้ว — ส่งต่อให้หนึ่งในใต้หล้าคนใหม่"
const TITLE_GONE := "ตำแหน่ง \"%s\" หมดอายุแล้ว — ใส่ได้อีกเมื่อครองหนึ่งในใต้หล้าอีกครั้ง"
const DEPOSIT_TEXT := "ชุด%sเป็นของผู้ครองหนึ่งในใต้หล้าคนนี้เท่านั้น ฝากคลังรวมไม่ได้"
const NOTE := "ไอเทมจำกัดเวลา: หายไปเมื่อหมดอายุ · ขาย แลกเปลี่ยน วางแผง ฝากขาย หรือฝากคลังรวมไม่ได้"
## No genuine crown ends further ahead than this (one week, and slack for a device clock
## that runs early or late): a later `expires` is forged and goes like an expired one.
## accounts.js MAZE_MAX_LIFE: keep equal.
const MAX_LIFE := 15 * 86400
## The range a saved `expires` / rshop.cx / mcrown.until may take (accounts.js: equal).
const EXPIRES_MIN := 1700000000
const EXPIRES_MAX := 4102444800
## Weeks caught up at most when the game was away (only the last ended one can still be held).
const MAX_BACK := 4
const MAX_WEEK := 100000

## Tests inject the champion of a week here (week -> {name, kills, hero, index}).
static var test_champions := {}
## The announcements made (newest last): tests and logs.
static var announced: Array[String] = []
static var _cache := {}
static var _told := {}


static func now() -> float:
	return WorldPresence.clock()


# --- Who holds it -------------------------------------------------------------------

## Week w's champion ({} until the week is over or when nobody killed): MazeWar.champion,
## cached a while (it is read by every world player's name plate).
static func champion_of(w: int) -> Dictionary:
	if test_champions.has(w):
		return (test_champions[w] as Dictionary).duplicate()
	var key := "%d|%d" % [w, Game.slot]
	var hit: Variant = _cache.get(key)
	var ms := Time.get_ticks_msec()
	if hit is Array and (not (hit[0] as Dictionary).is_empty() or ms - int(hit[1]) < 30000):
		return (hit[0] as Dictionary).duplicate()
	if _cache.size() > 64:
		_cache.clear()
	var c: Variant = MazeWar.champion(w)
	var out: Dictionary = (c as Dictionary).duplicate() if c is Dictionary else {}
	_cache[key] = [out, ms]
	return out.duplicate()


static func clear_cache() -> void:
	_cache.clear()


## The crown holder at t: the champion of the week that ended last, with `week` and
## `until` (when it passes on), {} for none.
static func holder(t := -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	var w := MazeWar.week_of(t) - 1
	var c := champion_of(w)
	if c.is_empty():
		return {}
	c["week"] = w
	c["until"] = int(MazeWar.week_end(w + 1))
	return c


## True when world player i holds the crown at t (wears the costume and the title).
static func ai_holds(i: int, t := -1.0) -> bool:
	if i < 0 or i >= WorldPlayers.size():
		return false
	var h := holder(t)
	if h.is_empty() or bool(h.get("hero", false)) or int(h.get("index", -1)) != i:
		return false
	return not h.has("name") or String(h.name) == String(WorldPlayers.entry(i).name)


## The title's end in profile p (unix, 0 never held).
static func until_of(p: Dictionary) -> int:
	var d: Variant = p.get(KEY)
	return int((d as Dictionary).get("until", 0)) if d is Dictionary else 0


## Profile p may wear the title at t (its crown has not ended).
static func title_valid(p: Dictionary, t := -1.0) -> bool:
	if t < 0.0:
		t = now()
	return _alive(until_of(p), t)


## Profile p wears the crown's title now (the grand plate over its name).
static func wears_title(p: Dictionary, t := -1.0) -> bool:
	return Achievements.title_index(p) == Achievements.index_of(ACH_ID) and title_valid(p, t)


static func _alive(expires: int, t: float) -> bool:
	return float(expires) > t and float(expires) <= t + float(MAX_LIFE)


# --- The costume item ---------------------------------------------------------------

static func is_crown_item(item: Variant) -> bool:
	return ItemData.is_costume(item) and String((item as Dictionary).get("id", "")) == COSTUME_ID


static func crown_item(expires: int) -> Dictionary:
	return RewardShop.costume_item(COSTUME_ID, expires)


## "หมดอายุใน 5 วัน 3 ชม." of an end at unix `expires`.
static func left_text(expires: int, t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var left := int(float(expires) - t)
	if left <= 0:
		return "หมดอายุแล้ว"
	var days := left / 86400
	var hours := (left % 86400) / 3600
	var mins := (left % 3600) / 60
	if days > 0:
		return "หมดอายุใน %d วัน %d ชม." % [days, hours]
	if hours > 0:
		return "หมดอายุใน %d ชม. %d นาที" % [hours, mins]
	return "หมดอายุใน %d นาที" % maxi(1, mins)


## The bag tile's short countdown ("5 วัน", "3 ชม.", "12 นาที").
static func tile_left(expires: int, t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var left := int(float(expires) - t)
	if left <= 0:
		return "หมดอายุ"
	if left >= 86400:
		return "%d วัน" % (left / 86400)
	if left >= 3600:
		return "%d ชม." % (left / 3600)
	return "%d นาที" % maxi(1, left / 60)


## Why item may not go into the shared storage ("" when it may).
static func deposit_lock(item: Variant) -> String:
	return DEPOSIT_TEXT % COSTUME_NAME if is_crown_item(item) else ""


# --- The hero's record ----------------------------------------------------------------

static func record() -> Dictionary:
	if not Game.has_profile:
		return {}
	var d: Variant = Game.profile.get(KEY)
	if not d is Dictionary:
		d = {"done": -1, "until": 0, "wins": 0, "last": -1}
		Game.profile[KEY] = d
	return d


## Works out every week ended since the last one (once each: `done`): the hero champion
## of the week that ended last gets the title and the costume until the end of the next
## week (a crown still held is renewed), the week's champion is announced, the hero hears
## it won or lost the crown; then every crown past its end goes (expire). Team maze calls
## it on load and at each week boundary; Game calls it on load and twice a minute too.
static func settle(t := -1.0) -> void:
	if not Game.has_profile:
		return
	if t < 0.0:
		t = now()
	var d := record()
	var last := MazeWar.week_of(t) - 1
	var done := int(d.get("done", -1))
	if done < last:
		var from := last if done < 0 else maxi(done + 1, last - MAX_BACK + 1)
		for w in range(from, last + 1):
			var c := champion_of(w)
			if c.is_empty():
				continue
			var ends := int(MazeWar.week_end(w + 1))
			var held_before := int(d.get("last", -1)) == w - 1 and _alive(int(d.get("until", 0)), t)
			if bool(c.get("hero", false)):
				d["wins"] = mini(int(d.get("wins", 0)) + 1, MAX_WEEK)
				d["last"] = w
				if float(ends) > t:
					_grant(c, ends, held_before, t)
			elif held_before and w == last:
				Game.say(LOST_TEXT % [String(c.get("name", "?")), int(c.get("kills", 0)), MazeWar.TITLE], &"warning")
			if w == last:
				_announce(w, c)
		d["done"] = last
		Game.mark_dirty()
	expire(t)


static func _grant(c: Dictionary, ends: int, renew: bool, t: float) -> void:
	var d := record()
	d["until"] = maxi(int(d.get("until", 0)), ends) if _alive(int(d.get("until", 0)), t) else ends
	if not Game.profile.get("ach") is Dictionary:
		Game.profile["ach"] = {}
	Game.profile.ach[ACH_ID] = true
	if not Game.profile.get("flags") is Dictionary:
		Game.profile["flags"] = {}
	Game.profile.flags[Achievements.TITLE_FLAG] = Achievements.index_of(ACH_ID)
	if not _renew_costume(ends, t):
		RewardShop.give_worn(crown_item(ends))
	var kills := int(c.get("kills", 0))
	Game.say((RENEW_TEXT % [CROWN, kills, COSTUME_NAME]) if renew else (WON_TEXT % [CROWN, kills, TITLE_NAME, COSTUME_NAME]), &"success")
	Game.mark_dirty()
	Game.title_changed.emit(Achievements.title_of(Game.profile))


## Moves the end of the costume the hero already has (worn, bag, old storage, shared
## storage) on to `ends`; a second copy anywhere goes. False when there is none.
static func _renew_costume(ends: int, t: float) -> bool:
	var found := false
	var shop: Variant = Game.profile.get(RewardShop.KEY)
	if shop is Dictionary and String((shop as Dictionary).get("cos", "")) == COSTUME_ID:
		shop["cx"] = maxi(int(shop.get("cx", 0)), ends) if _alive(int(shop.get("cx", 0)), t) else ends
		found = true
	var shared_changed := false
	for list_ref in _lists():
		var list: Array = list_ref[0]
		for i in range(list.size() - 1, -1, -1):
			if not is_crown_item(list[i]):
				continue
			if found:
				list.remove_at(i)
			else:
				var item: Dictionary = list[i]
				item["expires"] = maxi(int(item.get("expires", 0)), ends) if _alive(int(item.get("expires", 0)), t) else ends
				found = true
			shared_changed = shared_changed or bool(list_ref[1])
	if shared_changed:
		SharedStorage.store()
	if found:
		Game.inventory_changed.emit()
		Game.cosmetics_changed.emit()
	return found


## [list, is the shared storage] of every place an item of the hero can lie.
static func _lists() -> Array:
	var out: Array = []
	if Game.profile.get("inv") is Array:
		out.append([Game.profile.inv, false])
	if Game.profile.get("storage") is Array:
		out.append([Game.profile.storage, false])
	out.append([SharedStorage.items(), true])
	return out


## Takes every crown past its end (or forged further ahead than MAX_LIFE) from wherever
## it is, and the title off once its end has passed, each with a notice. The number of
## costumes taken.
static func expire(t := -1.0) -> int:
	if not Game.has_profile:
		return 0
	if t < 0.0:
		t = now()
	var removed := 0
	var shared := 0
	for list_ref in _lists():
		var list: Array = list_ref[0]
		for i in range(list.size() - 1, -1, -1):
			if is_crown_item(list[i]) and not _alive(int((list[i] as Dictionary).get("expires", 0)), t):
				list.remove_at(i)
				removed += 1
				if bool(list_ref[1]):
					shared += 1
	var stall: Variant = Game.profile.get("stall")
	if stall is Dictionary and (stall as Dictionary).get("lots") is Array:
		var lots: Array = stall.lots
		for i in range(lots.size() - 1, -1, -1):
			if lots[i] is Dictionary and is_crown_item((lots[i] as Dictionary).get("item")):
				lots.remove_at(i)
				removed += 1
	var shop: Variant = Game.profile.get(RewardShop.KEY)
	var worn_gone := false
	if shop is Dictionary and String((shop as Dictionary).get("cos", "")) == COSTUME_ID and not _alive(int(shop.get("cx", 0)), t):
		shop["cos"] = ""
		shop.erase("cx")
		removed += 1
		worn_gone = true
	if shared > 0:
		SharedStorage.store()
	var title_gone := false
	if Achievements.title_index(Game.profile) == Achievements.index_of(ACH_ID) and not title_valid(Game.profile, t):
		(Game.profile.flags as Dictionary).erase(Achievements.TITLE_FLAG)
		title_gone = true
	if removed > 0:
		Game.say(COSTUME_GONE % COSTUME_NAME, &"warning")
		Game.inventory_changed.emit()
		if worn_gone:
			Game.profile_changed.emit()
			Game.cosmetics_changed.emit()
	if title_gone:
		Game.say(TITLE_GONE % TITLE_NAME, &"warning")
		Game.title_changed.emit(Achievements.title_of(Game.profile))
	if removed > 0 or title_gone:
		Game.mark_dirty()
	return removed


## The week's champion for everyone playing: a banner and the world chat, once a week a
## session (every character of the account shares one announcement).
static func _announce(w: int, c: Dictionary) -> void:
	if _told.has(w):
		return
	_told[w] = true
	var who := String(c.get("name", "?"))
	if bool(c.get("hero", false)) and Game.has_profile:
		who = String(Game.profile.get("name", who))
	var text := ANNOUNCE_TEXT % [CROWN, who, int(c.get("kills", 0))]
	announced.append(text)
	if announced.size() > 16:
		announced.pop_front()
	Announcer.broadcast(text, "crown")


static func reset_session() -> void:
	_told.clear()
	announced.clear()
	_cache.clear()


# --- The grand title plate -------------------------------------------------------------

## The crown title over a name plate (Label3D `label`), shown or taken away. Sits just
## above the label's top line (its text decides how many lines there are), billboarded,
## gold with a dark rim on two pulsing glow rims: no light, no particle, one tween.
static func attach_plate(label: Label3D, on: bool) -> void:
	if not is_instance_valid(label):
		return
	var plate := label.get_node_or_null("CrownPlate") as Node3D
	if not on:
		if plate != null:
			plate.queue_free()
			label.remove_child(plate)
		return
	if plate == null:
		plate = make_plate(label.pixel_size, label.visibility_range_end)
		label.add_child(plate)
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var lines := label.text.count("\n") + 1
	var line_h := (font.get_height(label.font_size) + label.line_spacing) * label.pixel_size
	var own_h := font.get_height(PLATE_FONT) * label.pixel_size * PLATE_SCALE
	plate.position = Vector3(0, float(lines) * line_h * 0.5 + own_h * 0.5 + 0.02, 0)


const PLATE_FONT := 40
const PLATE_SCALE := 1.15


## The plate node: "♛ หนึ่งในใต้หล้า ♛" in gold over two glow rims that breathe.
static func make_plate(pixel_size := 0.0034, range_end := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "CrownPlate"
	var text := "%s %s %s" % [CROWN, TITLE_NAME, CROWN]
	var rims: Array[Label3D] = []
	for spec in [[30, 0.16], [18, 0.34]]:
		var rim := _plate_label(text, pixel_size, range_end)
		rim.modulate = Color(GLOW, 0.0)
		rim.outline_size = int(spec[0])
		rim.outline_modulate = Color(GLOW, float(spec[1]))
		rim.render_priority = 3
		rim.outline_render_priority = 2
		root.add_child(rim)
		rims.append(rim)
	var face := _plate_label(text, pixel_size, range_end)
	face.name = "CrownTitle"
	face.modulate = COLOR
	face.outline_size = 9
	face.outline_modulate = EDGE
	face.render_priority = 5
	face.outline_render_priority = 4
	root.add_child(face)
	root.set_meta("crown_text", text)
	# The rims breathe (one looping tween, started once the plate is in the tree).
	root.tree_entered.connect(func():
		var tw := root.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		var lo := [rims[0].outline_modulate.a, rims[1].outline_modulate.a]
		tw.tween_property(rims[0], "outline_modulate:a", minf(float(lo[0]) * 2.0, 1.0), 1.2)
		tw.parallel().tween_property(rims[1], "outline_modulate:a", minf(float(lo[1]) * 1.8, 1.0), 1.2)
		tw.tween_property(rims[0], "outline_modulate:a", float(lo[0]), 1.2)
		tw.parallel().tween_property(rims[1], "outline_modulate:a", float(lo[1]), 1.2),
		CONNECT_ONE_SHOT)
	return root


static func _plate_label(text: String, pixel_size: float, range_end: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = pixel_size * PLATE_SCALE
	l.font_size = PLATE_FONT
	l.no_depth_test = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		l.visibility_range_end = range_end
	return l


# --- The save ---------------------------------------------------------------------------

## profile.mcrown is well formed.
static func valid_record(v: Variant) -> bool:
	if not v is Dictionary or (v as Dictionary).size() > 4:
		return false
	for k in v:
		match str(k):
			"done", "last":
				if not Game._valid_integer(v[k], -1, MAX_WEEK):
					return false
			"wins":
				if not Game._valid_integer(v[k], 0, MAX_WEEK):
					return false
			"until":
				if not Game._valid_integer(v[k], 0, EXPIRES_MAX) or (int(v[k]) != 0 and int(v[k]) < EXPIRES_MIN):
					return false
			_:
				return false
	return true


## A costume item's `expires`: only the crown costume carries one, and it always does.
static func valid_expires(item: Dictionary) -> bool:
	if String(item.get("id", "")) != COSTUME_ID:
		return not item.has("expires")
	return Game._valid_integer(item.get("expires"), EXPIRES_MIN, EXPIRES_MAX)


## Numbers back to ints (JSON reads them as floats); a broken record goes.
static func repair(profile: Dictionary) -> void:
	if not profile.has(KEY):
		return
	if not valid_record(profile[KEY]):
		profile.erase(KEY)
		return
	var d: Dictionary = profile[KEY]
	for key in d:
		d[key] = int(d[key])
