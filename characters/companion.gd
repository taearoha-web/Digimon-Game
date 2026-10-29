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
var _book := BuffBook.new()
var _label: Label3D
var _equip_sig := ""
## The class the body was built for (a world player changes job at Lv.10).
var _built_class: StringName = &""
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
var _summons: Array = []
var _slow_until := 0
const SUMMON_LIMIT := 3


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
	_built_class = StringName(member["class"])
	visual.setup(_built_class, "", true, _party_equip(), _visual_look())
	_equip_sig = _signature()
	MeshKit.blob_shadow(self, 0.8)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0046 * BattleVfx.text_scale
	_label.font_size = 44
	_label.outline_size = 12
	_label.modulate = Color("8ff0ff")
	_label.position = Vector3(0, 2.75, 0)
	_label.visibility_range_end = 30.0
	_label.no_depth_test = true
	_label.render_priority = 2
	add_child(_label)
	_bar = FieldHpBar.new()
	_bar.position = Vector3(0, 3.05, 0)
	_bar.visible = false
	add_child(_bar)
	refresh()
	hp = max_hp
	mp = float(stats.max_mp)
	Game.party_changed.connect(refresh)
	_sync_raven()


## An AI Dark Lord's raven always joins its fights, hunting on its own (auto).
func _sync_raven() -> void:
	if _built_class == &"darklord":
		DarkRaven.ensure(self).attack = true
	else:
		DarkRaven.remove(self)


## Hook for the field-side announcement of a job change (FieldPlayer).
func _class_changed() -> void:
	pass


func _signature() -> String:
	return "%s|%d|%d" % [member.name, int(member.level) / 3, Game.party_stars(member) / 10]


func _level_text() -> String:
	var stars := Game.party_stars(member)
	return "%s Lv.%d%s" % [member.name, int(member.level), " ★%d" % stars if stars > 0 else ""]


func refresh() -> void:
	if not is_instance_valid(visual):
		return
	var pp := _party_profile()
	stats = HeroStats.compute(pp)
	data = JobData.resolve(StringName(member["class"]), int(pp.adv))
	_label.text = _level_text()
	var sig := _signature()
	if StringName(member["class"]) != _built_class:
		# The Lv.10 job change of a world player: the new body, weapon and companion pet.
		_built_class = StringName(member["class"])
		_equip_sig = sig
		visual.setup(_built_class, "", true, _party_equip(), _visual_look())
		_sync_raven()
		_class_changed()
	elif sig != _equip_sig:
		_equip_sig = sig
		visual.set_equipment(_party_equip())
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
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(stats.def) * (1.0 + _book.total("def"))))))
	amount = BuffBook.absorb(_book.buffs,amount)
	hp = maxi(0, hp - amount)
	_since_hurt = 0.0
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.4, 0), str(amount), Color("ff7a8a"), 1.0)
	visual.flash()
	_update_bar()
	if Time.get_ticks_msec() >= _cast_until:
		visual.action("Hit_A", 1.2)
	if hp <= 0:
		_die()


## Drinks potions when low, from the hero's bag first (own stock refills free in the village).
func _use_potions() -> void:
	if hero.safe_zone:
		member["potions"] = POTION_STOCK
		member["mp_potions"] = MP_POTION_STOCK
		return
	if _potion_cd > 0.0 or Time.get_ticks_msec() < _cast_until:
		return
	var hp_threshold := 0.55 if String(member.get("trait", "")) == "careful" else 0.35
	# Potions are shared with the hero: the bag first, the companion's own free stock after.
	var hp_left := int(member.get("potions", POTION_STOCK))
	var mp_left := int(member.get("mp_potions", MP_POTION_STOCK))
	if float(hp) / float(max_hp) < hp_threshold:
		var value := Game.take_potion_for_ally("hp", max_hp - hp)
		if value > 0:
			_drink_hp(float(value) / float(max_hp))
		elif hp_left > 0:
			member["potions"] = hp_left - 1
			_drink_hp(0.4)
	elif mp < float(stats.max_mp) * 0.2:
		var value := Game.take_potion_for_ally("mp", int(float(stats.max_mp) - mp))
		if value > 0:
			_drink_mp(float(value))
		elif mp_left > 0:
			member["mp_potions"] = mp_left - 1
			_drink_mp(float(stats.max_mp) * 0.5)


