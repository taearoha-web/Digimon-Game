class_name AscendBuffsB
extends RefCounted
## The ★500 Ascension buffs of the Priest, the Summoner, the Defender, the Dark Lord and the
## Bard: mechanics, not stat sticks (AscendSkillData.BUFFS). Each is a key of the buff,
## read on whoever carries it: the hero, its companions and summons, AI rivals and guild war
## fighters (the same rules for all of them; AscendBuffs holds the other five classes').
##
##   "regen"         แสงฟื้นต่อเนื่อง (halo_of_eternity, the whole party) and ผู้พิทักษ์ทีม
##                   (aegis_of_eternity, the Defender only): that share of max HP back every
##                   second.
##   "cleanse"       แสงฟื้นต่อเนื่อง: every that many seconds (the first at once) the carrier's
##                   negative statuses go: slow, armour crack, weakness, dark fire, and on a
##                   fighter (a Mob) stun and burn too.
##   "aegis"         ผู้พิทักษ์ทีม: that share of the damage meant for a party member goes to the
##                   guardian ("aegis_by", its instance id, set at the cast: cast_buff), through
##                   the guardian's own DEF and guards; the member takes the rest. Within
##                   AEGIS_REACH metres, never chained (a guardian's share never moves again).
##                   Its "def" is the party's DEF.
##   "titan"         พันธสัญญาไททัน (covenant_of_beasts): a Titan (Summon kind "titan",
##                   TitanVisual) fights beside the caster for the buff's time; it carries meta
##                   TITAN_META (the summoner's fused ultimate leaves it alone).
##   "summon_boost"  พันธสัญญาไททัน: every summon of the caster (the Titan too) has that much more
##                   ATK, DEF, max HP, run speed and attack speed while it runs.
##   "summon_life"   พันธสัญญาไททัน: the caster's summons last that many times as long: the ones
##                   out at the cast gain (factor - 1) x their full lifetime, the ones called
##                   while it runs start with factor x (once each: META_LIFE).
##   "dark_fire"     เพลิงมืดเผาผลาญ (crown_of_dual_realms): every hit of the caster sets dark
##                   fire on its victim for that many seconds: "dark_fire_dps" x ATK per second
##                   (through the victim's DEF, like a burn) and "dark_fire_vuln" more damage
##                   taken from EVERY source while it burns (Mob.add_taken_mark; on a player
##                   taken_mult), with a dark-purple flame on the body (DarkFlame).
##   "song_boost"    เสียงสะท้อน (aria_of_eternity): the songs the caster sings while it runs are
##                   that much stronger (BuffBook.boost_song) and "song_time" times as long.
##   "aspd"          เสียงสะท้อน (its party part, with its "speed"): attack speed (swings come
##                   1 / (1 + aspd) as often: attack_rate); run_rate carries its "speed" to the
##                   AI's steps (the hero's and a companion's follow come through "speed").
##
## Buff times are the wall clock (BuffBook), so is everything here. State lives on the body
## as metadata (META).

const META := &"ascend_buff_b"
## On the Titan (the fused ultimate of the summoner skips it).
const TITAN_META := &"ascend_titan"
## On a caster: a WeakRef to its Titan (a new cast replaces the old one).
const TITAN_REF := &"ascend_titan_ref"
## On a summon whose lifetime the covenant already stretched.
const META_LIFE := &"ascend_life"
## On a summon: its max HP before the covenant's boost.
const META_BASE_HP := &"ascend_base_hp"
const TITAN_KIND := "titan"
## The Titan's skill multiplier (the summoner's ★300 legends are 16; it is a ★500 summon).
const TITAN_MULT := 20.0
## The Titan swings this often (s) and its slam strikes everything this close to its target.
const TITAN_INTERVAL := 1.5
const TITAN_SPLASH := 3.2
const AEGIS_REACH := 20.0
const AEGIS_COLOR := Color("8ac4ff")
const REGEN_COLOR := Color("6dff9a")
const CLEANSE_COLOR := Color("fff6b0")
const FIRE_COLOR := Color("8a3cff")
const FIRE_CORE := Color("d9a6ff")
## A guardian's share is never moved on again (two guardians would pass it to and fro).
static var _redirecting := false


