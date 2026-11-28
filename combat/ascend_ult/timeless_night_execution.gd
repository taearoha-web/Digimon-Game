extends Node
## Assassin Ascension ultimate (★500) "ประหารเลือดพร่อง" (timeless_night_execution), an
## AscendUlt.
##
## The assassin melts into shadow (VANISH s), blinks to the far side of ONE foe (BLINK_AT)
## and executes it with a single slash (SLASH_AT), then the night closes (END).
##
## The foe: the caster's own target when it stands within reach (skill range + REACH_PAD),
## else the nearest enemy within that reach; with none the assassin only blinks in place
## (no hit).
##
## Damage: the skill's whole multiplier (god mult x ULT_POWER, the hero's rank power; an
## AI's x SKILL_POWER as Rival._resolve) times hp_scale(the foe's HP share just before the
## slash): x1 at full HP rising smoothly to x3 at LOW (30%) and below,
##     s = clamp((1 - hp) / (1 - LOW), 0, 1),  scale = 1 + 2 x s^2 (3 - 2 s)
## (x1.31 at 85%, x2 at 65%, x2.69 at 45%, x3 at 30% and under).
## The slash ignores 100% of the foe's DEF: the hero's goes through Hero._deal with the
## skill's "ignore_def" mark (no mitigation); an AI's raises its blow by exactly what the
## victim's own DEF would take off ((100 + DEF after pierce) / 100, HeroStats.mitigate), so
## it lands as if unarmoured too. Its effects (bleed, armour crack) follow the slash.
##
## Lifetime: a child of the caster's field; it stops at once (no slash after that, the
## caster shown again) when the caster is freed, falls, leaves the field or the duel ends.
const ID := "timeless_night_execution"
const VANISH := 0.08
const BLINK_AT := 0.24
const SLASH_AT := 0.42
const END := 0.95
const LOW := 0.3
const PEAK := 3.0
## Reach beyond the skill's range for the foe.
const REACH_PAD := 3.0
## How far beyond the foe's body the assassin reappears.
const BEHIND := 1.0
## The hero's cast stays locked through the blink and the slash.
const LEAD := 0.75
const CRIMSON := Color("ff3a7a")
const PALE := Color("ffe6f0")
const NIGHT := Color("1a0420")

## The last cast's numbers (tests).
static var last := {}

var caster: Node3D
var by_hero := false
var skill: Dictionary = {}
var total_mult := 0.0
var clock := 0.0
var target: Node3D
var slashed := false
var stopped := false

var _field: Node
var _hidden := false
var _blinked := false
var _strike: Dictionary = {}
var _from := Vector3.ZERO


## The execution's scale for a foe at [param hp] of its max HP (0..1).
static func hp_scale(hp: float) -> float:
	var s := clampf((1.0 - hp) / (1.0 - LOW), 0.0, 1.0)
	return 1.0 + (PEAK - 1.0) * s * s * (3.0 - 2.0 * s)


static func lead(_skill: Dictionary) -> float:
	return LEAD


func begin_hero(hero: Hero, data: Dictionary, _aim: Vector3, aimed: Mob) -> void:
	caster = hero
	by_hero = true
	skill = data
	_field = hero.field
	total_mult = float(data.get("mult", 0.0)) * hero.rank_mult(data)
	# The hit ignores the foe's DEF (Hero._deal_now reads "ignore_def").
	_strike = data.duplicate()
	_strike["ignore_def"] = true
	target = _pick(aimed)
	_begin()


func begin_rival(rival: Rival, data: Dictionary, _aim: Vector3, aimed: Node3D) -> void:
	caster = rival
	by_hero = false
	skill = data
	_field = rival.get_parent()
	total_mult = float(data.get("mult", 0.0)) * HeroStats.SKILL_POWER * SkillRank.power(rival.skill_rank(data))
	target = _pick(aimed)
	_begin()


func _begin() -> void:
	_from = caster.global_position
	last = {"found": target != null, "scale": 0.0, "mult": 0.0, "hp": 1.0, "slashed": false, "stopped": false}
	_room(func():
		VfxKit.impact_smoke(_field, _from + Vector3.UP * 0.9, NIGHT.lightened(0.15), 1.5)
		VfxKit.sparks(_field, _from + Vector3.UP * 1.0, CRIMSON, 12, 3.0, 0.5)
	)
	_sound(&"dash", -6.0)


