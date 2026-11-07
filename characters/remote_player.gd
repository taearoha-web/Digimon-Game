class_name RemotePlayer
extends Node3D
## A real player seen online (Online): their character exactly as they dress it (the
## same look code as a FieldPlayer, PlayerLook: class, gear, plus glow, wings, cape, job
## ring and mount), with the name and level over the head, a small "ผู้เล่นจริง" tag
## over the name and an HP bar. It does nothing by itself: it walks where its player's
## game says (the `state` frames, played ~INTERP_DELAY behind so the steps in between
## are smooth) and plays what they do (anim: run, idle, attack, a skill, falling).
##
## It is not a monster and not a world player: the hero's attacks never reach it (only
## the "mobs" group is hit), it is not in "world_players" or "companions" (achievements,
## the chat's answers and AI monsters leave it alone), only in "remote_players". A zone
## host's shared monsters may still go for it (Mob.take_hit with this node as the
## attacker): take_damage then only reports it (monster_hit) for the shared combat to
## send on. Far from the hero on a phone it is posed less often (like FieldPlayer).
## Nothing is allocated per frame: the snapshots live in fixed packed arrays.
## The pet their game sent (player["pet"], Online: hello / look) walks along with it, a
## PetFollower the zone's PetCrowd hands out (only a picture: it never deals damage here;
## its fights show from the owner's `pet_act`, PetSync).

## A host's monster struck this player (raw damage before the victim's own defence).
signal monster_hit(raw: float, attacker: Node)

## How far behind the newest state it plays (seconds).
const INTERP_DELAY := 0.1
## Snapshots kept.
const SNAPS := 6
## A gap this long since the last state: the player stood still meanwhile, so the walk
## starts from where it stood one send interval before the new state.
const STILL_GAP := 0.3
## Farther than this between two states is a warp (travel, a respawn): no walking there.
const TELEPORT := 14.0
const LABEL_Y := 2.75
const TAG_Y := 2.96
const BAR_Y := 3.1
const NAME_COLOR := Color("bfe8ff")
const PARTY_COLOR := Color("7dff8a")
const TAG_COLOR := Color("6dffd0")
const TAG_TEXT := "ผู้เล่นจริง"
## Distance LOD, as FieldPlayer's.
const LOD_NEAR := 18.0
const LOD_FAR := 34.0
## Running above this ground speed (m/s).
const RUN_SPEED := 0.6

var id := ""
## The player's latest dictionary (Online.players()).
var player: Dictionary = {}
var look: Dictionary = {}
var visual: HeroVisual
var mount: MountVisual
## The hero, for the distance LOD (Online sets it).
var hero: Node3D
var anim := "idle"
var hp := 1
var max_hp := 1
var in_party := false

var _label: Label3D
var _tag: Label3D
var _bar: FieldHpBar
var _ring: MeshInstance3D
var _look_sig := ""
var _body_sig := ""
var _snap_pos := PackedVector3Array()
var _snap_yaw := PackedFloat32Array()
var _snap_t := PackedFloat64Array()
var _snap_n := 0
var _facing := 0.0
var _speed := 0.0
var _last_pos := Vector3.ZERO
var _attack_anims: Array = []
var _attack_every := 0.8
var _attack_left := 0.0
var _combo := 0
var _mount_id := ""
var _lod_check := 0.0
var _label_key := ""
var _bob := 0.0
## How high the labels ride (the seat of a mount) and the room a God's title line takes.
var _lift := 0.0
var _god_lift := 0.0


## Called before it enters the tree: the player's dictionary (id, name, look, pos ...).
func setup(p: Dictionary) -> void:
	id = String(p.get("id", ""))
	player = p


