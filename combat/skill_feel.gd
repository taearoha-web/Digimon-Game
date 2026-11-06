class_name SkillFeel
extends Node
## What makes the player's own skills feel heavy, beyond their art: weight-scaled
## hit-stop, camera moves (a wind-up zoom, the impact punch, a ground slam's kick and a
## shake along the hit), enemies thrown along the hit, element-tinted flashes and
## damage numbers, a combo total for multi-hit skills, ground marks that linger, and
## the ultimate cut-in (UltCutIn). The weight comes from the skill's data (SkillWeight).
##
## Only the local Hero calls it (companions, rivals, guild fighters, world players and
## summons never do), so AI casts never move the camera or the clock. Presentation only:
## damage, targets, cooldowns and hit counts are never touched; the throw rides the
## existing Mob.knock_back slide (walls stop it) and is shortened to stay inside the
## field, and the airborne arc lifts only the monster's visual.
##
## One node per hero (child "SkillFeel"): it holds the ground-mark pool and the combo
## count, sleeps when idle and goes with the hero when the zone unloads.

const NODE_NAME := "SkillFeel"
## Hits of one skill closer than this (real ms) are one beat: one punch, one shake.
const BEAT_MS := 250
## A multi-hit skill's total shows once its hits stop for this long (ms).
const COMBO_CLOSE_MS := 700
const COMBO_MIN_HITS := 3
## Ground marks: how long they lie (s), how many at most per quality, fade-out time.
const MARK_LIFE := 4.0
const MARK_FADE := 1.3
const MARK_CAP := [0, 6, 10]
## The throw: slide speed (m/s) for weight 0..1, the arc's height and air time.
const LAUNCH_SPEED := Vector2(3.5, 7.5)
const LAUNCH_HEIGHT := Vector2(0.45, 1.25)
const LAUNCH_AIR := Vector2(0.38, 0.6)
## The slide slows by 12 m/s each second (Mob._physics_process).
const SLIDE_DECEL := 12.0
const MARK_KINDS := {"fire": 0, "dark": 0, "thunder": 0, "earth": 1, "phys": 1, "nature": 1, "wind": 1, "ice": 2, "holy": 3, "arcane": 3}
const MARK_TINTS := {"fire": Color("ff7a2a"), "dark": Color("9a4cff"), "thunder": Color("bfe6ff"), "earth": Color("d8a870"),
	"phys": Color("e0c8a8"), "nature": Color("9ee070"), "wind": Color("d0fff0"), "ice": Color("8fdcff"), "holy": Color("ffd84a"), "arcane": Color("c58cff")}

static var _mark_shader: Shader
static var _mark_mesh: PlaneMesh
## Where an area hit comes from (the blast's centre), set around an area's hits.
static var _center := Vector3.ZERO
static var _center_on := false
## A star skill's beats before its last: monsters only hop (no slide), so a throw never
## carries them out of the waves still to come (StarSkillSequence: beat_done after).
static var _hold := false
## Test hooks / counters.
static var launches := 0
static var staggers := 0

var hero: Node3D
var _marks: Array[MeshInstance3D] = []
var _mark_age: Array[float] = []
var _beat_id := ""
var _beat_ms := -100000
## The last full beat (its skill and when): the same skill's next landings within
## ECHO_MS (an Armageddon's fragments, a storm's strikes) land lighter, no punch.
var _full_id := ""
var _full_ms := -100000
const ECHO_MS := 1200
var _combo_id := ""
var _combo_hits := 0
var _combo_total := 0
var _combo_ms := 0
var _combo_pos := Vector3.ZERO
var _last_pressure := 0
var _query: PhysicsRayQueryParameters3D


static func of(p_hero: Node) -> SkillFeel:
	if p_hero == null or not is_instance_valid(p_hero):
		return null
	var hub := p_hero.get_node_or_null(NODE_NAME) as SkillFeel
	if hub == null:
		hub = SkillFeel.new()
		hub.name = NODE_NAME
		hub.hero = p_hero as Node3D
		p_hero.add_child(hub)
	return hub


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)


# ---------------------------------------------------------------------------
# Entry points (Hero, StarSkillSequence)
# ---------------------------------------------------------------------------

