class_name GuildFighter
extends Rival
## One AI player of a guild war. It is a [Rival] (class skills, gear, hero model) that
## belongs to a team: the rival guild's fighters are Mobs (so the hero's targeting and
## skills hit them), our guild's fighters stand with the hero (group "companions"
## so heals and buffs reach them) and are only ever hit by the other side. Fighters
## pick targets like a person (focus the weak one, protect the healer, retreat
## when low), fall back to base to heal, and come back after a short respawn.

const TEAM_ALLY := 0
const TEAM_ENEMY := 1
## After coming back the fighter cannot be hurt for a moment.
const SPAWN_GUARD := 2.5
const RETREAT_BELOW := 0.27
const RETURN_ABOVE := 0.65
## Standing in its own base heals this much of max HP per second.
const BASE_HEAL := 0.07
const BASE_RADIUS := 7.0

## Counters for tests/tools/guild_war_sim.gd.
static var dbg := {"recv": 0, "dmg": 0, "dodged": 0, "guard": 0, "basic": 0, "cast": 0, "hits_out": 0}

## Area attacks in the air, so enemies can step out of them like a person (after a reaction time).
static var _dangers: Array = []

signal fell(fighter: GuildFighter, killer: Node)
signal slew_hero(fighter: GuildFighter)

var team := TEAM_ENEMY
var spawn_point := Vector3.ZERO
var rally_point := Vector3.ZERO
var kills := 0
var deaths := 0
var assists := 0
var grade := 0
var guild_name := ""
var respawn_left := 0.0

var _last_attacker: Node
var _helpers: Dictionary = {}
var _guard_until := 0
var _retreating := false
var _grudge := 0.0
## Set by the match: a place to run to (the power orb) while no enemy is close.
var orb_goal: Variant = null
var _react_at := 0
var _ignore_danger := false


## info: GuildWarData.make_fighter(). `title` is the guild tag shown before the name.
func setup_fighter(info: Dictionary, p_team: int, p_hero: Node3D, p_spawn: Vector3, title: String) -> void:
	team = p_team
	grade = int(info.get("grade", 0))
	guild_name = title
	spawn_point = p_spawn
	rally_point = Vector3(p_spawn.x * 0.35, 0.0, 0.0)
	setup_rival(info, p_spawn, p_hero, title)
	war_scale = GuildWarData.damage_scale
	announce_skills = false
	_potions = 3
	_dodge = clampf(float(rstats.get("dodge", 0.0)), 0.0, 0.18)


func _ready() -> void:
	super._ready()
	add_to_group("gw_fighters")
	add_to_group("gw_team%d" % team)
	if team == TEAM_ALLY:
		remove_from_group("mobs")
		add_to_group("companions")
	# Just the name, coloured by guild (the full "[guild] name" overlapped when fighters bunched up).
	_label.text = String(member.name)
	_label.font_size = 36
	_label.modulate = Color("8fd0ff") if team == TEAM_ALLY else Color("ff9a8a")
	_label.visibility_range_end = 30.0
	_start_guard()


func fighter_class() -> StringName:
	return StringName(member["class"])


func is_healer() -> bool:
	return fighter_class() == &"priest"


func is_ranged() -> bool:
	return float(class_data.attack.range) > 5.0


func hp_ratio() -> float:
	return float(hp) / float(maxi(max_hp, 1))


func _leash() -> float:
	return 1.0e9


func set_dormant(_on: bool) -> void:
	pass


func start_fight() -> void:
	super.start_fight()
	_start_guard()


func _start_guard() -> void:
	_guard_until = Time.get_ticks_msec() + int(SPAWN_GUARD * 1000.0)


func under_guard() -> bool:
	return Time.get_ticks_msec() < _guard_until


# ---------------------------------------------------------------------------
# Who it can hurt, and who it chooses
# ---------------------------------------------------------------------------

func _targets() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if team == TEAM_ENEMY:
		if _alive(hero):
			out.append(hero)
		for node in get_tree().get_nodes_in_group("gw_team0"):
			if _alive(node):
				out.append(node as Node3D)
		for node in get_tree().get_nodes_in_group("summons"):
			if _alive(node):
				out.append(node as Node3D)
	else:
		for node in get_tree().get_nodes_in_group("gw_team1"):
			if _alive(node):
				out.append(node as Node3D)
	return out


