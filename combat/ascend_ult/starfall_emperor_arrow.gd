extends Node3D
## เลนส์ตะวัน (the archer's ★500 Ascension ultimate, AscendSkillData "starfall_emperor_arrow",
## played by AscendUlt from its release): the archer gathers the sun's light into a giant
## golden lens before it and fires it as one beam for DURATION seconds. The beam follows its
## mark (it swings round after a moving target; when the target falls it swings on to the
## enemy nearest its end) and burns everything along its line, from the archer to its end,
## once every TICK seconds: TICKS burns of 1/TICKS of the whole multiplier each, so a foe
## held in the beam the whole time takes exactly the skill's multiplier (x its rank's
## power). Each burn slows (SLOW s, so a foe in the beam stays slowed); the last one cracks
## armour (SHRED). The hero stands and channels (lead: the cast stays locked while the beam
## shines) and turns with it.
##
## The hero's burns go through Hero._deal (kill credit, combo count, duels' PvpProxy); an
## AI player's (Rival, begin_rival) through Rival._hit on its own targets, the slow on what
## can be slowed. The beam stops at once (no burn after) when its caster falls, leaves the
## field or the zone, enters a safe zone or ends its duel; the field freed frees it. Its
## light: the hero's always, an AI's only at medium quality and up and while fewer than
## MAX_AI_SHOWN others shine (it burns unseen otherwise), and lighter (no sky shaft, no sun).

const Kit := preload("res://combat/ascend_ult/_ult_kit.gd")
const ID := "starfall_emperor_arrow"
const DURATION := 3.0
const TICK := 0.2
const TICKS := 15
const FIRST_TICK := 0.1
## Half the width of the burnt line (plus each body's radius).
const WIDTH := 1.1
## The longest the beam reaches, and how far past its mark it runs.
const REACH := 18.0
const PAST := 2.0
## How fast the beam swings after its mark (1/s, exponential).
const TURN := 6.0
const SLOW := 1.0
const SHRED := [0.2, 6.0]
const FADE_OUT := 0.35
const MAX_AI_SHOWN := 2
## The lens: this far ahead of the archer, this high, this wide (radius).
const LENS_AHEAD := 1.7
const LENS_HEIGHT := 2.1
const LENS_RADIUS := 1.5
## Where the beam meets its mark (height over the ground).
const END_HEIGHT := 1.0
const SUN := Color("ffbf2e")
const WHITE_HOT := Color("fff7d6")
const EMBER := Color("ff5a14")
const GOLD := Color("ffd45a")

var caster: Node3D
var skill: Dictionary = {}
var by_hero := false
var shown := true
## The whole multiplier one target takes when held the whole time.
var total_mult := 0.0
var clock := 0.0
var ticks := 0
## Tests: what each foe (instance id) took, in shares of total_mult, and in burns.
var dealt := {}
var burns := {}
var gone := false

var _field: Node
var _zone: StringName
var _target: Node3D
var _yaw := 0.0
var _length := 10.0
var _ending := -1.0
var _held := false
var _lens: Node3D
var _spin: Node3D
var _parts: Array[GeometryInstance3D] = []
var _glass: MeshInstance3D
var _frame: MeshInstance3D
var _rays: MeshInstance3D
var _focus: MeshInstance3D
var _feed: MeshInstance3D
var _sun: MeshInstance3D
var _beam: MeshInstance3D
var _core: MeshInstance3D
var _strip: MeshInstance3D
var _end_glow: MeshInstance3D
var _end_ground: MeshInstance3D


## The hero's cast stays locked while it channels the beam.
static func lead(_skill: Dictionary) -> float:
	return DURATION + 0.1


func begin_hero(hero: Hero, data: Dictionary, aim: Vector3, target: Mob) -> void:
	_begin(hero, data, aim, target, true, Kit.hero_total(hero, data))


func begin_rival(rival: Rival, data: Dictionary, aim: Vector3, target: Node3D) -> void:
	_begin(rival, data, aim, target, false, Kit.rival_total(rival, data))


