class_name Star500WingArt
extends Node3D
## The look of the ★500 wings (ปีกเทวาลัย, Star500Gear): one set, a different pair for every
## class. What they share: a gold arm with a line of gold light, the jade gem in its gold
## ring and the class's sigil (SetGearArt._sigil) at the wrist, every feather or plate
## rimmed in gold light, a gold halo with rays between the wings behind the head, a soft
## glow in the class's light behind them (one additive quad), and gold motes drifting
## down (LegendWingArt's mote material, VfxBudget-counted) unless the dress is light.
## What sets them apart is the cut and colours (_wing_key, TINT):
##   warrior   a sunburst of gold sword-feathers with burning fullers over crimson coverts
##   archer    long emerald leaves streaming back in layers, gold-veined, loose leaves on a gust
##   lancer    tall royal-blue lance feathers with gold lightning spearheads, bolts between
##   mage      no feathers: rays of floating violet crystal shards, broken apart, pink-cored
##   priest    a seraph's six wings: a raised pale-gold pair, the great white pair, a lowered pair
##   summoner  a great silver crescent moon with teal spirit veils hanging and swaying
##   defender  broad wings of overlapping sky-steel shield plates with pearl bosses, gold crest
##   assassin  saw-edged black-violet scythe blades swept out and down, rimmed in crimson
##   bard      a gold lyre: a horn rising into a scroll, strings of light, a rose fringe, notes
##
## The Dark Lord, who wears a cape in the wing slot, gets the Eclipse King's cape: the
## star cape (CapeArt) re-cut in pearl and gold over jade, with a small pair at the
## shoulders of its own: onyx-violet feathers rimmed in gold round an eclipse (a black
## sun in a green-gold corona) at the wrist. The Muay Thai fighter gets its star ring
## robe re-cut in pearl satin and gold with the class's fire, and the floating halo; no
## wings.
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
## Each class's own colours [main, deep, light]: what tells the pairs apart with their
## cut (_wing_key); the set's gold, pearl and jade run through all of them.
const TINT := {
	"warrior": [Color("ffcf4a"), Color("b8241c"), Color("ff8a2a")],
	"archer": [Color("34c47a"), Color("0d6e44"), Color("b4ffd8")],
	"lancer": [Color("3d6ae0"), Color("1a2f86"), Color("fff06a")],
	"mage": [Color("9a6cff"), Color("3a1a8c"), Color("ff8cf0")],
	"priest": [Color("ffffff"), Color("e6efff"), Color("a8e8ff")],
	"summoner": [Color("e2f6ff"), Color("1b7f92"), Color("7af6ff")],
	"defender": [Color("74aef0"), Color("2b5a9c"), Color("d4f6ff")],
	"assassin": [Color("4a2468"), Color("120818"), Color("ff2f62")],
	"darklord": [Color("4a3a7c"), Color("1c1432"), Color("9aff6a")],
	"bard": [Color("ff8cc8"), Color("c23c86"), Color("8afff0")],
}

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
		# The pairs differ in reach (the lancer's tall, the bard's wide): framed by their
		# bounds, a little closer than the icon tool's margin.
		holder.set_meta("zoom", 1.1)
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


## The right wing (the left is the same mesh mirrored), baked once a class: the class's
## own cut (CUT) in its own colours (TINT), on the set's gold arm with its jade gem and
## sigil, every feather rimmed in the set's gold light.
func _wing_key() -> String:
	var key := "heavenwing_" + cls
	if StarGearArt._cache.has(key):
		return key
	var b := StarGearArt._builder()
	var p := Star500GearArt.palette(cls)
	var t: Array = TINT.get(cls, TINT.warrior)
	match cls:
		"archer": _gale(b, p, t)
		"lancer": _thunder(b, p, t)
		"mage": _cosmos(b, p, t)
		"priest": _seraph(b, p, t)
		"summoner": _moon(b, p, t)
		"defender": _bastion(b, p, t)
		"assassin": _night(b, p, t)
		"bard": _lyre(b, p, t)
		"darklord": _eclipse(b, p, t)
		_: _solar(b, p, t)
	StarGearArt._store(key, b)
	return key


# --- The class cuts (right wing, x out, y up; the rear, seen in play, is -z) ------

## Warrior (สุริยราชันย์): a sunburst of gold sword-feathers, each with a guard and a
## burning fuller, fanned up and out from a sun at the wrist over crimson coverts.
static func _solar(b: Dictionary, p: Dictionary, t: Array) -> void:
	_arm(b, p, "warrior", ELBOW, WRIST, 0.04)
	Star500GearArt._rays(b, p, WRIST + Vector3(0, 0, -0.05), 0.15, 0.2, 12)
	var hand := WRIST + Vector3(0.16, 0.12, 0)
	for k in 8:
		var f := k / 7.0
		_sword(b, p, t, hand.lerp(WRIST, f) + Vector3(0, 0, 0.012 * k), lerpf(0.02, 1.9, f), lerpf(1.85, 1.2, f) + 0.22 * sin(f * PI), 0.21)
	for k in 6:
		var f := k / 5.0
		_sword(b, p, t, WRIST.lerp(ELBOW, f * 0.9) + Vector3(0, 0, 0.11 + 0.01 * k), lerpf(2.1, 2.8, f), lerpf(1.15, 0.72, f), 0.19)
	# Crimson coverts, then gold, flame-tongued, over the arm.
	for row in 2:
		var n := 7 - row * 2
		for k in n:
			var f := float(k) / float(n - 1)
			var root := WRIST.lerp(Vector3(0.1, 0.06, 0), 0.1 + 0.9 * f) + Vector3(0, 0, -0.04 - 0.03 * row)
			var a := lerpf(1.3, 2.55, f) + row * 0.12
			var l := (0.5 if row == 0 else 0.3) * lerpf(1.0, 0.75, f)
			_lay(b, _leaf_pts(l * 1.12, 0.2 * 1.2), root - _dir(a) * 0.02, a, 0.002, p.gold, true)
			_lay(b, _leaf_pts(l, 0.2), root, a, 0.03, t[1] if row == 0 else p.metal)