func _process(delta: float) -> void:
	if stopped:
		return
	if not _caster_ok():
		_stop()
		return
	clock += delta
	if clock >= VANISH and not _hidden and not _blinked:
		_hide(true)
	if clock >= BLINK_AT and not _blinked:
		_blink()
	if clock >= SLASH_AT and not slashed:
		_slash()
	if clock >= END:
		stopped = true
		queue_free()


func _exit_tree() -> void:
	stopped = true
	_hide(false)


func _caster_ok() -> bool:
	if caster == null or not is_instance_valid(caster) or caster.is_queued_for_deletion():
		return false
	if not is_instance_valid(_field) or _field.is_queued_for_deletion():
		return false
	if caster.has_method("is_dead") and caster.is_dead():
		return false
	if by_hero:
		var hero := caster as Hero
		return hero.field == _field and not hero.safe_zone
	return not (caster as Rival).duel_over and caster.get_parent() == _field


func _stop() -> void:
	stopped = true
	last.stopped = true
	_hide(false)
	queue_free()


# ---------------------------------------------------------------------------
# The foe, the blink, the slash
# ---------------------------------------------------------------------------

func _reach() -> float:
	return float(skill.get("range", 13.0)) + REACH_PAD


func _alive(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
		return false
	if not by_hero:
		return (caster as Rival)._alive(node)
	if node is CastleGate and not (node as CastleGate).open_to(caster):
		return false
	return node.has_method("is_dead") and not node.is_dead()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


static func _body(node: Node3D) -> float:
	return (node as Mob).body_radius() if node is Mob else 0.5


## The aimed foe within reach, else the nearest one within reach, else none.
func _pick(aimed: Node3D) -> Node3D:
	var at := caster.global_position
	if _alive(aimed) and _flat(aimed.global_position - at).length() <= _reach() + _body(aimed):
		return aimed
	var best: Node3D = null
	var best_d := INF
	var pool: Array = []
	if by_hero:
		pool = get_tree().get_nodes_in_group("mobs")
	else:
		pool = (caster as Rival)._targets()
	for node in pool:
		var foe := node as Node3D
		if not _alive(foe):
			continue
		var d := _flat(foe.global_position - at).length() - _body(foe)
		if d <= _reach() and d < best_d:
			best_d = d
			best = foe
	return best


func _visual() -> Node3D:
	if by_hero:
		return (caster as Hero).visual
	var rival := caster as Rival
	return rival.visual if is_instance_valid(rival) else null


func _hide(on: bool) -> void:
	if on == _hidden:
		return
	_hidden = on
	if caster == null or not is_instance_valid(caster):
		return
	var v := _visual()
	if is_instance_valid(v):
		v.visible = not on


## Reappears on the far side of the foe (a wall between stops it short), facing it.
func _blink() -> void:
	_blinked = true
	if not _alive(target):
		_hide(false)
		return
	var foe_at := target.global_position
	var dir := _flat(foe_at - caster.global_position)
	if dir.length() < 0.2:
		dir = _flat(target.global_basis.z)
	dir = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
	var spot := Vector3(foe_at.x, caster.global_position.y, foe_at.z) + dir * (_body(target) + BEHIND)
	spot = _clear(foe_at, spot, dir)
	var was := caster.global_position
	caster.global_position = spot
	if caster is Hero:
		(caster as Hero)._clamp_to_field()
	var yaw := atan2(foe_at.x - spot.x, foe_at.z - spot.z)
	if by_hero:
		var hero := caster as Hero
		hero.set_facing(yaw)
		if is_instance_valid(hero.visual):
			hero.visual.rotation.y = yaw
			hero.visual.action("1H_Melee_Attack_Slice_Horizontal", 1.6)
	else:
		var rival := caster as Rival
		rival._yaw = yaw
		if is_instance_valid(rival.visual):
			rival.visual.rotation.y = yaw
		if rival._rv and rival._rv.hero_visual:
			rival._rv.hero_visual.action("1H_Melee_Attack_Slice_Horizontal", 1.6)
	_hide(false)
	_room(func():
		_streak(was + Vector3.UP * 1.0, spot + Vector3.UP * 1.0)
		VfxKit.impact_smoke(_field, spot + Vector3.UP * 0.9, NIGHT.lightened(0.15), 1.2)
		VfxKit.flash(_field, spot + Vector3.UP * 1.2, CRIMSON, 1.8, 0.16)
	)


## The spot behind the foe, or short of a wall in the way (never inside the foe).
func _clear(foe_at: Vector3, spot: Vector3, dir: Vector3) -> Vector3:
	var space := (caster as Node3D).get_world_3d()
	if space == null or not (caster is CollisionObject3D):
		return spot
	var body := caster as CollisionObject3D
	var from := foe_at + Vector3.UP * 0.8
	var to := spot + Vector3.UP * 0.8
	to.y = from.y
	var query := PhysicsRayQueryParameters3D.create(from, to, body.collision_mask)
	var skip: Array[RID] = [body.get_rid()]
	if target is CollisionObject3D:
		skip.append((target as CollisionObject3D).get_rid())
	# Other bodies (monsters, players) never stop the blink; only the world does.
	for node in get_tree().get_nodes_in_group("mobs"):
		if node is CollisionObject3D and not (node is CastleGate):
			skip.append((node as CollisionObject3D).get_rid())
	# Nor does any other unit in the way (a pet, a summon): only the world's own bodies.
	var hit := {}
	for i in 4:
		query.exclude = skip
		hit = space.direct_space_state.intersect_ray(query)
		if hit.is_empty() or not (hit.collider is CharacterBody3D) or hit.collider is CastleGate:
			break
		skip.append((hit.collider as CollisionObject3D).get_rid())
		hit = {}
	if hit.is_empty():
		return spot
	var stop: Vector3 = hit.position - dir * 0.45
	if _flat(stop - foe_at).length() < _body(target) + 0.3:
		# No room behind it: the near side, where the assassin came from.
		return Vector3(foe_at.x, spot.y, foe_at.z) - dir * (_body(target) + BEHIND)
	return Vector3(stop.x, spot.y, stop.z)


func _slash() -> void:
	slashed = true
	last.slashed = true
	if not _alive(target):
		return
	var hp := _hp_share(target)
	var scale := hp_scale(hp)
	var mult := total_mult * scale
	last.hp = hp
	last.scale = scale
	var at := _hit_point(target)
	var yaw := atan2(at.x - caster.global_position.x, at.z - caster.global_position.z)
	_room(func(): _slash_art(at, yaw, scale))
	_sound(SkillSound.landing(skill), -3.0)
	_sound(&"crit", -2.0)
	if by_hero:
		last.mult = mult
		var hero := caster as Hero
		VfxBudget.hero_begin()
		hero._deal(target as Mob, mult, CRIMSON, &"dark", false, _strike)
		VfxBudget.hero_end()
	else:
		var rival := caster as Rival
		var through := pierce_through(rival, target)
		last.mult = mult * through
		rival._hit(target, mult * through, CRIMSON, skill.get("fx", {}))
	if not _alive(target):
		BattleVfx.floating_text(_field, at + Vector3.UP * 1.3, "ประหาร!", CRIMSON, 1.0)


## What an AI's blow is raised by so the victim's own DEF takes nothing off (its
## take_damage mitigates by HeroStats.mitigate on ClassRoles.pierced DEF).
static func pierce_through(rival: Node, victim: Node) -> float:
	if victim == null or not is_instance_valid(victim) or victim.is_in_group("remote_players"):
		return 1.0
	var defence := 0.0
	if victim.has_method("effective_def"):
		defence = float(victim.call("effective_def"))
	elif victim.get("stats") is Dictionary:
		defence = float((victim.get("stats") as Dictionary).get("def", 0.0))
	return (100.0 + maxf(ClassRoles.pierced(rival, defence), 0.0)) / 100.0


static func _hp_share(node: Node3D) -> float:
	if node is Hero:
		var hero := node as Hero
		return clampf(float(Game.profile.get("hp", 0)) / maxf(float(hero.stats.get("max_hp", 1)), 1.0), 0.0, 1.0)
	var hp: Variant = node.get("hp")
	var max_hp: Variant = node.get("max_hp")
	if (hp is int or hp is float) and (max_hp is int or max_hp is float) and float(max_hp) > 0.0:
		return clampf(float(hp) / float(max_hp), 0.0, 1.0)
	return 1.0


static func _hit_point(node: Node3D) -> Vector3:
	if node.has_method("hit_point"):
		return node.call("hit_point")
	return node.global_position + Vector3.UP * 1.1


# ---------------------------------------------------------------------------
# Art
# ---------------------------------------------------------------------------

func _room(fn: Callable) -> void:
	if not is_instance_valid(_field) or not (_field is Node3D):
		return
	if by_hero:
		VfxBudget.hero_begin()
	fn.call()
	if by_hero:
		VfxBudget.hero_end()


func _sound(id: StringName, db: float) -> void:
	if id == &"" or not AudioManager.has_sound(id):
		return
	if by_hero:
		AudioManager.play_sfx(id, db)
	elif is_instance_valid(caster):
		AudioManager.play_sfx_at(caster.global_position, id, db - 4.0)


## The one slash: a giant crimson crescent through the foe, the execution line drawn
## across it and a spray of blood-red petals; heavier the lower its HP was.
func _slash_art(at: Vector3, yaw: float, scale: float) -> void:
	var heavy := (scale - 1.0) / (PEAK - 1.0)
	# One stroke, drawn twice: the crimson blade and its white-hot edge just inside it.
	VfxKit.slash_arc(_field, at, yaw + PI * 0.5, CRIMSON, 5.2 + 1.6 * heavy, -0.35)
	VfxKit.slash_arc(_field, at + Vector3.UP * 0.05, yaw + PI * 0.5, PALE, 3.8 + 1.2 * heavy, -0.35)
	VfxKit.flash(_field, at, PALE, 2.6 + 1.6 * heavy, 0.22)
	VfxKit.sparks(_field, at, CRIMSON, int(20 + 20 * heavy), 7.0, 0.65)
	if by_hero or VfxBudget.quality() > 0:
		_cut_line(at, yaw)
	var ground := Vector3(at.x, target.global_position.y + 0.08, at.z)
	VfxKit.impact_ring(_field, ground, CRIMSON, 2.2 + 1.4 * heavy, 0.45, PALE, NIGHT)


## A thin white-hot line across the foe (perpendicular to the blink), opening then fading.
func _cut_line(at: Vector3, yaw: float) -> void:
	if not VfxBudget.can_decorate():
		return
	var line := MeshInstance3D.new()
	line.name = "ExecutionLine"
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	line.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = PALE
	line.material_override = m
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_field.add_child(line)
	VfxBudget.track_decoration(line)
	line.global_position = at
	# Lying across the foe's chest, tilted a little like a downward stroke.
	line.global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, 0.28) * Basis(Vector3.RIGHT, -PI * 0.5)
	line.scale = Vector3(0.3, 0.1, 1)
	var tw := line.create_tween()
	tw.tween_property(line, "scale", Vector3(7.0, 0.16, 1), 0.08)
	tw.parallel().tween_property(m, "albedo_color", Color(CRIMSON.r, CRIMSON.g, CRIMSON.b, 0.0), 0.5).set_delay(0.1)
	tw.tween_callback(line.queue_free)


## The after-image of the blink: a dark streak from where it was to where it is.
func _streak(a: Vector3, b: Vector3) -> void:
	if not VfxBudget.can_decorate() or a.distance_to(b) < 0.3:
		return
	var s := MeshInstance3D.new()
	s.name = "BlinkStreak"
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	s.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(CRIMSON.r * 0.6, CRIMSON.g * 0.3, CRIMSON.b * 0.5, 0.7)
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_field.add_child(s)
	VfxBudget.track_decoration(s)
	var mid := (a + b) * 0.5
	var d := b - a
	s.global_position = mid
	var yaw := atan2(d.x, d.z)
	s.global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
	s.scale = Vector3(0.5, d.length(), 1)
	var tw := s.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.parallel().tween_property(s, "scale:x", 0.05, 0.3)
	tw.tween_callback(s.queue_free)
