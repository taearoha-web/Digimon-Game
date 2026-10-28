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
## Marks (the Bard's discords and laments, the Assassin's Death Mark, star skills):
## [fraction, secs] that crack the armour (shred: DEF down) or sap the strength
## (weaken: ATK down). One of each per monster, the stronger wins; bosses shake a
## weaken off in 40% of the time, players (rivals, guild fighters, the hero in the
## arena) feel half of a mark for 40% of the time.
const MARKS := ["shred", "weaken"]
const SHRED_CAP := 0.35
const WEAKEN_CAP := 0.30
const BOSS_WEAKEN_TIME := 0.4
const PLAYER_MARK := 0.5
const PLAYER_MARK_TIME := 0.4
## Word, colour and height over the head shown when a mark lands or grows.
const MARK_WORDS := {"shred": ["เกราะแตก!", Color("ff7ad9"), 0.55], "weaken": ["อ่อนแรง!", Color("9fb4ff"), 0.85]}
## Name tag tints while marked: cracked, sapped, both.
const MARK_TINTS := [Color("ffb0e6"), Color("b8c8ff"), Color("d8b0ff")]
## Mark words across every monster in one physics frame (a whole pack is hit at once).
const MARK_WORDS_PER_FRAME := 3
static var _word_frame := -1
static var _words := 0

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
var _taunt_chain: TauntChain
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
var _shred_time := 0.0
var _unshredded_def := 0.0
var _shred := 0.0
var _weaken := 0.0
var _weaken_time := 0.0
var _unweakened_atk := 0.0
## When each mark last showed its word (msec), and the tag's own colour while tinted.
var _word_at := {}
var _label_color: Variant = null
var _burn_dps := 0.0
var _burn_time := 0.0
## Damage taken from the hero's side and from world players (FieldPlayer): EXP and loot go
## to the hero by its share, like kill credit between real players.
var party_damage := 0
var others_damage := 0
## Who set the burn now ticking (its damage is credited like a hit).
var burn_source: Node
var _burn_tick := 0.0
var _anim_lock := 0
var _bar_until := 0.0
var _returning := false
var _yaw := 0.0
var phase := 0
var _atk_scale := 1.0
var _base_speed := 2.0
var _barrage_timer := 9.0
var _boss_moves := 0
var _dormant := false


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

	visual = _make_visual()
	if StarMonsters.has(monster_id): StarMonsterArt.attach(visual, template)
	var top := visual.height
	if not GameSettings.world_shadows():
		MeshKit.blob_shadow(self, clampf(float(template.height) * 0.55, 0.5, 1.6))

	_label = Label3D.new()
	_label.text = "Lv.%d %s" % [level, template.name]
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0046 * BattleVfx.text_scale
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


## The model of this monster (ranked-duel rivals override it with a hero model).
func _make_visual() -> MonsterVisual:
	var v := MonsterVisual.new()
	add_child(v)
	v.setup(String(template.model), float(template.height), float(template.get("hover", 0.0)), template.get("tint", Color.WHITE))
	v.add_to_group("anim_lod")
	return v


## Stop distant idle monsters while keeping fights, returning enemies and bosses awake.
## How far from home a hostile monster chases (guild-war fighters never give up).
func _leash() -> float:
	return LEASH


func set_dormant(on: bool) -> void:
	if on and (hostile or _returning or _dead or is_boss or _burn_time > 0.0):
		on = false
	if on == _dormant:
		return
	_dormant = on
	visible = not on
	set_physics_process(not on)
	visual.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if on:
		velocity = Vector3.ZERO


func is_dormant() -> bool:
	return _dormant


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
func take_hit(amount: int, crit: bool, _color := Color.WHITE, attacker: Node = null) -> bool:
	if _dead:
		return false
	set_dormant(false)
	_credit(attacker, mini(amount, hp))
	hp = maxi(0, hp - amount)
	_bar.set_ratio(float(hp) / float(max_hp))
	_bar.visible = true
	_bar_until = Time.get_ticks_msec() * 0.001 + 6.0
	BattleVfx.damage_number(get_parent(), top_point(), str(amount) + ("!" if crit else ""), false, 1.35 if crit else 1.0)
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


