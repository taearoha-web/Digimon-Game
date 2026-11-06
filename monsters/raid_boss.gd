class_name RaidBoss
extends Mob
## The raid boss of the party raid's last floor (RaidData, RaidRun): the Void Emperor's
## body in crimson. Its moves need the party's roles:
## - "ทุบทำลาย" (buster): a red ring follows whoever holds its threat (its current victim,
##   a taunt decides it) for TELEGRAPH seconds, then hits BUSTER_HIT of that one's max HP.
##   A tank (one who taunted it lately, or a Defender) takes TANK_TAKEN of it, and the
##   Defender's เบ่งเลือด (guard) cuts it further: the hit can't be dodged, only taken well.
## - "ฝนโลหิต" (rain): a circle on every member of the party; step out or take RAIN_HIT.
## - "ระเบิดโลหิต" (nova): a wide circle round the boss; melee step out or take NOVA_HIT.
## - Adds: at 75% HP, at the 50% phase and every ADD_EVERY seconds after it, ADDS
##   monsters; while any of them lives the boss is shielded (takes SHIELD_TAKEN damage).
## - Phase 2 at 50% HP: a roar, harder hits, a faster cycle (Mob.phase 1).
## - Enrage after ENRAGE_TIME seconds of fighting: hits ENRAGE_ATK times harder and acts
##   twice as fast (Mob.phase 2). The boss bar's name shows the time left.
## Companions read `active` to step out of the circles (Companion._raid_dodge) and a
## tank provokes it when it is on someone else (wants_taunt). The ground shapes are a
## few cheap meshes, tracked by VfxBudget, at most one set per move.

const CYCLE := 7.5
const TELEGRAPH := 2.0
const RAIN_RADIUS := 3.2
const NOVA_RADIUS := 7.5
const RAIN_HIT := 0.4
const NOVA_HIT := 0.55
const BUSTER_HIT := 0.7
const TANK_TAKEN := 0.5
const TAUNT_MEMORY := 8.0
const ADDS := 3
const ADD_EVERY := 30.0
const ADD_AT := 0.75
const SHIELD_TAKEN := 0.3
const PHASE_AT := 0.5
const PHASE_ATK := 1.25
const PHASE_HASTE := 0.7
const ENRAGE_TIME := 240.0
const ENRAGE_ATK := 3.0
const ENRAGE_HASTE := 0.5
const MOVES := ["buster", "rain", "nova"]
const TITLES := {"buster": "ทุบทำลาย", "rain": "ฝนโลหิต", "nova": "ระเบิดโลหิต"}
const COLOR := Color("ff2f4a")
const SHIELD_COLOR := Color("ff8a3a")

## The raid boss in play (null when none): companions dodge its circles.
static var active: RaidBoss

var zone_ref: Node3D
## Seconds of fighting so far (the enrage clock).
var elapsed := 0.0
var enraged := false
## Specials fired, adds called (tests).
var specials := 0
var add_waves := 0
## Ground warnings now: {kind, center, radius, left, victim (WeakRef, buster)}.
var telegraphs: Array[Dictionary] = []
var adds: Array[Mob] = []
## Who the adds are and how strong ({hp, atk, def, level}).
var add_ids: Array = []
var add_stats: Dictionary = {}
var _cycle := 4.0
var _haste := 1.0
var _next := 0
var _add_timer := ADD_EVERY
var _added_75 := false
var _taunter: WeakRef
var _taunt_at := -100.0
var _shapes: Array[Node3D] = []
var _shield: MeshInstance3D
var _aura: MeshInstance3D
var _name_timer := 0.0
var _rng := RandomNumberGenerator.new()


## The raid boss: `stats` already scaled (RaidData.monster_stats "boss").
func setup_raid(p_zone: Node3D, scaled: Dictionary, p_home: Vector3, p_hero: Node3D, ids: Array, p_add_stats: Dictionary, seed_value: int) -> void:
	setup(RaidData.BOSS_MODEL, int(scaled.level), p_home, p_hero)
	zone_ref = p_zone
	template = template.duplicate(true)
	template["name"] = RaidData.BOSS_NAME
	template["tint"] = RaidData.BOSS_TINT
	template["color"] = COLOR
	stats["hp"] = int(scaled.hp)
	stats["atk"] = int(scaled.atk)
	stats["def"] = int(scaled.def)
	hp = int(scaled.hp)
	max_hp = hp
	add_ids = ids
	add_stats = p_add_stats
	_rng.seed = seed_value
	_slam_timer = 999.0


