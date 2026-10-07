class_name Mob
extends CharacterBody3D
## A monster on a hunting field. It wanders near its spawn point, fights back
## when hurt (aggressive ones attack on sight), chases the hero, telegraphs its
## hits with a red flash, and bosses add a ground slam. Death drops loot via
## the field (signal [signal died]).

signal died(mob: Mob)
## A boss crossed a health threshold: phase 1 (70%) and 2 (40%, enraged).
signal phase_changed(mob: Mob, phase: int)

const NOTICE_RADIUS := 9.0
const LEASH := 34.0
const WINDUP := 0.5
const PACK_RADIUS := 6.0
const SLAM_INTERVAL := 8.0
const BARRAGE_METEORS := 4

var monster_id: StringName = &"pink_slime"
var template: Dictionary = {}
var level := 1
var stats: Dictionary = {}
var hp := 1
var max_hp := 1
var home := Vector3.ZERO
var hero: Node3D
var hostile := false
var _victim: Node3D
var _victim_timer := 0.0
var is_boss := false
var visual: MonsterVisual

var _label: Label3D
var _bar: FieldHpBar
var _ring: MeshInstance3D
var _alert: Label3D
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
var _goal := Vector3.ZERO
var _pause := 0.0
var _speed := 2.0
var _dead := false
var _winding := false
var _attack_timer := 1.0
var _slam_timer := SLAM_INTERVAL * 0.6
var _stun := 0.0
var _slow := 0.0
var _burn_dps := 0.0
var _burn_time := 0.0
var _burn_tick := 0.0
var _anim_lock := 0
var _bar_until := 0.0
var _returning := false
var _yaw := 0.0
var phase := 0
var _atk_scale := 1.0
var _base_speed := 2.0
var _barrage_timer := 9.0


func setup(id: StringName, p_level: int, p_home: Vector3, p_hero: Node3D) -> void:
	monster_id = id
	level = p_level
	home = p_home
	hero = p_hero
	template = MonsterData.get_monster(id)
	stats = MonsterData.stats_for(id, p_level)
	hp = int(stats.hp)
	max_hp = hp
	is_boss = bool(template.get("boss", false))
	_speed = float(template.speed)
	_base_speed = _speed


func _ready() -> void:
	add_to_group("mobs")
	collision_layer = 1 << 2
	collision_mask = 1 << 0
	floor_snap_length = 0.5
	var radius := clampf(float(template.height) * 0.3, 0.35, 1.2)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(radius * 2.0, float(template.height) * 0.8)
	shape.shape = capsule
	shape.position = Vector3(0, capsule.height * 0.5, 0)
	add_child(shape)

	visual = MonsterVisual.new()
	add_child(visual)
	visual.setup(String(template.model), float(template.height), float(template.get("hover", 0.0)), template.get("tint", Color.WHITE))
	var top := visual.height

	_label = Label3D.new()
	_label.text = "Lv.%d %s" % [level, template.name]
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0046
	_label.font_size = 44
	_label.outline_size = 12
	_label.modulate = Color(1.0, 0.82, 0.35) if is_boss else Color(1, 0.95, 0.85)
	_label.visibility_range_end = 26.0 if is_boss else 9.0
	_label.position = Vector3(0, top + 0.55, 0)
	add_child(_label)
	_bar = FieldHpBar.new()
	_bar.position = Vector3(0, top + 0.28, 0)
	_bar.scale = Vector3.ONE * (1.6 if is_boss else 1.0)
	_bar.visible = false
	add_child(_bar)
	_alert = Label3D.new()
	_alert.text = "!"
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.pixel_size = 0.01
	_alert.font_size = 64
	_alert.outline_size = 16
	_alert.modulate = Color(1.0, 0.3, 0.25)
	_alert.position = Vector3(0, top + 1.1, 0)
	_alert.visible = false
	add_child(_alert)
	_pick_goal()
	visual.scale = Vector3.ONE * 0.01
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_dead() -> bool:
	return _dead


func hit_point() -> Vector3:
	return global_position + Vector3(0, visual.height * 0.55, 0)


func top_point() -> Vector3:
	return global_position + Vector3(0, visual.height + 0.35, 0)


func body_radius() -> float:
	return clampf(float(template.height) * 0.3, 0.35, 1.2)


