class_name Companion
extends CharacterBody3D
## An AI party member: follows the hero, helps against whatever the hero is
## fighting, uses its class skills (the priest heals and buffs the hero) and
## shares EXP. Monsters attack it like the hero; when it falls it gets back up
## after a while.

var member: Dictionary = {}
var index := 0
var hero: Hero
var field: Node3D
var visual: HeroVisual
var stats: Dictionary = {}
var data: Dictionary = {}
var target: Mob
var mp := 0.0
var cooldowns: Dictionary = {}

var _facing := 0.0
var _attack_timer := 0.5
var _cast_until := 0
var _combo := 0
var _think := 0.0
var _buff_until := 0
var _buff_mult := 1.0
var _label: Label3D
var _equip_sig := ""
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
const POTION_STOCK := 5
const MP_POTION_STOCK := 3

var damage_dealt := 0
var _potion_cd := 0.0
var hp := 1
var max_hp := 1
var _dead := false
var _revive_timer := 0.0
var _invulnerable_until := 0
var _since_hurt := 99.0
var _bar: FieldHpBar


func setup(p_member: Dictionary, p_index: int, p_hero: Hero, p_field: Node3D) -> void:
	member = p_member
	index = p_index
	hero = p_hero
	field = p_field


func _ready() -> void:
	add_to_group("companions")
	collision_layer = 0
	collision_mask = 1 << 0
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	visual = HeroVisual.new()
	add_child(visual)
	visual.setup(StringName(member["class"]), "", true, Game.party_equip(member))
	_equip_sig = _signature()
	MeshKit.blob_shadow(self, 0.8)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0046
	_label.font_size = 44
	_label.outline_size = 12
	_label.modulate = Color("8ff0ff")
	_label.position = Vector3(0, 2.75, 0)
	_label.visibility_range_end = 30.0
	add_child(_label)
	_bar = FieldHpBar.new()
	_bar.position = Vector3(0, 3.05, 0)
	_bar.visible = false
	add_child(_bar)
	refresh()
	hp = max_hp
	mp = float(stats.max_mp)
	Game.party_changed.connect(refresh)


func _signature() -> String:
	return "%s|%d" % [member.name, int(member.level) / 3]


func refresh() -> void:
	if not is_instance_valid(visual):
		return
	stats = HeroStats.compute(Game.party_profile(member))
	var pp := Game.party_profile(member)
	data = JobData.resolve(StringName(member["class"]), StringName(pp.job), bool(pp.job3))
	_label.text = "%s Lv.%d" % [member.name, int(member.level)]
	var sig := _signature()
	if sig != _equip_sig:
		_equip_sig = sig
		visual.set_equipment(Game.party_equip(member))
	mp = minf(mp, float(stats.max_mp))
	var ratio := float(hp) / float(max_hp) if max_hp > 0 else 1.0
	max_hp = int(stats.max_hp)
	hp = clampi(int(round(ratio * max_hp)), 1 if not _dead else 0, max_hp)
	_update_bar()


func is_dead() -> bool:
	return _dead


func _update_bar() -> void:
	if _bar:
		_bar.set_ratio(float(hp) / float(maxi(1, max_hp)))
		_bar.visible = hp < max_hp and not _dead


## Monsters hit companions just like the hero.
func take_damage(raw: float, _attacker: Node = null) -> void:
	if _dead or Time.get_ticks_msec() < _invulnerable_until or hero.safe_zone:
		return
	if randf() < float(stats.dodge):
		BattleVfx.floating_text(field, global_position + Vector3(0, 2.4, 0), "หลบ!", Color("9fe8ff"), 0.8)
		return
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(stats.def)))))
	hp = maxi(0, hp - amount)
	_since_hurt = 0.0
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.4, 0), str(amount), Color("ff7a8a"), 1.0)
	visual.flash()
	_update_bar()
	if Time.get_ticks_msec() >= _cast_until:
		visual.action("Hit_A", 1.2)
	if hp <= 0:
		_die()


