class_name Star500WingArt
extends Node3D
## The look of the ★500 wings (ปีกเทวาลัย, Star500Gear): a great pair of celestial angel
## wings, each a gold arm (shoulder, wrist, a jade gem in a gold ring at the wrist)
## carrying three tiers of pearl feathers, the long flight feathers each with a shaft
## of gold light down its middle, the coverts in pale gold, the class's sigil
## (SetGearArt._sigil in its accent) burning at the wrist; a gold halo with rays floats
## between the wings behind the head, and a soft glow in the class's light sits behind
## them (one additive quad). Gold motes drift down from the pair (LegendWingArt's mote
## material, VfxBudget-counted) unless the dress is light.
##
## The Dark Lord, who wears a cape in the wing slot, gets the Eclipse King's cape: the
## star cape (CapeArt) re-cut in pearl and gold over jade, with a small pair of these
## wings at the shoulders. The Muay Thai fighter gets its star ring robe re-cut in
## pearl satin and gold with the class's fire, and the floating halo; no wings.
##
## Built once (StarGearArt's two vertex-colour surfaces, cached by key) and shared;
## no shader, no per-frame script: the wing clips (DragonWingArt._clips: Idle, Flap,
## Glide, Fold, Unfold) key [member beat], [member fold] and [member air], which place
## the two wing nodes (and billow the cape), so HeroVisual poses it like any pair.
##
## Model space is the chibi's (x side, y up, z front); authored in metres at the
## hero's size under the Fit node, on the shoulder blades.

const FIT := 1.0 / 2.45
const BACK := Vector3(0.0, 0.57, -0.09)
const PIVOT := Vector3(0.1, 0.08, -0.12)
const SMALL_PIVOT := Vector3(0.16, 0.18, -0.12)
const GREAT := 0.95
const SMALL := 0.5
const HALO_AT := Vector3(0.0, 0.95, -0.32)
## The arm of the right wing (x out, y up): shoulder, elbow, wrist.
const ELBOW := Vector3(0.45, 0.42, -0.02)
const WRIST := Vector3(0.95, 0.92, -0.05)

@export var beat := 0.0:
	set(value):
		beat = value
		_place()
@export var fold := 0.0:
	set(value):
		fold = value
		_place()
@export var air := 0.0:
	set(value):
		air = value
		_place()

var cls := "warrior"
var _fit: Node3D
var _wings: Array[Node3D] = []
var _halo: Node3D
var _cape: CapeArt
static var _glow_mats := {}


## The pair as worn by class [param p_cls]. [param light]: a crowd's light dress (no motes).
static func build(p_cls: String, light := false) -> Node3D:
	var art := Star500WingArt.new()
	art.cls = p_cls if Star500Gear.THEMES.has(p_cls) else "warrior"
	art.name = "Wings_star500_" + art.cls
	art._make(light)
	return art


static func build_icon_node(p_cls: String) -> Node3D:
	var holder := Node3D.new()
	var wings := build(p_cls, true)
	wings.rotation_degrees = Vector3(0, 180, 0)
	holder.add_child(wings)
	if p_cls == "muaythai":
		holder.set_meta("frame", Vector3(0.0, 0.44, 0.95))
	elif p_cls == "darklord":
		holder.set_meta("frame", Vector3(0.0, 0.42, 1.16))
	else:
		holder.set_meta("frame", Vector3(0.0, 0.72, 1.7))
	return holder


func _make(light: bool) -> void:
	_fit = Node3D.new()
	_fit.name = "Fit"
	_fit.scale = Vector3.ONE * FIT
	_fit.position = BACK
	add_child(_fit)
	var p := Star500GearArt.palette(cls)
	if cls == "muaythai":
		_cape = CapeArt.build_tinted("HeavenCape", {"outer_color": Color("fbf1d8"), "outer_deep": Color("c79a45"), "lining_color": Color("1d5a4c"),
			"trim_color": Star500Gear.GOLD, "glow_color": p.glow, "boxer": 2.0}, cls)
	elif cls == "darklord":
		_cape = CapeArt.build_tinted("HeavenCape", {"outer_color": Color("f4eedc"), "outer_deep": Color("9c8a5a"), "lining_color": Color("164a40"),
			"trim_color": Star500Gear.GOLD, "glow_color": p.glow, "capelet_color": Color("fff6dc"), "capelet_deep": Color("b8934a"), "gem": p.gem})
	if _cape != null:
		# This node's clips drive the cape: its own player would fight them.
		var own_player := _cape.get_node_or_null("AnimationPlayer")
		if own_player != null:
			_cape.remove_child(own_player)
			own_player.free()
		add_child(_cape)
	if cls != "muaythai":
		for side in [1.0, -1.0]:
			var holder := Node3D.new()
			holder.name = "Wing" + ("R" if side > 0 else "L")
			StarGearArt._attach(holder, _wing_key())
			_fit.add_child(holder)
			_wings.append(holder)
	if cls != "darklord":
		_halo = Node3D.new()
		_halo.name = "Halo"
		_halo.position = HALO_AT if cls != "muaythai" else Vector3(0.0, 0.62, -0.3)
		StarGearArt._attach(_halo, _halo_key())
		_fit.add_child(_halo)
		_fit.add_child(_glow_quad(p.glow))
	if not light and LegendWingArt.sparkles_allowed(light) and cls != "muaythai":
		var motes := LegendWingArt.sparkles(_fit)
		motes.name = "Star500Sparkles"
		motes.amount = VfxBudget.count(8)
	_place()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	player.add_animation_library("", DragonWingArt._clips())
	player.play("Idle")