func _drink_hp(fraction: float) -> void:
	_potion_cd = 6.0
	heal_fraction(fraction)
	BattleVfx.floating_text(field, global_position + Vector3(0, 3.1, 0), "ดื่มยา!", Color("ff8a9a"), 0.9)
	AudioManager.play_sfx(&"heal", -4.0)


func _drink_mp(amount: float) -> void:
	_potion_cd = 6.0
	mp = minf(float(stats.max_mp), mp + amount)
	BattleVfx.floating_text(field, global_position + Vector3(0, 3.1, 0), "ดื่มยามานา!", Color("7ab0ff"), 0.9)
	AudioManager.play_sfx(&"heal", -4.0)


## A boss or a legend summon mires the companion: half speed for a while.
func apply_slow(seconds: float) -> void:
	if _dead:
		return
	_slow_until = maxi(_slow_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func _summons_alive(skill_id: String) -> int:
	_summons = _summons.filter(func(s): return is_instance_valid(s) and not s.is_dead())
	var n := 0
	for s in _summons:
		if s.skill_id == skill_id:
			n += 1
	return n


## Calls the skill's creatures beside the companion (the same skill's earlier ones are replaced).
func _summon(skill: Dictionary, mult: float) -> void:
	var spec: Dictionary = skill.summon
	_summons = _summons.filter(func(s): return is_instance_valid(s) and not s.is_dead())
	for old in _summons.duplicate():
		if old.skill_id == skill.id:
			old.queue_free()
			_summons.erase(old)
	var count := int(spec.get("count", 1))
	var p_rank := maxi(1, int(_party_profile().get("skills", {}).get(skill.id, 1)))
	for i in count:
		if _summons.size() >= SUMMON_LIMIT:
			break
		var s := Summon.new()
		s.setup(self, String(skill.id), spec, mult * HeroStats.SKILL_POWER, i, count, p_rank)
		field.add_child(s)
		_summons.append(s)


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
	_label.text = _level_text()
	VfxKit.level_up(field, global_position)
	BattleVfx.floating_text(field, global_position + Vector3(0, 3.0, 0), "กลับมาสู้!", Color("8ff0ff"), 1.2)
	_update_bar()


func level_up_fx() -> void:
	VfxKit.level_up(field, global_position)
	BattleVfx.floating_text(field, global_position + Vector3(0, 3.1, 0), "เลเวลอัป!", Color("8ff0ff"), 1.3)
	refresh()


## A buff cast by the hero reaches the companion too.
func receive_party_buff(buff: Dictionary, color: Color, label := "", skill_id := "") -> void:
	var prepared := buff.duplicate()
	if prepared.has("shield"): prepared["shield_left"]=int(max_hp*float(prepared.shield))
	_book.add(prepared, color, label, true, skill_id)
	# Persistent buff halo and the skill silhouette carry this feedback.


func _physics_process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or stats.is_empty():
		return
	# A broken move (NaN) puts the companion back beside the hero instead of poisoning the
	# camera, the minimap and every distance check that looks at it.
	if not global_position.is_finite() or not velocity.is_finite():
		velocity = Vector3.ZERO
		global_position = hero.global_position + Vector3(1.5, 0.2, 0.0) if hero.global_position.is_finite() else Vector3.ZERO
	_book.tick(self, not _dead, func(): return BuffAura.measure_top(visual, self))
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
		visual.play(_rest_anim())


## The clip it stands still in (a stall keeper may sit).
func _rest_anim() -> String:
	return "Idle"


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
	# Beside the hero (seen from the camera), never between camera and hero: left, right,
	# then a step ahead on either side for the third and fourth party members.
	var spots := [Vector3(-3.0, 0, -0.6), Vector3(3.0, 0, -0.6), Vector3(-2.2, 0, -3.6), Vector3(2.2, 0, -3.6)]
	var yaw := hero.camera_rig.yaw if hero.camera_rig else hero._facing
	var offset: Vector3 = (spots[index % spots.size()] as Vector3).rotated(Vector3.UP, yaw)
	var spot := hero.global_position + offset
	var to := _flat(spot - global_position)
	if to.length() > 30.0:
		global_position = spot + Vector3(0, 0.3, 0)
		return Vector3.ZERO
	if to.length() < 0.7:
		return Vector3.ZERO
	_face(to, delta, 12.0)
	var speed := float(stats.speed) * (1.35 if to.length() > 5.0 else 1.0) * (1.0 + _book.total("speed"))
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


# Whom the companion looks after is the hero; a world player (FieldPlayer) answers
# these for itself.
func _visual_look() -> Dictionary:
	return Game.party_look(member)


func _party_profile() -> Dictionary:
	return Game.party_profile(member)


func _party_equip() -> Dictionary:
	return Game.party_equip(member)


## The HP share of whoever the companion protects.
func _ally_hp_ratio() -> float:
	return float(Game.profile.hp) / float(maxi(1, hero.stats.max_hp))


## Whether there is a fight worth a buff or a summon.
func _in_combat() -> bool:
	return hero.target != null


func _heal_allies(fraction: float) -> void:
	hero.receive_heal(fraction)


func _buff_allies(buff: Dictionary, color: Color, label: String, skill_id: String) -> void:
	hero.receive_buff(buff, color, label, true, skill_id)
	# A Bard's song reaches the whole party: the other members and every summon too
	# (other buffs stay the hero's, as they always were).
	if not BuffBook.is_song(buff) or not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("companions") + get_tree().get_nodes_in_group("summons"):
		if node != self and is_instance_valid(node) and node.has_method("receive_party_buff") and not node.is_dead():
			node.receive_party_buff(buff, color, label, skill_id)


## The song the party plays (the hero's song slot holds it), or {}.
func _song_entry() -> Dictionary:
	return hero.song_entry()


func _song_left() -> float:
	return hero.song_left()


## Whether the song playing is the hero's own: an AI Bard never sings over a player's song.
func _hero_sings() -> bool:
	var song := _song_entry()
	return not song.is_empty() and not bool(song.get("ally", false))


# ---------------------------------------------------------------------------
# Attacks
# ---------------------------------------------------------------------------

func _buffed_atk() -> float:
	return float(stats.atk) * (1.0 + _book.total("atk"))


func _basic_attack() -> void:
	var attack: Dictionary = data.attack
	_attack_timer = float(attack.interval) * 1.05
	var anims: Array = attack.anims
	var clip: String = anims[_combo % anims.size()]
	_combo += 1
	visual.action(clip, maxf(visual.anim.get_animation(clip).length / (float(attack.interval) * 0.9), 1.0) if visual.has_clip(clip) else 1.0)
	_cast_until = Time.get_ticks_msec() + int(float(attack.hit_delay) * 1000.0) + 60
	var mob_ref: WeakRef = weakref(target)
	var color: Color = attack.get("color", Color.WHITE)
	get_tree().create_timer(float(attack.hit_delay)).timeout.connect(func():
		var mob: Mob = mob_ref.get_ref() as Mob
		if mob == null or mob.is_dead() or not is_instance_valid(self):
			return
		if bool(attack.projectile):
			_shoot(mob, float(attack.mult), color, attack.vfx, null)
		else:
			_deal(mob, float(attack.mult), color, attack.vfx, true, null)
	, CONNECT_ONE_SHOT)


func _judgment_hit(victim: Node3D, skill: Dictionary) -> void:
	if victim is Mob and is_instance_valid(victim) and not victim.is_dead():
		_deal(victim, float(skill.mult), skill.color, skill.vfx, false, skill)


func _shoot(mob: Mob, mult: float, color: Color, vfx: StringName, skill: Variant) -> void:
	var from := visual.skill_emission_position() if skill is Dictionary else global_position + Vector3(0, 1.3, 0) + Vector3(sin(_facing), 0, cos(_facing)) * 0.6
	var to := mob.hit_point()
	var flight := clampf(from.distance_to(to) / 22.0, 0.1, 0.5)
	if skill is Dictionary and not skill.is_empty():
		SkillTableau.flight(field, skill, from, to, flight, 0.85)
	elif String(member["class"]) == "archer":
		VfxKit.arrow(field, color, from, to, flight)
	else:
		VfxKit.projectile(field, color, from, to, flight, 0.35, VfxKit.variant_for(vfx))
	var mob_ref: WeakRef = weakref(mob)
	get_tree().create_timer(flight).timeout.connect(func():
		var victim: Mob = mob_ref.get_ref() as Mob
		if victim != null and not victim.is_dead():
			_deal(victim, mult, color, vfx, false, skill)
	, CONNECT_ONE_SHOT)


func _deal(mob: Mob, mult: float, color: Color, _vfx: StringName, melee: bool, skill: Variant) -> void:
	var raw := _buffed_atk() * mult * randf_range(0.92, 1.08)
	if skill is Dictionary and not skill.is_empty():
		raw *= HeroStats.SKILL_POWER
	var crit := randf() < float(stats.crit) + _book.total("crit")
	if crit:
		raw *= HeroStats.CRIT_DAMAGE
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(mob.stats.def)))))
	if skill is Dictionary and not skill.is_empty():
		SkillTableau.contact(field, skill, mob.hit_point(), crit)
	else:
		VfxKit.impact(field, mob.hit_point(), color if color != Color.WHITE else Color("fff0c0"), 1.3 if crit else 0.9)
	damage_dealt += amount
	var killed := mob.take_hit(amount, crit, color, self)
	if killed:
		return
	if melee:
		mob.knock_back(global_position, 2.5)
	if skill is Dictionary:
		var fx: Dictionary = skill.get("fx", {})
		if fx.has("repel"):
			mob.shove_out(global_position, Mob.REPEL_DISTANCE)
		if fx.has("stun"):
			mob.apply_stun(float(fx.stun))
		if fx.has("taunt") and mob.has_method("taunt"):
			# A Defender companion draws the fight off the hero.
			mob.taunt(self, float(fx.taunt))
		if fx.get("shred") is Array:
			mob.apply_shred(float(fx.shred[0]), float(fx.shred[1]))
		if fx.get("weaken") is Array:
			mob.apply_weaken(float(fx.weaken[0]), float(fx.weaken[1]))
		if fx.has("slow"):
			mob.apply_slow(float(fx.slow))
		if fx.has("burn"):
			mob.apply_burn(HeroStats.burn_dps(_buffed_atk(), float(fx.burn[0]), float(mob.stats.def)), float(fx.burn[1]))
			mob.burn_source = self