## Archer (วายุสวรรค์): long emerald leaves streaming back on the gale in three layered
## rows, gold-veined, with loose leaves and two streams of wind blowing off the tips.
static func _gale(b: Dictionary, p: Dictionary, t: Array) -> void:
	var elbow := Vector3(0.5, 0.32, -0.02)
	var wrist := Vector3(1.1, 0.56, -0.04)
	var hand := Vector3(1.55, 0.52, -0.05)
	_arm(b, p, "archer", elbow, wrist, 0.032)
	StarGearArt._line(b, [wrist, hand], 0.026, p.metal)
	for k in 9:
		var f := k / 8.0
		var deep: Color = t[1]
		_leaf(b, p, hand.lerp(wrist, f) + Vector3(0, 0, 0.012 * k), lerpf(0.5, 1.9, f), lerpf(1.6, 1.25, f) + 0.2 * sin(f * PI), 0.36, deep if k % 2 == 0 else deep.lerp(t[0], 0.4))
	for k in 7:
		var f := k / 6.0
		_leaf(b, p, wrist.lerp(elbow, f) + Vector3(0, 0, -0.03 + 0.008 * k), lerpf(2.05, 2.75, f), lerpf(1.2, 0.75, f), 0.32, (t[0] as Color).lerp(t[1], 0.2 * (k % 2)))
	for row in 2:
		var n := 7 - row * 2
		for k in n:
			var f := float(k) / float(n - 1)
			var root := hand.lerp(Vector3(0.12, 0.06, 0), 0.05 + 0.92 * f) + Vector3(0, 0, -0.07 - 0.03 * row)
			_leaf(b, p, root, lerpf(1.25, 2.5, f) + row * 0.15, (0.55 if row == 0 else 0.36) * lerpf(1.0, 0.75, f), 0.22 - row * 0.04, (t[0] as Color).lerp(t[2], 0.35 + 0.35 * row))
	# Leaves loose on the wind beyond the tips.
	for k in 5:
		var at := Vector3(2.2 + 0.25 * sin(k * 2.1), 1.1 - 0.55 * k, -0.06)
		_lay(b, _leaf_pts(0.26, 0.12), at, 1.2 + k * 0.7, 0.012, t[2] if k % 2 == 0 else p.gold, true)
	# A stream of the gale curling off the tips.
	var gust: Array[Vector3] = []
	var gw: Array = []
	for i in 11:
		var u := i / 10.0
		gust.append(Vector3(1.3 + 1.2 * u, 1.75 - 1.9 * u + 0.25 * sin(u * TAU), -0.12))
		gw.append(0.026 * sin(u * PI) + 0.002)
	_ribbon(b, gust, gw, gw, p.gold, t[2], true)


## Lancer (อสนีทิพย์): tall royal-blue lance feathers thrust upward, each tipped with a
## gold spearhead of lightning, with thunderbolts crackling between them.
static func _thunder(b: Dictionary, p: Dictionary, t: Array) -> void:
	var elbow := Vector3(0.32, 0.52, -0.02)
	var wrist := Vector3(0.66, 1.1, -0.04)
	var hand := wrist + Vector3(0.06, 0.14, 0)
	_arm(b, p, "lancer", elbow, wrist, 0.036)
	for k in 8:
		var f := k / 7.0
		_lance(b, p, t, hand.lerp(wrist, f) + Vector3(0, 0, 0.012 * k), lerpf(-0.1, 1.3, f), lerpf(2.05, 1.35, f), 0.19, (t[0] as Color).lerp(t[1], 0.45 * (k % 2)))
	for k in 6:
		var f := k / 5.0
		_lance(b, p, t, wrist.lerp(elbow, f * 0.9) + Vector3(0, 0, 0.1 + 0.01 * k), lerpf(1.5, 2.35, f), lerpf(1.2, 0.75, f), 0.17, (t[1] as Color).lerp(t[0], 0.3 * (k % 2)))
	# Thunderbolts between the lances.
	for k in 3:
		var a := lerpf(0.3, 1.6, k / 2.0)
		var d := _dir(a)
		var side := Vector3(d.y, -d.x, 0)
		var pts: Array[Vector3] = []
		var w: Array = []
		for i in 7:
			var u := i / 6.0
			pts.append(wrist + d * (0.25 + 1.25 * u) + side * (0.08 if i % 2 == 0 else -0.08) * (1.0 - u * 0.3) + Vector3(0, 0, -0.06))
			w.append(lerpf(0.04, 0.008, u))
		_ribbon(b, pts, w, w, t[2], p.gold, true)
	for k in 6:
		var f := k / 5.0
		var root := wrist.lerp(Vector3(0.08, 0.06, 0), 0.08 + 0.9 * f) + Vector3(0, 0, -0.06)
		var a := lerpf(1.0, 2.3, f)
		_lay(b, _leaf_pts(0.48 * 1.12, 0.24), root - _dir(a) * 0.02, a, 0.002, p.gold, true)
		_lay(b, _leaf_pts(0.48, 0.2), root, a, 0.03, p.edge if k % 2 == 0 else p.metal)


