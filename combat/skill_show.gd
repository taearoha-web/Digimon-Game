class_name SkillShow
extends RefCounted
## The spectacle layered on top of a skill's normal effect. Everything is
## chosen by the skill's element ("style", from its vfx preset) and its shape,
## so every skill (class, job and master) gets a fitting show: rune circles,
## ice spikes, columns of light, fire rings, whirlwinds, X-slashes, motes...
## Used by the hero and by AI companions.

const BIG_IDS := ["bone_crash", "destroyer", "diastrophism", "flame_wave", "extinction", "glacial_spike", "phoenix_shot", "bomb_shot", "resurrection", "rage_of_zecram"]

static var _stopped := false


static func style_of(skill: Dictionary) -> String:
	match String(skill.get("vfx", &"impact")):
		"fireball": return "fire"
		"frost": return "ice"
		"light": return "holy"
		"heal": return "heal"
		"thunder": return "thunder"
		"wind": return "wind"
		"leaf": return "leaf"
		"aura": return "buff"
		_: return "phys"


## center: where the skill lands; origin: the caster's feet; camera: optional.
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, camera: ThirdPersonCamera = null) -> void:
	var color: Color = skill.color
	var style := style_of(skill)
	var shape := String(skill.shape)
	var radius := float(skill.get("radius", 3.0))
	var mult := float(skill.get("mult", 0.0))
	var fx: Dictionary = skill.get("fx", {})
	var big: bool = mult >= 4.0 or String(skill.id) in BIG_IDS or (shape == "self" and float(fx.get("buff", {}).get("atk", 0.0)) >= 0.3)
	match shape:
		"self", "summon": _self_cast(parent, skill, style, color, origin)
		"burst": _burst(parent, skill, style, color, origin, radius, big)
		"blast": _blast(parent, skill, style, color, center, radius, big)
		"single": _single(parent, skill, style, color, center, origin, big)
		_: _multi(parent, skill, style, color, center, origin)
	var grand := _grandeur(parent, skill, color, shape, center, origin, radius, camera)
	if big or grand >= 3:
		if camera:
			camera.punch(5.5 + 1.5 * float(maxi(grand - 2, 0)))
			Game.screen_flash.emit(color, 0.22 + 0.05 * float(maxi(grand - 2, 0)))
			hit_stop(parent, 0.06 + 0.02 * float(maxi(grand - 2, 0)))


## Higher-level skills put on a bigger show on top of their normal effect: every
## 20 skill levels add another rune circle, then sky strikes, shockwaves and
## raining light, a spiral and pillar of light (Lv.80+) and a delayed second
## wave for the Lv.100 ultimates. Returns the grandeur step 0-5.
static func _grandeur(parent: Node3D, skill: Dictionary, color: Color, shape: String, center: Vector3, origin: Vector3, radius: float, camera: ThirdPersonCamera) -> int:
	var step := clampi(int(skill.get("level", 1)) / 20, 0, 5)
	if step <= 0:
		return 0
	var scale := GameSettings.particle_scale()
	var at := origin if shape in ["self", "summon", "burst"] else center
	var r := maxf(radius, 2.6)
	for i in step:
		VfxArt.rune_circle(parent, at, color.lerp(Color.WHITE, 0.2 * float(i)), r * (1.1 + 0.3 * float(i)), 1.0 + 0.2 * float(i), 1.0 if i % 2 == 0 else -1.0)
	if step >= 2:
		var strikes := int((3 + step * 2) * scale)
		for i in strikes:
			var a := TAU * float(i) / float(maxi(strikes, 1)) + randf() * 0.4
			var spot := at + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.55, 0.95)
			VfxArt.sky_strike(parent, spot, color.lerp(Color.WHITE, 0.3), 0.5 + 0.12 * float(step), 12.0 + 2.0 * float(step), 0.12 * float(i % 4))
	if step >= 3:
		VfxKit.shockwave(parent, at + Vector3(0, 0.12, 0), color, r * 1.4)
		VfxKit.column_rain(parent, at, r, color, int((8 + step * 3) * scale), 0.9, 12.0)
	if step >= 4:
		VfxArt.ribbon_spiral(parent, at, color, r * 0.7, 6.0, 1.4)
		VfxKit.pillar(parent, at, color.lerp(Color.WHITE, 0.4), 16.0, 1.6, 1.2)
		VfxKit.vortex(parent, at, Color.WHITE, r * 0.8, 0.9)
	if step >= 5:
		# The Lv.100 ultimate: a second, bigger wave a moment later.
		parent.get_tree().create_timer(0.35).timeout.connect(func():
			if not is_instance_valid(parent):
				return
			VfxKit.shockwave(parent, at + Vector3(0, 0.12, 0), Color.WHITE, r * 1.9)
			VfxArt.star_flash(parent, at + Vector3(0, 1.4, 0), Color.WHITE, 7.0)
			VfxArt.rune_circle(parent, at, Color.WHITE, r * 1.8, 1.3, -1.0)
			for i in int(10.0 * scale):
				var a := randf() * TAU
				VfxArt.sky_strike(parent, at + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.2, 1.1), color, 1.0, 18.0, 0.05 * i)
			if camera:
				camera.punch(9.0), CONNECT_ONE_SHOT)
	return step


