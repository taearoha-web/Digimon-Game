class_name SummonMob
extends Mob
## A summon on the enemy side: what an AI summoner (a ranked-duel rival or a
## fighter of the rival guild) calls. It is a [Mob], so the hero's targeting,
## skills and own summons hit it, and it follows the monster AI (chase, basic
## attacks, warnings) with the summon's look, aura and lifetime. Legends cast
## their two moves (LegendMoves) with a danger circle first, like every enemy
## area attack, and the Fairy Spirit only heals her summoner. It never drops
## loot or EXP and does not count as a fallen fighter.

var caster: Rival
var skill_id := ""
var spec: Dictionary = {}
var damage_mult := 1.0
var life := Summon.LIFETIME
var rank := 1
var size_mult := 1.0
var war_scale := 1.0

var _kind: Dictionary = {}
var _kind_id := "wolf"
var _slot := 0
var _slots := 1
var _move_cds: Dictionary = {}
var _heal_timer := 3.0
var _expired := false
var _age := 0.0
var _twirl: Tween


func setup_summon(p_caster: Rival, p_skill_id: String, p_spec: Dictionary, p_damage_mult: float, slot: int, slots: int, p_rank := 1) -> void:
	caster = p_caster
	hero = p_caster.hero
	skill_id = p_skill_id
	spec = p_spec
	damage_mult = p_damage_mult
	rank = clampi(p_rank, 1, 10)
	size_mult = Summon.size_for_rank(rank)
	life = float(spec.get("secs", Summon.LIFETIME))
	_slot = slot
	_slots = maxi(slots, 1)
	_kind_id = String(spec.get("kind", "wolf"))
	_kind = Summon.KINDS.get(_kind_id, Summon.KINDS["wolf"])
	war_scale = p_caster.war_scale
	monster_id = &"summon"
	level = p_caster.level
	home = p_caster.global_position + (_fairy_spot() if is_fairy() else _formation())
	var rs: Dictionary = p_caster.rstats
	var legend := bool(_kind.get("legend", false))
	var share := Summon.LEGEND_HP_SHARE if legend else Summon.HP_SHARE
	hp = maxi(300, int(round(float(rs.max_hp) * share * (1.0 + 0.6 * float(rank - 1)))))
	max_hp = hp
	var model := String(_kind.get("model", ""))
	template = {
		"name": String(_kind.get("name", skill_id)), "model": model if model != "" else "blob/Dog",
		"height": float(_kind.get("height", 1.5)), "hover": float(_kind.get("hover", 0.0)), "tint": _kind.get("tint", Color.WHITE),
		"speed": float(_kind.speed) * 0.55, "aggro": true, "attack": "ranged" if bool(_kind.get("ranged", false)) else "melee",
		"boss": false, "color": _kind.color,
	}
	stats = {"hp": hp, "atk": float(rs.atk) * damage_mult * Summon.HIT_SHARE, "def": float(rs.def) * (0.8 if legend else 0.6), "exp": 0, "gold": 0}
	_speed = float(template.speed)
	_base_speed = _speed
	hostile = true
	for move in LegendMoves.moves(_kind_id):
		_move_cds[move.id] = randf_range(2.0, 3.5)


func is_fairy() -> bool:
	return bool(_kind.get("fairy", false))


func _make_visual() -> MonsterVisual:
	if is_fairy():
		var fairy := FairyVisual.new()
		add_child(fairy)
		fairy.setup_fairy(float(_kind.hover))
		fairy.add_to_group("anim_lod")
		return fairy
	return super._make_visual()


func _ready() -> void:
	super._ready()
	if caster and caster.is_in_group("gw_team1"):
		add_to_group("gw_team1")
	_label.modulate = _kind.color
	var glow := ShaderMaterial.new()
	glow.shader = Summon.SPIRIT_SHADER
	glow.set_shader_parameter("color", (_kind.color as Color).lightened(0.15))
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = glow
	SummonAura.attach(visual, _kind_id, _kind, rank)
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(self) and is_instance_valid(visual):
			create_tween().tween_property(visual, "scale", Vector3.ONE * (1.0 if is_fairy() else size_mult), 0.25)
		, CONNECT_ONE_SHOT)