## The hero starts a skill: the cut-in for its ultimates, the camera's wind-up zoom for
## heavy ones. Returns the ms the cut-in's slow motion adds to the cast lock.
static func cast_begun(p_hero: Node3D, skill: Dictionary, windup: float) -> int:
	if p_hero == null or skill.is_empty():
		return 0
	var t := SkillWeight.tier_of(skill)
	var debt := 0
	if SkillWeight.is_ultimate(skill) and UltCutIn.play(p_hero, skill):
		debt = UltCutIn.slow_debt_ms()
	var cam := _camera(p_hero)
	if cam and t >= SkillWeight.HEAVY and windup >= 0.3 and VfxBudget.quality() >= 1:
		cam.feel_windup(2.5 if t == SkillWeight.HEAVY else 4.5, windup)
	return debt


## Around an area's hits: they are thrown away from [param center], not from the hero.
static func area_from(center: Vector3) -> void:
	_center = center
	_center_on = true


static func area_done() -> void:
	_center_on = false


static func beat_done() -> void:
	_hold = false


## The landing of an area skill (a blast, a burst, a star beat): a ground mark and,
## for a star skill's beat, its punch, shake and hit-stop.
static func impact(p_hero: Node3D, skill: Dictionary, center: Vector3, radius: float, star_beat := -1, beats := 1) -> void:
	var hub := of(p_hero)
	if hub == null or skill.is_empty():
		return
	var t := SkillWeight.tier_of(skill)
	if star_beat >= 0:
		_hold = star_beat < beats - 1
		# The first beat and a god skill's finale land with everything; the waves between lighter.
		var finale := star_beat == beats - 1 and beats > 1 and StarSkillData.is_god(skill)
		var full := star_beat == 0 or finale
		var dir := center - p_hero.global_position
		hub._beat(skill, t if full else mini(t, SkillWeight.MEDIUM), dir, false, full, true)
		hub._beat_id = String(skill.get("id", ""))
		hub._beat_ms = Time.get_ticks_msec()
		if not full and star_beat % 2 == 1:
			return
	else:
		# An area landing is a beat even when it catches nobody (its hits then join it).
		var id := String(skill.get("id", ""))
		var now := Time.get_ticks_msec()
		if id != hub._beat_id or now - hub._beat_ms > BEAT_MS:
			hub._beat_id = id
			hub._beat_ms = now
			hub._beat(skill, t, center - p_hero.global_position, false, true)
	var shape := String(skill.get("shape", ""))
	if t >= SkillWeight.MEDIUM and (shape in ["burst", "blast"] or SkillWeight.is_slam(skill) or star_beat >= 0):
		hub.place_mark(center, clampf(radius * 0.55, 1.2, 4.5), SkillWeight.element(skill))


## One hit of the hero's skill on [param mob] (after its damage): hit-stop, camera,
## flash, the throw and the combo count.
static func hit(p_hero: Node3D, mob: Mob, skill: Dictionary, amount: int, crit: bool, killed: bool) -> void:
	var hub := of(p_hero)
	if hub == null or skill.is_empty() or not is_instance_valid(mob):
		return
	var w := SkillWeight.weight(skill)
	var t := SkillWeight.tier(w)
	var from := _center if _center_on else p_hero.global_position
	var dir := mob.global_position - from
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = mob.global_position - p_hero.global_position
		dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	var id := String(skill.get("id", ""))
	var now := Time.get_ticks_msec()
	# Star skills get their beats from StarSkillSequence (impact); others by time.
	if not skill.has("star") and (id != hub._beat_id or now - hub._beat_ms > BEAT_MS):
		hub._beat_id = id
		hub._beat_ms = now
		hub._beat(skill, t, dir, crit, true)
	var tint := ClassFlourish.tinted(skill)
	if tint.is_empty():
		flash(mob, SkillWeight.element(skill))
	elif is_instance_valid(mob.visual):
		# The venom stains its victim sickly green, briefly (not a pale lilac wash).
		mob.visual.flash(tint[0], 0.16)
	if not killed:
		react(p_hero, mob, dir, w)
	hub._count(id, amount, mob)


# ---------------------------------------------------------------------------
# Camera and clock
# ---------------------------------------------------------------------------

static func _camera(p_hero: Node) -> ThirdPersonCamera:
	var rig: Variant = p_hero.get("camera_rig") if p_hero else null
	return rig as ThirdPersonCamera if rig is ThirdPersonCamera and is_instance_valid(rig) else null


## Shake amplitude for a tier at the current quality (low quality: heavy hits only).
static func shake_for(t: int, crit := false) -> float:
	if VfxBudget.quality() == 0 and t < SkillWeight.HEAVY:
		return 0.0
	var amp := SkillWeight.shake_amp(t) * (1.25 if crit else 1.0)
	return minf(amp, ThirdPersonCamera.FEEL_MAX_OFFSET)


