class_name HeavenBirdVisual
extends MonsterVisual
## The กินรี and the ครุฑน้อยเทวาลัย drawn by HeavenBird: no rig, one shared mesh posed by
## its shader. The clips Mob and MobAttack ask for are played by the shader's scalars on
## this bird's own material (and its ink outline's):
##   kinnari  idle / walk / run  she floats and bobs, wings beating slowly, arms in a slow
##                               ตั้งวง and จีบ; on the move she leans into her flight, wings
##                               beating harder, sashes and plumes streaming
##            attack             the ribbon dance: she turns away, her right hand raised
##                               behind her and the nails kindling, then sweeps it at the
##                               target and a ribbon of light unfurls along the beam's line
##                               (the first blow of "beam", or her basic bolt), and settles
##   garuda   idle / walk / run  he stands guard, wings half spread, breathing; a strutting
##                               bird walk; a wing-beating run
##            attack             the swoop: he crouches, wings flung up and arms back, then
##                               springs through the dash of "pounce" pitched forward, talons
##                               thrust out and wings driving down, grips on landing and rises
##   both     hurt / die         a flinch / folded wings, falling (she sinks to the ground),
##                               dissolving into gold
## The hit flash lights the material (an overlay would draw the mesh unposed). Far from the
## camera (Zone's animation radius) the pose stops being driven, as the rigs' players stop.

var kind := ""
var mat: ShaderMaterial
var ink: ShaderMaterial
var body_mesh: MeshInstance3D
## Mesh metres to world metres.
var fit := 1.0
var _flap := 0.0
var _gait_clock := 0.0
## The gait now and where it is going: [flap cycles a second, flap height, gait cycles a
## second, stride, stream, lean].
var _gait := PackedFloat32Array([0.5, 0.16, 0.0, 0.0, 0.0, 0.0])
var _gait_goal := PackedFloat32Array([0.5, 0.16, 0.0, 0.0, 0.0, 0.0])
var _move_tween: Tween
var _glow_tween: Tween
var _plan := {}
var _bob := 0.0
## How far the floating dancer has sunk toward the ground (death), 0..1.
var _sink := 0.0
var _far := false
var _far_timer := 0.0
const GAIT_KEYS := ["flap", "flap_amp", "gait", "stride", "stream", "lean"]
const GAITS := {
	"kinnari": {"idle": [0.55, 0.16, 0.0, 0.0, 0.0, 0.0], "walk": [0.85, 0.3, 0.0, 0.0, 0.45, 0.12], "run": [1.35, 0.42, 0.0, 0.0, 1.0, 0.24]},
	"garuda": {"idle": [0.45, 0.08, 0.0, 0.0, 0.0, 0.0], "walk": [0.6, 0.1, 1.3, 0.42, 0.25, 0.08], "run": [1.6, 0.4, 2.0, 0.7, 0.8, 0.2]},
}
## The animation radius of Zone (by quality): beyond it the pose freezes.
const ANIM_RADIUS := [24.0, 34.0, 48.0]


func build(p_kind: String, target_height: float, hover := 0.0) -> void:
	kind = p_kind if HeavenBird.has(p_kind) else "kinnari"
	if is_instance_valid(model):
		model.free()
	var spec := HeavenBird.spec(kind)
	fit = target_height / float(spec.height)
	model = Node3D.new()
	model.name = "HeavenBird"
	add_child(model)
	body_mesh = HeavenBird.body(kind)
	body_mesh.scale = Vector3.ONE * fit
	model.add_child(body_mesh)
	mat = body_mesh.material_override as ShaderMaterial
	ink = mat.next_pass as ShaderMaterial
	if GameSettings.world_shadows():
		body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_ground_offset = 0.0
	_hover = hover
	_rest_scale = Vector3.ONE
	height = target_height + hover
	model.position.y = hover
	var phase := float(absi(get_instance_id()) % 997) * 0.37
	_shade("seed", phase)
	_flap = phase * 0.5
	_bob = phase
	_gait = PackedFloat32Array(GAITS[kind].idle)
	_gait_goal = _gait.duplicate()
	_apply_gait(true)
	current = "idle"
	set_process(true)


## Sets a shader scalar on the body and its ink outline.
func _shade(key: String, value: Variant) -> void:
	mat.set_shader_parameter(key, value)
	if ink != null:
		ink.set_shader_parameter(key, value)


func param(key: String) -> float:
	var v: Variant = mat.get_shader_parameter(key) if mat != null else null
	return float(v) if v != null else HeavenBird.rest_value(kind, key)