func _formation() -> Vector3:
	var angle := TAU * float(_slot) / float(_slots) - PI * 0.5
	return Vector3(cos(angle), 0.0, sin(angle)) * 2.6


## The enemy fairy's spot: the mirror of Summon._fairy_spot around her caster, 2.0 m
## behind the way the caster faces (so beyond him from whoever he fights), sweeping
## the same slow pendulum.
func _fairy_spot() -> Vector3:
	var yaw := float(caster._yaw) if caster else 0.0
	var a := sin(_age * 0.45) * deg_to_rad(70.0)
	return Vector3(sin(a) * Summon.FAIRY_ORBIT, 0.0, -cos(a) * Summon.FAIRY_ORBIT).rotated(Vector3.UP, yaw)


func _caster_alive() -> bool:
	return caster != null and is_instance_valid(caster) and not caster.is_dead() and not caster.duel_over


func _physics_process(delta: float) -> void:
	if _dead:
		return
	life -= delta
	if not _caster_alive() or life <= 0.0:
		_expire()
		return
	home = caster.global_position
	hostile = true
	_returning = false
	for id in _move_cds:
		_move_cds[id] = maxf(0.0, float(_move_cds[id]) - delta)
	if is_fairy():
		_tick_fairy(delta)
		return
	super._physics_process(delta)


## No wandering: a summon without a victim walks back beside its summoner.
func _wander(delta: float) -> Vector3:
	var to := home + _formation() - global_position
	to.y = 0.0
	if to.length() < 0.8:
		return Vector3.ZERO
	return to.normalized() * _speed * 1.6


func _chase(target: Node3D, delta: float, speed_factor: float) -> Vector3:
	var out := super._chase(target, delta, speed_factor)
	if not _winding and _stun <= 0.0:
		var distance := _flat_distance(target.global_position)
		for move in LegendMoves.moves(_kind_id):
			if float(_move_cds.get(move.id, 0.0)) > 0.0:
				continue
			var reach := float(move.radius) * 0.9 if String(move.shape) == "self" else 8.0
			if distance <= reach:
				_cast_move(move, target)
				return Vector3.ZERO
	return out


## The move is warned with a danger circle (dodgeable) and lands when the clip comes down.
func _cast_move(move: Dictionary, target: Node3D) -> void:
	_move_cds[move.id] = float(move.cd) * 1.2
	_winding = true
	_attack_timer = maxf(_attack_timer, float(move.lock) + 0.4)
	var center := global_position if String(move.shape) == "self" else target.global_position
	center.y = 0.0
	var radius := float(move.radius) * (1.0 + 0.3 * (size_mult - 1.0))
	var warn := float(move.impact) + 0.5
	VfxKit.danger_circle(get_parent(), center, radius, warn)
	visual.flash(Color(1.0, 0.3, 0.2), warn)
	visual.action(String(move.clip), int((float(move.lock) + 0.5) * 1000.0), float(move.lock) / (float(move.lock) + 0.5))
	_anim_lock = Time.get_ticks_msec() + int((float(move.lock) + 0.5) * 1000.0)
	get_tree().create_timer(warn).timeout.connect(func():
		_winding = false
		if _dead or _expired:
			return
		LegendMoves.impact_vfx(get_parent(), String(move.style), center, radius)
		for t in _targets():
			if _flat_distance_from(t.global_position, center) <= radius:
				_deliver(t, float(stats.atk) * float(move.power) * randf_range(0.92, 1.08))
				LegendMoves.afflict(move, t)
		, CONNECT_ONE_SHOT)


