class_name CapeArt
extends Node3D
## The Dark Lord's cape: worn in the wing slot instead of wings, built in code. It
## hangs from the shoulders under a fur (or star-gold) mantle and ripples as the
## Lord walks; with the wings' "fly" mode it billows out and floats the Lord, and
## "fold" gathers it up out of the way. It answers to the same clips as a wing rig
## (Idle, Flap, Glide, Fold, Unfold on an AnimationPlayer), so HeroVisual drives it
## like any pair of wings.
##
## Two designs:
##   Lv.100 (ผ้าคลุมราชันอีกา)            crimson velvet, black lining, gold trim, a raven
##                                        crest on the back and a dark fur collar
##   100 stars (ผ้าคลุมจักรพรรดิอีกาทมิฬ)  two layers (imperial violet over crimson) with a
##                                        tattered hem, glowing gold runes along the trim,
##                                        a crowned raven crest, a gold mantle with
##                                        pauldrons and a slowly turning rune halo
##
## Model space is the chibi's (x side, y up, z front), like the wing GLBs: the
## cape's top edge sits across the shoulder blades at y ~0.78, z ~-0.1.

const SHADER := preload("res://shaders/cape.gdshader")
const TOP_Y := 0.79
const BACK_Z := -0.11
const LENGTH := 0.76
const STAR_LENGTH := 0.86

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
var _materials: Array[ShaderMaterial] = []
var _halo: Node3D


static func build(p_star: bool) -> Node3D:
	var cape := CapeArt.new()
	cape.star = p_star
	cape.name = "Wings_star_darklord" if p_star else "Wings_darklord"
	cape._make()
	return cape


func _make() -> void:
	if star:
		# The violet outer layer over a crimson inner one that shows at the hem.
		_layer(Color("2a1446"), Color("120a22"), Color("ffcf5a"), STAR_LENGTH, 0.40, 0.70, 1.0, 1.0, 0.0)
		_layer(Color("8a1a2e"), Color("3a0a14"), Color("ff7a4a"), STAR_LENGTH + 0.06, 0.36, 0.76, 0.0, 0.0, 0.012)
		_mantle(true)
		_halo = _rune_halo()
	else:
		_layer(Color("8e1c2a"), Color("1a0c10"), Color("e8b64a"), LENGTH, 0.38, 0.64, 0.0, 1.0, 0.0)
		_mantle(false)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	var library := AnimationLibrary.new()
	library.add_animation("Idle", _clip(2.4, [[0.0, 0.12], [1.2, 0.24], [2.4, 0.12]], [[0.0, 0.0]], true))
	library.add_animation("Flap", _clip(1.6, [[0.0, 0.5], [0.8, 0.72], [1.6, 0.5]], [[0.0, 0.0]], true))
	library.add_animation("Glide", _clip(1.0, [[0.0, 0.92], [0.5, 1.0], [1.0, 0.92]], [[0.0, 0.0]], true))
	library.add_animation("Fold", _clip(0.35, [[0.0, 0.2], [0.35, 0.05]], [[0.0, 0.0], [0.35, 1.0]], false))
	library.add_animation("Unfold", _clip(0.35, [[0.0, 0.05], [0.35, 0.2]], [[0.0, 1.0], [0.35, 0.0]], false))
	player.add_animation_library("", library)
	player.play("Idle")


func _process(delta: float) -> void:
	if _halo != null:
		_halo.rotate_y(delta * 0.5)


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
		anim.track_set_path(track, NodePath("..:" + String(spec[0])))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for key in spec[1]:
			anim.track_insert_key(track, float(key[0]), float(key[1]))
	return anim


