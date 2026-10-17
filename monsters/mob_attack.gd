class_name MobAttack
extends BossAttack
## Short signature moves of ordinary field monsters (MonsterData "behavior").
## Same contract as BossAttack (locked, drawn warnings, one hit per wave), but
## small: at most 3 circles, light strike effects, and a cap on how many of
## these moves may run at once (by graphics quality) so a crowded camp cannot
## flood the screen. A monster over the cap just uses its basic attack.

## range: how far away the monster may start the move (dashes / leaps).
const MOB_MOVES := {
	"lunge": {"style": "mob", "slow": 0.0, "range": 5.5},
	"pounce": {"style": "mob", "slow": 0.0, "range": 5.0},
	"cleave": {"style": "mob", "slow": 0.0, "range": 0.0},
	"spin": {"style": "mob", "slow": 0.0, "range": 0.0},
	"volley": {"style": "mob", "slow": 0.0, "range": 0.0},
	"beam": {"style": "mob", "slow": 0.0, "range": 0.0},
	"mortar": {"style": "mob", "slow": 0.0, "range": 0.0},
}
const ACTIVE_LIMIT := [3, 5, 7]

static var _active := 0
var dash := false
var dash_to := Vector3.ZERO


static func knows(template: Dictionary) -> bool:
	return not bool(template.get("boss", false)) and MOB_MOVES.has(String(template.get("behavior", "")))


static func trigger_range(template: Dictionary) -> float:
	return float(MOB_MOVES.get(String(template.get("behavior", "")), {}).get("range", 0.0))


static func active_count() -> int:
	return _active


static func has_room() -> bool:
	return _active < int(ACTIVE_LIMIT[VfxBudget.quality()])


## Starts the monster's move; false when the cap is full or there is no victim.
static func launch(actor: Mob) -> bool:
	if not actor._alive(actor._victim) or not has_room():
		return false
	var attack := MobAttack.new()
	attack.mob = actor
	attack.move = String(actor.template.behavior)
	actor._winding = true
	actor._attack_timer = randf_range(2.2, 3.2)
	actor.add_child(attack)
	return true


func _ready() -> void:
	_active += 1
	super()


func _exit_tree() -> void:
	_active = maxi(0, _active - 1)
	super()


func _info() -> Dictionary:
	return MOB_MOVES[move]


func _build(origin: Vector3, forward: Vector3, hero_pos: Vector3, _heading: Vector3, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out := mob_plan(move, origin, forward, hero_pos, rng)
	if move == "lunge" or move == "pounce":
		dash = true
		dash_to = out[0].pos
	return out


func _announce() -> void:
	pass


## Dash / leap through the last 0.3 s of the warning, onto the locked circle.
func _motion(delta: float) -> void:
	if not dash or shots.is_empty():
		return
	var contact := float(shots[0].at)
	if age > contact - 0.3 and age <= contact:
		var step := (dash_to - mob.global_position) * Vector3(1, 0, 1)
		mob.move_and_collide(step.limit_length(18.0 * delta))


func _strike_vfx(shot: Dictionary) -> void:
	var parent := mob.get_parent()
	var color: Color = mob.template.get("color", Color("ffb04a"))
	VfxKit.impact_ring(parent, shot.pos + Vector3(0, 0.1, 0), color, float(shot.r) * 0.7, 0.3)
	BattleVfx.burst(parent, shot.pos + Vector3(0, 0.3, 0), color, 5, 0.7)


static func mob_plan(move_id: String, o: Vector3, f: Vector3, h: Vector3, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var reach := (h - o).length()
	match move_id:
		"lunge":
			out.append(_shot(o + f * minf(5.0, reach), 1.5, 0.8, 1.3, 0))
		"pounce":
			out.append(_shot(o + f * minf(4.8, reach), 2.0, 0.9, 1.4, 0))
		"cleave":
			out.append(_shot(o + f * 1.8, 2.0, 0.8, 1.2, 0))
		"spin":
			out.append(_shot(o, 2.8, 0.9, 1.2, 0))
		"volley":
			out.append(_shot(h, 1.4, 1.1, 0.8, 0))
			for p in _around(h, 2, 2.0, 3.2, rng):
				out.append(_shot(p, 1.4, 1.1, 0.8, 0))
		"beam":
			for i in 3:
				out.append(_shot(o + f * (2.5 + 2.0 * i), 1.2, 0.9 + 0.12 * i, 0.8, i))
		"mortar":
			out.append(_shot(h, 2.0, 1.2, 1.2, 0))
	return out