func _begin(who: Node3D, data: Dictionary, aim: Vector3, target: Node3D, hero_side: bool, mult: float) -> void:
	caster = who
	skill = data
	by_hero = hero_side
	total_mult = mult
	_field = get_parent()
	_zone = Game.current_zone
	shown = by_hero or (VfxBudget.quality() > 0 and get_tree().get_nodes_in_group("sun_lens_ai_shown").size() < MAX_AI_SHOWN)
	if shown and not by_hero:
		add_to_group("sun_lens_ai_shown")
	var from := Kit.flat(who.global_position)
	_target = target if Kit.valid(who, by_hero, target) else null
	var goal := Kit.flat(_target.global_position) if _target else Kit.flat(aim)
	if _target == null:
		_target = _nearest(goal)
		if _target:
			goal = Kit.flat(_target.global_position)
	if (goal - from).length() < 1.0:
		var facing := (who as Hero)._facing if who is Hero else float(who.get("_yaw"))
		goal = from + Vector3(sin(facing), 0, cos(facing)) * 12.0
	_yaw = atan2(goal.x - from.x, goal.z - from.z)
	_length = clampf((goal - from).length() + PAST, 3.0, REACH)
	if by_hero and is_instance_valid((who as Hero).visual):
		var visual := (who as Hero).visual
		for clip in ["2H_Ranged_Aiming", "2H_Ranged_Shooting", "2H_Ranged_Shoot"]:
			if visual.has_clip(clip):
				visual.hold_last_frame(clip)
				_held = true
				break
	if shown:
		Kit.with_room(by_hero, _build)
	Kit.sound(by_hero, who.global_position, SkillSound.star_beat(0), -3.0)
	if by_hero:
		BattleVfx.floating_text(_field, who.global_position + Vector3.UP * 3.2, String(data.get("name", "")), GOLD, 1.0)


func _process(delta: float) -> void:
	if gone:
		return
	clock += delta
	if _ending >= 0.0:
		_fade_out()
		return
	if not Kit.caster_ok(caster, _field, _zone):
		_end()
		return
	_steer(delta)
	while ticks < TICKS and clock >= FIRST_TICK + TICK * float(ticks):
		_burn(ticks)
		ticks += 1
	if shown:
		_draw()
	if clock >= DURATION:
		_end()


func _exit_tree() -> void:
	gone = true
	_release_pose()


## The beam's direction on the ground.
func direction() -> Vector3:
	return Vector3(sin(_yaw), 0.0, cos(_yaw))


## Where the beam ends (on the ground).
func end_point() -> Vector3:
	return Kit.flat(caster.global_position) + direction() * _length if is_instance_valid(caster) else Vector3.ZERO


## The foe the beam follows (null while it has none).
func mark() -> Node3D:
	return _target


# ---------------------------------------------------------------------------
# Aim and burns
# ---------------------------------------------------------------------------

func _steer(delta: float) -> void:
	var from := Kit.flat(caster.global_position)
	if not Kit.valid(caster, by_hero, _target) or Kit.flat(_target.global_position - from).length() > REACH + 2.0:
		_target = _nearest(from + direction() * _length)
	if _target:
		var want := Kit.flat(_target.global_position) - from
		if want.length() > 0.3:
			var k := 1.0 - exp(-TURN * delta)
			_yaw = lerp_angle(_yaw, atan2(want.x, want.z), k)
			_length = lerpf(_length, clampf(want.length() + PAST, 3.0, REACH), k)
	if by_hero:
		(caster as Hero)._face(direction(), delta, 30.0)