# --- reading the buffs -------------------------------------------------------------

## The buff list of [param unit]: the hero's, a companion's or summon's book, a rival's art.
static func entries(unit: Variant) -> Array:
	if unit == null or not is_instance_valid(unit):
		return []
	if unit is Hero:
		return (unit as Hero)._buffs
	if unit is Rival:
		return (unit as Rival)._buff_art.buffs
	if unit is Companion:
		return (unit as Companion)._book.buffs
	if unit is Summon:
		return (unit as Summon)._book.buffs
	return []


## The strongest running value of [param key] in [param list] (0 without one).
static func value(list: Array, key: String, now := -1) -> float:
	if list.is_empty():
		return 0.0
	if now < 0:
		now = Time.get_ticks_msec()
	var best := 0.0
	for buff in list:
		if int(buff.get("until", 0)) > now and buff.has(key):
			best = maxf(best, float(buff[key]))
	return best


## The running entry carrying [param key] with the strongest value ({} without one);
## [param own] only the carrier's own buffs (not a friend's).
static func entry(list: Array, key: String, own := false, now := -1) -> Dictionary:
	if now < 0:
		now = Time.get_ticks_msec()
	var best: Dictionary = {}
	for buff in list:
		if int(buff.get("until", 0)) > now and buff.has(key) and not (own and bool(buff.get("ally", false))):
			if best.is_empty() or float(buff[key]) > float(best[key]):
				best = buff
	return best


static func _alive(unit: Variant) -> bool:
	return unit != null and is_instance_valid(unit) and unit.has_method("is_dead") and not unit.is_dead()


static func _field(unit: Node3D) -> Node3D:
	if unit is Hero:
		return (unit as Hero).field
	return unit.get_parent() as Node3D


static func _state(unit: Object) -> Dictionary:
	if not unit.has_meta(META):
		unit.set_meta(META, {"regen_t": 0.0, "cleanse_t": 0.0, "cleansing": false, "fire_left": 0.0, "fire_dps": 0.0, "fire_tick": 0.0, "fire_vuln": 0.0, "link_ms": 0})
	return unit.get_meta(META)


static func _shown(unit: Node3D) -> bool:
	return unit is Hero or unit.visible


# --- casting ------------------------------------------------------------------------

## The buff as [param caster] casts it ([param own]: the caster's buff list): a song sung
## under its own เสียงสะท้อน grows and lasts longer; ผู้พิทักษ์ทีม names its guardian.
static func cast_buff(caster: Node, own: Array, buff: Dictionary) -> Dictionary:
	var out := buff
	if BuffBook.is_song(buff):
		var aria := entry(own, "song_boost", true)
		if not aria.is_empty():
			out = BuffBook.boost_song(buff, 1.0 + float(aria.song_boost))
			out["secs"] = float(buff.get("secs", 10.0)) * float(aria.get("song_time", 1.0))
	if out.has("aegis") and caster != null:
		out = out.duplicate()
		out["aegis_by"] = caster.get_instance_id()
	return out


## After [param caster] cast [param buff] (its own copy: the time it runs): the covenant's
## Titan comes and the caster's summons out now last longer.
static func after_cast(caster: Node3D, buff: Dictionary) -> void:
	if caster == null or not is_instance_valid(caster):
		return
	var factor := float(buff.get("summon_life", 0.0))
	if factor > 1.0:
		var list: Variant = caster.get("_summons")
		if list is Array:
			for s in list:
				_stretch_life(s, factor)
	if bool(buff.get("titan", false)):
		call_titan(caster, float(buff.get("secs", AscendSkillData.BUFF_SECS)))


## A summon out when the covenant came: (factor - 1) x its full lifetime more, once.
static func _stretch_life(s: Variant, factor: float) -> void:
	if s == null or not is_instance_valid(s) or (s as Object).has_meta(META_LIFE) or (s as Object).has_meta(TITAN_META):
		return
	if not ("life" in s) or not ("spec" in s):
		return
	if s.has_method("is_dead") and s.is_dead():
		return
	var full := float((s.spec as Dictionary).get("secs", Summon.LIFETIME))
	s.life = float(s.life) + full * (factor - 1.0)
	(s as Object).set_meta(META_LIFE, factor)


