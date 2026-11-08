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
## on; with wings it flies, stands or folds them as it pleases. With a mount
## (WorldPlayers.mount_of) it rides or walks as its taste says (WorldPlayers.ride_taste):
## some ride nearly always, some rarely, some never; it gets on more for a long way to a
## camp, less in the village, gets off at its stall or errand, and fights from the saddle
## like the hero. In the hero's party it rides while the hero rides. Never where riding
## is not allowed (MountData.zone_allows). Far away its mount is simplified (set_far).
## Online, in a zone another real player's game runs (WorldPresence MIRROR) it is a
## puppet instead: the same body, look, gear, mount and wings built from its roster
## index, but no AI, no fights and no damage; it walks where the host's `wp_snap` frames
## put it (played PUPPET_DELAY behind), plays their anim and flags, and the host's casts
## (`wp_event skill`) as effects at the mirrored monster. end_puppet turns it back into
## an ordinary world player where it stands (the host role came here, or the link went).
## In a party of world players (WorldParties, from WorldPlayers.state) it hunts with its
## people: the leader picks the camp that fits the party, the others walk round the leader
## and fight what it fights (or whatever attacks one of them), a healer heals and a buffer
## buffs the party, a tank's provoke pulls monsters off a hurt mate, and a Dark Lord's
## Summon pulls a mate who fell far behind back to the party. Its name plate says whose
## party it is ("ปาร์ตี้ของ <leader>"), the same on every screen (the party comes from the
## roster and the clock).

## Seconds it hunts a camp before it moves on to another (a longer stay is less walking).
const CAMP_STAY := Vector2(240.0, 480.0)
const AWAY_AFTER_FALL := 40.0
## How far it looks for its next monster: far enough that it goes from kill to kill
## instead of drifting about the camp.
const HUNT_REACH := 22.0

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
## Its mount ({id, level} from WorldPlayers.mount_of, {} with none), its taste for riding
## (WorldPlayers.ride_taste) and when it thinks about riding again.
var mount_info: Dictionary = {}
var ride_taste := 0.0
var _ride_think := 0.0
## Seconds between two thoughts about riding (random in this range).
const RIDE_THINK := Vector2(14.0, 45.0)
## A camp farther than this is a long way: more likely to ride there.
const RIDE_FAR := 22.0
## In the village it rides this much less.
const TOWN_RIDE := 0.5
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

# --- Puppet (online mirror, WorldPresence) ---
## Wire flags of wp_snap: riding, wings open, flying (bit 2: open wings in the air).
const F_RIDING := 1
const F_WINGS := 2
const F_FLYING := 4
## How far behind the newest snapshot it plays (seconds): one snapshot interval plus
## ~100 ms, so the walk never waits for the next one.
const PUPPET_DELAY := 0.35
const PUPPET_SNAPS := 4
## Farther than this between two snapshots: a warp, no walking there.
const PUPPET_TELEPORT := 14.0
## A pause this long since the last snapshot: it stood still meanwhile.
const PUPPET_STILL_GAP := 0.6
## A `skill:<id>` anim within this long after a cast event does not pose again (ms).
const PUPPET_POSE_MS := 1200
## How long after a cast the wire anim says "skill:<id>" (ms).
const SKILL_SHOW_MS := 900
var puppet := false
var puppet_anim := "idle"
var puppet_flags := 0
## Where the last cast shown as a puppet landed (tests).
var puppet_show_at := Vector3.INF
var _p_pos := PackedVector3Array()
var _p_yaw := PackedFloat32Array()
var _p_t := PackedFloat64Array()
var _p_n := 0
var _p_speed := 0.0
var _p_last := Vector3.ZERO
var _p_attack_left := 0.0
var _p_combo := 0
var _p_skill_ms := -100000
var _skill_shown := ""
var _skill_shown_until := 0