## The soft light behind the pair: one additive quad in the class's glow.
func _glow_quad(color: Color) -> MeshInstance3D:
	var key := color.to_html()
	if not _glow_mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = VfxKit.soft_dot()
		mat.albedo_color = Color(color.r, color.g, color.b, 0.32)
		mat.no_depth_test = false
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		MaterialKeeper.keep(mat)
		_glow_mats[key] = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 2.0) if cls != "muaythai" else Vector2(1.2, 1.2)
	var mi := MeshInstance3D.new()
	mi.name = "Glow"
	mi.mesh = quad
	mi.material_override = _glow_mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_outline", true)
	mi.position = Vector3(0, 0.55, -0.36) if cls != "muaythai" else Vector3(0, 0.6, -0.32)
	return mi


## The right wing (the left is the same mesh mirrored), baked once a class.
func _wing_key() -> String:
	var key := "heavenwing_" + cls
	if StarGearArt._cache.has(key):
		return key
	var b := StarGearArt._builder()
	var p := Star500GearArt.palette(cls)
	# The arm: gold, shoulder to elbow to wrist, with a jade gem in a ring at the wrist.
	StarGearArt._line(b, [Vector3.ZERO, ELBOW, WRIST, WRIST + Vector3(0.08, 0.05, 0)], 0.034, p.metal)
	StarGearArt._line(b, [Vector3(0, 0, 0.04), ELBOW + Vector3(0, 0, 0.04), WRIST + Vector3(0, 0, 0.03)], 0.012, p.gold, true)
	StarGearArt._ring_at(b, WRIST, 0.11, 0.028, p.metal, Vector3(90, 0, 0))
	StarGearArt._part(b, MeshKit.sphere_low(), p.jade, WRIST + Vector3(0, 0, 0.03), Vector3(0.11, 0.11, 0.07), Vector3.ZERO, true)
	SetGearArt._sigil(b, p, cls, WRIST + Vector3(0, 0, 0.08), 0.09)
	# Primary flight feathers from the wrist and hand: long, fanning out and down.
	var primaries := 9
	for k in primaries:
		var f := float(k) / float(primaries - 1)
		var root := WRIST.lerp(WRIST + Vector3(0.18, 0.1, 0), 1.0 - f) + Vector3(0, 0, -0.02 - 0.012 * k)
		var a := lerpf(0.35, 2.0, f)
		var length := lerpf(1.25, 1.55, sin(f * PI)) - f * 0.25
		_flight(b, p, root, a, length, 0.24, k)
	# Secondaries along the forearm: shorter, hanging down.
	var secondaries := 7
	for k in secondaries:
		var f := float(k) / float(secondaries - 1)
		var root := WRIST.lerp(ELBOW, f) + Vector3(0, 0, -0.05 - 0.01 * k)
		var a := lerpf(2.05, 2.75, f)
		var length := lerpf(1.1, 0.75, f)
		_flight(b, p, root, a, length, 0.22, k + primaries)
	# Tertials from the upper arm to the shoulder.
	for k in 4:
		var f := float(k) / 3.0
		var root := ELBOW.lerp(Vector3(0.08, 0.05, 0), f) + Vector3(0, 0, -0.1)
		StarGearArt._feather(b, root + _dir(lerpf(2.75, 2.95, f)) * 0.3, lerpf(0.6, 0.38, f), 0.17, -lerpf(2.75, 2.95, f), p.edge.lerp(p.gold, 0.15))
	# Two rows of coverts over the arm: pale gold, then gold, scale-like.
	for row in 2:
		var n := 9 - row * 2
		for k in n:
			var f := float(k) / float(n - 1)
			var root := WRIST.lerp(Vector3(0.1, 0.06, 0), f) + Vector3(0, 0, 0.02 + row * 0.03)
			var a := lerpf(1.2, 2.6, f) + row * 0.15
			var length := (0.42 if row == 0 else 0.26) * lerpf(1.0, 0.8, f)
			StarGearArt._feather(b, root + _dir(a) * length * 0.42, length, 0.15 - row * 0.03, -a, p.gold.lerp(p.edge, 0.55) if row == 0 else p.metal)
	# Glowing class-light tips on the outer primaries.
	for k in 5:
		var f := float(k) / float(primaries - 1)
		var root := WRIST.lerp(WRIST + Vector3(0.18, 0.1, 0), 1.0 - f)
		var a := lerpf(0.35, 2.0, f)
		var length := lerpf(1.25, 1.55, sin(f * PI)) - f * 0.25
		StarGearArt._shape(b, [Vector2(0, 0.14), Vector2(0.03, 0), Vector2(0, -0.05), Vector2(-0.03, 0)], root + _dir(a) * (length + 0.1) + Vector3(0, 0, -0.02), 0.012, p.glow, true, -a)
	StarGearArt._store(key, b)
	return key


