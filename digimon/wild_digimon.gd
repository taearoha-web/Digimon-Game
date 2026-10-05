class_name WildDigimon
extends CharacterBody3D
## A wild Digimon roaming its spawn region. In real-time field combat it has
## its own HP, fights back when hurt (or on sight, for Virus types) and hunts
## the player's partner. AI is intentionally light: decisions a few times per
## second, and fully asleep when the player is far away.

signal died(wild: WildDigimon)
signal despawned(wild: WildDigimon)

const NOTICE_RADIUS := 7.0
const SLEEP_DISTANCE := 55.0
## Gives up the chase when this far from its home region.
const LEASH_DISTANCE := 26.0
const PACK_ALERT_RADIUS := 6.0
const MELEE_REACH := 1.9
const RANGED_REACH := 6.5
const WINDUP_SECONDS := 0.6
## Wild damage is scaled so a pack is dangerous but not deadly at low level.
const DAMAGE_SCALE := 0.5

var species_id: StringName
var level := 3
var spawn_key := ""
var region_center := Vector3.ZERO
var region_extents := Vector3(10, 0, 10)
var player: Node3D
## False = never turns hostile on its own (used to keep scenes calm).
var encounters_enabled := true
var instance: DigimonInstance
var combatant: BattleCombatant
var hostile := false
var contributors: Array[String] = []

var visual: DigimonVisual
var _label: Label3D
var _alert: Label3D
var _hp_bar: FieldHpBar
var _target_ring: MeshInstance3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var _goal := Vector3.ZERO
var _think_timer := 0.0
var _pause_timer := 0.0
var _speed := 2.0
var _aggressive := false
var _noticed := false
var _yaw := 0.0
var _dead := false
var _winding_up := false
var _attack_timer := 1.0
var _attack_skill: SkillData
var _anim_lock_until := 0
var _bar_visible_until := 0.0
var _combat: FieldCombat


func setup(p_species_id: StringName, p_level: int, center: Vector3, extents: Vector3, p_player: Node3D) -> void:
	species_id = p_species_id
	level = p_level
	region_center = center
	region_extents = extents
	player = p_player


func _ready() -> void:
	add_to_group("wild_digimon")
	collision_layer = 1 << 2
	collision_mask = 1 << 0
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.0
	shape.shape = capsule
	shape.position = Vector3(0, 0.5, 0)
	add_child(shape)

	instance = DigimonInstance.create(species_id, level)
	combatant = BattleCombatant.new(instance, BattleCombatant.ENEMY_SIDE)
	visual = DigimonVisual.new()
	add_child(visual)
	visual.set_species(species_id)
	var species := visual.species
	_speed = (species.move_speed if species else 3.0) * 0.55
	_aggressive = species != null and species.attribute == DigimonSpecies.Attribute.VIRUS

	_label = Label3D.new()
	_label.text = L10n.t("Lv %d %s") % [level, species.display_name if species else String(species_id)]
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.004
	_label.font_size = 44
	_label.outline_size = 12
	_label.modulate = Color(1, 0.92, 0.8)
	_label.no_depth_test = false
	_label.visibility_range_end = 16.0
	_label.position = Vector3(0, visual.model_height + 0.45, 0)
	add_child(_label)
	_hp_bar = FieldHpBar.new()
	_hp_bar.position = Vector3(0, visual.model_height + 0.2, 0)
	_hp_bar.visible = false
	add_child(_hp_bar)
	_alert = Label3D.new()
	_alert.text = "!"
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.pixel_size = 0.01
	_alert.font_size = 64
	_alert.outline_size = 16
	_alert.modulate = Color(1.0, 0.35, 0.3)
	_alert.position = Vector3(0, visual.model_height + 0.95, 0)
	_alert.visible = false
	add_child(_alert)
	_pick_goal()
	# Pop-in spawn animation.
	visual.scale = Vector3.ONE * 0.01
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combat = get_tree().get_first_node_in_group("field_combat") as FieldCombat
	if _combat:
		_combat.register(self)


func is_dead() -> bool:
	return _dead


func get_hit_point() -> Vector3:
	return global_position + Vector3(0, visual.model_height * 0.55 if visual else 0.7, 0)


func get_top_point() -> Vector3:
	return global_position + Vector3(0, (visual.model_height if visual else 1.0) + 0.3, 0)