## The live foe nearest [param point] within the beam's reach of the caster.
func _nearest(point: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	var from := Kit.flat(caster.global_position)
	for foe: Node3D in Kit.foes(caster, by_hero):
		if Kit.flat(foe.global_position - from).length() > REACH:
			continue
		var d := Kit.flat(foe.global_position - point).length()
		if d < best_d:
			best_d = d
			best = foe
	return best


## On the beam's line: ahead of the archer, before its end, within WIDTH of it.
func on_line(foe: Node3D) -> bool:
	var from := Kit.flat(caster.global_position)
	var dir := direction()
	var off := Kit.flat(foe.global_position) - from
	var along := off.dot(dir)
	var r := Kit.body(foe)
	return along >= -r and along <= _length + r and (off - dir * along).length() <= WIDTH + r


func _burn(index: int) -> void:
	var share := 1.0 / float(TICKS)
	var fx := {"slow": SLOW}
	if index == TICKS - 1:
		fx["shred"] = SHRED
	var blow := Kit.strike(skill, fx)
	var shown_hits := 0
	for foe: Node3D in Kit.foes(caster, by_hero):
		if not on_line(foe):
			continue
		var key := foe.get_instance_id()
		dealt[key] = float(dealt.get(key, 0.0)) + share
		burns[key] = int(burns.get(key, 0)) + 1
		var at := Kit.hit_point(foe)
		Kit.deal(caster, by_hero, foe, total_mult * share, SUN, blow)
		if shown and shown_hits < 3 and is_instance_valid(_field):
			shown_hits += 1
			Kit.with_room(by_hero, func(): VfxKit.element_impact(_field, at, SUN, "fire", 0.55))
	if shown and is_instance_valid(_field):
		var tip := end_point() + Vector3.UP * END_HEIGHT
		Kit.with_room(by_hero, func(): VfxKit.sparks(_field, tip, SUN, 8, 3.2, 0.4))
	if index % 3 == 0:
		Kit.sound(by_hero, caster.global_position, SkillSound.star_beat(1), -9.0)


func _end() -> void:
	if _ending >= 0.0:
		return
	_ending = clock
	_target = null
	_release_pose()
	remove_from_group("sun_lens_ai_shown")
	if not shown or _parts.is_empty():
		gone = true
		queue_free()


func _fade_out() -> void:
	var f := 1.0 - (clock - _ending) / FADE_OUT
	for part in _parts:
		Kit.set_fade(part, f)
	if is_instance_valid(_lens):
		_lens.scale = Vector3.ONE * maxf(0.05, 0.6 + 0.4 * f)
	if f <= 0.0:
		gone = true
		queue_free()


func _release_pose() -> void:
	if not _held:
		return
	_held = false
	if is_instance_valid(caster) and caster is Hero and is_instance_valid((caster as Hero).visual):
		(caster as Hero).visual.release()


# ---------------------------------------------------------------------------
# Light: the lens, the sky's shaft into it, the beam, its burnt line and its end
# ---------------------------------------------------------------------------

## The lens as one Node3D (its local Y the beam's axis): glass, a gold frame, a sun crown of
## rays turning in its plane. Shared with the wind-up (telegraph).
static func make_lens(parent: Node, parts: Array) -> Node3D:
	var lens := Node3D.new()
	lens.name = "SunLens"
	parent.add_child(lens)
	var glass := Kit.light(lens, "lens", Kit.material(Kit.LENS, SUN, WHITE_HOT, EMBER), "Glass")
	if glass:
		glass.scale = Vector3(LENS_RADIUS * 2.0, 0.7, LENS_RADIUS * 2.0)
		parts.append(glass)
	var frame := Kit.light(lens, "ring", Kit.solid(Color("e0a21a")), "Frame")
	if frame:
		frame.scale = Vector3.ONE * LENS_RADIUS * 2.1
		parts.append(frame)
	var spin := Node3D.new()
	spin.name = "Spin"
	lens.add_child(spin)
	var rays := Kit.light(spin, "quad", Kit.material(Kit.GLOW, SUN, WHITE_HOT, EMBER, {"rays": 1.0, "strength": 0.7}), "Rays")
	if rays:
		rays.rotation.x = -PI / 2.0
		rays.scale = Vector3.ONE * LENS_RADIUS * 4.4
		parts.append(rays)
	return lens


## Points [param lens] (from make_lens) along [param dir] at [param at].
static func aim_lens(lens: Node3D, at: Vector3, dir: Vector3, size: float) -> void:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	lens.global_transform = Transform3D(Basis(x, y, z).scaled(Vector3.ONE * maxf(size, 0.01)), at)


func _lens_at() -> Vector3:
	return Kit.flat(caster.global_position) + direction() * LENS_AHEAD + Vector3.UP * LENS_HEIGHT


func _build() -> void:
	var parts: Array = []
	_lens = make_lens(self, parts)
	_spin = _lens.get_node("Spin") as Node3D
	for p in parts:
		_parts.append(p)
	var add := func(kind: String, mat: Material, label: String) -> MeshInstance3D:
		var node := Kit.light(self, kind, mat, label)
		if node:
			_parts.append(node)
		return node
	_beam = add.call("beam", Kit.material(Kit.BEAM, SUN, WHITE_HOT, EMBER, {"flow": 9.0, "span": 14.0, "strength": 1.3}), "Beam")
	_core = add.call("beam", Kit.material(Kit.BEAM, WHITE_HOT, Color.WHITE, SUN, {"flow": 14.0, "span": 20.0, "strength": 1.6}), "BeamCore")
	_strip = add.call("plane", Kit.material(Kit.STRIP, SUN, WHITE_HOT, EMBER, {"flow": 2.0, "span": 12.0}), "BurntLine")
	_focus = add.call("quad", Kit.material(Kit.GLOW, SUN, WHITE_HOT, EMBER, {"billboard": true, "strength": 1.2}), "Focus")
	_end_glow = add.call("quad", Kit.material(Kit.GLOW, SUN, WHITE_HOT, EMBER, {"billboard": true, "rays": 0.6, "strength": 1.3}), "BeamEnd")
	if by_hero:
		_feed = add.call("beam", Kit.material(Kit.BEAM, SUN, WHITE_HOT, EMBER, {"flow": -2.0, "span": 6.0, "strength": 0.32}), "SkyShaft")
		_sun = add.call("quad", Kit.material(Kit.GLOW, SUN, WHITE_HOT, EMBER, {"billboard": true, "rays": 1.0, "strength": 1.0}), "Sun")
		_end_ground = add.call("quad", Kit.material(Kit.GLOW, EMBER, SUN, EMBER, {"strength": 0.9}), "Scorch")
	_draw()


func _draw() -> void:
	if not is_instance_valid(caster):
		return
	var open := smoothstep(0.0, 0.22, clock)
	var pulse := 1.0 + 0.09 * sin(clock * 31.0) + 0.05 * sin(clock * 13.0)
	var dir := direction()
	var lens_at := _lens_at()
	var tip := end_point() + Vector3.UP * END_HEIGHT
	var beam_from := lens_at + dir * 0.15
	var beam_to := beam_from.lerp(tip, open)
	if is_instance_valid(_lens):
		aim_lens(_lens, lens_at, dir, 1.0)
	if is_instance_valid(_spin):
		_spin.rotation.y = clock * 0.9
	if _beam:
		Kit.span(_beam, beam_from, beam_to, 0.62 * pulse)
	if _core:
		Kit.span(_core, beam_from, beam_to, 0.24 * pulse)
	if _strip:
		Kit.strip(_strip, Kit.flat(caster.global_position), Kit.flat(beam_to), WIDTH * 2.0 * open)
	if _focus:
		_focus.global_position = lens_at
		_focus.scale = Vector3.ONE * 2.1 * pulse
	if _end_glow:
		_end_glow.global_position = tip
		_end_glow.scale = Vector3.ONE * 3.0 * pulse * open
	if _end_ground:
		_end_ground.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0).scaled(Vector3.ONE * 3.4 * open), Kit.flat(tip) + Vector3.UP * 0.08)
	var sky := Kit.flat(caster.global_position) - dir * 2.6 + Vector3.UP * 10.5
	if _feed:
		Kit.span(_feed, sky, lens_at, LENS_RADIUS * 0.85)
	if _sun:
		_sun.global_position = sky
		_sun.scale = Vector3.ONE * 4.2 * (1.0 + 0.04 * sin(clock * 3.0))


