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
## What it is doing (WorldPlayers.state doing): "stall" keeps a stall in the village.
var doing := ""
## Its stall in the village (WorldPresence hands one out) and the way it faces.
var stall_at := Vector3.INF
var stall_face := Vector3.FORWARD
## On an errand in the village ("quest", "enhance", "skill"; WorldPresence sends it): the
## spot in front of the villager, the way it faces there, the warp stone it walks back to
## and when the errand ends (WorldPresence.clock).
var errand := ""
var errand_at := Vector3.INF
var errand_face := Vector3.FORWARD
var errand_exit := Vector3.INF
var errand_until := 0.0
const ERRAND_TAGS := {"quest": "ส่งเควส", "enhance": "ตีบวก", "skill": "เรียนสกิล"}
## Seconds before an errand ends that it walks back to the warp stone.
const ERRAND_LEAVE := 20.0
var _bubble: Label3D
var _sits := false
## The world boss (WorldEvents): when it may shout again, and where it steps to out of a telegraph.
var _shout_at := 0.0
var _dodge_to := Vector3.INF
## In the party, told to wait ("รอตรงนี้", PartyTalk.command): where it holds until the
## hero gets HOLD_LEASH away or calls it ("ตามมา").
var hold_at := Vector3.INF
const HOLD_LEASH := 28.0
## In the village, the hero standing this close to a villager and still: the members
## gather GATHER_BACK behind the hero (each a step aside) instead of beside.
const GATHER_NEAR := 3.0
const GATHER_BACK := 2.2
const GATHER_SIDE := [-0.9, 0.9, -1.8, 1.8]


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
	_shout_at = Time.get_ticks_msec() * 0.001 + _rng.randf_range(1.0, 12.0)
	# Some stall keepers sit by their wares (the AFK ones doze).
	_sits = hash("sit|%s" % member.name) % 3 == 0
	_pick_camp()
	if party_mode:
		PartyTalk.attach(zone)


func _visual_look() -> Dictionary:
	return WorldPlayers.look(world_index)


## The players around wear the cheap enhancement dressing; a party member the full one.
func _light_decor() -> bool:
	return not party_mode


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
	var line := "%s%s Lv.%d%s" % ["[%s] " % WorldPlayers.guild_name(g) if g > 0 else "", member.name, int(member.level), " ★%d" % stars if stars > 0 else ""]
	if doing == "errand" and not party_mode and ERRAND_TAGS.has(errand):
		return line + "\n«%s»" % ERRAND_TAGS[errand]
	return line + ("\n«ร้านค้า»" if doing == "stall" and not party_mode else "")


## New level, stars or finds from the schedule (WorldPresence): the field sees the
## level-up and the new piece put on.
func sync_progress(s: Dictionary) -> void:
	doing = String(s.get("doing", doing))
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


## Keeping a stall: in the village, not in a party, with a stall handed out.
func keeps_stall() -> bool:
	return doing == "stall" and not party_mode and zone != null and zone.is_town and stall_at.is_finite()


## On an errand: in the village, not in a party, with a villager to go to.
func on_errand() -> bool:
	return doing == "errand" and not party_mode and zone != null and zone.is_town and errand_at.is_finite()


## Where an errand runner heads now: its villager, and the warp stone near the end.
func errand_goal() -> Vector3:
	if errand_exit.is_finite() and WorldPresence.clock() > errand_until - ERRAND_LEAVE:
		return errand_exit
	return errand_at


func _rest_anim() -> String:
	return "Sit_Floor_Idle" if _sits and keeps_stall() and _flat(stall_at - global_position).length() < 0.8 else "Idle"


