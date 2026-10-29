class_name HeroPortrait
extends TextureRect
## A half-body portrait of the real hero: the chosen look (hair, eyes, skin,
## accessory), the worn outfit and head gear, from the chest up. Only appearance
## changes create a temporary 3D capture of two stills (eyes open and closed);
## during play the HUD shows a normal texture and blinks by swapping the two,
## with no extra running viewport.

const CAPTURE_SIZE := 192
const CACHE_LIMIT := 12
const BARE_HEADS: Array[Texture2D] = [
	preload("res://assets/ui/portraits/hero_boy.png"),
	preload("res://assets/ui/portraits/hero_girl.png"),
]

## Seconds between blinks (a random pick in this range) and how long the eyes
## stay closed.
const BLINK_EVERY := Vector2(2.6, 5.2)
const BLINK_HOLD := 0.13
## How far the eye bones squash for the closed frame.
const CLOSED_EYE := 0.12

## key -> [eyes open, eyes closed] textures.
static var _textures: Dictionary = {}
static var _texture_order: Array[String] = []
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
## Capture stage: 0 eyes open, 1 eyes closed.
var _stage := 0
var _open_image: ImageTexture
var _closed: Texture2D
var _open: Texture2D
var _blink: Timer


func _enter_tree() -> void:
	_live_instances += 1
	_schedule_capture.call_deferred()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	visibility_changed.connect(_on_visibility_changed)
	_blink = Timer.new()
	_blink.one_shot = true
	_blink.timeout.connect(_on_blink)
	add_child(_blink)
	_blink.start(randf_range(BLINK_EVERY.x, BLINK_EVERY.y))
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
		_open = null
		_closed = null
		_shown_key = ""
		_textures.clear()
		_texture_order.clear()


## The HUD may call this on every status refresh; unchanged appearances do no
## scene construction, rendering or image readback. UID/stat-only item changes
## also share an image because they do not change what the bust shows.
func refresh_profile(profile: Dictionary) -> void:
	var key := appearance_key(profile)
	if key == _wanted_key:
		return
	_wanted_key = key
	_generation += 1
	_cancel_capture()
	var look := FaceKit.repair(profile.get("look", {}))
	var equipment: Dictionary = profile.get("equip", {}).duplicate(true)
	# The bust shows the outfit and head gear; wings and weapons stay out of frame.
	equipment.erase("wings")
	equipment.erase("weapon")
	_pending_profile = {"class": StringName(profile.get("class", ClassData.START)), "look": look, "equip": equipment}
	if _textures.has(key):
		_show(_textures[key])
		_shown_key = key
		_touch_cache(key)
	else:
		# Never leave the previous character's portrait visible while capturing a
		# newly selected save, and give first entry an immediate image to display.
		_show([BARE_HEADS[int(look.gender)], null])
		_shown_key = ""
	_schedule_capture()


static func appearance_key(profile: Dictionary) -> String:
	var look := FaceKit.repair(profile.get("look", {}))
	var looks: PackedStringArray = []
	for part in look:
		looks.append("%s=%d" % [part, int(look[part])])
	looks.sort()
	var equipment: Dictionary = profile.get("equip", {})
	var dress: PackedStringArray = []
	for slot in ["armor", "helm", "boots"]:
		var piece: Variant = equipment.get(slot)
		if piece is Dictionary:
			dress.append("%s:%s:%d" % [slot, ItemLook.look_of(piece), EnhanceFx.grade(int(piece.get("plus", 0)))])
	var halo_tier := -1
	if GameSettings.quality > 0:
		for slot in ["weapon", "armor", "helm", "boots"]:
			var piece: Variant = equipment.get(slot)
			if piece is Dictionary:
				var tier := ItemLook.tier_of(piece)
				if tier >= 8:
					halo_tier = maxi(halo_tier, tier)
	return "%s|%s|%s|%d|%d" % [String(profile.get("class", "")), ",".join(looks), ",".join(dress), halo_tier, int(GameSettings.quality > 0)]


func _show(pair: Array) -> void:
	_open = pair[0]
	_closed = pair[1]
	texture = _open