func _ready() -> void:
	super._ready()
	active = self
	_label.visibility_range_end = 40.0
	# A crimson ring on the ground under it: the arena's centre of attention.
	_aura = MeshInstance3D.new()
	_aura.mesh = MeshKit.torus()
	_aura.material_override = _material(COLOR, 0.6)
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aura)
	_aura.position = Vector3(0, 0.05, 0)
	_aura.scale = Vector3(4.2, 0.2, 4.2)
	_refresh_name()


func _exit_tree() -> void:
	if active == self:
		active = null
	_clear_shapes()


## Never leashes home in its own arena (no reset to full HP).
func _leash() -> float:
	return 999.0


## Its moves come from tick(), not the generic slam.
func _begin_slam() -> void:
	_slam_timer = 999.0


## A taunt holds it twice as long as on other bosses, and is remembered: a tank takes the
## buster well.
func taunt(by: Node3D, seconds: float) -> void:
	if by != null and is_instance_valid(by):
		_taunter = weakref(by)
		_taunt_at = elapsed
	super.taunt(by, seconds * 2.0)


## While its adds live it is shielded.
func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
	if shielded():
		amount = maxi(1, int(round(float(amount) * SHIELD_TAKEN)))
	return super.take_hit(amount, crit, color, attacker)


func shielded() -> bool:
	for a in adds:
		if is_instance_valid(a) and not a.is_dead():
			return true
	return false


## Its own phases (the generic boss phases are not used).
func _check_phase() -> void:
	var ratio := float(hp) / float(maxi(1, max_hp))
	if not _added_75 and ratio <= ADD_AT:
		_added_75 = true
		summon_adds()
	if phase == 0 and ratio <= PHASE_AT:
		enter_phase_two()


func enter_phase_two() -> void:
	if phase >= 1 or _dead:
		return
	phase = 1
	_atk_scale *= PHASE_ATK
	_haste *= PHASE_HASTE
	_cycle = minf(_cycle, 1.5)
	_speed *= 1.15
	_add_timer = ADD_EVERY
	var parent := get_parent() as Node3D
	VfxKit.shockwave(parent, global_position + Vector3(0, 0.1, 0), COLOR, 9.0)
	BattleVfx.burst(parent, global_position + Vector3(0, 0.8, 0), COLOR, 40, 1.8)
	visual.flash(Color(1.0, 0.2, 0.2), 1.2)
	BattleVfx.floating_text(parent, top_point() + Vector3(0, 0.9, 0), "ตื่นเต็มพลัง!", Color("ff5a5a"), 1.6)
	Game.screen_flash.emit(Color(1.0, 0.15, 0.2), 0.35)
	_banner("ช่วงที่ 2! %s ตื่นเต็มพลัง — โจมตีแรงขึ้น ระวังวงเลือด" % RaidData.BOSS_NAME)
	summon_adds()
	phase_changed.emit(self, phase)


func enrage() -> void:
	if enraged or _dead:
		return
	enraged = true
	phase = 2
	_atk_scale *= ENRAGE_ATK
	_haste *= ENRAGE_HASTE
	_speed *= 1.3
	visual.flash(Color(1.0, 0.1, 0.1), 2.0)
	VfxKit.shockwave(get_parent(), global_position + Vector3(0, 0.1, 0), Color("ff0a2a"), 12.0)
	Game.screen_flash.emit(Color(1.0, 0.05, 0.1), 0.5)
	_banner("%s คลั่งสุดขีด! (หมดเวลา) โจมตีแรง x%d" % [RaidData.BOSS_NAME, int(ENRAGE_ATK)])
	_refresh_name()
	phase_changed.emit(self, phase)


func _process(delta: float) -> void:
	tick(delta)


