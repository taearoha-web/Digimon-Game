class_name Summon
extends Node3D
## A creature or floating blade the hero calls with a summoner skill. It follows
## the hero, picks the hero's target (or the nearest monster) and attacks. It
## has its own health bar, monsters can attack it, and it lasts 3 minutes or
## until it is killed. Its size grows by one body-size per skill star.

## Seconds a summon stays (3 minutes).
const LIFETIME := 180.0

const KINDS := {
	"falcon": {"model": "flying/Pigeon", "height": 1.0, "hover": 1.8, "tint": Color(1.6, 1.3, 0.5), "ranged": true, "speed": 7.0, "range": 7.0, "color": Color("ffd84a")},
	"wolf": {"model": "blob/Dog", "height": 1.25, "hover": 0.0, "tint": Color(0.85, 0.95, 1.3), "ranged": false, "speed": 6.5, "range": 1.8, "color": Color("bfe0ff")},
	"beast": {"model": "big/Dino", "height": 1.9, "hover": 0.0, "tint": Color(0.7, 1.4, 0.7), "ranged": false, "speed": 5.2, "range": 2.2, "color": Color("7aff8a")},
	"elemental": {"model": "flying/Ghost", "height": 1.5, "hover": 0.9, "tint": Color(0.7, 1.2, 1.7), "ranged": true, "speed": 5.0, "range": 8.0, "color": Color("7fe3ff")},
	"fire_elemental": {"model": "flying/Ghost", "height": 2.2, "hover": 0.9, "tint": Color(1.8, 0.7, 0.3), "ranged": true, "speed": 5.0, "range": 8.5, "color": Color("ff7a2a")},
	"muspell": {"model": "big/Yeti", "height": 2.4, "hover": 0.0, "tint": Color(0.7, 0.95, 1.6), "ranged": false, "speed": 4.8, "range": 2.6, "color": Color("aaf0ff")},
	"sword": {"proc": true, "hover": 1.7, "ranged": false, "speed": 9.0, "range": 1.6, "color": Color("e6f4ff")},
}

var hero: Hero
var skill_id := ""
var spec: Dictionary = {}
var damage_mult := 1.0
var life := LIFETIME
var rank := 1
var size_mult := 1.0
var max_hp := 1
var hp := 1

var _kind: Dictionary = {}
var _visual: MonsterVisual
var _blade: Node3D
var _slot := 0
var _slots := 1
var _target: Mob
var _attack_timer := 0.5
var _age := 0.0
var _fading := false
var _dead := false
var _bar: FieldHpBar


func setup(p_hero: Hero, p_skill_id: String, p_spec: Dictionary, p_damage_mult: float, slot: int, slots: int, p_rank := 1) -> void:
	hero = p_hero
	skill_id = p_skill_id
	spec = p_spec
	damage_mult = p_damage_mult
	rank = clampi(p_rank, 1, 10)
	# One extra body-size per star: 1x at 1 star, 2x at 2 stars ... 5x at 5 stars.
	size_mult = float(rank)
	life = float(spec.get("secs", LIFETIME))
	max_hp = maxi(300, int(round(float(hero.stats.max_hp) * 0.8 * (1.0 + 0.6 * float(rank - 1)))))
	hp = max_hp
	_slot = slot
	_slots = maxi(slots, 1)
	_kind = KINDS.get(String(spec.get("kind", "wolf")), KINDS["wolf"])


