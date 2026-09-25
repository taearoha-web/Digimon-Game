class_name Interactable
extends Area3D
## Reusable interaction component. Add as a child of anything the player can
## use (NPCs, signs, portals, pickups, terminals) and connect [signal
## interacted], or subclass and override [method _on_interact].

signal interacted(by: Node)

@export var prompt_text := "Interact"
@export var interaction_radius := 2.2:
	set(value):
		interaction_radius = value
		_update_shape()
@export var enabled := true
## Higher priority wins when several interactables are in range.
@export var interaction_priority := 0
## Optional look for the HUD action button (defaults: speech icon, orange).
@export var prompt_icon: Texture2D
@export var prompt_accent := Color(0, 0, 0, 0)

var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 0
	monitoring = false
	monitorable = true
	_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _shape == null:
		_shape = CollisionShape3D.new()
		_shape.name = "CollisionShape3D"
		add_child(_shape)
	_update_shape()


func can_interact(_by: Node) -> bool:
	return enabled


func interact(by: Node) -> void:
	if not can_interact(by):
		return
	interacted.emit(by)
	_on_interact(by)


## Override in subclasses.
func _on_interact(_by: Node) -> void:
	pass


func get_prompt() -> String:
	return prompt_text


func _update_shape() -> void:
	if _shape == null:
		return
	var sphere := _shape.shape as SphereShape3D
	if sphere == null:
		sphere = SphereShape3D.new()
		_shape.shape = sphere
	sphere.radius = interaction_radius