func set_targeted(on: bool) -> void:
	if on and _ring == null:
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.62
		torus.outer_radius = 0.74
		torus.rings = 24
		_ring.mesh = torus
		_ring.material_override = MeshKit.toon(Color("ff5a6e"), {"unshaded": true, "emission": 1.5})
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.position = Vector3(0, 0.07, 0)
		var s := clampf(visual.height * 0.9, 0.9, 3.4)
		_ring.scale = Vector3(s, 0.4, s)
		add_child(_ring)
	if _ring:
		_ring.visible = on
	if on:
		_bar.visible = true


## Damage from the hero. Returns true when it killed the monster.
func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
	if _dead:
		return false
	hp = maxi(0, hp - amount)
	_bar.set_ratio(float(hp) / float(max_hp))
	_bar.visible = true
	_bar_until = Time.get_ticks_msec() * 0.001 + 6.0
	BattleVfx.floating_text(get_parent(), top_point(), str(amount) + ("!" if crit else ""),
			Color("ffd84a") if crit else color, 1.35 if crit else 1.0)
	visual.flash(Color(1, 1, 1))
	if hp <= 0:
		_die()
		return true
	if is_boss:
		_check_phase()
	if not is_boss:
		visual.action("hurt", 320)
		_anim_lock = Time.get_ticks_msec() + 320
	if attacker is Companion and randf() < 0.45:
		_victim = attacker
		_victim_timer = 3.0
	provoke()
	return false


func provoke(alert_pack := true) -> void:
	if _dead:
		return
	if not hostile:
		hostile = true
		_returning = false
		_flash_alert()
	if alert_pack:
		for other in get_tree().get_nodes_in_group("mobs"):
			var m := other as Mob
			if m and m != self and not m.hostile and not m.is_dead() and m.global_position.distance_to(global_position) <= PACK_RADIUS:
				m.provoke(false)


func apply_stun(seconds: float) -> void:
	if is_boss:
		seconds *= 0.4
	_stun = maxf(_stun, seconds)
	_winding = false
	BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.4, 0), "มึน!", Color("ffe27a"), 0.75)


func apply_slow(seconds: float) -> void:
	_slow = maxf(_slow, seconds)


func apply_burn(dps: float, seconds: float) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, seconds)


