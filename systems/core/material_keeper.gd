class_name MaterialKeeper
extends RefCounted
## Keeps effect materials alive so their shaders stay compiled.
##
## BaseMaterial3D shares one generated shader per feature key and frees it when
## the last material with that key is freed. Hit flashes, rings and glows each
## live for a fraction of a second, so the shader of an effect that is not on
## screen right now is destroyed and compiled again at the next hit. On a phone
## that is a stall of tens of milliseconds, several times a second in a fight.
##
## Two layers: a ring of the most recent materials covers every key in current
## use at once, and the first material of each distinct feature set seen is
## pinned for good (a few dozen in all), so even a rarely used effect keeps its
## compiled shader.

const RING_SIZE := 192
## The BaseMaterial3D properties that select the generated shader.
const FEATURES := ["shading_mode", "transparency", "blend_mode", "cull_mode", "depth_draw_mode", "no_depth_test",
		"billboard_mode", "billboard_keep_scale", "vertex_color_use_as_albedo", "vertex_color_is_srgb", "disable_fog",
		"disable_ambient_light", "emission_enabled", "texture_filter", "fixed_size", "use_point_size",
		"proximity_fade_enabled", "distance_fade_mode", "alpha_antialiasing_mode", "normal_enabled", "rim_enabled",
		"specular_mode", "diffuse_mode", "shadow_to_opacity", "grow", "albedo_texture", "emission_texture"]
static var _ring: Array[Material] = []
static var _next := 0
static var _pinned: Dictionary = {}
static var _queue: Array[Material] = []
static var _scheduled := false


## Remembers [param material] (returned unchanged, for chaining). Callers keep
## configuring it after this call; its feature set is read on the next frame.
static func keep(material: Material) -> Material:
	if _ring.size() < RING_SIZE:
		_ring.append(material)
	else:
		_ring[_next] = material
		_next = (_next + 1) % RING_SIZE
	if material is BaseMaterial3D:
		_queue.append(material)
		if not _scheduled:
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null:
				_scheduled = true
				tree.process_frame.connect(_pin_new, CONNECT_ONE_SHOT)
	return material


static func _pin_new() -> void:
	_scheduled = false
	for material in _queue:
		if not is_instance_valid(material):
			continue
		var key := feature_key(material as BaseMaterial3D)
		if not _pinned.has(key):
			_pinned[key] = material
	_queue.clear()


## The shader-selecting settings of [param material] as one string.
static func feature_key(material: BaseMaterial3D) -> String:
	var parts := PackedStringArray()
	for feature in FEATURES:
		var value: Variant = material.get(feature)
		parts.append("1" if value is Object else str(value))
	return ",".join(parts)


## For tests: materials held by the ring and pinned by feature set.
static func held() -> int:
	return _ring.size()


static func pinned() -> int:
	return _pinned.size()