## Mage (จักรวาลทิพย์): no feathers at all: rays of violet crystal shards floating
## apart, each broken in three with starlight between, burning pink at the tips, round
## a tilted orbit at the wrist.
static func _cosmos(b: Dictionary, p: Dictionary, t: Array) -> void:
	_arm(b, p, "mage", ELBOW, WRIST, 0.03)
	var cuts := [[0.0, 0.2], [0.28, 0.58], [0.66, 1.0]]
	for k in 7:
		var f := k / 6.0
		var a := lerpf(0.1, 2.15, f)
		var d := _dir(a)
		var length := lerpf(1.75, 1.25, f) + 0.25 * sin(f * PI)
		var root := WRIST + d * 0.36 + Vector3(0, 0, 0.012 * k)
		for s in 3:
			var c: Array = cuts[s]
			_crystal(b, t, root + d * length * float(c[0]), a, length * (float(c[1]) - float(c[0])), lerpf(0.12, 0.27, s / 2.0), s)
	for k in 4:
		var f := k / 3.0
		var a := lerpf(2.4, 2.95, f)
		var d := _dir(a)
		var length := lerpf(1.05, 0.7, f)
		var root := WRIST.lerp(ELBOW, f * 0.85) + d * 0.15 + Vector3(0, 0, 0.12)
		_crystal(b, t, root, a, length * 0.4, 0.13, 0)
		_crystal(b, t, root + d * length * 0.5, a, length * 0.5, 0.22, 2)
	# Small crystals over the arm, and stars among the shards.
	for k in 3:
		var f := k / 2.0
		_crystal(b, t, WRIST.lerp(Vector3(0.1, 0.06, 0), 0.3 + 0.55 * f) + Vector3(0, 0, -0.06), lerpf(1.3, 2.2, f), lerpf(0.36, 0.26, f), 0.15, 1)
	for at in [Vector3(1.55, 2.05, -0.08), Vector3(2.35, 1.35, -0.08), Vector3(2.4, 0.35, -0.08), Vector3(1.7, -0.45, -0.08), Vector3(1.9, 0.95, -0.1)]:
		SetGearArt._spark(b, at, 0.09, p.gold)


## Priest (อรุณเทวะ): a seraph's six wings: a small pair raised above, the great pair
## and a pair sweeping down, pure white feathers on gold boughs, rimmed in gold light.
static func _seraph(b: Dictionary, p: Dictionary, t: Array) -> void:
	var elbow := Vector3(0.42, 0.36, -0.02)
	var wrist := Vector3(0.88, 0.78, -0.04)
	_arm(b, p, "priest", elbow, wrist, 0.032)
	var hand := wrist + Vector3(0.14, 0.1, 0)
	for k in 8:
		var f := k / 7.0
		_plume(b, p, t, hand.lerp(wrist, f) + Vector3(0, 0, 0.012 * k), lerpf(0.75, 2.05, f), lerpf(1.45, 1.05, f) + 0.15 * sin(f * PI), 0.27, k)
	for k in 5:
		var f := k / 4.0
		_plume(b, p, t, wrist.lerp(elbow, f * 0.85) + Vector3(0, 0, 0.08), lerpf(2.05, 2.5, f), lerpf(0.95, 0.7, f), 0.24, k + 1)
	# The raised pair and the lowered pair, each on its own gold bough.
	var upper := Vector3(0.26, 0.62, 0.06)
	var lower := Vector3(0.3, -0.3, 0.06)
	StarGearArt._line(b, [Vector3(0, 0, 0.04), Vector3(0.12, 0.3, 0.05), upper], 0.026, p.metal)
	StarGearArt._line(b, [Vector3(0, 0, 0.04), Vector3(0.16, -0.14, 0.05), lower], 0.026, p.metal)
	# (Pale gold, so the three tiers read apart.)
	var dawn := [Color("fff6dc"), Color("ffe3a0"), t[2]]
	for k in 6:
		var f := k / 5.0
		_plume(b, p, dawn, upper.lerp(Vector3(0.14, 0.36, 0.06), f) + Vector3(0, 0, 0.01 * k), lerpf(-0.12, 0.55, f), lerpf(1.15, 0.75, f), 0.22, k)
		_plume(b, p, dawn, lower.lerp(Vector3(0.16, -0.12, 0.06), f) + Vector3(0, 0, 0.01 * k), lerpf(1.95, 2.65, 1.0 - f), lerpf(1.1, 0.72, f), 0.22, k + 1)
	for at in [upper, lower, wrist.lerp(elbow, 0.5)]:
		for k in 4:
			var a := lerpf(0.9, 2.2, k / 3.0)
			_lay(b, _leaf_pts(0.36, 0.17), at + Vector3(0, 0, -0.07), a, 0.025, p.metal if k % 2 == 0 else p.gold)