func _ready() -> void:
	add_to_group("remote_players")
	name = "Remote_%s" % id.validate_node_name()
	_snap_pos.resize(SNAPS)
	_snap_yaw.resize(SNAPS)
	_snap_t.resize(SNAPS)
	visual = HeroVisual.new()
	visual.decor_light = true
	add_child(visual)
	MeshKit.blob_shadow(self, 0.8)
	_label = _make_label(0.0046, 44, LABEL_Y)
	_label.outline_size = 12
	add_child(_label)
	_tag = _make_label(0.004, 32, TAG_Y)
	_tag.text = TAG_TEXT
	_tag.modulate = TAG_COLOR
	add_child(_tag)
	_bar = FieldHpBar.new()
	_bar.position = Vector3(0, BAR_Y, 0)
	_bar.visible = false
	add_child(_bar)
	apply_look(player.get("look", {}), int(player.get("level", 1)), int(player.get("stars", 0)))
	var at: Vector3 = Online.vec3(player.get("pos"))
	position = at
	_last_pos = at
	_facing = float(player.get("yaw", 0.0)) if (player.get("yaw") is float or player.get("yaw") is int) else 0.0
	visual.rotation.y = _facing
	apply_state(player)


func _make_label(pixel: float, font: int, y: float) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = pixel * BattleVfx.text_scale
	l.font_size = font
	l.outline_size = 9
	l.outline_modulate = Color(0.08, 0.1, 0.18, 0.95)
	l.position = Vector3(0, y, 0)
	l.visibility_range_end = 34.0
	l.no_depth_test = true
	l.render_priority = 2
	return l


# --- What the network says ------------------------------------------------------------

## A `look` (or the look in a join): the body is rebuilt when the class, job or face
## changed, only the gear when the pieces changed.
func apply_look(raw: Variant, level := -1, stars := -1) -> void:
	var clean := PlayerLook.clean(raw)
	if level >= 1:
		clean["level"] = clampi(level, 1, Game.MAX_LEVEL)
	if stars >= 0:
		clean["stars"] = clampi(stars, 0, Game.PARAGON_MAX)
	var sig := PlayerLook.signature(clean)
	if sig == _look_sig or not is_instance_valid(visual):
		return
	_look_sig = sig
	look = clean
	var body := "%s|%d|%s" % [clean["class"], int(clean.adv), PlayerLook.signature(clean.face)]
	if body != _body_sig:
		_body_sig = body
		var riding := mount != null
		if riding:
			_get_off()
		PlayerLook.dress(visual, look)
		if riding:
			_get_on(_mount_id)
		if anim == "dead":
			visual.hold_last_frame("Death_A")
	else:
		PlayerLook.redress(visual, look)
		if visual.has_wings() and visual.wing_mode != int(look.wing_mode) and mount == null:
			visual.set_wing_mode(int(look.wing_mode))
	var data := JobData.resolve(StringName(look["class"]), int(look.adv))
	var attack: Dictionary = data.get("attack", {})
	_attack_anims = attack.get("anims", ["1H_Melee_Attack_Chop"])
	_attack_every = clampf(float(attack.get("interval", 0.8)), 0.3, 2.0)
	_update_ring()
	_update_label()


## A `state` (or a join's fields): where it is going, what it does, its HP and mount.
func apply_state(p: Dictionary) -> void:
	if p.has("pos"):
		var yaw: float = float(p.yaw) if (p.get("yaw") is float or p.get("yaw") is int) and is_finite(float(p.yaw)) else _facing
		push_snapshot(Online.vec3(p.pos), yaw, Time.get_ticks_msec() * 0.001)
	if p.has("hp") or p.has("max_hp"):
		max_hp = maxi(1, Online.num(p.get("max_hp", max_hp), max_hp))
		hp = clampi(Online.num(p.get("hp", hp), hp), 0, max_hp)
		_bar.set_ratio(float(hp) / float(max_hp))
		_bar.visible = hp < max_hp or in_party
	if p.has("anim"):
		_set_anim(str(p.anim))
	if p.has("mount"):
		var want := str(p.mount) if p.mount != null else ""
		if want != _mount_id:
			_mount_id = want
			if want == "" or not MountData.exists(want) or anim == "dead":
				_get_off()
			else:
				_get_on(want)
	_update_label()


## In the hero's party (real party): the name in the party's green, the bar always shown.
func set_party(on: bool) -> void:
	in_party = on
	_bar.visible = hp < max_hp or in_party
	_label_key = ""
	_update_label()


