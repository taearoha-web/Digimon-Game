class_name MazeWar
extends RefCounted
## STUB written by team `crown` so data/maze_crown.gd compiles on its own: team `maze`
## owns the real เขาวงกตหนึ่งในใต้หล้า (data/maze_war.gd). Delete this file when merging
## and keep team maze's. Only the contract's names, with the guild league's week.

const ID := &"maze_war"
const TITLE := "เขาวงกตหนึ่งในใต้หล้า"


static func week_of(t: float) -> int:
	return GuildLeague.week_of(t)


static func week_end(week: int) -> float:
	return GuildLeague.week_end(week)


static func standings(_week: int, _t: float = -1.0) -> Array:
	return []


static func champion(_week: int) -> Dictionary:
	return {}