## One cloth layer: a grid hanging from the shoulders (u across, v down), drawn
## both sides (the lining shows on the inside), moved by the cape shader.
func _layer(outer: Color, lining: Color, trim: Color, length: float, top_width: float, hem_width: float,
		crest: float, raven: float, behind: float) -> void:
	var cols := 14
	var rows := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows + 1:
		var v := float(r) / float(rows)
		var half := lerpf(top_width, hem_width, pow(v, 0.8)) * 0.5
		for c in cols + 1:
			var u := float(c) / float(cols)
			var x := lerpf(-half, half, u)
			# Curved round the back at the top, opening a little lower down.
			var round := (1.0 - pow(2.0 * u - 1.0, 2.0)) * lerpf(0.06, 0.02, v)
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3(0, 0, -1))
			st.add_vertex(Vector3(x, TOP_Y - v * length, BACK_Z - behind - round - v * 0.05))
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
	mat.set_shader_parameter("outer_color", outer)
	mat.set_shader_parameter("lining_color", lining)
	mat.set_shader_parameter("trim_color", trim)
	mat.set_shader_parameter("cape_length", length)
	mat.set_shader_parameter("star", 1.0 if star else 0.0)
	mat.set_shader_parameter("crest", crest if star else raven)
	mat.set_shader_parameter("crown", crest)
	mat.set_shader_parameter("tatter", 1.0 if star else 0.0)
	mat.set_shader_parameter("phase", behind * 40.0)
	mat.set_shader_parameter("billow", billow)
	mat.set_shader_parameter("fold", fold)
	mesh.material_override = mat
	_materials.append(mat)
	add_child(mesh)


## The collar the cape hangs from: dark fur for the Lv.100 cape; a gold mantle with
## pauldrons, gem clasps and a raised collar for the star cape.
func _mantle(gold: bool) -> void:
	var root := Node3D.new()
	root.name = "Mantle"
	add_child(root)
	var fur := MeshKit.toon(Color("2a1e1a"))
	var metal := MeshKit.toon(Color("e8b64a"), {"emission": 0.15})
	var gem := MeshKit.toon(Color("ff3a4a") if not gold else Color("b06bff"), {"emission": 0.9})
	if not gold:
		# A ring of dark fur round the neck and over the shoulders.
		for i in 9:
			var a := lerpf(-1.25, 1.25, float(i) / 8.0)
			var at := Vector3(sin(a) * 0.17, TOP_Y + 0.02 - absf(a) * 0.015, BACK_Z + 0.06 - cos(a) * 0.1)
			_piece(root, MeshKit.sphere_low(), fur, at, Vector3(0.11, 0.08, 0.1))
	else:
		# Gold pauldrons over both shoulders, a raised collar and a band of gold scales.
		for side in [-1.0, 1.0]:
			_piece(root, MeshKit.hemisphere(), metal, Vector3(side * 0.2, TOP_Y - 0.01, BACK_Z + 0.07), Vector3(0.17, 0.12, 0.17))
			_piece(root, MeshKit.cone(), metal, Vector3(side * 0.25, TOP_Y + 0.07, BACK_Z + 0.05), Vector3(0.05, 0.12, 0.05), Vector3(0, 0, -side * 35.0))
		for i in 7:
			var a := lerpf(-0.9, 0.9, float(i) / 6.0)
			_piece(root, MeshKit.box(), metal, Vector3(sin(a) * 0.14, TOP_Y + 0.08, BACK_Z + 0.04 - cos(a) * 0.06), Vector3(0.06, 0.13, 0.02), Vector3(-15, rad_to_deg(a), 0))
	# Two gem clasps where the cape meets the shoulders.
	for side in [-1.0, 1.0]:
		_piece(root, MeshKit.cylinder(), metal, Vector3(side * 0.15, TOP_Y - 0.03, BACK_Z + 0.09), Vector3(0.07, 0.02, 0.07), Vector3(90, 0, 0))
		_piece(root, MeshKit.sphere_low(), gem, Vector3(side * 0.15, TOP_Y - 0.03, BACK_Z + 0.105), Vector3.ONE * 0.04)


## A slowly turning ring of gold runes behind the shoulders (star cape only).
func _rune_halo() -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "RuneHalo"
	pivot.position = Vector3(0, TOP_Y + 0.12, BACK_Z - 0.22)
	add_child(pivot)
	var glow := MeshKit.toon(Color("ffd36b"), {"emission": 1.6})
	var violet := MeshKit.toon(Color("b06bff"), {"emission": 1.4})
	_piece(pivot, MeshKit.torus(), glow, Vector3.ZERO, Vector3(0.42, 0.012, 0.42), Vector3(90, 0, 0))
	for i in 8:
		var a := TAU * float(i) / 8.0
		var at := Vector3(cos(a) * 0.21, sin(a) * 0.21, 0)
		_piece(pivot, MeshKit.box(), violet if i % 2 == 0 else glow, at, Vector3(0.03, 0.05, 0.01), Vector3(0, 0, rad_to_deg(a) + 45.0))
	return pivot


func _piece(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, size: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshKit.part(parent, mesh, mat, at, size, rot)
	mi.set_meta("no_outline", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
