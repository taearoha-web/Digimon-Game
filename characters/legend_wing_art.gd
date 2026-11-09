class_name LegendWingArt
extends Node3D
## The look of the Legendary Guild Wings (LegendWings): a dedicated pair built in code
## (LegendWingMesh), not a reused class pair. Two great upswept gold wings with three
## rows of clearly inked feathers (long primaries curving up and out, secondaries,
## rounded coverts), a smaller pair below, and a gold halo crowned with turning rays and
## gems in the guild's colour between them. Everything wears one shared unshaded
## material (legend_wing.gdshader: prismatic sweep, glowing tips, rippling feathers on
## TIME), so the pair is radiant in every zone and at night and costs five draw calls.
##
## It answers to the wing clips (Idle, Flap, Glide, Fold, Unfold on an AnimationPlayer),
## so HeroVisual poses it like any pair: the clips drive [member beat] and [member fold],
## which place the four wing nodes. Golden motes drift down from it (LegendSparkles,
## VfxBudget-counted; never on the low setting, at memory pressure 2 or in a crowd's
## light dress), and a fresh pair arrives with a radiant burst.
##
## Model space is the chibi's (x side, y up, z front) like the wing GLBs; everything is
## authored in metres at the hero's size under the Fit node, on the shoulder blades.

const SHADER := preload("res://shaders/legend_wing.gdshader")
const SPARKLE_COLOR := Color(1.0, 0.74, 0.22, 0.85)
const SPARKLES := 16
## The chibi's model space is this many times smaller than the hero in metres.
const FIT := 1.0 / 2.45
## The shoulder blades in model space.
const BACK := Vector3(0.0, 0.57, -0.09)
## Pivots (metres, from the shoulder blades) of the right wings and the halo.
const UPPER_PIVOT := Vector3(0.1, 0.06, -0.1)
const LOWER_PIVOT := Vector3(0.13, -0.4, -0.1)
const HALO_AT := Vector3(0.0, 0.6, -0.26)
const BURST_COLOR := Color(1.0, 0.85, 0.42)

## Wing beat: 0 rests open, up to 1 raised, down to -1 lowered.
@export var beat := 0.0:
	set(value):
		beat = value
		_place()
## 0 spread, 1 folded down behind the back.
@export var fold := 0.0:
	set(value):
		fold = value
		_place()

## The halo's arrival swell (1 at rest).
var halo_pop := 1.0:
	set(value):
		halo_pop = value
		_place()
var guild := 0
## How far the halo sits above HALO_AT (a big-headed body wears it higher).
var _halo_lift := 0.0
var _fit: Node3D
var _upper: Array[MeshInstance3D] = []
var _lower: Array[MeshInstance3D] = []
var _halo: MeshInstance3D
static var _material: ShaderMaterial
static var _mote_material: StandardMaterial3D
static var _library: AnimationLibrary


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		MaterialKeeper.keep(_material)
	return _material


## The pair as worn: `item` is a LegendWings pair. `light` is a crowd's light dress (no
## motes); `fresh` plays the arrival burst (a pair just received or put on).
static func build(item: Dictionary, light := false, fresh := false) -> Node3D:
	var art := LegendWingArt.new()
	art.guild = int(item.get("legend_guild", 0))
	art.name = "Wings_legend_%d" % art.guild
	art._make()
	if sparkles_allowed(light):
		sparkles(art._fit)
	if fresh and not light:
		art.ready.connect(art._burst, CONNECT_ONE_SHOT)
	return art


func _make() -> void:
	_fit = Node3D.new()
	_fit.name = "Fit"
	_fit.scale = Vector3.ONE * FIT
	_fit.position = BACK
	add_child(_fit)
	var gold := material()
	for side in [1.0, -1.0]:
		_upper.append(_piece("Wing" + ("R" if side > 0 else "L"), LegendWingMesh.wing(), gold))
		_lower.append(_piece("Lower" + ("R" if side > 0 else "L"), LegendWingMesh.lower(), gold))
	_halo = _piece("Halo", LegendWingMesh.halo(guild), gold)
	_place()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	player.add_animation_library("", _clips())
	player.play("Idle")