static func hit_stop(node: Node, seconds: float) -> void:
	if _stopped or node.get_tree().paused:
		return
	_stopped = true
	Engine.time_scale = 0.12
	node.get_tree().create_timer(seconds, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
		_stopped = false)


static func _motes_for(parent: Node3D, style: String, color: Color, pos: Vector3, radius: float, count := 26) -> void:
	match style:
		"fire": VfxArt.motes(parent, pos, Color("ff9a3a"), "ember", count, radius, 0.3)
		"ice": VfxArt.motes(parent, pos, Color("e6f8ff"), "snow", count, radius, 0.0)
		"holy": VfxArt.motes(parent, pos, Color("fff0a0"), "light", count, radius, 0.4)
		"heal": VfxArt.motes(parent, pos, Color("9affb8"), "petal", count, radius, 0.3)
		"wind", "leaf": VfxArt.motes(parent, pos, Color("8affb0") if style == "leaf" else color, "leaf", count, radius, 0.5)
		"thunder": VfxArt.motes(parent, pos, Color("fff06a"), "ember", count, radius, 0.3)
		"buff": VfxArt.motes(parent, pos, color, "light", count, radius, 0.3)
		_: VfxArt.motes(parent, pos, color.lerp(Color("c8a878"), 0.4), "ember", count, radius, 0.1)


static func _self_cast(parent: Node3D, skill: Dictionary, style: String, color: Color, origin: Vector3) -> void:
	VfxArt.rune_circle(parent, origin, color, 3.0, 1.0)
	VfxArt.ribbon_spiral(parent, origin, color, 3.4, 2.5, 1.0)
	VfxKit.shockwave(parent, origin + Vector3(0, 0.12, 0), color, 3.6)
	_motes_for(parent, style if style != "phys" else "buff", color, origin + Vector3(0, 0.3, 0), 1.4, 22)
	if style == "heal":
		VfxKit.vortex(parent, origin, Color("6dff9a"), 3.4, 0.9)
	else:
		VfxKit.pillar(parent, origin, color, 8.0, 1.1, 0.8)
		VfxKit.vortex(parent, origin, color, 3.6, 0.9)


static func _burst(parent: Node3D, skill: Dictionary, style: String, color: Color, origin: Vector3, radius: float, big: bool) -> void:
	VfxArt.rune_circle(parent, origin, color, radius, 0.9, -1.0)
	VfxKit.shockwave(parent, origin + Vector3(0, 0.12, 0), color, radius * 1.15)
	VfxKit.get_ring_delay(parent, origin, Color.WHITE, radius * 0.7, 0.1)
	_motes_for(parent, style, color, origin, radius * 0.7, 30)
	match style:
		"fire":
			VfxKit.fire_ring(parent, origin, Color("ff6a2a"), radius * 0.85, 24, 1.4)
		"ice":
			VfxKit.spikes(parent, origin, radius, Color("a8ecff"), 20, 2.6, 0.3)
		"holy":
			VfxKit.column_rain(parent, origin, radius, color, 10, 0.5, 9.0)
			VfxKit.get_ring_delay(parent, origin, color, radius * 0.5, 0.22)
		"wind", "leaf":
			VfxKit.vortex(parent, origin, color, 3.2, 0.8)
			VfxKit.vortex(parent, origin + Vector3(0, 0.6, 0), Color.WHITE, 2.4, 0.7)
		"thunder":
			for i in 5:
				var a := randf() * TAU
				var spot := origin + Vector3(cos(a), 0, sin(a)) * radius * 0.8
				VfxArt.sky_strike(parent, spot, Color("fff06a"), 0.7, 12.0, 0.3)
		_:
			VfxKit.slam(parent, origin, color, radius)
			if big:
				VfxKit.spikes(parent, origin, radius, Color("a8784a"), 16, 2.0)