## The lifetime factor a summon called now by [param summoner] starts with (1 without the
## covenant; never the Titan's own).
static func new_summon_life(summoner: Variant, spec: Dictionary, s: Object) -> float:
	if String(spec.get("kind", "")) == TITAN_KIND:
		return 1.0
	var factor := value(entries(summoner), "summon_life")
	if factor <= 1.0:
		return 1.0
	s.set_meta(META_LIFE, factor)
	return factor


## The covenant's boost on [param summoner]'s summons right now (0 without it).
static func summon_boost(summoner: Variant) -> float:
	return value(entries(summoner), "summon_boost")


## The Titan of [param caster], if one stands.
static func titan_of(caster: Object) -> Node3D:
	if caster == null or not is_instance_valid(caster) or not caster.has_meta(TITAN_REF):
		return null
	var ref: Variant = caster.get_meta(TITAN_REF)
	var t: Variant = (ref as WeakRef).get_ref() if ref is WeakRef else null
	if t == null or not is_instance_valid(t) or (t.has_method("is_dead") and t.is_dead()):
		return null
	return t as Node3D


## พันธสัญญาไททัน: the Titan stands beside [param caster] for [param secs] (an earlier one
## leaves). On the hero's side a Summon; an enemy AI summoner's (a duel rival, the rival
## guild's fighter) a SummonMob, as its other creatures.
static func call_titan(caster: Node3D, secs: float) -> Node3D:
	var field := _field(caster)
	if field == null or not caster.is_inside_tree():
		return null
	var old := titan_of(caster)
	if old != null:
		if old is Summon:
			(old as Summon)._vanish()
		else:
			old.queue_free()
	var spec := {"kind": TITAN_KIND, "count": 1, "secs": secs, "interval": TITAN_INTERVAL}
	var mult := TITAN_MULT * HeroStats.SKILL_POWER
	var id := String(AscendSkillData.IDS[&"summoner"][1])
	var node: Node3D
	if caster is Rival and (caster as Rival)._summons_are_enemies():
		var m := SummonMob.new()
		m.setup_summon(caster as Rival, id, spec, mult, 0, 1, 1)
		m.position = caster.global_position + m._formation()
		node = m
	else:
		var s := Summon.new()
		s.setup(caster, id, spec, mult, 0, 1, 1)
		node = s
	node.name = "AscendTitan"
	node.set_meta(TITAN_META, true)
	field.add_child(node, true)
	caster.set_meta(TITAN_REF, weakref(node))
	if _shown(caster):
		BattleVfx.floating_text(field, caster.global_position + Vector3(0, 3.2, 0), "ไททันมาแล้ว!", Color("8af05a"), 1.0)
		VfxKit.shockwave(field, node.global_position + Vector3(0, 0.1, 0), Color("8af05a"), 4.5)
	return node


## The Titan's slam: the target and everything within TITAN_SPLASH of it.
static func titan_slam(titan: Summon, target: Mob, raw: float) -> void:
	var center := target.global_position
	var field := titan.get_parent() as Node3D
	if field:
		VfxKit.shockwave(field, Vector3(center.x, titan.global_position.y + 0.1, center.z), Color("8af05a"), TITAN_SPLASH)
	if titan.is_inside_tree():
		for node in titan.get_tree().get_nodes_in_group("mobs"):
			var mob := node as Mob
			if mob and mob != target and not mob.is_dead() and Vector2(mob.global_position.x - center.x, mob.global_position.z - center.z).length() <= TITAN_SPLASH + mob.body_radius():
				titan._hit(mob, raw * 0.6)
	titan._hit(target, raw)


