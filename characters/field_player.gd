class_name FieldPlayer
extends Companion
## A world player (WorldPlayers) seen in the zone: the companion's class AI hunting on its
## own. In a field it picks a camp that fits its level, fights the monsters there with its
## class skills and drinks its own potions, leaves monsters the hero is already fighting
## alone and moves on to another camp now and then. In the village it strolls between the
## shops. Monsters fight it like the hero; when it falls it goes back to the village and
## walks in again a while later. Its kills are its own (Mob.party_share).

const CAMP_STAY := Vector2(150.0, 330.0)
const AWAY_AFTER_FALL := 40.0
const HUNT_REACH := 16.0

var world_index := 0
var zone: Zone
var _camp: Dictionary = {}
var _camp_left := 0.0
var _spot := Vector3.ZERO
var _spot_left := 0.0
var _away := false
var _leaving := false
## Running from a fight it was losing until then (ticks), like a player backing off to heal.
var _flee_until := 0
## Out of potions: walking back to the entrance to go and buy more.
var _restocking := false
var _rng := RandomNumberGenerator.new()


func setup_world(p_index: int, p_member: Dictionary, p_hero: Hero, p_zone: Zone) -> void:
	world_index = p_index
	zone = p_zone
	setup(p_member, 0, p_hero, p_zone)
	_rng.seed = hash("%s|%d" % [p_member.name, Time.get_ticks_msec()])


func _ready() -> void:
	super._ready()
	remove_from_group("companions")
	add_to_group("world_players")
	_label.modulate = WorldPlayers.GUILD_COLORS.get(int(WorldPlayers.entry(world_index).guild), Color.WHITE)
	_label.text = _level_text()
	_pick_camp()


func _visual_look() -> Dictionary:
	return WorldPlayers.look(world_index)


## A player's own character: every stat point spent and its skills ranked up (WorldPlayers.profile).
func _party_profile() -> Dictionary:
	return WorldPlayers.profile(member)


func _party_equip() -> Dictionary:
	return WorldPlayers.equip(member)


func _level_text() -> String:
	var guild := WorldPlayers.guild_name(int(WorldPlayers.entry(world_index).guild))
	var stars := Game.party_stars(member)
	return "[%s] %s Lv.%d%s" % [guild, member.name, int(member.level), " ★%d" % stars if stars > 0 else ""]


## New level or stars from the schedule (WorldPresence): the field sees the level-up.
func sync_progress(level: int, stars: int) -> void:
	if level == int(member.level) and stars == int(member.get("stars", 0)):
		return
	var up := level > int(member.level) or stars > int(member.get("stars", 0))
	member["level"] = level
	member["stars"] = stars
	if up and not _dead and visible:
		level_up_fx()
	else:
		refresh()
	_label.text = _level_text() if not _dead else _label.text


## Logs off: a flash and gone.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	if visible and is_instance_valid(field):
		VfxKit.flash(field, global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.4)
	queue_free()


# --- Looking after itself --------------------------------------------------------

func _ally_hp_ratio() -> float:
	return float(hp) / float(maxi(1, max_hp))


func _in_combat() -> bool:
	return target != null and is_instance_valid(target)


func _heal_allies(_fraction: float) -> void:
	pass


func _buff_allies(_buff: Dictionary, _color: Color, _label_text: String, _skill_id: String) -> void:
	pass


## Its own potions only (never the hero's bag); the stock refills in the village.
func _use_potions() -> void:
	if hero.safe_zone:
		member["potions"] = WorldPlayers.POTIONS
		member["mp_potions"] = WorldPlayers.MP_POTIONS
		return
	if _potion_cd > 0.0 or Time.get_ticks_msec() < _cast_until:
		return
	if int(member.get("potions", 0)) <= 0 and float(hp) / float(max_hp) < 0.5:
		_restocking = true
	if float(hp) / float(max_hp) < 0.5 and int(member.get("potions", 0)) > 0:
		member["potions"] = int(member.potions) - 1
		_drink_hp(0.45)
		_potion_cd = 3.5
	elif mp < float(stats.max_mp) * 0.2 and int(member.get("mp_potions", 0)) > 0:
		member["mp_potions"] = int(member.mp_potions) - 1
		_drink_mp(float(stats.max_mp) * 0.5)
		_potion_cd = 3.5


func _die() -> void:
	_dead = true
	target = null
	_revive_timer = 6.0
	_away = false
	visual.hold_last_frame("Death_A")
	_label.text = "%s ล้ม..." % member.name
	_bar.visible = false
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.8, 0), "ล้ม!", Color("ff7a8a"), 1.0)


