class_name Npc
extends Node3D
## A villager: a class model standing idle with a name tag and (for the elder)
## a bobbing quest marker. The zone finds the nearest one for the Talk button.

const RADIUS := 3.2

var role := "elder"
var display_name := ""
var visual: HeroVisual
var marker: Label3D


func setup(p_role: String, p_name: String, p_class: StringName, p_title := "", p_model := "") -> void:
	role = p_role
	display_name = p_name
	visual = HeroVisual.new()
	add_child(visual)
	visual.setup(p_class, p_model, false)
	visual.add_to_group("anim_lod")
	var label := Label3D.new()
	label.text = p_name if p_title == "" else "%s\n%s" % [p_name, p_title]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0048
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color("fff2c0")
	label.position = Vector3(0, 2.75, 0)
	label.visibility_range_end = 22.0
	add_child(label)
	marker = Label3D.new()
	marker.text = "!"
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.pixel_size = 0.012
	marker.font_size = 90
	marker.outline_size = 20
	marker.modulate = Color("ffd84a")
	marker.position = Vector3(0, 3.7, 0)
	marker.visible = false
	add_child(marker)
	MeshKit.blob_shadow(self, 0.8)


func _process(_delta: float) -> void:
	if marker and marker.visible:
		marker.position.y = 3.7 + sin(Time.get_ticks_msec() * 0.005) * 0.15


func face(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length_squared() > 0.01:
		visual.rotation.y = atan2(d.x, d.z)