## The raven goes for this member's target while it fights (DarkRaven).
func raven_target() -> Mob:
	if _dead or not is_instance_valid(target) or target.is_dead():
		return null
	return target if _flat(target.global_position - global_position).length() <= 16.0 else null


func raven_strike(mob: Mob, group := false) -> void:
	if _dead or not is_instance_valid(mob) or mob.is_dead():
		return
	if group:
		for other in DarkRaven.pack(get_tree(), mob.global_position, DarkRaven.GROUP_RADIUS):
			_deal(other, Hero.RAVEN_MULT * Hero.GROUP_SHARE, DarkRaven.VIOLET, &"slash", false, null)
		return
	_deal(mob, Hero.RAVEN_MULT, DarkRaven.VIOLET, &"slash", false, null)


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
	var hero_hp := _ally_hp_ratio()
	var skills: Array = data.skills
	var best: Dictionary = {}
	var best_score := 0.0
	for skill in skills:
		if skill.has("star") or int(skill.level) > int(member.level) + 9 or ClassData.skill_tier(skill) > _tier() or float(cooldowns.get(skill.id, 0.0)) > 0.0 or mp < float(skill.mp):
			continue
		var score := _score(skill, distance, hero_hp)
		if score > best_score:
			best_score = score
			best = skill
	if best.is_empty():
		return false
	_cast(best)
	return true


