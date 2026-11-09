class_name HallMate
extends FieldPlayer
## A guild mate idling in the guild hall (GuildHallData.mates): the world player's own
## body, gear and name plate (FieldPlayer), strolling between the hall's spots
## (GuildHall.SPOTS), standing a while at each, and now and then saying a line of guild
## talk over its head (GuildHallData.chatter; at most one bubble in the hall every
## BUBBLE_GAP seconds). It never fights (the training dummy is not its business), never
## rides indoors and keeps its wings down. Far from the hero it animates in steps like
## every world player (FieldPlayer._update_lod).

const STAY := Vector2(7.0, 20.0)
const CHAT_EVERY := Vector2(14.0, 32.0)
const BUBBLE_GAP := 4.0
const CHAT_NEAR := 24.0

var guild := 0
var spots: Array[Vector3] = []
var _stroll := Vector3.INF
var _stay := 0.0
var _chat_in := 0.0
static var last_bubble_at := -INF


func setup_hall(p_index: int, p_member: Dictionary, p_hero: Hero, p_zone: Zone, p_guild: int, p_spots: Array[Vector3], seed_value: int) -> void:
	guild = p_guild
	spots = p_spots
	setup_world(p_index, p_member, p_hero, p_zone)
	_rng.seed = seed_value
	_stay = _rng.randf_range(2.0, 9.0)
	_chat_in = _rng.randf_range(3.0, CHAT_EVERY.y)


func _ready() -> void:
	super._ready()
	if not spots.is_empty():
		_stroll = spots[_rng.randi() % spots.size()]


func _pick_target() -> Mob:
	return null


func wants_ride(_roll: float) -> bool:
	return false


## Indoors the wings stay standing or folded, never flying.
func _think_wings(delta: float) -> void:
	if _dead or not is_instance_valid(visual) or not visual.has_wings():
		return
	_wing_think -= delta
	if _wing_think > 0.0:
		return
	_wing_think = _rng.randf_range(20.0, 60.0)
	var mode := HeroVisual.WING_FOLD if _rng.randf() < 0.6 else HeroVisual.WING_STAND
	if mode != visual.wing_mode:
		visual.set_wing_mode(mode)


func _hover(_delta: float) -> void:
	pass


## Strolls between the hall's spots, stands a while at each facing the room's middle.
func _follow(delta: float) -> Vector3:
	if party_mode:
		return super._follow(delta)
	_chat(delta)
	if spots.is_empty():
		return Vector3.ZERO
	if not _stroll.is_finite():
		_stroll = spots[_rng.randi() % spots.size()]
	var to := _flat(_stroll - global_position)
	if to.length() > 0.7:
		_face(to, delta, 10.0)
		return to.normalized() * minf(float(stats.speed) * 0.55, to.length() * 3.0)
	_stay -= delta
	if _stay <= 0.0:
		_stay = _rng.randf_range(STAY.x, STAY.y)
		var next: Vector3 = spots[_rng.randi() % spots.size()]
		if next != _stroll:
			_stroll = next
	else:
		# Turned towards the middle of the room (the carpet), with a little of its own angle.
		var middle := _flat(Vector3(0, 0, -2.0) - global_position)
		if middle.length() > 1.0:
			_face(middle, delta, 2.5)
	return Vector3.ZERO


func _chat(delta: float) -> void:
	_chat_in -= delta
	if _chat_in > 0.0 or hero == null or not is_instance_valid(hero):
		return
	_chat_in = _rng.randf_range(CHAT_EVERY.x, CHAT_EVERY.y)
	var now := Time.get_ticks_msec() * 0.001
	if now - last_bubble_at < BUBBLE_GAP or _flat(hero.global_position - global_position).length() > CHAT_NEAR:
		return
	last_bubble_at = now
	bubble(GuildHallData.chatter(world_index, guild, WorldPresence.clock()), false)