## War-scaled like every fighter's hit; the hero keeps the BurstGuard protection.
func _deliver(victim: Node3D, raw: float, max_distance := 99.0) -> void:
	if _dead or _expired or not _alive(victim):
		return
	if _flat_distance(victim.global_position) > max_distance:
		return
	raw *= war_scale
	if war_scale > 1.0 and victim == hero and "stats" in hero:
		var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(hero.stats.def)))))
		var allowed := BurstGuard.take(hero.get_instance_id(), amount, int(hero.stats.max_hp))
		if allowed < amount:
			raw *= float(allowed) / float(amount)
	victim.take_damage(raw, self)


## Like Summon._tick_fairy: she drifts sideways to her spot behind the caster, always
## facing the hero (her caster's foe), hovering with a bob, and heals on her clock.
func _tick_fairy(delta: float) -> void:
	_age += delta
	var goal := home + _fairy_spot()
	var to := goal - global_position
	to.y = 0.0
	var desired := Vector3.ZERO
	if to.length() > Summon.FAIRY_DEADBAND:
		desired = to.normalized() * _speed * 1.8
	var face := (hero.global_position if hero and is_instance_valid(hero) else home) - global_position
	if face.length_squared() > 0.001:
		_yaw = lerp_angle(_yaw, atan2(face.x, face.z), 1.0 - exp(-9.0 * delta))
	if _twirl == null or not _twirl.is_running():
		visual.rotation.y = _yaw
	visual.play("idle")
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(desired, 12.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	visual.position.y = sin(Time.get_ticks_msec() * 0.0022) * 0.12
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		_heal_timer = Summon.FAIRY_EVERY
		visual.action("attack", 700)
		_twirl = Summon.fairy_twirl(visual)
		AudioManager.play_sfx(&"fairy_twirl", -9.0)
		var color: Color = _kind.color
		VfxKit.impact_ring(get_parent(), global_position + Vector3(0, 0.7, 0), color, 3.0, 0.8)
		BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.6, 0), "ฮีล +%d%%" % int(Summon.FAIRY_HEAL * 100.0), color, 0.9)
		caster._heal(Summon.FAIRY_HEAL)
		AudioManager.play_sfx(&"fairy_heal", -6.0)


## War-scaled like its summoner's own body, and in a war or duel one hit and one pile-on
## are capped like every fighter's: a swarm still wins, but not in one beat.
func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
	if _dead or _expired:
		return false
	amount = int(ceil(float(amount) * war_scale))
	if war_scale > 1.0:
		amount = BurstGuard.take(get_instance_id(), amount, max_hp)
	return super.take_hit(amount, crit, color, attacker)


func take_damage(raw: float, attacker: Node = null) -> void:
	if _dead or _expired:
		return
	take_hit(maxi(1, int(round(HeroStats.mitigate(raw, float(stats.def))))), false, Color.WHITE, attacker)


## Killed: no loot, no EXP, not a fallen fighter — it just fades.
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
	remove_from_group("gw_team1")
	BurstGuard.forget(get_instance_id())
	BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.4, 0), "ซัมมอนถูกสังหาร", Color("ffb0b0"), 1.1)
	VfxKit.sparks(get_parent(), hit_point(), _kind.color, 24, 4.0, 0.7)
	_vanish()


## Time is up, or the summoner fell: fade out quietly.
func _expire() -> void:
	if _expired or _dead:
		return
	_expired = true
	_dead = true
	hostile = false
	set_targeted(false)
	_label.visible = false
	_bar.visible = false
	collision_layer = 0
	remove_from_group("mobs")
	remove_from_group("gw_team1")
	BurstGuard.forget(get_instance_id())
	VfxArt.motes(get_parent(), global_position + Vector3(0, 0.8, 0), (_kind.color as Color).lightened(0.3), "star", 10, 0.8, 1.6, 0.9)
	_vanish()


func _vanish() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 0.05, 0.35)
	tween.tween_callback(queue_free)