## Where a part of the bird is at rest, in this node's space: "head", "hand" (the right,
## where the ribbon springs from), "chest", "feet".
func point(part: String) -> Vector3:
	var spec := HeavenBird.spec(kind)
	var lift := Vector3(0, _hover, 0)
	match part:
		"head": return lift + (spec.head as Vector3) * fit
		"hand":
			var h: Vector3 = spec.joints.j_hand
			return lift + Vector3(-h.x, h.y, h.z) * fit
		"feet": return lift
	return lift + (spec.joints.j_center as Vector3) * fit


func _process(delta: float) -> void:
	if model == null or mat == null:
		return
	_far_timer -= delta
	if _far_timer <= 0.0:
		_far_timer = 0.5
		var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
		var limit: float = ANIM_RADIUS[clampi(GameSettings.quality, 0, 2)]
		_far = camera != null and camera.global_position.distance_squared_to(global_position) > limit * limit and current != "die"
	if _far:
		return
	var moving := false
	for i in _gait.size():
		if not is_equal_approx(_gait[i], _gait_goal[i]):
			_gait[i] = move_toward(_gait[i], _gait_goal[i], delta * (3.0 if i < 3 else 1.6))
			moving = true
	_flap += delta * _gait[0]
	_gait_clock += delta * _gait[2]
	_shade("clock", _flap)
	if _gait[3] > 0.001 or moving:
		_shade("gait", _gait_clock)
	if moving:
		_apply_gait(false)
	if _hover > 0.0:
		_bob += delta * 1.7
		model.position.y = _hover * (1.0 - _sink) + sin(_bob) * minf(height * 0.025, 0.09) * (1.0 - _sink)


func _apply_gait(all: bool) -> void:
	_shade("flap_amp", _gait[1])
	_shade("stride", _gait[3])
	_shade("stream", _gait[4])
	_shade("lean", _gait[5])
	if all:
		_shade("clock", _flap)
		_shade("gait", _gait_clock)


func play(key: String, _speed := 1.0) -> void:
	if Time.get_ticks_msec() < busy_until or current == key:
		return
	current = key
	_gait_goal = PackedFloat32Array(GAITS[kind].get(key, GAITS[kind].idle))


func action(key: String, lock_ms := 450, _speed := 1.0) -> void:
	if mat == null:
		return
	busy_until = Time.get_ticks_msec() + lock_ms
	current = key
	_restart()
	match key:
		"hurt":
			_to({"bow": -0.22, "head_pitch": -0.3, "wing_raise": rest("wing_raise") + 0.3, "lunge": -0.08, "la_raise": rest("la_raise") + 0.25, "ra_raise": rest("ra_raise") + 0.25}, 0.08)
			_to(_rest_of(["bow", "head_pitch", "wing_raise", "lunge", "la_raise", "ra_raise"]), 0.24)
		"die":
			hold(key)
		_:
			_gait_goal = PackedFloat32Array(GAITS[kind].idle)
			if kind == "garuda":
				_swoop(lock_ms)
			else:
				_ribbon_dance(lock_ms)


func rest(key: String) -> float:
	return HeavenBird.rest_value(kind, key)


func _rest_of(keys: Array) -> Dictionary:
	var out := {}
	for key in keys:
		out[key] = rest(key)
	return out


