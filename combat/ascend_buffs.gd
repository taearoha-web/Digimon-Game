class_name AscendBuffs
extends RefCounted
## The ★500 Ascension buffs that are mechanics, not stat sticks (AscendSkillData.BUFFS).
## Each is a key of the buff, read on whoever carries it: the hero, its companions, AI
## rivals and guild war fighters (the same rules for all of them):
##
##   "drain"       ราชันดาบ (sovereign_awakening): that share of max HP is lost every second
##                 while it runs; it never kills (stops at 1 HP).
##   "still_shot"  ลมหายใจนักล่า (zenith_hawkeye): standing still STILL_SECS readies a shot
##                 (a reticle over the archer, ReadyCue): the next hit is a sure crit with that
##                 much more crit damage. Its "speed" is the run speed (run_mult for the AI).
##   "armor_pen"   หอกทะลวงเกราะ (celestial_phalanx): that share of the target's DEF is
##                 ignored (ClassRoles.pierced). armor_pen also reads META_PEN, a share a
##                 skill may set on its caster for a moment (1.0 ignores all of it).
##   "echo"        ร่ายซ้ำ (arcane_singularity): the chance a skill casts again for free right
##                 after (no MP, no cooldown); an echo never echoes, never on a ★500 skill,
##                 a buff, a heal-only or a summon.
##   "hunt"        ล่าต่อเนื่อง (veil_of_eternity): a kill dashes the caster up to that many
##                 metres to the nearest enemy (walls and bodies stop it); its next hit on
##                 that enemy is a sure crit. HUNT_ICD seconds between dashes.
##
## State lives on the body as metadata (META), like MuayThai's combo. Buff times are the
## wall clock (BuffBook), so is everything here.

const STILL_SECS := 1.0
## Under this speed (m/s, flat) a body stands still.
const STILL_SPEED := 0.35
const HUNT_ICD := 0.3
## The hunt's sure crit waits this long for its hit.
const HUNT_MARK_SECS := 3.0
const DASH_TIME := 0.16
## How long an echo waits for its caster's cast lock to end before it gives up.
const ECHO_WAIT := 6.0
const ECHO_POLL := 0.08
const META := &"ascend_buff"
const META_PEN := &"armor_pen"
## Set on a caster for the length of an echo's cast call (its costs are skipped).
const META_ECHO := &"ascend_echo"
const CUE_COLOR := Color("3ae0b0")
const ECHO_COLOR := Color("d6a6ff")


## The buff list of [param unit] (the hero's, a companion's book, a rival's art).
static func buffs_of(unit: Variant) -> Array:
	if unit == null or not is_instance_valid(unit):
		return []
	if unit is Hero:
		return (unit as Hero)._buffs
	if unit is Companion:
		return (unit as Companion)._book.buffs
	if unit is Rival:
		return (unit as Rival)._buff_art.buffs
	return []


## The strongest running value of [param key] on [param unit] (0 without one).
static func value(unit: Variant, key: String) -> float:
	var list := buffs_of(unit)
	if list.is_empty():
		return 0.0
	var now := Time.get_ticks_msec()
	var best := 0.0
	for buff in list:
		if int(buff.get("until", 0)) > now:
			best = maxf(best, float(buff.get(key, 0.0)))
	return best


static func _running(unit: Variant, key: String) -> Dictionary:
	var now := Time.get_ticks_msec()
	for buff in buffs_of(unit):
		if int(buff.get("until", 0)) > now and buff.has(key):
			return buff
	return {}


static func _state(unit: Object) -> Dictionary:
	if not unit.has_meta(META):
		unit.set_meta(META, {"still": 0.0, "last": Vector3.INF, "primed": false, "drain": 0.0, "hunt_ready": 0, "mark": 0, "mark_until": 0})
	return unit.get_meta(META)


static func _alive(unit: Variant) -> bool:
	return unit != null and is_instance_valid(unit) and unit.has_method("is_dead") and not unit.is_dead()