## A chat bubble over its head for a few seconds (the world chat's line, WorldPresence).
func bubble(text: String) -> void:
	if not is_instance_valid(visual) or not visible or _dead:
		return
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.pixel_size = 0.0042 * BattleVfx.text_scale
	_bubble.font_size = 40
	_bubble.outline_size = 10
	_bubble.modulate = Color("fffbe8")
	_bubble.outline_modulate = Color(0.1, 0.12, 0.2, 0.95)
	_bubble.position = Vector3(0, 3.35, 0)
	_bubble.visibility_range_end = 26.0
	_bubble.no_depth_test = true
	_bubble.render_priority = 3
	_bubble.width = 520.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.text = text
	add_child(_bubble)
	var fade := _bubble.create_tween()
	fade.tween_interval(4.0)
	fade.tween_property(_bubble, "modulate:a", 0.0, 0.6)
	fade.tween_callback(_bubble.queue_free)


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
	visual.decor_light = false
	visual.set_far(false)
	refresh()
	_label.text = _level_text()
	PartyTalk.attach(zone)


## Leaves the party but stays in the game: back to hunting a camp of its own.
func leave_party() -> void:
	party_mode = false
	target = null
	hold_at = Vector3.INF
	member = member.duplicate()
	remove_from_group("companions")
	add_to_group("world_players")
	visual.decor_light = true
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

## A stall keeper standing at its stall in the village rests: no thinking or moving until
## something changes (it is hurt, or it is asked into the party).
const LOD_NEAR := 18.0
const LOD_FAR := 34.0
var _lod_check := 0.0


func _resting() -> bool:
	if not _dead and hp >= max_hp and on_errand():
		var goal := errand_goal()
		return goal == errand_at and _flat(goal - global_position).length() < 0.7
	return keeps_stall() and not _dead and hp >= max_hp and _flat(stall_at - global_position).length() < 0.7


func _physics_process(delta: float) -> void:
	_lod_check -= delta
	if _lod_check <= 0.0:
		_lod_check = 0.5
		_update_lod()
	if _resting() and visual.current == _rest_anim():
		velocity = Vector3.ZERO
		fade_label(delta)
		return
	super._physics_process(delta)
	if stats.is_empty() or not is_instance_valid(visual):
		return
	_think_wings(delta)
	_hover(delta)


## Far from the hero (or resting at its stall) it is posed less often.
func _update_lod() -> void:
	if not is_instance_valid(visual) or hero == null or not is_instance_valid(hero):
		return
	var d := _flat(hero.global_position - global_position).length()
	var step := 1
	if party_mode or target != null:
		step = 1
	elif d > LOD_FAR:
		step = 4
	elif d > LOD_NEAR or _resting():
		step = 2
	visual.set_anim_lod(step)
	visual.set_far(step >= 2 and not party_mode)


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


func _song_buffs() -> Array:
	return super._song_buffs() if party_mode else _book.buffs


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
	var dodge := _dodge_world_boss(delta)
	if dodge.is_finite():
		return dodge
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
	var wboss := _join_world_boss()
	if wboss != null:
		return wboss
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


# --- The world boss (WorldEvents, WorldBoss) ----------------------------------------

## The field's world boss (Zone._wboss) while it lives, or null.
func _world_boss() -> Mob:
	if zone == null or not is_instance_valid(zone):
		return null
	var boss: Mob = zone._wboss
	return boss if boss != null and is_instance_valid(boss) and not boss.is_dead() else null


## Hunting here while the world boss is up, it joins in: the boss within
## WorldEvents.BOSS_JOIN_RANGE is its target, with a shout (bubble and world chat) at
## most every BOSS_SHOUT_GAP seconds.
func _join_world_boss() -> Mob:
	var boss := _world_boss()
	if boss == null or _flat(boss.global_position - global_position).length() > WorldEvents.BOSS_JOIN_RANGE:
		return null
	var now := Time.get_ticks_msec() * 0.001
	if now >= _shout_at:
		_shout_at = now + WorldEvents.BOSS_SHOUT_GAP + _rng.randf_range(0.0, 20.0)
		var text: String = WorldEvents.BOSS_SHOUTS[_rng.randi() % WorldEvents.BOSS_SHOUTS.size()]
		var g := WorldPlayers.guild_at(world_index, int(member.level))
		Game.world_chat.emit(String(member.name), text, WorldPlayers.GUILD_COLORS.get(g, Color("bfe8ff")))
		bubble(text)
	return boss