## Companions advance on their own: job at Lv.20, master at Lv.40.
func _tier() -> int:
	return 1 + JobData.adv_for_level(int(member.level))


func _score(skill: Dictionary, distance: float, hero_hp: float) -> float:
	var fx: Dictionary = skill.get("fx", {})
	if BuffBook.is_song_skill(skill):
		return _song_score(skill, hero_hp)
	var score := _shape_score(skill, distance, hero_hp)
	# A marking skill (shred / weaken) opens the fight while the target is unmarked,
	# and waits behind the other skills while its marks are still up.
	if Mob.carries_mark(fx) and _mark_in_reach(skill, distance):
		if Mob.lacks_mark(target, fx, 1.0):
			return maxf(score, 6.5) + (0.5 if target.is_boss else 0.0)
		return maxf(0.5, score - 2.0)
	return score


## A song for the party: never over the player's own song or over one with 10 s
## left (two AI Bards do not take turns), the strongest attack song first in a fight,
## and a healing song at once when the hero is badly hurt.
func _song_score(skill: Dictionary, hero_hp: float) -> float:
	var fx: Dictionary = skill.fx
	if _hero_sings():
		return 0.0
	if fx.has("heal") and hero_hp < 0.45 and BuffBook.identity(_song_entry()) != String(skill.id):
		return 10.0
	if _song_left() >= 10.0 or not _in_combat():
		return 0.0
	return 7.0 + float(fx.buff.get("atk", 0.0)) + 0.5 * float(fx.buff.get("crit", 0.0)) + 0.001 * float(member.get("level", 1))


