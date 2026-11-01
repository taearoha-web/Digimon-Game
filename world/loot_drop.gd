class_name LootDrop
extends Node3D
## Gold or an item tossed out of a monster the hero earned (Zone._spawn_loot: only the
## hero's own kills drop loot, a world player's kill stays its own), glowing in its
## rarity colour. Loot magnet: shortly after it lands it flies to the hero from
## anywhere in the zone, on a short arc that speeds up (FLY_MIN-FLY_MAX seconds, with
## a small sparkle), and is collected on arrival. An item the full bag can't take stays
## on the ground (a throttled "กระเป๋าเต็ม" toast) and flies over as soon as there is
## room, until LIFETIME runs out. Liftoff / pickup sparkles and sounds are capped per
## moment (FX_PER_BURST every FX_BURST seconds) so a boss's pile of drops does not
## flood the effect budget (VfxBudget).

const LIFETIME := 120.0
## Rest on the ground after landing before flying (seconds), plus a little per drop.
const REST := 0.35
const FLY_MIN := 0.3
const FLY_MAX := 0.6
## Liftoff / pickup sparkles and sounds allowed per FX_BURST seconds.
const FX_PER_BURST := 4
const FX_BURST := 0.25
## Seconds between two "bag full" toasts.
const FULL_TOAST_GAP := 15.0

static var _fx_window := -100.0
static var _fx_used := 0
static var _full_toast_at := -100.0

var item: Dictionary = {}
var gold := 0
var hero: Node3D

var _age := 0.0
## Flying to the hero (the loot magnet).
var _magnet := false
var _body: Node3D
var _landed := false
var _landed_at := 0.0
var _rest := REST
var _fly_from := Vector3.ZERO
var _fly_t := 0.0
var _fly_time := FLY_MIN
var _fly_side := Vector3.ZERO


func setup(p_item: Dictionary, p_gold: int, p_hero: Node3D, from: Vector3) -> void:
	item = p_item
	gold = p_gold
	hero = p_hero
	position = from + Vector3(0, 0.6, 0)


func _ready() -> void:
	add_to_group("loot")
	_body = Node3D.new()
	add_child(_body)
	var color := Color("ffd84a")
	if gold > 0:
		for i in 3:
			var coin := MeshInstance3D.new()
			coin.mesh = MeshKit.cylinder()
			coin.material_override = MeshKit.toon(Color("ffd84a"), {"emission": 1.2})
			coin.scale = Vector3(0.28, 0.05, 0.28)
			coin.position = Vector3((i - 1) * 0.12, 0.05 + i * 0.05, (i % 2) * 0.1)
			_body.add_child(coin)
	else:
		color = ItemData.color_of(item)
		var icon_texture := ItemLook.icon(item)
		if icon_texture != null:
			var pad := MeshInstance3D.new()
			pad.mesh = MeshKit.cylinder()
			pad.material_override = MeshKit.toon(color, {"emission": 1.4, "alpha": 0.55})
			pad.scale = Vector3(0.7, 0.03, 0.7)
			pad.position = Vector3(0, 0.05, 0)
			_body.add_child(pad)
			var sprite := Sprite3D.new()
			sprite.texture = icon_texture
			sprite.pixel_size = 0.0075 if item.get("kind", "") == "equip" else 0.0052
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.shaded = false
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sprite.position = Vector3(0, 0.75, 0)
			add_child(sprite)
		elif item.get("kind", "") == "potion":
			var bottle := MeshInstance3D.new()
			bottle.mesh = MeshKit.sphere_low()
			bottle.material_override = MeshKit.toon(color, {"emission": 1.0})
			bottle.scale = Vector3(0.3, 0.34, 0.3)
			bottle.position = Vector3(0, 0.3, 0)
			_body.add_child(bottle)
			var neck := MeshInstance3D.new()
			neck.mesh = MeshKit.cylinder()
			neck.material_override = MeshKit.toon(Color("e8e0d0"))
			neck.scale = Vector3(0.1, 0.18, 0.1)
			neck.position = Vector3(0, 0.55, 0)
			_body.add_child(neck)
		if icon_texture == null and not ItemData.is_stackable(item):
			var gem := MeshInstance3D.new()
			gem.mesh = MeshKit.sphere_low()
			gem.material_override = MeshKit.toon(color, {"emission": 1.6})
			gem.scale = Vector3(0.34, 0.46, 0.34)
			gem.position = Vector3(0, 0.45, 0)
			_body.add_child(gem)
		var rarity := int(item.get("rarity", 0))
		if item.get("kind", "") == "equip":
			VfxKit.loot_beam(self, color, 2.0 + rarity * 1.4 + (2.5 if rarity >= 4 else 0.0))
			if rarity >= 1:
				var label := Label3D.new()
				label.text = ItemData.name_of(item)
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.pixel_size = 0.005
				label.font_size = 40
				label.outline_size = 12
				label.modulate = color
				label.position = Vector3(0, 1.3, 0)
				label.no_depth_test = true
				add_child(label)
	# Toss out and land nearby.
	var angle := randf() * TAU
	var land := position + Vector3(cos(angle), 0, sin(angle)) * randf_range(0.8, 1.8)
	land.y = 0.05
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 1.2, 0.18).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:x", land.x, 0.4)
	tween.parallel().tween_property(self, "position:z", land.z, 0.4)
	tween.tween_property(self, "position:y", 0.05, 0.22).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_landed)


