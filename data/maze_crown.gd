class_name MazeCrown
extends RefCounted
## STUB (team maze): the crown of เขาวงกตหนึ่งในใต้หล้า is team crown's (the title, the
## costume เทพราชันหนึ่งในใต้หล้า, its expiry and the award flow). This file only holds
## the contract's names so the maze compiles until theirs replaces it; take theirs whole.

const TITLE_NAME := "หนึ่งในใต้หล้า"
const COSTUME_ID := "maze_sovereign"


## Called on load and when a week boundary passes (MazeMatch / Game): the crown's award
## and expiry. Nothing here (team crown).
static func settle(_t: float) -> void:
	pass


## The current crown holder for display: the last ended week's champion ({} none).
static func holder(t: float) -> Dictionary:
	return MazeWar.champion(MazeWar.week_of(t) - 1)


static func wearing_crown(_item_or_profile: Variant) -> bool:
	return false


## Whether world player i holds the crown now (the last ended week's champion).
static func ai_holds(i: int, t := -1.0) -> bool:
	var h := holder(MazeWar.now() if t < 0.0 else t)
	return not h.is_empty() and not bool(h.get("hero", false)) and int(h.get("index", -1)) == i


## The gold title plate over a name label (team crown draws the real one).
static func attach_plate(label: Label3D, on: bool) -> void:
	if not is_instance_valid(label):
		return
	var plate := label.get_node_or_null("CrownPlate") as Label3D
	if not on:
		if plate != null:
			plate.queue_free()
		return
	if plate == null:
		plate = Label3D.new()
		plate.name = "CrownPlate"
		plate.text = "♛ %s ♛" % TITLE_NAME
		plate.modulate = MazeWar.COLOR
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.pixel_size = label.pixel_size
		plate.font_size = label.font_size
		plate.position = Vector3(0, 0.3, 0)
		label.add_child(plate)
