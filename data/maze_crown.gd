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
