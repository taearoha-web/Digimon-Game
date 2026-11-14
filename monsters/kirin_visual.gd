class_name KirinVisual
extends MonsterVisual
## The kirin กิเลนเหยียบเมฆ drawn by Kirin: no rig, one shared mesh posed by its shader.
## The clips Mob and MobAttack ask for are played by the shader's scalars on this
## kirin's own material:
##   idle / walk / run  breathing and a slow nod / a four-beat walk / a rocking gallop,
##                      the mane and tail streaming back, clouds drifting under the hooves
##   attack (skill1/2)  the horn charge: rears on its hind legs, forehooves curled, then
##                      plunges down, head low, the golden horn forward and alight
##   hurt / die         a flinch / legs fold and it sinks on its side
## The hit flash lights the material (an overlay would draw the mesh unposed).

var mat: ShaderMaterial
var body_mesh: MeshInstance3D
## Mesh metres to world metres.
var fit := 1.0
var _clock := 0.0
var _breeze := 0.0
## The gait now and where it is going: [cycles a second, stride, gallop, stream].
var _gait := Vector4(0.9, 0.0, 0.0, 0.0)
var _gait_goal := Vector4(0.9, 0.0, 0.0, 0.0)
var _move_tween: Tween
var _glow_tween: Tween
var _plan := {}
const GAITS := {"idle": Vector4(0.9, 0.0, 0.0, 0.0), "walk": Vector4(1.15, 0.36, 0.0, 0.3), "run": Vector4(1.75, 0.6, 1.0, 1.0)}
## The scalars the clips tween (all rest at 0).
const POSE_KEYS := ["rear", "tuck", "head_pitch", "lift", "lunge", "fold", "roll", "charge"]


func build(target_height: float) -> void:
	if is_instance_valid(model):
		model.free()
	fit = target_height / Kirin.HEIGHT
	model = Node3D.new()
	model.name = "Kirin"
	add_child(model)
	body_mesh = Kirin.body()
	body_mesh.scale = Vector3.ONE * fit
	model.add_child(body_mesh)
	mat = body_mesh.material_override as ShaderMaterial
	if GameSettings.world_shadows():
		body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_ground_offset = 0.0
	_hover = 0.0
	_rest_scale = Vector3.ONE
	height = target_height
	_breeze = float(absi(get_instance_id()) % 997) * 0.37
	_clock = _breeze * 0.5
	_apply_gait()
	current = "idle"
	set_process(true)


## Where a part of the kirin is at rest, in this node's space: "nose", "head", "chest".
func point(part: String) -> Vector3:
	match part:
		"nose": return Kirin.NOSE * fit
		"head": return Kirin.HEAD * fit
	return Vector3(0, 1.55, 0.3) * fit


func _process(delta: float) -> void:
	if model == null or mat == null:
		return
	var k := delta * 3.5
	_gait = Vector4(move_toward(_gait.x, _gait_goal.x, k), move_toward(_gait.y, _gait_goal.y, k * 0.4), move_toward(_gait.z, _gait_goal.z, k * 0.6), move_toward(_gait.w, _gait_goal.w, k * 0.6))
	_clock += delta * _gait.x
	_breeze += delta
	_apply_gait()


func _apply_gait() -> void:
	mat.set_shader_parameter("clock", _clock)
	mat.set_shader_parameter("breeze", _breeze)
	mat.set_shader_parameter("stride", _gait.y)
	mat.set_shader_parameter("gallop", _gait.z)
	mat.set_shader_parameter("stream", _gait.w)


func play(key: String, _speed := 1.0) -> void:
	if Time.get_ticks_msec() < busy_until or current == key:
		return
	current = key
	_gait_goal = GAITS.get(key, GAITS.idle)


func action(key: String, lock_ms := 450, _speed := 1.0) -> void:
	if mat == null:
		return
	busy_until = Time.get_ticks_msec() + lock_ms
	current = key
	var secs := clampf(float(lock_ms) / 1000.0, 0.35, 1.4)
	_restart()
	match key:
		"hurt":
			_to({"rear": 0.14, "head_pitch": -0.3, "lunge": -0.12}, 0.08)
			_to({"rear": 0.0, "head_pitch": 0.0, "lunge": 0.0}, 0.24)
		"die":
			hold(key)
		_:
			# The horn charge: rear up, forehooves curled and the head thrown back...
			_gait_goal = GAITS.idle
			_to({"rear": 0.62, "tuck": 1.0, "head_pitch": -0.4, "lift": 0.12, "charge": 0.5}, secs * 0.4)
			# ...then down on the forehooves, the head low and the burning horn driven forward.
			_to({"rear": -0.1, "tuck": 0.0, "head_pitch": 0.75, "lift": 0.0, "lunge": 0.5, "charge": 1.0}, secs * 0.2)
			_move_tween.tween_interval(secs * 0.12)
			_to({"rear": 0.0, "head_pitch": 0.0, "lunge": 0.0, "charge": 0.0}, secs * 0.28)


func _restart() -> void:
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	_plan.clear()


## The tween's next step: these shader scalars together over [param secs].
func _to(values: Dictionary, secs: float) -> void:
	var first := true
	for key in values:
		var now: Variant = mat.get_shader_parameter(key)
		var from := float(_plan.get(key, now if now != null else 0.0))
		_plan[key] = float(values[key])
		var step := _move_tween.tween_method(_param.bind(key), from, float(values[key]), secs) if first else _move_tween.parallel().tween_method(_param.bind(key), from, float(values[key]), secs)
		step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		first = false


func _param(value: float, key: String) -> void:
	if mat != null:
		mat.set_shader_parameter(key, value)


func hold(key: String) -> void:
	busy_until = Time.get_ticks_msec() + 3_600_000
	current = key
	if key == "die" and mat != null:
		_restart()
		_gait_goal = GAITS.idle
		_to({"rear": 0.0, "tuck": 0.0, "lunge": 0.0, "charge": 0.0, "fold": 1.0, "roll": 1.4, "head_pitch": 0.4, "lift": 0.05}, 0.6)


func flash(color := Color(1, 1, 1), duration := 0.16) -> void:
	if mat == null:
		return
	if _glow_tween:
		_glow_tween.kill()
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("glow", 0.55)
	_glow_tween = create_tween()
	_glow_tween.tween_method(_param.bind("glow"), 0.55, 0.0, maxf(duration, 0.05))
