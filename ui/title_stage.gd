class_name TitleStage
extends Node3D
## The character select scene: the painted sky platform (assets/ui/title_stage.jpg)
## hangs as a backdrop in front of the camera, and the hero of each save slot stands
## in 3D on the painting's numbered rune circles, slot N on circle N.
##
## The painting looks down at the platform at about 19 degrees (its circle
## ellipses are roughly 1:3), so the camera does too: a hero's feet are where the
## ray through the circle's centre meets the ground plane, and the hero is scaled to
## the circle's on-screen width. Every aspect ratio fits the painting around KEEP
## (all ten circles, the name plates above them, room for the button bar): a cover
## fit where that crops nothing of KEEP, otherwise KEEP's full width (tall screens)
## or height (very wide phone browsers), with the painting mirrored at its edges.

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
## Centre (px) of the number crystal above each row's circles, and its half-size.
const GEM_Y := [352.0, 605.0]
const GEM_HALF := Vector2(25, 37)
const BACKDROP_SHADER := preload("res://shaders/title_stage.gdshader")
const SKY := Color("4f9be6")
const DEFENDER_TURN := 38.0
const GOLD := Color("ffd36a")

var camera: Camera3D
## slot -> {visual, root, feet, scale, height, shadow}
var heroes: Dictionary = {}
var selected := 0
## Screen (canvas) rectangle the painting covers.
var image_rect := Rect2()
var _backdrop: MeshInstance3D
var _texture: Texture2D
var _glow_tween: Tween
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
	# The painting's own shader turns the selected hero's blue circle gold.
	var mat := ShaderMaterial.new()
	mat.shader = BACKDROP_SHADER
	mat.set_shader_parameter("image", _texture)
	_backdrop.material_override = mat
	_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_backdrop)


## Fits the painting and every hero to a canvas of [param canvas] (the viewport's
## visible rectangle, the space UI controls and Camera3D projections share).
func layout(canvas: Vector2) -> void:
	if canvas.x < 2.0 or canvas.y < 2.0 or camera == null:
		return
	_canvas = canvas
	image_rect = cover_rect(canvas)
	# The backdrop quad exactly under the painting's screen rectangle, facing the camera.
	# The backdrop quad fills the whole screen, facing the camera; the shader places the
	# painting on it at image_rect and mirrors it beyond its edges.
	var a := camera.project_position(Vector2.ZERO, BACKDROP_DEPTH)
	var b := camera.project_position(Vector2(canvas.x, 0), BACKDROP_DEPTH)
	var c := camera.project_position(Vector2(0, canvas.y), BACKDROP_DEPTH)
	(_backdrop.mesh as QuadMesh).size = Vector2(a.distance_to(b), a.distance_to(c))
	_backdrop.global_transform = Transform3D(camera.global_basis, camera.project_position(canvas * 0.5, BACKDROP_DEPTH))
	var mat := _backdrop.material_override as ShaderMaterial
	mat.set_shader_parameter("image_uv", Vector4(image_rect.position.x / canvas.x, image_rect.position.y / canvas.y,
			image_rect.size.x / canvas.x, image_rect.size.y / canvas.y))
	for slot in heroes:
		_place(int(slot))


## Where the painting lies on a canvas: a cover fit centred on KEEP; a screen too
## narrow for KEEP's width gets KEEP's full width, one too wide for its height gets
## KEEP's full height (the painting is mirrored past its edges either way).
static func cover_rect(canvas: Vector2) -> Rect2:
	var scale := maxf(canvas.x / IMAGE_SIZE.x, canvas.y / IMAGE_SIZE.y)
	if canvas.x / scale < KEEP.size.x:
		scale = canvas.x / KEEP.size.x
	if canvas.y / scale < KEEP.size.y:
		scale = canvas.y / KEEP.size.y
	var view := canvas / scale
	var centre := KEEP.get_center()
	if view.x <= IMAGE_SIZE.x:
		centre.x = clampf(centre.x, view.x * 0.5, IMAGE_SIZE.x - view.x * 0.5)
	else:
		centre.x = IMAGE_SIZE.x * 0.5
	if view.y <= IMAGE_SIZE.y:
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
	# A Defender holds its great shield square in front: turn it a little so the
	# shield swings to the side and the face shows.
	var turn := deg_to_rad(DEFENDER_TURN) if String(overview.get("class", "")) == "defender" else 0.0
	heroes[slot] = {"root": root, "visual": visual, "shadow": shadow, "height": height, "scale": 1.0, "feet": Vector3.ZERO, "turn": turn}
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
	(entry.visual as Node3D).rotation.y = atan2(to_camera.x, to_camera.z) + float(entry.get("turn", 0.0))
	(entry.shadow as Node3D).scale = Vector3.ONE * scale * 1.25