## Summoner (จันทราทิพย์): a great silver crescent moon round the wrist for a wing,
## spirit veils of teal light hanging from it and swaying, with little moons beside.
static func _moon(b: Dictionary, p: Dictionary, t: Array) -> void:
	var c := Vector3(0.9, 0.82, -0.04)
	_arm(b, p, "summoner", Vector3(0.45, 0.42, -0.02), c, 0.03)
	var r := 1.12
	var pts: Array[Vector3] = []
	var outer: Array = []
	var inner: Array = []
	var rim: Array = []
	var rim_in: Array = []
	for i in 21:
		var u := i / 20.0
		pts.append(c + _dir(lerpf(-0.35, 2.6, u)) * r)
		outer.append(0.02 + 0.3 * sin(u * PI))
		inner.append(0.015)
		rim.append(0.045 + 0.3 * sin(u * PI))
		rim_in.append(0.04)
	_ribbon(b, pts, rim, rim_in, p.gold, p.gold, true)
	_sheet(b, pts, outer, inner, t[0], Color("ffffff"), 0.008)
	# Spirit veils from the crescent's outer half, down and swaying.
	for k in 8:
		var f := k / 7.0
		var top := c + _dir(lerpf(0.7, 2.45, f)) * (r + 0.02)
		var length := lerpf(0.95, 1.4, sin(f * PI)) + 0.1
		var veil: Array[Vector3] = []
		var w: Array = []
		var thread: Array = []
		for i in 8:
			var u := i / 7.0
			veil.append(top + Vector3(0.06 * sin(u * 5.0 + k) + 0.18 * u * (f - 0.2), -length * u, 0.03 + 0.004 * k))
			w.append(lerpf(0.085, 0.012, u))
			thread.append(lerpf(0.016, 0.003, u))
		_ribbon(b, veil, w, w, t[1], t[0], false)
		var front: Array[Vector3] = []
		for v in veil:
			front.append(v + Vector3(0, 0, -0.012))
		_ribbon(b, front, thread, thread, t[2], p.gold, true)
		_oval(b, veil[7] + Vector3(0, -0.04, -0.01), 0.035, 0.035, t[2], true)
	# Two little moons and stars in the hollow.
	for m in [[Vector3(2.25, 1.75, -0.06), 0.16], [Vector3(-0.05, 1.45, 0.02), 0.12]]:
		var mc: Vector3 = m[0]
		var mr: float = m[1]
		var arc: Array[Vector3] = []
		var mw: Array = []
		for i in 9:
			var u := i / 8.0
			arc.append(mc + _dir(lerpf(0.2, 3.0, u)) * mr)
			mw.append(mr * 0.45 * sin(u * PI) + 0.005)
		_ribbon(b, arc, mw, [0.004, 0.004, 0.004, 0.004, 0.004, 0.004, 0.004, 0.004, 0.004], t[0], p.gold, true)
	for at in [c + Vector3(0.45, 0.35, -0.08), c + Vector3(0.55, -0.3, -0.08), c + Vector3(0.15, 0.6, -0.08)]:
		SetGearArt._spark(b, at, 0.07, t[2])


## Defender (ปราการสวรรค์): broad heavy wings of overlapping sky-steel shield plates,
## gold-rimmed with a pearl boss each, under a crest of gold pauldron plates.
static func _bastion(b: Dictionary, p: Dictionary, t: Array) -> void:
	var elbow := Vector3(0.5, 0.34, -0.02)
	var wrist := Vector3(1.02, 0.62, -0.04)
	_arm(b, p, "defender", elbow, wrist, 0.055)
	var hand := wrist + Vector3(0.2, 0.06, 0)
	for k in 6:
		var f := k / 5.0
		_shield_plate(b, p, t, hand.lerp(wrist, f) + Vector3(0, 0, 0.014 * k), lerpf(0.95, 2.35, f), lerpf(1.3, 1.0, f) + 0.1 * sin(f * PI), 0.58, t[0] if k % 2 == 0 else (t[0] as Color).darkened(0.12))
	for k in 5:
		var f := k / 4.0
		_shield_plate(b, p, t, wrist.lerp(elbow, f * 0.9) + Vector3(0, 0, -0.03 + 0.01 * k), lerpf(2.35, 2.9, f), lerpf(0.95, 0.72, f), 0.52, t[1] if k % 2 == 0 else (t[1] as Color).lightened(0.12))
	# The crest: gold pauldron plates along the arm, raised up and out.
	for k in 4:
		var f := k / 3.0
		var root := wrist.lerp(Vector3(0.1, 0.06, 0), f * 0.85) + Vector3(0, 0, -0.08 - 0.01 * k)
		var a := lerpf(0.55, 1.05, f)
		var l := lerpf(0.46, 0.32, f)
		_lay(b, _heater_pts(l * 1.12, 0.34 * 1.12), root - _dir(a) * 0.03, a, 0.002, p.gold, true)
		_lay(b, _heater_pts(l, 0.34), root, a, 0.05, p.metal)
		StarGearArt._gem(b, root + _dir(a) * l * 0.5 + Vector3(0, 0, -0.06), Vector3(0.08, 0.12, 0.03), {"gem": t[2]}, -a)


## Assassin (ราตรีทิพย์): tattered night blades of black violet, saw-edged and curved
## like scythes, sweeping out and down, rimmed in crimson light, two claws raised.
static func _night(b: Dictionary, p: Dictionary, t: Array) -> void:
	var elbow := Vector3(0.5, 0.4, -0.02)
	var wrist := Vector3(1.02, 0.72, -0.04)
	_arm(b, p, "assassin", elbow, wrist, 0.03)
	var hand := wrist + Vector3(0.16, 0.06, 0)
	for k in 2:
		_jag(b, p, t, wrist + Vector3(0.02 * k, 0.04, -0.02), -0.05 + 0.45 * k, 0.8 - 0.22 * k, 0.12, -0.3)
	for k in 8:
		var f := k / 7.0
		_jag(b, p, t, hand.lerp(wrist, f) + Vector3(0, 0, 0.012 * k), lerpf(0.85, 2.4, f), lerpf(2.0, 1.4, f) + 0.15 * sin(f * PI), 0.2, 0.16)
	for k in 6:
		var f := k / 5.0
		_jag(b, p, t, wrist.lerp(elbow, f * 0.9) + Vector3(0, 0, 0.11 + 0.01 * k), lerpf(2.45, 2.95, f), lerpf(1.2, 0.75, f), 0.18, 0.12)
	for k in 5:
		var f := k / 4.0
		var root := wrist.lerp(Vector3(0.1, 0.06, 0), 0.1 + 0.85 * f) + Vector3(0, 0, -0.06)
		_jag(b, p, t, root, lerpf(1.5, 2.6, f), lerpf(0.5, 0.36, f), 0.14, 0.05)