func knock_back(from: Vector3, strength := 2.5) -> void:
	if is_boss:
		return
	var dir := global_position - from
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		velocity += dir.normalized() * strength


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var now := Time.get_ticks_msec() * 0.001
	if _bar_until > 0.0 and now > _bar_until and (_ring == null or not _ring.visible):
		_bar.visible = false
		_bar_until = 0.0
	_tick_status(delta)
	if _dead:
		return
	_victim_timer -= delta
	if _victim_timer <= 0.0 or not _alive(_victim):
		_victim = _nearest_victim()
		_victim_timer = 0.8
	var hero_ok: bool = _victim != null
	var desired := Vector3.ZERO
	var chase_target: Node3D = null
	var speed_factor := 0.5 if _slow > 0.0 else 1.0
	if _stun > 0.0:
		_stun -= delta
	elif hero_ok:
		var distance := _flat_distance(_victim.global_position)
		if not hostile and bool(template.aggro) and distance < NOTICE_RADIUS and not _returning:
			hostile = true
			_flash_alert()
		if hostile:
			if _flat_distance(home) > LEASH or distance > LEASH + 12.0:
				hostile = false
				_returning = true
				_winding = false
			else:
				chase_target = _victim
	if _stun <= 0.0:
		if chase_target:
			desired = _chase(chase_target, delta, speed_factor)
		elif _returning:
			var to_home := home - global_position
			to_home.y = 0.0
			if to_home.length() < 1.2:
				_returning = false
				hp = max_hp
				_bar.set_ratio(1.0)
				phase = 0
				_atk_scale = 1.0
				_speed = _base_speed
			else:
				desired = to_home.normalized() * _speed * 1.6
		elif not _winding:
			desired = _wander(delta) * speed_factor
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(desired, 12.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	_animate(horizontal, delta, chase_target)


func _chase(target: Node3D, delta: float, speed_factor: float) -> Vector3:
	var to := target.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var ranged := String(template.attack) == "ranged"
	var reach := (7.0 if ranged else 1.5 + body_radius() * 1.2)
	_attack_timer -= delta
	_slam_timer -= delta
	if phase >= 1:
		_barrage_timer -= delta
		if _barrage_timer <= 0.0:
			_barrage_timer = 9.0 if phase == 1 else 6.0
			_meteor_barrage(target)
	if to.length_squared() > 0.01:
		_yaw = lerp_angle(_yaw, atan2(to.x, to.z), 1.0 - exp(-9.0 * delta))
		visual.rotation.y = _yaw
	if is_boss and _slam_timer <= 0.0 and distance < 9.0 and not _winding:
		_begin_slam()
	elif distance <= reach and _attack_timer <= 0.0 and not _winding:
		_begin_attack()
	if _winding or distance <= reach * 0.85:
		return Vector3.ZERO
	return to.normalized() * _speed * 1.7 * speed_factor


func _wander(delta: float) -> Vector3:
	if _pause > 0.0:
		_pause -= delta
		return Vector3.ZERO
	var to_goal := _goal - global_position
	to_goal.y = 0.0
	if to_goal.length() < 0.7:
		_pause = randf_range(1.5, 4.0)
		_pick_goal()
		return Vector3.ZERO
	return to_goal.normalized() * _speed


func _animate(horizontal: Vector3, delta: float, chase: Node3D) -> void:
	if Time.get_ticks_msec() < _anim_lock:
		return
	if horizontal.length() > 0.25:
		if chase == null:
			_yaw = lerp_angle(_yaw, atan2(horizontal.x, horizontal.z), 1.0 - exp(-7.0 * delta))
			visual.rotation.y = _yaw
		visual.play("run" if horizontal.length() > _speed * 1.4 else "walk")
	else:
		visual.play("idle")


func _begin_attack() -> void:
	_winding = true
	visual.flash(Color(1.0, 0.25, 0.2), WINDUP)
	var squash := create_tween()
	squash.tween_property(visual, "scale", Vector3(1.12, 0.88, 1.12), WINDUP * 0.8)
	squash.tween_property(visual, "scale", Vector3.ONE, 0.12)
	get_tree().create_timer(WINDUP).timeout.connect(_strike, CONNECT_ONE_SHOT)


func _strike() -> void:
	_winding = false
	_attack_timer = randf_range(1.8, 2.8) if not is_boss else randf_range(1.4, 2.0)
	if _dead or _stun > 0.0 or not _alive(_victim):
		return
	var victim := _victim
	visual.action("attack", 450)
	_anim_lock = Time.get_ticks_msec() + 450
	var raw := float(stats.atk) * _atk_scale * randf_range(0.9, 1.1)
	if String(template.attack) == "ranged":
		var color: Color = template.get("color", Color("ff9a5a"))
		var from := hit_point()
		var to: Vector3 = victim.global_position + Vector3(0, 1.0, 0)
		var flight := clampf(from.distance_to(to) / 13.0, 0.15, 0.6)
		VfxKit.projectile(get_parent(), color, from, to, flight, 0.42)
		get_tree().create_timer(flight).timeout.connect(func(): _deliver(victim, raw), CONNECT_ONE_SHOT)
	else:
		_deliver(victim, raw, 1.5 + body_radius() * 1.2 + 1.0)


func _deliver(victim: Node3D, raw: float, max_distance := 99.0) -> void:
	if _dead or not _alive(victim):
		return
	if _flat_distance(victim.global_position) > max_distance:
		return
	victim.take_damage(raw, self)


## Hero or companion still standing.
func _alive(node: Node3D) -> bool:
	return node != null and is_instance_valid(node) and node.has_method("is_dead") and not node.is_dead()


func _targets() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _alive(hero):
		out.append(hero)
	for node in get_tree().get_nodes_in_group("companions"):
		if _alive(node as Node3D):
			out.append(node as Node3D)
	for node in get_tree().get_nodes_in_group("summons"):
		if _alive(node as Node3D):
			out.append(node as Node3D)
	return out


## The closest hero / companion (the hero counts as a little closer).
func _nearest_victim() -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	for t in _targets():
		var d := _flat_distance(t.global_position) * (0.8 if t == hero else 1.0)
		if d < best_d:
			best_d = d
			best = t
	return best


func _begin_slam() -> void:
	_winding = true
	_slam_timer = SLAM_INTERVAL
	var radius := 5.5
	var center := global_position
	var color: Color = template.get("color", Color("ff6a4a"))
	VfxKit.danger_circle(get_parent(), center, radius, 1.2)
	visual.flash(Color(1.0, 0.3, 0.2), 1.2)
	visual.action("attack", 700)
	_anim_lock = Time.get_ticks_msec() + 900
	get_tree().create_timer(1.2).timeout.connect(func():
		_winding = false
		if _dead:
			return
		VfxKit.shockwave(get_parent(), center + Vector3(0, 0.1, 0), color, radius)
		BattleVfx.burst(get_parent(), center + Vector3(0, 0.4, 0), color, 36, 1.4)
		for t in _targets():
			if _flat_distance_from(t.global_position, center) <= radius:
				t.take_damage(float(stats.atk) * _atk_scale * 1.9, self)
		, CONNECT_ONE_SHOT)


## Bosses change tactics as they lose health: help arrives at 70%, rage at 40%.
func _check_phase() -> void:
	var ratio := float(hp) / float(max_hp)
	var wanted := 2 if ratio < 0.4 else (1 if ratio < 0.7 else 0)
	if wanted <= phase:
		return
	phase = wanted
	_barrage_timer = 2.5
	var color: Color = template.get("color", Color("ff6a4a"))
	VfxKit.shockwave(get_parent(), global_position + Vector3(0, 0.1, 0), color, 7.0)
	BattleVfx.burst(get_parent(), global_position + Vector3(0, 0.6, 0), color, 40, 1.6)
	if phase == 2:
		_atk_scale = 1.3
		_speed *= 1.25
		visual.flash(Color(1.0, 0.2, 0.15), 1.0)
		BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.9, 0), "คลั่ง!", Color("ff4a4a"), 1.5)
		Game.say("%s คลั่งแล้ว! ระวังอุกกาบาต" % String(template.name), &"warning")
	else:
		BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.9, 0), "เรียกพวก!", Color("ffd84a"), 1.4)
		Game.say("%s ร้องเรียกลูกสมุน!" % String(template.name), &"warning")
	phase_changed.emit(self, phase)


