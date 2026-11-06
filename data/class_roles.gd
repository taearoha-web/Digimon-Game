class_name ClassRoles
extends RefCounted
## Party roles: every class carries ONE trait that helps its whole party (itself included)
## in a way no other class does, so a party wants one of each. A trait counts once per
## party however many of that class are in it (two Warriors do not double it) and only
## while a member of that class is alive.
##
## Who is a party: outside a guild war the hero and its companions (group "companions");
## in a guild war the party GuildWarMatch.party_of gives (the same reach as buffs,
## GuildWarMatch.buff_reaches); a fighter or rival outside a war is a party of one.
##
## The hooks (the hero, companions, rivals and guild fighters call them):
##   outgoing(attacker, target)   damage multiplier of a hit (Warrior, Mage mark, Assassin)
##   crit_bonus(attacker)         added crit chance (Archer)
##   pierce(attacker)             share of the target's DEF ignored (Lancer)
##   taken(victim)                damage taken multiplier (Defender)
##   after_hit(attacker, target, dealt)  Mage mark, Dark Lord lifesteal
##   cd_rate(unit)                cooldown speed (Bard)
##   regen(unit, delta)           HP (Priest) and MP (Summoner) over time

## The traits. "value" is the number the effect uses; "text" its short Thai line.
const TRAITS := {
	&"warrior": {"name": "แนวหน้า", "value": 0.08,
		"text": "ทั้งปาร์ตี้ทำดาเมจ +8%"},
	&"defender": {"name": "กำแพงเหล็ก", "value": 0.10,
		"text": "ทั้งปาร์ตี้รับดาเมจ -10%"},
	&"priest": {"name": "พรแห่งแสง", "value": 0.005,
		"text": "ทั้งปาร์ตี้ฟื้น HP 0.5%/วิ แม้กำลังสู้"},
	&"mage": {"name": "ตราเวท", "value": 0.10, "secs": 6.0,
		"text": "ศัตรูที่โดนเวทนักเวทย์ รับดาเมจจากปาร์ตี้ +10% (6 วิ)"},
	&"archer": {"name": "ตาเหยี่ยว", "value": 0.08,
		"text": "ทั้งปาร์ตี้คริติคอล +8%"},
	&"assassin": {"name": "จุดตาย", "value": 0.12, "below": 0.35,
		"text": "ทั้งปาร์ตี้ตีศัตรูที่ HP ต่ำกว่า 35% แรงขึ้น 12%"},
	&"lancer": {"name": "ทะลวงเกราะ", "value": 0.10,
		"text": "ทั้งปาร์ตี้เจาะเกราะศัตรู 10%"},
	&"summoner": {"name": "พันธะวิญญาณ", "value": 0.006,
		"text": "ทั้งปาร์ตี้ฟื้น MP +0.6%/วิ"},
	&"darklord": {"name": "เงามืด", "value": 0.04,
		"text": "ทั้งปาร์ตี้ดูดเลือด 4% ของดาเมจที่ทำ"},
	&"bard": {"name": "ประสานเสียง", "value": 0.10,
		"text": "ทั้งปาร์ตี้คูลดาวน์สกิลสั้นลง 10%"},
}

## The Mage's mark on a target: meta {party key: until (ms)}.
const MARK_META := &"role_arcane"

## Off only in tests that measure a skill's own numbers (armageddon_test).
static var enabled := true
static var _stamp := -1
static var _cache := {} # party key -> {class: true}


## The trait of a class ({} for the Vagabond).
static func trait_of(cls: StringName) -> Dictionary:
	return TRAITS.get(cls, {})


## "แนวหน้า: ทั้งปาร์ตี้ทำดาเมจ +8%" (empty for a class without one).
static func line(cls: StringName) -> String:
	var t := trait_of(cls)
	return "" if t.is_empty() else "%s: %s" % [t.name, t.text]


## The tooltip of a party member's card: its class and its party role.
static func tooltip(cls: StringName) -> String:
	var t := trait_of(cls)
	if t.is_empty():
		return ""
	return "%s\nบทบาทในปาร์ตี้ — %s" % [String(ClassData.get_class_data(cls).name), line(cls)]