## Bard (ทิพยคีตา): a gold lyre for a wing, its horn sweeping up into a scroll, strings
## of light strung down to a rose-feather fringe, and notes of music floating round.
static func _lyre(b: Dictionary, p: Dictionary, t: Array) -> void:
	var horn: Array[Vector3] = []
	for i in 13:
		horn.append(_lyre_top(i / 12.0))
	var tip := horn[12]
	var light: Array[Vector3] = []
	for v in horn:
		light.append(v + Vector3(0, 0, -0.045))
	# The scroll: the horn's end curling over and in.
	var curl := tip + Vector3(0.0, -0.15, 0)
	for i in range(1, 9):
		horn.append(curl + _dir(i * 0.75) * lerpf(0.15, 0.05, i / 8.0))
	StarGearArt._line(b, horn, 0.045, p.metal)
	StarGearArt._line(b, light, 0.014, p.gold, true)
	var base: Array[Vector3] = []
	for i in 10:
		base.append(_lyre_low(i / 9.0))
	StarGearArt._line(b, base, 0.032, p.metal)
	# The strings, from the horn down to the low bar.
	for i in 7:
		var u := lerpf(0.22, 0.94, i / 6.0)
		var top := _lyre_top(u)
		var low := _lyre_low(clampf(top.x / LYRE_LOW_X, 0.0, 1.0))
		StarGearArt._line(b, [top + Vector3(0, 0, 0.01), low + Vector3(0, 0, 0.01)], 0.017, t[2] if i % 2 == 0 else p.gold, true)
	# The jade gem, ring and sigil where the horn rises.
	var hub := _lyre_top(0.28)
	StarGearArt._ring_at(b, hub + Vector3(0, 0, -0.03), 0.11, 0.028, p.metal)
	StarGearArt._part(b, MeshKit.sphere_low(), p.jade, hub + Vector3(0, 0, -0.04), Vector3(0.11, 0.11, 0.07), Vector3.ZERO, true)
	SetGearArt._sigil(b, p, "bard", hub + Vector3(0, 0, -0.09), 0.09)
	# The rose fringe under the bar, and plumes off the scroll.
	for k in 9:
		var f := k / 8.0
		_plume(b, p, t, _lyre_low(lerpf(0.08, 1.0, f)) + Vector3(0, 0, 0.03 + 0.008 * k), lerpf(2.95, 2.25, f), lerpf(0.5, 0.82, f), 0.23, k)
	for k in 3:
		_plume(b, p, t, tip + Vector3(0.02, -0.06, 0.04 + 0.01 * k), lerpf(0.75, 1.55, k / 2.0), 0.85 - 0.12 * k, 0.24, k + 1)
	# Notes floating by.
	for n in [[Vector3(1.25, 0.72, -0.08), 0], [Vector3(2.45, 1.05, -0.08), 1], [Vector3(2.25, -0.35, -0.08), 2], [Vector3(0.55, 1.75, -0.04), 3]]:
		_note(b, p, t, n[0], int(n[1]))


## Dark Lord (ราชันสุริยคราส, the small pair over the cape): onyx feathers rimmed in
## gold round an eclipse at the wrist: a black sun in a green-gold corona.
static func _eclipse(b: Dictionary, p: Dictionary, t: Array) -> void:
	_arm(b, p, "darklord", ELBOW, WRIST, 0.036)
	var hand := WRIST + Vector3(0.16, 0.1, 0)
	for k in 8:
		var f := k / 7.0
		var a := lerpf(0.25, 1.95, f)
		var l := lerpf(1.55, 1.1, f) + 0.2 * sin(f * PI)
		var root := hand.lerp(WRIST, f) + Vector3(0, 0, 0.012 * k)
		_lay(b, _talon_pts(l * 1.1, 0.36), root - _dir(a) * 0.04, a, 0.002, p.gold, true)
		_lay(b, _talon_pts(l, 0.25), root, a, 0.04, t[0] if k % 2 == 0 else (t[0] as Color).lerp(t[1], 0.5))
		_stroke(b, root + _dir(a) * l * 0.1, root + _dir(a) * l * 0.8, 0.018, t[2], -0.045)
	for k in 6:
		var f := k / 5.0
		var a := lerpf(2.05, 2.75, f)
		var l := lerpf(1.05, 0.7, f)
		var root := WRIST.lerp(ELBOW, f * 0.9) + Vector3(0, 0, 0.11)
		_lay(b, _talon_pts(l * 1.1, 0.33), root - _dir(a) * 0.04, a, 0.002, p.gold, true)
		_lay(b, _talon_pts(l, 0.23), root, a, 0.04, t[1])
	for k in 5:
		var f := k / 4.0
		var a := lerpf(1.3, 2.5, f)
		var root := WRIST.lerp(Vector3(0.1, 0.06, 0), 0.15 + 0.8 * f) + Vector3(0, 0, -0.05)
		_lay(b, _talon_pts(0.42, 0.2), root, a, 0.03, p.metal)
	# The eclipse: a black disc in a corona of rays, the sigil in front.
	Star500GearArt._rays(b, p, WRIST + Vector3(0, 0, -0.06), 0.19, 0.22, 16)
	StarGearArt._ring_at(b, WRIST + Vector3(0, 0, -0.07), 0.19, 0.03, t[2], Vector3(90, 0, 0), true)
	StarGearArt._part(b, MeshKit.sphere_low(), t[1], WRIST + Vector3(0, 0, -0.07), Vector3(0.36, 0.36, 0.06))


