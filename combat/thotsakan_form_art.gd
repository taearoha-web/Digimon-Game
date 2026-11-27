class_name ThotsakanFormArt
extends Node3D
## The art of ThotsakanForm (★300 สิบเศียรสิบกรสะท้านสามภพ): the fighter BECOMES ทศกัณฐ์.
## Drawn with RamakienArt's engine and RamakienSculpt's figures (the ten-headed bust, its
## eighteen halo arms, the spirit fist), cosmetic only (ThotsakanForm owns every hit):
##   wind-up     a jade-and-gold ยันต์ seal opens under the fighter, mantra script and
##               jade embers swirl up round it into a column of light, the field dims; the
##               aureole of flame tongues gathers where the ten heads will stand
##               (StarGodGround always, StarGodSky without memory pressure)
##   the form    this node: a mantle standing on the fighter's far side from the camera and
##               turned to it, so the spirit is seen from any view: the emerald bust of
##               ทศกัณฐ์ rising out of mist behind the grown fighter, its main face over
##               the fighter's head and its crown of faces above, the eighteen arms fanned
##               round its shoulders, the aureole behind; a turning seal and embers at the
##               fighter's feet; an emerald sheen on the fighter's own body
##   a punch     the halo arms lunge (alternating sides); a spirit fist with a trail of
##               light snaps from the halo at each foe in reach and bursts on it in a flash
##               and a flame wisp; a gold shock ring rolls out to the reach of the punch
##   finisher    the arms gather a god fist over the crown; it hammers down before the
##               fighter: flash, three rings of the three realms, temple-glass cracks
##               (กระจกสี), dust, stun stars and flame on every foe struck
## Every layer is a VfxBudget decoration on a RamakienArt root (its quality / memory
## layer cap and core / mid / debris tiers); the spirit bust and arms are dropped under
## memory pressure (GodSkillArt.extra_roots), the extra finisher roots at low quality.

const ID := "three_realms_fist"
## The spirit's height (m, before the camera fit), how far behind the fighter it stands
## and how high its waist (the model's origin) is.
const SPIRIT_H := 5.6
const BEHIND := 1.6
const WAIST := 2.4
## And a little to the side on the screen, so a camera right behind the fighter sees
## the spirit's face past the fighter's head.
const ASIDE := 0.9
## The emerald sheen on the fighter's body (an additive fresnel overlay).
const SHEEN_CODE := "shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec4 rim : source_color = vec4(0.12, 0.95, 0.58, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.78, 0.3, 1.0);
uniform float strength = 0.0;
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = rim.rgb * (0.12 + 0.8 * pow(f, 2.2)) + edge.rgb * 0.7 * pow(f, 6.0);
	ALBEDO = c * strength;
}
"
static var _sheen_shader: Shader

var form_ref: WeakRef
## The spirit (pivot-local) and the ground under the fighter.
var spirit: RamakienArt
var ground: RamakienArt
var spirit_h := SPIRIT_H
var _arms: Dictionary = {}
var _arms_angles := Vector3.ZERO
var _arms_size := Vector3.ONE
var _spirit_layers: Array = []
var _swing_at := -10.0
var _swing_side := 1.0
var _swing_big := false
## The punches' roots still playing (the finisher clears them to make room for itself).
var _punch_roots: Array = []
var _age := 0.0
var _away := Vector3.BACK
var _sheen: ShaderMaterial
var _sheened: Dictionary = {}
var _closed := false


# ---------------------------------------------------------------------------
# The wind-up (StarSkillSequence: GodSkillArt.telegraph via combat/god_art)
# ---------------------------------------------------------------------------

