class_name Hero
extends CharacterBody3D
## The player's hero: moves with the joystick, auto-attacks the locked-on
## monster, casts four class skills and drinks potions. HP / MP live in
## [Game] (profile) so they persist; this node plays them out in 3D.

signal died()
signal target_changed(target: Mob)
signal skill_fired(index: int)
signal message(text: String)
signal auto_changed(on: bool)

const TARGET_RANGE := 16.0
const POTION_COOLDOWN := 1.2

var visual: HeroVisual
var _equip_sig := ""
var _step_timer := 0.0
var _ring_job: StringName = &""
var _ring: MeshInstance3D
var camera_rig: ThirdPersonCamera
var field: Node3D
var safe_zone := false
var field_radius := 56.0

var move_input := Vector2.ZERO
var target: Mob
## Auto-attack mode: keeps hitting the target and picks the next one itself.
var engaged := false
## Auto hunting: fights inside the camp it was switched on in, uses skills and potions.
var auto := false
var _summons: Array = []
var _auto_center := Vector3.ZERO
var _auto_radius := 10.0
var _auto_timer := 0.0
var stats: Dictionary = {}
var cooldowns: Dictionary = {}
var potion_cd := 0.0

var _buffs: Array[Dictionary] = []
var _auras: Dictionary = {} # kind -> BuffAura
var _pending: Dictionary = {}
var _attack_timer := 0.0
var _combo := 0
var _cast_until := 0
var _since_hurt := 99.0
var _regen_hp := 0.0
var _regen_mp := 0.0
var _dead := false
var _invulnerable_until := 0
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
var _facing := 0.0
var _quiet := false
var _buff_emitter: CPUParticles3D


func _ready() -> void:
	add_to_group("hero")
	collision_layer = 1 << 1
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
	visual.setup(Game.class_id(), "", true, Game.profile.equip, Game.profile.get("look", {}))
	_equip_sig = _equipment_signature()
	MeshKit.blob_shadow(self, 0.8)
	refresh_stats()
	Game.profile_changed.connect(refresh_stats)
	Game.inventory_changed.connect(_on_inventory_changed)
	Game.profile_changed.connect(_update_job_ring)
	_update_job_ring()


## Changes the hero's weapon / hat / outfit when the worn items change.
func _on_inventory_changed() -> void:
	var sig := _equipment_signature()
	if sig != _equip_sig:
		_equip_sig = sig
		visual.set_equipment(Game.profile.equip)