func _teammates() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("gw_team%d" % team):
		if node != self and _alive(node):
			out.append(node as Node3D)
	if team == TEAM_ALLY and _alive(hero):
		out.append(hero)
	return out


## Closest enemy, but like a person: finish the weak, go for the healer, share the
## attention (not all five on one) and do not flip target every moment.
func _nearest_victim() -> Node3D:
	var best: Node3D = null
	var best_score := -1.0e9
	var allies := _teammates()
	for t in _targets():
		var d := _flat_distance(t.global_position)
		if d > 48.0:
			continue
		var score := -d
		var ratio := 1.0
		if t is GuildFighter:
			ratio = (t as GuildFighter).hp_ratio()
			if (t as GuildFighter).is_healer():
				score += 4.0
			if (t as GuildFighter).under_guard():
				score -= 14.0
		elif t == hero:
			ratio = float(Game.profile.hp) / maxf(float(hero.stats.max_hp), 1.0)
		if ratio < 0.4:
			score += 9.0 * (0.4 - ratio) / 0.4 + 3.0
		var on_it := 0
		for a in allies:
			if a is GuildFighter and (a as GuildFighter)._victim == t:
				on_it += 1
		score += 2.5 * minf(on_it, 2.0) - 5.0 * maxf(on_it - 2.0, 0.0)
		if t == _victim:
			score += 4.5
		if t == _last_attacker and _grudge > 0.0:
			score += 3.0
		if score > best_score:
			best_score = score
			best = t
	return best


# ---------------------------------------------------------------------------
# Taking damage
# ---------------------------------------------------------------------------

## Damage already worked out by the hero, a summon or an ally (the Mob interface).
func take_hit(amount: int, crit: bool, _color := Color.WHITE, attacker: Node = null) -> bool:
	if _dead or _frozen or under_guard():
		dbg.guard += 1
		return false
	if randf() < _dodge:
		dbg.dodged += 1
		BattleVfx.floating_text(get_parent(), top_point(), "หลบ!", Color("9fe8ff"), 0.9)
		return false
	return _receive(int(ceil(float(amount) * war_scale)), crit, attacker if attacker != null else hero)


## Raw damage from another fighter or a monster's strike (defence still to apply).
func take_damage(raw: float, attacker: Node = null) -> void:
	if _dead or _frozen or under_guard():
		return
	if randf() < _dodge:
		dbg.dodged += 1
		BattleVfx.floating_text(get_parent(), top_point(), "หลบ!", Color("9fe8ff"), 0.9)
		return
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(stats.def)))))
	_receive(amount, false, attacker)


func _receive(amount: int, crit: bool, attacker: Node) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	# Nobody is deleted by one hit or one combo, however many enemies pile on.
	amount = BurstGuard.take(get_instance_id(), amount, max_hp)
	dbg.recv += 1
	dbg.dmg += amount
	hp = maxi(0, hp - amount)
	_bar.set_ratio(float(hp) / float(max_hp))
	_bar.visible = true
	_bar_until = now + 6.0
	BattleVfx.damage_number(get_parent(), top_point(), str(amount) + ("!" if crit else ""), team == TEAM_ALLY, 1.35 if crit else 1.0)
	visual.flash(Color(1, 1, 1))
	if attacker != null and is_instance_valid(attacker):
		_last_attacker = attacker
		_grudge = 4.0
		_helpers[attacker.get_instance_id()] = attacker
	if hp <= 0:
		_die()
		return true
	if Time.get_ticks_msec() >= _cast_until:
		visual.action("hurt", 320)
	return false


func _die() -> void:
	if _dead:
		return
	_dead = true
	hostile = false
	set_targeted(false)
	_bar.visible = false
	_alert.visible = false
	_label.visible = false
	collision_layer = 0
	_buff_art.clear(self)
	deaths += 1
	visual.hold("die")
	VfxKit.flash(get_parent(), hit_point(), Color("ffe9a0"), 1.6)
	VfxKit.sparks(get_parent(), hit_point(), Color("ffe27a"), 14, 5.0, 0.7)
	respawn_left = GuildWarData.RESPAWN
	var killer := _last_attacker
	var helpers: Array = []
	for id in _helpers:
		var helper: Variant = _helpers[id]
		if is_instance_valid(helper) and helper != killer:
			helpers.append(helper)
	_helpers.clear()
	fell.emit(self, killer)
	for helper in helpers:
		if helper is GuildFighter:
			(helper as GuildFighter).assists += 1


