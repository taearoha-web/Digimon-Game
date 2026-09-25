class_name Signpost
extends Interactable
## Readable sign showing a DialogueData entry. Builds its own simple mesh.

@export var dialogue_id: StringName
@export var title := "Sign"


func _ready() -> void:
	super._ready()
	prompt_text = "Read"
	interaction_radius = 2.0
	var wood := MeshKit.toon(Color("9a6b44"))
	var board := MeshKit.toon(Color("c99a66"))
	MeshKit.part(self, MeshKit.cylinder(), wood, Vector3(0, 0.6, 0), Vector3(0.12, 1.2, 0.12))
	MeshKit.part(self, MeshKit.box(), board, Vector3(0, 1.15, 0), Vector3(1.1, 0.6, 0.08))
	var label := Label3D.new()
	label.text = L10n.t(title)
	label.pixel_size = 0.004
	label.font_size = 40
	label.outline_size = 8
	label.modulate = Color("3a2412")
	label.outline_modulate = Color(1, 0.9, 0.75, 0.6)
	label.position = Vector3(0, 1.15, 0.05)
	add_child(label)
	var back := label.duplicate() as Label3D
	back.position = Vector3(0, 1.15, -0.05)
	back.rotation.y = PI
	add_child(back)


func _on_interact(_by: Node) -> void:
	var box := DialogueBox.find(get_tree())
	if box:
		await box.play(dialogue_id)