## Standing in the world boss's telegraph (WorldBoss.inside), it steps 7 m out of it
## (WorldBoss.escape_point); Vector3.INF when there is nothing to dodge.
func _dodge_world_boss(delta: float) -> Vector3:
	var special := WorldBoss.of(_world_boss())
	if special == null or special.telegraph.is_empty():
		_dodge_to = Vector3.INF
		return Vector3.INF
	if not _dodge_to.is_finite():
		if not special.inside(global_position):
			return Vector3.INF
		_dodge_to = special.escape_point(global_position)
	var to := _flat(_dodge_to - global_position)
	if to.length() < 0.6:
		return Vector3.ZERO
	_face(to, delta, 14.0)
	return to.normalized() * float(stats.speed) * 1.2


## No fight: walk to the camp and drift around in it (in the village, between the shops);
## backing off, it runs towards the field's entrance.
func _follow(delta: float) -> Vector3:
	if party_mode:
		return _party_follow(delta)
	var dodge := _dodge_world_boss(delta)
	if dodge.is_finite():
		return dodge
	if _fleeing() and zone != null:
		var away := _flat(zone.entrance() - global_position)
		if away.length() > 2.0:
			_face(away, delta, 12.0)
			return away.normalized() * float(stats.speed) * 1.15
		if _restocking:
			_go_shopping()
			return Vector3.ZERO
	if keeps_stall():
		# At its stall: walks there, then stands (or sits) facing the street.
		var to_stall := _flat(stall_at - global_position)
		if to_stall.length() > 0.6:
			_face(to_stall, delta, 10.0)
			return to_stall.normalized() * minf(float(stats.speed) * 0.7, to_stall.length() * 4.0)
		_face(stall_face, delta, 6.0)
		return Vector3.ZERO
	if on_errand():
		# Walks to the villager, stands facing it, and heads back to the warp stone at the end.
		var goal := errand_goal()
		var to_goal := _flat(goal - global_position)
		if to_goal.length() > 0.6:
			_face(to_goal, delta, 10.0)
			return to_goal.normalized() * minf(float(stats.speed) * 0.8, to_goal.length() * 4.0)
		if goal == errand_at:
			_face(errand_face, delta, 6.0)
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


## Walking with the hero: holds where it was told to wait until the hero gets far or calls
## it; in the village, while the hero stands talking to a villager, it gathers behind the
## hero facing the villager; otherwise its usual spot beside the hero (Companion).
func _party_follow(delta: float) -> Vector3:
	if hold_at.is_finite():
		if _flat(hero.global_position - hold_at).length() > HOLD_LEASH:
			hold_at = Vector3.INF
		else:
			return _walk_to(hold_at, delta, 0.8)
	var npc := _hero_villager()
	if npc != null:
		var back := _flat(hero.global_position - npc.global_position)
		back = back.normalized() if back.length() > 0.01 else Vector3.BACK
		var side := back.rotated(Vector3.UP, PI * 0.5)
		var spot := hero.global_position + back * GATHER_BACK + side * float(GATHER_SIDE[index % GATHER_SIDE.size()])
		if _flat(spot - global_position).length() < 0.6:
			_face(_flat(npc.global_position - global_position), delta, 6.0)
			return Vector3.ZERO
		return _walk_to(spot, delta, 0.9)
	return super._follow(delta)


## The villager the hero stands still in front of (Zone.current_interact), or null.
func _hero_villager() -> Npc:
	if zone == null or not is_instance_valid(zone) or not zone.is_town or hero.is_dead():
		return null
	var npc := zone.current_interact.get("npc") as Npc
	if npc == null or not is_instance_valid(npc):
		return null
	if _flat(npc.global_position - hero.global_position).length() > GATHER_NEAR or _flat(hero.velocity).length() > 0.4:
		return null
	return npc


func _walk_to(spot: Vector3, delta: float, rate: float) -> Vector3:
	var to := _flat(spot - global_position)
	if to.length() < 0.6:
		return Vector3.ZERO
	_face(to, delta, 10.0)
	return to.normalized() * minf(float(stats.speed) * rate, to.length() * 4.0)
