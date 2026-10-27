class_name FieldPlayer
extends Companion
## A world player (WorldPlayers) seen in the zone: the companion's class AI hunting on its
## own. In a field it picks a camp that fits its level, fights the monsters there with its
## class skills and drinks its own potions, leaves monsters the hero is already fighting
## alone and moves on to another camp now and then. In the village it strolls between the
## shops. Monsters fight it like the hero; when it falls it goes back to the village and
## walks in again a while later. Its kills are its own (Mob.party_share).
## In the hero's party (party_mode, Game.party_invite) it is a companion instead: it walks
## with the hero from zone to zone, fights what the hero fights, heals and buffs the hero,
## gets back up beside the hero, and its kills count for the party (the EXP is shared).
## It wears what it has found (WorldPlayers.equip) and shows each new piece as it puts it
## on; with wings it flies, stands or folds them as it pleases.

const CAMP_STAY := Vector2(150.0, 330.0)
const AWAY_AFTER_FALL := 40.0
const HUNT_REACH := 16.0

var world_index := 0
## In the hero's party: the companion's own following, targeting and support.
var party_mode := false
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
## Wing pose it picks for itself now and then (HeroVisual.WING_*), and when it thinks again.
var _wing_think := 0.0
var _worn: Dictionary = {}


func setup_world(p_index: int, p_member: Dictionary, p_hero: Hero, p_zone: Zone) -> void:
	world_index = p_index
	zone = p_zone
	setup(p_member, 0, p_hero, p_zone)
	_rng.seed = hash("%s|%d" % [p_member.name, Time.get_ticks_msec()])


func _ready() -> void:
	super._ready()
	if not party_mode:
		remove_from_group("companions")
		add_to_group("world_players")
	_label.text = _level_text()
	_worn = _party_equip()
	_wing_think = _rng.randf_range(0.5, 4.0)
	_pick_camp()


func _visual_look() -> Dictionary:
	return WorldPlayers.look(world_index)


## A player's own character: every stat point spent and its skills ranked up (WorldPlayers.profile).
func _party_profile() -> Dictionary:
	return WorldPlayers.profile(member)


func _party_equip() -> Dictionary:
	return WorldPlayers.equip(member)


## A new find or enhancement re-dresses it (Companion.refresh).
func _signature() -> String:
	return WorldPlayers.gear_signature(member)


func refresh() -> void:
	var before := _equip_sig
	super.refresh()
	if before == "" or _equip_sig == before or not is_instance_valid(visual):
		return
	var now_worn := _party_equip()
	var piece := WorldPlayers.new_piece(_worn, now_worn)
	_worn = now_worn
	if not piece.is_empty() and visible and not _dead and is_instance_valid(field):
		var plus := int(piece.get("plus", 0))
		say(("สวม %s +%d" % [piece.name, plus]) if plus > 0 else ("สวม %s" % piece.name), ItemData.RARITY_COLORS[clampi(int(piece.get("rarity", 0)), 0, 4)])


## "[Alpha] Kaito Lv.100 ★44" in the guild's colour; no tag before Lv.100 (no guild yet).
func _level_text() -> String:
	var g := WorldPlayers.guild_at(world_index, int(member.level))
	_label.modulate = WorldPlayers.GUILD_COLORS.get(g, Color("e8f4ff"))
	var stars := Game.party_stars(member)
	return "%s%s Lv.%d%s" % ["[%s] " % WorldPlayers.guild_name(g) if g > 0 else "", member.name, int(member.level), " ★%d" % stars if stars > 0 else ""]


## New level, stars or finds from the schedule (WorldPresence): the field sees the
## level-up and the new piece put on.
func sync_progress(s: Dictionary) -> void:
	var up := int(s.level) > int(member.level) or int(s.stars) > int(member.get("stars", 0))
	var dressed := WorldPlayers.sync_member(member, s)
	if up and not _dead and visible:
		level_up_fx()
	elif up or dressed:
		refresh()
	_label.text = _level_text() if not _dead else _label.text


## Lv.10: the Vagabond takes its line (the body is rebuilt in Companion.refresh).
func _class_changed() -> void:
	if visible and not _dead and is_instance_valid(field):
		VfxKit.level_up(field, global_position)
		say("เปลี่ยนอาชีพเป็น %s!" % String(ClassData.get_class_data(StringName(member["class"])).name), Color("ffd24a"))


## A line above its head (its answer to an invitation, a new piece of gear).
func say(text: String, color := Color("fff4c0")) -> void:
	if is_instance_valid(field):
		BattleVfx.floating_text(field, global_position + Vector3(0, 3.4, 0), text, color, 1.1)


