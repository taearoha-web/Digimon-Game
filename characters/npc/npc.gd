class_name Npc
extends StaticBody3D
## Reusable NPC: chibi avatar, name tag, quest marker and dialogue/quest
## handling through QuestManager. Configure with [member npc_id] (NpcData).

@export var npc_id: StringName
@export var face_player_radius := 6.0
@export var initial_yaw_degrees := 0.0

var data: NpcData
var avatar: ChibiAvatar
var interactable: Interactable
var busy := false

var _marker: Label3D
var _name_label: Label3D
var _player: Node3D
var _yaw := 0.0
var _marker_tween: Tween


func _ready() -> void:
	add_to_group("npcs")
	collision_layer = 1 << 4
	collision_mask = 0
	data = GameData.get_npc(npc_id)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.3
	shape.shape = capsule
	shape.position = Vector3(0, 0.65, 0)
	add_child(shape)

	avatar = ChibiAvatar.new()
	avatar.name = "Avatar"
	add_child(avatar)
	avatar.apply_appearance(CharacterAppearance.from_dict(data.appearance if data else {}))
	_yaw = deg_to_rad(initial_yaw_degrees)
	avatar.rotation.y = _yaw

	interactable = Interactable.new()
	interactable.name = "Interactable"
	interactable.prompt_text = "Talk"
	interactable.interaction_radius = data.interaction_radius if data else 2.6
	interactable.position = Vector3(0, 0.8, 0)
	add_child(interactable)
	interactable.interacted.connect(_on_interacted)

	_name_label = Label3D.new()
	_name_label.text = (data.display_name + ("\n" + data.title if data.title != "" else "")) if data else String(npc_id)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.pixel_size = 0.0035
	_name_label.font_size = 48
	_name_label.outline_size = 14
	_name_label.position = Vector3(0, 1.72, 0)
	_name_label.visibility_range_end = 18.0
	add_child(_name_label)

	_marker = Label3D.new()
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.pixel_size = 0.012
	_marker.font_size = 72
	_marker.outline_size = 18
	_marker.position = Vector3(0, 2.3, 0)
	_marker.no_depth_test = true
	add_child(_marker)
	_marker_tween = create_tween().set_loops()
	_marker_tween.tween_property(_marker, "position:y", 2.45, 0.6).set_trans(Tween.TRANS_SINE)
	_marker_tween.tween_property(_marker, "position:y", 2.3, 0.6).set_trans(Tween.TRANS_SINE)

	QuestManager.tracked_quest_changed.connect(_update_marker)
	EventBus.quest_updated.connect(func(_id): _update_marker())
	_update_marker()


func set_player(player: Node3D) -> void:
	_player = player


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() < face_player_radius:
		_yaw = lerp_angle(_yaw, atan2(to_player.x, to_player.z), 1.0 - exp(-4.0 * delta))
		avatar.rotation.y = _yaw


func _update_marker() -> void:
	if _marker == null:
		return
	match QuestManager.get_npc_marker(npc_id):
		&"available":
			_marker.text = "!"
			_marker.modulate = UIPalette.GOLD
			_marker.visible = true
		&"turn_in":
			_marker.text = "?"
			_marker.modulate = UIPalette.CYAN
			_marker.visible = true
		_:
			_marker.visible = false


func _on_interacted(by: Node) -> void:
	if busy:
		return
	busy = true
	if by is Node3D:
		var to_player := (by as Node3D).global_position - global_position
		_yaw = atan2(to_player.x, to_player.z)
		avatar.rotation.y = _yaw
	avatar.play_once(&"wave", &"idle")
	var result := QuestManager.resolve_npc_interaction(npc_id)
	var box := DialogueBox.find(get_tree())
	if box and result.dialogue_id != &"":
		await box.play(result.dialogue_id, {"npc_name": data.display_name if data else String(npc_id)})
	QuestManager.apply_npc_action(result, npc_id)
	if data and data.service == &"heal_party":
		GameState.roster.heal_all()
		EventBus.toast("Your party was fully healed!", &"success")
	_update_marker()
	# Small cooldown so a held interact key doesn't immediately re-open.
	await get_tree().create_timer(0.3).timeout
	busy = false
