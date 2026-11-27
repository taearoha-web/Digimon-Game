class_name HeavenNagaVisual
extends MonsterVisual
## พญานาคทองเทวาลัย drawn by HeavenNaga: no rig, one shared mesh posed by its shader. The
## clips Mob, MobAttack and BossCast ask for play on this naga's own material:
##   idle / walk / run  the body ripples down the coil (faster on the move), the seven heads
##                      sway each on its own neck, the hood turns slowly; it bobs on its
##                      cloud
##   attack             the hood rears back and fans out, the mouths gape and kindle, then
##                      it strikes forward and spits on the move's impact (MobAttack
##                      "mortar": 1.2 s); the quick basic blow is a short strike
##   hurt               a flinch laid over whatever it is doing
##   die                the hood droops, the coil sinks into its cloud and it dissolves
##                      into gold
## The hit flash lights the material.

## The scalars the clips tween (all rest at 0 but sway at 1).
const KEYS := ["lean", "reach", "rise", "gape", "breath", "spread", "sink"]

var mat: ShaderMaterial
var body_mesh: MeshInstance3D
var fit := 1.0
var fade := 1.0
var _clock := 0.0
var _breeze := 0.0
var _pace := 1.0
var _pace_goal := 1.0
var _model_y := 0.0
var _s := {}
var _plan := {}
var _flinch := 0.0
var _move_tween: Tween
var _glow_tween: Tween
var _dying := false


func build(_kind: String, target_height: float, hover := 0.0) -> void:
	if is_instance_valid(model):
		model.free()
	var box: AABB = HeavenNaga.BOX
	fit = target_height / HeavenNaga.FIGURE_H
	model = Node3D.new()
	model.name = "HeavenNaga"
	add_child(model)
	body_mesh = HeavenNaga.body()
	body_mesh.scale = Vector3.ONE * fit
	model.add_child(body_mesh)
	mat = body_mesh.material_override as ShaderMaterial
	if GameSettings.world_shadows():
		body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_ground_offset = -box.position.y * fit
	_hover = hover
	_model_y = _ground_offset + hover
	model.position.y = _model_y
	_rest_scale = Vector3.ONE
	height = target_height + hover
	for key in KEYS:
		_s[key] = 0.0
	_breeze = float(absi(get_instance_id()) % 997) * 0.37
	_clock = _breeze * 0.5
	current = "idle"
	_push()
	set_process(true)


## Where a part of the naga is at rest, in this node's space: "nose" (the king head's
## snout), "crown" (its crown), "chest" (the neck's top).
func point(part: String) -> Vector3:
	var p := HeavenNaga.neck()
	match part:
		"nose": p = HeavenNaga.nose()
		"crown": p = HeavenNaga.neck() + HeavenNaga._head_at(HeavenNaga.HEADS[0]) + Vector3(0, 0.55, 0)
	return Vector3(0, _model_y, 0) + p * fit


func _process(delta: float) -> void:
	if model == null or mat == null:
		return
	_pace = move_toward(_pace, _pace_goal, delta * 2.0)
	_clock += delta * _pace
	_breeze += delta
	_flinch = move_toward(_flinch, 0.0, delta * 4.0)
	var bob := sin(_breeze * 1.4) * minf(height * 0.025, 0.14) if _hover > 0.0 else 0.0
	model.position.y = _model_y + bob
	_push()


func _push() -> void:
	var f := _flinch * _flinch
	mat.set_shader_parameter("clock", _clock)
	mat.set_shader_parameter("breeze", _breeze)
	mat.set_shader_parameter("lean", float(_s.lean) - 0.2 * f)
	mat.set_shader_parameter("turn", 0.0 if _dying else sin(_breeze * 0.31) * 0.22 * (1.0 - float(_s.spread)))
	mat.set_shader_parameter("reach", float(_s.reach))
	mat.set_shader_parameter("rise", float(_s.rise) + 0.04 * sin(_breeze * 1.1))
	mat.set_shader_parameter("gape", clampf(float(_s.gape) + 0.4 * f + 0.06 * (0.5 + 0.5 * sin(_breeze * 0.7)), 0.0, 1.2))
	mat.set_shader_parameter("breath", float(_s.breath))
	mat.set_shader_parameter("spread", float(_s.spread))
	mat.set_shader_parameter("sink", float(_s.sink))
	mat.set_shader_parameter("sway", 0.0 if _dying else (1.0 + 0.6 * clampf(_pace - 1.0, 0.0, 1.0)))


func play(key: String, _speed := 1.0) -> void:
	if Time.get_ticks_msec() < busy_until or current == key:
		return
	current = key
	_pace_goal = {"walk": 1.6, "run": 2.4}.get(key, 1.0)


