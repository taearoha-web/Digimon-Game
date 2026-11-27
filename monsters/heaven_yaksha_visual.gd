class_name HeavenYakshaVisual
extends MonsterVisual
## A gate giant of ดินแดนเทวาลัย drawn by HeavenYaksha: no rig, one shared mesh whose twelve
## rigid parts the shader carries by the bones this node poses each frame (one uniform
## array, also handed to the ink outline). The clips Mob, MobAttack and BossCast ask for:
##   idle         the temple guardian's stance (ยักษ์วัดแจ้ง): the club planted head-down in
##                front, both fists on its pommel, breathing, the head turning slowly
##   walk / run   a heavy stomping gait, the club carried on the right shoulder, the left
##                arm swinging, the body rolling over the stride (faster, lower at a run)
##   attack       jade: the club swung up behind the crown (it kindles gold through the
##                wind-up), then smashed down in front, the body thrown after it, landing
##                on the move's impact (MobAttack "cleave": 0.8 s); king: the club held out,
##                the body wound back, then a whole whirl (MobAttack "spin": 0.9 s). The
##                quick basic blow (450 ms) is a short smash.
##   hurt         a flinch laid over whatever it is doing (a blow never cuts a swing short)
##   die          he sinks to his knees, slumps, and dissolves into gold
## Far from the camera the pose is worked out every few frames.

const DEG := PI / 180.0
## Poses (degrees per bone; "lift"/"fwd": the hips' offset in mesh units; "glow": the club).
const GUARD := {"hips": Vector3(0, 0, 0), "chest": Vector3(4, 0, 0), "neck": Vector3(-4, 0, 0),
	"sh_r": Vector3(-39, 0, 8), "el_r": Vector3(-63, 0, 0), "club": Vector3(0, 180, 0),
	"sh_l": Vector3(40, -70, 0), "el_l": Vector3(-80, 0, 0),
	"hip_l": Vector3(-4, 0, 6), "kn_l": Vector3(8, 0, 0), "hip_r": Vector3(-4, 0, -6), "kn_r": Vector3(8, 0, 0), "lift": 0.0}
const CARRY := {"hips": Vector3(0, 0, 0), "chest": Vector3(8, 0, 0), "neck": Vector3(-6, 0, 0),
	"sh_r": Vector3(-25, 0, -32), "el_r": Vector3(-118, 0, 0), "club": Vector3(0, -20, 0),
	"sh_l": Vector3(0, 0, 12), "el_l": Vector3(-22, 0, 0),
	"hip_l": Vector3(0, 0, 5), "kn_l": Vector3(6, 0, 0), "hip_r": Vector3(0, 0, -5), "kn_r": Vector3(6, 0, 0), "lift": 0.0}
const RAISE := {"hips": Vector3(-6, 0, 0), "chest": Vector3(-14, 8, 0), "neck": Vector3(10, 0, 0),
	"sh_r": Vector3(-172, 0, -12), "el_r": Vector3(-52, 0, 0), "club": Vector3(0, 0, 0),
	"sh_l": Vector3(-60, 0, 58), "el_l": Vector3(-40, 0, 0),
	"hip_l": Vector3(-14, 0, 10), "kn_l": Vector3(20, 0, 0), "hip_r": Vector3(8, 0, -10), "kn_r": Vector3(18, 0, 0), "lift": 0.0, "glow": 1.0}
const SMASH := {"hips": Vector3(10, -6, 0), "chest": Vector3(30, -10, 0), "neck": Vector3(-22, 0, 0),
	"sh_r": Vector3(-78, 10, 12), "el_r": Vector3(-6, 0, 0), "club": Vector3(0, 0, 0),
	"sh_l": Vector3(-20, 0, 46), "el_l": Vector3(-50, 0, 0),
	"hip_l": Vector3(-46, 0, 12), "kn_l": Vector3(62, 0, 0), "hip_r": Vector3(12, 0, -12), "kn_r": Vector3(40, 0, 0), "lift": 0.0, "glow": 0.6}
## The king's whirl: wound back with the club held out to his right, then turned through.
const WIND := {"hips": Vector3(0, 28, 0), "chest": Vector3(6, 34, 0), "neck": Vector3(0, -40, 0),
	"sh_r": Vector3(-20, 0, -78), "el_r": Vector3(-30, 0, 0), "club": Vector3(0, 90, 0),
	"sh_l": Vector3(-50, 0, 40), "el_l": Vector3(-70, 0, 0),
	"hip_l": Vector3(-30, 0, 14), "kn_l": Vector3(46, 0, 0), "hip_r": Vector3(-16, 0, -18), "kn_r": Vector3(40, 0, 0), "lift": 0.0, "glow": 1.0}