func respawn() -> void:
	_dead = false
	hp = max_hp
	mp = float(rstats.max_mp)
	_potions = 3
	_potion_cd = 0.0
	_retreating = false
	_victim = null
	BurstGuard.forget(get_instance_id())
	cooldowns.clear()
	_slow = 0.0
	_stun = 0.0
	_atk_boost = 1.0
	_def_boost = 1.0
	stats["def"] = _base_def
	_buff_until = 0.0
	hostile = true
	collision_layer = 1 << 2
	velocity = Vector3.ZERO
	global_position = spawn_point + Vector3(randf_range(-2.0, 2.0), 0.3, randf_range(-2.0, 2.0))
	_label.visible = true
	_bar.set_ratio(1.0)
	_bar.visible = false
	if _rv and _rv.hero_visual:
		_rv.hero_visual.release()
		_rv.hero_visual.play("Idle")
	VfxKit.flash(get_parent(), global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.8)
	_start_guard()


# ---------------------------------------------------------------------------
# Moving and fighting
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _dead:
		respawn_left = maxf(0.0, respawn_left - delta)
		return
	_grudge = maxf(0.0, _grudge - delta)
	if _flat_distance(spawn_point) < BASE_RADIUS and hp < max_hp and not _frozen:
		hp = mini(max_hp, hp + int(ceil(float(max_hp) * BASE_HEAL * delta)))
		_bar.set_ratio(float(hp) / float(max_hp))
	super._physics_process(delta)


func _chase(target: Node3D, delta: float, speed_factor: float) -> Vector3:
	var dodge_step := _dodge_area(delta)
	if dodge_step != Vector3.ZERO:
		return dodge_step
	var ratio := hp_ratio()
	if not _retreating and ratio < RETREAT_BELOW and (_potions <= 0 or _potion_cd > 0.0):
		_retreating = true
	elif _retreating and (ratio > RETURN_ABOVE or (_flat_distance(spawn_point) < BASE_RADIUS * 0.6 and ratio > 0.5)):
		_retreating = false
	if _retreating and not _frozen:
		return _fall_back(delta)
	if orb_goal != null and not _frozen and _flat_distance(target.global_position) > 9.0:
		return _run_to(orb_goal as Vector3, delta)
	return super._chase(target, delta, speed_factor)


## A person sees the warning ring and walks out of it after a beat; sometimes does not.
func _dodge_area(delta: float) -> Vector3:
	if _frozen or Time.get_ticks_msec() < _cast_until:
		return Vector3.ZERO
	var now := Time.get_ticks_msec()
	for danger in _dangers:
		if int(danger.team) == team or now > int(danger.until):
			continue
		var from_center := global_position - (danger.center as Vector3)
		from_center.y = 0.0
		if from_center.length() > float(danger.radius) + 0.5:
			continue
		if _react_at == 0:
			_react_at = now + randi_range(250, 480)
			_ignore_danger = randf() < 0.15
		if now < _react_at or _ignore_danger:
			return Vector3.ZERO
		_tick(delta)
		var away := from_center.normalized() if from_center.length() > 0.05 else Vector3(1, 0, 0)
		_yaw = lerp_angle(_yaw, atan2(away.x, away.z), 1.0 - exp(-10.0 * delta))
		visual.rotation.y = _yaw
		return away * float(rstats.speed)
	_react_at = 0
	return Vector3.ZERO


func _cast(skill: Dictionary, target: Node3D) -> void:
	var shape := String(skill.shape)
	if shape in ["burst", "blast"] and is_instance_valid(target):
		var at := target.global_position if shape == "blast" else global_position
		var wait := maxf(float(skill.hit_delay), lerpf(1.25, 0.65, difficulty))
		_dangers.append({"center": Vector3(at.x, 0.0, at.z), "radius": float(skill.radius), "until": Time.get_ticks_msec() + int(wait * 1000.0) + 250, "team": team})
		if _dangers.size() > 24:
			_dangers = _dangers.filter(func(d): return Time.get_ticks_msec() <= int(d.until))
	super._cast(skill, target)