## Drinks its own potions when low (they are restocked for free in the village).
func _use_potions() -> void:
	if hero.safe_zone:
		member["potions"] = POTION_STOCK
		member["mp_potions"] = MP_POTION_STOCK
		return
	if _potion_cd > 0.0 or Time.get_ticks_msec() < _cast_until:
		return
	var hp_threshold := 0.55 if String(member.get("trait", "")) == "careful" else 0.35
	var hp_left := int(member.get("potions", POTION_STOCK))
	var mp_left := int(member.get("mp_potions", MP_POTION_STOCK))
	if hp_left > 0 and float(hp) / float(max_hp) < hp_threshold:
		member["potions"] = hp_left - 1
		_potion_cd = 6.0
		heal_fraction(0.4)
		BattleVfx.floating_text(field, global_position + Vector3(0, 3.1, 0), "ดื่มยา!", Color("ff8a9a"), 0.9)
		AudioManager.play_sfx(&"heal", -4.0)
	elif mp_left > 0 and mp < float(stats.max_mp) * 0.2:
		member["mp_potions"] = mp_left - 1
		_potion_cd = 6.0
		mp = minf(float(stats.max_mp), mp + float(stats.max_mp) * 0.5)
		BattleVfx.floating_text(field, global_position + Vector3(0, 3.1, 0), "ดื่มยามานา!", Color("7ab0ff"), 0.9)
		AudioManager.play_sfx(&"heal", -4.0)


func heal_fraction(fraction: float) -> void:
	if _dead:
		return
	var before := hp
	hp = mini(max_hp, hp + int(float(max_hp) * fraction))
	if hp > before:
		VfxKit.heal(field, global_position)
		BattleVfx.floating_text(field, global_position + Vector3(0, 2.6, 0), "+%d" % (hp - before), Color("6dff9a"), 0.9)
	_update_bar()


func _die() -> void:
	_dead = true
	target = null
	_revive_timer = 14.0
	visual.hold_last_frame("Death_A")
	_label.text = "%s ล้มแล้ว..." % member.name
	_bar.visible = false
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.8, 0), "ล้มแล้ว!", Color("ff7a8a"), 1.2)
	Game.say("%s ล้มแล้ว! จะลุกขึ้นมาใน %d วินาที" % [member.name, int(_revive_timer)], &"warning")


func _revive() -> void:
	_dead = false
	hp = int(float(max_hp) * 0.6)
	_invulnerable_until = Time.get_ticks_msec() + 2500
	visual.release()
	visual.play("Idle")
	global_position = hero.global_position + Vector3(3.0, 0.3, -0.6).rotated(Vector3.UP, hero.camera_rig.yaw if hero.camera_rig else 0.0)
	_label.text = "%s Lv.%d" % [member.name, int(member.level)]
	VfxKit.level_up(field, global_position)
	BattleVfx.floating_text(field, global_position + Vector3(0, 3.0, 0), "กลับมาสู้!", Color("8ff0ff"), 1.2)
	_update_bar()


func level_up_fx() -> void:
	VfxKit.level_up(field, global_position)
	BattleVfx.floating_text(field, global_position + Vector3(0, 3.1, 0), "เลเวลอัป!", Color("8ff0ff"), 1.3)
	refresh()


func _physics_process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or stats.is_empty():
		return
	if _dead:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
		move_and_slide()
		_revive_timer -= delta
		if _revive_timer <= 0.0 and not hero.is_dead():
			_revive()
		return
	_since_hurt += delta
	_potion_cd = maxf(0.0, _potion_cd - delta)
	_use_potions()
	var regen := 0.03 if hero.safe_zone else (0.012 if _since_hurt > 5.0 else 0.0)
	if regen > 0.0 and hp < max_hp:
		hp = mini(max_hp, hp + maxi(1, int(float(max_hp) * regen * delta)))
		_update_bar()
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_think -= delta
	mp = minf(float(stats.max_mp), mp + float(stats.max_mp) * 0.02 * delta)
	for id in cooldowns.keys():
		cooldowns[id] = maxf(0.0, float(cooldowns[id]) - delta)
	var casting := Time.get_ticks_msec() < _cast_until
	var desired := Vector3.ZERO
	if _think <= 0.0:
		_think = 0.35
		target = _pick_target()
	if not casting:
		if target != null and is_instance_valid(target) and not target.is_dead() and not hero.safe_zone:
			desired = _fight(delta)
		else:
			desired = _follow(delta)
	velocity.x = lerpf(velocity.x, desired.x, 1.0 - exp(-14.0 * delta))
	velocity.z = lerpf(velocity.z, desired.z, 1.0 - exp(-14.0 * delta))
	velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	if speed > 0.6:
		visual.play("Running_A", 0.12, clampf(speed / 5.4, 0.8, 1.5))
	else:
		visual.play("Idle")