static func _field(unit: Node3D) -> Node3D:
	if unit is Hero:
		return (unit as Hero).field
	return unit.get_parent() as Node3D


# --- every frame ---------------------------------------------------------------

## The frame of a buffed body: the warrior's drain, the archer's stillness.
static func tick(unit: Node3D, delta: float) -> void:
	var list := buffs_of(unit)
	if list.is_empty() and not unit.has_meta(META):
		return
	var now := Time.get_ticks_msec()
	var drain := 0.0
	var shot := false
	for buff in list:
		if int(buff.get("until", 0)) > now:
			drain = maxf(drain, float(buff.get("drain", 0.0)))
			shot = shot or buff.has("still_shot")
	if drain <= 0.0 and not shot and not unit.has_meta(META):
		return
	var st := _state(unit)
	if not _alive(unit):
		st.primed = false
		st.still = 0.0
		st.last = Vector3.INF
		return
	if drain > 0.0:
		_drain(unit, st, drain, delta)
	if shot:
		_watch_still(unit, st, delta)
	else:
		st.primed = false
		st.still = 0.0
		st.last = Vector3.INF


## ราชันดาบ: max HP x share each second off the body, never below 1 HP.
static func _drain(unit: Node3D, st: Dictionary, share: float, delta: float) -> void:
	var max_hp := _max_hp(unit)
	if max_hp <= 0:
		return
	st.drain = float(st.drain) + float(max_hp) * share * delta
	var take := int(st.drain)
	if take <= 0:
		return
	st.drain = float(st.drain) - float(take)
	var hp := hp_of(unit)
	if hp <= 1:
		return
	_set_hp(unit, maxi(1, hp - take))


static func _max_hp(unit: Node3D) -> int:
	if unit is Hero:
		return int((unit as Hero).stats.get("max_hp", 0))
	return int(unit.get("max_hp")) if "max_hp" in unit else 0


static func hp_of(unit: Node3D) -> int:
	if unit is Hero:
		return int(Game.profile.get("hp", 0))
	return int(unit.get("hp")) if "hp" in unit else 0


static func _set_hp(unit: Node3D, hp: int) -> void:
	if unit is Hero:
		Game.profile.hp = hp
	elif unit is Companion:
		(unit as Companion).hp = hp
		(unit as Companion)._update_bar()
	elif unit is Mob:
		var m := unit as Mob
		m.hp = hp
		if m._bar:
			m._bar.set_ratio(float(m.hp) / float(maxi(m.max_hp, 1)))


## ลมหายใจนักล่า: STILL_SECS without a step readies the shot (kept until it is fired).
static func _watch_still(unit: Node3D, st: Dictionary, delta: float) -> void:
	var at := unit.global_position
	var last: Vector3 = st.last
	st.last = at
	if not last.is_finite() or delta <= 0.0:
		return
	var moved := Vector2(at.x - last.x, at.z - last.z).length() / delta
	if moved > STILL_SPEED:
		st.still = 0.0
		return
	st.still = float(st.still) + delta
	if not bool(st.primed) and float(st.still) >= STILL_SECS:
		st.primed = true
		_ensure_cue(unit)
		var field := _field(unit)
		if is_instance_valid(field) and (unit is Hero or unit.visible):
			BattleVfx.floating_text(field, unit.global_position + Vector3(0, 2.9, 0), "พร้อมยิง!", CUE_COLOR, 0.7)


## Whether the archer's shot is readied now (the cue shows it).
static func primed(unit: Variant) -> bool:
	if not _alive(unit) or not (unit as Object).has_meta(META):
		return false
	return bool(((unit as Object).get_meta(META) as Dictionary).primed) and not _running(unit, "still_shot").is_empty()


static func _ensure_cue(unit: Node3D) -> void:
	for child in unit.get_children():
		if child is ReadyCue:
			return
	var cue := ReadyCue.new()
	cue.host = unit
	var root: Variant = unit.get("visual")
	cue.top = BuffAura.measure_top(root as Node, unit) if root is Node else 2.4
	unit.add_child(cue)


