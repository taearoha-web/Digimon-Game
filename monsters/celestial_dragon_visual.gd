class_name CelestialDragonVisual
extends MonsterVisual
## A monster drawn as one of the isle's eastern dragons (CelestialDragon): no rig, one
## mesh laid on its pose by the shader. The clips Mob, BossAttack and the mirrors ask for
## are played by tweening the shader's scalars on this dragon's own material:
##   idle / walk / run  the body ripples, faster on the move; flyers bob
##   attack             by the kind's "move": "lunge" (the head draws back and strikes along
##                      its own body), "rear" (rises, then strikes down), "spin" (a whirl),
##                      "swoop" (wings beat hard, a dive at the target)
##   skill1             the breath: rears back, then thrusts the head out, mouth alight
##   skill2             heaven's call: rears high, the whole dragon lifts and glows gold
##   hurt / die         a flinch / the head sinks and the ripple stills
## The hit flash lights the material (an overlay would draw the mesh straight).

var kind := ""
var mat: ShaderMaterial
var body_mesh: MeshInstance3D
var pose: Dictionary = {}
## Mesh metres to world metres.
var fit := 1.0
var _clock := 0.0
var _pace := 1.0
var _pace_goal := 1.0
var _move_tween: Tween
var _glow_tween: Tween
var _model_y := 0.0
## Where the queued tween steps leave each scalar (the next step starts from there).
var _plan := {}
## How far heaven's call lifts the whole dragon now.
var _lift := 0.0


## The visual a template asks for: a celestial dragon for "celestial" templates, the
## sculpted kirin (KirinVisual) for "beast": "kirin", the rig otherwise.
static func make(parent: Node, template: Dictionary) -> MonsterVisual:
	if String(template.get("beast", "")) == "kirin":
		var kirin := KirinVisual.new()
		parent.add_child(kirin)
		kirin.build(float(template.height))
		return kirin
	var kind_id := String(template.get("celestial", ""))
	if CelestialDragon.has(kind_id):
		var dragon := CelestialDragonVisual.new()
		parent.add_child(dragon)
		dragon.build(kind_id, float(template.height), float(template.get("hover", 0.0)))
		return dragon
	var v := MonsterVisual.new()
	parent.add_child(v)
	v.setup(String(template.model), float(template.height), float(template.get("hover", 0.0)), template.get("tint", Color.WHITE))
	return v


func build(p_kind: String, target_height: float, hover := 0.0) -> void:
	kind = p_kind
	if is_instance_valid(model):
		model.free()
	pose = CelestialDragon.pose(kind)
	var box: AABB = pose.box
	fit = target_height / maxf(box.size.y, 0.001)
	model = Node3D.new()
	model.name = "CelestialDragon"
	add_child(model)
	body_mesh = CelestialDragon.body(kind)
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
	_clock = float(absi(get_instance_id()) % 997) * 0.37
	_idle_phase = _clock
	mat.set_shader_parameter("clock", _clock)
	current = "idle"
	set_process(true)


## Where a part of the dragon is now at rest, in this node's space: "nose", "crown",
## "skull", "chest", "seat".
func point(part: String) -> Vector3:
	var p: Vector3 = pose.get(part, pose.get("chest", Vector3.ZERO))
	return Vector3(0, model.position.y if model else 0.0, 0) + p * fit


func _process(delta: float) -> void:
	if model == null or mat == null:
		return
	_pace = move_toward(_pace, _pace_goal, delta * 3.0)
	_clock += delta * _pace
	mat.set_shader_parameter("clock", _clock)
	_idle_phase += delta * 1.6
	var bob := sin(_idle_phase) * minf(height * 0.04, 0.18) if _hover > 0.0 else 0.0
	model.position.y = _model_y + _lift + bob


func play(key: String, _speed := 1.0) -> void:
	if Time.get_ticks_msec() < busy_until or current == key:
		return
	current = key
	_pace_goal = {"walk": 1.7, "run": 2.6}.get(key, 1.0)