## Hit-stop seconds for a tier (a crit one frame more), never past the ultimate's.
static func stop_for(t: int, crit := false) -> float:
	return minf(SkillWeight.stop_seconds(t) + (1.0 / 60.0 if crit else 0.0), SkillWeight.stop_seconds(SkillWeight.ULTIMATE))


func _beat(skill: Dictionary, t: int, dir: Vector3, crit: bool, punch: bool, authored := false) -> void:
	var id := String(skill.get("id", ""))
	var now := Time.get_ticks_msec()
	if not authored:
		if id == _full_id and now - _full_ms < ECHO_MS:
			t = mini(t, SkillWeight.MEDIUM)
			punch = false
		else:
			_full_id = id
			_full_ms = now
	HitFeel.hitstop(get_tree(), stop_for(t, crit))
	var cam := _camera(hero)
	if cam == null:
		return
	var amp := shake_for(t, crit)
	var slam := SkillWeight.is_slam(skill)
	var down := 0.0
	if slam and t >= SkillWeight.MEDIUM:
		down = 0.06 if t < SkillWeight.ULTIMATE else 0.1
	if amp > 0.0 or down > 0.0:
		cam.feel_shake(dir, amp, [0.12, 0.18, 0.26, 0.38][t], down)
	if punch and t >= SkillWeight.HEAVY and VfxBudget.quality() >= 1:
		cam.feel_punch(2.5 if t == SkillWeight.HEAVY else 4.0)


# ---------------------------------------------------------------------------
# Enemy reactions
# ---------------------------------------------------------------------------

## Monsters that hold their ground: bosses, the world boss, rivals and guild fighters
## (and every other Mob kind: mirrors of another game's monsters, gates, summons).
static func resists(mob: Mob) -> bool:
	return mob.is_boss or mob.has_meta("world_boss") or mob.get_script() != preload("res://monsters/mob.gd")


## The element's flash on the monster: fire orange, ice blue held a moment (a freeze
## tint), lightning flickering twice, dark purple, holy gold. Plain hits keep the white.
static func flash(mob: Mob, element: String) -> void:
	if not is_instance_valid(mob) or not is_instance_valid(mob.visual) or not SkillWeight.FLASH.has(element):
		return
	var color := SkillWeight.flash_color(element)
	mob.visual.flash(color, 0.45 if element == "ice" else 0.22)
	if element == "thunder" and mob.is_inside_tree():
		# Lightning flickers: white, then the yellow again.
		var ref: WeakRef = weakref(mob)
		mob.get_tree().create_timer(0.08).timeout.connect(_flicker.bind(ref, Color(1, 1, 1), 0.06, color), CONNECT_ONE_SHOT)


static func _flicker(ref: WeakRef, color: Color, seconds: float, then: Color) -> void:
	var mob := ref.get_ref() as Mob
	if mob == null or mob.is_dead() or not is_instance_valid(mob.visual) or not mob.is_inside_tree():
		return
	mob.visual.flash(color, seconds)
	if then.a > 0.0:
		mob.get_tree().create_timer(seconds).timeout.connect(_flicker.bind(ref, then, 0.12, Color(0, 0, 0, 0)), CONNECT_ONE_SHOT)


## Heavy hits throw a normal monster along [param dir] (a slide with a short arc and a
## landing); resisting ones only stagger. Medium hits stagger.
static func react(p_hero: Node3D, mob: Mob, dir: Vector3, w: float) -> void:
	var t := SkillWeight.tier(w)
	if t < SkillWeight.MEDIUM or not is_instance_valid(mob.visual):
		return
	if t == SkillWeight.MEDIUM or resists(mob):
		stagger(mob, 0.1 if t == SkillWeight.MEDIUM else 0.16)
		return
	launch(p_hero, mob, dir, w, not _hold)


static func stagger(mob: Mob, lean: float) -> void:
	var visual := mob.visual
	if visual.has_meta(&"feel_arc"):
		return
	var old: Variant = visual.get_meta(&"feel_tilt", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	staggers += 1
	var tween := visual.create_tween()
	visual.set_meta(&"feel_tilt", tween)
	tween.tween_property(visual, "rotation:x", -lean, 0.05).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "rotation:x", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		if visual.has_meta(&"feel_tilt"):
			visual.remove_meta(&"feel_tilt"))