## Run speed share [param unit]'s ลมหายใจนักล่า adds to an AI's steps (the hero's comes
## through its stats' "speed"): 1.0 without it.
static func run_mult(unit: Variant) -> float:
	if not (unit is Rival or unit is Companion):
		return 1.0
	var buff := _running(unit, "still_shot")
	return 1.0 + float(buff.get("speed", 0.0)) if not buff.is_empty() else 1.0


# --- hits ------------------------------------------------------------------------

## A sure crit waiting for [param victim]: -1 when none; else the crit damage it adds
## (the readied shot's, 0 for the hunt's). Taking it spends it.
static func take_sure_crit(unit: Variant, victim: Variant) -> float:
	if unit == null or not is_instance_valid(unit) or not (unit as Object).has_meta(META):
		return -1.0
	var st: Dictionary = (unit as Object).get_meta(META)
	var out := -1.0
	if bool(st.primed):
		var buff := _running(unit, "still_shot")
		st.primed = false
		st.still = 0.0
		if not buff.is_empty():
			out = float(buff.still_shot)
	if int(st.mark) != 0:
		if Time.get_ticks_msec() >= int(st.mark_until):
			st.mark = 0
		elif victim != null and is_instance_valid(victim) and int(st.mark) == (victim as Object).get_instance_id():
			out = maxf(out, 0.0)
			st.mark = 0
	return out


## Share of the target's DEF [param attacker]'s hits ignore (หอกทะลวงเกราะ and META_PEN).
static func armor_pen(attacker: Variant) -> float:
	if attacker == null or not is_instance_valid(attacker):
		return 0.0
	var pen := value(attacker, "armor_pen")
	if (attacker as Object).has_meta(META_PEN):
		pen = maxf(pen, float((attacker as Object).get_meta(META_PEN)))
	return clampf(pen, 0.0, 1.0)


## ล่าต่อเนื่อง: [param unit] killed [param victim]: a dash to the nearest enemy in reach.
static func on_kill(unit: Node3D, victim: Variant) -> void:
	var metres := value(unit, "hunt")
	if metres <= 0.0 or not _alive(unit):
		return
	var st := _state(unit)
	var now := Time.get_ticks_msec()
	if now < int(st.hunt_ready):
		return
	var next := _nearest_foe(unit, victim, metres)
	if next == null:
		return
	st.hunt_ready = now + int(HUNT_ICD * 1000.0)
	st.mark = next.get_instance_id()
	st.mark_until = now + int(HUNT_MARK_SECS * 1000.0)
	if unit is Hero:
		(unit as Hero).set_target(next as Mob)
	elif unit is Companion:
		(unit as Companion).target = next as Mob
	elif unit is Mob:
		(unit as Mob)._victim = next
		(unit as Mob)._victim_timer = maxf((unit as Mob)._victim_timer, 0.8)
	var dash := HuntDash.new()
	dash.setup(unit, next)
	unit.add_child(dash)
	var field := _field(unit)
	if is_instance_valid(field) and (unit is Hero or unit.visible):
		BattleVfx.floating_text(field, unit.global_position + Vector3(0, 2.7, 0), "ล่าต่อ!", Color("d08aff"), 0.7)


static func _foes(unit: Node3D) -> Array:
	if unit is Rival:
		return (unit as Rival)._victims()
	var out: Array = []
	for node in unit.get_tree().get_nodes_in_group("mobs"):
		if node is Mob and not (node as Mob).is_dead() and not (node is CastleGate):
			out.append(node)
	return out


static func _nearest_foe(unit: Node3D, killed: Variant, metres: float) -> Node3D:
	var best: Node3D = null
	var best_d := metres
	for foe in _foes(unit):
		if foe == killed or not _alive(foe) or (foe as Node).is_queued_for_deletion():
			continue
		var d := Vector2(foe.global_position.x - unit.global_position.x, foe.global_position.z - unit.global_position.z).length()
		if d <= best_d:
			best_d = d
			best = foe
	return best