# ---------------------------------------------------------------------------
# The wind-up (combat/god_art/starfall_emperor_arrow.gd): the sun lights up behind the
# archer, its shaft comes down, the lens assembles ahead of it and the aim line is drawn.
# ---------------------------------------------------------------------------

static func telegraph(art: StarSkillArt, caster: Node3D, _skill: Dictionary, point: Vector3, time: float) -> bool:
	if not is_instance_valid(art) or not is_instance_valid(caster):
		return true
	var from := Kit.flat(caster.global_position)
	var to := Kit.flat(point)
	var dir := to - from
	dir = dir.normalized() if dir.length() > 0.5 else Vector3(sin(art.rotation.y), 0, cos(art.rotation.y))
	var lens_at := from + dir * LENS_AHEAD + Vector3.UP * LENS_HEIGHT
	var parts: Array = []
	var lens := make_lens(art, parts)
	aim_lens(lens, lens_at, dir, 0.05)
	var tw := lens.create_tween()
	tw.tween_method(func(s: float): aim_lens(lens, lens_at, dir, s), 0.05, 1.0, time * 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var spin := lens.get_node("Spin") as Node3D
	spin.create_tween().tween_property(spin, "rotation:y", TAU * 0.75, time)
	var sky := from - dir * 2.6 + Vector3.UP * 10.5
	var sun := Kit.light(art, "quad", Kit.material(Kit.GLOW, SUN, WHITE_HOT, EMBER, {"billboard": true, "rays": 1.0, "fade": 0.0}), "WindupSun")
	if sun:
		sun.global_position = sky
		sun.scale = Vector3.ONE * 4.2
		parts.append(sun)
	var shaft := Kit.light(art, "beam", Kit.material(Kit.BEAM, SUN, WHITE_HOT, EMBER, {"flow": -2.0, "span": 6.0, "strength": 0.5, "fade": 0.0}), "WindupShaft")
	if shaft:
		Kit.span(shaft, sky, lens_at, LENS_RADIUS * 0.85)
	var line := Kit.light(art, "plane", Kit.material(Kit.STRIP, SUN, WHITE_HOT, EMBER, {"span": 10.0, "fade": 0.0}), "WindupLine")
	if line:
		Kit.strip(line, from, from + dir * clampf((to - from).length() + PAST, 3.0, REACH), 0.5)
	for p in parts:
		if p != sun:
			Kit.set_fade(p, 0.0)
	var fade_in := func(node: GeometryInstance3D, start: float, length: float, top: float) -> void:
		if node == null:
			return
		var t := node.create_tween()
		t.tween_interval(start)
		t.tween_method(func(v: float): Kit.set_fade(node, v), 0.0, top, length)
	for p in parts:
		if p != sun:
			fade_in.call(p, 0.0, time * 0.6, 1.0)
	fade_in.call(sun, 0.0, time * 0.4, 1.0)
	fade_in.call(shaft, time * 0.35, time * 0.4, 1.0)
	fade_in.call(line, time * 0.5, time * 0.4, 0.6)
	return true