func _credit(attacker: Node, amount: int) -> void:
	if is_instance_valid(attacker) and attacker.is_in_group("world_players"):
		others_damage += amount
	else:
		party_damage += amount


## The hero's side's share of the damage this monster took (1 when untouched).
func party_share() -> float:
	var total := party_damage + others_damage
	return 1.0 if total <= 0 else float(party_damage) / float(total)


func provoke(alert_pack := true) -> void:
	if _dead:
		return
	set_dormant(false)
	if not hostile:
		hostile = true
		_returning = false
		_flash_alert()
	if alert_pack:
		for other in get_tree().get_nodes_in_group("mobs"):
			var m := other as Mob
			if m and m != self and not m.hostile and not m.is_dead() and m.global_position.distance_to(global_position) <= PACK_RADIUS:
				m.provoke(false)


## The Defender's provoke: this monster turns on [param by] for [param seconds]
## (bosses for 40% of it), whatever it was chasing.
func taunt(by: Node3D, seconds: float) -> void:
	if _dead or by == null or not is_instance_valid(by):
		return
	if is_boss:
		seconds *= 0.4
	_victim = by
	_victim_timer = maxf(_victim_timer, seconds)
	provoke(false)
	BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.7, 0), "ยั่วยุ!", Color("ff9a6a"), 0.7)
	# The challenge made visible: the monster flares red and a light chain binds it to the shield.
	if is_instance_valid(visual):
		visual.flash(Color("ff5a3a"), 0.3)
	if is_instance_valid(_taunt_chain):
		_taunt_chain.left = maxf(_taunt_chain.left, seconds)
	else:
		_taunt_chain = TauntChain.link(self, by, seconds)


func apply_stun(seconds: float) -> void:
	if is_boss:
		seconds *= 0.4
	_stun = maxf(_stun, seconds)
	_winding = false
	BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.4, 0), "มึน!", Color("ffe27a"), 0.75)


func apply_slow(seconds: float) -> void:
	_slow = maxf(_slow, seconds)


## Frozen solid (Poseidon's ice): held like a stun, with a frost tint for as long as it lasts.
func apply_freeze(seconds: float) -> void:
	if is_boss:
		seconds *= 0.4
	_stun = maxf(_stun, seconds)
	_winding = false
	visual.flash(Color(0.55, 0.85, 1.0), maxf(_stun, 0.5))
	ElementFx.ice_hit(get_parent(), hit_point())
	BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.4, 0), "แข็ง!", Color("bff4ff"), 0.85)


func apply_burn(dps: float, seconds: float) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, seconds)


## How far a repel (Imperial Judgment) throws monsters: 3 m round the caster.
const REPEL_DISTANCE := 3.0


## Throws the monster clear of a burst: it slides (walls still stop it) until its
## edge stands `radius` from `center`. Bosses hold their ground, as with knock_back.
func shove_out(center: Vector3, radius: float) -> void:
	if is_boss:
		return
	var dir := global_position - center
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	var gap := radius + body_radius() - dir.length()
	if gap > 0.0:
		# The slide slows by 12 m/s each second (_physics_process): v0 = sqrt(2 a d).
		velocity += dir.normalized() * sqrt(2.0 * 12.0 * gap)


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
	# A broken move (NaN) puts the monster back home instead of poisoning the camera,
	# the minimap and every distance check that looks at it.
	if not global_position.is_finite() or not velocity.is_finite():
		velocity = Vector3.ZERO
		global_position = home if home.is_finite() else Vector3.ZERO
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
			if _flat_distance(home) > _leash() or distance > _leash() + 12.0:
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
				_boss_moves = 0
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
	if phase >= 1 and not StarMonsters.has(monster_id) and not DivineRegionData.has_monster(monster_id) and not BossAttack.has_moves(template):
		_barrage_timer -= delta
		if _barrage_timer <= 0.0:
			_barrage_timer = 9.0 if phase == 1 else 6.0
			_meteor_barrage(target)
	if to.length_squared() > 0.01:
		_yaw = lerp_angle(_yaw, atan2(to.x, to.z), 1.0 - exp(-9.0 * delta))
		visual.rotation.y = _yaw
	# Dashing / leaping monsters start their move from farther away.
	var trigger := maxf(reach, MobAttack.trigger_range(template)) if MobAttack.knows(template) else reach
	if is_boss and _slam_timer <= 0.0 and distance < 9.0 and not _winding:
		_begin_slam()
	elif distance <= trigger and _attack_timer <= 0.0 and not _winding:
		_begin_attack(distance <= reach)
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