## A glowing ring under the feet of a hero who has changed jobs.
func _update_job_ring() -> void:
	var job := StringName("%s|%d" % [Game.class_id(), Game.adv()])
	if job == _ring_job:
		return
	_ring_job = job
	if _ring:
		_ring.queue_free()
		_ring = null
	if Game.adv() <= 0:
		return
	var color: Color = JobData.current(Game.class_id(), Game.adv()).color
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.78
	torus.outer_radius = 0.94
	torus.rings = 36
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring.material_override = MeshKit.toon(color, {"unshaded": true, "emission": 1.0})
	_ring.scale = Vector3(1, 0.12, 1)
	_ring.position = Vector3(0, 0.07, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _equipment_signature() -> String:
	var parts: PackedStringArray = []
	for slot in ["weapon", "armor", "helm", "boots", "amulet", "ring"]:
		var item: Variant = Game.profile.equip.get(slot)
		parts.append((ItemLook.look_of(item) + "|%d|%d" % [int(item.get("plus", 0)), int(item.get("rarity", 0))]) if item is Dictionary else "-")
	return "|".join(parts)


func refresh_stats() -> void:
	var totals := {"atk": 0.0, "def": 0.0, "speed": 0.0, "crit": 0.0}
	var now := Time.get_ticks_msec()
	for buff in _buffs:
		if buff.until > now:
			for key in totals:
				totals[key] += float(buff.get(key, 0.0))
	stats = Game.stats_now(totals)


func is_dead() -> bool:
	return _dead


func facing() -> float:
	return _facing


func set_facing(yaw: float) -> void:
	_facing = yaw
	visual.rotation.y = yaw


## Defence buffs wrap the hero in a green barrier, attack buffs flare a power
## aura, speed buffs spin wind rings and crit buffs scatter sparkles. Each kind
## lives as long as at least one buff of that kind is active.
func _sync_auras(now: int) -> void:
	var wanted := {}
	for buff in _buffs:
		if int(buff.until) <= now or _dead:
			continue
		var color: Color = buff.get("color", Color("ffd84a"))
		if float(buff.get("def", 0.0)) > 0.0:
			wanted["shield"] = Color("5aff9a").lerp(color, 0.3)
		if float(buff.get("atk", 0.0)) > 0.0:
			wanted["power"] = color
		if float(buff.get("speed", 0.0)) > 0.0:
			wanted["wind"] = color
		if float(buff.get("crit", 0.0)) > 0.0:
			wanted["spark"] = color
	for kind in wanted:
		if not _auras.has(kind) or not is_instance_valid(_auras[kind]):
			var aura := BuffAura.new()
			aura.setup(kind, wanted[kind])
			aura.body_top = _body_top()
			add_child(aura)
			_auras[kind] = aura
	for kind in _auras.keys():
		if not wanted.has(kind):
			if is_instance_valid(_auras[kind]):
				(_auras[kind] as Node).queue_free()
			_auras.erase(kind)


## Height from the soles to the highest point of the body (hat / big hair included).
func _body_top() -> float:
	var top := 2.0
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.get_parent() is BuffAura or not mi.is_inside_tree():
			continue
		var box := mi.global_transform * mi.get_aabb()
		top = maxf(top, box.end.y - global_position.y)
	return clampf(top, 2.0, 4.5)


## What the HUD timer bars show: active buffs (own and from allies) and summons,
## each {id, name, color, left, total, kind, ally, count, hp}. [left] counts down in seconds.
func timer_status() -> Array:
	var out: Array = []
	var now := Time.get_ticks_msec()
	var seen := {}
	for buff in _buffs:
		var left := (float(buff.until) - float(now)) / 1000.0
		if left <= 0.0:
			continue
		var key := "buff:%s:%s" % [buff.get("name", ""), buff.get("ally", false)]
		if seen.has(key):
			var entry: Dictionary = out[seen[key]]
			if left > float(entry.left):
				entry["left"] = left
				entry["total"] = float(buff.get("total", left))
			continue
		seen[key] = out.size()
		var glyph := "power"
		if float(buff.get("def", 0.0)) > 0.0:
			glyph = "shield"
		elif float(buff.get("atk", 0.0)) > 0.0:
			glyph = "power"
		elif float(buff.get("speed", 0.0)) > 0.0:
			glyph = "wind"
		elif float(buff.get("crit", 0.0)) > 0.0:
			glyph = "spark"
		out.append({"id": key, "glyph": glyph, "name": String(buff.get("name", "บัฟ")), "color": buff.get("color", Color("ffd84a")), "left": left,
				"total": float(buff.get("total", left)), "kind": "buff", "ally": bool(buff.get("ally", false)), "count": 1, "hp": 1.0})
	for summon in _summons:
		if not is_instance_valid(summon) or summon.is_dead():
			continue
		var key := "summon:%s" % summon.skill_id
		if seen.has(key):
			var entry: Dictionary = out[seen[key]]
			entry["count"] = int(entry.count) + 1
			entry["left"] = minf(float(entry.left), float(summon.life))
			entry["hp"] = minf(float(entry.hp), float(summon.hp) / float(maxi(summon.max_hp, 1)))
			continue
		seen[key] = out.size()
		var skill := ClassData.find_skill(Game.class_id(), String(summon.skill_id))
		out.append({"id": key, "glyph": "summon", "name": String(skill.get("name", summon.skill_id)), "color": skill.get("color", Color("7fe3ff")), "left": float(summon.life),
				"total": float(summon.spec.get("secs", Summon.LIFETIME)), "kind": "summon", "ally": false, "count": 1,
				"hp": float(summon.hp) / float(maxi(summon.max_hp, 1))})
	return out


func has_buff() -> bool:
	var now := Time.get_ticks_msec()
	for buff in _buffs:
		if buff.until > now:
			return true
	return false


# ---------------------------------------------------------------------------
# Input from the HUD
# ---------------------------------------------------------------------------

## The big attack button: lock the nearest monster and start auto-attacking.
func tap_attack() -> void:
	if _dead or safe_zone:
		return
	if not _valid_target(target):
		set_target(nearest_mob())
	if target == null:
		message.emit("ไม่มีมอนสเตอร์อยู่ใกล้ๆ")
		return
	engaged = true


# ---------------------------------------------------------------------------
# Auto hunting
# ---------------------------------------------------------------------------

func toggle_auto() -> void:
	set_auto(not auto)


func set_auto(on: bool) -> void:
	if on == auto:
		return
	if on:
		if _dead or safe_zone:
			message.emit("ออโต้ใช้ได้เฉพาะในทุ่งล่ามอนสเตอร์")
			return
		var camp: Dictionary = field.camp_near(global_position) if field and field.has_method("camp_near") else {}
		if camp.is_empty():
			_auto_center = global_position
			_auto_radius = 12.0
		else:
			_auto_center = Vector3(camp.pos.x, 0.0, camp.pos.y)
			_auto_radius = float(camp.radius)
		Game.say("ออโต้เปิด: ล่าในวงนี้ (แตะปุ่มออโต้หรือเดินเองเพื่อหยุด)", &"info")
	else:
		engaged = false
		_pending = {}
	auto = on
	auto_changed.emit(on)


func _auto_step(delta: float) -> Vector3:
	_auto_timer -= delta
	if _auto_timer <= 0.0:
		_auto_timer = 0.3
		_auto_think()
	var home := _flat(_auto_center - global_position)
	if not _valid_target(target):
		if home.length() > 4.0:
			_face(home, delta, 12.0)
			return home.normalized() * float(stats.speed)
		return Vector3.ZERO
	if home.length() > _auto_radius + 6.0:
		set_target(null)
		engaged = false
		_pending = {}
		return Vector3.ZERO
	return _combat_step(delta)


func _auto_think() -> void:
	var hp_rate := float(Game.profile.hp) / float(maxi(1, stats.max_hp))
	var mp_rate := float(Game.profile.mp) / float(maxi(1, stats.max_mp))
	if hp_rate < 0.45 and Game.total_potions("hp") > 0:
		use_potion("hp")
	if mp_rate < 0.2 and Game.total_potions("mp") > 0:
		use_potion("mp")
	if hp_rate < 0.25 and Game.total_potions("hp") == 0:
		message.emit("ยาเลือดหมด — ปิดออโต้")
		set_auto(false)
		return
	if not _valid_target(target):
		for mob in mobs_in_range(_auto_radius + 6.0):
			if _flat(mob.global_position - _auto_center).length() <= _auto_radius + 2.0:
				set_target(mob)
				break
	engaged = _valid_target(target)
	if engaged and _pending.is_empty() and Time.get_ticks_msec() >= _cast_until and mp_rate > 0.12:
		_auto_cast(hp_rate)


## Picks the next skill off the bar that makes sense right now.
func _auto_cast(hp_rate: float) -> void:
	var skills: Array = Game.class_data().skills
	var crowd := mobs_in_range(7.0).size()
	for i in skills.size():
		var skill: Dictionary = skills[i]
		if skill.is_empty() or not Game.skill_unlocked(skill):
			continue
		if float(cooldowns.get(skill.id, 0.0)) > 0.0 or int(Game.profile.mp) < mp_cost(skill):
			continue
		var fx: Dictionary = skill.get("fx", {})
		match String(skill.shape):
			"self":
				if fx.has("heal") and hp_rate > (0.55 if not fx.has("buff") else 0.75):
					continue
				if fx.has("buff") and not fx.has("heal") and not _buffs.is_empty():
					continue
			"summon":
				if _summons_alive(skill.id) > 0:
					continue
			"burst":
				if crowd < 2:
					continue
		use_skill(i)
		return


func set_target(mob: Mob) -> void:
	if mob == target:
		return
	if _valid_target(target):
		target.set_targeted(false)
	target = mob if _valid_target(mob) else null
	if target:
		target.set_targeted(true)
	target_changed.emit(target)


func cycle_target() -> void:
	var list := mobs_in_range()
	if list.is_empty():
		set_target(null)
		return
	var index := list.find(target)
	set_target(list[(index + 1) % list.size()])


func mobs_in_range(radius := TARGET_RANGE) -> Array[Mob]:
	var list: Array[Mob] = []
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and not mob.is_dead() and _flat(mob.global_position - global_position).length() <= radius:
			list.append(mob)
	list.sort_custom(func(a: Mob, b: Mob) -> bool:
		if a.hostile != b.hostile:
			return a.hostile
		return _flat(a.global_position - global_position).length() < _flat(b.global_position - global_position).length())
	return list


func nearest_mob(radius := TARGET_RANGE) -> Mob:
	var list := mobs_in_range(radius)
	return list[0] if not list.is_empty() else null


func use_potion(kind: String) -> void:
	if _dead or potion_cd > 0.0:
		return
	var before_hp: int = Game.profile.hp
	var before_mp: int = Game.profile.mp
	var id := Game.quick_potion(kind)
	if id == "":
		message.emit("ไม่มียา%s หรือเต็มอยู่แล้ว" % ("เลือด" if kind == "hp" else "มานา"))
		return
	potion_cd = POTION_COOLDOWN
	AudioManager.play_sfx(&"item_use")
	var gained: int = (Game.profile.hp - before_hp) if kind == "hp" else (Game.profile.mp - before_mp)
	VfxKit.heal(field, global_position, Color("6dff9a") if kind == "hp" else Color("6aa8ff"))
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.6, 0), "+%d" % gained,
			Color("6dff9a") if kind == "hp" else Color("7ab4ff"), 1.0)