## One step of the fight: the enrage clock, the adds' timer, the warnings on the ground
## and the move cycle. Only while it fights (hostile). Tests drive it with big deltas: one
## move starts per call at most.
func tick(delta: float) -> void:
	if _dead or not hostile:
		return
	elapsed += delta
	if not enraged and elapsed >= ENRAGE_TIME:
		enrage()
	_name_timer -= delta
	if _name_timer <= 0.0:
		_name_timer = 0.5
		_refresh_name()
		_update_shield()
	adds = adds.filter(func(a): return is_instance_valid(a) and not a.is_dead())
	if phase >= 1:
		_add_timer -= delta
		if _add_timer <= 0.0:
			summon_adds()
	_tick_telegraphs(delta)
	if not telegraphs.is_empty():
		_slam_timer = 999.0
		return
	if _stun > 0.0:
		return
	_cycle -= delta
	if _cycle <= 0.0:
		force_special(MOVES[_next])
		_next = (_next + 1) % MOVES.size()


## Starts a move's warning now (tests, and the cycle).
func force_special(kind: String) -> void:
	if _dead or not telegraphs.is_empty():
		return
	_cycle = CYCLE * _haste * _rng.randf_range(0.85, 1.15)
	var parent := get_parent() as Node3D
	match kind:
		"buster":
			var victim: Node3D = _victim if _alive(_victim) else _pick_victim()
			if victim == null:
				return
			var shape := _ground_ring(victim.global_position, 1.6, 0.9, 0.35)
			telegraphs.append({"kind": kind, "center": victim.global_position, "radius": 1.6, "left": TELEGRAPH, "victim": weakref(victim), "shape": shape})
			var who := "คุณ" if victim == hero else (String((victim as Companion).member.get("name", "เพื่อน")) if victim is Companion else "เพื่อน")
			Game.say("%s เล็ง \"ทุบทำลาย\" ใส่ %s! ให้ผู้พิทักษ์ยั่วยุ / เบ่งเลือดรับแทน" % [RaidData.BOSS_NAME, who], &"warning")
		"rain":
			var spots: Array[Vector3] = []
			var seen := {}
			for t in _targets():
				if seen.has(t):
					continue
				seen[t] = true
				spots.append(Vector3(t.global_position.x, 0.0, t.global_position.z))
			for i in (2 if phase >= 1 else 0):
				var a := _rng.randf() * TAU
				spots.append(global_position * Vector3(1, 0, 1) + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(4.0, 9.0))
			for spot in spots.slice(0, 7):
				telegraphs.append({"kind": kind, "center": spot, "radius": RAIN_RADIUS, "left": TELEGRAPH, "shape": _ground_ring(spot, RAIN_RADIUS, 0.25, 0.9)})
		"nova":
			var c := Vector3(global_position.x, 0.0, global_position.z)
			telegraphs.append({"kind": kind, "center": c, "radius": NOVA_RADIUS, "left": TELEGRAPH + 0.3, "shape": _ground_ring(c, NOVA_RADIUS, 0.25, 0.9)})
	if telegraphs.is_empty():
		return
	_winding = true
	visual.flash(Color(1.0, 0.3, 0.25), TELEGRAPH)
	visual.action("attack", int(TELEGRAPH * 1000.0))
	_anim_lock = Time.get_ticks_msec() + int(TELEGRAPH * 1000.0)
	BattleVfx.floating_text(parent, top_point() + Vector3(0, 0.9, 0), String(TITLES[kind]) + "!", Color("ffb3a0"), 1.4)


func _tick_telegraphs(delta: float) -> void:
	if telegraphs.is_empty():
		return
	var done := true
	for t in telegraphs:
		if t.kind == "buster":
			var v: Node3D = (t.victim as WeakRef).get_ref() as Node3D
			if v != null and is_instance_valid(t.shape):
				(t.shape as Node3D).global_position = Vector3(v.global_position.x, 0.06, v.global_position.z)
				t["center"] = v.global_position
		t["left"] = float(t.left) - delta
		if float(t.left) > 0.0:
			done = false
	if not done:
		return
	var fired := telegraphs.duplicate()
	telegraphs.clear()
	_clear_shapes()
	_winding = false
	specials += 1
	var hit := {}
	for t in fired:
		_land(t, hit)


