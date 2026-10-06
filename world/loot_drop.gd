class_name LootDrop
extends Node3D
## Gold or an item lying on the ground: tossed out of a monster, glowing in
## its rarity colour, and picked up automatically when the hero walks near.

const PICKUP_RADIUS := 8.0
const LIFETIME := 120.0

var item: Dictionary = {}
var gold := 0
var hero: Node3D

var _age := 0.0
var _magnet := false
var _body: Node3D
var _landed := false


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
			VfxKit.loot_beam(self, color, 2.0 + rarity * 1.4)
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
	tween.tween_callback(func(): _landed = true)


func _process(delta: float) -> void:
	_age += delta
	if _body:
		_body.rotation.y += delta * 2.0
		_body.position.y = sin(_age * 3.0) * 0.06
	if _age > LIFETIME:
		queue_free()
		return
	if not _landed or hero == null or not is_instance_valid(hero) or hero.is_dead():
		return
	var to := hero.global_position + Vector3(0, 0.8, 0) - global_position
	var flat := Vector2(to.x, to.z).length()
	if _magnet:
		global_position += to.normalized() * delta * 16.0
		if to.length() < 0.5:
			_collect()
	elif flat < PICKUP_RADIUS and _age > 0.5:
		if gold == 0 and not ItemData.is_stackable(item) and Game.inventory_free() <= 0:
			if int(_age * 2.0) % 6 == 0:
				pass
			return
		_magnet = true


func _collect() -> void:
	var parent := get_parent() as Node3D
	if gold > 0:
		Game.add_gold(gold)
		BattleVfx.floating_text(parent, global_position + Vector3(0, 0.8, 0), "+%d เหรียญ" % gold, Color("ffd84a"), 0.8)
		AudioManager.play_sfx(&"coin", -4.0)
	else:
		if not Game.add_item(item):
			_magnet = false
			Game.say("กระเป๋าเต็ม!", &"warning")
			_age = 0.0
			return
		var qty := int(item.get("count", 1))
		BattleVfx.floating_text(parent, global_position + Vector3(0, 0.9, 0),
				ItemData.name_of(item) + (" x%d" % qty if qty > 1 else ""), ItemData.color_of(item), 0.85)
		AudioManager.play_sfx(&"pickup", -2.0)
	VfxKit.sparks(parent, global_position, Color("ffe27a"), 10, 2.5, 0.3)
	queue_free()