## After falling: gone to the village for a while, then walks back in from the field's entrance.
func _revive() -> void:
	if not _away:
		_away = true
		visible = false
		_revive_timer = AWAY_AFTER_FALL
		return
	_away = false
	_dead = false
	visible = true
	hp = max_hp
	mp = float(stats.max_mp)
	member["potions"] = WorldPlayers.POTIONS
	member["mp_potions"] = WorldPlayers.MP_POTIONS
	_invulnerable_until = Time.get_ticks_msec() + 2500
	visual.release()
	visual.play("Idle")
	global_position = zone.entrance() + Vector3(_rng.randf_range(-2.0, 2.0), 0.3, _rng.randf_range(-2.0, 2.0))
	_label.text = _level_text()
	_update_bar()
	_pick_camp()


# --- Where it goes -----------------------------------------------------------------

## A camp that fits its level (one of the two closest, so players spread out).
func _pick_camp() -> void:
	_camp_left = _rng.randf_range(CAMP_STAY.x, CAMP_STAY.y)
	if zone == null or zone.is_town or zone._camps.is_empty():
		_camp = {}
		return
	var level := int(member.level)
	var ranked := zone._camps.duplicate()
	ranked.sort_custom(func(a, b): return _fit(a, level) < _fit(b, level))
	_camp = ranked[_rng.randi() % mini(2, ranked.size())]
	_spot_left = 0.0


static func _fit(camp: Dictionary, level: int) -> float:
	var lv: Array = camp.get("levels", [level, level])
	if level >= int(lv[0]) and level <= int(lv[1]):
		return 0.0
	return absf((float(lv[0]) + float(lv[1])) * 0.5 - float(level))


func camp() -> Dictionary:
	return _camp


func _camp_center() -> Vector3:
	return Vector3(_camp.pos.x, 0.0, _camp.pos.y) if not _camp.is_empty() else global_position


## Losing and out of potions for now: backs off out of the fight.
func _fight(delta: float) -> Vector3:
	if float(hp) / float(max_hp) < 0.25 and (_potion_cd > 0.0 or int(member.get("potions", 0)) <= 0):
		_flee_until = Time.get_ticks_msec() + 7000
		target = null
		return _follow(delta)
	return super._fight(delta)


func _fleeing() -> bool:
	return _restocking or Time.get_ticks_msec() < _flee_until


## Gone to the village to buy potions: away a while, then back from the entrance (the
## same way as after a fall).
func _go_shopping() -> void:
	_restocking = false
	_dead = true
	target = null
	_away = true
	visible = false
	_revive_timer = AWAY_AFTER_FALL


## Nearest monster of its camp that nobody on the hero's side is fighting (or that is
## attacking it); field bosses only when they come for it.
func _pick_target() -> Mob:
	if hero.safe_zone or _camp.is_empty() or _fleeing():
		return null
	var center := _camp_center()
	var reach := float(_camp.radius) + 8.0
	var best: Mob = null
	var best_d := HUNT_REACH
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob == null or mob.is_dead() or mob is Rival:
			continue
		var on_me: bool = mob._victim == self
		if not on_me and (mob.is_boss or mob.party_damage > 0 or (hero.target == mob)):
			continue
		if not on_me and _flat(mob.global_position - center).length() > reach:
			continue
		var d := _flat(mob.global_position - global_position).length() * (0.5 if on_me else 1.0)
		if d < best_d:
			best_d = d
			best = mob
	return best


## No fight: walk to the camp and drift around in it (in the village, between the shops);
## backing off, it runs towards the field's entrance.
func _follow(delta: float) -> Vector3:
	if _fleeing() and zone != null:
		var away := _flat(zone.entrance() - global_position)
		if away.length() > 2.0:
			_face(away, delta, 12.0)
			return away.normalized() * float(stats.speed) * 1.15
		if _restocking:
			_go_shopping()
			return Vector3.ZERO
	_camp_left -= delta
	if _camp_left <= 0.0:
		_pick_camp()
	_spot_left -= delta
	if _spot_left <= 0.0:
		_spot_left = _rng.randf_range(3.0, 8.0)
		if zone != null and zone.is_town:
			var spots: Array = zone.npcs
			if not spots.is_empty():
				var npc: Node3D = spots[_rng.randi() % spots.size()]
				_spot = npc.global_position + Vector3(_rng.randf_range(-3.0, 3.0), 0, _rng.randf_range(2.0, 4.0))
				_spot_left = _rng.randf_range(8.0, 20.0)
		else:
			var r := float(_camp.get("radius", 6.0)) * 0.6
			_spot = _camp_center() + Vector3(_rng.randf_range(-r, r), 0, _rng.randf_range(-r, r))
	var to := _flat(_spot - global_position)
	if to.length() < 0.8:
		return Vector3.ZERO
	_face(to, delta, 10.0)
	var speed := float(stats.speed) * (1.0 if to.length() > 4.0 else 0.6)
	return to.normalized() * minf(speed, to.length() * 4.0)