func _begin_attack(in_reach := true) -> void:
	if DivineRegionData.has_monster(monster_id):
		DivineAttack.start(self)
		return
	if StarMonsters.has(monster_id):
		StarAttack.start(self)
		return
	if MobAttack.knows(template) and MobAttack.launch(self):
		return
	if not in_reach:
		_attack_timer = 0.5
		return
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
		var victim_ref: WeakRef = weakref(victim)
		get_tree().create_timer(flight).timeout.connect(func():
			var hit_victim: Node3D = victim_ref.get_ref() as Node3D
			if hit_victim != null:
				_deliver(hit_victim, raw)
		, CONNECT_ONE_SHOT)
	else:
		_deliver(victim, raw, 1.5 + body_radius() * 1.2 + 1.0)


func _deliver(victim: Node3D, raw: float, max_distance := 99.0) -> void:
	if _dead or not _alive(victim):
		return
	if _flat_distance(victim.global_position) > max_distance:
		return
	victim.take_damage(raw, self)


## Hero or companion still standing.
func _alive(node: Variant) -> bool:
	return node != null and is_instance_valid(node) and node.has_method("is_dead") and not node.is_dead()


func _targets() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _alive(hero):
		out.append(hero)
	for node in get_tree().get_nodes_in_group("companions"):
		if _alive(node as Node3D):
			out.append(node as Node3D)
	for node in get_tree().get_nodes_in_group("world_players"):
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
	if DivineRegionData.has_monster(monster_id):
		DivineAttack.start(self, true)
		return
	if StarMonsters.has(monster_id):
		StarAttack.start(self,true)
		return
	if BossAttack.has_moves(template):
		BossAttack.start(self)
		return
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
		if BossAttack.has_moves(template) and BossAttack.MOVES.has(String(template.get("behavior2", ""))):
			_boss_moves = 0
			_slam_timer = minf(_slam_timer, 2.0)
			Game.say("%s คลั่งแล้ว! ท่าใหม่ \"%s\"" % [String(template.name), BossAttack.title(String(template.behavior2))], &"warning")
		else:
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
	if _shred_time > 0.0:
		_shred_time -= delta
		if _shred_time <= 0.0:
			_shred_time = 0.0
			_shred = 0.0
			stats.def = _unshredded_def
			_tint_marks()
	if _weaken_time > 0.0:
		_weaken_time -= delta
		if _weaken_time <= 0.0:
			_weaken_time = 0.0
			_weaken = 0.0
			stats.atk = _unweakened_atk
			_tint_marks()
	if _slow > 0.0:
		_slow -= delta
	if _burn_time > 0.0:
		_burn_time -= delta
		_burn_tick += delta
		if _burn_tick >= 0.5:
			_burn_tick -= 0.5
			var amount := maxi(1, int(_burn_dps * 0.5))
			# The one who lit it may have left the zone since (a world player logging off):
			# then the burn counts for nobody.
			if is_instance_valid(burn_source):
				_credit(burn_source, mini(amount, hp))
			hp = maxi(0, hp - amount)
			_bar.set_ratio(float(hp) / float(max_hp))
			_bar.visible = true
			BattleVfx.damage_number(get_parent(), top_point(), str(amount), false, 0.7)
			if hp <= 0:
				_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	hostile = false
	set_targeted(false)
	if is_instance_valid(_taunt_chain):
		_taunt_chain.queue_free()
	_label.visible = false
	_bar.visible = false
	_alert.visible = false
	collision_layer = 0
	remove_from_group("mobs")
	visual.hold("die")
	VfxKit.flash(get_parent(), hit_point(), Color("ffe9a0"), 2.6 if is_boss else 1.6)
	VfxKit.sparks(get_parent(), hit_point(), Color("ffe27a"), 30 if is_boss else 14, 5.0, 0.7)
	died.emit(self)
	_vanish()


## After dying the body shrinks away and the node is freed.
func _vanish() -> void:
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


# --- Marks: shred (DEF down) and weaken (ATK down) ---------------------------------