## Keeps a summon's covenant boost in step with its summoner's buff (a Summon's
## ascend_boost, a SummonMob's ATK / DEF / speed), and its max HP (current HP in step).
static func sync_summon(s: Node, summoner: Variant) -> void:
	var boost := summon_boost(summoner)
	var current := float(s.get_meta(&"ascend_boost", 0.0))
	if is_equal_approx(boost, current):
		return
	s.set_meta(&"ascend_boost", boost)
	if not s.has_meta(META_BASE_HP):
		s.set_meta(META_BASE_HP, int(s.max_hp))
	var base_hp := int(s.get_meta(META_BASE_HP))
	var new_max := maxi(1, int(round(float(base_hp) * (1.0 + boost))))
	var ratio := float(s.hp) / float(maxi(int(s.max_hp), 1))
	s.max_hp = new_max
	s.hp = clampi(int(round(ratio * float(new_max))), 1, new_max)
	if s is Summon:
		(s as Summon).ascend_boost = boost
		if (s as Summon)._bar:
			(s as Summon)._bar.set_ratio(float(s.hp) / float(new_max))
	elif s is SummonMob:
		var m := s as SummonMob
		if not m.has_meta(&"ascend_base"):
			m.set_meta(&"ascend_base", [float(m.stats.def), m._base_speed])
		var base: Array = m.get_meta(&"ascend_base")
		m._atk_scale = 1.0 + boost
		var def := float(base[0]) * (1.0 + boost)
		if m._shred_time > 0.0:
			m._unshredded_def = def
			def *= 1.0 - m._shred
		m.stats.def = def
		m._speed = float(base[1]) * (1.0 + boost)
		if m._bar:
			m._bar.set_ratio(float(m.hp) / float(new_max))


# --- every frame ------------------------------------------------------------------

## The frame of a buffed body: regeneration, the cleanse, dark fire burning on a player.
static func tick(unit: Node3D, delta: float) -> void:
	var list := entries(unit)
	var has_state := unit.has_meta(META)
	if list.is_empty() and not has_state:
		return
	var now := Time.get_ticks_msec()
	var regen := value(list, "regen", now)
	var cleanse := value(list, "cleanse", now)
	if regen <= 0.0 and cleanse <= 0.0 and not has_state:
		return
	var st := _state(unit)
	if not _alive(unit):
		st.regen_t = 0.0
		st.cleansing = false
		_fire_out(unit, st)
		return
	if regen > 0.0:
		st.regen_t = float(st.regen_t) + delta
		while float(st.regen_t) >= 1.0:
			st.regen_t = float(st.regen_t) - 1.0
			restore(unit, regen)
	else:
		st.regen_t = 0.0
	if cleanse > 0.0:
		if not bool(st.cleansing):
			st.cleansing = true
			st.cleanse_t = 0.0
		st.cleanse_t = float(st.cleanse_t) - delta
		if float(st.cleanse_t) <= 0.0:
			st.cleanse_t = cleanse
			cleanse_now(unit)
	else:
		st.cleansing = false
	if float(st.fire_left) > 0.0:
		_tick_player_fire(unit, st, delta)


## [param fraction] of max HP back on [param unit] (a quiet number: it comes every second).
static func restore(unit: Node3D, fraction: float) -> void:
	var gained := 0
	if unit is Hero:
		var h := unit as Hero
		var max_hp := int(h.stats.get("max_hp", 0))
		var before := int(Game.profile.get("hp", 0))
		Game.profile.hp = mini(max_hp, before + int(ceil(float(max_hp) * fraction)))
		gained = int(Game.profile.hp) - before
	elif "hp" in unit and "max_hp" in unit:
		var before := int(unit.hp)
		unit.hp = mini(int(unit.max_hp), before + int(ceil(float(unit.max_hp) * fraction)))
		gained = int(unit.hp) - before
		_bar_of(unit)
	if gained > 0 and _shown(unit):
		var field := _field(unit)
		if is_instance_valid(field):
			BattleVfx.floating_text(field, unit.global_position + Vector3(0, 2.5, 0), "+%d" % gained, REGEN_COLOR, 0.6)


static func _bar_of(unit: Node) -> void:
	if unit.has_method("_update_bar"):
		unit._update_bar()
	elif "_bar" in unit and unit._bar != null and "max_hp" in unit:
		unit._bar.set_ratio(float(unit.hp) / float(maxi(int(unit.max_hp), 1)))