# --- casts ------------------------------------------------------------------------

## Whether [param skill] may echo: an attack, never a ★500 skill, a buff, a heal-only
## self cast, a summon or a recall.
static func echoes(skill: Dictionary) -> bool:
	if skill.is_empty() or AscendSkillData.is_ascend(skill):
		return false
	if String(skill.get("shape", "")) in ["self", "summon"]:
		return false
	var fx: Variant = skill.get("fx", {})
	return not (fx is Dictionary and ((fx as Dictionary).has("buff") or (fx as Dictionary).has("recall")))


## The echo's cast call is running on [param unit] (its MP, cooldown and checks are skipped).
static func echoing(unit: Object) -> bool:
	return unit.has_meta(META_ECHO)


## A paid cast of [param skill] by [param unit]: ร่ายซ้ำ's chance to cast it again for
## free once the cast lock is over. True when an echo was queued.
static func roll_echo(unit: Node3D, skill: Dictionary, target: Node = null) -> bool:
	if echoing(unit) or not echoes(skill):
		return false
	var chance := value(unit, "echo")
	if chance <= 0.0 or randf() >= chance:
		return false
	var unit_ref: WeakRef = weakref(unit)
	var target_ref: WeakRef = weakref(target) if target != null else null
	_echo_wait(unit_ref, skill, target_ref, ECHO_WAIT)
	return true


static func _echo_wait(unit_ref: WeakRef, skill: Dictionary, target_ref: WeakRef, left: float) -> void:
	var unit := unit_ref.get_ref() as Node3D
	if unit == null or not unit.is_inside_tree():
		return
	unit.get_tree().create_timer(ECHO_POLL, false).timeout.connect(func():
		var u := unit_ref.get_ref() as Node3D
		if u == null or not _alive(u) or not u.is_inside_tree():
			return
		if _busy(u):
			if left > ECHO_POLL:
				_echo_wait(unit_ref, skill, target_ref, left - ECHO_POLL)
			return
		_echo(u, skill, target_ref.get_ref() as Node3D if target_ref != null else null)
	, CONNECT_ONE_SHOT)


static func _busy(unit: Node3D) -> bool:
	if unit is Rival:
		var r := unit as Rival
		return r.duel_over or r._frozen or GameClock.msec() < r._cast_until
	return Time.get_ticks_msec() < int(unit.get("_cast_until"))


## The free cast. Targeted skills need an enemy: the cast's own, else the nearest.
static func _echo(unit: Node3D, skill: Dictionary, target: Node3D) -> void:
	var field := _field(unit)
	if unit is Hero:
		var h := unit as Hero
		if not h._valid_target(h.target):
			h.set_target(h.nearest_mob())
		if h.target == null:
			return
	elif unit is Companion:
		var c := unit as Companion
		if c.target == null or not is_instance_valid(c.target) or c.target.is_dead():
			c.target = c._pick_target()
		if c.target == null:
			return
	elif unit is Rival:
		if not _alive(target):
			target = (unit as Rival)._victim if _alive((unit as Rival)._victim) else null
		if target == null:
			return
	if is_instance_valid(field) and (unit is Hero or unit.visible):
		BattleVfx.floating_text(field, unit.global_position + Vector3(0, 3.1, 0), "ร่ายซ้ำ!", ECHO_COLOR, 0.8)
	unit.set_meta(META_ECHO, true)
	if unit is Hero:
		(unit as Hero)._cast(skill)
	elif unit is Companion:
		(unit as Companion)._cast(skill)
	elif unit is Rival:
		(unit as Rival)._cast(skill, target)
	if is_instance_valid(unit):
		unit.remove_meta(META_ECHO)


# --- nodes ------------------------------------------------------------------------