## The roles a party of [param classes] brings, each once, and how many are missing:
## "บทบาทในปาร์ตี้: แนวหน้า · ตราเวท (ขาดอีก 8 บทบาท)".
static func summary(classes: Array) -> String:
	var names: PackedStringArray = []
	var seen := {}
	for cls in classes:
		var id := StringName(cls)
		if TRAITS.has(id) and not seen.has(id):
			seen[id] = true
			names.append(String(TRAITS[id].name))
	if names.is_empty():
		return ""
	var missing := TRAITS.size() - names.size()
	return "บทบาทในปาร์ตี้: %s%s" % [" · ".join(names), (" (ขาดอีก %d บทบาท — อาชีพซ้ำไม่ทบกัน)" % missing) if missing > 0 else " (ครบทุกบทบาท!)"]


## Forget the cached parties (they are rebuilt once a frame anyway).
static func invalidate() -> void:
	_stamp = -1
	_cache.clear()


# ---------------------------------------------------------------------------
# Parties
# ---------------------------------------------------------------------------

## The class of a body ("" for monsters and anything else).
static func class_of(unit: Variant) -> StringName:
	if unit == null or not is_instance_valid(unit):
		return &""
	if unit is Hero:
		return Game.class_id()
	if (unit is Companion or unit is Rival) and (unit.member is Dictionary) and unit.member.has("class"):
		return StringName(unit.member["class"])
	return &""


## The party a body counts in: "" for none (monsters, summons, world players).
static func party_key(unit: Variant) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	if not (unit is Hero or unit is Companion or unit is Rival):
		return ""
	if GuildWarMatch.in_war():
		var p := GuildWarMatch.HERO_PARTY if unit is Companion else GuildWarMatch.party_of(unit)
		if p >= 0:
			return "w%d" % p
		return "u%d" % unit.get_instance_id() if unit is Rival else ""
	if unit is Hero:
		return "hero"
	if unit is Companion:
		return "hero" if (unit as Node).is_in_group("companions") else ""
	return "u%d" % unit.get_instance_id()


static func _alive(node: Variant) -> bool:
	return node != null and is_instance_valid(node) and node.is_inside_tree() and node.has_method("is_dead") and not node.is_dead()


## The classes alive in [param unit]'s party, each once: {class: true}.
static func party_classes(unit: Variant) -> Dictionary:
	if not enabled:
		return {}
	var key := party_key(unit)
	if key == "":
		return {}
	var stamp := Engine.get_process_frames()
	if stamp != _stamp:
		_stamp = stamp
		_cache.clear()
	if _cache.has(key):
		return _cache[key]
	var found := {}
	var members: Array = []
	if key.begins_with("u"):
		members = [unit]
	else:
		var tree := (unit as Node).get_tree() if (unit as Node).is_inside_tree() else null
		if tree == null:
			members = [unit]
		elif key == "hero":
			members = tree.get_nodes_in_group("hero") + tree.get_nodes_in_group("companions").filter(func(n): return n is Companion)
		else:
			var party := int(key.substr(1))
			members = tree.get_nodes_in_group("gw_fighters").filter(func(n): return n is GuildFighter and (n as GuildFighter).party == party)
			if party == GuildWarMatch.HERO_PARTY:
				members += tree.get_nodes_in_group("hero")
	for m in members:
		if _alive(m):
			var cls := class_of(m)
			if TRAITS.has(cls):
				found[cls] = true
	_cache[key] = found
	return found


## Whether [param unit]'s party has a living member of [param cls].
static func has(unit: Variant, cls: StringName) -> bool:
	return party_classes(unit).has(cls)


static func value(cls: StringName) -> float:
	return float(TRAITS[cls].value)


# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------

## HP share of a body (1 when unknown).
static func hp_ratio(unit: Variant) -> float:
	if unit == null or not is_instance_valid(unit):
		return 1.0
	if unit is Hero:
		return float(Game.profile.hp) / maxf(float((unit as Hero).stats.get("max_hp", 1)), 1.0)
	if "hp" in unit and "max_hp" in unit:
		return float(unit.hp) / maxf(float(unit.max_hp), 1.0)
	return 1.0