## Lifts [param unit]'s negative statuses. True when one went.
static func cleanse_now(unit: Node3D) -> bool:
	var any := false
	var now := Time.get_ticks_msec()
	if unit is Hero:
		var h := unit as Hero
		any = h._slow_until > now or h._enemy_shred_until > now or h._enemy_weaken_until > now
		h._slow_until = 0
		h._enemy_shred_until = 0
		h._enemy_weaken_until = 0
	elif unit is Companion:
		var c := unit as Companion
		any = c._slow_until > now
		c._slow_until = 0
	elif unit is Mob:
		any = (unit as Mob).cleanse_status()
		if unit is Rival:
			var r := unit as Rival
			any = any or r.debuff_left("shred") > 0.0 or r.debuff_left("weaken") > 0.0
			r._clear_marks()
	if unit.has_meta(META) and float(_state(unit).fire_left) > 0.0:
		any = true
		_fire_out(unit, _state(unit))
	if any and _shown(unit):
		var field := _field(unit)
		if is_instance_valid(field):
			BattleVfx.floating_text(field, unit.global_position + Vector3(0, 2.9, 0), "ชำระล้าง!", CLEANSE_COLOR, 0.7)
			VfxKit.impact_ring(field, unit.global_position + Vector3(0, 0.2, 0), CLEANSE_COLOR, 1.4, 0.4)
	return any


# --- hits ------------------------------------------------------------------------

## Swings come this many times as often (เสียงสะท้อน's "aspd"): divide an interval by it.
static func attack_rate(list: Array) -> float:
	return 1.0 + value(list, "aspd")


## Run speed factor of เสียงสะท้อน for an AI's steps (rival, guild fighter, a companion in a
## fight): its "speed", read only off the entries that carry "aspd" (1 without it).
static func run_rate(unit: Variant) -> float:
	var aria := entry(entries(unit), "aspd")
	return 1.0 + float(aria.get("speed", 0.0)) if not aria.is_empty() else 1.0


## [param attacker] (its buff list [param list], its attack [param atk]) hit [param victim]:
## เพลิงมืดเผาผลาญ sets dark fire on it.
static func after_hit(attacker: Node, list: Array, victim: Variant, atk: float) -> void:
	if list.is_empty() or not _alive(victim):
		return
	var fire := entry(list, "dark_fire")
	if fire.is_empty():
		return
	var secs := float(fire.dark_fire)
	var vuln := float(fire.get("dark_fire_vuln", 0.0))
	if victim is Mob:
		var m := victim as Mob
		m.apply_dark_fire(HeroStats.burn_dps(atk, float(fire.get("dark_fire_dps", 0.0)), float(m.stats.def)), secs, vuln, attacker)
	elif victim is Hero or victim is Companion:
		var def := float((victim as Hero).effective_def()) if victim is Hero else float((victim as Companion).stats.def)
		set_player_fire(victim as Node3D, HeroStats.burn_dps(atk, float(fire.get("dark_fire_dps", 0.0)), def), secs, vuln)


## Dark fire on a player (the hero, a companion): the stronger burn and the longer time win.
static func set_player_fire(unit: Node3D, dps: float, secs: float, vuln: float) -> void:
	if not _alive(unit) or secs <= 0.0:
		return
	if unit is Hero and ((unit as Hero).safe_zone or (unit as Hero).spectating):
		return
	var st := _state(unit)
	var burning := float(st.fire_left) > 0.0
	st.fire_dps = maxf(float(st.fire_dps) if burning else 0.0, dps)
	st.fire_vuln = maxf(float(st.fire_vuln) if burning else 0.0, vuln)
	st.fire_left = maxf(float(st.fire_left), secs)
	DarkFlame.ensure(unit, 2.0)


static func _tick_player_fire(unit: Node3D, st: Dictionary, delta: float) -> void:
	st.fire_left = float(st.fire_left) - delta
	st.fire_tick = float(st.fire_tick) + delta
	if float(st.fire_tick) >= 0.5:
		st.fire_tick = float(st.fire_tick) - 0.5
		var amount := maxi(1, int(float(st.fire_dps) * 0.5 * taken_mult(unit)))
		_burn_player(unit, amount)
	if float(st.fire_left) <= 0.0:
		_fire_out(unit, st)