# --- The pieces -------------------------------------------------------------------

## The gold arm every pair hangs on (shoulder, elbow, wrist), with a line of gold light
## down it and the jade gem in its gold ring and the class's sigil at the wrist.
static func _arm(b: Dictionary, p: Dictionary, p_cls: String, elbow: Vector3, wrist: Vector3, thick: float) -> void:
	var hand := wrist + (wrist - elbow).normalized() * 0.1
	StarGearArt._line(b, [Vector3.ZERO, elbow, wrist, hand], thick, p.metal)
	StarGearArt._line(b, [Vector3(0, 0, -thick * 0.8), elbow + Vector3(0, 0, -thick * 0.8), wrist + Vector3(0, 0, -thick * 0.8)], thick * 0.35, p.gold, true)
	StarGearArt._ring_at(b, wrist + Vector3(0, 0, -0.04), 0.11, 0.028, p.metal)
	StarGearArt._part(b, MeshKit.sphere_low(), p.jade, wrist + Vector3(0, 0, -0.05), Vector3(0.11, 0.11, 0.07), Vector3.ZERO, true)
	SetGearArt._sigil(b, p, p_cls, wrist + Vector3(0, 0, -0.1), 0.09)


## A gold sword-feather: a blade in a rim of the sun's light, a burning fuller, a guard.
static func _sword(b: Dictionary, p: Dictionary, t: Array, root: Vector3, a: float, l: float, w: float) -> void:
	var d := _dir(a)
	var side := Vector3(d.y, -d.x, 0)
	_lay(b, _blade_pts(l * 1.05, w * 1.32), root - d * l * 0.02, a, 0.002, t[2], true)
	_lay(b, _blade_pts(l, w), root, a, w * 0.16, t[0])
	_stroke(b, root + d * l * 0.2, root + d * l * 0.8, w * 0.16, (t[1] as Color).lerp(t[2], 0.6), -w * 0.17)
	_lay(b, [Vector2(-w * 0.64, 0), Vector2(-w * 0.5, w * 0.1), Vector2(w * 0.5, w * 0.1), Vector2(w * 0.64, 0), Vector2(w * 0.5, -w * 0.1), Vector2(-w * 0.5, -w * 0.1)], root + d * l * 0.13, a, w * 0.08, p.metal)
	_oval(b, root + d * l * 0.13 + Vector3(0, 0, -w * 0.06), w * 0.14, w * 0.14, t[1], true)


## A leaf: emerald, rimmed in gold light, its midrib and veins of gold.
static func _leaf(b: Dictionary, p: Dictionary, root: Vector3, a: float, l: float, w: float, color: Color) -> void:
	var d := _dir(a)
	var side := Vector3(d.y, -d.x, 0)
	_lay(b, _leaf_pts(l * 1.06, w * 1.18), root - d * l * 0.03, a, 0.002, p.gold, true)
	_lay(b, _leaf_pts(l, w), root, a, w * 0.09, color)
	_stroke(b, root + d * l * 0.04, root + d * l * 0.88, w * 0.06, p.gold, -w * 0.1)
	var at := root + d * l * 0.42
	for s in [1.0, -1.0]:
		_stroke(b, at, at + (d * 0.55 + side * s * 0.7).normalized() * w * 0.32, w * 0.035, p.gold, -w * 0.07)


## A lance feather: a long narrow blue feather on a gold shaft, a lightning spearhead.
static func _lance(b: Dictionary, p: Dictionary, t: Array, root: Vector3, a: float, l: float, w: float, color: Color) -> void:
	var d := _dir(a)
	_lay(b, _leaf_pts(l * 0.82 * 1.05, w * 1.25), root - d * 0.02, a, 0.002, p.gold, true)
	_lay(b, _leaf_pts(l * 0.82, w), root, a, w * 0.1, color)
	_stroke(b, root + d * l * 0.04, root + d * l * 0.74, w * 0.08, p.gold, -w * 0.11)
	var head := root + d * l * 0.7
	_lay(b, _diamond_pts(l * 0.32, w * 1.05), head, a, w * 0.14, p.metal)
	_lay(b, _diamond_pts(l * 0.22, w * 0.55), head + d * l * 0.04, a, w * 0.2, t[2], true)


## A crystal shard, faceted, with a core of light: [param s] 0 a small bright splinter
## near the arm, 1 violet, 2 the great deep-violet shard at the tip burning pink.
static func _crystal(b: Dictionary, t: Array, root: Vector3, a: float, l: float, w: float, s: int) -> void:
	var color: Color = [(t[0] as Color).lerp(t[2], 0.3), t[0], (t[0] as Color).lerp(t[1], 0.45)][s]
	_lay(b, _blade_pts(l, w), root, a, w * 0.36, color)
	_lay(b, _blade_pts(l * 0.72, w * 0.5), root + _dir(a) * l * 0.14, a, w * 0.5, t[2] if s > 0 else Color.WHITE, true)


## A white plume with a gold shaft, rimmed in gold light (a seraph's, the bard's fringe).
static func _plume(b: Dictionary, p: Dictionary, t: Array, root: Vector3, a: float, l: float, w: float, k: int) -> void:
	var d := _dir(a)
	var color: Color = t[0] if k % 2 == 0 else (t[0] as Color).lerp(t[1], 0.55)
	_lay(b, _plume_pts(l * 1.05, w * 1.2), root - d * l * 0.02, a, 0.002, p.gold, true)
	_lay(b, _plume_pts(l, w), root, a, w * 0.12, color)
	_stroke(b, root + d * l * 0.05, root + d * l * 0.85, w * 0.06, p.gold, -w * 0.13)
	_lay(b, _diamond_pts(w * 0.45, w * 0.24), root + d * l * 0.7, a, w * 0.16, t[2], true)