## Joins the hero's party where it stands: from now on a companion (stance, follows, shares).
func join_party(m: Dictionary, k: int) -> void:
	party_mode = true
	member = m
	index = k
	target = null
	_restocking = false
	_flee_until = 0
	remove_from_group("world_players")
	add_to_group("companions")
	refresh()
	_label.text = _level_text()


## Leaves the party but stays in the game: back to hunting a camp of its own.
func leave_party() -> void:
	party_mode = false
	target = null
	member = member.duplicate()
	remove_from_group("companions")
	add_to_group("world_players")
	if _dead:
		_dead = false
		hp = maxi(1, max_hp / 2)
		visual.release()
		visual.play("Idle")
	_label.text = _level_text()
	_pick_camp()


## Logs off: a flash and gone.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	if visible and is_instance_valid(field):
		VfxKit.flash(field, global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.4)
	queue_free()


# --- Wings ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if stats.is_empty() or not is_instance_valid(visual):
		return
	_think_wings(delta)
	_hover(delta)


## Picks its wing pose now and then, as it pleases: its own taste (WorldPlayers.wing_taste),
## a little more flying on the way somewhere and a little less in the village.
func _think_wings(delta: float) -> void:
	if _dead or not visual.has_wings():
		return
	_wing_think -= delta
	if _wing_think > 0.0:
		return
	_wing_think = _rng.randf_range(20.0, 75.0)
	var w: Array = WorldPlayers.wing_taste(world_index)
	var stand := float(w[0])
	var fly := float(w[1]) * (0.6 if hero != null and hero.safe_zone else (1.3 if target == null else 1.0))
	var fold := float(w[2])
	var pick := _rng.randf() * (stand + fly + fold)
	var mode := HeroVisual.WING_STAND
	if pick > stand:
		mode = HeroVisual.WING_FLY if pick <= stand + fly else HeroVisual.WING_FOLD
	if mode != visual.wing_mode:
		visual.set_wing_mode(mode)


## Flying lifts it off the ground with a gentle bob and leans it into the flight, like the hero.
func _hover(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.6
	visual.set_wing_moving(moving)
	var flying := visual.flying() and not _dead
	var lift := Hero.FLY_HEIGHT + sin(Time.get_ticks_msec() * 0.0025 + float(world_index)) * 0.1 if flying else 0.0
	visual.position.y = lerpf(visual.position.y, lift, 1.0 - exp(-4.0 * delta))
	if visual.model != null:
		visual.model.rotation.x = lerpf(visual.model.rotation.x, Hero.FLY_LEAN if flying and moving else 0.0, 1.0 - exp(-5.0 * delta))


# --- Looking after itself --------------------------------------------------------

func _ally_hp_ratio() -> float:
	if party_mode:
		return super._ally_hp_ratio()
	return float(hp) / float(maxi(1, max_hp))


func _in_combat() -> bool:
	if party_mode:
		return super._in_combat()
	return target != null and is_instance_valid(target)


func _heal_allies(fraction: float) -> void:
	if party_mode:
		super._heal_allies(fraction)


func _buff_allies(buff: Dictionary, color: Color, label_text: String, skill_id: String) -> void:
	if party_mode:
		super._buff_allies(buff, color, label_text, skill_id)


## Hunting alone, a Bard sings for itself: its own song slot.
func _song_entry() -> Dictionary:
	return super._song_entry() if party_mode else BuffBook.song_of(_book.buffs)


func _song_left() -> float:
	return super._song_left() if party_mode else BuffBook.song_left(_book.buffs)


func _hero_sings() -> bool:
	return party_mode and super._hero_sings()


## Its own potions only (never the hero's bag); the stock refills in the village.
func _use_potions() -> void:
	if hero.safe_zone:
		member["potions"] = WorldPlayers.POTIONS
		member["mp_potions"] = WorldPlayers.MP_POTIONS
		return
	if _potion_cd > 0.0 or Time.get_ticks_msec() < _cast_until:
		return
	if int(member.get("potions", 0)) <= 0 and float(hp) / float(max_hp) < 0.5 and not party_mode:
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
	if party_mode:
		super._die()
		return
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
	if party_mode:
		super._revive()
		member["potions"] = WorldPlayers.POTIONS
		_label.text = _level_text()
		return
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
	if party_mode:
		return super._fight(delta)
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
	if party_mode:
		return super._pick_target()
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
	if party_mode:
		return super._follow(delta)
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