# --- Party of world players (WorldParties) ---
## Its party now (WorldPlayers.state party_id, party_leader, party_members), "" / -1 / [] alone.
var ai_party_id := ""
var ai_leader := -1
var ai_members: Array = []
## Its people standing here (refreshed every MATES_EVERY seconds, not every frame).
var _mates: Array[FieldPlayer] = []
var _mates_in := 0.0
const MATES_EVERY := 1.0
## How far from it a mate still gets its heals and buffs.
const PARTY_NEAR := 16.0
## Spots round the leader (behind and to the sides) the others keep while it walks.
const PARTY_SPOTS := [Vector3(-2.6, 0, -1.8), Vector3(2.6, 0, -1.8), Vector3(-1.6, 0, -4.0), Vector3(1.6, 0, -4.0)]
## A mate this far from a Dark Lord of the party is summoned back to it.
const REGROUP := 24.0
## A party line over its head at most this often (seconds).
const PARTY_SAY_GAP := 40.0
var _party_said := -1000.0
const MOVE_LINES := ["ไปแคมป์ถัดไปกัน ตามมา!", "ย้ายจุดฟาร์มกัน", "ตรงนี้มอนหมดแล้ว ไปต่อกัน", "ไปทางนี้ มอนเยอะกว่า"]
const HEAL_LINES := ["ฮีลให้แล้วนะ!", "เลือดน้อยแล้ว เดี๋ยวฮีลให้", "ถอยมาใกล้ ๆ จะฮีลให้"]
const SUMMON_LINES := ["รวมพล! มาทางนี้", "ดึงมาแล้ว อย่าหลงอีกนะ 555", "Summon! อยู่ใกล้ ๆ กันหน่อย"]
const TAUNT_LINES := ["มาทางนี้ อย่าไปตีเพื่อนฉัน!", "ดึงมอนให้แล้ว ตีเลย!"]


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
	mount_info = WorldPlayers.mount_of(member)
	ride_taste = WorldPlayers.ride_taste(world_index)
	_ride_think = _rng.randf_range(0.2, 2.0)
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
	var enhanced := false
	for slot in _worn:
		enhanced = enhanced or (now_worn.get(slot) is Dictionary and now_worn[slot] == piece and String((_worn[slot] as Dictionary).get("name", "")) == String(piece.get("name", "")))
	_worn = now_worn
	if not piece.is_empty() and visible and not _dead and is_instance_valid(field):
		var plus := int(piece.get("plus", 0))
		var color: Color = ItemData.RARITY_COLORS[clampi(int(piece.get("rarity", 0)), 0, 4)]
		# A find is always +0; a higher grade on the same piece came from the forge.
		say(("ตีบวก %s เป็น +%d สำเร็จ!" % [piece.name, plus]) if plus > 0 and enhanced else ("เก็บได้ %s" % piece.name), color)


## "[Alpha] Kaito Lv.100 ★44" in the guild's colour; no tag before Lv.100 (no guild yet);
## a God's title above it ("✦ เทพเจ้าแห่งนักรบ ✦").
func _level_text() -> String:
	var g := WorldPlayers.guild_at(world_index, int(member.level))
	_label.modulate = WorldPlayers.GUILD_COLORS.get(g, Color("e8f4ff"))
	var stars := Game.party_stars(member)
	var line := "%s%s Lv.%d%s" % ["[%s] " % WorldPlayers.guild_name(g) if g > 0 else "", member.name, int(member.level), " ★%d" % stars if stars > 0 else ""]
	# Members of the weekly Castle King (ราชันปราสาท) wear a gold crown plate (GuildLeague).
	if GuildLeague.crowned(g):
		_label.modulate = GuildLeague.CROWN_COLOR
		line = "%s %s" % [GuildLeague.CROWN, line]
	# A God (Lv.100 ★300) wears its title over the name, like the hero's name plate.
	var god := WorldPlayers.god_title({"class": member["class"], "level": int(member.level), "stars": stars})
	if god != "":
		line = "✦ %s ✦\n%s" % [god, line]
	if doing == "errand" and not party_mode and ERRAND_TAGS.has(errand):
		return line + "\n«%s»" % ERRAND_TAGS[errand]
	if ai_party_id != "" and not party_mode and ai_leader >= 0 and ai_leader < WorldPlayers.size():
		return line + "\n«ปาร์ตี้ของ %s · %d คน»" % [WorldPlayers.entry(ai_leader).name, ai_members.size()]
	return line + ("\n«ร้านค้า»" if doing == "stall" and not party_mode else "")


