class_name TowerData
extends RefCounted
## The Void Tower: an endless climb of Lv.100 monster waves. Every floor the
## monsters get tougher; every 10th floor is the Void Emperor with an escort.
## Floors pay gold and Void Shards (spent at the tower keeper).

const MIN_LEVEL := 100
const POOL: Array[StringName] = [&"void_golem", &"star_wraith", &"rift_stalker", &"tentacle_horror", &"nova_drake"]
const CHECKPOINT_EVERY := 10

## Shard prices at the keeper.
const COST_REROLL := 40
const COST_GEAR := 60
const COST_GEM := 15


static func is_boss_floor(floor_no: int) -> bool:
	return floor_no % CHECKPOINT_EVERY == 0


## HP / attack multipliers of the monsters on a floor.
static func hp_mult(floor_no: int) -> float:
	return 1.0 + 0.09 * float(floor_no - 1)


static func atk_mult(floor_no: int) -> float:
	return 1.0 + 0.035 * float(floor_no - 1)


## { ids: Array[StringName], boss: bool } for a floor.
static func spec(floor_no: int, rng: RandomNumberGenerator) -> Dictionary:
	var ids: Array[StringName] = []
	if is_boss_floor(floor_no):
		ids.append(&"void_emperor")
		for i in 4:
			ids.append(POOL[rng.randi() % POOL.size()])
		return {"ids": ids, "boss": true}
	var count := clampi(5 + floor_no / 4, 5, 12)
	for i in count:
		ids.append(POOL[rng.randi() % POOL.size()])
	return {"ids": ids, "boss": false}


static func gold_reward(floor_no: int) -> int:
	return floor_no * 2500 * (3 if is_boss_floor(floor_no) else 1)


static func shard_reward(floor_no: int) -> int:
	return 1 + floor_no / 10 + (6 if is_boss_floor(floor_no) else 0)


## Floors you may start from: 1 and every checkpoint (11, 21 ...) up to your best.
static func start_floors(best: int) -> Array[int]:
	var out: Array[int] = [1]
	var f := CHECKPOINT_EVERY + 1
	while f <= best:
		out.append(f)
		f += CHECKPOINT_EVERY
	return out