func action(key: String, lock_ms := 450, _speed := 1.0) -> void:
	if mat == null:
		return
	busy_until = Time.get_ticks_msec() + lock_ms
	current = key
	var secs := maxf(0.35, float(lock_ms) / 1000.0)
	var spec: Dictionary = CelestialDragon.KINDS.get(kind, {})
	var size := float(spec.get("head", 1.0)) * 1.6
	_restart()
	match key:
		"attack":
			_strike(String(spec.get("move", "lunge")), minf(secs, 0.9), size)
		"hurt":
			_to({"reach": -0.6 * size, "rise": 0.2 * size}, 0.08)
			_to({"reach": 0.0, "rise": 0.0}, 0.22)
		"skill1":
			# The breath: draw back and up, then the head thrown forward, mouth alight.
			_to({"reach": -0.7 * size, "rise": 0.35 * size, "breath": 0.6}, secs * 0.3)
			_to({"reach": 1.8 * size, "rise": -0.7 * size, "breath": 1.0}, secs * 0.18)
			_move_tween.tween_interval(secs * 0.32)
			_to({"reach": 0.0, "rise": 0.0, "breath": 0.0}, secs * 0.2)
		"skill2":
			# Heaven's call: reared to the sky, the whole dragon lifted, glowing gold.
			_to({"reach": -0.5 * size, "rise": 0.6 * size, "breath": 1.0}, secs * 0.35)
			_move_tween.parallel().tween_property(self, "_lift", height * 0.05, secs * 0.35).set_trans(Tween.TRANS_SINE)
			_move_tween.tween_interval(secs * 0.3)
			_to({"reach": 1.1 * size, "rise": -0.9 * size}, secs * 0.12)
			_move_tween.parallel().tween_property(self, "_lift", 0.0, secs * 0.12)
			_to({"reach": 0.0, "rise": 0.0, "breath": 0.0}, secs * 0.23)
		"die":
			hold(key)
		_:
			_strike("lunge", minf(secs, 0.7), size)


func _strike(style: String, secs: float, size: float) -> void:
	match style:
		"rear":
			_to({"reach": -0.8 * size, "rise": 1.4 * size}, secs * 0.4)
			_to({"reach": 1.6 * size, "rise": -0.5 * size}, secs * 0.2)
			_to({"reach": 0.0, "rise": 0.0}, secs * 0.4)
		"spin":
			_to({"reach": -0.4 * size}, secs * 0.2)
			_move_tween.parallel().tween_property(model, "rotation:y", TAU, secs * 0.6).from(0.0).set_trans(Tween.TRANS_SINE)
			_to({"reach": 1.2 * size}, secs * 0.4)
			_to({"reach": 0.0}, secs * 0.4)
		"swoop":
			mat.set_shader_parameter("flap_rate", 13.0)
			_to({"reach": -0.6 * size, "rise": 0.8 * size}, secs * 0.35)
			_to({"reach": 2.0 * size, "rise": -0.8 * size}, secs * 0.25)
			_to({"reach": 0.0, "rise": 0.0}, secs * 0.4)
			_move_tween.tween_callback(func(): mat.set_shader_parameter("flap_rate", 5.0))
		_:
			_to({"reach": -0.9 * size}, secs * 0.35)
			_to({"reach": 1.8 * size, "rise": -0.2 * size}, secs * 0.2)
			_to({"reach": 0.0, "rise": 0.0}, secs * 0.45)


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
		_to({"rise": -2.2, "reach": -1.0, "wave_amp": 0.0}, 0.6)
		_pace_goal = 0.2


func flash(color := Color(1, 1, 1), duration := 0.16) -> void:
	if mat == null:
		return
	if _glow_tween:
		_glow_tween.kill()
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("glow", 0.55)
	_glow_tween = create_tween()
	_glow_tween.tween_method(_param.bind("glow"), 0.55, 0.0, maxf(duration, 0.05))