## Whether a marking skill would reach the target now (a burst needs a monster in its ring).
func _mark_in_reach(skill: Dictionary, distance: float) -> bool:
	if target == null or not is_instance_valid(target) or target.is_dead():
		return false
	if String(skill.shape) == "burst":
		return not _mobs_near(global_position, float(skill.radius)).is_empty()
	return distance <= float(skill.get("range", 3.0))


## How far a party member may drift from the hero before an AI Dark Lord recalls it.
const RECALL_DISTANCE := 22.0


## A party member (this one included) far from the hero, outside the village.
func _straggler() -> bool:
	if hero == null or not is_instance_valid(hero) or hero.safe_zone or hero.is_dead():
		return false
	for node in get_tree().get_nodes_in_group("companions"):
		var ally := node as Node3D
		if is_instance_valid(ally) and ally.global_position.distance_to(hero.global_position) > RECALL_DISTANCE:
			return true
	return false


func _shape_score(skill: Dictionary, distance: float, hero_hp: float) -> float:
	var fx: Dictionary = skill.get("fx", {})
	# Summon (recall) is never a reflex: an AI Dark Lord casts it on purpose, to pull
	# back a party member who has fallen far behind the hero.
	if fx.has("recall"):
		return 9.5 if _straggler() else 0.0
	# A provoke is worth most while the hero is the one being hurt.
	if fx.has("taunt") and hero_hp < 0.6 and distance <= float(skill.get("range", skill.get("radius", 3.0))) + 1.0:
		return 8.5
	match String(skill.shape):
		"summon":
			# A summoner companion fights through its creatures: call them as soon as there is a fight.
			if not _in_combat() or _summons_alive(String(skill.id)) > 0 or _summons.size() >= SUMMON_LIMIT:
				return 0.0
			return 9.0 + float(skill.get("mult", 1.0)) * 0.2
		"self":
			# A stance (self_only) counts as a plain buff even when it also heals: its heal is its own.
			var stance := fx.get("buff") is Dictionary and BuffBook.is_self_only(fx.buff)
			if fx.has("heal") and ((hero_hp < 0.55 and not stance) or float(hp) / float(max_hp) < 0.45):
				return 10.0
			if fx.has("buff") and (not fx.has("heal") or stance) and BuffBook.group_count(_book.buffs, false) < BuffBook.GROUP_LIMIT and not BuffBook.contains(_book.buffs, String(skill.id), false) and _in_combat():
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
	visual.skill_action(skill, delay)
	_cast_until = Time.get_ticks_msec() + int(delay * 1000.0) + 90
	_attack_timer = maxf(_attack_timer, delay + 0.2)
	var color: Color = skill.color
	var aim := target.global_position if target and is_instance_valid(target) else global_position + Vector3(sin(_facing), 0, cos(_facing)) * 4.0
	var snapshot: WeakRef = weakref(target) if is_instance_valid(target) else null
	SkillShow.anticipate(field, skill, global_position, delay, aim, visual)
	var cast_sound := SkillSound.cast(skill)
	if cast_sound != &"skill_start":
		AudioManager.play_sfx(cast_sound, -8.0)
	if String(skill.id) == "judgment_ray":
		JudgmentRaySequence.launch(field, self, target, delay, _judgment_hit.bind(skill), visual)
		return
	if skill.shape == "blast":
		SkillInk.telegraph(field, skill, Vector3(aim.x, global_position.y, aim.z), float(skill.radius), delay + (0.5 if skill.vfx == &"fireball" else 0.0))
	elif skill.shape == "burst":
		SkillInk.telegraph(field, skill, global_position, float(skill.radius), delay)
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.9, 0), String(skill.name), color, 0.5)
	var cast := create_tween()
	cast.tween_interval(delay)
	cast.tween_callback(_finish_cast.bind(skill, snapshot, aim, weakref(field)))