const WHIRL := {"hips": Vector3(6, -20, 0), "chest": Vector3(10, -26, 0), "neck": Vector3(-6, 20, 0),
	"sh_r": Vector3(-10, 0, -92), "el_r": Vector3(-6, 0, 0), "club": Vector3(0, 90, 0),
	"sh_l": Vector3(-10, 0, 80), "el_l": Vector3(-20, 0, 0),
	"hip_l": Vector3(-24, 0, 14), "kn_l": Vector3(36, 0, 0), "hip_r": Vector3(-24, 0, -14), "kn_r": Vector3(36, 0, 0), "lift": 0.0, "glow": 0.8}
const KNEEL := {"hips": Vector3(18, 0, 4), "chest": Vector3(34, 0, -6), "neck": Vector3(30, 14, 0),
	"sh_r": Vector3(-20, 0, -26), "el_r": Vector3(-20, 0, 0), "club": Vector3(40, 0, 0),
	"sh_l": Vector3(-10, 0, 30), "el_l": Vector3(-14, 0, 0),
	"hip_l": Vector3(-96, 0, 10), "kn_l": Vector3(118, 0, 0), "hip_r": Vector3(-70, 0, -10), "kn_r": Vector3(126, 0, 0), "lift": 0.0}

var kind := ""
var mat: ShaderMaterial
var line: ShaderMaterial
var body_mesh: MeshInstance3D
## Mesh units to metres.
var fit := 1.0
## The pose now (for tests and tools).
var pose_now: Dictionary = {}
var fade := 1.0
var _king := false
var _clock := 0.0
var _breath := 0.0
var _move := 0.0
var _move_goal := 0.0
## The action's keys: [[seconds, pose], ...], played from _track_t, blended in by _track_w.
var _track: Array = []
var _track_t := 0.0
var _track_w := 0.0
var _track_hold := false
var _hurt := 0.0
var _spin_from := -1.0
var _spin_len := 0.0
var _dying := false
var _flash_tween: Tween
var _skip := 0
var _far := false
var _far_check := 0.0
var _plant := true


func build(p_kind: String, target_height: float) -> void:
	kind = p_kind if HeavenYaksha.has(p_kind) else "jade"
	_king = bool(HeavenYaksha.KINDS[kind].king)
	if is_instance_valid(model):
		model.free()
	fit = target_height / HeavenYaksha.figure_height(kind)
	model = Node3D.new()
	model.name = "HeavenYaksha"
	add_child(model)
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "YakshaBody"
	body_mesh.mesh = HeavenYaksha.mesh(kind)
	mat = HeavenYaksha.material(kind)
	# The ink outline above low quality, dropped under strict memory pressure.
	if GameSettings.quality > 0 and outline and MemoryGuard.pressure < 2:
		line = HeavenYaksha.outline(kind, 0.012 / maxf(fit, 0.01))
		mat.next_pass = line
	body_mesh.material_override = mat
	body_mesh.scale = Vector3.ONE * fit
	body_mesh.extra_cull_margin = 0.5
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if GameSettings.world_shadows() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(body_mesh)
	_ground_offset = -HeavenYaksha.SOLE_Y * fit
	_hover = 0.0
	model.position.y = _ground_offset
	_rest_scale = Vector3.ONE
	height = target_height
	_breath = float(absi(get_instance_id()) % 997) * 0.37
	_clock = _breath * 0.13
	current = "idle"
	_pose_now()
	set_process(true)


## Where a part of the giant is at rest, in this node's space: "head", "mouth", "club", "chest".
func point(part: String) -> Vector3:
	var spec: Dictionary = HeavenYaksha.KINDS[kind]
	var neck: Vector3 = HeavenYaksha.PIVOTS[2]
	var p := Vector3(0, 0.2, 0.06)
	match part:
		"head": p = neck + Vector3(0, 0.072, 0.02) * float(spec.head)
		"mouth": p = neck + Vector3(0, 0.04, 0.08) * float(spec.head)
		"club": p = Vector3(0, 0.2, 0.45)
	return p * fit + Vector3(0, _ground_offset, 0)