func _land(t: Dictionary, hit: Dictionary) -> void:
	var parent := get_parent() as Node3D
	var center: Vector3 = t.center
	match String(t.kind):
		"buster":
			var v: Node3D = (t.victim as WeakRef).get_ref() as Node3D
			if v == null or not _alive(v):
				return
			VfxKit.pillar(parent, v.global_position, COLOR, 7.0, 1.4, 0.5)
			BattleVfx.burst(parent, v.global_position + Vector3(0, 0.6, 0), COLOR, 26, 1.4)
			var share := BUSTER_HIT * (TANK_TAKEN if is_tank(v) else 1.0)
			_hit(v, share)
			BattleVfx.floating_text(parent, v.global_position + Vector3(0, 3.2, 0), "รับไว้ได้!" if is_tank(v) else "ทุบทำลาย!", Color("ffd0a0") if is_tank(v) else Color("ff5a5a"), 1.1)
		"rain", "nova":
			VfxKit.shockwave(parent, center + Vector3(0, 0.1, 0), COLOR, float(t.radius))
			BattleVfx.burst(parent, center + Vector3(0, 0.4, 0), COLOR, 14 if t.kind == "rain" else 30, 1.2)
			for v in _targets():
				if hit.has(v) or not inside_circle(v.global_position, center, float(t.radius)):
					continue
				hit[v] = true
				_hit(v, RAIN_HIT if t.kind == "rain" else NOVA_HIT)


## A tank for the buster: it taunted the boss in the last TAUNT_MEMORY seconds, or it is
## a Defender (the hero's class or a companion's).
func is_tank(v: Node) -> bool:
	if _taunter != null and _taunter.get_ref() == v and elapsed - _taunt_at <= TAUNT_MEMORY:
		return true
	if v is Hero:
		return Game.class_id() == &"defender"
	if v is Companion:
		return StringName((v as Companion).member.get("class", "")) == &"defender"
	return false


## `fraction` of the victim's max HP after its own DEF (the raw hit is scaled back up
## through HeroStats.mitigate); guards (เบ่งเลือด) and shields still cut it.
func _hit(victim: Node3D, fraction: float) -> void:
	fraction *= _atk_scale
	var raw := float(stats.atk) * fraction * 4.0
	if victim is Hero:
		var h := victim as Hero
		raw = fraction * float(h.stats.max_hp) * (100.0 + maxf(h.effective_def(), 0.0)) / 100.0
	elif victim is Companion:
		var c := victim as Companion
		raw = fraction * float(c.max_hp) * (100.0 + maxf(float(c.stats.def) * (1.0 + c._book.total("def")), 0.0)) / 100.0
	Mob.strike(victim, raw, self)


static func inside_circle(point: Vector3, center: Vector3, radius: float) -> bool:
	return Vector2(point.x - center.x, point.z - center.z).length() <= radius


## Calls ADDS monsters round itself; it is shielded while they live.
func summon_adds() -> void:
	if _dead or add_ids.is_empty():
		return
	_add_timer = ADD_EVERY
	add_waves += 1
	var parent := get_parent() as Node3D
	for i in ADDS:
		var angle := TAU * float(i) / float(ADDS) + _rng.randf() * 0.5
		var spot := Vector3(global_position.x, 0.0, global_position.z) + Vector3(cos(angle), 0, sin(angle)) * 6.0
		var add := Mob.new()
		add.setup(StringName(add_ids[_rng.randi() % add_ids.size()]), int(add_stats.get("level", level)), spot, hero)
		RaidRun.apply_stats(add, add_stats)
		add.position = spot + Vector3(0, 0.3, 0)
		add.set_meta("raid_add", true)
		parent.add_child(add)
		add.provoke(false)
		adds.append(add)
		VfxKit.shockwave(parent, spot + Vector3(0, 0.1, 0), SHIELD_COLOR, 2.2)
	BattleVfx.floating_text(parent, top_point() + Vector3(0, 0.9, 0), "เรียกสมุน!", Color("ffd84a"), 1.4)
	Game.say("%s เรียกสมุนโลหิต! ฆ่าสมุนให้หมดเพื่อทำลายโล่ของบอส" % RaidData.BOSS_NAME, &"warning")
	_update_shield()