## The kinnari's attack. A telegraphed move ("beam": its lock is the last blow + 0.4 s,
## the first blow 0.24 s before the last) sweeps the ribbon out as the first blow lands;
## the basic bolt (450 ms, the bolt already flying) is a quick flick of it.
func _ribbon_dance(lock_ms: int) -> void:
	var span := float(lock_ms) / 1000.0
	var keys := ["twist", "bow", "head_pitch", "head_turn", "ra_swing", "ra_raise", "ra_bend", "ra_twist", "la_swing", "la_raise", "la_bend", "la_twist", "wing_raise", "ribbon", "charge", "dance"]
	if span < 0.8:
		_to({"ra_swing": 1.45, "ra_raise": 0.2, "ra_bend": 0.15, "ra_twist": 0.0, "twist": -0.2, "ribbon": 0.45, "charge": 1.0, "dance": 0.0}, 0.12)
		_move_tween.tween_interval(0.08)
		_to(_rest_of(keys), 0.24)
		return
	var first := clampf(span - 0.64, 0.3, 1.6)
	var reach := 0.15
	# She turns away, the right hand lifted behind her, the left in จีบ before her, the
	# wings flared, the nails kindling.
	_to({"twist": 0.42, "bow": -0.08, "head_turn": -0.25, "head_pitch": -0.08, "ra_swing": -0.5, "ra_raise": 2.1, "ra_bend": 0.7, "ra_twist": 0.6,
		"la_swing": 1.1, "la_raise": 0.35, "la_bend": 1.2, "la_twist": -0.3, "wing_raise": 0.42, "ribbon": 0.06, "charge": 0.7, "dance": 0.0}, maxf(first - reach, 0.15))
	# The sweep: the hand flung at the target, the ribbon of light unfurling.
	_to({"twist": -0.08, "bow": 0.0, "head_turn": 0.0, "head_pitch": 0.1, "ra_swing": 1.66, "ra_raise": 0.06, "ra_bend": 0.0, "ra_twist": 0.0,
		"la_swing": 0.2, "la_raise": 1.1, "la_bend": 0.9, "la_twist": 0.6, "wing_raise": 0.0, "ribbon": 1.0, "charge": 1.0}, reach)
	_move_tween.tween_interval(maxf(span - 0.4 - first + 0.1, 0.1))
	_to(_rest_of(keys), 0.36)


## The garuda's attack. "pounce" (its lock is the blow + 0.4 s; the dash fills the last
## 0.3 s before it): crouched and wound up, then the leap through the dash, landing on the
## blow; the basic strike (450 ms) is a short talon kick and claw rake.
func _swoop(lock_ms: int) -> void:
	var span := float(lock_ms) / 1000.0
	var keys := ["crouch", "bow", "head_pitch", "dive", "lift", "lunge", "leg_swing", "leg_bend", "talon", "wing_raise", "wing_sweep", "la_swing", "la_raise", "la_bend", "la_twist", "ra_swing", "ra_raise", "ra_bend", "ra_twist", "tail_lift", "charge"]
	if span < 0.8:
		_to({"wing_raise": 0.35, "bow": -0.12, "la_swing": -0.3, "ra_swing": -0.3, "crouch": 0.25}, 0.12)
		_to({"wing_raise": -0.2, "dive": 0.3, "lunge": 0.25, "la_swing": 1.4, "ra_swing": 1.4, "la_bend": 0.4, "ra_bend": 0.4, "la_raise": 0.2, "ra_raise": 0.2, "talon": 0.8, "crouch": 0.05, "charge": 1.0}, 0.1)
		_to(_rest_of(keys), 0.23)
		return
	var blow := clampf(span - 0.4, 0.4, 1.6)
	var leap := 0.32
	# Wound up: crouched low, wings flung up, arms drawn back, eyes on the prey.
	_to({"crouch": 0.55, "bow": 0.25, "head_pitch": -0.3, "wing_raise": 0.75, "wing_sweep": -0.15, "la_swing": -0.7, "ra_swing": -0.7, "la_raise": 0.6, "ra_raise": 0.6,
		"la_bend": 1.0, "ra_bend": 1.0, "la_twist": 0.0, "ra_twist": 0.0, "talon": 0.3, "tail_lift": 0.3, "charge": 0.6}, maxf(blow - leap, 0.15))
	# The spring: up and forward, pitched into the dive, talons thrust out, wings driving down.
	_to({"crouch": 0.0, "lift": 0.75, "dive": 0.5, "bow": 0.1, "head_pitch": 0.0, "leg_swing": 1.2, "leg_bend": 0.2, "talon": 1.0, "wing_raise": 0.1,
		"la_swing": 1.2, "ra_swing": 1.2, "la_bend": 0.5, "ra_bend": 0.5, "charge": 1.0}, leap * 0.5)
	_to({"lift": 0.0, "dive": 0.3, "leg_swing": 0.6, "wing_raise": -0.45, "talon": 1.0}, leap * 0.5)
	# The blow: talons close, the landing bends the knees.
	_to({"talon": -0.3, "crouch": 0.35, "dive": 0.12, "leg_swing": 0.0, "lift": 0.0, "la_swing": 1.5, "ra_swing": 1.5}, 0.1)
	_move_tween.tween_interval(maxf(span - blow - 0.4, 0.1))
	_to(_rest_of(keys), 0.32)


func _restart() -> void:
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	_plan.clear()


## The tween's next step: these shader scalars together over [param secs].
func _to(values: Dictionary, secs: float) -> void:
	var first := true
	for key in values:
		var from := float(_plan.get(key, param(key)))
		_plan[key] = float(values[key])
		var step := _move_tween.tween_method(_param.bind(key), from, float(values[key]), secs) if first else _move_tween.parallel().tween_method(_param.bind(key), from, float(values[key]), secs)
		step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		first = false