func _pick_target() -> Mob:
	if hero.safe_zone:
		return null
	var stance := String(member.get("stance", "follow"))
	var best: Mob = null
	if stance == "aggressive":
		# Goes after any monster near itself, within reach of the hero.
		var near_d := 16.0
		for node in get_tree().get_nodes_in_group("mobs"):
			var m := node as Mob
			if m and not m.is_dead() and _flat(m.global_position - hero.global_position).length() < 24.0:
				var dd := _flat(m.global_position - global_position).length()
				if dd < near_d:
					near_d = dd
					best = m
		if best:
			return best
	elif stance == "guard":
		# Only helps with what is attacking the hero.
		if hero.target != null and is_instance_valid(hero.target) and not hero.target.is_dead() and hero.target.hostile:
			return hero.target
		var guard_d := 7.0
		for node in get_tree().get_nodes_in_group("mobs"):
			var m := node as Mob
			if m and not m.is_dead() and m.hostile:
				var dd := _flat(m.global_position - hero.global_position).length()
				if dd < guard_d:
					guard_d = dd
					best = m
		return best
	if hero.target != null and is_instance_valid(hero.target) and not hero.target.is_dead() \
			and _flat(hero.target.global_position - global_position).length() < 28.0:
		return hero.target
	var best_d := 13.0
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob == null or mob.is_dead():
			continue
		var d := _flat(mob.global_position - hero.global_position).length()
		if d < best_d and (mob.hostile or d < 7.0):
			best_d = d
			best = mob
	return best


func _follow(delta: float) -> Vector3:
	# Beside the hero (seen from the camera), never between camera and hero.
	var side := -1.0 if index == 0 else 1.0
	var yaw := hero.camera_rig.yaw if hero.camera_rig else hero._facing
	var offset := Vector3(side * 3.0, 0, -0.6).rotated(Vector3.UP, yaw)
	var spot := hero.global_position + offset
	var to := _flat(spot - global_position)
	if to.length() > 30.0:
		global_position = spot + Vector3(0, 0.3, 0)
		return Vector3.ZERO
	if to.length() < 0.7:
		return Vector3.ZERO
	_face(to, delta, 12.0)
	var speed := float(stats.speed) * (1.35 if to.length() > 5.0 else 1.0)
	return to.normalized() * minf(speed, to.length() * 6.0)


func _fight(delta: float) -> Vector3:
	var attack: Dictionary = data.attack
	var to := _flat(target.global_position - global_position)
	var distance := to.length() - target.body_radius()
	var reach := float(attack.range) * 0.85
	_face(to, delta, 18.0)
	# Careful companions back off towards the hero when badly hurt.
	if String(member.get("trait", "")) == "careful" and float(hp) / float(max_hp) < 0.3 and not hero.is_dead():
		var back := _flat(hero.global_position - global_position)
		if back.length() > 2.5:
			_face(back, delta, 14.0)
			return back.normalized() * float(stats.speed) * 1.2
	if distance > reach:
		return to.normalized() * float(stats.speed) * 1.05
	if _try_skills(to.length()):
		return Vector3.ZERO
	if _attack_timer <= 0.0:
		_basic_attack()
	return Vector3.ZERO


