class_name HeroPortrait
extends TextureRect
## A still portrait of the same head and head accessories as the real hero.
## Only appearance changes create a temporary, single-frame 3D capture. During
## play the HUD displays a normal texture, with no extra running viewport.

const CAPTURE_SIZE := 192
const CACHE_LIMIT := 12
const BARE_HEADS: Array[Texture2D] = [
	preload("res://assets/ui/portraits/hero_boy.png"),
	preload("res://assets/ui/portraits/hero_girl.png"),
]

static var _textures: Dictionary = {}
static var _texture_order: Array[String] = []
static var _head_meshes: Dictionary = {}
static var _live_instances := 0

var _wanted_key := ""
var _shown_key := ""
var _pending_profile: Dictionary = {}
var _generation := 0
var _runner_id := 0
var _capturing := false
var _viewport: SubViewport
var _capture_key := ""
var _capture_generation := -1
var _frames_left := 0
var _visual: HeroVisual
var _camera: Camera3D
var _post_draw := Callable()


func _enter_tree() -> void:
	_live_instances += 1
	_schedule_capture.call_deferred()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	visibility_changed.connect(_on_visibility_changed)
	_schedule_capture()


func _exit_tree() -> void:
	_generation += 1
	_cancel_capture()
	_live_instances = maxi(0, _live_instances - 1)
	if _live_instances == 0:
		# GPU resources in a static cache can outlive the final HUD at shutdown.
		# Keep them while another portrait is active, then release the cache and
		# this last texture reference together when the last owner leaves.
		texture = null
		_shown_key = ""
		_textures.clear()
		_texture_order.clear()
		_head_meshes.clear()


## The HUD may call this on every status refresh; unchanged appearances do no
## scene construction, rendering or image readback. UID/stat-only item changes
## also share an image because they do not change the chibi head's appearance.
func refresh_profile(profile: Dictionary) -> void:
	var key := appearance_key(profile)
	if key == _wanted_key:
		return
	_wanted_key = key
	_generation += 1
	_cancel_capture()
	var look: Dictionary = profile.get("look", {})
	var gender := clampi(int(look.get("gender", 0)), 0, 1)
	var equipment: Dictionary = profile.get("equip", {})
	_pending_profile = {"look": {"gender": gender}, "equip": equipment.duplicate(true)}
	if _textures.has(key):
		texture = _textures[key]
		_shown_key = key
		_touch_cache(key)
	else:
		# Never leave the previous character's portrait visible while capturing a
		# newly selected save, and give first entry an immediate image to display.
		texture = BARE_HEADS[gender]
		_shown_key = ""
	_schedule_capture()


static func appearance_key(profile: Dictionary) -> String:
	var look: Dictionary = profile.get("look", {})
	var gender := clampi(int(look.get("gender", 0)), 0, 1)
	var equipment: Dictionary = profile.get("equip", {})
	var helm: Variant = equipment.get("helm")
	var helm_tier := ItemLook.tier_of(helm) if helm is Dictionary else -1
	# Star circlets have class-specific shapes and colours even at equal tiers.
	var helm_style := ItemLook.look_of(helm) if StarGearData.is_star(helm) else str(helm_tier)
	var grade := EnhanceFx.grade(int(helm.get("plus", 0))) if helm is Dictionary else 0
	var halo_tier := -1
	if GameSettings.quality > 0:
		for slot in ["weapon", "armor", "helm", "boots"]:
			var piece: Variant = equipment.get(slot)
			if piece is Dictionary:
				var tier := ItemLook.tier_of(piece)
				if tier >= 8:
					halo_tier = maxi(halo_tier, tier)
	return "%d|%s|%d|%d|%d" % [gender, helm_style, grade, halo_tier, int(GameSettings.quality > 0)]


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_cancel_capture()
	_schedule_capture()


func _schedule_capture() -> void:
	if _capturing or _wanted_key == "" or _shown_key == _wanted_key:
		return
	if not is_inside_tree() or not is_visible_in_tree():
		return
	_capturing = true
	_runner_id += 1
	_capture_pending.call_deferred(_runner_id)


