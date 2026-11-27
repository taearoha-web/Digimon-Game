class_name HeavenFolkVisual
extends MonsterVisual
## ดินแดนเทวาลัย's code-sculpted folk (HeavenFolk: the lantern deva, the hermit sage): no
## rig, one shared mesh per kind posed by its shader. The clips Mob and MobAttack ask for
## are played by tweening the shader's scalars on this figure's own material (and its ink
## outline's, which draws the same pose):
##   idle / walk / run  breathing, a slow bob on the air, the cloud turning; on the move
##                      the body leans in and the stole, beard and lantern stream back
##   attack             the deva lifts her lantern high while three light orbs gather round
##                      her, then swings it at the foe and the orbs fly; the hermit raises
##                      his staff and blessing hand while the gold ยันต์ seal grows before
##                      him, then drives the staff forward and the seal is flung up to fall
##                      on the foe. A long move (MobAttack) winds up until just before its
##                      blows land; the basic attack is a quick throw.
##   hurt / die         a flinch / it sinks, tips back and burns away into gold light
## The hit flash lights the material (an overlay would draw the mesh unposed).

var kind := ""
var mat: ShaderMaterial
## The ink outline (quality 1-2; none at 0 or under strict memory pressure).
var line: ShaderMaterial
var body_mesh: MeshInstance3D
## Mesh metres to world metres.
var fit := 1.0
var _spec := {}
## The gait now and where it is going: (lean, stream, pace).
var _gait := Vector3.ZERO
var _gait_goal := Vector3.ZERO
var _move_tween: Tween
var _glow_tween: Tween
## Where the queued tween steps leave each scalar (the next step starts from there).
var _plan := {}
## The pose scalars now (the move's lean adds to the gait's).
var _vals := {}
const GAITS := {"idle": Vector3.ZERO, "walk": Vector3(0.1, 0.45, 0.5), "run": Vector3(0.2, 1.0, 1.0)}
## The scalars the clips tween, at rest.
const REST := {"lean": 0.0, "head_pitch": 0.0, "head_roll": 0.0, "arm_a": Vector3.ZERO, "arm_b": Vector3.ZERO, "swing": 0.0,
	"seal": 0.0, "seal_rise": 0.0, "charge": 0.0, "flinch": 0.0, "sink": 0.0, "dissolve": 0.0}
## The strike of each kind: the wind-up pose and the release.
const MOVES := {
	"deva": {
		"windup": {"arm_a": Vector3(0.55, 0.4, 0.45), "arm_b": Vector3(0.55, 0.75, 0.5), "lean": -0.12, "head_pitch": -0.25, "head_roll": 0.06, "seal": 1.0, "charge": 1.0, "swing": 0.15},
		"release": {"arm_a": Vector3(0.12, 0.05, -0.2), "arm_b": Vector3(0.2, 0.35, 0.25), "lean": 0.16, "head_pitch": 0.15, "head_roll": -0.04, "swing": -0.75, "seal_rise": 1.0, "charge": 0.7}},
	"hermit": {
		"windup": {"arm_a": Vector3(0.55, 0.1, 0.8), "arm_b": Vector3(1.35, 0.3, 0.55), "lean": -0.1, "head_pitch": -0.3, "seal": 1.0, "charge": 1.0},
		"release": {"arm_a": Vector3(-0.4, 0.0, 0.15), "arm_b": Vector3(0.65, 0.1, 0.25), "lean": 0.18, "head_pitch": 0.12, "seal_rise": 1.0, "charge": 0.6}},
}


## The visual for a template whose "folk" is one of HeavenFolk's kinds.
static func make(parent: Node, template: Dictionary) -> MonsterVisual:
	var v := HeavenFolkVisual.new()
	parent.add_child(v)
	v.build(String(template.get("folk", "deva")), float(template.height), float(template.get("hover", 0.0)))
	return v