func _face(direction: Vector3, delta: float, rate: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	_facing = lerp_angle(_facing, atan2(direction.x, direction.z), 1.0 - exp(-rate * delta))
	visual.rotation.y = _facing


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v


# ---------------------------------------------------------------------------
# Attacks
# ---------------------------------------------------------------------------

func _buffed_atk() -> float:
	return float(stats.atk) * (_buff_mult if Time.get_ticks_msec() < _buff_until else 1.0)


func _basic_attack() -> void:
	var attack: Dictionary = data.attack
	_attack_timer = float(attack.interval) * 1.05
	var anims: Array = attack.anims
	var clip: String = anims[_combo % anims.size()]
	_combo += 1
	visual.action(clip, maxf(visual.anim.get_animation(clip).length / (float(attack.interval) * 0.9), 1.0) if visual.has_clip(clip) else 1.0)
	_cast_until = Time.get_ticks_msec() + int(float(attack.hit_delay) * 1000.0) + 60
	var mob := target
	var color: Color = attack.get("color", Color.WHITE)
	get_tree().create_timer(float(attack.hit_delay)).timeout.connect(func():
		if not is_instance_valid(mob) or mob.is_dead() or not is_instance_valid(self):
			return
		if bool(attack.projectile):
			_shoot(mob, float(attack.mult), color, attack.vfx, null)
		else:
			_deal(mob, float(attack.mult), color, attack.vfx, true, null)
	, CONNECT_ONE_SHOT)


func _shoot(mob: Mob, mult: float, color: Color, vfx: StringName, skill: Variant) -> void:
	var from := global_position + Vector3(0, 1.3, 0) + Vector3(sin(_facing), 0, cos(_facing)) * 0.6
	var to := mob.hit_point()
	var flight := clampf(from.distance_to(to) / 22.0, 0.1, 0.5)
	if String(member["class"]) == "archer":
		VfxKit.arrow(field, color, from, to, flight)
	else:
		VfxKit.projectile(field, color, from, to, flight, 0.35, VfxKit.variant_for(vfx))
	get_tree().create_timer(flight).timeout.connect(func():
		if is_instance_valid(mob) and not mob.is_dead():
			_deal(mob, mult, color, vfx, false, skill)
	, CONNECT_ONE_SHOT)


func _deal(mob: Mob, mult: float, color: Color, _vfx: StringName, melee: bool, skill: Variant) -> void:
	var raw := _buffed_atk() * mult * randf_range(0.92, 1.08)
	var crit := randf() < float(stats.crit)
	if crit:
		raw *= HeroStats.CRIT_DAMAGE
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(mob.stats.def)))))
	VfxKit.impact(field, mob.hit_point(), color if color != Color.WHITE else Color("fff0c0"), 1.3 if crit else 0.9)
	damage_dealt += amount
	var killed := mob.take_hit(amount, crit, color, self)
	if killed:
		return
	if melee:
		mob.knock_back(global_position, 2.5)
	if skill is Dictionary:
		var fx: Dictionary = skill.get("fx", {})
		if fx.has("stun"):
			mob.apply_stun(float(fx.stun))
		if fx.has("slow"):
			mob.apply_slow(float(fx.slow))
		if fx.has("burn"):
			mob.apply_burn(_buffed_atk() * float(fx.burn[0]), float(fx.burn[1]))


func _mobs_near(center: Vector3, radius: float) -> Array[Mob]:
	var out: Array[Mob] = []
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and not mob.is_dead() and _flat(mob.global_position - center).length() <= radius + mob.body_radius():
			out.append(mob)
	return out


# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------

## Picks a skill worth using right now. Returns true when one was started.
func _try_skills(distance: float) -> bool:
	if Time.get_ticks_msec() < _cast_until:
		return false
	var hero_hp := float(Game.profile.hp) / float(maxi(1, hero.stats.max_hp))
	var skills: Array = data.skills
	var best: Dictionary = {}
	var best_score := 0.0
	for skill in skills:
		if int(skill.level) > int(member.level) or float(cooldowns.get(skill.id, 0.0)) > 0.0 or mp < float(skill.mp):
			continue
		var score := _score(skill, distance, hero_hp)
		if score > best_score:
			best_score = score
			best = skill
	if best.is_empty():
		return false
	_cast(best)
	return true


func _score(skill: Dictionary, distance: float, hero_hp: float) -> float:
	var fx: Dictionary = skill.get("fx", {})
	match String(skill.shape):
		"self":
			if fx.has("heal") and (hero_hp < 0.55 or float(hp) / float(max_hp) < 0.45):
				return 10.0
			if fx.has("buff") and not fx.has("heal") and Time.get_ticks_msec() >= _buff_until and hero.target != null:
				return 6.0
			if fx.has("buff") and fx.has("heal") and hero_hp < 0.7:
				return 8.0
			return 0.0
		"burst":
			var n := _mobs_near(global_position, float(skill.radius)).size()
			return 3.0 + n * 1.5 if n >= 2 else 0.0
		"blast":
			var n := _mobs_near(target.global_position, float(skill.radius)).size()
			if distance > float(skill.range):
				return 0.0
			return 3.0 + n * 1.5 if n >= 2 else 1.0
		_:
			if distance > float(skill.get("range", 3.0)):
				return 0.0
			return 2.5 + float(skill.get("mult", 1.0)) * 0.2


func _cast(skill: Dictionary) -> void:
	mp -= float(skill.mp)
	cooldowns[skill.id] = float(skill.cd) * 1.15
	var delay := float(skill.hit_delay)
	visual.action(skill.anim, 1.0)
	_cast_until = Time.get_ticks_msec() + int(delay * 1000.0) + 90
	_attack_timer = maxf(_attack_timer, delay + 0.2)
	var color: Color = skill.color
	var aim := target.global_position if target and is_instance_valid(target) else global_position + Vector3(sin(_facing), 0, cos(_facing)) * 4.0
	var snapshot := target
	if skill.shape == "blast":
		VfxKit.ground_circle(field, Vector3(aim.x, global_position.y, aim.z), color, float(skill.radius), delay + 0.2)
	elif skill.shape == "burst":
		VfxKit.ground_circle(field, global_position, color, float(skill.radius) * 0.5, delay)
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.9, 0), String(skill.name), color, 0.5)
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(self):
			_resolve(skill, snapshot, aim)
	, CONNECT_ONE_SHOT)