## A chat bubble over its head for a few seconds.
func bubble(text: String) -> void:
	if not is_instance_valid(visual) or not visible:
		return
	var old := get_node_or_null("Bubble")
	if old != null:
		old.free()
	var b := _make_label(0.0042, 40, 3.7)
	b.name = "Bubble"
	b.modulate = Color("fffbe8")
	b.width = 520.0
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.render_priority = 3
	b.visibility_range_end = 26.0
	b.text = text.left(120)
	add_child(b)
	var fade := b.create_tween()
	fade.tween_interval(4.0)
	fade.tween_property(b, "modulate:a", 0.0, 0.6)
	fade.tween_callback(b.queue_free)


## Adds one position at time t (seconds): a long pause first holds the old spot until one
## send interval before t, so it walks off instead of sliding the whole pause long.
func push_snapshot(pos: Vector3, yaw: float, t: float) -> void:
	if not pos.is_finite():
		return
	if _snap_n > 0:
		var last := _snap_n - 1
		if pos.distance_to(_snap_pos[last]) > TELEPORT:
			_snap_n = 0
			position = pos
		elif t - _snap_t[last] > STILL_GAP:
			_append(_snap_pos[last], _snap_yaw[last], t - 0.125)
	_append(pos, yaw, t)


func _append(pos: Vector3, yaw: float, t: float) -> void:
	if _snap_n == SNAPS:
		for k in SNAPS - 1:
			_snap_pos[k] = _snap_pos[k + 1]
			_snap_yaw[k] = _snap_yaw[k + 1]
			_snap_t[k] = _snap_t[k + 1]
		_snap_n -= 1
	_snap_pos[_snap_n] = pos
	_snap_yaw[_snap_n] = yaw
	_snap_t[_snap_n] = t
	_snap_n += 1


## Where it stands at time t (seconds): between the two states around t, or the newest.
func sample(t: float) -> Vector3:
	if _snap_n == 0:
		return position
	if t <= _snap_t[0]:
		return _snap_pos[0]
	for k in range(1, _snap_n):
		if t <= _snap_t[k]:
			var span := maxf(_snap_t[k] - _snap_t[k - 1], 0.0001)
			var w := clampf((t - _snap_t[k - 1]) / span, 0.0, 1.0)
			_facing = lerp_angle(_snap_yaw[k - 1], _snap_yaw[k], w)
			return _snap_pos[k - 1].lerp(_snap_pos[k], w)
	_facing = _snap_yaw[_snap_n - 1]
	return _snap_pos[_snap_n - 1]


func snapshot_count() -> int:
	return _snap_n


func is_dead() -> bool:
	return anim == "dead"


## A shared monster (on the zone host's game) struck this player: the shared combat
## sends it on; nothing happens here.
func take_damage(raw: float, attacker: Node = null) -> void:
	if not is_dead():
		monster_hit.emit(raw, attacker)


# --- Every frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(visual):
		return
	_lod_check -= delta
	if _lod_check <= 0.0:
		_lod_check = 0.5
		_update_lod()
	var now := Time.get_ticks_msec() * 0.001
	var to := sample(now - INTERP_DELAY)
	var step := Vector2(to.x - _last_pos.x, to.z - _last_pos.z).length()
	_speed = lerpf(_speed, step / maxf(delta, 0.001), 1.0 - exp(-12.0 * delta))
	_last_pos = to
	position = to
	if anim == "dead":
		return
	if anim == "attack":
		_attack_left -= delta
		if _attack_left <= 0.0:
			_attack_left = _attack_every
			_attack_once()
	if mount != null:
		var lift := MountVisual.carry(mount, visual, _facing, _speed, 6.0, "Idle")
		_raise(lift)
		return
	visual.rotation.y = _facing
	if _speed > RUN_SPEED or anim == "run":
		visual.play("Running_A", 0.12, clampf(_speed / 5.4, 0.8, 1.5))
	else:
		visual.play("Idle")
	_hover(delta)


## Flying wings lift it a little with a gentle bob, like the hero.
func _hover(delta: float) -> void:
	var moving := _speed > RUN_SPEED
	var flying := visual.flying()
	if not flying and is_zero_approx(visual.position.y):
		return
	visual.set_wing_moving(moving)
	_bob += delta
	var lift := Hero.FLY_HEIGHT + sin(_bob * 2.5) * 0.1 if flying else 0.0
	visual.position.y = lerpf(visual.position.y, lift, 1.0 - exp(-4.0 * delta))
	if visual.model != null:
		visual.model.rotation.x = lerpf(visual.model.rotation.x, Hero.FLY_LEAN if flying and moving else 0.0, 1.0 - exp(-5.0 * delta))