## New level, stars or finds from the schedule (WorldPresence): the field sees the
## level-up and the new piece put on.
func sync_progress(s: Dictionary) -> void:
	doing = String(s.get("doing", doing))
	set_ai_party(s)
	var up := int(s.level) > int(member.level) or int(s.stars) > int(member.get("stars", 0))
	var dressed := WorldPlayers.sync_member(member, s)
	_sync_mount()
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
## `share`: the zone host's game also shows it on the other real players' screens
## (`wp_event bubble`); the same line already up is not shown twice.
func bubble(text: String, share := true) -> void:
	if not is_instance_valid(visual) or not visible or _dead:
		return
	if share and not puppet and zone != null and is_instance_valid(zone) and zone.presence != null:
		zone.presence.shared_bubble(world_index, text)
	if is_instance_valid(_bubble):
		if _bubble.text == text and not _bubble.is_queued_for_deletion():
			return
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
	set_ai_party({})
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
	if puppet:
		_puppet_tick(delta)
		return
	_think_ride(delta)
	if _resting() and visual.current == _rest_anim():
		velocity = Vector3.ZERO
		fade_label(delta)
		return
	super._physics_process(delta)
	if stats.is_empty() or not is_instance_valid(visual):
		return
	_think_wings(delta)
	if mount == null:
		_hover(delta)


## A puppet is only a picture of another game's player: nothing here hurts it.
func take_damage(raw: float, attacker: Node = null) -> void:
	if puppet:
		return
	super.take_damage(raw, attacker)


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
	if mount != null:
		mount.lod_step = step
		mount.set_far(step >= 2 and not party_mode)


# --- Riding (MountData) ------------------------------------------------------------

## Its mount moved on (a new one or a level from the schedule): the ridden body follows.
func _sync_mount() -> void:
	mount_info = WorldPlayers.mount_of(member)
	if mount == null:
		return
	if mount_info.is_empty():
		dismount()
	elif String(mount_info.id) != mount.id:
		mount.build(String(mount_info.id))


## Whether it wants to be on its mount now (rolls `roll` 0-1 against its taste): never
## without one, dead, away or where riding is not allowed; in the party while the hero
## rides; off at its stall or errand; more likely for a long way to its camp, less in
## the village.
func wants_ride(roll: float) -> bool:
	if mount_info.is_empty() or _dead or _away or not visible or not can_ride_here():
		return false
	if party_mode:
		return hero != null and is_instance_valid(hero) and hero.is_riding()
	if keeps_stall() or on_errand():
		var goal := stall_at if keeps_stall() else errand_goal()
		if _flat(goal - global_position).length() < 4.0:
			return false
	var p := ride_taste
	if zone != null and zone.is_town:
		p *= TOWN_RIDE
	elif not _camp.is_empty() and _flat(_camp_center() - global_position).length() > RIDE_FAR:
		# Far from its camp it rides more, though now and then it still walks.
		p = minf(0.95, p * 1.6)
	return roll < p


## Now and then it makes up its mind to ride or walk (wants_ride); in the party it keeps
## up with the hero at once; a no-riding place or a fall takes it off at once.
func _think_ride(delta: float) -> void:
	if mount != null and (_dead or _away or not can_ride_here() or mount_info.is_empty()):
		dismount()
		return
	if mount_info.is_empty() or _dead:
		return
	if party_mode:
		_set_riding(wants_ride(0.0))
		return
	if mount != null and (keeps_stall() or on_errand()) and not wants_ride(0.0):
		# Arrived at its stall or errand: off the mount at once.
		dismount()
		return
	_ride_think -= delta
	if _ride_think > 0.0:
		return
	_ride_think = _rng.randf_range(RIDE_THINK.x, RIDE_THINK.y)
	_set_riding(wants_ride(_rng.randf()))


func _set_riding(on: bool) -> void:
	if on and mount == null:
		if ride_mount(String(mount_info.id)):
			mount.lod_step = visual.anim_lod
			mount.set_far(visual.anim_lod >= 2 and not party_mode)
	elif not on and mount != null:
		dismount()


## Picks its wing pose now and then, as it pleases: its own taste (WorldPlayers.wing_taste),
## a little more flying on the way somewhere and a little less in the village.
func _think_wings(delta: float) -> void:
	if _dead or not visual.has_wings():
		return
	if mount != null:
		# In the saddle the wings stay open, never flying.
		if visual.flying():
			visual.set_wing_mode(HeroVisual.WING_STAND)
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
	_hover_moving(delta, Vector2(velocity.x, velocity.z).length() > 0.6)