## Marks this monster as the locked-on target (ring on the ground + HP bar).
func set_targeted(on: bool) -> void:
	if on and _target_ring == null:
		_target_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.62
		torus.outer_radius = 0.72
		torus.rings = 24
		_target_ring.mesh = torus
		_target_ring.material_override = MeshKit.toon(UIPalette.DANGER, {"unshaded": true, "emission": 1.5})
		_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_target_ring.position = Vector3(0, 0.06, 0)
		var s := clampf(visual.model_height * 0.9, 0.8, 2.2)
		_target_ring.scale = Vector3(s, 0.4, s)
		add_child(_target_ring)
	if _target_ring:
		_target_ring.visible = on
	if _hp_bar:
		_hp_bar.visible = on or Time.get_ticks_msec() * 0.001 < _bar_visible_until


## Applies damage from the partner or a status effect. Returns true if this
## killed the monster.
func take_damage(amount: int, attacker_uid := "") -> bool:
	if _dead:
		return false
	instance.take_damage(amount)
	_hp_bar.set_ratio(instance.get_hp_ratio())
	_hp_bar.visible = true
	_bar_visible_until = Time.get_ticks_msec() * 0.001 + 6.0
	if attacker_uid != "" and not contributors.has(attacker_uid):
		contributors.append(attacker_uid)
	if instance.is_fainted():
		_die()
		return true
	provoke()
	return false


## Turns hostile (and rouses nearby monsters of the pack).
func provoke(alert_pack := true) -> void:
	if _dead:
		return
	if not hostile:
		hostile = true
		_show_alert()
	if alert_pack:
		for other in get_tree().get_nodes_in_group("wild_digimon"):
			var w := other as WildDigimon
			if w and w != self and not w.hostile and not w.is_dead() \
					and w.global_position.distance_to(global_position) <= PACK_ALERT_RADIUS:
				w.provoke(false)


func play_hurt() -> void:
	if _dead:
		return
	visual.flash(Color(1, 1, 1))
	visual.play_once(&"hurt", &"idle")
	_anim_lock_until = Time.get_ticks_msec() + 350