# ---------------------------------------------------------------------------
# Frame update
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _dead:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
		move_and_slide()
		return
	_tick_timers(delta)
	var now := Time.get_ticks_msec()
	var casting := now < _cast_until
	var direction := _read_move()
	if direction.length() > 0.1 and not casting:
		engaged = false
		_pending = {}
		if auto:
			set_auto(false)
	if _target_dead():
		_on_target_lost()
	var desired := Vector3.ZERO
	if not casting:
		if direction.length() > 0.1:
			desired = direction * float(stats.speed)
			_face(direction, delta, 14.0)
		elif auto:
			desired = _auto_step(delta)
		else:
			desired = _combat_step(delta)
	velocity.x = lerpf(velocity.x, desired.x, 1.0 - exp(-16.0 * delta))
	velocity.z = lerpf(velocity.z, desired.z, 1.0 - exp(-16.0 * delta))
	velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	_clamp_to_field()
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	if speed > 0.6:
		visual.play("Running_A", 0.12, clampf(speed / 5.4, 0.8, 1.4))
		_step_timer -= delta
		if _step_timer <= 0.0 and is_on_floor():
			_step_timer = 0.34
			AudioManager.play_sfx(&"step", -17.0, 0.12)
	else:
		visual.play("Idle")


func _tick_timers(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	_since_hurt += delta
	for id in cooldowns.keys():
		cooldowns[id] = maxf(0.0, float(cooldowns[id]) - delta)
	var now := Time.get_ticks_msec()
	var expired := false
	for buff in _buffs:
		if buff.until <= now:
			expired = true
	if expired:
		_buffs = _buffs.filter(func(b): return b.until > now)
		refresh_stats()
		if _buffs.is_empty() and _buff_emitter:
			_buff_emitter.emitting = false
	_sync_auras(now)
	# Regeneration: MP always, HP once out of combat (faster in the village).
	var hp_rate := 0.02 if safe_zone else (0.006 if _since_hurt > 4.0 else 0.0)
	var mp_rate := 0.05 if safe_zone else (0.02 if _since_hurt > 4.0 else 0.008)
	_regen_hp += float(stats.max_hp) * hp_rate * delta
	_regen_mp += float(stats.max_mp) * mp_rate * delta
	if _regen_hp >= 1.0:
		Game.profile.hp = mini(stats.max_hp, Game.profile.hp + int(_regen_hp))
		_regen_hp -= int(_regen_hp)
	if _regen_mp >= 1.0:
		Game.profile.mp = mini(stats.max_mp, Game.profile.mp + int(_regen_mp))
		_regen_mp -= int(_regen_mp)


func _read_move() -> Vector3:
	var v := move_input
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if v.length() < 0.05:
		return Vector3.ZERO
	v = v.limit_length(1.0)
	var basis := camera_rig.get_move_basis() if camera_rig else Basis.IDENTITY
	return (basis * Vector3(v.x, 0, v.y)).normalized() * v.length()


func _face(direction: Vector3, delta: float, rate := 12.0) -> void:
	if direction.length_squared() < 0.0001:
		return
	_facing = lerp_angle(_facing, atan2(direction.x, direction.z), 1.0 - exp(-rate * delta))
	visual.rotation.y = _facing


func _clamp_to_field() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > field_radius:
		flat = flat.normalized() * field_radius
		global_position.x = flat.x
		global_position.z = flat.y


# ---------------------------------------------------------------------------
# Combat: approach, auto-attack, skills
# ---------------------------------------------------------------------------

func _valid_target(mob: Variant) -> bool:
	return mob != null and is_instance_valid(mob) and not (mob as Mob).is_dead()


func _target_dead() -> bool:
	return target != null and not _valid_target(target)


func _on_target_lost() -> void:
	target = null
	target_changed.emit(null)
	if engaged or not _pending.is_empty():
		var next := nearest_mob(12.0)
		if next:
			set_target(next)
		else:
			engaged = false
			_pending = {}


## Returns the desired velocity while fighting (approach / stand and attack).
func _combat_step(delta: float) -> Vector3:
	if safe_zone or not _valid_target(target):
		return Vector3.ZERO
	var attack: Dictionary = Game.class_data().attack
	var to := _flat(target.global_position - global_position)
	var distance := to.length() - target.body_radius()
	var want_range := float(attack.range)
	if not _pending.is_empty():
		want_range = _skill_range(_pending)
	if not engaged and _pending.is_empty():
		return Vector3.ZERO
	if distance > want_range:
		_face(to, delta, 16.0)
		return to.normalized() * float(stats.speed) * 1.05
	_face(to, delta, 20.0)
	if not _pending.is_empty():
		var skill: Dictionary = _pending
		_pending = {}
		_cast(skill)
	elif engaged and _attack_timer <= 0.0:
		_basic_attack()
	return Vector3.ZERO


func _skill_range(skill: Dictionary) -> float:
	if skill.shape == "burst":
		return float(_ranked(skill).radius) * 0.7
	return float(skill.get("range", 3.0))


func _basic_attack() -> void:
	var attack: Dictionary = Game.class_data().attack
	_attack_timer = float(attack.interval) * (1.0 - _haste())
	_since_hurt = minf(_since_hurt, 1.0)
	var anims: Array = attack.anims
	var clip: String = anims[_combo % anims.size()]
	_combo += 1
	var length := visual.action(clip, maxf(visual.anim.get_animation(clip).length / (float(attack.interval) * 0.9), 1.0) if visual.has_clip(clip) else 1.0)
	_cast_until = Time.get_ticks_msec() + int(float(attack.hit_delay) * 1000.0) + 60
	var mob := target
	var delay := float(attack.hit_delay)
	var color: Color = attack.get("color", Color.WHITE)
	AudioManager.play_sfx(&"hit_physical" if not bool(attack.projectile) else &"hit_special", -6.0)
	if bool(attack.projectile):
		get_tree().create_timer(delay).timeout.connect(func():
			if not _valid_target(mob) or _dead:
				return
			var from := global_position + Vector3(0, 1.3, 0) + Vector3(sin(_facing), 0, cos(_facing)) * 0.6
			var to := mob.hit_point()
			var flight := clampf(from.distance_to(to) / 22.0, 0.1, 0.5)
			if Game.class_id() == &"archer":
				VfxKit.arrow(field, color, from, to, flight)
			else:
				VfxKit.projectile(field, color, from, to, flight, 0.3, VfxKit.variant_for(attack.vfx))
			get_tree().create_timer(flight).timeout.connect(func(): _deal(mob, float(attack.mult), color, attack.vfx, false), CONNECT_ONE_SHOT)
		, CONNECT_ONE_SHOT)
	else:
		get_tree().create_timer(delay).timeout.connect(func():
			if _dead or not _valid_target(mob):
				return
			VfxKit.slash_arc(field, global_position + Vector3(sin(_facing), 0, cos(_facing)) * 1.1 + Vector3(0, 1.0, 0), _facing, Color("fff2d0"), 2.0,
					[0.5, -0.5, 0.0][_combo % 3])
			_deal(mob, float(attack.mult), Color.WHITE, attack.vfx, true)
		, CONNECT_ONE_SHOT)


func rank_mult(skill: Dictionary) -> float:
	return 1.0 + 0.15 * float(Game.effective_rank(skill) - 1)


func mp_cost(skill: Dictionary) -> int:
	return int(ceil(float(skill.mp) * (1.0 + 0.04 * float(Game.effective_rank(skill) - 1))))


func cooldown_of(skill: Dictionary) -> float:
	return float(skill.cd) * (1.0 - 0.03 * float(Game.effective_rank(skill) - 1)) * (1.0 - _haste())


## Share of time DEX cuts from cooldowns, wind-ups and the basic attack interval.
func _haste() -> float:
	return float(stats.get("haste", 0.0))


## The skill with its area and target counts grown by the star rank.
func _ranked(skill: Dictionary) -> Dictionary:
	var rank := Game.effective_rank(skill)
	if rank <= 1:
		return skill
	var grown := skill.duplicate()
	if grown.has("radius"):
		grown["radius"] = float(skill.radius) * Game.radius_scale(rank)
	if String(skill.shape) in ["chain", "fan"] and grown.has("hits"):
		grown["hits"] = int(skill.hits) + (1 if rank >= 3 else 0) + (1 if rank >= 5 else 0)
	return grown


func cooldown_ratio(skill: Dictionary) -> float:
	return clampf(float(cooldowns.get(skill.id, 0.0)) / maxf(cooldown_of(skill), 0.1), 0.0, 1.0)


## Skill button pressed. Returns "" when started, otherwise why not.
func use_skill(index: int) -> String:
	if _dead or safe_zone:
		return "safe"
	var skills: Array = Game.class_data().skills
	var skill: Dictionary = skills[index] if index >= 0 and index < skills.size() else {}
	if skill.is_empty():
		return "none"
	if not Game.skill_unlocked(skill):
		message.emit(Game.skill_lock_reason(skill))
		return "locked"
	if float(cooldowns.get(skill.id, 0.0)) > 0.0:
		return "cooldown"
	if int(Game.profile.mp) < mp_cost(skill):
		message.emit("MP ไม่พอ!")
		return "mp"
	if skill.shape == "self" or skill.shape == "summon":
		_cast(skill)
		return ""
	if not _valid_target(target):
		set_target(nearest_mob())
	if target == null:
		message.emit("ไม่มีมอนสเตอร์อยู่ใกล้ๆ")
		return "target"
	_pending = skill
	return ""


func _cast(skill: Dictionary) -> void:
	var cost := mp_cost(skill)
	if int(Game.profile.mp) < cost:
		return
	Game.profile.mp -= cost
	cooldowns[skill.id] = cooldown_of(skill)
	_since_hurt = minf(_since_hurt, 1.0)
	skill_fired.emit(Game.class_data().skills.find(skill))
	skill = _ranked(skill)
	var delay := float(skill.hit_delay) * (1.0 - _haste())
	visual.action(skill.anim, 1.0 / maxf(1.0 - _haste(), 0.5))
	_cast_until = Time.get_ticks_msec() + int(delay * 1000.0) + 90
	if target and _valid_target(target):
		_face(_flat(target.global_position - global_position), 1.0, 60.0)
	AudioManager.play_sfx(&"skill_start", -4.0)
	Game.daily_progress("skills", 1)
	var snapshot := target
	var aim := target.global_position if _valid_target(target) else global_position + Vector3(sin(_facing), 0, cos(_facing)) * 4.0
	var color: Color = skill.color
	# Wind-up effect while the cast animation plays.
	if skill.shape == "blast":
		VfxKit.ground_circle(field, Vector3(aim.x, global_position.y, aim.z), color, float(skill.radius), delay + 0.2)
	elif skill.shape == "burst":
		VfxKit.ground_circle(field, global_position, color, float(skill.radius) * 0.5, delay)
	get_tree().create_timer(delay).timeout.connect(func(): _resolve(skill, snapshot, aim), CONNECT_ONE_SHOT)


func _resolve(skill: Dictionary, mob: Mob, aim: Vector3) -> void:
	if _dead:
		return
	var color: Color = skill.color
	var mult: float = float(skill.get("mult", 0.0)) * rank_mult(skill)
	var origin := global_position + Vector3(0, 1.3, 0)
	var forward := Vector3(sin(_facing), 0, cos(_facing))
	var show_center := global_position
	if String(skill.shape) in ["single", "chain", "fan"] and _valid_target(mob):
		show_center = mob.global_position
	elif String(skill.shape) == "blast":
		show_center = Vector3(mob.global_position.x if _valid_target(mob) else aim.x, 0.0, mob.global_position.z if _valid_target(mob) else aim.z)
	SkillShow.play(field, skill, show_center, global_position, camera_rig)
	match String(skill.shape):
		"self":
			_apply_self_fx(skill)
		"summon":
			_summon(skill, mult)
		"single":
			if not _valid_target(mob):
				return
			if bool(skill.get("projectile", false)):
				_shoot(skill, mob, mult, origin, 1.0)
			else:
				VfxKit.slash_arc(field, global_position + forward * 1.2 + Vector3(0, 1.0, 0), _facing, color, 3.0, -0.4)
				VfxKit.sparks(field, mob.hit_point(), color, 20, 4.5, 0.5)
				_deal(mob, mult, color, skill.vfx, true, skill)
		"fan":
			var list := mobs_in_range(float(skill.range))
			if _valid_target(mob):
				list.erase(mob)
				list.push_front(mob)
			var count := int(skill.hits)
			for i in mini(count, maxi(list.size(), 1)):
				var victim: Mob = list[i] if i < list.size() else mob
				if _valid_target(victim):
					_shoot(skill, victim, mult, origin + Vector3(0, 0, 0) + forward.rotated(Vector3.UP, (i - 1) * 0.0), 1.0)
			if list.is_empty():
				for i in count:
					var angle := (i - 1) * 0.25
					VfxKit.arrow(field, color, origin, origin + forward.rotated(Vector3.UP, angle) * 9.0, 0.3)
		"chain":
			var hit: Array[Mob] = []
			var current := mob
			var from := origin + forward * 0.8
			for i in int(skill.hits):
				if not _valid_target(current):
					break
				VfxKit.lightning(field, from, current.hit_point(), color)
				_deal(current, mult * pow(0.85, i), color, skill.vfx, true, skill)
				hit.append(current)
				from = current.hit_point()
				var next: Mob = null
				var best := 7.0
				for node in get_tree().get_nodes_in_group("mobs"):
					var other := node as Mob
					if other and not other.is_dead() and not hit.has(other):
						var d := (other.global_position - current.global_position).length()
						if d < best:
							best = d
							next = other
				current = next
		"burst":
			var radius := float(skill.radius)
			VfxKit.shockwave(field, global_position + Vector3(0, 0.15, 0), color, radius * 1.15)
			if skill.get("special", "") == "spin":
				for i in 3:
					VfxKit.slash_arc(field, global_position + Vector3(0, 0.9 + i * 0.2, 0), _facing + i * 2.1, color, 3.4, 0.0)
			_shake(0.2)
			var hits := 0
			for victim in mobs_in_range(radius + 0.6):
				_deal(victim, mult, color, skill.vfx, true, skill)
				hits += 1
			if skill.get("fx", {}).has("heal"):
				_heal(float(skill.fx.heal))
		"blast":
			var center := Vector3(aim.x, 0.0, aim.z)
			if _valid_target(mob):
				center = Vector3(mob.global_position.x, 0.0, mob.global_position.z)
			var radius := float(skill.radius)
			if skill.get("special", "") == "meteor":
				VfxKit.meteor(field, center, color, 0.55, radius, func(): _blast_damage(skill, center, radius, mult))
			elif skill.get("special", "") == "rain":
				_arrow_rain(skill, center, radius, mult)
			else:
				VfxKit.shockwave(field, center + Vector3(0, 0.1, 0), color, radius)
				_blast_damage(skill, center, radius, mult)


func _shoot(skill: Dictionary, mob: Mob, mult: float, from: Vector3, scale: float) -> void:
	var color: Color = skill.color
	var to := mob.hit_point()
	var flight := clampf(from.distance_to(to) / 20.0, 0.12, 0.6)
	if Game.class_id() == &"archer":
		VfxKit.arrow(field, color, from, to, flight)
	else:
		VfxKit.projectile(field, color, from, to, flight, 0.5 * scale, VfxKit.variant_for(skill.vfx))
	get_tree().create_timer(flight).timeout.connect(func():
		if _dead:
			return
		if _valid_target(mob):
			if skill.get("special", "") == "boom":
				VfxKit.shockwave(field, mob.global_position + Vector3(0, 0.15, 0), color, 2.2)
			_deal(mob, mult, color, skill.vfx, true, skill)
	, CONNECT_ONE_SHOT)


func _blast_damage(skill: Dictionary, center: Vector3, radius: float, mult: float) -> void:
	_shake(0.3)
	for node in get_tree().get_nodes_in_group("mobs"):
		var victim := node as Mob
		if victim and not victim.is_dead() and _flat(victim.global_position - center).length() <= radius + victim.body_radius():
			_deal(victim, mult, skill.color, skill.vfx, true, skill)


func _arrow_rain(skill: Dictionary, center: Vector3, radius: float, mult: float) -> void:
	var color: Color = skill.color
	for i in 14:
		var angle := randf() * TAU
		var spot := center + Vector3(cos(angle), 0, sin(angle)) * randf() * radius
		get_tree().create_timer(i * 0.07).timeout.connect(func():
			VfxKit.arrow(field, color, spot + Vector3(1.5, 12.0, 0.5), spot + Vector3(0, 0.2, 0), 0.28)
		, CONNECT_ONE_SHOT)
	get_tree().create_timer(0.55).timeout.connect(func():
		if _dead:
			return
		VfxKit.shockwave(field, center + Vector3(0, 0.1, 0), color, radius * 0.9)
		_blast_damage(skill, center, radius, mult)
	, CONNECT_ONE_SHOT)


## Calls the skill's creatures (replacing the same skill's earlier ones; at most 5 in all).
func _summon(skill: Dictionary, mult: float) -> void:
	var spec: Dictionary = skill.summon
	_summons = _summons.filter(func(s): return is_instance_valid(s))
	for old in _summons.duplicate():
		if old.skill_id == skill.id:
			old.queue_free()
			_summons.erase(old)
	var count := int(spec.get("count", 1)) + (1 if Game.effective_rank(skill) >= 5 and int(spec.get("count", 1)) > 1 else 0)
	for i in count:
		var s := Summon.new()
		s.setup(self, String(skill.id), spec, mult, i, count, maxi(1, Game.effective_rank(skill)))
		field.add_child(s)
		_summons.append(s)
	while _summons.size() > 5:
		var oldest: Summon = _summons.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	VfxKit.aura(field, global_position, skill.color)
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.7, 0), String(skill.name), skill.color, 0.6)