## A healer casts when an ally nearby is hurt, not only when it is.
func _score(skill: Dictionary, shape: String, distance: float, own_ratio: float) -> float:
	var fx: Dictionary = skill.get("fx", {})
	if shape == "self" and fx.has("heal"):
		var lowest := own_ratio
		for ally in _teammates():
			if _flat_distance(ally.global_position) < 9.0:
				if ally is GuildFighter:
					lowest = minf(lowest, (ally as GuildFighter).hp_ratio())
				elif ally == hero and "stats" in hero:
					lowest = minf(lowest, float(Game.profile.hp) / maxf(float(hero.stats.max_hp), 1.0))
		return 10.0 if lowest < 0.55 else 0.0
	return super._score(skill, shape, distance, own_ratio)


func _run_to(point: Vector3, delta: float) -> Vector3:
	_tick(delta)
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		_yaw = lerp_angle(_yaw, atan2(to.x, to.z), 1.0 - exp(-10.0 * delta))
		visual.rotation.y = _yaw
	if Time.get_ticks_msec() < _cast_until or to.length() < 1.0:
		return Vector3.ZERO
	return to.normalized() * float(rstats.speed)


## Low on health: run home, drink if possible, heal in the base, then return.
func _fall_back(delta: float) -> Vector3:
	_tick(delta)
	var to := spawn_point - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		_yaw = lerp_angle(_yaw, atan2(to.x, to.z), 1.0 - exp(-10.0 * delta))
		visual.rotation.y = _yaw
	_think -= delta
	if _think <= 0.0:
		_think = 0.3
		_try_potion()
	if Time.get_ticks_msec() < _cast_until or to.length() < 2.0:
		return Vector3.ZERO
	return to.normalized() * float(rstats.speed) * 1.05


## With nobody to fight (the other side is waiting to respawn) it holds its half.
func _wander(delta: float) -> Vector3:
	if orb_goal != null and not _frozen:
		return _run_to(orb_goal as Vector3, delta)
	_tick(delta)
	var to := rally_point - global_position
	to.y = 0.0
	if to.length() < 2.5:
		return Vector3.ZERO
	return to.normalized() * float(rstats.speed) * 0.8


# ---------------------------------------------------------------------------
# Team play: heals and buffs reach the allies like the hero's do
# ---------------------------------------------------------------------------

func _heal(fraction: float) -> void:
	super._heal(fraction)
	for ally in _teammates():
		if _flat_distance(ally.global_position) < 9.0:
			if ally is GuildFighter:
				(ally as GuildFighter).heal_fraction(fraction * 0.6)
			elif ally.has_method("receive_heal"):
				ally.receive_heal(fraction * 0.6)


func heal_fraction(fraction: float) -> void:
	if _dead:
		return
	var before := hp
	hp = mini(max_hp, hp + int(float(max_hp) * fraction))
	_bar.set_ratio(float(hp) / float(max_hp))
	if hp > before:
		VfxKit.heal(get_parent(), global_position)
		BattleVfx.floating_text(get_parent(), top_point(), "+%d" % (hp - before), Color("6dff9a"), 0.9)


func receive_heal(fraction: float) -> void:
	heal_fraction(fraction)


func receive_party_buff(buff: Dictionary, color: Color, label := "", skill_id := "") -> void:
	if _dead:
		return
	_atk_boost = maxf(_atk_boost, 1.0 + float(buff.get("atk", 0.0)))
	_def_boost = maxf(_def_boost, 1.0 + float(buff.get("def", 0.0)))
	stats["def"] = _base_def * _def_boost
	_buff_until = maxf(_buff_until, Time.get_ticks_msec() * 0.001 + minf(float(buff.get("secs", 20.0)), 30.0))
	var display := buff.duplicate()
	display.secs = minf(float(buff.get("secs", 20.0)), 30.0)
	_buff_art.add(display, color, label, true, skill_id)


func _resolve(skill: Dictionary, target: Node3D, aim: Vector3) -> void:
	super._resolve(skill, target, aim)
	if String(skill.shape) == "self" and skill.get("fx", {}).has("buff"):
		for ally in _teammates():
			if _flat_distance(ally.global_position) <= 12.0 and ally.has_method("receive_party_buff"):
				ally.receive_party_buff(skill.fx.buff, skill.color, String(skill.name), String(skill.id))


## A strike at `victim` (scale and the hero's burst cap are in Rival._hit).
func _hit(victim: Node3D, mult: float, color: Color) -> void:
	var was_alive := _alive(victim)
	dbg.hits_out += 1
	super._hit(victim, mult, color)
	if was_alive and victim == hero and not _alive(victim):
		slew_hero.emit(self)


## The war never ends a fighter's life for good: no EXP, gold or loot, nothing to free.
func _vanish() -> void:
	pass