## Seconds left before the enrage.
func enrage_left() -> float:
	return maxf(0.0, ENRAGE_TIME - elapsed)


func _refresh_name() -> void:
	if enraged:
		template["name"] = "%s · คลั่ง!" % RaidData.BOSS_NAME
	else:
		var left := int(ceil(enrage_left()))
		template["name"] = "%s · คลั่งใน %d:%02d%s" % [RaidData.BOSS_NAME, left / 60, left % 60, " · โล่" if shielded() else ""]
	if is_instance_valid(_label):
		_label.text = "Lv.%d %s" % [level, RaidData.BOSS_NAME]


func _update_shield() -> void:
	var on := shielded()
	if on and not is_instance_valid(_shield):
		_shield = MeshInstance3D.new()
		_shield.mesh = MeshKit.sphere_low()
		_shield.material_override = _material(SHIELD_COLOR, 0.22)
		_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_shield)
		var r := float(template.get("height", 6.0)) * 0.55
		_shield.position = Vector3(0, r * 0.9, 0)
		_shield.scale = Vector3.ONE * r
	elif not on and is_instance_valid(_shield):
		_shield.queue_free()
		_shield = null


func _banner(text: String) -> void:
	if zone_ref != null and is_instance_valid(zone_ref) and zone_ref.has_signal("banner_requested"):
		zone_ref.banner_requested.emit(text)
	Game.say(text, &"warning")


## Escape step for someone at `point` standing in a circle warning: the flat direction
## out of it, or Vector3.INF when nothing threatens that spot.
static func danger_escape(point: Vector3) -> Vector3:
	if active == null or not is_instance_valid(active) or active.is_dead():
		return Vector3.INF
	for t in active.telegraphs:
		if String(t.kind) == "buster":
			continue
		var c: Vector3 = t.center
		var d := Vector3(point.x - c.x, 0.0, point.z - c.z)
		if d.length() <= float(t.radius) + 0.8:
			if d.length_squared() < 0.04:
				# Dead centre: away from the boss.
				d = Vector3(point.x - active.global_position.x, 0.0, point.z - active.global_position.z)
				if d.length_squared() < 0.01:
					d = Vector3.BACK
			return d.normalized()
	return Vector3.INF


## A companion with a provoke should use it on the raid boss while the boss is on
## someone else.
static func wants_taunt(by: Node, target: Node) -> bool:
	if active == null or not is_instance_valid(active) or active.is_dead() or target != active:
		return false
	return active._victim != by


# --- Ground shapes -------------------------------------------------------------------

## A red edge ring and a disc that fills over the warning.
func _ground_ring(center: Vector3, radius: float, fill_alpha: float, edge_alpha: float) -> MeshInstance3D:
	var parent := get_parent() as Node3D
	if parent == null:
		parent = self
	var holder := MeshInstance3D.new()
	holder.mesh = MeshKit.torus()
	holder.material_override = _material(COLOR, edge_alpha)
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(holder)
	holder.global_position = Vector3(center.x, 0.06, center.z)
	holder.scale = Vector3(radius, radius * 0.06, radius)
	VfxBudget.track_decoration(holder)
	var fill := MeshInstance3D.new()
	fill.mesh = MeshKit.cylinder()
	var fill_mat := _material(COLOR, fill_alpha * 0.3)
	fill.material_override = fill_mat
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(fill)
	fill.scale = Vector3(0.15, 0.3, 0.15)
	var tween := fill.create_tween().set_parallel(true)
	tween.tween_property(fill, "scale", Vector3(1.0, 0.3, 1.0), TELEGRAPH)
	tween.tween_property(fill_mat, "albedo_color:a", fill_alpha, TELEGRAPH)
	_shapes.append(holder)
	return holder


func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _clear_shapes() -> void:
	for s in _shapes:
		if is_instance_valid(s):
			s.queue_free()
	_shapes.clear()