## Rare gear announces itself: a burst of light, a chime and a message.
func _on_landed() -> void:
	_landed = true
	_landed_at = _age
	_rest = REST + randf() * 0.2
	if item.get("kind", "") != "equip":
		return
	var rarity := int(item.get("rarity", 0))
	if rarity < 3:
		return
	var color := ItemData.color_of(item)
	var parent := get_parent() as Node3D
	if parent:
		VfxKit.shockwave(parent, global_position + Vector3(0, 0.1, 0), color, 2.0 + rarity)
		VfxKit.sparks(parent, global_position + Vector3(0, 0.6, 0), color, 14 + rarity * 8, 4.0, 0.8)
	AudioManager.play_sfx(&"quest_complete", -3.0)
	Game.say("ของ%s ตกแล้ว: %s" % [ItemData.RARITY_NAMES[rarity], ItemData.name_of(item)], &"success")


func _process(delta: float) -> void:
	_age += delta
	if _body:
		_body.rotation.y += delta * 2.0
		if not _magnet:
			_body.position.y = sin(_age * 3.0) * 0.06
	if _magnet:
		_fly(delta)
		return
	if _age > LIFETIME:
		queue_free()
		return
	if not _landed or not _hero_ok() or _age - _landed_at < _rest:
		return
	if not fits():
		_bag_full_toast()
		return
	_lift_off()


func _hero_ok() -> bool:
	return hero != null and is_instance_valid(hero) and hero.is_inside_tree() and not hero.is_dead()


## True when the bag can take this drop now (gold always; a stackable onto its stack).
func fits() -> bool:
	if gold > 0 or item.is_empty():
		return true
	if ItemData.is_stackable(item):
		for existing in Game.profile.get("inv", []):
			if existing.get("kind", "") == item.get("kind", "") and existing.get("id") == item.get("id"):
				return true
	return Game.inventory_free() > 0


## Starts the homing flight from wherever it lies in the zone.
func _lift_off() -> void:
	_magnet = true
	_fly_from = global_position
	_fly_t = 0.0
	var dist := (hero.global_position - _fly_from).length()
	_fly_time = clampf(FLY_MIN + dist * 0.006, FLY_MIN, FLY_MAX)
	# A sideways bow so a pile fans out instead of flying as one line.
	var flat := Vector3(hero.global_position.x - _fly_from.x, 0, hero.global_position.z - _fly_from.z)
	var side := flat.cross(Vector3.UP).normalized() if flat.length() > 0.01 else Vector3.RIGHT
	_fly_side = side * randf_range(-1.0, 1.0) * clampf(dist * 0.12, 0.3, 3.0)
	var parent := get_parent() as Node3D
	if parent != null and take_fx():
		VfxKit.sparks(parent, global_position + Vector3(0, 0.3, 0), _sparkle_color(), 6, 2.0, 0.3)


## One frame of the flight: a quadratic arc from where it lifted off to the hero
## (followed as it moves), eased in so it speeds up; collected on arrival.
func _fly(delta: float) -> void:
	if not _hero_ok():
		# The hero fell (or left): drop where it is and wait.
		_magnet = false
		global_position.y = 0.05
		_landed_at = _age
		return
	_fly_t = minf(1.0, _fly_t + delta / _fly_time)
	var to := hero.global_position + Vector3(0, 0.9, 0)
	var mid := (_fly_from + to) * 0.5 + _fly_side
	mid.y = maxf(_fly_from.y, to.y) + clampf((to - _fly_from).length() * 0.18, 1.0, 5.0)
	var e := _fly_t * _fly_t
	var a := _fly_from.lerp(mid, e)
	var b := mid.lerp(to, e)
	global_position = a.lerp(b, e)
	if _body:
		_body.scale = Vector3.ONE * lerpf(1.0, 0.55, e)
	if _fly_t >= 1.0:
		_collect()


static func _sparkle_color() -> Color:
	return Color("ffe27a")


## True while the liftoff / pickup sparkles and sounds have room this moment.
static func take_fx() -> bool:
	var now := Time.get_ticks_msec() * 0.001
	if now - _fx_window > FX_BURST:
		_fx_window = now
		_fx_used = 0
	if _fx_used >= FX_PER_BURST:
		return false
	_fx_used += 1
	return true


static func _bag_full_toast() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - _full_toast_at < FULL_TOAST_GAP:
		return
	_full_toast_at = now
	Game.say("กระเป๋าเต็ม! ของยังตกอยู่ที่พื้น ว่างช่องเมื่อไรจะบินมาเก็บเอง", &"warning")


func _collect() -> void:
	var parent := get_parent() as Node3D
	var fx := take_fx()
	if gold > 0:
		Game.add_gold(gold)
		Game.daily_progress("gold", gold)
		if parent != null:
			BattleVfx.floating_text(parent, global_position + Vector3(0, 0.8, 0), "+%d เหรียญ" % gold, Color("ffd84a"), 0.8)
		if fx:
			AudioManager.play_sfx(&"coin", -4.0)
	else:
		if not Game.add_item(item):
			# The bag filled up mid-flight: back on the ground, it waits for room.
			_magnet = false
			if _body:
				_body.scale = Vector3.ONE
			global_position.y = 0.05
			_landed = true
			_age = 0.0
			_landed_at = 0.0
			_bag_full_toast()
			return
		var qty := int(item.get("count", 1))
		if String(item.get("kind", "")) == "jewel":
			Game.guild_quest_progress("jewels", qty)
		if parent != null:
			BattleVfx.floating_text(parent, global_position + Vector3(0, 0.9, 0),
					ItemData.name_of(item) + (" x%d" % qty if qty > 1 else ""), ItemData.color_of(item), 0.85)
		if fx:
			AudioManager.play_sfx(&"pickup", -2.0)
	if fx and parent != null:
		VfxKit.sparks(parent, global_position, _sparkle_color(), 10, 2.5, 0.3)
	queue_free()