func _finish_cast(skill: Dictionary, target_ref: WeakRef, aim: Vector3, field_ref: WeakRef) -> void:
	var cast_field := field_ref.get_ref() as Node3D
	if _dead or not is_instance_valid(cast_field) or cast_field != field or cast_field.is_queued_for_deletion():
		return
	var mob := target_ref.get_ref() as Mob if target_ref != null else null
	_resolve(skill, mob, aim)


func _resolve(skill: Dictionary, mob: Mob, aim: Vector3) -> void:
	if _dead or not is_instance_valid(field) or field.is_queued_for_deletion():
		return
	var color: Color = skill.color
	if String(skill.id) == "judgment_ray":
		JudgmentRaySequence.launch(field, self, mob, 0.001, _judgment_hit.bind(skill))
		return
	var mult := float(skill.get("mult", 0.0))
	var origin := visual.skill_emission_position()
	var forward := Vector3(sin(_facing), 0, cos(_facing))
	var alive := is_instance_valid(mob) and not mob.is_dead()
	var show_center := global_position
	if alive and String(skill.shape) in ["single", "chain", "fan", "blast"]:
		show_center = Vector3(mob.global_position.x, 0.0, mob.global_position.z)
	if String(skill.id) not in ["armageddon", "thunder_storm"]:
		# Companion fire blasts currently land at 0.5 s; other companion areas
		# resolve immediately. Share the art while respecting that real clock.
		var landing := 0.5 if String(skill.shape) == "blast" and skill.vfx == &"fireball" else 0.0
		SkillShow.play(field, skill, show_center, global_position, landing)
	var landing_sound := SkillSound.landing(skill)
	if landing_sound != &"":
		AudioManager.play_sfx(landing_sound, -8.0)
	match String(skill.shape):
		"self":
			_apply_self(skill)
		"summon":
			_summon(skill, mult)
		"single":
			if not alive:
				return
			if bool(skill.get("projectile", false)):
				_shoot(mob, mult, color, skill.vfx, skill)
			else:
				_deal(mob, mult, color, skill.vfx, true, skill)
				if skill.has("pierce"):
					var spec: Dictionary = skill.pierce
					for extra in Pierce.victims(get_tree(), global_position, mob.global_position, spec, mob):
						_deal(extra, mult * float(spec.get("k", 0.7)), color, skill.vfx, true, skill)
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
			var from := origin
			for i in int(skill.hits):
				if current == null or not is_instance_valid(current) or current.is_dead():
					break
				SkillTableau.link(field, skill, from, current.hit_point())
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
			for victim in _mobs_near(global_position, radius + 0.6):
				_deal(victim, mult, color, skill.vfx, true, skill)
			var fx: Dictionary = skill.get("fx", {})
			if fx.has("heal"):
				_heal_allies(float(fx.heal) * 0.6)
				heal_fraction(float(fx.heal) * 0.6)
		"blast":
			var center := Vector3(aim.x, 0.0, aim.z)
			if alive:
				center = Vector3(mob.global_position.x, 0.0, mob.global_position.z)
			var radius := float(skill.radius)
			if String(skill.id) == "thunder_storm":
				ThunderStormSequence.launch(field, self, center, radius, _storm_candidates, _storm_hit.bind(skill, mult))
			elif String(skill.id) == "armageddon":
				ArmageddonSequence.launch(field, self, center, radius, mult, _armageddon_impact.bind(skill))
			elif skill.vfx == &"fireball":
				VfxKit.meteor(field, center, color, 0.5, radius, func(): _blast(skill, center, radius, mult), String(skill.id) == "hell_meteor")
			else:
				_blast(skill, center, radius, mult)