func build(p_kind: String, target_height: float, hover := 0.0) -> void:
	kind = p_kind if HeavenFolk.has(p_kind) else "deva"
	if is_instance_valid(model):
		model.free()
	_spec = HeavenFolk.spec(kind)
	fit = target_height / float(_spec.height)
	model = Node3D.new()
	model.name = "HeavenFolk"
	add_child(model)
	body_mesh = HeavenFolk.body(kind)
	body_mesh.scale = Vector3.ONE * fit
	model.add_child(body_mesh)
	mat = body_mesh.material_override as ShaderMaterial
	line = null
	if VfxBudget.quality() > 0 and MemoryGuard.pressure < 2:
		line = HeavenFolk.line_material(kind, 0.011 / maxf(fit, 0.01))
		mat.next_pass = line
	if GameSettings.world_shadows():
		body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_ground_offset = 0.0
	_hover = hover
	model.position.y = hover
	_rest_scale = Vector3.ONE
	height = target_height + hover
	_vals = REST.duplicate()
	_gait = Vector3.ZERO
	_gait_goal = Vector3.ZERO
	_uniform("seed", float(absi(get_instance_id()) % 997) * 0.37)
	current = "idle"
	set_process(true)


## Where a part is at rest, in this node's space: "head", "mouth" (the lantern / the seal),
## "chest".
func point(part: String) -> Vector3:
	var at: Vector3 = _spec.get(part, _spec.get("chest", Vector3(0, 1, 0)))
	return at * fit + Vector3(0, _hover, 0)


func _process(delta: float) -> void:
	if mat == null or _gait == _gait_goal:
		return
	_gait = _gait.move_toward(_gait_goal, delta * 2.4)
	_uniform("lean", _gait.x + float(_vals.lean))
	_uniform("stream", _gait.y)
	_uniform("pace", _gait.z)


func _uniform(key: String, value: Variant) -> void:
	mat.set_shader_parameter(key, value)
	if line != null:
		line.set_shader_parameter(key, value)


func play(key: String, _speed := 1.0) -> void:
	if Time.get_ticks_msec() < busy_until or current == key:
		return
	current = key
	_gait_goal = GAITS.get(key, GAITS.idle)


func action(key: String, lock_ms := 450, _speed := 1.0) -> void:
	if mat == null:
		return
	if key == "die":
		hold(key)
		return
	busy_until = Time.get_ticks_msec() + lock_ms
	current = key
	_restart()
	if key == "hurt":
		_to({"flinch": 1.0, "head_pitch": -0.28, "swing": 0.35}, 0.07, Tween.TRANS_QUAD, Tween.EASE_OUT)
		_to({"flinch": 0.0, "head_pitch": 0.0, "swing": 0.0}, 0.26)
		return
	_gait_goal = GAITS.idle
	var secs := float(lock_ms) / 1000.0
	if secs < 0.8:
		# The basic attack: the shot has left already (Mob._strike), a quick throw.
		_strike(0.09, 0.08, 0.6)
	else:
		# A move (MobAttack): its blows land about 0.4 s before the lock ends; the charge
		# grows through most of that, the release flings it so it lands with them.
		var contact := maxf(secs - 0.4, 0.4)
		_strike(contact * 0.66, 0.12, 1.0)


## Wind up for [param wind] seconds, release in [param snap], then settle.
func _strike(wind: float, snap: float, depth: float) -> void:
	var m: Dictionary = MOVES[kind]
	_to(_scaled(m.windup, depth), wind, Tween.TRANS_SINE, Tween.EASE_OUT)
	_to(m.release, snap, Tween.TRANS_BACK, Tween.EASE_OUT)
	_move_tween.tween_interval(0.12)
	_to({"seal": 0.0}, 0.06)
	_to(_settle(), 0.36)


## The rest pose to settle back into (the charge already gone, no death).
func _settle() -> Dictionary:
	var back := REST.duplicate()
	for key in ["seal", "flinch", "sink", "dissolve"]:
		back.erase(key)
	return back


func _scaled(pose: Dictionary, depth: float) -> Dictionary:
	if depth >= 1.0:
		return pose
	var out := {}
	for key in pose:
		out[key] = pose[key] * depth
	return out


func _restart() -> void:
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	_plan.clear()


