class_name TitanVisual
extends MonsterVisual
## ★500 buff: covenant_of_beasts (พันธสัญญาไททัน) — the Titan's body, sculpted in code: a
## colossus of mossy grey-green stone bound by jade veins and gold bands, a heart crystal
## burning in its chest, a horned crown over glowing eyes, boulder fists, and a rune ring and
## three shards of rock turning at its back. Built at [param height] metres (the Summon's
## size scales the whole node). The generic clip keys play procedurally: idle breathes,
## walk / run stride (legs, arms and a heavy bob), attack raises both fists and slams them
## down (the blow lands about 0.42 s in, as a legend summon's), hurt rocks it, die sinks it.

const STONE := Color("74857a")
const STONE_DARK := Color("434f48")
const MOSS := Color("5d7a46")
const GOLD := Color("e8c860")

var _jade := Color("8af05a")
var _h := 4.6
var _body: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _forearms: Array[Node3D] = []
var _ring: Node3D
var _shards: Node3D
var _core: MeshInstance3D
var _phase := 0.0
var _stride := 0.0
var _act := ""
var _act_t := 0.0
var _act_len := 0.0
var _held := false
var _pulse := 0.0


func setup(_model_path: String, _target_height: float, _hover := 0.0, _tint := Color.WHITE, _skin: Texture2D = null) -> void:
	pass


