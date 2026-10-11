class_name Npc
extends Node3D
## A villager: a class model standing idle with a name tag and (for the elder)
## a bobbing quest marker. The zone finds the nearest one for the Talk button.

const RADIUS := 3.2
## Each villager's own look: a FaceKit face, an outfit [model, tint, cape part]
## and Japanese headwear (see JapanKit.hat), so no two look alike.
const LOOKS := {
	"elder": {"gender": 0, "skin": 2, "hair": 4, "hair_color": 5, "eyes": 3, "eye_color": 0, "nose": 2, "mouth": 1,
		"npc_outfit": ["Mage", Color(0.85, 0.7, 0.5), ""], "npc_hat": ["eboshi", Color.BLACK]},
	"job": {"gender": 0, "skin": 3, "hair": 1, "hair_color": 0, "eyes": 4, "eye_color": 3, "nose": 2, "mouth": 1,
		"npc_outfit": ["Knight", Color(1.5, 0.55, 0.45), "Knight_Cape"], "npc_hat": ["hachimaki", Color("f4f0e8")]},
	"skill": {"gender": 1, "skin": 0, "hair": 6, "hair_color": 10, "eyes": 0, "eye_color": 4, "nose": 0, "mouth": 0,
		"npc_outfit": ["Mage", Color(0.75, 0.6, 1.35), "Mage_Cape"], "npc_hat": ["ribbon", Color("9a6ad8")]},
	"shop": {"gender": 0, "skin": 1, "hair": 7, "hair_color": 1, "eyes": 3, "eye_color": 0, "nose": 1, "mouth": 2,
		"npc_outfit": ["Rogue", Color(0.6, 0.8, 1.5), ""], "npc_hat": ["tenugui", Color("5a7ad8")]},
	"forge": {"gender": 0, "skin": 4, "hair": 3, "hair_color": 4, "eyes": 4, "eye_color": 5, "nose": 3, "mouth": 4,
		"npc_outfit": ["Barbarian", Color(0.85, 0.75, 0.7), ""], "npc_hat": ["hachimaki", Color("d8452e")]},
	"storage": {"gender": 0, "skin": 2, "hair": 2, "hair_color": 2, "eyes": 2, "eye_color": 3, "nose": 1, "mouth": 1,
		"npc_outfit": ["Rogue", Color(0.75, 0.95, 0.75), "Rogue_Cape"], "npc_hat": ["kasa", Color.WHITE]},
	"party": {"gender": 1, "skin": 1, "hair": 1, "hair_color": 11, "eyes": 0, "eye_color": 2, "nose": 0, "mouth": 2,
		"npc_outfit": ["Ranger", Color(1.45, 0.75, 0.75), ""], "npc_hat": ["ribbon", Color("e8463a")]},
	"arena": {"gender": 0, "skin": 5, "hair": 4, "hair_color": 0, "eyes": 4, "eye_color": 0, "nose": 3, "mouth": 4,
		"npc_outfit": ["Barbarian", Color(1.4, 1.2, 0.6), ""], "npc_hat": ["hachimaki", Color("2f4f8a")]},
	"pvp": {"gender": 1, "skin": 2, "hair": 4, "hair_color": 0, "eyes": 4, "eye_color": 1, "nose": 0, "mouth": 1,
		"npc_outfit": ["Knight", Color(0.6, 0.85, 1.6), "Knight_Cape"], "npc_hat": ["hachimaki", Color("f4f0e8")]},
	"tower": {"gender": 0, "skin": 7, "hair": 2, "hair_color": 8, "eyes": 2, "eye_color": 4, "nose": 0, "mouth": 1,
		"npc_outfit": ["Rogue", Color(0.55, 0.5, 0.75), "Rogue_Cape"], "npc_hat": ["kasa", Color.WHITE]},
	"healer": {"gender": 1, "skin": 0, "hair": 6, "hair_color": 0, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 0,
		"npc_outfit": ["Mage", Color(1.15, 1.08, 1.05), ""], "npc_wash": 0.9, "npc_hat": ["ribbon", Color("e8463a")]},
	"guide": {"gender": 1, "skin": 1, "hair": 3, "hair_color": 7, "eyes": 3, "eye_color": 1, "nose": 1, "mouth": 2,
		"npc_outfit": ["Ranger", Color(0.7, 1.2, 1.5), ""], "npc_hat": ["tenugui", Color("f4f0e8")]},
}

var role := "elder"
var display_name := ""
var visual: HeroVisual
var marker: Label3D


func setup(p_role: String, p_name: String, p_class: StringName, p_title := "", p_model := "", p_look := {}) -> void:
	role = p_role
	display_name = p_name
	visual = HeroVisual.new()
	add_child(visual)
	visual.setup(p_class, p_model, false, {}, p_look)
	visual.add_to_group("anim_lod")
	var label := Label3D.new()
	label.text = p_name if p_title == "" else "%s\n%s" % [p_name, p_title]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0048
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color("fff2c0")
	label.position = Vector3(0, 3.05 if p_look.has("npc_hat") else 2.75, 0)
	label.visibility_range_end = 22.0
	add_child(label)
	marker = Label3D.new()
	marker.text = "!"
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.pixel_size = 0.012
	marker.font_size = 90
	marker.outline_size = 20
	marker.modulate = Color("ffd84a")
	marker.position = Vector3(0, 4.0, 0)
	marker.visible = false
	add_child(marker)
	MeshKit.blob_shadow(self, 0.8)


func _process(_delta: float) -> void:
	if marker and marker.visible:
		marker.position.y = 4.0 + sin(Time.get_ticks_msec() * 0.005) * 0.15


func face(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length_squared() > 0.01:
		visual.rotation.y = atan2(d.x, d.z)