func _param(value: float, key: String) -> void:
	if mat != null:
		_shade(key, value)


func hold(key: String) -> void:
	busy_until = Time.get_ticks_msec() + 3_600_000
	current = key
	if key == "die" and mat != null:
		_restart()
		_gait_goal = PackedFloat32Array(GAITS[kind].idle)
		_gait_goal[1] = 0.0
		var limp := {"ribbon": 0.0, "charge": 0.0, "dance": 0.0, "wing_fold": 0.9, "wing_raise": -0.35, "head_pitch": 0.45, "la_raise": 0.15, "ra_raise": 0.15, "la_bend": 0.3, "ra_bend": 0.3, "la_swing": 0.2, "ra_swing": 0.2, "lift": 0.0, "lunge": 0.0}
		if kind == "garuda":
			limp.merge({"crouch": 0.7, "roll": 1.25, "bow": 0.35, "dive": 0.0, "leg_swing": 0.0, "talon": -0.4})
		else:
			limp.merge({"bow": -0.35, "roll": 0.35, "twist": 0.2})
		_to(limp, 0.6)
		if kind != "garuda":
			_move_tween.parallel().tween_property(self, "_sink", 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Dissolving into gold from the edges of soft blotches.
		_move_tween.parallel().tween_method(_param.bind("fade"), 1.0, 0.0, 1.1).set_delay(0.25)


func flash(color := Color(1, 1, 1), duration := 0.16) -> void:
	if mat == null:
		return
	if _glow_tween:
		_glow_tween.kill()
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("glow", 0.55)
	_glow_tween = create_tween()
	_glow_tween.tween_method(func(v: float): mat.set_shader_parameter("glow", v), 0.55, 0.0, maxf(duration, 0.05))


# ---------------------------------------------------------------------------
# Boss casts (BossCast), should a move ever be cast through one: the attack's wind-up
# held for the telegraph, the strike on release.
# ---------------------------------------------------------------------------

func cast_body(_pose: String) -> Dictionary:
	return {"lean": 0.0, "lift": 0.0, "sx": 1.03, "sy": 1.05}


func _cast_clip_windup(secs: float, hold_secs: float, clip: String) -> void:
	if mat == null:
		return
	busy_until = Time.get_ticks_msec() + int((secs + hold_secs + 1.0) * 1000.0)
	_cast_clip = clip
	current = clip
	_restart()
	if kind == "garuda":
		_to({"crouch": 0.55, "wing_raise": 0.75, "la_swing": -0.7, "ra_swing": -0.7, "charge": 0.7}, secs)
	else:
		_to({"twist": 0.42, "ra_swing": -0.5, "ra_raise": 2.1, "ra_bend": 0.7, "wing_raise": 0.42, "charge": 0.7, "dance": 0.0}, secs)
	if hold_secs > 0.05:
		_to({"charge": 1.0}, hold_secs)


func _cast_clip_release(secs: float) -> void:
	if mat == null or _cast_clip == "":
		_cast_clip = ""
		return
	busy_until = Time.get_ticks_msec() + int((secs + 0.4) * 1000.0)
	_restart()
	if kind == "garuda":
		_to({"crouch": 0.0, "dive": 0.4, "lunge": 0.4, "wing_raise": -0.4, "la_swing": 1.4, "ra_swing": 1.4, "talon": 1.0}, 0.12)
	else:
		_to({"twist": -0.25, "ra_swing": 1.5, "ra_raise": 0.12, "ra_bend": 0.0, "wing_raise": 0.0, "ribbon": 1.0, "charge": 1.0}, 0.12)
	_move_tween.tween_interval(0.2)
	_to(_rest_of(HeavenBird.POSE_KEYS), secs)
	_cast_clip = ""


func cast_cancel() -> void:
	var was := _cast_clip != ""
	super.cast_cancel()
	if was and mat != null and current != "die":
		_restart()
		_to(_rest_of(HeavenBird.POSE_KEYS), 0.2)
		busy_until = 0


func cast_glow(color: Color, amount: float) -> void:
	if mat == null or (_glow_tween != null and _glow_tween.is_running()):
		return
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("glow", clampf(amount, 0.0, 1.0) * 0.45)


func cast_point(part: String) -> Vector3:
	return point("head" if part == "mouth" else "chest")