func _hover_moving(delta: float, moving: bool) -> void:
	visual.set_wing_moving(moving)
	var flying := visual.flying() and not _dead
	var lift := Hero.FLY_HEIGHT + sin(Time.get_ticks_msec() * 0.0025 + float(world_index)) * 0.1 if flying else 0.0
	visual.position.y = lerpf(visual.position.y, lift, 1.0 - exp(-4.0 * delta))
	if visual.model != null:
		visual.model.rotation.x = lerpf(visual.model.rotation.x, Hero.FLY_LEAN if flying and moving else 0.0, 1.0 - exp(-5.0 * delta))


# --- Looking after itself --------------------------------------------------------

## The lowest HP share of itself and the party's people near it (whom a healer heals).
func _ally_hp_ratio() -> float:
	if party_mode:
		return super._ally_hp_ratio()
	var low := float(hp) / float(maxi(1, max_hp))
	for mate in near_mates():
		low = minf(low, float(mate.hp) / float(maxi(1, mate.max_hp)))
	return low


func _in_combat() -> bool:
	if party_mode:
		return super._in_combat()
	if target != null and is_instance_valid(target):
		return true
	for mate in near_mates():
		if mate.target != null and is_instance_valid(mate.target):
			return true
	return false


## A heal reaches the party's people near it (in the hero's party, the hero's).
func _heal_allies(fraction: float) -> void:
	if party_mode:
		super._heal_allies(fraction)
		return
	var hurt := false
	for mate in near_mates():
		hurt = hurt or float(mate.hp) / float(maxi(1, mate.max_hp)) < 0.45
		mate.heal_fraction(fraction)
	if hurt:
		party_say(HEAL_LINES)


## A buff reaches the party's people near it (in the hero's party, the hero and the party).
func _buff_allies(buff: Dictionary, color: Color, label_text: String, skill_id: String) -> void:
	if party_mode:
		super._buff_allies(buff, color, label_text, skill_id)
		return
	for mate in near_mates():
		mate.receive_party_buff(buff, color, label_text, skill_id)


## Summon is a Dark Lord's on purpose: in the hero's party as a companion's; alone never
## (the hero's party is not its business); in a party of world players to pull back one of
## its people who fell REGROUP behind.
func _shape_score(skill: Dictionary, distance: float, hero_hp: float) -> float:
	if party_mode:
		return super._shape_score(skill, distance, hero_hp)
	var fx: Dictionary = skill.get("fx", {})
	if fx.has("recall"):
		return 9.5 if _straggling_mate() != null else 0.0
	var score := super._shape_score(skill, distance, hero_hp)
	if fx.has("taunt") and score >= 8.5 and not mates().is_empty():
		party_say(TAUNT_LINES)
	return score


## Its Summon outside the hero's party gathers its own people round it (never the hero's).
func _apply_self(skill: Dictionary) -> void:
	var fx: Dictionary = skill.get("fx", {})
	if party_mode or not fx.has("recall"):
		super._apply_self(skill)
		return
	gather_mates()
	var rest := skill.duplicate(true)
	(rest.fx as Dictionary).erase("recall")
	super._apply_self(rest)


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
	dismount()
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
	var lead := party_leader()
	if lead != null and not lead.camp().is_empty():
		# In a party the leader picks: the others go where it goes.
		_camp = lead.camp()
		_spot_left = 0.0
		return
	var level := party_level()
	var ranked := zone._camps.duplicate()
	ranked.sort_custom(func(a, b): return _fit(a, level) < _fit(b, level))
	var was := _camp
	_camp = ranked[_rng.randi() % mini(2, ranked.size())]
	_spot_left = 0.0
	if not was.is_empty() and _camp != was and not mates().is_empty() and _rng.randf() < 0.5:
		party_say(MOVE_LINES)


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
	dismount()
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
	# In a party: what the leader fights (unless the hero's side has it).
	var lead := party_leader()
	if lead != null and lead.target != null and is_instance_valid(lead.target) and not lead.target.is_dead() \
			and lead.target.party_damage <= 0 and hero.target != lead.target \
			and _flat(lead.target.global_position - global_position).length() < HUNT_REACH * 1.5:
		return lead.target
	var center := _camp_center()
	var reach := float(_camp.radius) + 8.0
	var best: Mob = null
	var best_d := HUNT_REACH
	var team := mates()
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob == null or mob.is_dead() or mob is Rival:
			continue
		# A monster on one of its people counts as on itself (it helps them).
		var victim: Variant = mob._victim
		var on_me: bool = victim == self or (not team.is_empty() and is_instance_valid(victim) and victim is FieldPlayer and team.has(victim))
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
	var lead := party_leader()
	if lead != null:
		return _follow_leader(lead, delta)
	_camp_left -= delta
	if _camp_left <= 0.0:
		_pick_camp()
	_spot_left -= delta
	if _spot_left <= 0.0:
		_spot_left = _rng.randf_range(2.0, 5.0)
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