func _set_anim(a: String) -> void:
	if a == anim:
		return
	var was := anim
	anim = a
	if was == "dead":
		visual.release()
		visual.play("Idle")
	if a == "dead":
		_get_off()
		visual.hold_last_frame("Death_A")
	elif a == "attack":
		_attack_left = _attack_every
		_attack_once()
	elif a.begins_with("skill:"):
		var skill := ClassData.find_skill(StringName(look.get("class", ClassData.START)), a.substr(6))
		if skill.is_empty():
			visual.action("Spellcast_Shoot")
		else:
			visual.skill_action(skill, clampf(float(skill.get("hit_delay", 0.35)), 0.05, 1.5))


func _attack_once() -> void:
	if _attack_anims.is_empty():
		return
	var clip := String(_attack_anims[_combo % _attack_anims.size()])
	_combo += 1
	visual.action(clip, 1.2)


func _get_on(mount_id: String) -> void:
	if mount_id == "" or not MountData.exists(mount_id) or not is_instance_valid(visual):
		return
	if mount != null:
		if mount.id != mount_id:
			mount.build(mount_id)
		return
	mount = MountVisual.mount_up(self, self, visual, mount_id, _facing)
	mount.lod_step = visual.anim_lod
	mount.set_far(visual.anim_lod >= 2 and not in_party)


func _get_off() -> void:
	if mount == null:
		return
	MountVisual.step_down(self, mount, visual)
	mount = null
	_raise(0.0)


func is_riding() -> bool:
	return mount != null


func _raise(lift: float) -> void:
	_lift = lift
	_label.position.y = LABEL_Y + lift
	_tag.position.y = TAG_Y + _god_lift + lift
	_bar.position.y = BAR_Y + _god_lift + lift


## Posed less often far from the hero (phones gain the most), like FieldPlayer.
func _update_lod() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var d := Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length()
	var step := 1
	if not in_party:
		if d > LOD_FAR:
			step = 4
		elif d > LOD_NEAR:
			step = 2
	visual.set_anim_lod(step)
	visual.set_far(step >= 2)
	if mount != null:
		mount.lod_step = step
		mount.set_far(step >= 2)


## "✦ God title ✦ / Name Lv.41 ★5" in the party's green or the players' blue.
func _update_label() -> void:
	var lv := clampi(Online.num(player.get("level", look.get("level", 1)), 1), 1, Game.MAX_LEVEL)
	var stars := clampi(Online.num(player.get("stars", look.get("stars", 0)), 0), 0, Game.PARAGON_MAX)
	var who := Online.display_name(player)
	var key := "%s|%d|%d|%s|%s|%d" % [who, lv, stars, in_party, anim == "dead", int(look.get("adv", 0))]
	if key == _label_key:
		return
	_label_key = key
	var line := "%s Lv.%d%s" % [who, lv, " ★%d" % stars if stars > 0 else ""]
	var god := WorldPlayers.god_title({"class": look.get("class", ClassData.START), "level": lv, "stars": stars})
	if god != "" and JobData.is_god(int(look.get("adv", 0))):
		line = "✦ %s ✦\n%s" % [god, line]
	if anim == "dead":
		line = "%s ล้ม..." % who
	_label.text = line
	_label.modulate = PARTY_COLOR if in_party else NAME_COLOR
	_god_lift = 0.2 if line.contains("\n") else 0.0
	_raise(_lift)


## The glowing ring of a hero who has changed jobs (as the hero's own).
func _update_ring() -> void:
	var adv := int(look.get("adv", 0))
	if is_instance_valid(_ring):
		_ring.queue_free()
		_ring = null
	if adv <= 0:
		return
	var step := JobData.current(StringName(look["class"]), adv)
	if step.is_empty():
		return
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.78
	torus.outer_radius = 0.94
	torus.rings = 24
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring.material_override = MeshKit.toon(step.get("color", Color.WHITE), {"unshaded": true, "emission": 1.0})
	_ring.scale = Vector3(1, 0.12, 1)
	_ring.position = Vector3(0, 0.07, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