static func _burn_player(unit: Node3D, amount: int) -> void:
	var field := _field(unit)
	if unit is Hero:
		var h := unit as Hero
		if h.safe_zone or h.spectating:
			return
		Game.profile.hp = maxi(0, int(Game.profile.hp) - amount)
		if is_instance_valid(field):
			BattleVfx.damage_number(field, h.global_position + Vector3(0, 2.4, 0), str(amount), true, 0.7)
		if int(Game.profile.hp) <= 0:
			h._die()
	elif unit is Companion:
		var c := unit as Companion
		c.hp = maxi(0, c.hp - amount)
		c._update_bar()
		if is_instance_valid(field):
			BattleVfx.other_number(field, c.global_position + Vector3(0, 2.4, 0), str(amount), FIRE_CORE, 0.8)
		if c.hp <= 0:
			c._die()


static func _fire_out(unit: Node3D, st: Dictionary) -> void:
	st.fire_left = 0.0
	st.fire_dps = 0.0
	st.fire_vuln = 0.0
	st.fire_tick = 0.0
	DarkFlame.remove(unit)


## Damage a player takes is multiplied by this (dark fire burning on it).
static func taken_mult(unit: Object) -> float:
	if unit == null or not unit.has_meta(META):
		return 1.0
	var st: Dictionary = unit.get_meta(META)
	return 1.0 + float(st.fire_vuln) if float(st.fire_left) > 0.0 else 1.0


## ผู้พิทักษ์ทีม on a party member about to take [param raw] (before its DEF): the guardian's
## share goes to the guardian (its own DEF and guards apply); the rest is returned.
static func intercept(victim: Node3D, list: Array, raw: float, attacker: Node) -> float:
	var guard := _guardian(victim, list)
	if guard.is_empty():
		return raw
	var g: Node3D = guard.node
	var share := float(guard.share)
	_redirecting = true
	g.take_damage(raw * share, attacker)
	_redirecting = false
	_link(victim, g)
	return raw * (1.0 - share)


## The same for a fighter hit by an amount its own DEF already cut ([param amount], a Mob's
## take_hit): the guardian takes its share as its own DEF would cut it, the rest is returned.
static func intercept_hit(victim: Mob, list: Array, amount: int, attacker: Node) -> int:
	var guard := _guardian(victim, list)
	if guard.is_empty() or not (guard.node is Mob):
		return amount
	var g := guard.node as Mob
	var share := float(guard.share)
	# Mitigation is linear (HeroStats.mitigate): back to the raw blow, then through the guardian's DEF.
	var raw := float(amount) * (100.0 + maxf(float(victim.stats.def), 0.0)) / 100.0
	_redirecting = true
	g.take_hit(maxi(1, int(round(HeroStats.mitigate(raw * share, float(g.stats.def))))), false, AEGIS_COLOR, attacker)
	_redirecting = false
	_link(victim, g)
	return maxi(1, int(ceil(float(amount) * (1.0 - share))))


## {node, share} of the guardian standing for [param victim] ({} for none).
static func _guardian(victim: Node3D, list: Array) -> Dictionary:
	if _redirecting or list.is_empty():
		return {}
	var now := Time.get_ticks_msec()
	var mine := victim.get_instance_id()
	for buff in list:
		if int(buff.get("until", 0)) <= now or not buff.has("aegis_by") or int(buff.aegis_by) == mine:
			continue
		var g: Variant = instance_from_id(int(buff.aegis_by))
		if g == null or not is_instance_valid(g) or not (g is Node3D) or not g.has_method("take_damage") or not _alive(g):
			continue
		if (g as Node3D).global_position.distance_to(victim.global_position) > AEGIS_REACH:
			continue
		return {"node": g, "share": clampf(float(buff.get("aegis", 0.5)), 0.0, 0.9)}
	return {}