# --- Party of world players (WorldParties) ----------------------------------------------

## Takes its party from a WorldPlayers.state (party_id, party_leader, party_members); {}
## or a state with none: alone.
func set_ai_party(s: Dictionary) -> void:
	var id := String(s.get("party_id", ""))
	var lead := int(s.get("party_leader", -1))
	var people: Array = s.get("party_members", []) if id != "" else []
	if id == ai_party_id and lead == ai_leader and people == ai_members:
		return
	ai_party_id = id
	ai_leader = lead if id != "" else -1
	ai_members = people.duplicate()
	_mates_in = 0.0
	_mates.clear()
	if is_instance_valid(_label) and not _dead:
		_label.text = _level_text()


## In a party of world players (not the hero's), and not a puppet of another game's.
func in_ai_party() -> bool:
	return ai_party_id != "" and not party_mode and not puppet


## Its people standing here (alive or not), itself left out; refreshed every MATES_EVERY s.
func mates() -> Array[FieldPlayer]:
	if not in_ai_party():
		if not _mates.is_empty():
			_mates.clear()
		return _mates
	var now := Time.get_ticks_msec() * 0.001
	if now < _mates_in:
		return _mates
	_mates_in = now + MATES_EVERY
	_mates.clear()
	if zone == null or not is_instance_valid(zone) or zone.presence == null:
		return _mates
	for k in ai_members:
		var i := int(k)
		if i == world_index:
			continue
		var p: Variant = zone.presence.shown.get(i)
		if p == null or not is_instance_valid(p) or (p as Node).is_queued_for_deletion():
			continue
		var f := p as FieldPlayer
		if f.party_mode or f.ai_party_id != ai_party_id:
			continue
		_mates.append(f)
	return _mates


## Its people here who are up and near it (heals and buffs reach them).
func near_mates() -> Array[FieldPlayer]:
	var out: Array[FieldPlayer] = []
	for mate in mates():
		if is_instance_valid(mate) and mate.visible and not mate._dead and not mate._away \
				and _flat(mate.global_position - global_position).length() <= PARTY_NEAR:
			out.append(mate)
	return out


## Its party's leader standing here, up and hunting (null: it leads, is alone, or the
## leader is not here: it hunts on its own until the leader comes).
func party_leader() -> FieldPlayer:
	if not in_ai_party() or ai_leader == world_index or ai_leader < 0:
		return null
	for mate in mates():
		if is_instance_valid(mate) and mate.world_index == ai_leader and mate.visible and not mate._away and not mate._leaving:
			return mate
	return null


## The level the party hunts at: the mean of its people here (its own alone).
func party_level() -> int:
	var total := int(member.level)
	var n := 1
	for mate in mates():
		if is_instance_valid(mate):
			total += int(mate.member.level)
			n += 1
	return int(round(float(total) / float(n)))


## Walking with the leader: its own spot round it (by its place in the party), a run when
## far behind; the leader's camp is its camp.
func _follow_leader(lead: FieldPlayer, delta: float) -> Vector3:
	if not lead.camp().is_empty():
		_camp = lead.camp()
	var k := maxi(0, ai_members.find(world_index) - 1)
	var spot := lead.global_position + (PARTY_SPOTS[k % PARTY_SPOTS.size()] as Vector3).rotated(Vector3.UP, lead._facing)
	var to := _flat(spot - global_position)
	if to.length() < 0.8:
		return Vector3.ZERO
	_face(to, delta, 10.0)
	var speed := float(stats.speed) * (1.3 if to.length() > 8.0 else (1.0 if to.length() > 3.0 else 0.6))
	return to.normalized() * minf(speed, to.length() * 4.0)