func _summons_alive(skill_id: String) -> int:
	var n := 0
	for s in _summons:
		if is_instance_valid(s) and s.skill_id == skill_id:
			n += 1
	return n


func _apply_self_fx(skill: Dictionary) -> void:
	var fx: Dictionary = skill.get("fx", {})
	var color: Color = skill.color
	if fx.has("heal"):
		_heal(float(fx.heal))
	if fx.has("buff"):
		receive_buff(fx.buff, color, String(skill.name))


## A buff from a skill or from a companion: {atk, def, speed, crit, secs}.
func receive_buff(buff_data: Dictionary, color: Color, label := "", from_ally := false) -> void:
	var buff: Dictionary = buff_data.duplicate()
	buff["until"] = Time.get_ticks_msec() + int(float(buff.secs) * 1000.0)
	buff["name"] = label if label != "" else "บัฟ"
	buff["color"] = color
	buff["total"] = float(buff.secs)
	buff["ally"] = from_ally
	_buffs.append(buff)
	refresh_stats()
	if _buff_emitter == null:
		_buff_emitter = VfxKit.buff_emitter(self, color)
	_buff_emitter.color_ramp = null
	(_buff_emitter.mesh.material as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 0.9)
	_buff_emitter.emitting = true
	VfxKit.aura(field, global_position, color)
	VfxKit.shockwave(field, global_position + Vector3(0, 0.15, 0), color, 3.0)
	if label != "":
		BattleVfx.floating_text(field, global_position + Vector3(0, 2.7, 0), label, color, 0.6)
	AudioManager.play_sfx(&"buff")