func _process(delta: float) -> void:
	if model == null or mat == null:
		return
	var goal := _move_goal
	_move = move_toward(_move, goal, delta * 3.0)
	var speed := lerpf(0.0, 1.05, clampf(_move, 0.0, 1.0)) + 0.45 * clampf(_move - 1.0, 0.0, 1.0)
	_clock += delta * speed
	_breath += delta
	_hurt = move_toward(_hurt, 0.0, delta * 4.0)
	if not _track.is_empty():
		_track_t += delta
		var end := float((_track[_track.size() - 1] as Array)[0])
		if _track_t <= end or _track_hold:
			_track_w = move_toward(_track_w, 1.0, delta * 10.0)
		else:
			_track_w = move_toward(_track_w, 0.0, delta * 3.5)
			if _track_w <= 0.0 and not _dying:
				_track.clear()
	if _spin_from >= 0.0:
		var f := clampf((_track_t - _spin_from) / maxf(_spin_len, 0.05), 0.0, 1.0)
		model.rotation.y = TAU * (f * f * (3.0 - 2.0 * f))
		if f >= 1.0:
			_spin_from = -1.0
			model.rotation.y = 0.0
	# Far away: the pose every third frame.
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		_far = cam != null and cam.global_position.distance_squared_to(global_position) > 900.0
	_skip = (_skip + 1) % 3
	if _far and _skip != 0 and _track.is_empty():
		return
	_pose_now()


## Works out this frame's pose and hands the bones to the shader.
func _pose_now() -> void:
	var pose := _loco()
	if not _track.is_empty() and _track_w > 0.0:
		pose = blend(pose, _sample(), _track_w)
	if _hurt > 0.0:
		var h := _hurt * _hurt
		pose.chest = (pose.chest as Vector3) + Vector3(-16, 0, 4) * h
		pose.neck = (pose.neck as Vector3) + Vector3(-20, 0, -6) * h
		pose.sh_l = (pose.sh_l as Vector3) + Vector3(10, 0, 14) * h
		pose.fwd = float(pose.get("fwd", 0.0)) - 0.03 * h
	pose_now = pose
	var bones := HeavenYaksha.rest_bones()
	pose_bones(kind, pose, bones, _plant)
	mat.set_shader_parameter("bones", bones)
	mat.set_shader_parameter("club_glow", float(pose.get("glow", 0.0)))
	if line:
		line.set_shader_parameter("bones", bones)


## The stance and the gait, breathing over both.
func _loco() -> Dictionary:
	var walk := clampf(_move, 0.0, 1.0)
	var run := clampf(_move - 1.0, 0.0, 1.0)
	var pose := blend(GUARD, CARRY, smoothstep(0.0, 0.6, walk))
	var b := _breath
	var breathe := sin(b * 1.7)
	pose.chest = (pose.chest as Vector3) + Vector3(breathe * 2.2, 0, 0)
	pose.neck = (pose.neck as Vector3) + Vector3(sin(b * 0.9) * 3.0, sin(b * 0.37) * 16.0 * (1.0 - walk), 0)
	pose.sh_l = (pose.sh_l as Vector3) + Vector3(0, 0, -breathe * 1.5)
	pose.sh_r = (pose.sh_r as Vector3) + Vector3(0, 0, breathe * 1.5)
	pose.lift = float(pose.lift) + breathe * 0.004 * (1.0 - walk)
	if walk > 0.0:
		var ph := TAU * _clock
		var stride := (26.0 + 10.0 * run) * walk
		var s := sin(ph)
		pose.hip_l = (pose.hip_l as Vector3) + Vector3(-s * stride - 6.0 * run, 0, 0)
		pose.hip_r = (pose.hip_r as Vector3) + Vector3(s * stride - 6.0 * run, 0, 0)
		pose.kn_l = (pose.kn_l as Vector3) + Vector3(maxf(0.0, cos(ph)) * stride * 1.7 + 10.0 * run, 0, 0)
		pose.kn_r = (pose.kn_r as Vector3) + Vector3(maxf(0.0, -cos(ph)) * stride * 1.7 + 10.0 * run, 0, 0)
		pose.sh_l = (pose.sh_l as Vector3) + Vector3(s * stride * 0.9, 0, 0)
		pose.el_l = (pose.el_l as Vector3) + Vector3(-maxf(0.0, -s) * 22.0 * walk, 0, 0)
		pose.hips = (pose.hips as Vector3) + Vector3(4.0 * run, s * 8.0 * walk, cos(ph) * 0.0 + s * 3.0 * walk)
		pose.chest = (pose.chest as Vector3) + Vector3(6.0 * run, -s * 10.0 * walk, -s * 3.0 * walk)
		pose.neck = (pose.neck as Vector3) + Vector3(0, s * 4.0 * walk, s * 2.0 * walk)
		# The heavy roll: up over the planted leg, down onto the next.
		pose.lift = float(pose.lift) + absf(cos(ph)) * 0.018 * walk - 0.012 * run
	return pose