## Sculpts the colossus [param p_height] metres tall in [param color] (its jade).
func build(p_height: float, color: Color) -> void:
	_h = maxf(p_height, 1.0)
	_jade = color
	height = _h
	current = "idle"
	var h := _h
	var stone := MeshKit.toon(STONE, {"rim": true})
	var dark := MeshKit.toon(STONE_DARK)
	var moss := MeshKit.toon(MOSS)
	var gold := MeshKit.toon(GOLD, {"emission": 0.35})
	var jade := MeshKit.toon(_jade, {"emission": 1.6})
	var glow := MeshKit.toon(_jade.lerp(Color.WHITE, 0.55), {"emission": 3.0, "unshaded": true})
	_body = MeshKit.pivot(self, "TitanBody")
	_hips = MeshKit.pivot(_body, "Hips", Vector3(0, 0.44 * h, 0))
	# The pelvis and a belt of gold.
	MeshKit.part(_hips, MeshKit.sphere(), dark, Vector3(0, 0.0, 0), Vector3(0.34, 0.17, 0.24) * h)
	MeshKit.part(_hips, MeshKit.cylinder(), gold, Vector3(0, 0.05 * h, 0), Vector3(0.36, 0.035, 0.26) * h)
	# Legs: thick stone pillars, knee caps, broad feet.
	for side in [-1.0, 1.0]:
		var leg := MeshKit.pivot(_hips, "Leg", Vector3(side * 0.11 * h, -0.02 * h, 0))
		MeshKit.part(leg, MeshKit.capsule(), stone, Vector3(0, -0.11 * h, 0), Vector3(0.15, 0.24, 0.15) * h)
		MeshKit.part(leg, MeshKit.sphere(), moss, Vector3(0, -0.22 * h, 0.04 * h), Vector3(0.12, 0.1, 0.1) * h)
		MeshKit.part(leg, MeshKit.capsule(), stone, Vector3(0, -0.32 * h, 0), Vector3(0.14, 0.2, 0.14) * h)
		MeshKit.part(leg, MeshKit.cylinder(), jade, Vector3(0, -0.3 * h, 0), Vector3(0.145, 0.012, 0.145) * h)
		MeshKit.part(leg, MeshKit.box(), dark, Vector3(0, -0.42 * h, 0.04 * h), Vector3(0.17, 0.06, 0.24) * h)
		_legs.append(leg)
	# The torso: a broad chest over a narrower waist, leaning a little forward.
	_torso = MeshKit.pivot(_hips, "Torso", Vector3(0, 0.06 * h, 0))
	MeshKit.part(_torso, MeshKit.sphere(), stone, Vector3(0, 0.1 * h, 0), Vector3(0.3, 0.2, 0.22) * h)
	MeshKit.part(_torso, MeshKit.sphere(), stone, Vector3(0, 0.25 * h, 0.01 * h), Vector3(0.46, 0.28, 0.3) * h)
	MeshKit.part(_torso, MeshKit.sphere(), moss, Vector3(0, 0.36 * h, -0.05 * h), Vector3(0.4, 0.12, 0.24) * h)
	# Jade veins across the chest and the heart crystal in its socket of gold.
	for i in 3:
		var y := (0.17 + 0.05 * float(i)) * h
		MeshKit.part(_torso, MeshKit.box(), jade, Vector3(0, y, 0.15 * h), Vector3(0.26 - 0.05 * float(i), 0.012, 0.02) * h, Vector3(0, 0, (-1.0 if i % 2 == 0 else 1.0) * 8.0))
	MeshKit.part(_torso, MeshKit.torus(), gold, Vector3(0, 0.27 * h, 0.155 * h), Vector3(0.13, 0.13, 0.13) * h, Vector3(90, 0, 0))
	_core = MeshKit.part(_torso, MeshKit.sphere(), glow, Vector3(0, 0.27 * h, 0.16 * h), Vector3(0.09, 0.11, 0.06) * h, Vector3.ZERO, "HeartCrystal")
	# Shoulders: great boulder pauldrons with gold rims and jade spikes.
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 0.27 * h, 0.33 * h, 0)
		MeshKit.part(_torso, MeshKit.sphere(), stone, at + Vector3(side * 0.02 * h, 0.03 * h, 0), Vector3(0.22, 0.17, 0.22) * h)
		MeshKit.part(_torso, MeshKit.torus(), gold, at + Vector3(side * 0.02 * h, -0.02 * h, 0), Vector3(0.2, 0.12, 0.2) * h)
		for k in 2:
			MeshKit.part(_torso, MeshKit.cone(), jade, at + Vector3(side * (0.05 + 0.05 * float(k)) * h, 0.12 * h, (0.04 - 0.08 * float(k)) * h), Vector3(0.05, 0.12, 0.05) * h, Vector3(0, 0, -side * 25.0))
		var arm := MeshKit.pivot(_torso, "Arm", at + Vector3(side * 0.05 * h, -0.02 * h, 0))
		MeshKit.part(arm, MeshKit.capsule(), stone, Vector3(side * 0.02 * h, -0.12 * h, 0), Vector3(0.13, 0.24, 0.13) * h)
		var fore := MeshKit.pivot(arm, "Forearm", Vector3(side * 0.03 * h, -0.24 * h, 0))
		MeshKit.part(fore, MeshKit.capsule(), stone, Vector3(0, -0.1 * h, 0.01 * h), Vector3(0.15, 0.22, 0.15) * h)
		MeshKit.part(fore, MeshKit.cylinder(), gold, Vector3(0, -0.12 * h, 0.01 * h), Vector3(0.16, 0.03, 0.16) * h)
		MeshKit.part(fore, MeshKit.cylinder(), jade, Vector3(0, -0.06 * h, 0.01 * h), Vector3(0.155, 0.012, 0.155) * h)
		# The boulder fist with knuckle stones.
		MeshKit.part(fore, MeshKit.sphere(), dark, Vector3(0, -0.25 * h, 0.02 * h), Vector3(0.19, 0.17, 0.19) * h)
		for k in 3:
			MeshKit.part(fore, MeshKit.sphere(), stone, Vector3((float(k) - 1.0) * 0.05 * h, -0.27 * h, 0.1 * h), Vector3(0.06, 0.06, 0.06) * h)
		_arms.append(arm)
		_forearms.append(fore)
	# The head: small and heavy-browed, glowing eyes, a crown of jade horns.
	_head = MeshKit.pivot(_torso, "Head", Vector3(0, 0.43 * h, 0.04 * h))
	MeshKit.part(_head, MeshKit.sphere(), stone, Vector3(0, 0.05 * h, 0), Vector3(0.15, 0.15, 0.15) * h)
	MeshKit.part(_head, MeshKit.box(), dark, Vector3(0, 0.0, 0.05 * h), Vector3(0.13, 0.06, 0.08) * h)
	MeshKit.part(_head, MeshKit.box(), dark, Vector3(0, 0.085 * h, 0.06 * h), Vector3(0.15, 0.025, 0.05) * h)
	for side in [-1.0, 1.0]:
		MeshKit.part(_head, MeshKit.sphere(), glow, Vector3(side * 0.035 * h, 0.06 * h, 0.072 * h), Vector3(0.03, 0.018, 0.012) * h)
		MeshKit.part(_head, MeshKit.cone(), jade, Vector3(side * 0.07 * h, 0.13 * h, -0.01 * h), Vector3(0.035, 0.14, 0.035) * h, Vector3(-10, 0, -side * 35.0))
	MeshKit.part(_head, MeshKit.torus(), gold, Vector3(0, 0.12 * h, 0), Vector3(0.12, 0.08, 0.12) * h)
	for k in 5:
		var a := (float(k) - 2.0) * 0.45
		MeshKit.part(_head, MeshKit.prism(), gold, Vector3(sin(a) * 0.06 * h, 0.16 * h, cos(a) * 0.06 * h), Vector3(0.025, 0.06 - 0.008 * absf(float(k) - 2.0), 0.02) * h)
	# The rune ring behind its shoulders and three shards of rock turning round it.
	_ring = MeshKit.pivot(_torso, "RuneRing", Vector3(0, 0.33 * h, -0.2 * h))
	MeshKit.part(_ring, MeshKit.torus(), jade, Vector3.ZERO, Vector3(0.42, 0.42, 0.42) * h, Vector3(90, 0, 0))
	MeshKit.part(_ring, MeshKit.torus(), gold, Vector3.ZERO, Vector3(0.34, 0.34, 0.34) * h, Vector3(90, 0, 0))
	for k in 6:
		var a := TAU * float(k) / 6.0
		MeshKit.part(_ring, MeshKit.prism(), glow, Vector3(cos(a), sin(a), 0) * 0.19 * h, Vector3(0.025, 0.05, 0.01) * h, Vector3(0, 0, rad_to_deg(a) - 90.0))
	_shards = MeshKit.pivot(self, "Shards", Vector3(0, 0.55 * h, 0))
	for k in 3:
		var a := TAU * float(k) / 3.0
		var shard := MeshKit.part(_shards, MeshKit.prism(), stone, Vector3(cos(a), 0.0, sin(a)) * 0.42 * h, Vector3(0.07, 0.13, 0.07) * h, Vector3(20, rad_to_deg(a), 15))
		MeshKit.part(shard, MeshKit.prism(), jade, Vector3(0, 0.3, 0), Vector3(0.5, 0.5, 0.5))
	set_process(true)