func _piece(piece_name: String, mesh: ArrayMesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = piece_name
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader inks its own feathers: no hull outline (an extra pass) on top.
	mi.set_meta("no_outline", true)
	_fit.add_child(mi)
	return mi


## Places the wings for the current beat and fold (the left ones mirror the right).
func _place() -> void:
	if _fit == null:
		return
	var mirror := Basis.from_scale(Vector3(-1, 1, 1))
	# Folding rolls the wings down along the back like a mantle and draws them in.
	var up := Basis.from_euler(Vector3(deg_to_rad(-10.0 + 6.0 * fold), deg_to_rad(22.0 + 26.0 * fold), deg_to_rad(beat * 20.0 - 112.0 * fold)))
	up = up.scaled(Vector3.ONE * lerpf(1.0, 0.52, fold))
	var low := Basis.from_euler(Vector3(deg_to_rad(8.0), deg_to_rad(34.0 + 16.0 * fold), deg_to_rad(-beat * 10.0 - 30.0 * fold)))
	low = low.scaled(Vector3.ONE * lerpf(1.0, 0.6, fold))
	for i in 2:
		var m := Basis.IDENTITY if i == 0 else mirror
		var flip := Vector3(1, 1, 1) if i == 0 else Vector3(-1, 1, 1)
		_upper[i].transform = Transform3D(m * up, UPPER_PIVOT * flip)
		_lower[i].transform = Transform3D(m * low, LOWER_PIVOT * flip)
	if _halo != null:
		_halo.position = HALO_AT + Vector3(0, _halo_lift, 0)
		_halo.scale = Vector3.ONE * lerpf(1.0, 0.7, fold) * halo_pop


## On the KayKit body (the world players' rig, a far bigger head) the pair is a little
## larger and the halo rides above the helmet.
func fit_big_head() -> void:
	_fit.scale = Vector3.ONE * FIT * 1.12
	_halo_lift = 0.36
	_place()


## The wing clips, shared by every pair (they key this node's beat and fold).
static func _clips() -> AnimationLibrary:
	if _library == null:
		_library = AnimationLibrary.new()
		_library.add_animation("Idle", _clip(3.2, [[0.0, 0.0], [1.6, 0.16], [3.2, 0.0]], [[0.0, 0.0]], true))
		_library.add_animation("Flap", _clip(1.1, [[0.0, -0.55], [0.5, 0.75], [1.1, -0.55]], [[0.0, 0.0]], true))
		_library.add_animation("Glide", _clip(2.0, [[0.0, 0.3], [1.0, 0.4], [2.0, 0.3]], [[0.0, 0.0]], true))
		_library.add_animation("Fold", _clip(0.4, [[0.0, 0.0], [0.4, -0.2]], [[0.0, 0.0], [0.4, 1.0]], false))
		_library.add_animation("Unfold", _clip(0.5, [[0.0, -0.2], [0.3, 0.5], [0.5, 0.0]], [[0.0, 1.0], [0.3, 0.0]], false))
	return _library


## A clip animating beat and fold through the given [time, value] keys.
static func _clip(length: float, beat_keys: Array, fold_keys: Array, loop: bool) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for spec in [["beat", beat_keys], ["fold", fold_keys]]:
		var track := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, NodePath(".:" + String(spec[0])))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for key in spec[1]:
			anim.track_insert_key(track, float(key[0]), float(key[1]))
	return anim


## Motes are decoration: never on the low setting or under memory pressure 2
## (VfxBudget-safe), and never for the light dress of a crowd of world players.
static func sparkles_allowed(light := false) -> bool:
	return not light and VfxBudget.quality() > 0 and MemoryGuard.pressure < 2


static func mote_material() -> StandardMaterial3D:
	if _mote_material == null:
		_mote_material = StandardMaterial3D.new()
		MaterialKeeper.keep(_mote_material)
		_mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mote_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_mote_material.vertex_color_use_as_albedo = true
		_mote_material.albedo_texture = VfxKit.soft_dot()
		_mote_material.albedo_color = SPARKLE_COLOR
	return _mote_material


## Golden motes drifting slowly down from the whole span of the wings.
static func sparkles(fit: Node3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "LegendSparkles"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = mote_material()
	p.mesh = quad
	p.amount = VfxBudget.count(SPARKLES)
	p.lifetime = 3.4
	p.preprocess = 3.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.5, 0.7, 0.25)
	p.direction = Vector3.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.18
	p.gravity = Vector3(0, -0.12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.25
	p.local_coords = false
	p.color_ramp = VfxKit._fade_ramp()
	p.position = Vector3(0, 0.8, -0.35)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fit.add_child(p)
	return p


## The arrival: the wings sweep open from folded, the halo swells in, and a radiant
## flash with rays and a ring of gold sparks (VfxKit, budget-counted) bursts behind.
func _burst() -> void:
	fold = 1.0
	var player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player != null:
		player.play("Unfold")
		player.queue("Idle")
	halo_pop = 0.2
	var tween := create_tween()
	tween.tween_property(self, "halo_pop", 1.25, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "halo_pop", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	var at := _fit.to_global(HALO_AT + Vector3(0, -0.15, -0.1))
	VfxKit.flash(_fit, at, BURST_COLOR, 3.0, 0.6)
	VfxKit.sparks(_fit, at, BURST_COLOR, 26, 3.6, 1.0)