## A flight feather from [param root] along angle [param a] (0 up, PI/2 out, PI down).
static func _flight(b: Dictionary, p: Dictionary, root: Vector3, a: float, length: float, width: float, k: int) -> void:
	var dir := _dir(a)
	# Pearl feathers that hold their light from every side (the glow surface), every
	# third warmed toward gold.
	var tint: Color = (p.edge as Color).darkened(0.04) if k % 3 != 2 else (p.edge as Color).lerp(p.gold, 0.3)
	StarGearArt._feather(b, root + dir * length * 0.5, length, width, -a, tint, true)
	StarGearArt._line(b, [root + dir * length * 0.06 + Vector3(0, 0, 0.012), root + dir * length * 0.9 + Vector3(0, 0, 0.012)], 0.009, p.gold, true)
	# The leading feathers lie along the arm: no back shaft there (it read as one long rod).
	if k >= 2:
		StarGearArt._line(b, [root + dir * length * 0.06 + Vector3(0, 0, -0.012), root + dir * length * 0.9 + Vector3(0, 0, -0.012)], 0.006, p.gold)


static func _dir(a: float) -> Vector3:
	return Vector3(sin(a), cos(a), 0.0)


## The halo between the wings: a gold ring of rays round a jade ring and the sigil.
func _halo_key() -> String:
	var key := "heavenhalo_" + cls
	if StarGearArt._cache.has(key):
		return key
	var b := StarGearArt._builder()
	var p := Star500GearArt.palette(cls)
	var r := 0.3 if cls != "muaythai" else 0.26
	StarGearArt._ring_at(b, Vector3.ZERO, r, 0.03, p.gold, Vector3(90, 0, 0), true)
	StarGearArt._ring_at(b, Vector3.ZERO, r * 0.82, 0.016, p.jade, Vector3(90, 0, 0), true)
	StarGearArt._ring_at(b, Vector3.ZERO, r * 0.9, 0.022, p.metal, Vector3(90, 0, 0))
	Star500GearArt._rays(b, p, Vector3(0, 0, -0.01), r * 1.08, r * 0.42, 24, r * 0.035)
	SetGearArt._sigil(b, p, cls, Vector3(0, 0, 0.02), r * 0.32)
	StarGearArt._store(key, b)
	return key


## Places the wings for the current beat and fold (the left one mirrors the right).
func _place() -> void:
	if _cape != null:
		_cape.billow = clampf(0.14 + 0.82 * air + 0.08 * beat, 0.0, 1.0)
		_cape.fold = fold
	if _halo != null:
		_halo.scale = Vector3.ONE * lerpf(1.0, 0.6, fold)
	if _fit == null or _wings.size() < 2:
		return
	var small := cls == "darklord"
	var size := (SMALL if small else GREAT) * lerpf(1.0, 0.5, fold)
	var open := Basis.from_euler(Vector3(deg_to_rad(-6.0 + 6.0 * fold), deg_to_rad(26.0 + 30.0 * fold), deg_to_rad(beat * 15.0 - 8.0 - 96.0 * fold + (14.0 if small else 0.0))))
	open = open.scaled(Vector3.ONE * size)
	var pivot := SMALL_PIVOT if small else PIVOT
	_wings[0].transform = Transform3D(open, pivot)
	_wings[1].transform = Transform3D(Basis.from_scale(Vector3(-1, 1, 1)) * open, pivot * Vector3(-1, 1, 1))
