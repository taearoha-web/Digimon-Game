class_name AreaTrigger
extends Area3D
## Emits EventBus.area_entered when the player walks in (quests use it for
## REACH_AREA objectives; the HUD shows the area name banner).

@export var area_id: StringName
@export var display_name := ""
@export var radius := 8.0
@export var show_banner := true

var _inside := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1
	monitoring = true
	monitorable = false
	if get_node_or_null("CollisionShape3D") == null:
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = 12.0
		shape.shape = cylinder
		add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController and not _inside:
		_inside = true
		EventBus.area_entered.emit(area_id, display_name if show_banner else "")


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		_inside = false