## One of its people (up, not away) more than REGROUP from it, or null.
func _straggling_mate() -> FieldPlayer:
	if hero != null and is_instance_valid(hero) and hero.safe_zone:
		return null
	for mate in mates():
		if is_instance_valid(mate) and mate.visible and not mate._dead and not mate._away and not mate._fleeing() \
				and _flat(mate.global_position - global_position).length() > REGROUP:
			return mate
	return null


## A Dark Lord's Summon in a party of world players: its people up and here stand round
## it at once (a flash where each left and arrived). Returns how many came.
func gather_mates() -> int:
	var movers: Array[FieldPlayer] = []
	for mate in mates():
		if is_instance_valid(mate) and mate.visible and not mate._dead and not mate._away:
			movers.append(mate)
	if movers.is_empty() or not is_instance_valid(field):
		return 0
	for k in movers.size():
		var mate := movers[k]
		var angle := _facing + PI + (float(k) - float(movers.size() - 1) * 0.5) * 0.8
		var spot := global_position + Vector3(sin(angle), 0, cos(angle)) * 2.4
		VfxKit.flash(field, mate.global_position + Vector3(0, 1.0, 0), Color("8a4dff"), 1.2, 0.2)
		mate.global_position = spot + Vector3(0, 0.3, 0)
		mate.velocity = Vector3.ZERO
		VfxKit.flash(field, spot + Vector3(0, 1.0, 0), Color("e0a83a"), 1.3, 0.2)
	VfxKit.shockwave(field, global_position + Vector3(0, 0.1, 0), Color("6a2fd0"), 3.2)
	party_say(SUMMON_LINES)
	return movers.size()


## A line of party talk over its head (and on the other real players' screens), at most
## every PARTY_SAY_GAP seconds and only near the hero (where it is seen).
func party_say(lines: Array) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - _party_said < PARTY_SAY_GAP or lines.is_empty() or not visible or _dead:
		return
	if hero == null or not is_instance_valid(hero) or _flat(hero.global_position - global_position).length() > LOD_FAR:
		return
	_party_said = now
	bubble(String(lines[_rng.randi() % lines.size()]))


# --- Online: what it does, on the wire, and the puppet of another game's player --------

## A cast: the zone host's game tells the other real players here (`wp_event skill`, with
## the target monster's shared eid) so the effect plays at the same spot there.
func _cast(skill: Dictionary) -> void:
	var aimed: Mob = target if target != null and is_instance_valid(target) else null
	super._cast(skill)
	_skill_shown = String(skill.id)
	_skill_shown_until = Time.get_ticks_msec() + SKILL_SHOW_MS
	if not party_mode and zone != null and is_instance_valid(zone) and zone.presence != null:
		var eid := int(aimed.get_meta("eid", 0)) if aimed != null else 0
		zone.presence.shared_cast(world_index, String(skill.id), eid)


## The anim for wp_snap: "dead", "skill:<id>" just after a cast, "attack" at a target in
## reach, "run", "sit" (a stall keeper by its wares) or "idle".
func wire_anim() -> String:
	if _dead:
		return "dead"
	if Time.get_ticks_msec() < _skill_shown_until:
		return "skill:" + _skill_shown
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed <= 0.6 and target != null and is_instance_valid(target) and not target.is_dead() and data.has("attack"):
		var reach := float((data.attack as Dictionary).get("range", 2.4)) + target.body_radius() + 0.6
		if _flat(target.global_position - global_position).length() <= reach:
			return "attack"
	if speed > 0.6:
		return "run"
	return "sit" if _rest_anim() == "Sit_Floor_Idle" else "idle"


## The wire flags for wp_snap (F_RIDING, F_WINGS, F_FLYING).
func wire_flags() -> int:
	var f := 0
	if mount != null:
		f |= F_RIDING
	if is_instance_valid(visual) and visual.has_wings() and visual.wing_mode != HeroVisual.WING_FOLD:
		f |= F_WINGS
		if visual.wing_mode == HeroVisual.WING_FLY:
			f |= F_FLYING
	return f


## Whether the zone host's snapshot lists it now (standing here, not away or leaving).
func on_wire() -> bool:
	return not puppet and not party_mode and visible and not _away and not _leaving and not is_queued_for_deletion()