## Armour cracked: DEF drops by [param fraction] (at most 35%) for [param seconds].
## An equal or stronger mark takes over and keeps the longer time; a weaker one is
## ignored while the stronger runs. Expiry gives the DEF back.
func apply_shred(fraction: float, seconds: float) -> void:
	var f := clampf(fraction, 0.0, SHRED_CAP)
	if _dead or f <= 0.0 or seconds <= 0.0:
		return
	if _shred_time <= 0.0:
		_unshredded_def = float(stats.def)
		_shred = 0.0
	if f + 0.0001 < _shred:
		return
	var stronger := f > _shred + 0.0001
	_shred = f
	_shred_time = maxf(_shred_time, seconds)
	stats.def = _unshredded_def * (1.0 - _shred)
	_mark_feedback("shred", stronger)


## Strength sapped: ATK (every strike, slam, meteor and boss move reads it) drops by
## [param fraction] (at most 30%) for [param seconds] (bosses 40% of it). The same
## stronger-wins rule as the armour crack.
func apply_weaken(fraction: float, seconds: float) -> void:
	var f := clampf(fraction, 0.0, WEAKEN_CAP)
	if _dead or f <= 0.0 or seconds <= 0.0:
		return
	if is_boss:
		seconds *= BOSS_WEAKEN_TIME
	if _weaken_time <= 0.0:
		_unweakened_atk = float(stats.atk)
		_weaken = 0.0
	if f + 0.0001 < _weaken:
		return
	var stronger := f > _weaken + 0.0001
	_weaken = f
	_weaken_time = maxf(_weaken_time, seconds)
	stats.atk = _unweakened_atk * (1.0 - _weaken)
	_mark_feedback("weaken", stronger)


## Seconds left of a mark ("shred" / "weaken"), 0 without it. The AI reads it so it
## does not mark again what is still marked.
func debuff_left(key: String) -> float:
	if key == "shred":
		return maxf(_shred_time, 0.0)
	if key == "weaken":
		return maxf(_weaken_time, 0.0)
	return 0.0


## Whether [param fx] (a skill's effects) leaves a mark.
static func carries_mark(fx: Dictionary) -> bool:
	return fx.get("shred") is Array or fx.get("weaken") is Array


## True when [param target] lacks one of the marks [param fx] leaves, or keeps it
## for [param margin] seconds at most. What cannot be marked (a summon) never lacks one.
static func lacks_mark(target: Variant, fx: Dictionary, margin: float) -> bool:
	if target == null or not is_instance_valid(target) or not (target as Object).has_method("debuff_left"):
		return false
	for key in MARKS:
		if fx.get(key) is Array and float(target.debuff_left(key)) <= margin:
			return true
	return false


## At most MARK_WORDS_PER_FRAME mark words in one physics frame, over every monster.
static func mark_word_ok() -> bool:
	var frame := Engine.get_physics_frames()
	if frame != _word_frame:
		_word_frame = frame
		_words = 0
	if _words >= MARK_WORDS_PER_FRAME:
		return false
	_words += 1
	return true


## A mark landed: the tag is tinted, and a new or stronger mark shows its word and a
## flash (each mark at most once in 1.2 s; refreshing the same mark shows nothing).
func _mark_feedback(key: String, stronger: bool) -> void:
	_tint_marks()
	if not stronger or not is_inside_tree() or not (get_parent() is Node3D):
		return
	var now := Time.get_ticks_msec()
	if now - int(_word_at.get(key, -100000)) < 1200 or not mark_word_ok():
		return
	_word_at[key] = now
	var word: Array = MARK_WORDS[key]
	BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, float(word[2]), 0), String(word[0]), word[1], 0.7)
	if is_instance_valid(visual):
		visual.flash(word[1], 0.25)


## The name tag while marked: pink cracked, blue sapped, violet both; its own colour
## (boss gold, guild colours) comes back when the marks end.
func _tint_marks() -> void:
	if _label == null:
		return
	var cracked := debuff_left("shred") > 0.0
	var sapped := debuff_left("weaken") > 0.0
	if not cracked and not sapped:
		if _label_color != null:
			_label.modulate = _label_color
			_label_color = null
		return
	if _label_color == null:
		_label_color = _label.modulate
	_label.modulate = MARK_TINTS[2 if cracked and sapped else (0 if cracked else 1)]