func _armageddon_impact(index: int, center: Vector3, radius: float, mult: float, skill: Dictionary) -> void:
	if _dead or not is_instance_valid(field) or field.is_queued_for_deletion():
		return
	_blast(skill, center, radius, mult, index == 0)


func _blast(skill: Dictionary, center: Vector3, radius: float, mult: float, knockback := true) -> void:
	for victim in _mobs_near(center, radius):
		_deal(victim, mult, skill.color, skill.vfx, knockback, skill)


func _apply_self(skill: Dictionary) -> void:
	var fx: Dictionary = skill.get("fx", {})
	var color: Color = skill.color
	if fx.has("recall") and is_instance_valid(hero) and hero.is_inside_tree():
		hero.recall_party()
	if fx.has("heal"):
		# A stance (self_only) keeps its heal to the caster too.
		if not (fx.get("buff") is Dictionary and BuffBook.is_self_only(fx.buff)):
			_heal_allies(float(fx.heal))
		heal_fraction(float(fx.heal))
		VfxKit.heal(field, global_position, color)
	if fx.has("buff"):
		var buff: Dictionary = fx.buff
		# A stance (self_only) stays on the one who cast it.
		if not BuffBook.is_self_only(buff):
			_buff_allies(buff, color, String(skill.name), String(skill.id))
		_book.add(buff, color, String(skill.name), false, String(skill.id))
		# Persistent buff halo and the skill silhouette carry this feedback.


func _storm_candidates() -> Array:
	return get_tree().get_nodes_in_group("mobs")

func _storm_hit(victim: Node3D, skill: Dictionary, mult: float) -> void:
	if victim is Mob and not victim.is_dead():
		_deal(victim, mult, skill.color, skill.vfx, false, skill)