## One snapshot position at `t` (seconds, this game's clock): a warp jumps there, a long
## pause holds the old spot until just before the new one.
func puppet_push(pos: Vector3, yaw: float, t: float) -> void:
	if not pos.is_finite() or not is_finite(yaw):
		return
	if _p_pos.size() != PUPPET_SNAPS:
		_p_pos.resize(PUPPET_SNAPS)
		_p_yaw.resize(PUPPET_SNAPS)
		_p_t.resize(PUPPET_SNAPS)
	if _p_n > 0:
		var last := _p_n - 1
		if _flat(pos - _p_pos[last]).length() > PUPPET_TELEPORT:
			_p_n = 0
		elif t - _p_t[last] > PUPPET_STILL_GAP:
			_p_append(_p_pos[last], _p_yaw[last], t - 0.25)
	if _p_n == 0:
		if is_inside_tree():
			global_position = Vector3(pos.x, global_position.y, pos.z)
		else:
			position = Vector3(pos.x, position.y, pos.z)
		_p_last = Vector3(pos.x, 0.0, pos.z)
		_facing = yaw
		if is_instance_valid(visual):
			visual.rotation.y = yaw
	_p_append(pos, yaw, t)


func _p_append(pos: Vector3, yaw: float, t: float) -> void:
	if _p_n == PUPPET_SNAPS:
		for k in PUPPET_SNAPS - 1:
			_p_pos[k] = _p_pos[k + 1]
			_p_yaw[k] = _p_yaw[k + 1]
			_p_t[k] = _p_t[k + 1]
		_p_n -= 1
	_p_pos[_p_n] = pos
	_p_yaw[_p_n] = yaw
	_p_t[_p_n] = t
	_p_n += 1


## Where the puppet stands at time t: between the two snapshots around t, or the newest.
func puppet_sample(t: float) -> Vector3:
	if _p_n == 0:
		return global_position
	if t <= _p_t[0]:
		_facing = _p_yaw[0]
		return _p_pos[0]
	for k in range(1, _p_n):
		if t <= _p_t[k]:
			var w := clampf((t - _p_t[k - 1]) / maxf(_p_t[k] - _p_t[k - 1], 0.0001), 0.0, 1.0)
			_facing = lerp_angle(_p_yaw[k - 1], _p_yaw[k], w)
			return _p_pos[k - 1].lerp(_p_pos[k], w)
	_facing = _p_yaw[_p_n - 1]
	return _p_pos[_p_n - 1]


func puppet_snapshots() -> int:
	return _p_n


## The host's word on what it does: the anim (dead, attack, a skill's pose, run, sit,
## idle) and the flags (riding, wings).
func puppet_state(anim: String, flags: int) -> void:
	if not is_instance_valid(visual):
		return
	if anim != puppet_anim:
		var was := puppet_anim
		puppet_anim = anim
		if was == "dead":
			_dead = false
			visual.release()
			visual.play("Idle")
			_label.text = _level_text()
		if anim == "dead":
			dismount()
			_dead = true
			visual.hold_last_frame("Death_A")
			_label.text = "%s ล้ม..." % member.name
		elif anim == "attack":
			_p_attack_left = 0.0
		elif anim.begins_with("skill:") and Time.get_ticks_msec() - _p_skill_ms > PUPPET_POSE_MS:
			var skill := find_skill(anim.substr(6))
			if not skill.is_empty():
				visual.skill_action(skill, clampf(float(skill.get("hit_delay", 0.35)), 0.05, 1.5))
	puppet_flags = flags
	if _dead:
		return
	var riding := (flags & F_RIDING) != 0
	if riding and mount == null and not mount_info.is_empty():
		ride_mount(String(mount_info.id))
	elif not riding and mount != null:
		dismount()
	if visual.has_wings():
		var mode := HeroVisual.WING_FOLD
		if (flags & F_FLYING) != 0:
			mode = HeroVisual.WING_FLY
		elif (flags & F_WINGS) != 0:
			mode = HeroVisual.WING_STAND
		if mode != visual.wing_mode:
			visual.set_wing_mode(mode)


## One of its skills by id (its job's line first), {} when it has none such.
func find_skill(id: String) -> Dictionary:
	for skill in data.get("skills", []):
		if String(skill.id) == id:
			return skill
	return ClassData.find_skill(StringName(member["class"]), id)