## Two poses mixed, [param w] of the second.
static func blend(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	if w <= 0.0:
		return a.duplicate()
	var out := a.duplicate()
	for key in b:
		var va: Variant = a.get(key, Vector3.ZERO if b[key] is Vector3 else 0.0)
		if b[key] is Vector3:
			out[key] = (va as Vector3).lerp(b[key], w)
		else:
			out[key] = lerpf(float(va), float(b[key]), w)
	return out


func _sample() -> Dictionary:
	var keys := _track
	if _track_t <= float((keys[0] as Array)[0]):
		return keys[0][1]
	for i in range(1, keys.size()):
		var t1 := float((keys[i] as Array)[0])
		if _track_t <= t1:
			var t0 := float((keys[i - 1] as Array)[0])
			var f := clampf((_track_t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
			f = f * f * (3.0 - 2.0 * f)
			return blend(keys[i - 1][1], keys[i][1], f)
	return keys[keys.size() - 1][1]


## The bones for [param pose] (degrees per bone), written into [param out] (4 per bone);
## [param plant] keeps the lower sole on the ground.
static func pose_bones(p_kind: String, pose: Dictionary, out: PackedVector3Array, plant := true) -> Array:
	var world: Array = []
	world.resize(HeavenYaksha.BONES)
	var root := Vector3(0, float(pose.get("lift", 0.0)), float(pose.get("fwd", 0.0)))
	for j in HeavenYaksha.BONES:
		var e: Vector3 = pose.get(HeavenYaksha.KEYS[j], Vector3.ZERO)
		var basis := Basis.from_euler(e * DEG)
		var c: Vector3 = HeavenYaksha.PIVOTS[j]
		var local := Transform3D(basis, c - basis * c)
		var parent: int = HeavenYaksha.PARENT[j]
		world[j] = (Transform3D(Basis(), root) * local) if parent < 0 else (world[parent] as Transform3D) * local
	if plant:
		var sole := HeavenYaksha.SOLE
		var lo := minf(((world[9] as Transform3D) * sole).y, ((world[10] as Transform3D) * Vector3(-sole.x, sole.y, sole.z)).y)
		var dy := HeavenYaksha.SOLE_Y - lo
		for j in HeavenYaksha.BONES:
			world[j] = Transform3D((world[j] as Transform3D).basis, (world[j] as Transform3D).origin + Vector3(0, dy, 0))
	for j in HeavenYaksha.BONES:
		var t: Transform3D = world[j]
		out[j * 4] = t.basis.x
		out[j * 4 + 1] = t.basis.y
		out[j * 4 + 2] = t.basis.z
		out[j * 4 + 3] = t.origin
	return world


func play(key: String, _speed := 1.0) -> void:
	if Time.get_ticks_msec() < busy_until or current == key:
		return
	current = key
	_move_goal = {"walk": 1.0, "run": 2.0}.get(key, 0.0)


## The pose the track starts from: wherever the giant is now.
func _from() -> Dictionary:
	return pose_now.duplicate() if not pose_now.is_empty() else GUARD.duplicate()


func action(key: String, lock_ms := 450, _speed := 1.0) -> void:
	if mat == null or _dying:
		return
	if key == "hurt":
		# A flinch over the swing, not instead of it.
		_hurt = 1.0
		busy_until = maxi(busy_until, Time.get_ticks_msec() + lock_ms)
		if current != "attack" or _track.is_empty():
			current = key
		return
	if key == "die":
		hold(key)
		return
	busy_until = Time.get_ticks_msec() + lock_ms
	current = key
	_move_goal = 0.0
	var secs := float(lock_ms) / 1000.0
	# A move's blow lands 0.4 s before its lock runs out (BossAttack); the basic blow at once.
	var impact := secs - 0.4 if lock_ms > 600 else 0.12
	if _king and lock_ms > 600:
		_whirl(impact)
	else:
		_smash(impact)


## The overhead smash, its blow at [param impact] seconds.
func _smash(impact: float) -> void:
	var start := _from()
	_spin_from = -1.0
	model.rotation.y = 0.0
	if impact < 0.3:
		_set_track([[0.0, start], [0.08, blend(RAISE, SMASH, 0.25)], [impact + 0.02, SMASH], [impact + 0.22, SMASH]])
		return
	var up := impact - 0.2
	var hold := blend(RAISE, RAISE, 1.0)
	hold.chest = (RAISE.chest as Vector3) + Vector3(-5, 0, 0)
	hold.sh_r = (RAISE.sh_r as Vector3) + Vector3(-8, 0, 0)
	_set_track([[0.0, start], [up * 0.7, RAISE], [up, hold], [impact, SMASH], [impact + 0.3, SMASH]])


## The king's whirl: wound back, then a whole turn through the blow at [param impact].
func _whirl(impact: float) -> void:
	var start := _from()
	var turn := minf(0.42, impact * 0.5)
	_set_track([[0.0, start], [impact - turn, WIND], [impact - turn * 0.4, WHIRL], [impact + 0.12, WHIRL], [impact + 0.35, blend(WHIRL, GUARD, 0.4)]])
	_spin_from = impact - turn
	_spin_len = turn + 0.1


func _set_track(keys: Array, hold := false) -> void:
	_track = keys
	_track_t = 0.0
	_track_hold = hold
	_track_w = maxf(_track_w, 0.0)


func hold(key: String) -> void:
	busy_until = Time.get_ticks_msec() + 3_600_000
	current = key
	if key == "die" and mat != null and not _dying:
		_dying = true
		_spin_from = -1.0
		model.rotation.y = 0.0
		_move_goal = 0.0
		var slump := KNEEL.duplicate()
		slump.chest = (KNEEL.chest as Vector3) + Vector3(18, 0, 0)
		slump.neck = (KNEEL.neck as Vector3) + Vector3(16, 0, 0)
		_set_track([[0.0, _from()], [0.36, KNEEL], [0.8, slump]], true)
		_track_w = 1.0
		var t := create_tween()
		t.tween_interval(0.42)
		t.tween_method(_set_fade, 1.0, 0.0, 0.85)


func _set_fade(f: float) -> void:
	fade = f
	if mat:
		mat.set_shader_parameter("fade", f)
	if line:
		line.set_shader_parameter("fade", f)


func flash(color := Color(1, 1, 1), duration := 0.16) -> void:
	if mat == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash", 0.6)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_flash_param, 0.6, 0.0, maxf(duration, 0.05))


func _flash_param(v: float) -> void:
	if mat:
		mat.set_shader_parameter("flash", v)


# ---------------------------------------------------------------------------
# Boss casts (BossCast): the wind-up held as the telegraph runs (the club raised and
# kindling, or the king wound back), the release the smash or the whirl.
# ---------------------------------------------------------------------------

func cast_body(_pose: String) -> Dictionary:
	return {"lean": 0.0, "lift": 0.0, "sx": 1.03, "sy": 1.03}


func _cast_clip_windup(secs: float, hold: float, clip: String) -> void:
	if mat == null:
		return
	busy_until = Time.get_ticks_msec() + int((secs + hold + 1.0) * 1000.0)
	_cast_clip = clip
	current = clip
	_move_goal = 0.0
	var top := WIND if _king else RAISE
	_set_track([[0.0, _from()], [maxf(secs, 0.1), top]], true)


func _cast_clip_release(secs: float) -> void:
	if mat == null or _cast_clip == "":
		_cast_clip = ""
		return
	busy_until = Time.get_ticks_msec() + int((secs + 0.4) * 1000.0)
	if _king:
		_set_track([[0.0, _from()], [0.12, WHIRL], [0.12 + secs, WHIRL]])
		_spin_from = 0.0
		_spin_len = 0.3
	else:
		_set_track([[0.0, _from()], [0.1, SMASH], [0.1 + secs, SMASH]])
	_cast_clip = ""


func cast_cancel() -> void:
	var was := _cast_clip != ""
	super.cast_cancel()
	if was and mat != null and not _dying:
		_track_hold = false
		_track_t = 99.0
		busy_until = 0


func cast_glow(color: Color, amount: float) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("glow", clampf(amount, 0.0, 1.0) * 0.3)


func cast_point(part: String) -> Vector3:
	return point("mouth" if part == "mouth" else "chest")