func _resolve(skill: Dictionary, mob: Mob, aim: Vector3) -> void:
	var color: Color = skill.color
	var mult := float(skill.get("mult", 0.0))
	var origin := global_position + Vector3(0, 1.3, 0)
	var forward := Vector3(sin(_facing), 0, cos(_facing))
	var alive := is_instance_valid(mob) and not mob.is_dead()
	var show_center := global_position
	if alive and String(skill.shape) in ["single", "chain", "fan", "blast"]:
		show_center = Vector3(mob.global_position.x, 0.0, mob.global_position.z)
	SkillShow.play(field, skill, show_center, global_position, null)
	match String(skill.shape):
		"self":
			_apply_self(skill)
		"single":
			if not alive:
				return
			if bool(skill.get("projectile", false)):
				_shoot(mob, mult, color, skill.vfx, skill)
			else:
				VfxKit.slash_arc(field, global_position + forward * 1.2 + Vector3(0, 1.0, 0), _facing, color, 3.0, -0.4)
				_deal(mob, mult, color, skill.vfx, true, skill)
		"fan":
			var list := _mobs_near(global_position, float(skill.range))
			if alive:
				list.erase(mob)
				list.push_front(mob)
			for i in mini(int(skill.hits), list.size()):
				_shoot(list[i], mult, color, skill.vfx, skill)
		"chain":
			var hit: Array[Mob] = []
			var current: Mob = mob if alive else null
			var from := origin + forward * 0.8
			for i in int(skill.hits):
				if current == null or not is_instance_valid(current) or current.is_dead():
					break
				VfxKit.lightning(field, from, current.hit_point(), color)
				_deal(current, mult * pow(0.85, i), color, skill.vfx, false, skill)
				hit.append(current)
				from = current.hit_point()
				var next: Mob = null
				var best := 7.0
				for other in _mobs_near(current.global_position, 7.0):
					if not hit.has(other) and other.global_position.distance_to(current.global_position) < best:
						best = other.global_position.distance_to(current.global_position)
						next = other
				current = next
		"burst":
			var radius := float(skill.radius)
			VfxKit.shockwave(field, global_position + Vector3(0, 0.15, 0), color, radius * 1.15)
			for victim in _mobs_near(global_position, radius + 0.6):
				_deal(victim, mult, color, skill.vfx, true, skill)
			var fx: Dictionary = skill.get("fx", {})
			if fx.has("heal"):
				hero.receive_heal(float(fx.heal) * 0.6)
				heal_fraction(float(fx.heal) * 0.6)
		"blast":
			var center := Vector3(aim.x, 0.0, aim.z)
			if alive:
				center = Vector3(mob.global_position.x, 0.0, mob.global_position.z)
			var radius := float(skill.radius)
			if skill.vfx == &"fireball":
				VfxKit.meteor(field, center, color, 0.5, radius, func(): _blast(skill, center, radius, mult))
			else:
				VfxKit.shockwave(field, center + Vector3(0, 0.1, 0), color, radius)
				if skill.vfx == &"light":
					for i in 5:
						var a := i * TAU / 5.0
						VfxKit.pillar(field, center + Vector3(cos(a), 0, sin(a)) * radius * 0.6, color, 7.0, 0.7, 0.7)
				_blast(skill, center, radius, mult)


func _blast(skill: Dictionary, center: Vector3, radius: float, mult: float) -> void:
	for victim in _mobs_near(center, radius):
		_deal(victim, mult, skill.color, skill.vfx, true, skill)


func _apply_self(skill: Dictionary) -> void:
	var fx: Dictionary = skill.get("fx", {})
	var color: Color = skill.color
	if fx.has("heal"):
		hero.receive_heal(float(fx.heal))
		heal_fraction(float(fx.heal))
		VfxKit.heal(field, global_position, color)
	if fx.has("buff"):
		var buff: Dictionary = fx.buff
		hero.receive_buff(buff, color, String(skill.name))
		_buff_until = Time.get_ticks_msec() + int(float(buff.secs) * 1000.0)
		_buff_mult = 1.0 + float(buff.get("atk", 0.0))
		VfxKit.aura(field, global_position, color)