## The host's cast (`wp_event skill`): the pose, the wind-up and, after the skill's own
## delay, its effect at the mirrored monster `at` (or ahead of it). Nobody is hurt.
func puppet_cast(skill: Dictionary, at: Node3D) -> void:
	if not puppet or _dead or not is_instance_valid(visual) or not is_instance_valid(field):
		return
	var delay := clampf(float(skill.get("hit_delay", 0.35)), 0.05, 1.5)
	var aim := global_position + Vector3(sin(_facing), 0, cos(_facing)) * 4.0
	if at != null and is_instance_valid(at):
		aim = at.global_position
		var to := _flat(aim - global_position)
		if to.length_squared() > 0.0001:
			_facing = atan2(to.x, to.z)
			visual.rotation.y = _facing
	_p_skill_ms = Time.get_ticks_msec()
	visual.skill_action(skill, delay)
	SkillShow.anticipate(field, skill, global_position, delay, aim, visual)
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.9, 0), String(skill.get("name", "")), skill.get("color", Color.WHITE), 0.5)
	var land := create_tween()
	land.tween_interval(delay)
	land.tween_callback(_puppet_land.bind(skill, weakref(at) if at != null else null, aim))


func _puppet_land(skill: Dictionary, at_ref: WeakRef, aim: Vector3) -> void:
	if not puppet or _dead or not is_instance_valid(field) or field.is_queued_for_deletion():
		return
	var at := at_ref.get_ref() as Node3D if at_ref != null else null
	var center := global_position
	var shape := String(skill.get("shape", "single"))
	if shape in ["single", "chain", "fan", "blast"]:
		center = at.global_position if at != null and is_instance_valid(at) else aim
		center.y = 0.0
	puppet_show_at = center
	if shape == "single" and bool(skill.get("projectile", false)) and at != null and is_instance_valid(at):
		var from := visual.skill_emission_position()
		var to := at.global_position + Vector3(0, 1.0, 0)
		SkillTableau.flight(field, skill, from, to, clampf(from.distance_to(to) / 22.0, 0.1, 0.5), 0.85)
	SkillShow.play(field, skill, center, global_position, 0.5 if shape == "blast" and skill.get("vfx") == &"fireball" else 0.0)


## Every frame as a puppet: glides along the snapshots, stays on the ground, plays the
## anim (swings while it attacks), rides and flies as the flags say.
func _puppet_tick(delta: float) -> void:
	if not is_instance_valid(visual) or stats.is_empty():
		return
	var now := Time.get_ticks_msec() * 0.001
	var to := puppet_sample(now - PUPPET_DELAY)
	var step := Vector2(to.x - _p_last.x, to.z - _p_last.z).length()
	_p_speed = lerpf(_p_speed, step / maxf(delta, 0.001), 1.0 - exp(-12.0 * delta))
	_p_last = to
	global_position.x = to.x
	global_position.z = to.z
	velocity = Vector3(0.0, -0.5 if is_on_floor() else velocity.y - _gravity * delta, 0.0)
	move_and_slide()
	fade_label(delta)
	if _dead:
		return
	if puppet_anim == "attack" and data.has("attack"):
		_p_attack_left -= delta
		if _p_attack_left <= 0.0:
			var attack: Dictionary = data.attack
			_p_attack_left = float(attack.get("interval", 0.8)) * 1.05
			var anims: Array = attack.get("anims", [])
			if not anims.is_empty():
				visual.action(String(anims[_p_combo % anims.size()]), 1.2)
				_p_combo += 1
	if mount != null:
		_raise_labels(MountVisual.carry(mount, visual, _facing, _p_speed, float(stats.speed) * (1.0 + MountData.speed_bonus(mount.id)), "Idle"))
		return
	visual.rotation.y = _facing
	if _p_speed > 0.6 or puppet_anim == "run":
		visual.play("Running_A", 0.12, clampf(_p_speed / 5.4, 0.8, 1.5))
	else:
		visual.play("Sit_Floor_Idle" if puppet_anim == "sit" else "Idle")
	_hover_moving(delta, _p_speed > 0.6)


## The host role came to this game (or the link went): an ordinary world player again,
## right where it stands, hunting on its own.
func end_puppet() -> void:
	if not puppet:
		return
	puppet = false
	_p_n = 0
	velocity = Vector3.ZERO
	if _dead:
		_dead = false
		if is_instance_valid(visual):
			visual.release()
			visual.play("Idle")
	puppet_anim = "idle"
	hp = max_hp
	mp = float(stats.get("max_mp", 0.0))
	target = null
	_label.text = _level_text()
	_update_bar()
	_pick_camp()