## A shield plate: sky steel in a heavier gold rim, a gold ridge and a pearl boss.
static func _shield_plate(b: Dictionary, p: Dictionary, t: Array, root: Vector3, a: float, l: float, w: float, color: Color) -> void:
	var d := _dir(a)
	_lay(b, _heater_pts(l * 1.08, w * 1.14), root - d * l * 0.03 + Vector3(0, 0, 0.01), a, w * 0.03, p.metal)
	_lay(b, _heater_pts(l, w), root, a, w * 0.09, color)
	_stroke(b, root + d * l * 0.05, root + d * l * 0.9, w * 0.06, p.gold, -w * 0.09)
	_oval(b, root + d * l * 0.45 + Vector3(0, 0, -w * 0.05), w * 0.17, w * 0.17, p.metal)
	_oval(b, root + d * l * 0.45 + Vector3(0, 0, -w * 0.08), w * 0.11, w * 0.11, p.edge, true)


## A night blade: saw-edged along its leading side, curved like a scythe ([param bend]),
## black violet shading darker to the tip, in a rim of crimson light.
static func _jag(b: Dictionary, p: Dictionary, t: Array, root: Vector3, a: float, l: float, w: float, bend: float) -> void:
	var d := _dir(a)
	var side := Vector3(d.y, -d.x, 0)
	var pts: Array[Vector3] = []
	var rim_pts: Array[Vector3] = []
	var teeth := [0.0, 0.55, 0.22, 0.7, 0.28, 0.72, 0.28, 0.6, 0.2, 0.0]
	var back := [0.0, 0.22, 0.3, 0.32, 0.32, 0.3, 0.27, 0.2, 0.1, 0.0]
	var wl: Array = []
	var wr: Array = []
	var gl: Array = []
	var gr: Array = []
	for i in 10:
		var u := i / 9.0
		var at := root + d * l * u + side * bend * l * u * u
		pts.append(at)
		rim_pts.append(at - d * 0.03)
		wl.append(float(teeth[i]) * w)
		wr.append(float(back[i]) * w)
		gl.append(float(teeth[i]) * w + 0.022)
		gr.append(float(back[i]) * w + 0.018)
	gl[9] = 0.0
	gr[9] = 0.0
	_ribbon(b, rim_pts, gl, gr, t[2], (t[2] as Color).lerp(p.gold, 0.25), true)
	_sheet(b, pts, wl, wr, t[0], t[1], 0.006)
	var core: Array[Vector3] = []
	var cw: Array = []
	for i in 7:
		core.append(pts[i + 1] + Vector3(0, 0, -0.012))
		cw.append(0.012 * (1.0 - i / 7.0))
	_ribbon(b, core, cw, cw, t[2], p.gold, true)


## A floating note: a head, a stem and a flag, in glow.
static func _note(b: Dictionary, p: Dictionary, t: Array, at: Vector3, k: int) -> void:
	var color: Color = t[2] if k % 2 == 0 else t[0]
	_oval(b, at, 0.1, 0.072, color, true, 0.45)
	var stem := at + Vector3(0.085, 0.03, 0)
	StarGearArt._line(b, [stem, stem + Vector3(0, 0.42, 0)], 0.017, p.gold, true)
	if k != 1:
		_ribbon(b, [stem + Vector3(0, 0.42, 0), stem + Vector3(0.11, 0.31, 0), stem + Vector3(0.14, 0.17, 0)], [0.045, 0.035, 0.006], [0.0, 0.0, 0.0], p.gold, color, true)
		return
	var two := at + Vector3(0.34, 0.08, 0)
	_oval(b, two, 0.1, 0.072, color, true, 0.45)
	StarGearArt._line(b, [two + Vector3(0.085, 0.03, 0), two + Vector3(0.085, 0.46, 0)], 0.017, p.gold, true)
	_ribbon(b, [stem + Vector3(0, 0.42, 0), two + Vector3(0.085, 0.46, 0)], [0.035, 0.035], [0.035, 0.035], p.gold, p.gold, true)


## The lyre's horn, from the shoulder up and out to the scroll ([param u] 0..1).
static func _lyre_top(u: float) -> Vector3:
	return Vector3(2.0 * u, 1.55 * sin(u * PI * 0.62) - 0.05 * u, -0.02)


const LYRE_LOW_X := 1.8


## The lyre's low bar, from the shoulder out ([param u] 0..1), sagging a little.
static func _lyre_low(u: float) -> Vector3:
	return Vector3(LYRE_LOW_X * u, -0.18 * sin(u * PI) - 0.1 * u + 0.02, -0.02)


# --- Outlines (authored along +Y from the root, laid along an angle by _lay) --------

## The direction at angle [param a] in the wing's plane: 0 up, PI/2 out, PI down.
static func _dir(a: float) -> Vector3:
	return Vector3(sin(a), cos(a), 0.0)


static func _lay(b: Dictionary, pts: Array[Vector2], root: Vector3, a: float, thick: float, color: Color, glow := false) -> void:
	StarGearArt._shape(b, pts, root, thick, color, glow, -a)


static func _blade_pts(l: float, w: float) -> Array[Vector2]:
	return [Vector2(0, 0), Vector2(w * 0.32, l * 0.05), Vector2(w * 0.5, l * 0.16), Vector2(w * 0.46, l * 0.74), Vector2(0, l),
		Vector2(-w * 0.46, l * 0.74), Vector2(-w * 0.5, l * 0.16), Vector2(-w * 0.32, l * 0.05)]