## The slide speed for a throw of weight [param w], shortened so the monster stays
## inside the hero's field (its round edge, or the castle hall it stands in).
static func launch_speed(p_hero: Node3D, mob: Mob, dir: Vector3, w: float) -> float:
	var speed := lerpf(LAUNCH_SPEED.x, LAUNCH_SPEED.y, clampf(w, 0.0, 1.0))
	var radius: Variant = p_hero.get("field_radius") if p_hero else null
	if radius == null:
		return speed
	var hall: Variant = p_hero.get("field_hall")
	var at := Vector2(mob.global_position.x, mob.global_position.z)
	var flat := Vector2(dir.x, dir.z).normalized()
	for i in 4:
		var slide := speed * speed / (2.0 * SLIDE_DECEL)
		var end := at + flat * slide
		var inside := end.length() <= float(radius) - 1.5 or (hall is Rect2 and (hall as Rect2).has_point(end))
		if inside:
			break
		speed *= 0.5
	return speed if speed >= 1.0 else 0.0


static func launch(p_hero: Node3D, mob: Mob, dir: Vector3, w: float, slide := true) -> void:
	var speed := launch_speed(p_hero, mob, dir, w) if slide else 0.0
	if not slide:
		w *= 0.6
	if speed > 0.0:
		# The existing slide: move_and_slide stops it at walls, the leash brings it home.
		mob.knock_back(mob.global_position - dir, speed)
	var visual := mob.visual
	var old: Variant = visual.get_meta(&"feel_arc", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tilt: Variant = visual.get_meta(&"feel_tilt", null)
	if tilt is Tween and (tilt as Tween).is_valid():
		(tilt as Tween).kill()
	launches += 1
	var k := clampf(w, 0.0, 1.0)
	var height := lerpf(LAUNCH_HEIGHT.x, LAUNCH_HEIGHT.y, k)
	var air := lerpf(LAUNCH_AIR.x, LAUNCH_AIR.y, k)
	var start := visual.position.y
	var tween := visual.create_tween()
	visual.set_meta(&"feel_arc", tween)
	tween.set_parallel(true)
	tween.tween_property(visual, "position:y", start + height, air * 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "rotation:x", -0.55 * k - 0.15, air * 0.42).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(visual, "position:y", 0.0, air * 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual, "rotation:x", 0.0, air * 0.58).set_ease(Tween.EASE_IN)
	var ref: WeakRef = weakref(mob)
	tween.chain().tween_callback(func():
		var m := ref.get_ref() as Mob
		if m == null or not is_instance_valid(m.visual):
			return
		if m.visual.has_meta(&"feel_arc"):
			m.visual.remove_meta(&"feel_arc")
		# The landing: a squash and a puff of dust.
		var squash := m.visual.create_tween()
		squash.tween_property(m.visual, "scale", Vector3(1.15, 0.82, 1.15), 0.05)
		squash.tween_property(m.visual, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var parent := m.get_parent() as Node3D
		if parent and VfxBudget.can_decorate(1) and VfxBudget.quality() >= 1:
			VfxKit.sparks(parent, m.global_position + Vector3(0, 0.15, 0), Color("d9c4a0"), 8, 2.6, 0.35))


# ---------------------------------------------------------------------------
# Combo total
# ---------------------------------------------------------------------------

func _count(id: String, amount: int, mob: Mob) -> void:
	var now := Time.get_ticks_msec()
	if id != _combo_id or now - _combo_ms > COMBO_CLOSE_MS * 1.3:
		close_combo()
		_combo_id = id
		_combo_hits = 0
		_combo_total = 0
	_combo_hits += 1
	_combo_total += amount
	_combo_ms = now
	_combo_pos = mob.top_point()
	set_process(true)


## Shows the total of the skill whose hits just stopped (3 hits or more). Returns the text.
func close_combo() -> String:
	var text := ""
	if _combo_hits >= COMBO_MIN_HITS and _combo_total > 0 and is_instance_valid(hero):
		var parent: Variant = hero.get("field")
		var where := parent as Node3D if parent is Node3D and is_instance_valid(parent) else hero.get_parent() as Node3D
		text = "รวม %d ฮิต %s" % [_combo_hits, group_digits(_combo_total)]
		if where:
			var label := BattleVfx.floating_text(where, _combo_pos + Vector3(0, 0.9, 0), text, Color("ffd84a"), 1.3, Color(0.2, 0.06, 0.0), 26)
			if label:
				label.render_priority = 4
	_combo_id = ""
	_combo_hits = 0
	_combo_total = 0
	return text


static func group_digits(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out


# ---------------------------------------------------------------------------
# Ground marks
# ---------------------------------------------------------------------------

## How many marks may lie at once now: none at low quality or under strict memory
## pressure, half under trimmed pressure.
static func mark_cap() -> int:
	var cap := int(MARK_CAP[VfxBudget.quality()])
	match MemoryGuard.pressure:
		1:
			cap /= 2
		2:
			cap = 0
	if MemoryGuard.hot:
		cap /= 2
	return cap


func marks_visible() -> int:
	var count := 0
	for mark in _marks:
		if mark.visible:
			count += 1
	return count


## Lays a mark of [param element] at [param center] (pooled; the oldest gives way).
func place_mark(center: Vector3, size: float, element: String) -> MeshInstance3D:
	var cap := mark_cap()
	if cap <= 0 or not VfxBudget.can_decorate(1) or not center.is_finite():
		return null
	# The same landing twice (an area's fragments): the fresh mark is enough.
	for i in _marks.size():
		if _marks[i].visible and _mark_age[i] < 0.3 and _marks[i].global_position.distance_to(center) < 1.0:
			return null
	var slot := -1
	for i in _marks.size():
		if not _marks[i].visible:
			slot = i
			break
	if slot < 0 and _marks.size() < cap:
		slot = _marks.size()
		_marks.append(_new_mark())
		_mark_age.append(0.0)
	if slot < 0:
		var oldest := 0.0
		for i in _marks.size():
			if _mark_age[i] >= oldest:
				oldest = _mark_age[i]
				slot = i
	var mark := _marks[slot]
	var mat := mark.material_override as ShaderMaterial
	mat.set_shader_parameter("kind", float(MARK_KINDS.get(element, 1)))
	mat.set_shader_parameter("tint", MARK_TINTS.get(element, Color("e0c8a8")))
	mat.set_shader_parameter("seed", randf() * 10.0)
	mat.set_shader_parameter("fade", 0.0)
	mark.visible = true
	mark.global_position = Vector3(center.x, _ground_y(center) + 0.04, center.z)
	mark.rotation = Vector3(0, randf() * TAU, 0)
	mark.scale = Vector3(size * 2.0, 1.0, size * 2.0)
	_mark_age[slot] = 0.0
	set_process(true)
	return mark


func _new_mark() -> MeshInstance3D:
	if _mark_shader == null:
		_mark_shader = load("res://shaders/ground_mark.gdshader")
		_mark_mesh = PlaneMesh.new()
		_mark_mesh.size = Vector2.ONE
	var mark := MeshInstance3D.new()
	mark.name = "GroundMark"
	mark.mesh = _mark_mesh
	var mat := ShaderMaterial.new()
	mat.shader = _mark_shader
	mark.material_override = mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.top_level = true
	mark.visible = false
	add_child(mark)
	return mark


func _ground_y(at: Vector3) -> float:
	var base := hero.global_position.y if is_instance_valid(hero) else at.y
	if not is_inside_tree() or not is_instance_valid(hero):
		return base
	var space := hero.get_world_3d().direct_space_state if hero.get_world_3d() else null
	if space == null:
		return base
	if _query == null:
		_query = PhysicsRayQueryParameters3D.new()
		_query.collision_mask = 1
	_query.from = Vector3(at.x, base + 4.0, at.z)
	_query.to = Vector3(at.x, base - 6.0, at.z)
	var hit := space.intersect_ray(_query)
	return float(hit.position.y) if hit.has("position") else base


## Every mark off now (memory pressure); the pool itself is freed under strict pressure.
func clear_marks(free_pool := false) -> void:
	for mark in _marks:
		mark.visible = false
	if free_pool:
		for mark in _marks:
			mark.queue_free()
		_marks.clear()
		_mark_age.clear()


func _process(delta: float) -> void:
	var busy := false
	if _combo_hits > 0:
		if Time.get_ticks_msec() - _combo_ms > COMBO_CLOSE_MS:
			close_combo()
		else:
			busy = true
	if not _marks.is_empty():
		var cap := mark_cap()
		if MemoryGuard.pressure != _last_pressure or cap <= 0:
			_last_pressure = MemoryGuard.pressure
			if cap <= 0:
				clear_marks(MemoryGuard.pressure >= 2)
		var shown := 0
		for i in _marks.size():
			var mark := _marks[i]
			if not mark.visible:
				continue
			shown += 1
			if shown > cap:
				mark.visible = false
				continue
			_mark_age[i] += delta
			var age := _mark_age[i]
			var fade := clampf(age / 0.08, 0.0, 1.0) * clampf((MARK_LIFE - age) / MARK_FADE, 0.0, 1.0)
			(mark.material_override as ShaderMaterial).set_shader_parameter("fade", fade)
			if age >= MARK_LIFE:
				mark.visible = false
			else:
				busy = true
	if not busy:
		set_process(false)