func _capture_pending(runner_id: int) -> void:
	if runner_id != _runner_id:
		return
	if not is_inside_tree() or not is_visible_in_tree():
		_cancel_capture()
		return
	var key := _wanted_key
	if _textures.has(key):
		texture = _textures[key]
		_shown_key = key
		_touch_cache(key)
		_cancel_capture()
		return
	# The headless renderer never emits a useful frame_post_draw signal. Keep
	# the fallback without queuing a capture that could never complete.
	if DisplayServer.get_name() == "headless":
		_shown_key = key
		_cancel_capture()
		return
	_capture_key = key
	_capture_generation = _generation
	var profile := _pending_profile
	var viewport := SubViewport.new()
	_viewport = viewport
	viewport.size = Vector2i(CAPTURE_SIZE, CAPTURE_SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(viewport)
	_add_lighting(viewport)
	var look: Dictionary = profile.get("look", {})
	var gender := clampi(int(look.get("gender", 0)), 0, 1)
	var visual := HeroVisual.new()
	_visual = visual
	viewport.add_child(visual)
	visual.setup(ClassData.START, "", false, profile.get("equip", {}), {"gender": gender})
	_isolate_head(visual, gender)
	visual.anim.play("Idle")
	visual.anim.seek(0.0, true)
	visual.anim.pause()
	visual.set_process(false)
	visual.set_physics_process(false)
	visual.rotation_degrees.y = -8.0
	var camera := Camera3D.new()
	_camera = camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	# Bone attachments receive their posed transforms during scene updates.
	# Keep rendering disabled until they are settled; only the final still is
	# drawn. These scene updates continue while the equipment menu pauses play.
	_frames_left = 2
	set_process(true)


func _process(_delta: float) -> void:
	if not _capture_is_current():
		_cancel_capture()
		_schedule_capture()
		return
	_frames_left -= 1
	if _frames_left > 0:
		return
	_frame_head(_camera, _visual)
	# The component has no member coroutine awaiting an external signal. This
	# one-shot callback disconnects automatically if the HUD is destroyed, and
	# explicit cancellation also removes it on hide or equipment changes.
	_post_draw = _finish_capture.bind(_runner_id, _capture_key, _capture_generation)
	RenderingServer.frame_post_draw.connect(_post_draw, CONNECT_ONE_SHOT)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	set_process(false)


func _finish_capture(runner_id: int, key: String, generation: int) -> void:
	if runner_id != _runner_id:
		return
	_post_draw = Callable()
	if not _capture_is_current():
		_cancel_capture()
		_schedule_capture()
		return
	var image := _viewport.get_texture().get_image()
	var rendered: ImageTexture = null
	if image != null and not image.is_empty():
		rendered = ImageTexture.create_from_image(image)
	_cancel_capture()
	if rendered != null:
		_store_texture(key, rendered)
		if generation == _generation and key == _wanted_key:
			texture = rendered
			_shown_key = key
	elif generation == _generation:
		# Do not retry a failed renderer readback on every HUD refresh.
		_shown_key = key
	_schedule_capture()


func _capture_is_current() -> bool:
	return is_inside_tree() and is_visible_in_tree() and is_instance_valid(_viewport) and _capture_generation == _generation and _capture_key == _wanted_key


func _cancel_capture() -> void:
	_runner_id += 1
	set_process(false)
	if _post_draw.is_valid() and RenderingServer.frame_post_draw.is_connected(_post_draw):
		RenderingServer.frame_post_draw.disconnect(_post_draw)
	_post_draw = Callable()
	_release_viewport()
	_visual = null
	_camera = null
	_frames_left = 0
	_capture_key = ""
	_capture_generation = -1
	_capturing = false


func _release_viewport(expected: SubViewport = null) -> void:
	var viewport := expected if expected != null else _viewport
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.free()
	if _viewport == viewport:
		_viewport = null


static func _add_lighting(viewport: SubViewport) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e5eaff")
	environment.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-24, -28, 0)
	key.light_color = Color("fff1e2")
	key.light_energy = 1.2
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12, 135, 0)
	fill.light_color = Color("bacfee")
	fill.light_energy = 0.55
	viewport.add_child(fill)


