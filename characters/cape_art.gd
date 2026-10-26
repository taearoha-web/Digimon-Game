class_name CapeArt
extends Node3D
## The Dark Lord's cape: worn in the wing slot instead of wings, built in code. A
## long cape hangs from the shoulders under a capelet of feather scallops and a
## standing collar; it ripples and its pleats sway as the Lord walks, with the
## wings' "fly" mode it streams out behind and floats the Lord, and "fold" gathers
## it up out of the way. It answers to the same clips as a wing rig (Idle, Flap,
## Glide, Fold, Unfold on an AnimationPlayer), so HeroVisual drives it like any
## pair of wings. The cloth itself is shaped by shaders/cape.gdshader.
##
## Two designs:
##   Lv.100 (ผ้าคลุมราชันอีกา)              crimson velvet with deep pleats, gold trim
##                                          and filigree, a gold raven crest in a ring of
##                                          dots, a black capelet of gold-edged feather
##                                          scales, a black-and-gold standing collar, ruby
##                                          clasps and a quilted black lining
##   100 stars (ผ้าคลุมจักรพรรดิอีกาทมิฬ)    galaxy cloth (drifting nebula, twinkling
##                                          stars), a crowned raven on a gold sunburst, a hem
##                                          of raven feathers whose tips glow, a capelet of
##                                          indigo feather scales edged in glowing gold and
##                                          a gold collar set with violet gems
##
## Model space is the chibi's (x side, y up, z front), like the wing GLBs.

const SHADER := preload("res://shaders/cape.gdshader")
const TOP_Y := 0.79
const BACK_Z := -0.11
const LENGTH := 0.8
const STAR_LENGTH := 0.9
## Authored size to the chibi's (its model is small: the wings' root sits at y 0.51).
const FIT := 0.66

## 0 hangs, 1 streams back and up (flying).
@export var billow := 0.15:
	set(value):
		billow = value
		_push("billow", value)
## 0 open, 1 gathered up.
@export var fold := 0.0:
	set(value):
		fold = value
		_push("fold", value)

var star := false
## Everything is authored at TOP_Y / BACK_Z and fitted onto the chibi's back by this node.
var _fit: Node3D
var _materials: Array[ShaderMaterial] = []


static func build(p_star: bool) -> Node3D:
	var cape := CapeArt.new()
	cape.star = p_star
	cape.name = "Wings_star_darklord" if p_star else "Wings_darklord"
	cape._make()
	return cape


func _make() -> void:
	# The chibi's shoulder blades sit at about y 0.57, z -0.09 in model space.
	_fit = Node3D.new()
	_fit.name = "Fit"
	_fit.scale = Vector3.ONE * FIT
	_fit.position = Vector3(0, 0.57 - TOP_Y * FIT, -0.09 - BACK_Z * FIT)
	add_child(_fit)
	if star:
		var palette := {"outer_color": Color("4a2a9a"), "outer_deep": Color("0e0824"), "lining_color": Color("5a1430"),
			"trim_color": Color("ffd36b"), "glow_color": Color("ff9ae6"), "style": 1.0}
		_layer(palette.merged({"kind": 0.0, "top_width": 0.3, "hem_width": 0.74, "cape_length": STAR_LENGTH,
			"hem_curve": 0.1, "wrap": 0.2, "fold_depth": 0.06, "folds": 5.5, "crest": 1.0, "feather_len": 0.17}, true), 52, 34)
		_layer(palette.merged({"kind": 1.0, "outer_color": Color("3a2378"), "outer_deep": Color("0c0620"), "behind": 0.05,
			"top_width": 0.34, "hem_width": 0.66, "cape_length": 0.24, "hem_curve": 0.32, "wrap": 0.26, "fold_depth": 0.014,
			"folds": 4.0, "crest": 0.0, "scallop": 11.0, "phase": 0.6, "stiff": 0.3}, true), 22, 12)
		_layer(palette.merged({"kind": 2.0, "top_width": 0.1, "hem_width": 0.17, "cape_length": 0.075, "crest": 0.0}, true), 18, 6)
	else:
		var palette := {"outer_color": Color("a01e30"), "outer_deep": Color("4e0a16"), "lining_color": Color("150d12"),
			"trim_color": Color("f0c058"), "glow_color": Color("ffd88a"), "style": 0.0}
		_layer(palette.merged({"kind": 0.0, "top_width": 0.3, "hem_width": 0.66, "cape_length": LENGTH,
			"hem_curve": 0.06, "wrap": 0.2, "fold_depth": 0.055, "folds": 5.0, "crest": 1.0}, true), 48, 32)
		_layer(palette.merged({"kind": 1.0, "outer_color": Color("2a1d26"), "outer_deep": Color("120c12"), "behind": 0.05,
			"top_width": 0.33, "hem_width": 0.62, "cape_length": 0.21, "hem_curve": 0.32, "wrap": 0.26, "fold_depth": 0.012,
			"folds": 4.0, "crest": 0.0, "scallop": 11.0, "phase": 0.6, "stiff": 0.3}, true), 22, 12)
		_layer(palette.merged({"kind": 2.0, "outer_deep": Color("5a0c1a"), "lining_color": Color("1a1016"),
			"top_width": 0.1, "hem_width": 0.16, "cape_length": 0.07, "crest": 0.0}, true), 18, 6)
	_clasps()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	var library := AnimationLibrary.new()
	library.add_animation("Idle", _clip(2.4, [[0.0, 0.1], [1.2, 0.2], [2.4, 0.1]], [[0.0, 0.0]], true))
	library.add_animation("Flap", _clip(1.6, [[0.0, 0.5], [0.8, 0.72], [1.6, 0.5]], [[0.0, 0.0]], true))
	library.add_animation("Glide", _clip(1.0, [[0.0, 0.92], [0.5, 1.0], [1.0, 0.92]], [[0.0, 0.0]], true))
	library.add_animation("Fold", _clip(0.35, [[0.0, 0.2], [0.35, 0.05]], [[0.0, 0.0], [0.35, 1.0]], false))
	library.add_animation("Unfold", _clip(0.35, [[0.0, 0.05], [0.35, 0.2]], [[0.0, 1.0], [0.35, 0.0]], false))
	player.add_animation_library("", library)
	player.play("Idle")