static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, _point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D if art else null
	if not SculptureArt._alive(parent) or not is_instance_valid(caster):
		return false
	var origin := caster.global_position * Vector3(1, 0, 1)
	var radius := float(skill.get("radius", 9.0)) * ThotsakanForm.PUNCH_RADIUS / ThotsakanForm.BASE_RADIUS
	var g := RamakienArt._open(parent, origin, "StarGodGround_" + ID, ID)
	var mid := NaturalArt.TIER_MID
	var debris := NaturalArt.TIER_DEBRIS
	# The seal opens under the fighter and spreads to the reach of the punches to come.
	g.layer("yant", false, MuayThaiArt._lace(MuayThaiArt.JADE), Vector3.UP * 0.04, Vector3.ONE * 2.4, Vector3.ZERO, 0.0, time + 0.3, {"initial": 0.25, "grow": 1.6, "spin": 0.9, "fade_in": 0.18, "decay": 0.84, "opacity": 0.95})
	g.layer("yant", false, MuayThaiArt._lace(MuayThaiArt.GOLD), Vector3.UP * 0.045, Vector3.ONE * radius * 0.95, Vector3.ZERO, 0.1, time + 0.2, {"initial": 0.2, "grow": 1.4, "spin": -0.4, "fade_in": 0.22, "decay": 0.82, "opacity": 0.55, "tier": mid})
	g.layer("script", true, MuayThaiArt.GOLD, Vector3.UP * 0.2, Vector3(1.3, 1.4, 1.3), Vector3.ZERO, 0.05, time, {"initial": 0.5, "grow": 2.0, "spin": -2.4, "travel": Vector3(0, 2.6, 0), "fade_in": 0.2, "decay": 0.7, "opacity": 0.8, "tier": mid})
	g._light("embers", 5, RamakienArt.L_JADE, RamakienArt.L_WHITE, Vector3.UP * 0.2, Vector3(2.6, 3.8, 2.6), 0.0, time + 0.2, {"initial": 0.6, "grow": 3.0, "fade_in": 0.1, "decay": 0.8, "tier": mid}, {}, Vector3.ZERO)
	g._light("disc", 0, RamakienArt.L_JADE, RamakienArt.L_GOLD, Vector3.UP * 0.06, Vector3.ONE * 3.2, 0.0, time + 0.25, {"initial": 0.3, "grow": 2.0, "fade_in": 0.2, "decay": 0.8, "opacity": 0.7})
	# The release: the fighter bursts into the demon king (a flash and a shock ring).
	g._light("quad", 10, RamakienArt.L_JADE, RamakienArt.L_WHITE, Vector3.UP * 1.6, Vector3.ONE * 5.0, time - 0.04, 0.4, {"initial": 0.3, "grow": 9.0, "billboard": true, "decay": 0.4, "priority": 4})
	g.layer("shock", true, MuayThaiArt.JADE, Vector3.UP * 0.07, Vector3.ONE * radius, Vector3.ZERO, time, 0.55, {"initial": 0.1, "grow": 4.5, "decay": 0.5, "opacity": 0.5, "tier": mid})
	g.layer("smoke", true, MuayThaiArt.DUST, Vector3.UP * 0.1, Vector3.ONE * 2.6, Vector3.ZERO, time, 0.9, {"initial": 0.3, "grow": 3.0, "travel": Vector3(0, 1.0, 0), "face_camera": true, "decay": 0.55, "opacity": 0.4, "tier": debris})
	# The sky (no memory pressure): a column of jade light and the aureole gathering where
	# the ten heads will stand, under a short dusk.
	if GodSkillArt.extra_roots(1) >= 1:
		var sky := RamakienArt._open(parent, origin, "StarGodSky_" + ID, ID)
		sky._veil(time + 0.5, 0.4)
		sky._light("shaft", 4, RamakienArt.L_JADE, RamakienArt.L_WHITE, Vector3.ZERO, Vector3(2.4, 9.0, 1.0), 0.15, time + 0.15, {"initial": 0.4, "grow": 2.5, "face_camera": true, "fade_in": 0.3, "decay": 0.75, "opacity": 0.75})
		sky._light("quad", 1, RamakienArt.L_GOLD, RamakienArt.L_WHITE, Vector3.UP * 4.6, Vector3.ONE * 3.6, 0.3, time + 0.1, {"initial": 0.2, "grow": 2.0, "billboard": true, "fade_in": 0.3, "decay": 0.8, "opacity": 0.9, "priority": RamakienArt.PRI_HALO, "tier": mid})
	return true


