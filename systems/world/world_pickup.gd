class_name WorldPickup
extends Interactable
## One-time item pickup floating in the world. Remembered in WorldState so it
## stays collected after saving/loading.

@export var pickup_id := ""
@export var item_id: StringName
@export var amount := 1

var _visual: Node3D


func _ready() -> void:
	super._ready()
	prompt_text = "Pick up"
	interaction_radius = 1.8
	add_to_group("pickups")
	if pickup_id != "" and GameState.world.is_pickup_collected(pickup_id):
		queue_free()
		return
	_build_visual()


func _on_interact(_by: Node) -> void:
	var item := GameData.get_item(item_id)
	if item == null:
		return
	var added := GameState.inventory.add_item(item_id, amount)
	if added <= 0:
		EventBus.toast("You can't carry more %s." % item.display_name, &"warning")
		return
	enabled = false
	if pickup_id != "":
		GameState.world.mark_pickup_collected(pickup_id)
	EventBus.toast("Obtained %s ×%d" % [item.display_name, added], &"item")
	AudioManager.play_sfx(&"pickup")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_visual, "position:y", _visual.position.y + 1.2, 0.35)
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.05, 0.35)
	tween.chain().tween_callback(queue_free)


func _build_visual() -> void:
	var item := GameData.get_item(item_id)
	var color := item.icon_color if item else UIPalette.CYAN
	_visual = Node3D.new()
	_visual.position = Vector3(0, 0.9, 0)
	add_child(_visual)
	var core_mesh := MeshKit.box() if item and item.category == ItemData.Category.QUEST else MeshKit.capsule()
	var core_scale := Vector3(0.36, 0.36, 0.36) if item and item.category == ItemData.Category.QUEST else Vector3(0.24, 0.16, 0.24)
	var core := MeshKit.part(_visual, core_mesh, MeshKit.toon(color, {"emission": 1.4}), Vector3.ZERO, core_scale, Vector3(35, 0, 35))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := MeshKit.part(_visual, MeshKit.sphere(), MeshKit.toon(Color(color.r, color.g, color.b, 0.22), {"unshaded": true, "alpha": 0.22}), Vector3.ZERO, Vector3.ONE * 0.75)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := MeshKit.part(self, MeshKit.torus(), MeshKit.toon(color, {"unshaded": true}), Vector3(0, 0.05, 0), Vector3(0.9, 0.3, 0.9))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spin := create_tween().set_loops()
	spin.tween_property(_visual, "rotation:y", TAU, 3.0).from(0.0)
	var bob := create_tween().set_loops()
	bob.tween_property(_visual, "position:y", 1.1, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_visual, "position:y", 0.9, 0.9).set_trans(Tween.TRANS_SINE)
