class_name Rival
extends Mob
## An AI "player" for the ranked duel arena. It is a [Mob] (so the hero's
## targeting, skills, summons and the boss bar all work on it) with a hero
## model, a class, gear and real class skills. How sharp it is depends on the
## rank: higher ranks react quicker, cast more, telegraph less, kite, drink
## potions and dodge.

var member: Dictionary = {}
var difficulty := 0.0
var class_data: Dictionary = {}
var rstats: Dictionary = {}
var mp := 0.0
var cooldowns: Dictionary = {}
var rival_name := ""
var duel_over := false

var _profile: Dictionary = {}
var _equip: Dictionary = {}
var _look: Dictionary = {}
var _frozen := true
var _cast_until := 0
var _combo := 0
var _think := 0.2
var _atk_boost := 1.0
var _def_boost := 1.0
var _buff_until := 0.0
var _base_def := 1.0
var _dodge := 0.0
var _potions := 0
var _potion_cd := 0.0
var _strafe := 1.0
var _strafe_timer := 0.0
var _rv: RivalVisual


func setup_rival(info: Dictionary, p_home: Vector3, p_hero: Node3D, title: String) -> void:
	member = info.member
	_profile = info.profile
	_equip = _profile.equip
	_look = info.look
	difficulty = float(info.difficulty)
	class_data = JobData.resolve(StringName(member["class"]), int(_profile.adv))
	var base := HeroStats.compute(_profile)
	var mults: Dictionary = info.mults
	rstats = base
	rstats["max_hp"] = int(float(base.max_hp) * float(mults.hp))
	rstats["atk"] = float(base.atk) * float(mults.atk)
	rstats["def"] = float(base.def) * float(mults.def)
	rival_name = "%s %s" % [title, member.name]
	monster_id = &"rival"
	level = int(member.level)
	home = p_home
	hero = p_hero
	hp = int(rstats.max_hp)
	max_hp = hp
	_base_def = float(rstats.def)
	stats = {"hp": hp, "atk": float(rstats.atk), "def": _base_def, "exp": 0, "gold": 0}
	var attack: Dictionary = class_data.attack
	template = {
		"name": rival_name, "model": "", "height": 1.9, "speed": float(rstats.speed), "aggro": true,
		"attack": "ranged" if float(attack.range) > 5.0 else "melee", "boss": false,
		"color": class_data.get("color", Color.WHITE),
	}
	is_boss = true
	hostile = true
	_speed = float(rstats.speed) * 0.6
	_base_speed = _speed
	mp = float(rstats.max_mp)
	_dodge = lerpf(0.0, 0.18, difficulty)
	_potions = int(round(lerpf(0.0, 3.0, difficulty)))
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _make_visual() -> MonsterVisual:
	_rv = RivalVisual.new()
	add_child(_rv)
	_rv.setup_rival(StringName(member["class"]), _equip, _look)
	return _rv


## The countdown is over: the rival starts fighting.
func start_fight() -> void:
	_frozen = false
	_attack_timer = 0.6


func stop_fight() -> void:
	duel_over = true
	_frozen = true
	hostile = false


func _check_phase() -> void:
	pass


func apply_slow(seconds: float) -> void:
	super.apply_slow(seconds * 0.5)


## Higher-ranked fighters dodge some hits; nothing hurts during the countdown.
func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
	if _dead or _frozen:
		return false
	if randf() < _dodge:
		BattleVfx.floating_text(get_parent(), top_point(), "หลบ!", Color("9fe8ff"), 0.9)
		return false
	return super.take_hit(amount, crit, color, attacker)


func _die() -> void:
	super._die()
	duel_over = true


## The fallen rival lies on the sand until the zone is left.
func _vanish() -> void:
	pass


# ---------------------------------------------------------------------------
# AI
# ---------------------------------------------------------------------------

func _chase(target: Node3D, delta: float, _speed_factor: float) -> Vector3:
	var to := target.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var now := Time.get_ticks_msec()
	if to.length_squared() > 0.01:
		_yaw = lerp_angle(_yaw, atan2(to.x, to.z), 1.0 - exp(-12.0 * delta))
		visual.rotation.y = _yaw
	if _frozen or duel_over:
		return Vector3.ZERO
	_tick(delta)
	if now < _cast_until:
		return Vector3.ZERO
	var attack: Dictionary = class_data.attack
	var ranged := float(attack.range) > 5.0
	var reach := float(attack.range) * 0.85
	var pace := lerpf(0.85, 1.05, difficulty)
	var speed := float(rstats.speed) * pace * (0.5 if _slow > 0.0 else 1.0)
	var dir := to.normalized() if distance > 0.01 else Vector3.ZERO
	_think -= delta
	if _think <= 0.0:
		_think = lerpf(0.55, 0.18, difficulty)
		if _try_potion():
			return Vector3.ZERO
		if _try_skill(target, distance):
			return Vector3.ZERO
	# Ranged fighters keep their distance (and slide round the hero when cornered).
	if ranged:
		var keep := lerpf(4.5, 7.5, difficulty)
		if distance < keep:
			var away := -dir
			if global_position.length() > 27.0:
				away = Vector3(-dir.z, 0, dir.x) * _strafe
			return away * speed * 0.95
		if distance > reach:
			return dir * speed
	elif distance - 0.4 > reach:
		return dir * speed
	if _attack_timer <= 0.0:
		_basic_attack(target)
		return Vector3.ZERO
	# Melee fighters circle a little between swings (more at high rank).
	if not ranged and difficulty > 0.35:
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = randf_range(0.9, 2.2)
			_strafe = -_strafe
		return Vector3(-dir.z, 0, dir.x) * _strafe * speed * 0.5
	return Vector3.ZERO