## Short shove away from [param from], used by hits (the velocity eases back
## to normal on its own).
func knock_back(from: Vector3, strength := 2.5) -> void:
	var dir := global_position - from
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		velocity += dir.normalized() * strength


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if player and global_position.distance_squared_to(player.global_position) > SLEEP_DISTANCE * SLEEP_DISTANCE:
		return # Asleep: far from the player.
	if _combat and _combat.paused:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	_tick_status(delta)
	if _dead:
		return
	if _bar_visible_until > 0.0 and Time.get_ticks_msec() * 0.001 > _bar_visible_until \
			and (_target_ring == null or not _target_ring.visible):
		_hp_bar.visible = false
		_bar_visible_until = 0.0
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = 0.3
		_think()
	var stunned := FieldSkillResolver.is_disabled(combatant)
	var speed_factor := FieldSkillResolver.speed_factor(combatant)
	var desired := Vector3.ZERO
	var chase := _get_chase_target() if hostile and not stunned else null
	if chase:
		desired = _chase(chase, delta, speed_factor)
	elif stunned or _winding_up:
		desired = Vector3.ZERO
	elif _pause_timer > 0.0:
		_pause_timer -= delta
	else:
		var to_goal := _goal - global_position
		to_goal.y = 0.0
		if to_goal.length() < 0.6:
			_pause_timer = randf_range(1.5, 4.0)
			_pick_goal()
		else:
			desired = to_goal.normalized() * _speed * speed_factor
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(desired, 10.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	_update_animation(horizontal, delta, chase)


func _chase(target: Node3D, delta: float, speed_factor: float) -> Vector3:
	var to := target.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var reach := _attack_reach()
	_attack_timer -= delta
	if to.length_squared() > 0.01:
		_yaw = lerp_angle(_yaw, atan2(to.x, to.z), 1.0 - exp(-8.0 * delta))
		visual.rotation.y = _yaw
	if distance <= reach and _attack_timer <= 0.0 and not _winding_up:
		_begin_attack(target)
	if _winding_up or distance <= reach * 0.85:
		return Vector3.ZERO
	return to.normalized() * _speed * 1.7 * speed_factor


func _update_animation(horizontal: Vector3, delta: float, chase: Node3D) -> void:
	if Time.get_ticks_msec() < _anim_lock_until:
		return
	if horizontal.length() > 0.2:
		if chase == null:
			_yaw = lerp_angle(_yaw, atan2(horizontal.x, horizontal.z), 1.0 - exp(-6.0 * delta))
			visual.rotation.y = _yaw
		visual.play_animation(&"run" if horizontal.length() > _speed * 1.4 else &"walk")
	elif _noticed and player and chase == null:
		var to_player := player.global_position - global_position
		_yaw = lerp_angle(_yaw, atan2(to_player.x, to_player.z), 1.0 - exp(-6.0 * delta))
		visual.rotation.y = _yaw
		visual.play_animation(&"idle")
	else:
		visual.play_animation(&"idle")


func _think() -> void:
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	var was_noticed := _noticed
	_noticed = distance < NOTICE_RADIUS and encounters_enabled
	if _noticed and not was_noticed and _aggressive:
		_show_alert()
		hostile = true
	if hostile and (not encounters_enabled or global_position.distance_to(region_center) > LEASH_DISTANCE \
			or distance > LEASH_DISTANCE + 6.0):
		hostile = false # lost interest
		_winding_up = false
		_pick_goal()


func _get_chase_target() -> Node3D:
	var partner := get_tree().get_first_node_in_group("partner") as Node3D
	if partner and _combat and _combat.partner_alive():
		return partner
	return null


func _attack_reach() -> float:
	return RANGED_REACH if (_attack_skill != null and _attack_skill.projectile) else MELEE_REACH


func _pick_skill() -> SkillData:
	var options: Array[SkillData] = []
	for skill in combatant.get_equipped_skills():
		if skill.target == SkillData.Target.ENEMY and skill.deals_damage():
			options.append(skill)
	if options.is_empty():
		return GameData.get_skill(&"tackle")
	return options.pick_random()


func _begin_attack(target: Node3D) -> void:
	_attack_skill = _pick_skill()
	if _attack_skill == null:
		return
	if global_position.distance_to(target.global_position) > _attack_reach():
		return
	_winding_up = true
	# Telegraph: squash + red flash so the player can see the hit coming.
	visual.flash(Color(1.0, 0.25, 0.2), WINDUP_SECONDS)
	var squash := create_tween()
	squash.tween_property(visual, "scale", Vector3(1.12, 0.88, 1.12), WINDUP_SECONDS * 0.8)
	squash.tween_property(visual, "scale", Vector3.ONE, 0.12)
	get_tree().create_timer(WINDUP_SECONDS).timeout.connect(_strike, CONNECT_ONE_SHOT)


func _strike() -> void:
	_winding_up = false
	_attack_timer = randf_range(2.0, 3.2)
	if _dead or _attack_skill == null or _combat == null:
		return
	visual.play_once(&"attack" if _attack_skill.animation == &"attack" else &"skill", &"idle")
	_anim_lock_until = Time.get_ticks_msec() + 450
	_combat.enemy_attack(self, _attack_skill)


func _tick_status(delta: float) -> void:
	for event in FieldSkillResolver.tick(combatant, delta):
		if event.type == "status_damage":
			_hp_bar.set_ratio(instance.get_hp_ratio())
			_hp_bar.visible = true
			_bar_visible_until = Time.get_ticks_msec() * 0.001 + 6.0
			BattleVfx.floating_text(get_parent(), get_top_point(), str(int(event.amount)), StatusEffects.get_color(event.status_id), 0.8)
			if event.killed:
				_die()
				return


func _die() -> void:
	if _dead:
		return
	_dead = true
	hostile = false
	set_targeted(false)
	_alert.visible = false
	_label.visible = false
	_hp_bar.visible = false
	collision_layer = 0
	remove_from_group("wild_digimon")
	visual.play_once(&"defeat", &"")
	died.emit(self)
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.35)
	tween.tween_callback(func():
		despawned.emit(self)
		queue_free())


func _show_alert() -> void:
	_alert.visible = true
	_alert.scale = Vector3.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(_alert, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.2)
	tween.tween_callback(func(): _alert.visible = false)


func _pick_goal() -> void:
	_goal = region_center + Vector3(randf_range(-region_extents.x, region_extents.x), 0, randf_range(-region_extents.z, region_extents.z))


## Removes the Digimon with a small shrink animation.
func despawn() -> void:
	encounters_enabled = false
	hostile = false
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.3)
	tween.tween_callback(func():
		despawned.emit(self)
		queue_free())
