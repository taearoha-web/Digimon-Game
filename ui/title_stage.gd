class_name TitleStage
extends Node3D
## The character select scene: the painted sky platform (assets/ui/title_stage.jpg)
## hangs as a backdrop in front of the camera, and the hero of each save slot stands
## in 3D on the painting's numbered rune circles, slot N on circle N.
##
## The painting looks down at the platform at about 19 degrees (its circle
## ellipses are roughly 1:3), so the camera does too: a hero's feet are where the
## ray through the circle's centre meets the ground plane, and the hero is scaled to
## the circle's on-screen width. Every aspect ratio crops the painting like a
## "cover" fit around KEEP (all ten circles, the heads above them and the steps), and
## a tall screen shows the painting's full width on its sky colour.

const IMAGE_PATH := "res://assets/ui/title_stage.jpg"
const IMAGE_SIZE := Vector2(1536, 1024)
## Circle centre (px in the painting) and its width (px), for slots 1..10.
const SPOTS := [
	[Vector2(286, 411), 214.0], [Vector2(526, 411), 210.0], [Vector2(768, 411), 215.0], [Vector2(1007, 411), 204.0], [Vector2(1248, 411), 201.0],
	[Vector2(259, 665), 234.0], [Vector2(512, 664), 234.0], [Vector2(768, 664), 236.0], [Vector2(1023, 664), 232.0], [Vector2(1278, 664), 231.0]]
## The part of the painting that must stay in view: every circle, the name plates
## above the back row's heads, and room under the front row for the button bar.
const KEEP := Rect2(118, 212, 1300, 600)
const PITCH := -19.0
const FOV := 30.0
const CAMERA_HEIGHT := 3.2
## The painting sits far behind everything a hero can be.
const BACKDROP_DEPTH := 120.0
## Hero height on screen per pixel of its circle's on-screen width.
const HERO_TO_CIRCLE := 0.78
## Height / width of the painted circle ellipses, back row and front row.
const ROW_FLATTENING := [0.29, 0.34]
const SKY := Color("4f9be6")
const GOLD := Color("ffd36a")

var camera: Camera3D
## slot -> {visual, root, feet, scale, height, shadow}
var heroes: Dictionary = {}
var selected := 0
## Screen (canvas) rectangle the painting covers.
var image_rect := Rect2()
var _backdrop: MeshInstance3D
var _texture: Texture2D
var _ring: Node3D
var _ring_tween: Tween
var _canvas := Vector2(1280, 720)


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe9f5")
	env.ambient_light_energy = 0.75
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# A warm key from the painting's sun (upper left) and a cool sky rim.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -38, 0)
	key.light_color = Color("fff1dc")
	key.light_energy = 1.15
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_color = Color("b8dcff")
	rim.light_energy = 0.55
	add_child(rim)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.2
	camera.far = BACKDROP_DEPTH * 1.6
	camera.position = Vector3(0, CAMERA_HEIGHT, 0)
	camera.rotation_degrees = Vector3(PITCH, 0, 0)
	add_child(camera)
	camera.make_current()
	# Loaded, not preloaded: the painting is released with the title screen.
	_texture = load(IMAGE_PATH) as Texture2D
	_backdrop = MeshInstance3D.new()
	_backdrop.name = "Backdrop"
	var quad := QuadMesh.new()
	_backdrop.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.disable_receive_shadows = true
	_backdrop.material_override = mat
	_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_backdrop)
	_ring = _make_ring()
	_ring.visible = false
	add_child(_ring)


## Fits the painting and every hero to a canvas of [param canvas] (the viewport's
## visible rectangle, the space UI controls and Camera3D projections share).
func layout(canvas: Vector2) -> void:
	if canvas.x < 2.0 or canvas.y < 2.0 or camera == null:
		return
	_canvas = canvas
	image_rect = cover_rect(canvas)
	# The backdrop quad exactly under the painting's screen rectangle, facing the camera.
	var a := camera.project_position(image_rect.position, BACKDROP_DEPTH)
	var b := camera.project_position(image_rect.position + Vector2(image_rect.size.x, 0), BACKDROP_DEPTH)
	var c := camera.project_position(image_rect.position + Vector2(0, image_rect.size.y), BACKDROP_DEPTH)
	(_backdrop.mesh as QuadMesh).size = Vector2(a.distance_to(b), a.distance_to(c))
	_backdrop.global_transform = Transform3D(camera.global_basis, camera.project_position(image_rect.get_center(), BACKDROP_DEPTH))
	for slot in heroes:
		_place(int(slot))
	if selected > 0 and heroes.has(selected):
		_place_ring(selected)