static func _isolate_head(visual: HeroVisual, gender: int) -> void:
	var skeleton := visual.model.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := skeleton.find_bone("Head")
	# Head accessories have exactly the same bone transforms as the world hero.
	# All other equipment, full-body auras and particles are outside this crop.
	for child in skeleton.get_children():
		if child is BoneAttachment3D and not (child.name in ["ChibiHelm", "ChibiStar_helm", "ChibiDivineDye_helm", "Halo"]):
			child.free()
	for child in visual.get_children():
		if child != visual.model:
			child.free()
	for node in visual.model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.skin == null or instance.mesh == null:
			continue
		var cache_key := "%d|%s" % [gender, visual.model.get_path_to(instance)]
		if not _head_meshes.has(cache_key):
			_head_meshes[cache_key] = _crop_head_mesh(instance, skeleton, head)
		var cropped: ArrayMesh = _head_meshes[cache_key]
		instance.mesh = cropped
		instance.visible = cropped != null and cropped.get_surface_count() > 0


## The immutable cropped meshes are built once per gender. Retain the original
## skin and vertex arrays but only triangles whose three vertices are weighted
## to the Head subtree, including all facial and hair descendants.
static func _crop_head_mesh(instance: MeshInstance3D, skeleton: Skeleton3D, head: int) -> ArrayMesh:
	var head_binds: Dictionary = {}
	for bind in instance.skin.get_bind_count():
		var bone := skeleton.find_bone(instance.skin.get_bind_name(bind))
		if bone < 0:
			bone = instance.skin.get_bind_bone(bind)
		while bone >= 0:
			if bone == head:
				head_binds[bind] = true
				break
			bone = skeleton.get_bone_parent(bone)
	var source := instance.mesh
	var cropped := ArrayMesh.new()
	var bounds := AABB()
	var has_bounds := false
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or bones.is_empty() or weights.is_empty():
			continue
		var stride := bones.size() / vertices.size()
		var included: PackedByteArray = []
		included.resize(vertices.size())
		for vertex in vertices.size():
			var head_weight := 0.0
			for slot in stride:
				var at := vertex * stride + slot
				if head_binds.has(bones[at]):
					head_weight += weights[at]
			included[vertex] = 1 if head_weight >= 0.45 else 0
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in vertices.size():
				indices.append(index)
		var kept: PackedInt32Array = []
		for triangle in range(0, indices.size() - 2, 3):
			if included[indices[triangle]] and included[indices[triangle + 1]] and included[indices[triangle + 2]]:
				for corner in 3:
					var index := indices[triangle + corner]
					kept.append(index)
					if has_bounds:
						bounds = bounds.expand(vertices[index])
					else:
						bounds = AABB(vertices[index], Vector3.ZERO)
						has_bounds = true
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		cropped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		cropped.surface_set_material(cropped.get_surface_count() - 1, source.surface_get_material(surface))
	if has_bounds:
		# The retained vertex arrays also contain unused body vertices. Their old
		# bounds must not pull the portrait camera down to the missing torso.
		cropped.custom_aabb = bounds.grow(0.015)
	return cropped


static func _frame_head(camera: Camera3D, visual: HeroVisual) -> void:
	var bounds := AABB()
	var has_bounds := false
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.visible:
			continue
		var local_box := mesh.get_aabb()
		# ArrayMesh.get_aabb() retains unused body vertices even when its custom
		# rendering bounds are head-only. Use those explicit crop bounds here.
		if mesh.skin != null and mesh.mesh is ArrayMesh:
			local_box = (mesh.mesh as ArrayMesh).custom_aabb
		var box: AABB = mesh.global_transform * local_box
		if has_bounds:
			bounds = bounds.merge(box)
		else:
			bounds = box
			has_bounds = true
	if not has_bounds:
		camera.size = 1.16
		camera.position = Vector3(-0.03, 1.96, 5.0)
		return
	var center := bounds.get_center()
	camera.size = maxf(1.16, maxf(bounds.size.x, bounds.size.y) * 1.16)
	# A small downward angle lets horizontal circlets and halos read as rings
	# rather than thin edge-on lines while keeping the face almost frontal.
	var distance := maxf(5.0, bounds.size.z + 3.0)
	camera.position = center + Vector3(0, distance * tan(deg_to_rad(7.0)), distance)
	camera.look_at(center, Vector3.UP)


static func _touch_cache(key: String) -> void:
	_texture_order.erase(key)
	_texture_order.append(key)


static func _store_texture(key: String, rendered: ImageTexture) -> void:
	_textures[key] = rendered
	_touch_cache(key)
	while _texture_order.size() > CACHE_LIMIT:
		var oldest: String = _texture_order.pop_front()
		_textures.erase(oldest)