func play(key: String, _speed := 1.0) -> void:
	if _held or Time.get_ticks_msec() < busy_until:
		return
	current = key


func action(key: String, lock_ms := 450, _speed := 1.0) -> void:
	if _held:
		return
	busy_until = Time.get_ticks_msec() + lock_ms
	current = key
	_act = key
	_act_t = 0.0
	_act_len = maxf(float(lock_ms) / 1000.0, 0.3)


func hold(key: String) -> void:
	_held = true
	current = key
	_act = key
	_act_t = 0.0
	_act_len = 1.0


## A hit shows as a jolt of the heart crystal and the body (the spirit glow stays on).
func flash(_color := Color(1, 1, 1), _duration := 0.16) -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	if _body == null:
		return
	_phase += delta
	_pulse = maxf(0.0, _pulse - delta * 4.0)
	var moving := current == "walk" or current == "run"
	_stride += delta * (5.2 if current == "run" else 3.4) if moving else 0.0
	var swing := sin(_stride) if moving else 0.0
	var breathe := sin(_phase * 1.6)
	# Rest pose, then the stride on top.
	var leg_a := deg_to_rad(26.0) * swing
	_legs[0].rotation.x = leg_a
	_legs[1].rotation.x = -leg_a
	var arm_rest := deg_to_rad(8.0)
	_arms[0].rotation = Vector3(-leg_a * 0.7, 0, -arm_rest)
	_arms[1].rotation = Vector3(leg_a * 0.7, 0, arm_rest)
	_forearms[0].rotation.x = deg_to_rad(-14.0)
	_forearms[1].rotation.x = deg_to_rad(-14.0)
	_hips.position.y = 0.44 * _h + (absf(swing) * -0.025 * _h if moving else breathe * 0.006 * _h)
	_torso.rotation = Vector3(deg_to_rad(6.0 if moving else 3.0), sin(_stride) * 0.06 if moving else 0.0, 0)
	_torso.scale = Vector3.ONE * (1.0 + breathe * 0.012 + _pulse * 0.04)
	_head.rotation.x = deg_to_rad(-4.0) + breathe * 0.02
	_body.rotation = Vector3.ZERO
	_body.position = Vector3.ZERO
	if _act != "":
		_act_t += delta
		_play_act()
		if _act_t >= _act_len and not _held:
			_act = ""
	_ring.rotation.z += delta * 0.6
	_shards.rotation.y += delta * 0.9
	_shards.position.y = 0.55 * _h + sin(_phase * 1.3) * 0.04 * _h
	if _core:
		var s := 1.0 + 0.12 * sin(_phase * 3.0) + 0.5 * _pulse
		_core.scale = Vector3(0.09, 0.11, 0.06) * _h * s


## The one-shot clips: the two-fisted slam, the hurt rock, the fall.
func _play_act() -> void:
	var t := _act_t
	match _act:
		"attack":
			# Up over 0.3 s, crash down by 0.45 s, hold, then back by the end.
			var up := smoothstep(0.0, 0.3, t)
			var down := smoothstep(0.32, 0.45, t)
			var back := smoothstep(0.6, maxf(_act_len, 0.7), t)
			var raise := deg_to_rad(-165.0) * up * (1.0 - down) + deg_to_rad(-40.0) * down * (1.0 - back)
			for arm in _arms:
				arm.rotation.x = raise
				arm.rotation.z *= 0.4
			for fore in _forearms:
				fore.rotation.x = deg_to_rad(-30.0) * up * (1.0 - down)
			_torso.rotation.x = deg_to_rad(-12.0) * up * (1.0 - down) + deg_to_rad(22.0) * down * (1.0 - back)
			_hips.position.y -= 0.04 * _h * down * (1.0 - back)
		"hurt":
			var k := sin(clampf(t / maxf(_act_len, 0.01), 0.0, 1.0) * PI)
			_torso.rotation.x -= deg_to_rad(10.0) * k
		"die":
			var k := smoothstep(0.0, 1.0, t)
			_body.rotation.x = deg_to_rad(-70.0) * k
			_body.position.y = -0.25 * _h * k