## Where the painting lies on a canvas: a cover fit centred on KEEP; a screen too
## narrow for KEEP's width gets the full width of KEEP instead (sky above and below).
static func cover_rect(canvas: Vector2) -> Rect2:
	var scale := maxf(canvas.x / IMAGE_SIZE.x, canvas.y / IMAGE_SIZE.y)
	if canvas.x / scale < KEEP.size.x:
		scale = canvas.x / KEEP.size.x
	var view := canvas / scale
	var centre := KEEP.get_center()
	if view.x <= IMAGE_SIZE.x:
		centre.x = clampf(centre.x, view.x * 0.5, IMAGE_SIZE.x - view.x * 0.5)
	else:
		centre.x = IMAGE_SIZE.x * 0.5
	if view.y < KEEP.size.y:
		# A very wide screen: keep the heads, give up more of the steps below.
		centre.y = KEEP.position.y + view.y * 0.5 + (KEEP.size.y - view.y) * 0.3
	elif view.y <= IMAGE_SIZE.y:
		centre.y = clampf(centre.y, view.y * 0.5, IMAGE_SIZE.y - view.y * 0.5)
	else:
		centre.y = IMAGE_SIZE.y * 0.5
	return Rect2(canvas * 0.5 - centre * scale, IMAGE_SIZE * scale)


## Canvas position of a point of the painting.
func to_screen(image_point: Vector2) -> Vector2:
	return image_rect.position + image_point * (image_rect.size.x / IMAGE_SIZE.x)


func spot_screen(slot: int) -> Vector2:
	return to_screen(SPOTS[slot - 1][0])


## The circle's width on screen.
func spot_width(slot: int) -> float:
	return float(SPOTS[slot - 1][1]) * image_rect.size.x / IMAGE_SIZE.x


## Ground point under the circle's centre on screen.
func spot_ground(slot: int) -> Vector3:
	var at := spot_screen(slot)
	var origin := camera.project_ray_origin(at)
	var normal := camera.project_ray_normal(at)
	if normal.y > -0.0001:
		return origin + normal * 10.0
	return origin + normal * (-origin.y / normal.y)


## Puts the hero of [param slot] (preview = Game.slot_overview) on its circle.
## [param arrival]: the hero was just created and lands in a column of light.
func add_hero(slot: int, overview: Dictionary, arrival := false) -> void:
	remove_hero(slot, false)
	var root := Node3D.new()
	root.name = "Slot%d" % slot
	add_child(root)
	var shadow := MeshInstance3D.new()
	shadow.mesh = VfxKit.quad(Vector2(1.0, 1.0))
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = VfxKit.soft_dot()
	smat.albedo_color = Color(0.04, 0.05, 0.14, 0.42)
	shadow.material_override = smat
	shadow.rotation_degrees = Vector3(-90, 0, 0)
	shadow.position = Vector3(0, 0.02, 0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)
	var visual := HeroVisual.new()
	root.add_child(visual)
	visual.setup(StringName(overview.get("class", ClassData.START)), "", true, overview.get("equip", {}), overview.get("look", {}))
	var height := HeroVisual.CHIBI_HEIGHT if visual.chibi else HeroVisual.HEIGHT
	heroes[slot] = {"root": root, "visual": visual, "shadow": shadow, "height": height, "scale": 1.0, "feet": Vector3.ZERO}
	_place(slot)
	if arrival:
		_arrive(slot)


