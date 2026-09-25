class_name RecoveryTerminal
extends Interactable
## Heals the whole party and sets the respawn point. Placeholder kiosk mesh.

@export var respawn_spawn_id: StringName = &"start"

var _hologram: Node3D


func _ready() -> void:
	super._ready()
	prompt_text = "Heal"
	interaction_radius = 2.4
	interaction_priority = 1
	var base := MeshKit.toon(Color("dfe7ff"))
	var dark := MeshKit.toon(Color("27316b"))
	var glow := MeshKit.toon(UIPalette.CYAN, {"emission": 1.5})
	MeshKit.part(self, MeshKit.cylinder(), dark, Vector3(0, 0.08, 0), Vector3(1.6, 0.16, 1.6))
	MeshKit.part(self, MeshKit.box(), base, Vector3(0, 0.75, 0), Vector3(0.9, 1.3, 0.55))
	MeshKit.part(self, MeshKit.box(), glow, Vector3(0, 1.05, 0.28), Vector3(0.7, 0.45, 0.02))
	MeshKit.part(self, MeshKit.torus(), glow, Vector3(0, 0.17, 0), Vector3(1.55, 0.3, 1.55))
	_hologram = Node3D.new()
	_hologram.position = Vector3(0, 2.05, 0)
	add_child(_hologram)
	var plus := MeshKit.toon(Color("5ad17a"), {"emission": 1.2})
	MeshKit.part(_hologram, MeshKit.box(), plus, Vector3.ZERO, Vector3(0.5, 0.16, 0.16))
	MeshKit.part(_hologram, MeshKit.box(), plus, Vector3.ZERO, Vector3(0.16, 0.5, 0.16))
	var spin := create_tween().set_loops()
	spin.tween_property(_hologram, "rotation:y", TAU, 4.0).from(0.0)
	var label := Label3D.new()
	label.text = L10n.t("Recovery Terminal")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0035
	label.font_size = 44
	label.outline_size = 12
	label.position = Vector3(0, 2.6, 0)
	label.visibility_range_end = 18.0
	add_child(label)


func _on_interact(_by: Node) -> void:
	GameState.roster.heal_all()
	GameState.world.respawn_map_id = GameState.world.current_map_id
	GameState.world.respawn_spawn_id = respawn_spawn_id
	AudioManager.play_sfx(&"heal")
	var tween := create_tween()
	tween.tween_property(_hologram, "scale", Vector3.ONE * 1.8, 0.2)
	tween.tween_property(_hologram, "scale", Vector3.ONE, 0.3)
	var box := DialogueBox.find(get_tree())
	if box:
		await box.play(&"terminal_heal")
	EventBus.toast(L10n.t("Party fully healed!"), &"success")