## Close the eyes for a moment, then open them and wait for the next blink.
func _on_blink() -> void:
	if _closed != null and texture == _open and is_visible_in_tree():
		texture = _closed
		_blink.start(BLINK_HOLD)
		return
	texture = _open
	_blink.start(randf_range(BLINK_EVERY.x, BLINK_EVERY.y))


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
		_show(_textures[key])
		_shown_key = key
		_touch_cache(key)
		_cancel_capture()
		return
	# The headless renderer never emits a useful frame_post_draw signal. Keep
	# the fallback without queuing a capture that could never complete.
	# An iPhone keeps the drawn bare-head portrait: a second 3D render (a multisampled
	# SubViewport) as the game starts is the prime suspect for the iPhone's grey world.
	if DisplayServer.get_name() == "headless" or MemoryGuard.ios():
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
	viewport.msaa_3d = Viewport.MSAA_DISABLED if OS.has_feature("web") else Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(viewport)
	_add_lighting(viewport)
	var visual := HeroVisual.new()
	_visual = visual
	viewport.add_child(visual)
	visual.setup(profile.get("class", ClassData.START), "", false, profile.get("equip", {}), profile.get("look", {}))
	_isolate_bust(visual)
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
	_stage = 0
	_open_image = null
	set_process(true)


func _process(_delta: float) -> void:
	if not _capture_is_current():
		_cancel_capture()
		_schedule_capture()
		return
	_frames_left -= 1
	if _frames_left > 0:
		return
	if _stage == 0:
		_frame_bust(_camera, _visual)
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
	if _stage == 0 and rendered != null:
		# Second still: the same pose with the eyes closed, for the blink.
		_open_image = rendered
		_stage = 1
		_close_eyes(_visual)
		_frames_left = 2
		set_process(true)
		return
	var pair: Array = [_open_image, rendered] if _stage == 1 else [rendered, null]
	if pair[0] == null:
		pair = [rendered, null]
	_cancel_capture()
	if pair[0] != null:
		_store_texture(key, pair)
		if generation == _generation and key == _wanted_key:
			_show(pair)
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
	_stage = 0
	_open_image = null


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


## Only the body and what it wears stay: auras, particles and the wings (on
## their own bone attachments) are left out of the still.
static func _isolate_bust(visual: HeroVisual) -> void:
	var skeleton := visual.model.find_child("Skeleton3D", true, false) as Skeleton3D
	for child in skeleton.get_children():
		if child is BoneAttachment3D and (String(child.name).contains("Wing") or String(child.name).begins_with("Held_")):
			child.free()
	for child in visual.get_children():
		if child != visual.model:
			child.free()


## The eye bones carry the middle of each eye: squashed flat they read as shut.
static func _close_eyes(visual: HeroVisual) -> void:
	var skeleton := visual.model.find_child("Skeleton3D", true, false) as Skeleton3D
	for eye in ["Eye_L", "Eye_R"]:
		var bone := skeleton.find_bone(eye)
		if bone >= 0:
			skeleton.set_bone_pose_scale(bone, Vector3(1.0, CLOSED_EYE, 1.0))


## Chest up: from just under the chest bone to the top of the hair, head gear or
## halo, centred on the body.
static func _frame_bust(camera: Camera3D, visual: HeroVisual) -> void:
	var skeleton := visual.model.find_child("Skeleton3D", true, false) as Skeleton3D
	var top := -INF
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.visible:
			continue
		top = maxf(top, (mesh.global_transform * mesh.get_aabb()).end.y)
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
	var chest := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Spine")).origin
	if not is_finite(top) or top < head.y:
		top = head.y + (head.y - chest.y) * 1.4
	var bottom := chest.y
	var height := top - bottom
	# A little air above the hair, crown or halo; the chest runs off the bottom.
	camera.size = height * 1.14
	var center := Vector3(head.x, bottom + height * 0.53, head.z)
	var distance := 5.0
	camera.position = center + Vector3(0, distance * tan(deg_to_rad(5.0)), distance)
	camera.look_at(center, Vector3.UP)


static func _touch_cache(key: String) -> void:
	_texture_order.erase(key)
	_texture_order.append(key)


static func _store_texture(key: String, rendered: Array) -> void:
	_textures[key] = rendered
	_touch_cache(key)
	while _texture_order.size() > CACHE_LIMIT:
		var oldest: String = _texture_order.pop_front()
		_textures.erase(oldest)