## Canvas point just above the hero's head (for its name plate).
func head_screen(slot: int) -> Vector2:
	if not heroes.has(slot):
		return spot_screen(slot)
	var entry: Dictionary = heroes[slot]
	var root: Node3D = entry.root
	# The arrival stretches the hero tall for a moment; the plate stays at its real height.
	var top: Vector3 = entry.feet + Vector3.UP * float(entry.height) * float(entry.scale) * minf(root.scale.y, 1.0)
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


## Turns the circle under [param slot] gold (0: none) and lets that hero cheer; the
## circle selected before fades back to blue.
func select(slot: int) -> void:
	var next := slot if heroes.has(slot) else 0
	if next == selected and (next == 0 or gold_amount() > 0.0):
		return
	var mat := _backdrop.material_override as ShaderMaterial
	if _glow_tween:
		_glow_tween.kill()
	# The old gold circle becomes the fading set; the new one fades in.
	var previous := selected
	if previous > 0:
		_set_spot(mat, "old_", previous)
		mat.set_shader_parameter("old_amount", float(mat.get_shader_parameter("amount")))
	else:
		mat.set_shader_parameter("old_amount", 0.0)
	selected = next
	if previous > 0 and previous != selected and heroes.has(previous):
		_idle(heroes[previous].visual)
	if selected > 0:
		_set_spot(mat, "", selected)
	mat.set_shader_parameter("amount", 0.0)
	_glow_tween = create_tween().set_parallel()
	_glow_tween.tween_method(func(v: float): mat.set_shader_parameter("old_amount", v), float(mat.get_shader_parameter("old_amount")), 0.0, 0.22)
	if selected > 0:
		_glow_tween.tween_method(func(v: float): mat.set_shader_parameter("amount", v), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	if selected == 0:
		return
	_cheer(heroes[selected].visual)


## One round of the cheer (the clip loops), then back to standing.
func _cheer(visual: HeroVisual) -> void:
	if visual.anim == null or not visual.anim.has_animation("Cheer"):
		return
	var length := visual.action("Cheer")
	var back := visual.create_tween()
	back.tween_interval(maxf(length, 0.4))
	back.tween_callback(func(): if visual.current == "Cheer": _idle(visual))
	visual.set_meta("cheer_tween", back)


func _idle(visual: HeroVisual) -> void:
	if not is_instance_valid(visual):
		return
	var pending: Variant = visual.get_meta("cheer_tween", null)
	if pending is Tween and (pending as Tween).is_valid():
		(pending as Tween).kill()
	visual.release()
	visual.play("Idle")


## How gold the selected circle is now (0..1).
func gold_amount() -> float:
	return float((_backdrop.material_override as ShaderMaterial).get_shader_parameter("amount"))


## Where circle [param slot] and its number crystal are in the painting, as UV.
func _set_spot(mat: ShaderMaterial, prefix: String, slot: int) -> void:
	var spot: Array = SPOTS[slot - 1]
	var centre: Vector2 = spot[0]
	var half := Vector2(float(spot[1]) * 0.5, float(spot[1]) * 0.5 * float(ROW_FLATTENING[0 if slot <= 5 else 1]))
	mat.set_shader_parameter(prefix + "circle_centre", centre / IMAGE_SIZE)
	mat.set_shader_parameter(prefix + "circle_half", half / IMAGE_SIZE)
	mat.set_shader_parameter(prefix + "gem_centre", Vector2(centre.x, float(GEM_Y[0 if slot <= 5 else 1])) / IMAGE_SIZE)
	mat.set_shader_parameter(prefix + "gem_half", GEM_HALF / IMAGE_SIZE)


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
	_cheer(entry.visual)