func _tick(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_potion_cd = maxf(0.0, _potion_cd - delta)
	mp = minf(float(rstats.max_mp), mp + float(rstats.max_mp) * 0.025 * delta)
	for id in cooldowns.keys():
		cooldowns[id] = maxf(0.0, float(cooldowns[id]) - delta)
	if _buff_until > 0.0 and Time.get_ticks_msec() * 0.001 > _buff_until:
		_buff_until = 0.0
		_atk_boost = 1.0
		_def_boost = 1.0
		stats["def"] = _base_def


func _try_potion() -> bool:
	if _potions <= 0 or _potion_cd > 0.0 or float(hp) / float(max_hp) > 0.32:
		return false
	_potions -= 1
	_potion_cd = 5.0
	_heal(0.35)
	BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.5, 0), "ดื่มยา!", Color("ff8a9a"), 0.9)
	AudioManager.play_sfx(&"heal", -4.0)
	return false


func _heal(fraction: float) -> void:
	var before := hp
	hp = mini(max_hp, hp + int(float(max_hp) * fraction))
	_bar.set_ratio(float(hp) / float(max_hp))
	if hp > before:
		VfxKit.heal(get_parent(), global_position)
		BattleVfx.floating_text(get_parent(), top_point(), "+%d" % (hp - before), Color("6dff9a"), 0.9)


func _tier() -> int:
	return 1 + int(_profile.adv)


func _try_skill(target: Node3D, distance: float) -> bool:
	var best: Dictionary = {}
	var best_score := 0.0
	var hp_ratio := float(hp) / float(max_hp)
	for skill in class_data.skills:
		var shape := String(skill.shape)
		if shape == "summon" or int(skill.level) > level or ClassData.skill_tier(skill) > _tier():
			continue
		if float(cooldowns.get(skill.id, 0.0)) > 0.0 or mp < float(skill.mp):
			continue
		var score := _score(skill, shape, distance, hp_ratio)
		# Lower ranks miss chances to cast.
		if score > 0.0 and randf() > lerpf(0.55, 1.0, difficulty):
			continue
		if score > best_score:
			best_score = score
			best = skill
	if best.is_empty():
		return false
	_cast(best, target)
	return true


func _score(skill: Dictionary, shape: String, distance: float, hp_ratio: float) -> float:
	var fx: Dictionary = skill.get("fx", {})
	match shape:
		"self":
			if fx.has("heal"):
				return 10.0 if hp_ratio < 0.5 else 0.0
			if fx.has("buff"):
				return 6.0 if _buff_until <= 0.0 and distance < 16.0 else 0.0
			return 0.0
		"burst":
			return 5.0 + float(skill.mult) if distance < float(skill.radius) + 0.6 else 0.0
		"blast":
			return 4.5 + float(skill.mult) if distance <= float(skill.get("range", 11.0)) else 0.0
		_:
			return 3.0 + float(skill.get("mult", 1.0)) if distance <= float(skill.get("range", 3.0)) else 0.0


func _cast(skill: Dictionary, target: Node3D) -> void:
	mp -= float(skill.mp)
	cooldowns[skill.id] = float(skill.cd) * lerpf(1.7, 1.05, difficulty)
	var shape := String(skill.shape)
	var color: Color = skill.color
	var delay := float(skill.hit_delay)
	# Area attacks warn the target first; sharper rivals warn for less time.
	if shape in ["burst", "blast"]:
		delay = maxf(delay, lerpf(1.25, 0.65, difficulty))
	var aim := target.global_position
	aim.y = 0.0
	if shape == "blast":
		VfxKit.danger_circle(get_parent(), aim, float(skill.radius), delay)
	elif shape == "burst":
		VfxKit.danger_circle(get_parent(), Vector3(global_position.x, 0.0, global_position.z), float(skill.radius), delay)
	visual.flash(Color(1.0, 0.35, 0.25), minf(delay, 0.5))
	if _rv and _rv.hero_visual:
		_rv.hero_visual.action(String(skill.anim), 1.0)
	_cast_until = Time.get_ticks_msec() + int(delay * 1000.0) + 80
	_attack_timer = maxf(_attack_timer, delay + 0.25)
	BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.5, 0), String(skill.name), color, 0.6)
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(self) and not _dead and not duel_over:
			_resolve(skill, target, aim)
	, CONNECT_ONE_SHOT)