func _ready() -> void:
	add_to_group("summons")
	var around := _formation()
	global_position = hero.global_position + around
	if bool(_kind.get("proc", false)):
		_blade = _build_blade()
		add_child(_blade)
	else:
		_visual = MonsterVisual.new()
		add_child(_visual)
		_visual.setup(String(_kind.model), float(_kind.height), float(_kind.hover), _kind.tint)
	scale = Vector3.ONE * 0.05
	create_tween().tween_property(self, "scale", Vector3.ONE * size_mult, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	VfxKit.shockwave(get_parent(), global_position + Vector3(0, 0.1, 0), _kind.color, 2.2 * size_mult)
	# Health bar above the head (the node is scaled, so the bar is placed in local units).
	var top: float = (float(_kind.height) if _kind.has("height") else 1.8) + float(_kind.hover) + 0.5
	_bar = FieldHpBar.new()
	_bar.position = Vector3(0, top, 0)
	_bar.scale = Vector3.ONE * 1.3 / sqrt(size_mult)
	add_child(_bar)


func _build_blade() -> Node3D:
	var root := Node3D.new()
	root.position.y = float(_kind.hover)
	var blade := MeshInstance3D.new()
	blade.mesh = MeshKit.prism()
	blade.material_override = MeshKit.toon(Color("e6f4ff"), {"emission": 1.4})
	blade.scale = Vector3(0.22, 1.5, 0.08)
	blade.rotation_degrees = Vector3(180, 0, 0)
	root.add_child(blade)
	var guard := MeshInstance3D.new()
	guard.mesh = MeshKit.box()
	guard.material_override = MeshKit.toon(Color("ffd84a"), {"emission": 0.8})
	guard.scale = Vector3(0.5, 0.08, 0.1)
	guard.position.y = 0.78
	root.add_child(guard)
	return root


func _formation() -> Vector3:
	var angle := TAU * float(_slot) / float(_slots) + PI * 0.5
	return Vector3(cos(angle), 0.0, sin(angle)) * (2.6 + 1.2 * (size_mult - 1.0))


func _process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or hero.is_dead():
		queue_free()
		return
	_age += delta
	life -= delta
	if life <= 0.0 and not _fading:
		_vanish()
	if _fading:
		return
	_attack_timer -= delta
	if not _valid(_target):
		_target = _pick_target()
	var goal := hero.global_position + _formation()
	var want_range := 0.0
	if _valid(_target):
		goal = _target.global_position
		want_range = _reach() * 0.85
	var to := goal - global_position
	to.y = 0.0
	var speed := float(_kind.speed)
	if to.length() > want_range + 0.3:
		var step := minf(to.length() - want_range, speed * delta * (1.0 if _valid(_target) else 1.6))
		global_position += to.normalized() * maxf(step, 0.0)
		_face(to, delta)
		if _visual:
			_visual.play("run" if speed > 4.0 else "walk")
	elif _visual:
		_visual.play("idle")
	global_position.y = hero.global_position.y
	if _blade:
		_blade.rotation.y += delta * 7.0
		_blade.position.y = float(_kind.hover) + sin(_age * 4.0 + float(_slot)) * 0.12
	if _valid(_target) and _attack_timer <= 0.0:
		var dist := Vector2(_target.global_position.x - global_position.x, _target.global_position.z - global_position.z).length() - _target.body_radius()
		if dist <= _reach() + 0.4:
			_attack()


func is_dead() -> bool:
	return _dead


## Monsters hit summons like any other ally.
func take_damage(raw: float, _attacker: Node = null) -> void:
	if _dead or _fading or not is_instance_valid(hero):
		return
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(hero.stats.def) * 0.6))))
	hp = maxi(0, hp - amount)
	_bar.set_ratio(float(hp) / float(max_hp))
	BattleVfx.floating_text(get_parent(), global_position + Vector3(0, (float(_kind.hover) + 1.8) * size_mult, 0), str(amount), Color("ff7a8a"), 1.0)
	if _visual:
		_visual.flash()
	if hp <= 0:
		_dead = true
		remove_from_group("summons")
		BattleVfx.floating_text(get_parent(), global_position + Vector3(0, (float(_kind.hover) + 2.2) * size_mult, 0), "ซัมมอนถูกสังหาร", Color("ffb0b0"), 1.1)
		VfxKit.sparks(get_parent(), global_position + Vector3(0, 1.0, 0), _kind.color, 24, 4.0, 0.7)
		_vanish()


func _vanish() -> void:
	if _fading:
		return
	_fading = true
	remove_from_group("summons")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.05, 0.35)
	tween.tween_callback(queue_free)


func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return
	var yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-14.0 * delta))


## Bigger summons reach further.
func _reach() -> float:
	return float(_kind.range) * (1.0 + 0.5 * (size_mult - 1.0))


func _valid(mob: Variant) -> bool:
	return mob != null and is_instance_valid(mob) and not (mob as Mob).is_dead()


func _pick_target() -> Mob:
	if _valid(hero.target):
		return hero.target
	var best: Mob = null
	var best_d := 16.0
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and not mob.is_dead():
			var d := Vector2(mob.global_position.x - hero.global_position.x, mob.global_position.z - hero.global_position.z).length()
			if d < best_d:
				best_d = d
				best = mob
	return best


func _attack() -> void:
	_attack_timer = float(spec.get("interval", 1.0))
	var mob := _target
	var color: Color = _kind.color
	if _visual:
		_visual.action("attack", 380)
	var strike := func():
		if not _valid(mob) or not is_instance_valid(hero):
			return
		var raw: float = float(hero.stats.atk) * damage_mult * randf_range(0.92, 1.08)
		var crit := randf() < float(hero.stats.crit)
		if crit:
			raw *= HeroStats.CRIT_DAMAGE
		var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(mob.stats.def)))))
		VfxKit.impact(get_parent(), mob.hit_point(), color, 0.9)
		mob.take_hit(amount, crit, color, hero)
		if spec.has("heal"):
			hero.receive_heal(float(spec.heal))
	if bool(_kind.ranged):
		var from := global_position + Vector3(0, float(_kind.hover) + 0.8, 0)
		var to := mob.hit_point()
		var flight := clampf(from.distance_to(to) / 22.0, 0.1, 0.5)
		VfxKit.projectile(get_parent(), color, from, to, flight, 0.4, "spark")
		get_tree().create_timer(flight).timeout.connect(strike, CONNECT_ONE_SHOT)
	else:
		get_tree().create_timer(0.18).timeout.connect(strike, CONNECT_ONE_SHOT)