func action(key: String, lock_ms := 450, _speed := 1.0) -> void:
	if mat == null or _dying:
		return
	if key == "hurt":
		_flinch = 1.0
		busy_until = maxi(busy_until, Time.get_ticks_msec() + lock_ms)
		return
	if key == "die":
		hold(key)
		return
	busy_until = Time.get_ticks_msec() + lock_ms
	current = key
	var secs := float(lock_ms) / 1000.0
	var impact := secs - 0.4 if lock_ms > 600 else 0.1
	_restart()
	if impact < 0.3:
		_to({"lean": -0.22, "gape": 0.5, "breath": 0.8, "rise": 0.08}, 0.08)
		_to({"lean": 0.38, "reach": 0.25, "gape": 1.0, "rise": -0.05}, 0.12)
		_move_tween.tween_callback(_spit)
		_move_tween.tween_interval(0.08)
		_rest(0.36)
		return
	# Rear back, the hood fanned, the mouths gaping and kindling...
	var up := impact - 0.24
	_to({"lean": -0.46, "rise": 0.28, "gape": 0.75, "breath": 1.0, "spread": 1.0}, up * 0.75)
	_to({"lean": -0.52, "rise": 0.32, "gape": 0.85}, up * 0.25)
	# ...then the strike forward, spitting as the blow lands.
	_to({"lean": 0.52, "reach": 0.45, "rise": -0.12, "gape": 1.05, "spread": 0.5}, 0.2)
	_move_tween.tween_callback(_spit)
	_move_tween.tween_interval(0.16)
	_rest(0.45)


func _rest(secs: float) -> void:
	_to({"lean": 0.0, "reach": 0.0, "rise": 0.0, "gape": 0.0, "breath": 0.0, "spread": 0.0}, secs)


## The flash of the spit: the mouths and the body flare gold for a moment.
func _spit() -> void:
	flash(Color("fff0b0"), 0.22)


func _restart() -> void:
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	_plan.clear()


## The tween's next step: these scalars together over [param secs].
func _to(values: Dictionary, secs: float) -> void:
	var first := true
	for key in values:
		var from := float(_plan.get(key, _s.get(key, 0.0)))
		_plan[key] = float(values[key])
		var step := _move_tween.tween_method(_put.bind(key), from, float(values[key]), maxf(secs, 0.02)) if first else _move_tween.parallel().tween_method(_put.bind(key), from, float(values[key]), maxf(secs, 0.02))
		step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		first = false


func _put(value: float, key: String) -> void:
	_s[key] = value


## The scalars now (tests and tools).
func scalar(key: String) -> float:
	return float(_s.get(key, 0.0))


func hold(key: String) -> void:
	busy_until = Time.get_ticks_msec() + 3_600_000
	current = key
	if key == "die" and mat != null and not _dying:
		_dying = true
		_restart()
		_to({"lean": 0.75, "reach": 0.1, "rise": -0.3, "gape": 0.25, "breath": 0.0, "spread": 0.0, "sink": 0.55}, 0.85)
		_pace_goal = 0.15
		var t := create_tween()
		t.tween_interval(0.35)
		t.tween_method(_set_fade, 1.0, 0.0, 0.9)


func _set_fade(f: float) -> void:
	fade = f
	if mat:
		mat.set_shader_parameter("fade", f)


func flash(color := Color(1, 1, 1), duration := 0.16) -> void:
	if mat == null:
		return
	if _glow_tween:
		_glow_tween.kill()
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash", 0.55)
	_glow_tween = create_tween()
	_glow_tween.tween_method(_flash_param, 0.55, 0.0, maxf(duration, 0.05))


func _flash_param(v: float) -> void:
	if mat:
		mat.set_shader_parameter("flash", v)


# ---------------------------------------------------------------------------
# Boss casts (BossCast): reared back with the mouths kindling for the whole telegraph,
# then the strike.
# ---------------------------------------------------------------------------

func cast_body(_pose: String) -> Dictionary:
	return {"lean": 0.0, "lift": 0.0, "sx": 1.03, "sy": 1.03}


func _cast_clip_windup(secs: float, hold: float, clip: String) -> void:
	if mat == null:
		return
	busy_until = Time.get_ticks_msec() + int((secs + hold + 1.2) * 1000.0)
	_cast_clip = clip
	current = clip
	_restart()
	_to({"lean": -0.48, "rise": 0.3, "gape": 0.8, "breath": 1.0, "spread": 1.0}, maxf(secs, 0.1))
	if hold > 0.05:
		_to({"lean": -0.54, "gape": 0.9}, hold)


func _cast_clip_release(secs: float) -> void:
	if mat == null or _cast_clip == "":
		_cast_clip = ""
		return
	busy_until = Time.get_ticks_msec() + int((secs + 0.5) * 1000.0)
	_restart()
	_to({"lean": 0.52, "reach": 0.45, "rise": -0.12, "gape": 1.05, "spread": 0.5}, 0.14)
	_move_tween.tween_callback(_spit)
	_move_tween.tween_interval(0.2)
	_rest(secs)
	_cast_clip = ""


func cast_cancel() -> void:
	var was := _cast_clip != ""
	super.cast_cancel()
	if was and mat != null and not _dying:
		_restart()
		_rest(0.2)
		busy_until = 0


func cast_glow(color: Color, amount: float) -> void:
	if mat == null or (_glow_tween != null and _glow_tween.is_running()):
		return
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("glow", clampf(amount, 0.0, 1.0) * 0.3)


func cast_point(part: String) -> Vector3:
	return point("nose" if part == "mouth" else "chest")