static func _blast(parent: Node3D, skill: Dictionary, style: String, color: Color, center: Vector3, radius: float, big: bool) -> void:
	VfxArt.rune_circle(parent, center, color, radius, 1.0)
	_motes_for(parent, style, color, center, radius * 0.8, 34)
	match style:
		"fire":
			VfxKit.fire_ring(parent, center, Color("ff6a2a"), radius, 22, 1.6)
			if big:
				VfxKit.slam(parent, center, color, radius)
		"ice":
			VfxKit.spikes(parent, center, radius, Color("a8ecff"), 22, 2.8, 0.5)
			VfxKit.column_rain(parent, center, radius, Color("e6f8ff"), 14, 1.0, 10.0)
		"holy":
			VfxKit.column_rain(parent, center, radius, color, 22, 1.1, 12.0)
			VfxArt.sky_strike(parent, center, color, 1.8, 16.0, 0.6)
		"leaf", "wind":
			VfxKit.column_rain(parent, center, radius, color, 12, 0.7, 12.0)
			VfxKit.vortex(parent, center, color, 2.6, 0.7)
		"thunder":
			for i in 6:
				var a := randf() * TAU
				VfxArt.sky_strike(parent, center + Vector3(cos(a), 0, sin(a)) * radius * randf(), Color("fff06a"), 0.7, 14.0, 0.3)
		_:
			VfxKit.slam(parent, center, color, radius)
			VfxKit.spikes(parent, center, radius, Color("a8784a"), 14, 2.0)


static func _single(parent: Node3D, skill: Dictionary, style: String, color: Color, center: Vector3, origin: Vector3, big: bool) -> void:
	var hit := center + Vector3(0, 1.0, 0)
	_motes_for(parent, style, color, hit, 0.9, 16)
	match style:
		"holy":
			VfxArt.sky_strike(parent, center, color, 1.2 if big else 0.8, 14.0, 0.5)
		"ice":
			VfxKit.spikes(parent, center, 1.4, Color("a8ecff"), 7, 2.0, 0.1)
			VfxArt.star_flash(parent, hit, Color("dff8ff"), 2.6)
		"fire":
			VfxKit.fire_ring(parent, center, Color("ff6a2a"), 1.6, 9, 1.0)
			VfxArt.star_flash(parent, hit, color, 2.8)
		"thunder":
			VfxArt.sky_strike(parent, center, Color("fff06a"), 0.8, 14.0, 0.3)
		"leaf", "wind":
			VfxArt.star_flash(parent, hit, color, 2.4)
			VfxKit.vortex(parent, center, color, 1.8, 0.5)
		"buff", "heal":
			VfxArt.star_flash(parent, hit, color, 2.4)
		_:
			var to := center - origin
			var yaw := atan2(to.x, to.z) if to.length() > 0.1 else 0.0
			VfxArt.cross_slash(parent, origin + to.normalized() * minf(1.4, to.length()) + Vector3(0, 1.1, 0), yaw, color, 4.8 if big else 4.0)
			VfxArt.star_flash(parent, hit, color, 4.2 if big else 3.4)
			if big:
				VfxKit.slam(parent, center, color, 2.4)


static func _multi(parent: Node3D, skill: Dictionary, style: String, color: Color, center: Vector3, origin: Vector3) -> void:
	VfxKit.vortex(parent, origin, color, 2.4, 0.5)
	VfxArt.rune_circle(parent, origin, color, 1.8, 0.6)
	_motes_for(parent, style, color, origin + Vector3(0, 0.6, 0), 1.0, 18)
	VfxArt.star_flash(parent, center + Vector3(0, 1.0, 0), color, 2.2)