## Healing from a companion.
func receive_heal(fraction: float) -> void:
	_heal(fraction)


func _heal(fraction: float) -> void:
	var amount := int(float(stats.max_hp) * fraction)
	var before: int = Game.profile.hp
	Game.profile.hp = mini(stats.max_hp, Game.profile.hp + amount)
	VfxKit.heal(field, global_position)
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.6, 0), "+%d" % (Game.profile.hp - before), Color("6dff9a"), 1.0)
	for node in get_tree().get_nodes_in_group("companions"):
		if node.has_method("heal_fraction") and node.global_position.distance_to(global_position) < 9.0:
			node.heal_fraction(fraction * 0.6)
	AudioManager.play_sfx(&"heal")


## Applies one hit: damage roll, crit, mitigation, skill effects, juice.
func _deal(mob: Mob, mult: float, color: Color, vfx: StringName, melee: bool, skill := {}) -> void:
	if not _valid_target(mob):
		return
	var raw := float(stats.atk) * mult * randf_range(0.92, 1.08)
	var crit := randf() < float(stats.crit)
	if crit:
		raw *= HeroStats.CRIT_DAMAGE
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(mob.stats.def)))))
	VfxKit.impact(field, mob.hit_point(), color if color != Color.WHITE else Color("fff0c0"), 1.4 if crit else 1.0)
	var killed := mob.take_hit(amount, crit, color)
	AudioManager.play_sfx(&"crit" if crit else &"hit_physical", -3.0)
	_shake(0.12 if crit else 0.05)
	if killed:
		return
	if melee:
		mob.knock_back(global_position, 3.0)
	var fx: Dictionary = skill.get("fx", {})
	if fx.has("stun"):
		mob.apply_stun(float(fx.stun))
	if fx.has("slow"):
		mob.apply_slow(float(fx.slow))
	if fx.has("burn"):
		mob.apply_burn(float(stats.atk) * float(fx.burn[0]) * rank_mult(skill), float(fx.burn[1]))