# ---------------------------------------------------------------------------
# The form's mantle
# ---------------------------------------------------------------------------

## Puts the mantle on [param body] for [param form].
static func mantle(body: Node3D, form: ThotsakanForm) -> ThotsakanFormArt:
	if not SculptureArt._alive(body):
		return null
	var art := ThotsakanFormArt.new()
	art.name = "ThotsakanMantle"
	art.form_ref = weakref(form)
	body.add_child(art)
	art.top_level = true
	art._build(body, form)
	return art


func _build(body: Node3D, form: ThotsakanForm) -> void:
	var stay := ThotsakanForm.SECS + ThotsakanForm.FINISH_WINDUP + ThotsakanForm.SHRINK + 0.3
	var origin := body.global_position
	_away = RamakienArt._view(self, origin, Vector3.BACK)[0]
	global_position = origin
	# The ground under the fighter's feet: a turning jade seal at the reach of the
	# punches, soft jade light and embers rising round the body.
	ground = RamakienArt.new()
	ground.name = "ThotsakanGround"
	ground.cap = RamakienArt.layer_cap()
	body.add_child(ground)
	ground.position = Vector3.ZERO
	var reach := form.radius
	ground.layer("yant", false, MuayThaiArt._lace(MuayThaiArt.JADE), Vector3.UP * 0.05, Vector3.ONE * 2.2, Vector3.ZERO, 0.0, stay, {"initial": 1.0, "spin": 0.6, "fade_in": 0.03, "decay": 0.95, "opacity": 0.85})
	ground._light("disc", 0, RamakienArt.L_JADE, RamakienArt.L_GOLD, Vector3.UP * 0.06, Vector3.ONE * reach * 0.9, 0.0, stay, {"initial": 1.0, "fade_in": 0.03, "decay": 0.95, "opacity": 0.32})
	ground.layer("yant", false, MuayThaiArt._lace(MuayThaiArt.GOLD), Vector3.UP * 0.055, Vector3.ONE * reach * 1.05, Vector3.ZERO, 0.0, stay, {"initial": 1.0, "spin": -0.25, "fade_in": 0.04, "decay": 0.95, "opacity": 0.13, "tier": NaturalArt.TIER_MID})
	ground._light("embers", 5, RamakienArt.L_JADE, RamakienArt.L_GOLD, Vector3.UP * 0.3, Vector3(2.2, 4.6, 2.2), 0.0, stay, {"initial": 1.0, "fade_in": 0.04, "decay": 0.92, "tier": NaturalArt.TIER_MID}, {}, Vector3.ZERO)
	# The emerald sheen on the fighter's own body.
	_wear_sheen(ThotsakanForm.visual_of(body))
	# The spirit (no memory pressure): the ten-headed bust, the arms, the aureole.
	if GodSkillArt.extra_roots(1) < 1:
		return
	spirit_h = clampf(RamakienArt.fit_height(self, origin + _away * BEHIND, SPIRIT_H + WAIST, 0.6, 0.02) - WAIST, 4.6, SPIRIT_H)
	var h := spirit_h
	spirit = RamakienArt.new()
	spirit.name = "ThotsakanSpirit"
	spirit.cap = RamakienArt.layer_cap()
	add_child(spirit)
	var look := RamakienArt.YAK_LOOK
	var body_style := {"initial": 1.0, "fade_in": 0.04, "decay": 0.95, "opacity": 0.9, "priority": RamakienArt.PRI_BODY}
	var before := spirit.layers.size()
	spirit._sculpt("thotsakan", look, Vector3.ZERO, Vector3.ONE * h, Vector3.ZERO, 0.0, stay, body_style, {"manifest": 0.5, "mist_lo": 0.06, "mist_hi": 0.24, "skin_alpha": 0.62, "rim_power": 1.4})
	if spirit.layers.size() > before:
		_spirit_layers.append(spirit.layers[before])
	before = spirit.layers.size()
	spirit._sculpt("thotsakan_arms", look, RamakienSculpt.ARM_PIVOT * h, Vector3.ONE * h, Vector3.ZERO, 0.12, stay - 0.12, {"initial": 0.3, "grow": 30.0, "overshoot": true, "fade_in": 0.03, "decay": 0.95, "opacity": 0.92, "priority": RamakienArt.PRI_ARMS}, {"mist_lo": -0.1, "mist_hi": 0.02, "skin_alpha": 0.7, "rim_power": 1.5})
	if spirit.layers.size() > before:
		_arms = spirit.layers[before]
		_arms_angles = _arms.angles
		_arms_size = _arms.size
		_spirit_layers.append(_arms)
	spirit._light("quad", 1, RamakienArt.L_GOLD, RamakienArt.L_WHITE, Vector3(0, 0.6, -0.12) * h, Vector3.ONE * h * 0.95, 0.1, stay - 0.1, {"initial": 0.4, "grow": 24.0, "billboard": true, "fade_in": 0.04, "decay": 0.94, "opacity": 0.95, "priority": RamakienArt.PRI_HALO, "tier": NaturalArt.TIER_MID})
	spirit._light("bank", 9, RamakienArt.L_GOLD, Color("fff3dc"), Vector3(0, 0.08, 0.12) * h, Vector3(h * 0.62, h * 0.2, 1.0), 0.0, stay, {"initial": 0.7, "grow": 20.0, "billboard": true, "fade_in": 0.04, "decay": 0.93, "opacity": 0.85, "priority": 1, "tier": NaturalArt.TIER_MID})