## Writes a cape parameter to every layer.
func _push(key: String, value: float) -> void:
	for mat in _materials:
		mat.set_shader_parameter(key, value)


## A clip animating billow and fold through the given [time, value] keys.
func _clip(length: float, billow_keys: Array, fold_keys: Array, loop: bool) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for spec in [["billow", billow_keys], ["fold", fold_keys]]:
		var track := anim.add_track(Animation.TYPE_VALUE)
		# The player's root is the cape itself.
		anim.track_set_path(track, NodePath(".:" + String(spec[0])))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for key in spec[1]:
			anim.track_insert_key(track, float(key[0]), float(key[1]))
	return anim


## One cloth layer: a UV grid (u across, v down) drawn both sides; the cape shader
## places every vertex, so the grid carries UVs and a rest shape close to the
## cloth's (item icons frame the mesh by it).
func _layer(params: Dictionary, cols: int, rows: int) -> void:
	var top_width: float = params.get("top_width", 0.4)
	var hem_width: float = params.get("hem_width", 0.7)
	var length: float = params.get("cape_length", LENGTH)
	var collar: bool = float(params.get("kind", 0.0)) > 1.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows + 1:
		var v := float(r) / float(rows)
		for c in cols + 1:
			var u := float(c) / float(cols)
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3(0, 0, -1))
			if collar:
				var a := (u * 2.0 - 1.0) * 1.45
				st.add_vertex(Vector3(sin(a) * hem_width, TOP_Y + (1.0 - v) * length, BACK_Z + 0.1 - cos(a) * hem_width))
			else:
				var half := lerpf(top_width, hem_width, pow(v, 0.8)) * 0.5
				st.add_vertex(Vector3((u * 2.0 - 1.0) * half, TOP_Y - v * length * 1.05, BACK_Z - v * 0.06))
	for r in rows:
		for c in cols:
			var i := r * (cols + 1) + c
			st.add_index(i)
			st.add_index(i + cols + 1)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + cols + 1)
			st.add_index(i + cols + 2)
	var mesh := MeshInstance3D.new()
	mesh.name = "CapeLayer"
	mesh.mesh = st.commit()
	mesh.set_meta("no_outline", true)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Generous bounds: the shader moves the hem well behind and above its rest place.
	mesh.custom_aabb = AABB(Vector3(-0.8, -0.4, -1.4), Vector3(1.6, 2.0, 1.8))
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("top_y", TOP_Y)
	mat.set_shader_parameter("back_z", BACK_Z)
	for key in params:
		mat.set_shader_parameter(key, params[key])
	mat.set_shader_parameter("billow", billow)
	mat.set_shader_parameter("fold", fold)
	mesh.material_override = mat
	_materials.append(mat)
	_fit.add_child(mesh)


## Gem clasps where the cape meets the shoulders: rubies in gold for the Lv.100
## cape, violet stones for the star cape.
func _clasps() -> void:
	var root := Node3D.new()
	root.name = "Clasps"
	_fit.add_child(root)
	var metal := MeshKit.toon(Color("f0c058"), {"emission": 0.2 if star else 0.08})
	var gem := MeshKit.toon(Color("b06bff") if star else Color("e8243c"), {"emission": 1.2 if star else 0.6})
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 0.205, TOP_Y - 0.035, BACK_Z + 0.12)
		_piece(root, MeshKit.cylinder(), metal, at, Vector3(0.075, 0.022, 0.075), Vector3(90, 0, 0))
		_piece(root, MeshKit.sphere_low(), gem, at + Vector3(0, 0, 0.016), Vector3(0.05, 0.05, 0.035))


func _piece(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, size: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshKit.part(parent, mesh, mat, at, size, rot)
	mi.set_meta("no_outline", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