# ---------------------------------------------------------------------------
# Taking damage, dying
# ---------------------------------------------------------------------------

func take_damage(raw: float, _attacker: Node = null) -> void:
	if _dead or Time.get_ticks_msec() < _invulnerable_until or safe_zone:
		return
	if randf() < float(stats.dodge):
		BattleVfx.floating_text(field, global_position + Vector3(0, 2.4, 0), "หลบ!", Color("9fe8ff"), 0.9)
		return
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(stats.def)))))
	Game.profile.hp = maxi(0, Game.profile.hp - amount)
	_since_hurt = 0.0
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.4, 0), str(amount), Color("ff5a6e"), 1.1)
	visual.flash()
	AudioManager.play_sfx(&"hit_special", -2.0)
	_shake(0.14)
	GameSettings.vibrate(35)
	if Time.get_ticks_msec() >= _cast_until:
		visual.action("Hit_A", 1.2)
	if Game.profile.hp <= 0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	set_auto(false)
	engaged = false
	_pending = {}
	set_target(null)
	visual.hold_last_frame("Death_A")
	AudioManager.play_sfx(&"faint")
	Game.profile["deaths"] = int(Game.profile.get("deaths", 0)) + 1
	died.emit()


func revive() -> void:
	_dead = false
	visual.release()
	visual.play("Idle")
	_invulnerable_until = Time.get_ticks_msec() + 2500


func level_up_fx() -> void:
	VfxKit.level_up(field, global_position)
	BattleVfx.floating_text(field, global_position + Vector3(0, 3.0, 0), "เลเวลอัป!", Color("ffe27a"), 1.5)
	AudioManager.play_sfx(&"level_up")


func _shake(strength: float) -> void:
	if camera_rig:
		camera_rig.shake(strength)


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v