## Every frame (ThotsakanForm): the mantle stands on the fighter's far side, turned to the
## camera, grown with the body; the arms swing back from the last punch.
func tick(body: Node3D, form: ThotsakanForm, delta: float) -> void:
	if _closed or not is_instance_valid(body):
		return
	_age += delta
	var k := maxf(form._grown, 0.001)
	var origin := body.global_position
	var view := RamakienArt._view(self, origin, _away)
	_away = (_away.lerp(view[0], 1.0 - exp(-3.0 * delta))).normalized()
	var right := _away.cross(Vector3.UP).normalized()
	var at := origin + (_away * BEHIND + right * ASIDE) * k + Vector3.UP * WAIST * k
	var face := -_away
	var yaw := atan2(face.x, face.z)
	global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * k), at)
	if is_instance_valid(spirit) and not _arms.is_empty():
		var t := _age - _swing_at
		var s := exp(-7.0 * t) * sin(minf(t * 14.0, PI)) if t >= 0.0 else 0.0
		if _swing_big:
			s = 1.8 * smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.5, 0.9, t))
		_arms.angles = _arms_angles + Vector3(0.32 * s, 0.0, 0.14 * s * _swing_side)
		_arms.size = _arms_size * (1.0 + 0.1 * s)
	if _sheen != null:
		_sheen.set_shader_parameter("strength", 0.55 * form._grown)


## The emerald sheen goes on every mesh of [param visual] (what each wore is kept and
## given back; a hit flash keeps and restores it like any overlay).
func _wear_sheen(visual: HeroVisual) -> void:
	if visual == null or not is_instance_valid(visual) or visual.model == null:
		return
	if _sheen_shader == null:
		_sheen_shader = Shader.new()
		_sheen_shader.code = SHEEN_CODE
	_sheen = ShaderMaterial.new()
	_sheen.shader = _sheen_shader
	_sheen.set_shader_parameter("strength", 0.0)
	for node in visual.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or not mi.visible:
			continue
		_sheened[mi] = mi.material_overlay
		mi.material_overlay = _sheen


func _take_sheen() -> void:
	for mi in _sheened:
		if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == _sheen:
			var was: Variant = _sheened[mi]
			(mi as MeshInstance3D).material_overlay = was if was is Material and is_instance_valid(was) else null
	_sheened.clear()
	_sheen = null