## Damage multiplier of a hit by [param attacker] on [param target]: แนวหน้า (Warrior),
## ตราเวท (a Mage of the party marked the target), จุดตาย (target under 35% HP).
static func outgoing(attacker: Variant, target: Variant) -> float:
	var classes := party_classes(attacker)
	if classes.is_empty():
		return 1.0
	var mult := 1.0
	if classes.has(&"warrior"):
		mult += value(&"warrior")
	if classes.has(&"mage") and marked(target, party_key(attacker)):
		mult += value(&"mage")
	if classes.has(&"assassin") and hp_ratio(target) < float(TRAITS[&"assassin"].below):
		mult += value(&"assassin")
	return mult


## Crit chance the party adds (ตาเหยี่ยว).
static func crit_bonus(attacker: Variant) -> float:
	return value(&"archer") if has(attacker, &"archer") else 0.0


## Share of the target's DEF the attacker's hits ignore (ทะลวงเกราะ).
static func pierce(attacker: Variant) -> float:
	return value(&"lancer") if has(attacker, &"lancer") else 0.0


## [param defence] after the attacker's party pierces it.
static func pierced(attacker: Variant, defence: float) -> float:
	return defence * (1.0 - pierce(attacker))


## Multiplier of the damage [param victim] takes (กำแพงเหล็ก).
static func taken(victim: Variant) -> float:
	return 1.0 - value(&"defender") if has(victim, &"defender") else 1.0


## [param amount] of damage after the victim's party guard (never below 1).
static func guard(victim: Variant, amount: int) -> int:
	var m := taken(victim)
	return amount if m >= 1.0 else maxi(1, int(ceil(float(amount) * m)))


## Speed cooldowns run at (ประสานเสียง: 10% shorter cooldowns).
static func cd_rate(unit: Variant) -> float:
	return 1.0 / (1.0 - value(&"bard")) if has(unit, &"bard") else 1.0


## Whether a Mage of party [param key] marked [param target] and the mark still holds.
static func marked(target: Variant, key: String) -> bool:
	if key == "" or target == null or not is_instance_valid(target) or not (target as Object).has_meta(MARK_META):
		return false
	var marks: Dictionary = (target as Object).get_meta(MARK_META)
	return int(marks.get(key, 0)) > Time.get_ticks_msec()


## After a hit landed: a Mage marks the target for its party (ตราเวท) and a party with a
## Dark Lord drinks its share of the damage (เงามืด).
static func after_hit(attacker: Variant, target: Variant, dealt: int) -> void:
	if dealt <= 0:
		return
	var key := party_key(attacker)
	if key == "":
		return
	if class_of(attacker) == &"mage" and target != null and is_instance_valid(target):
		var obj := target as Object
		var marks: Dictionary = obj.get_meta(MARK_META) if obj.has_meta(MARK_META) else {}
		marks[key] = Time.get_ticks_msec() + int(float(TRAITS[&"mage"].secs) * 1000.0)
		obj.set_meta(MARK_META, marks)
	if has(attacker, &"darklord"):
		_gain(attacker, &"role_leech", float(dealt) * value(&"darklord"), "hp")


## Over time: พรแห่งแสง (HP) and พันธะวิญญาณ (MP), for a living member.
static func regen(unit: Variant, delta: float) -> void:
	var classes := party_classes(unit)
	if classes.is_empty() or not _alive(unit):
		return
	if classes.has(&"priest"):
		_gain(unit, &"role_hp", _max_of(unit, "hp") * value(&"priest") * delta, "hp")
	if classes.has(&"summoner"):
		_gain(unit, &"role_mp", _max_of(unit, "mp") * value(&"summoner") * delta, "mp")


static func _max_of(unit: Variant, kind: String) -> float:
	if unit is Hero:
		return float((unit as Hero).stats.get("max_hp" if kind == "hp" else "max_mp", 0))
	if kind == "hp":
		return float(unit.max_hp)
	if unit is Companion:
		return float((unit as Companion).stats.get("max_mp", 0))
	if unit is Rival:
		return float((unit as Rival).rstats.get("max_mp", 0))
	return 0.0


## Adds a fraction-carrying gain of HP or MP to a body (whole points only).
static func _gain(unit: Variant, meta: StringName, amount: float, kind: String) -> void:
	if amount <= 0.0 or not unit.has_method("role_restore"):
		return
	var obj := unit as Object
	var left := float(obj.get_meta(meta, 0.0)) + amount
	var whole := int(left)
	obj.set_meta(meta, left - float(whole))
	if whole > 0:
		unit.role_restore(kind, whole)