## The guard link: a blue streak from the member to its guardian (at most every 0.25 s).
static func _link(victim: Node3D, guard: Node3D) -> void:
	var st := _state(victim)
	var now := Time.get_ticks_msec()
	if now - int(st.link_ms) < 250 or not (_shown(victim) or _shown(guard)):
		return
	st.link_ms = now
	var field := _field(victim)
	if not is_instance_valid(field):
		return
	ClassFlourish._lance_streak(field, victim.global_position + Vector3(0, 1.2, 0), guard.global_position + Vector3(0, 1.4, 0), AEGIS_COLOR, Color("fbfdff"), 0.35, 0.25)


# --- the dark flame ----------------------------------------------------------------

## A dark-purple flame licking up a burning body: billboard flames in a dark violet with a
## bright violet core flickering, round the lower body and the chest. One per body.
class DarkFlame extends Node3D:
	static var _dark: StandardMaterial3D
	static var _mid: StandardMaterial3D
	static var _core: StandardMaterial3D
	static var _pool: StandardMaterial3D

	static func ensure(host: Node3D, height: float) -> DarkFlame:
		var have := host.get_node_or_null("DarkFire") as DarkFlame
		if have != null and not have.is_queued_for_deletion():
			return have
		var flame := DarkFlame.new()
		flame.name = "DarkFire"
		flame._build(clampf(height, 0.8, 6.0))
		host.add_child(flame)
		return flame

	static func remove(host: Node3D) -> void:
		var have := host.get_node_or_null("DarkFire")
		if have != null:
			have.name = "DarkFireOut"
			have.queue_free()

	static func _mats() -> void:
		if _dark != null:
			return
		var flame := VfxArt.texture("flame")
		# A dark violet body, a vivid violet tongue over it and a hot lilac core (additive).
		_dark = VfxKit._glow(Color("2a0650"), 0.92, false)
		_mid = VfxKit._glow(Color("a855ff"), 1.0, false)
		_core = VfxKit._glow(Color("d9a6ff"), 0.9, true)
		for m in [_dark, _mid, _core]:
			(m as StandardMaterial3D).albedo_texture = flame
			(m as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		# The tongues and the core read over the body that carries them (the body would
		# otherwise swallow the billboards standing inside it).
		for m in [_mid, _core]:
			(m as StandardMaterial3D).no_depth_test = true
			(m as StandardMaterial3D).render_priority = 2
		_pool = VfxKit._glow(Color("5a12b0"), 0.6, false)
		_pool.albedo_texture = VfxArt.texture("flare")

	func _build(height: float) -> void:
		_mats()
		var spots := [Vector3(0.0, 0.0, 0.3), Vector3(-0.32, 0.08, 0.0), Vector3(0.32, 0.05, -0.02), Vector3(0.0, 0.05, -0.3), Vector3(-0.1, 0.42, 0.18), Vector3(0.14, 0.5, -0.1)]
		for i in spots.size():
			var at: Vector3 = spots[i] * height
			var size := height * (0.9 if i < 4 else 0.62)
			_layer(at, size, _dark, i)
			_layer(at + Vector3(0, 0.02 * height, 0.03), size * 0.72, _mid, i + 3)
			_layer(at + Vector3(0, 0.03 * height, 0.06), size * 0.42, _core, i + 6)
		var pool := MeshInstance3D.new()
		pool.mesh = VfxKit.ground_quad()
		pool.material_override = _pool
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.position = Vector3(0, 0.05, 0)
		pool.scale = Vector3.ONE * height * 0.6
		add_child(pool)

	## Gone with its body (a fallen monster shrinks away, a fallen player lies down).
	func _process(_delta: float) -> void:
		var host := get_parent()
		if host == null or (host.has_method("is_dead") and host.is_dead()):
			queue_free()

	func _layer(at: Vector3, size: float, mat: StandardMaterial3D, seed: int) -> void:
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(size * 0.7, size)
		quad.center_offset = Vector3(0, size * 0.42, 0)
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = at
		add_child(mi)
		var flicker := mi.create_tween().set_loops()
		flicker.tween_interval(0.03 * float(seed % 5))
		flicker.tween_property(mi, "scale", Vector3(0.82, 1.24, 1.0), 0.14 + 0.02 * float(seed % 3))
		flicker.tween_property(mi, "scale", Vector3(1.12, 0.84, 1.0), 0.12 + 0.02 * float(seed % 2))