## The tween's next step: these scalars together over [param secs].
func _to(values: Dictionary, secs: float, trans := Tween.TRANS_SINE, ease := Tween.EASE_IN_OUT) -> void:
	var first := true
	for key in values:
		var from: Variant = _plan.get(key, _vals.get(key, REST.get(key, 0.0)))
		var to: Variant = values[key]
		_plan[key] = to
		var step := _move_tween.tween_method(_param.bind(key), from, to, maxf(secs, 0.01)) if first else _move_tween.parallel().tween_method(_param.bind(key), from, to, maxf(secs, 0.01))
		step.set_trans(trans).set_ease(ease)
		first = false


func _param(value: Variant, key: String) -> void:
	if mat == null:
		return
	_vals[key] = value
	if key == "lean":
		_uniform("lean", _gait.x + float(value))
	else:
		_uniform(key, value)


func hold(key: String) -> void:
	busy_until = Time.get_ticks_msec() + 3_600_000
	current = key
	if key == "die" and mat != null:
		_restart()
		_gait_goal = GAITS.idle
		_to({"flinch": 0.6, "seal": 0.0, "charge": 0.0, "head_pitch": -0.35, "arm_a": Vector3(0.4, 0.5, 0.2), "arm_b": Vector3(0.4, 0.5, 0.2)}, 0.12, Tween.TRANS_QUAD, Tween.EASE_OUT)
		_to({"flinch": 0.0, "sink": 1.0, "head_pitch": 0.3, "dissolve": 1.0, "swing": 0.4}, 1.05, Tween.TRANS_SINE, Tween.EASE_IN)
		if _glow_tween:
			_glow_tween.kill()
		mat.set_shader_parameter("glow_color", Color("fff0b0"))
		_glow_tween = create_tween()
		_glow_tween.tween_method(_glow, 0.5, 0.0, 0.9)


func _glow(value: float) -> void:
	if mat != null:
		mat.set_shader_parameter("glow", value)


func flash(color := Color(1, 1, 1), duration := 0.16) -> void:
	if mat == null or current == "die":
		return
	if _glow_tween:
		_glow_tween.kill()
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("glow", 0.55)
	_glow_tween = create_tween()
	_glow_tween.tween_method(_glow, 0.55, 0.0, maxf(duration, 0.05))


# ---------------------------------------------------------------------------
# Boss casts (BossCast), should a template ever make one of the folk cast: the strike's
# wind-up held for the telegraph, the release on cue.
# ---------------------------------------------------------------------------

func cast_body(_pose: String) -> Dictionary:
	return {"lean": 0.0, "lift": 0.0, "sx": 1.03, "sy": 1.05}


func _cast_clip_windup(secs: float, hold_secs: float, clip: String) -> void:
	if mat == null:
		return
	busy_until = Time.get_ticks_msec() + int((secs + hold_secs + 1.0) * 1000.0)
	_cast_clip = clip
	current = clip
	_gait_goal = GAITS.idle
	_restart()
	_to(MOVES[kind].windup, secs, Tween.TRANS_SINE, Tween.EASE_OUT)


func _cast_clip_release(secs: float) -> void:
	if mat == null or _cast_clip == "":
		_cast_clip = ""
		return
	busy_until = Time.get_ticks_msec() + int((secs + 0.4) * 1000.0)
	_restart()
	_to(MOVES[kind].release, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT)
	_move_tween.tween_interval(0.15)
	_to({"seal": 0.0}, 0.06)
	_to(_settle(), secs)
	_cast_clip = ""


func cast_cancel() -> void:
	var was := _cast_clip != ""
	super.cast_cancel()
	if was and mat != null and current != "die":
		_restart()
		var back := REST.duplicate()
		back.erase("sink")
		back.erase("dissolve")
		_to(back, 0.2)
		busy_until = 0


func cast_glow(color: Color, amount: float) -> void:
	if mat == null or current == "die" or (_glow_tween != null and _glow_tween.is_running()):
		return
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("glow", clampf(amount, 0.0, 1.0) * 0.4)


func cast_point(part: String) -> Vector3:
	return point("mouth" if part == "mouth" else "chest")