## ล่าต่อเนื่อง's dash: the body is carried to just in front of its prey over DASH_TIME by
## move_and_collide (walls, gates and rocks stop it, as walking would; never through a body).
class HuntDash extends Node:
	var body_ref: WeakRef
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var age := 0.0

	func setup(body: Node3D, prey: Node3D) -> void:
		body_ref = weakref(body)
		from = body.global_position
		var gap := Vector3(prey.global_position.x - from.x, 0.0, prey.global_position.z - from.z)
		var stop := 1.1 + (float(prey.call("body_radius")) if prey.has_method("body_radius") else 0.4)
		var reach := gap.length() - stop
		to = from + gap.normalized() * reach if reach > 0.3 else from

	func _physics_process(delta: float) -> void:
		var body := body_ref.get_ref() as CharacterBody3D if body_ref != null else null
		if body == null or to == from or (body.has_method("is_dead") and body.is_dead()):
			queue_free()
			return
		age += delta
		var t := clampf(age / AscendBuffs.DASH_TIME, 0.0, 1.0)
		var want := from.lerp(to, 1.0 - pow(1.0 - t, 3.0))
		var step := Vector3(want.x - body.global_position.x, 0.0, want.z - body.global_position.z)
		if step.length() > 0.001:
			var hit := body.move_and_collide(step)
			if hit != null:
				var n := hit.get_normal()
				# The ground or a slope underfoot: carry on along it; a wall ends the run.
				if n.y > 0.6:
					body.move_and_collide(hit.get_remainder().slide(n))
				else:
					t = 1.0
			if body is Hero:
				(body as Hero)._face(step.normalized(), 1.0, 60.0)
				(body as Hero)._clamp_to_field()
		if t >= 1.0:
			queue_free()


## ลมหายใจนักล่า's cue: a reticle over the archer's head and a ring at its feet while the
## shot is readied; it shows and hides itself by AscendBuffs.primed.
class ReadyCue extends Node3D:
	const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color;
uniform bool billboard = true;
void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = smoothstep(0.1, 0.0, abs(r - 0.78)) ;
	float inner = smoothstep(0.06, 0.0, abs(r - 0.46)) * 0.6;
	float ticks = 0.0;
	if (billboard) {
		ticks = step(abs(p.x), 0.055) * step(0.5, abs(p.y)) * step(abs(p.y), 0.98)
			+ step(abs(p.y), 0.055) * step(0.5, abs(p.x)) * step(abs(p.x), 0.98);
	}
	float dot_c = smoothstep(0.12, 0.05, r);
	float a = clamp(ring + inner + ticks + dot_c, 0.0, 1.0);
	float pulse = 0.75 + 0.25 * sin(TIME * 9.0);
	ALBEDO = mix(tint.rgb, vec3(1.0), dot_c * 0.6);
	ALPHA = a * pulse * tint.a;
}
"""
	static var _shader: Shader
	var host: Node3D
	var top := 2.4
	var _head: MeshInstance3D
	var _feet: MeshInstance3D
	var _age := 0.0

	func _ready() -> void:
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER
		_head = _quad(0.75, true)
		_head.position = Vector3(0, top + 0.6, 0)
		_feet = _quad(1.7, false)
		_feet.rotation.x = -PI / 2.0
		_feet.position = Vector3(0, 0.06, 0)
		visible = false

	func _quad(size: float, board: bool) -> MeshInstance3D:
		var mesh := QuadMesh.new()
		mesh.size = Vector2(size, size)
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter("tint", AscendBuffs.CUE_COLOR)
		mat.set_shader_parameter("billboard", board)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		return mi

	func _process(delta: float) -> void:
		var on := AscendBuffs.primed(host)
		if on != visible:
			visible = on
			_age = 0.0
		if not on:
			if AscendBuffs._running(host, "still_shot").is_empty():
				queue_free()
			return
		_age += delta
		var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - _age * 5.0)
		_head.scale = Vector3.ONE * pop
		_feet.rotation.y += delta * 1.4