## Warning circles drop around the victim; whoever stays inside is hit.
func _meteor_barrage(target: Node3D) -> void:
	if _dead or target == null or not is_instance_valid(target):
		return
	var color: Color = template.get("color", Color("ff6a4a"))
	var radius := 2.6
	for i in BARRAGE_METEORS:
		var spot: Vector3 = target.global_position
		if i > 0:
			var angle := randf() * TAU
			spot += Vector3(cos(angle), 0, sin(angle)) * randf_range(2.0, 7.0)
		spot.y = 0.0
		VfxKit.danger_circle(get_parent(), spot, radius, 1.5)
		get_tree().create_timer(1.5).timeout.connect(func():
			if _dead:
				return
			VfxKit.shockwave(get_parent(), spot + Vector3(0, 0.1, 0), color, radius)
			BattleVfx.burst(get_parent(), spot + Vector3(0, 0.4, 0), color, 20, 1.0)
			for t in _targets():
				if _flat_distance_from(t.global_position, spot) <= radius:
					t.take_damage(float(stats.atk) * _atk_scale * 1.2, self)
			, CONNECT_ONE_SHOT)


func _tick_status(delta: float) -> void:
	if _slow > 0.0:
		_slow -= delta
	if _burn_time > 0.0:
		_burn_time -= delta
		_burn_tick += delta
		if _burn_tick >= 0.5:
			_burn_tick -= 0.5
			var amount := maxi(1, int(_burn_dps * 0.5))
			hp = maxi(0, hp - amount)
			_bar.set_ratio(float(hp) / float(max_hp))
			_bar.visible = true
			BattleVfx.floating_text(get_parent(), top_point(), str(amount), Color("ff8a3a"), 0.7)
			if hp <= 0:
				_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	hostile = false
	set_targeted(false)
	_label.visible = false
	_bar.visible = false
	_alert.visible = false
	collision_layer = 0
	remove_from_group("mobs")
	visual.hold("die")
	VfxKit.flash(get_parent(), hit_point(), Color("ffe9a0"), 2.6 if is_boss else 1.6)
	VfxKit.sparks(get_parent(), hit_point(), Color("ffe27a"), 30 if is_boss else 14, 5.0, 0.7)
	died.emit(self)
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.4)
	tween.tween_callback(queue_free)


func _flash_alert() -> void:
	_alert.visible = true
	_alert.scale = Vector3.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(_alert, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.0)
	tween.tween_callback(func(): _alert.visible = false)


func _pick_goal() -> void:
	var angle := randf() * TAU
	_goal = home + Vector3(cos(angle), 0, sin(angle)) * randf_range(1.0, 6.0)


func _flat_distance(point: Vector3) -> float:
	return _flat_distance_from(point, global_position)


func _flat_distance_from(a: Vector3, b: Vector3) -> float:
	var d := a - b
	d.y = 0.0
	return d.length()