## The form ended: the mantle (and the seal on the body) fades out within
## MuayThaiArt.CLOSE; the roots free themselves, the mantle a moment after.
func close() -> void:
	if _closed:
		return
	_closed = true
	_closed_at = _age
	_take_sheen()
	for root in [spirit, ground]:
		if is_instance_valid(root):
			var art := root as RamakienArt
			art._closing = art.age
			art.lifetime = minf(art.lifetime, art.age + MuayThaiArt.CLOSE)


var _closed_at := 0.0


func _process(delta: float) -> void:
	if not _closed:
		return
	_age += delta
	if _age - _closed_at > MuayThaiArt.CLOSE + 0.1:
		queue_free()


func _exit_tree() -> void:
	_take_sheen()


# ---------------------------------------------------------------------------
# A punch and the finisher (field roots, world space)
# ---------------------------------------------------------------------------

## A point of the spirit (model units x its height) in the world.
func spirit_point(p: Vector3) -> Vector3:
	return global_transform * (p * spirit_h)


func punch(body: Node3D, form: ThotsakanForm, victims: Array, swing: int) -> void:
	if _closed or not is_instance_valid(body):
		return
	_swing_at = _age
	_swing_big = false
	_swing_side = 1.0 if swing % 2 == 0 else -1.0
	var parent := body.get_parent() as Node3D
	if not SculptureArt._alive(parent):
		return
	var origin := body.global_position * Vector3(1, 0, 1)
	var root := _field_root(parent, origin, "ThotsakanPunch")
	_punch_roots = _punch_roots.filter(func(r): return is_instance_valid((r as WeakRef).get_ref()))
	_punch_roots.append(weakref(root))
	var targets: Array = []
	for v in victims:
		if is_instance_valid(v):
			targets.append((v as Node3D).global_position * Vector3(1, 0, 1) + Vector3.UP * 1.0)
	var cosmetic := targets.is_empty()
	if cosmetic:
		# Nobody in reach (or another player's body): the fists strike the ground before it.
		var facing := Vector3(sin(body.rotation.y), 0, cos(body.rotation.y))
		var visual := ThotsakanForm.visual_of(body)
		if visual != null:
			facing = Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
		targets.append(origin + facing * 2.2 + facing.cross(Vector3.UP) * 0.8 + Vector3.UP * 0.4)
	var snap := 0.12
	var n := mini(targets.size(), [1, 2, 4][NaturalArt.depth()])
	# The first fists and their bursts first (a tight cap keeps one whole blow).
	for k in n:
		var to: Vector3 = targets[k]
		var side := (1.0 if (k + swing) % 2 == 0 else -1.0)
		var from := spirit_point(Vector3(0.3 * side, 0.42, 0.12)) if is_instance_valid(spirit) else origin + Vector3.UP * 3.2 + _away * 0.6
		var dir := (to - from).normalized()
		var tier := NaturalArt.TIER_CORE if k < 2 else NaturalArt.TIER_MID
		root._spirit_fist(from - origin, to - origin - dir * 0.35, 0.0, snap, 1.0, 0.18, tier, dir)
		root._light("quad", 10, RamakienArt.L_GOLD if k % 2 == 0 else RamakienArt.L_JADE, RamakienArt.L_WHITE, to - origin, Vector3.ONE * 2.0, snap - 0.02, 0.28, {"initial": 0.4, "grow": 9.0, "billboard": true, "decay": 0.4, "priority": 4, "tier": tier})
	root.layer("shock", true, MuayThaiArt.GOLD, Vector3.UP * 0.06, Vector3.ONE * form.radius * 0.95, Vector3.ZERO, snap, 0.42, {"initial": 0.2, "grow": 5.5, "decay": 0.45, "opacity": 0.38, "tier": NaturalArt.TIER_MID})
	if not cosmetic:
		# Every foe struck catches fire (a flame wisp), the first ones drawn.
		for k in mini(targets.size(), NaturalArt.count(3)):
			var to: Vector3 = targets[k]
			root._light("quad", 8, RamakienArt.L_EMBER, RamakienArt.L_FLAME, to - origin + Vector3(0, -0.15, 0), Vector3(0.7, 1.05, 1.0), snap + 0.03, 0.7, {"initial": 0.3, "grow": 5.0, "billboard": true, "travel": Vector3(0, 0.3, 0), "fade_in": 0.08, "decay": 0.6, "opacity": 0.9, "priority": 4, "tier": NaturalArt.TIER_MID})
	root.layer("crack", true, MuayThaiArt.SUN, Vector3.UP * 0.04, Vector3.ONE * 1.6, Vector3(0, randf() * TAU, 0), snap, 0.6, {"initial": 0.3, "grow": 9.0, "decay": 0.6, "opacity": 0.8, "tier": NaturalArt.TIER_DEBRIS})