func _resolve(skill: Dictionary, target: Node3D, aim: Vector3) -> void:
	var color: Color = skill.color
	var mult := float(skill.get("mult", 0.0))
	var field := get_parent()
	var shape := String(skill.shape)
	var fx: Dictionary = skill.get("fx", {})
	var alive := target != null and is_instance_valid(target) and _alive(target)
	var center := global_position
	if alive and shape in ["single", "chain", "fan", "blast"]:
		center = Vector3(aim.x, 0.0, aim.z) if shape == "blast" else Vector3(target.global_position.x, 0.0, target.global_position.z)
	SkillShow.play(field, skill, center, global_position, null)
	match shape:
		"self":
			if fx.has("heal"):
				_heal(float(fx.heal))
			if fx.has("buff"):
				var buff: Dictionary = fx.buff
				_atk_boost = 1.0 + float(buff.get("atk", 0.0))
				_def_boost = 1.0 + float(buff.get("def", 0.0))
				stats["def"] = _base_def * _def_boost
				_buff_until = Time.get_ticks_msec() * 0.001 + minf(float(buff.get("secs", 20.0)), 30.0)
				VfxKit.aura(field, global_position, color)
		"burst":
			VfxKit.shockwave(field, global_position + Vector3(0, 0.15, 0), color, float(skill.radius) * 1.15)
			if fx.has("heal"):
				_heal(float(fx.heal) * 0.6)
			for victim in _victims():
				if _flat_distance(victim.global_position) <= float(skill.radius) + 0.6 + 0.4:
					_hit(victim, mult, color)
		"blast":
			var spot := Vector3(aim.x, 0.0, aim.z)
			VfxKit.shockwave(field, spot + Vector3(0, 0.1, 0), color, float(skill.radius))
			for victim in _victims():
				if _flat_distance_from(victim.global_position, spot) <= float(skill.radius) + 0.4:
					_hit(victim, mult, color)
		_:
			if not alive:
				return
			var total := mult
			if shape == "fan":
				total = mult * float(mini(int(skill.get("hits", 3)), 4)) * 0.55
			elif shape == "chain":
				total = mult * float(mini(int(skill.get("hits", 3)), 3)) * 0.8
			if bool(skill.get("projectile", false)) or shape in ["fan", "chain"]:
				_shoot_at(target, total, color, skill.vfx)
			else:
				VfxKit.slash_arc(field, global_position + Vector3(sin(_yaw), 0, cos(_yaw)) * 1.2 + Vector3(0, 1.0, 0), _yaw, color, 3.0, -0.4)
				if _flat_distance(target.global_position) <= float(skill.get("range", 3.0)) + 1.4:
					_hit(target, total, color)


## The hero, plus any of its summons.
func _victims() -> Array[Node3D]:
	return _targets()


func _hit(victim: Node3D, mult: float, color: Color) -> void:
	if not _alive(victim):
		return
	var raw := float(rstats.atk) * _atk_boost * mult * randf_range(0.92, 1.08)
	if randf() < float(rstats.crit):
		raw *= HeroStats.CRIT_DAMAGE
	VfxKit.impact(get_parent(), victim.global_position + Vector3(0, 1.1, 0), color if color != Color.WHITE else Color("fff0c0"), 0.9)
	victim.take_damage(raw, self)


func _shoot_at(victim: Node3D, mult: float, color: Color, vfx: StringName) -> void:
	var field := get_parent()
	var from := global_position + Vector3(0, 1.3, 0) + Vector3(sin(_yaw), 0, cos(_yaw)) * 0.6
	var to := victim.global_position + Vector3(0, 1.1, 0)
	var flight := clampf(from.distance_to(to) / 22.0, 0.1, 0.5)
	if String(member["class"]) == "archer":
		VfxKit.arrow(field, color, from, to, flight)
	else:
		VfxKit.projectile(field, color, from, to, flight, 0.35, VfxKit.variant_for(vfx))
	get_tree().create_timer(flight).timeout.connect(func():
		if is_instance_valid(self) and not _dead and not duel_over:
			_hit(victim, mult, color)
	, CONNECT_ONE_SHOT)


func _basic_attack(target: Node3D) -> void:
	var attack: Dictionary = class_data.attack
	_attack_timer = float(attack.interval) * lerpf(1.6, 1.0, difficulty)
	var anims: Array = attack.anims
	var clip: String = anims[_combo % anims.size()]
	_combo += 1
	if _rv and _rv.hero_visual:
		_rv.hero_visual.action(clip, 1.0)
	_cast_until = Time.get_ticks_msec() + int(float(attack.hit_delay) * 1000.0) + 60
	var color: Color = attack.get("color", Color.WHITE)
	var mult := float(attack.mult)
	get_tree().create_timer(float(attack.hit_delay)).timeout.connect(func():
		if not is_instance_valid(self) or _dead or duel_over or target == null or not is_instance_valid(target):
			return
		if bool(attack.projectile):
			_shoot_at(target, mult, color, attack.vfx)
		elif _flat_distance(target.global_position) <= float(attack.range) + 1.4:
			_hit(target, mult, color)
	, CONNECT_ONE_SHOT)