static func _leaf_pts(l: float, w: float) -> Array[Vector2]:
	var right: Array[Vector2] = []
	for i in range(1, 5):
		var u := i / 5.0
		right.append(Vector2(w * 0.5 * pow(sin(PI * pow(u, 0.85)), 0.8), l * u))
	var out: Array[Vector2] = [Vector2(0, 0)]
	out.append_array(right)
	out.append(Vector2(0, l))
	for i in range(right.size() - 1, -1, -1):
		out.append(Vector2(-right[i].x, right[i].y))
	return out


static func _plume_pts(l: float, w: float) -> Array[Vector2]:
	return [Vector2(0, 0), Vector2(w * 0.4, l * 0.14), Vector2(w * 0.5, l * 0.5), Vector2(w * 0.38, l * 0.84), Vector2(w * 0.12, l * 0.99),
		Vector2(-w * 0.16, l * 0.97), Vector2(-w * 0.42, l * 0.8), Vector2(-w * 0.5, l * 0.48), Vector2(-w * 0.38, l * 0.14)]


static func _heater_pts(l: float, w: float) -> Array[Vector2]:
	return [Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(w * 0.5, l * 0.42), Vector2(w * 0.4, l * 0.68), Vector2(w * 0.2, l * 0.88),
		Vector2(0, l), Vector2(-w * 0.2, l * 0.88), Vector2(-w * 0.4, l * 0.68), Vector2(-w * 0.5, l * 0.42)]


static func _diamond_pts(l: float, w: float) -> Array[Vector2]:
	return [Vector2(0, 0), Vector2(w * 0.5, l * 0.38), Vector2(0, l), Vector2(-w * 0.5, l * 0.38)]


## A narrow pointed feather curving to a sharp tip, its trailing side cut straighter.
static func _talon_pts(l: float, w: float) -> Array[Vector2]:
	return [Vector2(0, 0), Vector2(w * 0.42, l * 0.12), Vector2(w * 0.5, l * 0.4), Vector2(w * 0.3, l * 0.78), Vector2(w * 0.06, l),
		Vector2(-w * 0.2, l * 0.8), Vector2(-w * 0.42, l * 0.45), Vector2(-w * 0.36, l * 0.12)]


# --- Strips ---------------------------------------------------------------------------

## A flat strip in XY along [param pts], [param wl] out to its left and [param wr] to
## its right at each point (tapers, saw edges), shading from [param c0] to [param c1].
## Lit as facing the rear (-z); the material draws both sides.
static func _ribbon(b: Dictionary, pts: Array, wl: Array, wr: Array, c0: Color, c1: Color, glow := false) -> void:
	var layer := "glow" if glow else "solid"
	var st: SurfaceTool = b[layer]
	var n := pts.size()
	var ls: Array[Vector3] = []
	var rs: Array[Vector3] = []
	var nl: Array[Vector3] = []
	var nr: Array[Vector3] = []
	for i in n:
		var tangent: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var side := Vector3(-tangent.y, tangent.x, 0.0).normalized()
		ls.append(pts[i] + side * float(wl[i]))
		rs.append(pts[i] - side * float(wr[i]))
		nl.append((Vector3.FORWARD + side * 0.22).normalized())
		nr.append((Vector3.FORWARD - side * 0.22).normalized())
	for i in n - 1:
		var ca := c0.lerp(c1, float(i) / float(n - 1))
		var cb := c0.lerp(c1, float(i + 1) / float(n - 1))
		for tri in [[[ls[i], nl[i], ca], [rs[i], nr[i], ca], [rs[i + 1], nr[i + 1], cb]], [[ls[i], nl[i], ca], [rs[i + 1], nr[i + 1], cb], [ls[i + 1], nl[i + 1], cb]]]:
			# Wound to face the rear, so the light reads the right side.
			var v0: Vector3 = tri[0][0]
			var order: Array = tri if (tri[1][0] - v0).cross(tri[2][0] - v0).z > 0.0 else [tri[0], tri[2], tri[1]]
			for v in order:
				st.set_color(v[2])
				st.set_normal(v[1])
				st.add_vertex(v[0])
		b[layer + "_count"] += 6


## A solid strip seen from both sides: two ribbons [param gap] before and behind.
static func _sheet(b: Dictionary, pts: Array[Vector3], wl: Array, wr: Array, c0: Color, c1: Color, gap: float) -> void:
	for z in [-gap, gap]:
		_ribbon(b, pts.map(func(v: Vector3) -> Vector3: return v + Vector3(0, 0, z)), wl, wr, c0, c1)


## A faceted oval facing the rear (a gem, a boss, a note's head), tilted by [param tilt].
static func _oval(b: Dictionary, at: Vector3, rx: float, ry: float, color: Color, glow := false, tilt := 0.0) -> void:
	var pts: Array[Vector2] = []
	for i in 10:
		var u := TAU * i / 10.0
		pts.append(Vector2(cos(u) * rx, sin(u) * ry))
	StarGearArt._shape(b, pts, at, minf(rx, ry) * 0.5, color, glow, tilt)


## A thin flat line of light from [param from] to [param to], [param z] before them.
static func _stroke(b: Dictionary, from: Vector3, to: Vector3, w: float, color: Color, z: float) -> void:
	var off := Vector3(0, 0, z)
	_ribbon(b, [from + off, from.lerp(to, 0.5) + off, to + off], [w * 0.3, w * 0.5, w * 0.1], [w * 0.3, w * 0.5, w * 0.1], color, color, true)


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