## The time is up: the god fist rises over the crown and hammers down on the slam
## point [param windup] seconds later.
func finisher(body: Node3D, form: ThotsakanForm, windup: float) -> void:
	if _closed or not is_instance_valid(body):
		return
	var parent := body.get_parent() as Node3D
	if not SculptureArt._alive(parent):
		return
	var slam := form.slam_point(body)
	var radius := form.finish_radius
	var fx: Dictionary = form.skill.get("fx", {})
	# The last punches' sparks give way: the god fist must have its room in the budget.
	for ref in _punch_roots:
		var old := (ref as WeakRef).get_ref() as Node
		if is_instance_valid(old) and old.get_parent() != null:
			old.get_parent().remove_child(old)
			old.queue_free()
	_punch_roots.clear()
	var hit := _field_root(parent, slam, "ThotsakanSlam")
	# The god fist: it gathers over the spirit's crown, hangs, then hammers down knuckles
	# first on a slant from the spirit's side.
	var size := 2.6
	var apex := spirit_point(Vector3(0.5, 0.66, 0.2)) if is_instance_valid(spirit) else body.global_position + Vector3.UP * 5.5
	# The halo arms rear up with it.
	_swing_at = _age
	_swing_big = true
	var knuckles := slam + Vector3.UP * (0.5 * size + 0.15)
	var aim := (knuckles - apex).normalized()
	var hang := windup - 0.12
	hit._sculpt("spirit_fist", RamakienArt.FIST_LOOK, apex - slam, Vector3.ONE * size, Vector3.ZERO, 0.0, hang + 0.02, {"initial": 0.2, "grow": 4.0, "overshoot": true, "travel": -aim * 0.4, "point": aim, "fade_in": 0.05, "decay": 0.99, "opacity": 0.92, "priority": 1}, {"rim_power": 2.0, "skin_alpha": 0.85})
	var top := apex - aim * 0.4
	var drop := {"initial": 1.0, "travel": knuckles - top, "snap": 0.12, "snap_in": true, "accelerate": true, "point": aim}
	hit._sculpt("spirit_fist", RamakienArt.FIST_LOOK, top - slam, Vector3.ONE * size, Vector3.ZERO, hang, 0.12 + 0.55, drop.merged({"decay": 0.75, "opacity": 0.92, "priority": 1}, true), {"rim_power": 2.0, "skin_alpha": 0.85})
	hit._light("trail", 7, RamakienArt.L_JADE, RamakienArt.L_WHITE, top - slam, Vector3(size * 3.0, size * 1.2, 1.0), hang, 0.26, drop.merged({"pop": 0.0, "decay": 0.4, "opacity": 0.9, "tier": NaturalArt.TIER_MID}, true))
	# The blow: a flash with rays, temple glass cracking out, the shock, dust and stars.
	hit._light("quad", 10, RamakienArt.L_GOLD, RamakienArt.L_WHITE, Vector3(0, 0.8, 0), Vector3.ONE * 6.0, windup, 0.38, {"initial": 0.3, "grow": 9.0, "billboard": true, "decay": 0.45, "priority": 4})
	hit._light("disc", 6, RamakienArt.L_GOLD, RamakienArt.L_WHITE, Vector3.UP * 0.05, Vector3.ONE * radius * 0.8, windup, 1.9, {"initial": 1.0, "fade_in": 0.01, "decay": 0.66, "opacity": 1.0}, {"spread": 0.55})
	hit.layer("shock", true, MuayThaiArt.SUN, Vector3.UP * 0.08, Vector3.ONE * radius, Vector3.ZERO, windup + 0.03, 0.6, {"initial": 0.1, "grow": 4.0, "decay": 0.5, "opacity": 0.4})
	hit._stun_stars(Vector3.UP * 0.3, windup + 0.05, float(fx.get("stun", 1.5)), 3)
	for k in NaturalArt.count(4):
		var a := float(k) * 1.7 + 0.4
		hit.layer("smoke", true, MuayThaiArt.DUST, Vector3(sin(a), 0.1, cos(a)) * 1.8, Vector3.ONE * 2.0, Vector3.ZERO, windup + 0.03 + 0.03 * float(k), 1.1, {"initial": 0.3, "grow": 3.0, "travel": Vector3(sin(a) * 1.4, 1.2, cos(a) * 1.4), "face_camera": true, "decay": 0.55, "opacity": 0.45, "tier": NaturalArt.TIER_MID if k == 0 else NaturalArt.TIER_DEBRIS})
	hit._sparks(MuayThaiArt.SUN, Vector3(0, 0.6, 0), 8, windup + 0.02, 1.8)
	# The realms (no memory pressure): rings of heaven, earth and the underworld, flame on
	# every foe struck, a short dusk.
	if GodSkillArt.extra_roots(1) >= 1:
		var avatar := _field_root(parent, slam, "StarGodAvatar_" + ID)
		avatar._veil(windup + 1.0, 0.35)
		var realms := [[MuayThaiArt.GOLD, 0.09, 0.55], [MuayThaiArt.JADE, 0.1, 0.8], [MuayThaiArt.CLOTH, 0.11, 1.05]]
		for k in 3:
			avatar.layer("shock", true, realms[k][0], Vector3.UP * float(realms[k][1]), Vector3.ONE * radius * float(realms[k][2]), Vector3.ZERO, windup + 0.04 + 0.07 * float(k), 0.6, {"initial": 0.2, "grow": 4.5, "decay": 0.45, "opacity": 0.25, "tier": NaturalArt.TIER_CORE if k < 2 else NaturalArt.TIER_MID})
		if fx.has("burn"):
			var foes := form.foes(body, radius) if not form.cosmetic else []
			for k in mini(foes.size(), NaturalArt.count(6)):
				var at := (foes[k] as Node3D).global_position - slam
				avatar._light("quad", 8, RamakienArt.L_EMBER, RamakienArt.L_FLAME, at + Vector3(0, 0.8, 0), Vector3(0.8, 1.2, 1.0), windup + 0.05 + 0.06 * float(k % 3), 1.4, {"initial": 0.3, "grow": 5.0, "billboard": true, "travel": Vector3(0, 0.25, 0), "fade_in": 0.08, "decay": 0.6, "opacity": 0.9, "priority": 4})
	# The temple (high quality only): shafts of gold light rise from the glass.
	if GodSkillArt.extra_roots(2) >= 2:
		var temple := _field_root(parent, slam, "StarGodTemple_" + ID)
		for k in NaturalArt.count(5):
			var a := float(k) * 2.39996 + 0.3
			temple._light("shaft", 4, RamakienArt.L_GOLD, RamakienArt.L_WHITE, Vector3(sin(a), 0, cos(a)) * radius * (0.18 + 0.08 * float(k)), Vector3(1.4, 6.5, 1.0), windup + 0.06 + 0.05 * float(k), 1.1, {"initial": 0.4, "grow": 4.0, "face_camera": true, "fade_in": 0.12, "decay": 0.6, "opacity": 0.7})


## A RamakienArt root on the field at [param at] (its own clock and cap), not tied to any
## star cast (the form outlives its StarSkillSequence).
static func _field_root(parent: Node3D, at: Vector3, label: String) -> RamakienArt:
	var root := RamakienArt.new()
	root.name = label
	root.cap = RamakienArt.layer_cap()
	parent.add_child(root)
	root.global_position = at
	return root