func remove_hero(slot: int, effect := true) -> void:
	if not heroes.has(slot):
		return
	var entry: Dictionary = heroes[slot]
	heroes.erase(slot)
	var root: Node3D = entry.root
	if selected == slot:
		select(0)
	if effect and is_instance_valid(root):
		VfxKit.flash(self, entry.feet + Vector3.UP * entry.height * entry.scale * 0.5, Color("c9e4ff"), 2.0 * entry.scale, 0.35)
		var tween := root.create_tween()
		tween.tween_property(root, "scale", Vector3(0.05, 1.4, 0.05), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(root.queue_free)
	elif is_instance_valid(root):
		root.queue_free()


func _place(slot: int) -> void:
	var entry: Dictionary = heroes[slot]
	var feet := spot_ground(slot)
	var root: Node3D = entry.root
	# On-screen pixels per metre straight up at the feet, so the hero matches its circle.
	var up_px := absf(camera.unproject_position(feet).y - camera.unproject_position(feet + Vector3.UP).y)
	var scale := HERO_TO_CIRCLE * spot_width(slot) / maxf(up_px * float(entry.height), 0.001)
	entry.feet = feet
	entry.scale = scale
	root.global_position = feet
	(entry.visual as Node3D).scale = Vector3.ONE * scale
	# Face the camera, as the circles face the viewer.
	var to_camera := camera.global_position - feet
	(entry.visual as Node3D).rotation.y = atan2(to_camera.x, to_camera.z)
	(entry.shadow as Node3D).scale = Vector3.ONE * scale * 1.25


## Canvas point just above the hero's head (for its name plate).
func head_screen(slot: int) -> Vector2:
	if not heroes.has(slot):
		return spot_screen(slot)
	var entry: Dictionary = heroes[slot]
	var root: Node3D = entry.root
	var top: Vector3 = entry.feet + Vector3.UP * float(entry.height) * float(entry.scale) * root.scale.y
	return camera.unproject_position(top)


## The slot whose hero is under a canvas point (0 when none). The hero's body and
## its circle both count; the nearest wins when they overlap.
func slot_at(point: Vector2) -> int:
	var best := 0
	var best_distance := INF
	for slot in heroes:
		var feet := spot_screen(int(slot))
		var head := head_screen(int(slot))
		var half := spot_width(int(slot)) * 0.5
		var body := Rect2(Vector2(feet.x - half * 0.62, head.y), Vector2(half * 1.24, feet.y - head.y + half * 0.3))
		var on_circle := Vector2((point.x - feet.x) / half, (point.y - feet.y) / (half * 0.36)).length() <= 1.0
		if not body.has_point(point) and not on_circle:
			continue
		var distance := point.distance_to(Vector2(feet.x, (feet.y + head.y) * 0.5))
		if distance < best_distance:
			best_distance = distance
			best = int(slot)
	return best


## Lights the circle under [param slot] (0 clears it) and lets that hero cheer.
func select(slot: int) -> void:
	if slot == selected and (slot == 0 or _ring.visible):
		return
	selected = slot if heroes.has(slot) else 0
	_ring.visible = selected > 0
	if selected == 0:
		return
	_place_ring(selected)
	var visual: HeroVisual = heroes[selected].visual
	if visual.anim and visual.anim.has_animation("Cheer"):
		visual.action("Cheer")


func _place_ring(slot: int) -> void:
	var entry: Dictionary = heroes[slot]
	var feet: Vector3 = entry.feet
	_ring.global_position = Vector3(feet.x, 0.03, feet.z)
	# Sized on screen to the painted ellipse: its width, and its height from the
	# painting's own flattening (the painting is nearly orthographic, the camera is not).
	var right := Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
	var ahead := Vector3(-camera.global_basis.z.x, 0.0, -camera.global_basis.z.z).normalized()
	var at := camera.unproject_position(feet)
	var px_across := absf(camera.unproject_position(feet + right).x - at.x)
	var px_deep := absf(camera.unproject_position(feet + ahead).y - at.y)
	var width := spot_width(slot) * 0.5
	var height := width * float(ROW_FLATTENING[0 if slot <= 5 else 1])
	_ring.basis = Basis(right * (width / maxf(px_across, 0.001)), Vector3.UP, -ahead * (height / maxf(px_deep, 0.001)))


## A gold ring of light hugging the painted circle, breathing slowly.
func _make_ring() -> Node3D:
	var holder := Node3D.new()
	holder.name = "SelectRing"
	var ring := MeshInstance3D.new()
	ring.mesh = VfxKit.torus_mesh(0.9, 1.0, 48, 6)
	ring.scale = Vector3(1.0, 0.02, 1.0)
	# Alpha-blended, not additive: added onto the painted blue-white circle a gold
	# glow turns white.
	ring.material_override = VfxKit._glow(Color("ffb22e"), 0.9, false)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ring)
	var glow := MeshInstance3D.new()
	glow.mesh = VfxKit.quad(Vector2(2.3, 2.3))
	var gmat := VfxKit._glow(Color("ffc24a"), 0.55)
	gmat.albedo_texture = VfxKit.soft_dot()
	glow.material_override = gmat
	glow.rotation_degrees = Vector3(-90, 0, 0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(glow)
	_ring_tween = holder.create_tween().set_loops()
	_ring_tween.tween_property(gmat, "albedo_color:a", 0.25, 0.9).set_trans(Tween.TRANS_SINE)
	_ring_tween.tween_property(gmat, "albedo_color:a", 0.6, 0.9).set_trans(Tween.TRANS_SINE)
	return holder


## The new hero lands in a column of light on its circle.
func _arrive(slot: int) -> void:
	var entry: Dictionary = heroes[slot]
	var root: Node3D = entry.root
	var size := float(entry.height) * float(entry.scale)
	VfxKit.pillar(self, entry.feet, Color("bfe3ff"), size * 2.6, size * 0.45, 0.9, Color.WHITE)
	VfxArt.rays_burst(self, entry.feet + Vector3.UP * size * 0.45, GOLD, size * 1.2, 0.6)
	VfxArt.motes(self, entry.feet + Vector3.UP * size * 0.2, Color("d8ecff"), "star", 26, size * 0.45, size, 1.4)
	root.scale = Vector3(0.05, 1.6, 0.05)
	var tween := root.create_tween()
	tween.tween_interval(0.18)
	tween.tween_property(root, "scale", Vector3.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var visual: HeroVisual = entry.visual
	if visual.anim and visual.anim.has_animation("Cheer"):
		visual.action("Cheer")
