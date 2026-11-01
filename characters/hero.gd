class_name Hero
extends CharacterBody3D
## The player's hero: moves with the joystick, auto-attacks the locked-on
## monster, casts four class skills and drinks potions. HP / MP live in
## [Game] (profile) so they persist; this node plays them out in 3D.

signal died()
signal target_changed(target: Mob)
signal skill_fired(index: int)
signal message(text: String)
signal auto_changed(on: bool)

const TARGET_RANGE := 16.0
const POTION_COOLDOWN := 1.2
const SLOW_FACTOR := 0.6
## How high flying wings lift the hero.
const FLY_HEIGHT := 0.9
## Forward lean (radians) while flying on the move.
const FLY_LEAN := 0.38
const LEECH_TEXT_MS := 700
## A gem set's Thai note ("เลือดเดือด! ...") shows again only after this long.
const GEM_NOTE_MS := 15000
## Emerald set: 2% of max HP every 5 s in combat; sapphire set: 2% of max MP every 3 s.
const GEM_REGEN_SHARE := 0.02
const EMERALD_PERIOD := 5.0
const SAPPHIRE_PERIOD := 3.0
## Ruby set fires under this share of max HP, amethyst set under BULWARK_HP.
const FURY_HP := 0.3
const BULWARK_HP := 0.5
## Riding (MountData / MountVisual): the rider's body clip and how high its hips sit
## above its soles in that clip. The chibi rig has no chair sit, only the floor sit
## (hip bone 0.15 above the soles); 0.13 rests the pelvis on the saddle.
const RIDE_CLIP := "Sit_Floor_Idle"
const RIDE_HIP := 0.13
const NAME_PLATE_Y := 2.45

var visual: HeroVisual
var _equip_sig := ""
var _step_timer := 0.0
var _ring_job: StringName = &""
var _ring: MeshInstance3D
var _name_plate: Label3D
var _self_ring: MeshInstance3D
const SELF_RING_COLOR := Color("ffd24a")
var camera_rig: ThirdPersonCamera
var field: Node3D
var safe_zone := false
var field_radius := 56.0
## A floor (x, z) the hero may stand on past the round edge: the guild war's castle hall.
var field_hall := Rect2()

var move_input := Vector2.ZERO
var _star_combo_target := 0
var _star_combo_count := 0
var _star_retaliation := false
var target: Mob
## Auto-attack mode: keeps hitting the target and picks the next one itself.
var engaged := false
## Auto hunting: fights inside the camp it was switched on in, uses skills and potions.
var auto := false
var _summons: Array = []
var _auto_center := Vector3.ZERO
var _auto_radius := 10.0
var _auto_timer := 0.0
var stats: Dictionary = {}
var cooldowns: Dictionary = {}
var last_cast_id := ""
var potion_cd := 0.0

var _buffs: Array[Dictionary] = []
var _auras: Dictionary = {} # kind -> BuffAura
var _pending: Dictionary = {}
var _attack_timer := 0.0
var _combo := 0
var _cast_until := 0
var _since_hurt := 99.0
var _slow_until := 0
var _reflect_ms := 0
## Marks an enemy Bard (arena rival, guild fighter) put on the hero: DEF / ATK
## down by a fraction until a time (ms); players feel half of a monster's mark.
var _enemy_shred := 0.0
var _enemy_shred_until := 0
var _enemy_weaken := 0.0
var _enemy_weaken_until := 0
var _mark_word_at := {}
var _regen_hp := 0.0
var _regen_mp := 0.0
## Lifesteal (pearl gems): healing below 1 HP carried to the next hit, and the "+N"
## shown at most every LEECH_TEXT_MS (the sum of what was healed meanwhile).
var _leech_left := 0.0
var _leech_unshown := 0
var _leech_text_at := -100000
## Gem sets (HeroStats gem_set): which conditional set is on, the regen tick and
## when each set last announced itself.
var _fury_on := false
var _bulwark_on := false
var _gem_regen_time := 0.0
var _gem_note_at := {}
var _dead := false
var _invulnerable_until := 0
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
var _facing := 0.0
var _quiet := false
## The mount the hero sits on (null on foot). Riding is for travel only.
var mount: MountVisual
## The hero was riding when it left the last zone: a new hero rides on where allowed.
static var keep_riding := false


func _ready() -> void:
	add_to_group("hero")
	collision_layer = 1 << 1
	collision_mask = 1 << 0
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	visual = HeroVisual.new()
	visual.wing_mode = clampi(int(Game.profile.flags.get("wing_mode", 0)), HeroVisual.WING_STAND, HeroVisual.WING_FOLD)
	add_child(visual)
	visual.setup(Game.class_id(), "", true, Game.profile.equip, _look())
	_equip_sig = _equipment_signature()
	MeshKit.blob_shadow(self, 0.8)
	refresh_stats()
	Game.profile_changed.connect(refresh_stats)
	Game.inventory_changed.connect(_on_inventory_changed)
	Game.profile_changed.connect(_update_job_ring)
	_update_job_ring()
	_build_self_ring()
	_build_name_plate()
	Game.title_changed.connect(_on_title_changed)
	Game.mount_changed.connect(_on_mount_changed)
	if keep_riding and Game.active_mount() != "" and can_ride_here():
		ride(true)


## The hero's name above the head, with the chosen title (Achievements) in brackets
## above it on a smaller line.
func _build_name_plate() -> void:
	_name_plate = Label3D.new()
	_name_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_plate.pixel_size = 0.0034 * BattleVfx.text_scale
	_name_plate.font_size = 34
	_name_plate.outline_size = 9
	_name_plate.modulate = Color("fff4de")
	_name_plate.outline_modulate = Color(0.1, 0.12, 0.2, 0.9)
	_name_plate.position = Vector3(0, NAME_PLATE_Y, 0)
	_name_plate.no_depth_test = true
	_name_plate.render_priority = 2
	_name_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_plate)
	refresh_name_plate()


func _on_title_changed(_title: String) -> void:
	refresh_name_plate()


func refresh_name_plate() -> void:
	if not is_instance_valid(_name_plate):
		return
	var hero_name := String(Game.profile.get("name", ""))
	var title := Achievements.title_of(Game.profile)
	_name_plate.text = "「%s」\n%s" % [title, hero_name] if title != "" else hero_name


## Changes the hero's weapon / hat / outfit when the worn items change.
func _on_inventory_changed() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	var sig := _equipment_signature()
	if sig != _equip_sig:
		_equip_sig = sig
		visual.set_equipment(Game.profile.equip)


## A thin gold ring under the hero's own feet (inside the job ring), so the player finds
## the hero at once in the middle of a party fight. One unshaded mesh, no shadow.
func _build_self_ring() -> void:
	_self_ring = MeshInstance3D.new()
	_self_ring.name = "SelfRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.68
	torus.rings = 32
	torus.ring_segments = 4
	_self_ring.mesh = torus
	_self_ring.material_override = MeshKit.toon(SELF_RING_COLOR, {"unshaded": true, "emission": 0.6, "alpha": 0.85})
	_self_ring.scale = Vector3(1, 0.1, 1)
	_self_ring.position = Vector3(0, 0.06, 0)
	_self_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_self_ring)


## A glowing ring under the feet of a hero who has changed jobs.
func _update_job_ring() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	_sync_raven()
	var job := StringName("%s|%d" % [Game.class_id(), Game.adv()])
	if job == _ring_job:
		return
	_ring_job = job
	if _ring:
		_ring.queue_free()
		_ring = null
	if Game.adv() <= 0:
		return
	var color: Color = JobData.current(Game.class_id(), Game.adv()).color
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.78
	torus.outer_radius = 0.94
	torus.rings = 36
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring.material_override = MeshKit.toon(color, {"unshaded": true, "emission": 1.0})
	_ring.scale = Vector3(1, 0.12, 1)
	_ring.position = Vector3(0, 0.07, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _equipment_signature() -> String:
	var parts: PackedStringArray = []
	for slot in ["weapon", "armor", "helm", "boots", "amulet", "ring", "wings"]:
		var item: Variant = Game.profile.equip.get(slot)
		parts.append((ItemLook.look_of(item) + "|%d|%d" % [int(item.get("plus", 0)), int(item.get("rarity", 0))]) if item is Dictionary else "-")
	return "|".join(parts)


func refresh_stats() -> void:
	var totals := {"atk": 0.0, "def": 0.0, "speed": 0.0, "crit": 0.0, "dodge": 0.0}
	var now := Time.get_ticks_msec()
	for key in totals:
		var values: Array = []
		for buff in _buffs:
			if buff.until > now:
				values.append(float(buff.get(key, 0.0)))
		totals[key] = BuffBook.stack(values)
	stats = Game.stats_now(totals)


func is_dead() -> bool:
	return _dead


func facing() -> float:
	return _facing


func set_facing(yaw: float) -> void:
	_facing = yaw
	visual.rotation.y = yaw


## Each active skill owns its authored aura, removed with its actual stats.
func _sync_auras(now: int) -> void:
	BuffAura.sync(self, _auras, _buffs, now, not _dead, _body_top)


## Height from the soles to the highest point of the body (hat / big hair included).
func _body_top() -> float:
	return BuffAura.measure_top(visual, self)


## What the HUD timer bars show: active buffs (own and from allies) and summons,
## each {id, name, color, left, total, kind, ally, count, hp}. [left] counts down in seconds.
func timer_status() -> Array:
	var out: Array = []
	var now := Time.get_ticks_msec()
	var seen := {}
	for buff in _buffs:
		var left := (float(buff.until) - float(now)) / 1000.0
		if left <= 0.0:
			continue
		var key := "buff:%s:%s" % [BuffBook.identity(buff), buff.get("ally", false)]
		if seen.has(key):
			var entry: Dictionary = out[seen[key]]
			if left > float(entry.left):
				entry["left"] = left
				entry["total"] = float(buff.get("total", left))
			continue
		seen[key] = out.size()
		var glyph := "power"
		if BuffBook.is_song(buff):
			glyph = "note"
		elif float(buff.get("def", 0.0)) > 0.0:
			glyph = "shield"
		elif float(buff.get("atk", 0.0)) > 0.0:
			glyph = "power"
		elif float(buff.get("speed", 0.0)) > 0.0:
			glyph = "wind"
		elif float(buff.get("crit", 0.0)) > 0.0:
			glyph = "spark"
		out.append({"id": key, "glyph": glyph, "name": String(buff.get("name", "บัฟ")), "color": BuffArt.profile(buff).primary, "left": left,
				"total": float(buff.get("total", left)), "kind": "buff", "ally": bool(buff.get("ally", false)), "song": BuffBook.is_song(buff), "count": 1, "hp": 1.0})
	for summon in _summons:
		if not is_instance_valid(summon) or summon.is_dead():
			continue
		var key := "summon:%s" % summon.skill_id
		if seen.has(key):
			var entry: Dictionary = out[seen[key]]
			entry["count"] = int(entry.count) + 1
			entry["left"] = minf(float(entry.left), float(summon.life))
			entry["hp"] = minf(float(entry.hp), float(summon.hp) / float(maxi(summon.max_hp, 1)))
			continue
		seen[key] = out.size()
		var skill := ClassData.find_skill(Game.class_id(), String(summon.skill_id))
		out.append({"id": key, "glyph": "summon", "name": String(skill.get("name", summon.skill_id)), "color": skill.get("color", Color("7fe3ff")), "left": float(summon.life),
				"total": float(summon.spec.get("secs", Summon.LIFETIME)), "kind": "summon", "ally": false, "count": 1,
				"hp": float(summon.hp) / float(maxi(summon.max_hp, 1))})
	return out


func has_buff() -> bool:
	var now := Time.get_ticks_msec()
	for buff in _buffs:
		if buff.until > now:
			return true
	return false


## The song playing on the hero (its own or a party Bard's), or {}.
func song_entry() -> Dictionary:
	return BuffBook.song_of(_buffs)


## Seconds left of the hero's newest song (0 without one).
func song_left() -> float:
	return BuffBook.song_left(_buffs)


## The buffs songs are counted on (the party's song slots live on the hero).
func song_buffs() -> Array:
	return _buffs


# ---------------------------------------------------------------------------
# Input from the HUD
# ---------------------------------------------------------------------------

## The big attack button: lock the nearest monster and start auto-attacking.
func tap_attack() -> void:
	if _dead or safe_zone:
		return
	dismount()
	if not _valid_target(target):
		set_target(nearest_mob())
	if target == null:
		message.emit("ไม่มีมอนสเตอร์อยู่ใกล้ๆ")
		return
	engaged = true


# ---------------------------------------------------------------------------
# Auto hunting
# ---------------------------------------------------------------------------

func toggle_auto() -> void:
	set_auto(not auto)


func set_auto(on: bool) -> void:
	if on == auto:
		return
	if on:
		if _dead or safe_zone:
			message.emit("ออโต้ใช้ได้เฉพาะในทุ่งล่ามอนสเตอร์")
			return
		dismount()
		var camp: Dictionary = field.camp_near(global_position) if field and field.has_method("camp_near") else {}
		if camp.is_empty():
			_auto_center = global_position
			_auto_radius = 12.0
		else:
			_auto_center = Vector3(camp.pos.x, 0.0, camp.pos.y)
			_auto_radius = float(camp.radius)
		Game.say("ออโต้เปิด: ล่าในวงนี้ (แตะปุ่มออโต้หรือเดินเองเพื่อหยุด)", &"info")
	else:
		engaged = false
		_pending = {}
	auto = on
	auto_changed.emit(on)


func _auto_step(delta: float) -> Vector3:
	_auto_timer -= delta
	if _auto_timer <= 0.0:
		_auto_timer = 0.3
		_auto_think()
	var home := _flat(_auto_center - global_position)
	if not _valid_target(target):
		if home.length() > 4.0:
			_face(home, delta, 12.0)
			return home.normalized() * float(stats.speed)
		return Vector3.ZERO
	if home.length() > _auto_radius + 6.0:
		set_target(null)
		engaged = false
		_pending = {}
		return Vector3.ZERO
	return _combat_step(delta)


func _auto_think() -> void:
	var hp_rate := float(Game.profile.hp) / float(maxi(1, stats.max_hp))
	var mp_rate := float(Game.profile.mp) / float(maxi(1, stats.max_mp))
	if hp_rate < 0.45 and Game.total_potions("hp") > 0:
		use_potion("hp")
	if mp_rate < 0.2 and Game.total_potions("mp") > 0:
		use_potion("mp")
	if hp_rate < 0.25 and Game.total_potions("hp") == 0:
		message.emit("ยาเลือดหมด — ปิดออโต้")
		set_auto(false)
		return
	if not _valid_target(target):
		for mob in mobs_in_range(_auto_radius + 6.0):
			if _flat(mob.global_position - _auto_center).length() <= _auto_radius + 2.0:
				set_target(mob)
				break
	engaged = _valid_target(target)
	if engaged and _pending.is_empty() and Time.get_ticks_msec() >= _cast_until and mp_rate > 0.12:
		_auto_cast(hp_rate)


## Picks the next skill off the bar that makes sense right now. A song plays when
## the song slot is (nearly) empty, so the first song on the bar is the default and a
## running song is never cut short, except by a healing song when badly hurt. A skill
## whose marks (shred / weaken) are already on the target waits, and is cast only when
## nothing later on the bar can be.
func _auto_cast(hp_rate: float) -> void:
	var skills: Array = Game.class_data().skills
	var crowd := mobs_in_range(7.0).size()
	var fallback := -1
	for i in skills.size():
		var skill: Dictionary = skills[i]
		if skill.is_empty() or not Game.skill_unlocked(skill):
			continue
		if float(cooldowns.get(skill.id, 0.0)) > 0.0 or int(Game.profile.mp) < mp_cost(skill):
			continue
		var fx: Dictionary = skill.get("fx", {})
		# Summon (recall) pulls the whole party in: only ever on the player's own press.
		if fx.has("recall"):
			continue
		var marks := Mob.carries_mark(fx)
		match String(skill.shape):
			"self":
				if BuffBook.is_song_skill(skill):
					# An attack song and a ward song play together: sing this one when it is not
					# playing (or about to end) and its family's slot is free or that song is
					# about to end; a healing song comes in at once when badly hurt.
					var own_left := BuffBook.song_left_of(_buffs, String(skill.id))
					var swap := fx.has("heal") and hp_rate < 0.45 and own_left <= 0.0
					var rival := BuffBook.song_to_replace(_buffs, BuffBook.skill_song_family(skill))
					var full := not rival.is_empty() and float(rival.until) - float(Time.get_ticks_msec()) >= 3000.0
					if not swap and (own_left >= 3.0 or full):
						continue
				else:
					var stance := fx.get("buff") is Dictionary and BuffBook.is_self_only(fx.buff)
					if fx.has("heal") and not stance and hp_rate > (0.55 if not fx.has("buff") else 0.75):
						continue
					if fx.has("buff") and (not fx.has("heal") or stance) and (BuffBook.group_count(_buffs, false) >= BuffBook.GROUP_LIMIT or BuffBook.contains(_buffs, String(skill.id), false)):
						continue
			"summon":
				if _summons_alive(skill.id) > 0:
					continue
			"burst":
				# A marking burst also opens on a lone monster that is still unmarked.
				if crowd < 2 and not (marks and mobs_in_range(float(_ranked(skill).radius)).size() >= 1 and Mob.lacks_mark(target, fx, 2.0)):
					continue
		# (Star skills are nukes first: their marks never hold them back.)
		if marks and crowd < 3 and not skill.has("star") and not Mob.lacks_mark(target, fx, 2.0):
			if fallback < 0:
				fallback = i
			continue
		use_skill(i)
		return
	if fallback >= 0:
		use_skill(fallback)


## A monster tapped on the screen: lock onto it and, by the tap setting
## (GameSettings.tap_target_mode), go for it (auto hunting follows it) or only mark it.
func tap_target(mob: Mob) -> void:
	if _dead or safe_zone or not _valid_target(mob) or GameSettings.tap_target_mode >= 2:
		return
	dismount()
	set_target(mob)
	_pending = {}
	if GameSettings.tap_target_mode == 1:
		engaged = false
	else:
		engaged = true
		if auto:
			_auto_center = mob.global_position
	var who := String((mob as Rival).member.get("name", "")) if mob is Rival else String(mob.template.get("name", ""))
	message.emit("เลือกเป้า: %s" % who)


func set_target(mob: Mob) -> void:
	if mob == target:
		return
	if _valid_target(target):
		target.set_targeted(false)
	target = mob if _valid_target(mob) else null
	if target:
		target.set_targeted(true)
	target_changed.emit(target)


func cycle_target() -> void:
	var list := mobs_in_range()
	if list.is_empty():
		set_target(null)
		return
	var index := list.find(target)
	set_target(list[(index + 1) % list.size()])


func mobs_in_range(radius := TARGET_RANGE) -> Array[Mob]:
	var list: Array[Mob] = []
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and not mob.is_dead() and _flat(mob.global_position - global_position).length() <= radius:
			list.append(mob)
	list.sort_custom(func(a: Mob, b: Mob) -> bool:
		if a.hostile != b.hostile:
			return a.hostile
		return _flat(a.global_position - global_position).length() < _flat(b.global_position - global_position).length())
	return list


func nearest_mob(radius := TARGET_RANGE) -> Mob:
	var list := mobs_in_range(radius)
	return list[0] if not list.is_empty() else null


func use_potion(kind: String) -> void:
	if _dead or potion_cd > 0.0:
		return
	if Game.in_duel():
		Game.say("ใช้ยาในสนามจัดอันดับไม่ได้", &"warning")
		potion_cd = 1.0
		return
	var before_hp: int = Game.profile.hp
	var before_mp: int = Game.profile.mp
	var id := Game.quick_potion(kind)
	if id == "":
		message.emit("ไม่มียา%s หรือเต็มอยู่แล้ว" % ("เลือด" if kind == "hp" else "มานา"))
		return
	potion_cd = POTION_COOLDOWN
	AudioManager.play_sfx(&"item_use")
	var gained: int = (Game.profile.hp - before_hp) if kind == "hp" else (Game.profile.mp - before_mp)
	VfxKit.heal(field, global_position, Color("6dff9a") if kind == "hp" else Color("6aa8ff"))
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.6, 0), "+%d" % gained,
			Color("6dff9a") if kind == "hp" else Color("7ab4ff"), 1.0)


# ---------------------------------------------------------------------------
# Frame update
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _dead:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
		move_and_slide()
		visual.position.y = lerpf(visual.position.y, 0.0, 1.0 - exp(-6.0 * delta))
		return
	_tick_timers(delta)
	var now := Time.get_ticks_msec()
	var casting := now < _cast_until
	var direction := _read_move()
	if direction.length() > 0.1 and not casting:
		engaged = false
		_pending = {}
		if auto:
			set_auto(false)
	if _target_dead():
		_on_target_lost()
	var desired := Vector3.ZERO
	if not casting:
		if direction.length() > 0.1:
			desired = direction * move_speed()
			_face(direction, delta, 14.0)
		elif auto:
			desired = _auto_step(delta)
		else:
			desired = _combat_step(delta)
	if Time.get_ticks_msec() < _slow_until:
		desired *= SLOW_FACTOR
	velocity.x = lerpf(velocity.x, desired.x, 1.0 - exp(-16.0 * delta))
	velocity.z = lerpf(velocity.z, desired.z, 1.0 - exp(-16.0 * delta))
	velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	_clamp_to_field()
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	if mount != null:
		if not can_ride_here():
			dismount()
		else:
			_ride_step(speed)
			return
	if speed > 0.6:
		visual.play("Running_A", 0.12, clampf(speed / 5.4, 0.8, 1.4))
		_step_timer -= delta
		if _step_timer <= 0.0 and is_on_floor():
			_step_timer = 0.34
			AudioManager.play_sfx(&"step", -17.0, 0.12)
	else:
		visual.play("Idle")
	_hover(delta, speed > 0.6)


## Flying wings lift the hero off the ground (the shadow stays below) with a
## gentle bob; standing or folded wings bring it back down.
func _hover(delta: float, moving: bool) -> void:
	if has_meta("star_airborne"): return
	var flying := visual.has_wings() and visual.wing_mode == HeroVisual.WING_FLY
	visual.set_wing_moving(moving)
	var lift := 0.0
	if flying:
		lift = FLY_HEIGHT + sin(Time.get_ticks_msec() * 0.0025) * 0.1
	visual.position.y = lerpf(visual.position.y, lift, 1.0 - exp(-4.0 * delta))
	# Flying forward leans the whole body into the flight.
	if visual.model != null:
		var lean := FLY_LEAN if flying and moving else 0.0
		visual.model.rotation.x = lerpf(visual.model.rotation.x, lean, 1.0 - exp(-5.0 * delta))


# ---------------------------------------------------------------------------
# Mounts (MountData): faster travel; any fight puts the hero back on foot
# ---------------------------------------------------------------------------

func is_riding() -> bool:
	return mount != null


## Walking speed now: the mount's bonus on top while riding.
func move_speed() -> float:
	var base := float(stats.speed)
	return base * (1.0 + MountData.speed_bonus(mount.id)) if mount != null else base


## The town and the hunting fields; not the arena, duels, the guild war or the tower.
func can_ride_here() -> bool:
	return not (field is Zone) or MountData.zone_allows((field as Zone).data)


## Gets on the active mount. Returns false (with a note unless [param quiet]) when it can't.
func ride(quiet := false) -> bool:
	if mount != null:
		return true
	var id := Game.active_mount()
	var why := ""
	if _dead:
		why = "ขี่สัตว์ไม่ได้ตอนนี้"
	elif id == "":
		why = "ยังไม่มีสัตว์ขี่ สร้างได้ที่เมนู > สัตว์ขี่"
	elif not can_ride_here():
		why = "พื้นที่นี้ขี่สัตว์ไม่ได้"
	if why != "":
		if not quiet:
			message.emit(why)
		return false
	if auto:
		set_auto(false)
	engaged = false
	_pending = {}
	visual.release()
	mount = MountVisual.new()
	add_child(mount)
	mount.build(id)
	mount.rotation.y = _facing
	visual.stow_held(true)
	var shadow := get_node_or_null("BlobShadow") as Node3D
	if shadow != null:
		shadow.visible = false
	keep_riding = true
	return true


## Back on foot (attacking, casting, a hit, death or a no-riding zone).
func dismount() -> void:
	if mount == null:
		return
	mount.queue_free()
	mount = null
	keep_riding = false
	visual.stow_held(false)
	var shadow := get_node_or_null("BlobShadow") as Node3D
	if shadow != null:
		shadow.visible = true
	visual.position = Vector3(0, visual.position.y, 0)
	if is_instance_valid(_name_plate):
		_name_plate.position.y = NAME_PLATE_Y
	if visual.current == RIDE_CLIP:
		visual.current = ""
		visual.play("Idle")


## The HUD's "ขี่" / "ลง" button.
func toggle_ride() -> bool:
	if mount != null:
		dismount()
		return false
	return ride()


func _on_mount_changed() -> void:
	if mount == null:
		return
	var id := Game.active_mount()
	if id == "":
		dismount()
	elif id != mount.id:
		mount.build(id)


## Riding frame: the mount gallops under the seated rider, who follows its bob.
func _ride_step(speed: float) -> void:
	mount.rotation.y = _facing
	mount.set_motion(speed > 0.6, speed / maxf(move_speed(), 0.1))
	visual.set_wing_moving(false)
	visual.play(RIDE_CLIP, 0.2)
	visual.position = Vector3(0, mount.seat_height() - RIDE_HIP, 0) + Basis(Vector3.UP, _facing) * Vector3(0, 0, mount.seat.position.z)
	if visual.model != null:
		visual.model.rotation.x = 0.0
	if is_instance_valid(_name_plate):
		_name_plate.position.y = NAME_PLATE_Y + visual.position.y


## Wing pose from the HUD buttons (saved with the profile).
func set_wing_mode(mode: int) -> void:
	Game.profile.flags["wing_mode"] = mode
	Game.mark_dirty()
	visual.set_wing_mode(mode)


func _tick_timers(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	_since_hurt += delta
	if not cooldowns.is_empty():
		for id in cooldowns:
			cooldowns[id] = maxf(0.0, float(cooldowns[id]) - delta)
	var now := Time.get_ticks_msec()
	var expired := false
	for buff in _buffs:
		if buff.until <= now:
			expired = true
	if expired:
		_buffs = _buffs.filter(func(b): return b.until > now)
		refresh_stats()
	_sync_auras(now)
	# Regeneration: MP always, HP once out of combat (faster in the village).
	var hp_rate := 0.02 if safe_zone else (0.006 if _since_hurt > 4.0 else 0.0)
	var mp_rate := 0.05 if safe_zone else (0.02 if _since_hurt > 4.0 else 0.008)
	_regen_hp += float(stats.max_hp) * hp_rate * delta
	_regen_mp += float(stats.max_mp) * mp_rate * delta
	if _regen_hp >= 1.0:
		Game.profile.hp = mini(stats.max_hp, Game.profile.hp + int(_regen_hp))
		_regen_hp -= int(_regen_hp)
	if _regen_mp >= 1.0:
		Game.profile.mp = mini(stats.max_mp, Game.profile.mp + int(_regen_mp))
		_regen_mp -= int(_regen_mp)
	_gem_set_tick(delta)


func _read_move() -> Vector3:
	var v := move_input
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if v.length() < 0.05:
		return Vector3.ZERO
	v = v.limit_length(1.0)
	var basis := camera_rig.get_move_basis() if camera_rig else Basis.IDENTITY
	return (basis * Vector3(v.x, 0, v.y)).normalized() * v.length()


func _face(direction: Vector3, delta: float, rate := 12.0) -> void:
	if direction.length_squared() < 0.0001:
		return
	_facing = lerp_angle(_facing, atan2(direction.x, direction.z), 1.0 - exp(-rate * delta))
	visual.rotation.y = _facing


func _clamp_to_field() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	if field_hall.has_area() and field_hall.has_point(flat):
		return
	if flat.length() > field_radius:
		flat = flat.normalized() * field_radius
		global_position.x = flat.x
		global_position.z = flat.y


# ---------------------------------------------------------------------------
# Combat: approach, auto-attack, skills
# ---------------------------------------------------------------------------

func _valid_target(mob: Variant) -> bool:
	return mob != null and is_instance_valid(mob) and not (mob as Mob).is_dead()


func _target_dead() -> bool:
	return target != null and not _valid_target(target)


func _on_target_lost() -> void:
	target = null
	target_changed.emit(null)
	if engaged or not _pending.is_empty():
		var next := nearest_mob(12.0)
		if next:
			set_target(next)
		else:
			engaged = false
			_pending = {}


## Returns the desired velocity while fighting (approach / stand and attack).
func _combat_step(delta: float) -> Vector3:
	if safe_zone or not _valid_target(target):
		return Vector3.ZERO
	var attack: Dictionary = Game.class_data().attack
	var to := _flat(target.global_position - global_position)
	var distance := to.length() - target.body_radius()
	var want_range := float(attack.range)
	if not _pending.is_empty():
		want_range = _skill_range(_pending)
	if not engaged and _pending.is_empty():
		return Vector3.ZERO
	if distance > want_range:
		# In the castle siege the way to a target round the moat and walls goes by the
		# bridge and the gates (SiegeArena.route).
		var way := to
		if field is Zone and (field as Zone).gw_match != null:
			way = _flat(SiegeArena.route(global_position, target.global_position) - global_position)
		_face(way, delta, 16.0)
		return way.normalized() * float(stats.speed) * 1.05
	_face(to, delta, 20.0)
	if not _pending.is_empty():
		var skill: Dictionary = _pending
		_pending = {}
		_cast(skill)
	elif engaged and _attack_timer <= 0.0:
		_basic_attack()
	return Vector3.ZERO


func _skill_range(skill: Dictionary) -> float:
	if skill.shape == "burst":
		return float(_ranked(skill).radius) * 0.7
	return float(skill.get("range", 3.0))


func _basic_attack() -> void:
	var attack: Dictionary = Game.class_data().attack
	_attack_timer = float(attack.interval) * (1.0 - _haste())
	_since_hurt = minf(_since_hurt, 1.0)
	var anims: Array = attack.anims
	var clip: String = anims[_combo % anims.size()]
	_combo += 1
	var length := visual.action(clip, maxf(visual.anim.get_animation(clip).length / (float(attack.interval) * 0.9), 1.0) if visual.has_clip(clip) else 1.0)
	_cast_until = Time.get_ticks_msec() + int(float(attack.hit_delay) * 1000.0) + 60
	# The target is held weakly: it can be freed (a summon, a vanished fighter) before the hit lands.
	var mob_ref: WeakRef = weakref(target)
	var delay := float(attack.hit_delay)
	var color: Color = attack.get("color", Color.WHITE)
	AudioManager.play_sfx(&"hit_physical" if not bool(attack.projectile) else &"hit_special", -6.0)
	if bool(attack.projectile):
		get_tree().create_timer(delay).timeout.connect(func():
			var mob: Mob = mob_ref.get_ref() as Mob
			if not _valid_target(mob) or _dead:
				return
			var from := global_position + Vector3(0, 1.3, 0) + Vector3(sin(_facing), 0, cos(_facing)) * 0.6
			var to := mob.hit_point()
			var flight := clampf(from.distance_to(to) / 22.0, 0.1, 0.5)
			if Game.class_id() == &"archer":
				VfxKit.arrow(field, color, from, to, flight)
			else:
				VfxKit.projectile(field, color, from, to, flight, 0.3, VfxKit.variant_for(attack.vfx))
			get_tree().create_timer(flight).timeout.connect(func():
				_deal(mob_ref.get_ref() as Mob, float(attack.mult), color, attack.vfx, false)
			, CONNECT_ONE_SHOT)
		, CONNECT_ONE_SHOT)
	else:
		get_tree().create_timer(delay).timeout.connect(func():
			var mob: Mob = mob_ref.get_ref() as Mob
			if _dead or not _valid_target(mob):
				return
			VfxKit.slash_arc(field, global_position + Vector3(sin(_facing), 0, cos(_facing)) * 1.1 + Vector3(0, 1.0, 0), _facing, Color("fff2d0"), 2.0,
					[0.5, -0.5, 0.0][_combo % 3])
			_deal(mob, float(attack.mult), Color.WHITE, attack.vfx, true)
		, CONNECT_ONE_SHOT)


func rank_mult(skill: Dictionary) -> float:
	return SkillRank.power(Game.effective_rank(skill))


func mp_cost(skill: Dictionary) -> int:
	return int(ceil(float(skill.mp) * SkillRank.mp_scale(Game.effective_rank(skill)) * (0.88 if StarProgression.has_full_set(Game.profile, "mage") else 1.0)))


func cooldown_of(skill: Dictionary) -> float:
	return SkillRank.cooldown(skill, Game.effective_rank(skill)) * (1.0 - _haste()) * (1.0 - float(stats.get("cdr", 0.0)))


## Share of time DEX cuts from cooldowns, wind-ups and the basic attack interval.
func _haste() -> float:
	return float(stats.get("haste", 0.0))


## The skill as cast at its star rank: area, targets, heal, buffs and control grown.
func _ranked(skill: Dictionary) -> Dictionary:
	return SkillRank.scaled(skill, Game.effective_rank(skill))


func cooldown_ratio(skill: Dictionary) -> float:
	return clampf(float(cooldowns.get(skill.id, 0.0)) / maxf(cooldown_of(skill), 0.1), 0.0, 1.0)


## Skill button pressed. Returns "" when started, otherwise why not.
func use_skill(index: int) -> String:
	if _dead or safe_zone:
		return "safe"
	dismount()
	var skills: Array = Game.class_data().skills
	var skill: Dictionary = skills[index] if index >= 0 and index < skills.size() else {}
	if skill.is_empty():
		return "none"
	if not Game.skill_unlocked(skill):
		message.emit(Game.skill_lock_reason(skill))
		return "locked"
	if float(cooldowns.get(skill.id, 0.0)) > 0.0:
		return "cooldown"
	if Time.get_ticks_msec() < _cast_until: return "casting"
	if bool(skill.get("requires_wings", false)) and not visual.has_wings():
		message.emit("ต้องสวมปีกก่อนใช้สกิลนี้")
		return "wings"
	if int(Game.profile.mp) < mp_cost(skill):
		message.emit("MP ไม่พอ!")
		return "mp"
	if skill.shape == "self" or skill.shape == "summon":
		_cast(skill)
		return ""
	if not _valid_target(target):
		set_target(nearest_mob())
	if target == null:
		message.emit("ไม่มีมอนสเตอร์อยู่ใกล้ๆ")
		return "target"
	_pending = skill
	return ""


func _cast(skill: Dictionary) -> void:
	if _dead or Time.get_ticks_msec() < _cast_until: return
	if not Game.skill_unlocked(skill) or float(cooldowns.get(skill.id,0.0)) > 0.0: return
	if bool(skill.get("requires_wings",false)) and not visual.has_wings(): return
	var cost := mp_cost(skill)
	if int(Game.profile.mp) < cost:
		return
	Game.profile.mp -= cost
	last_cast_id=String(skill.id)
	cooldowns[skill.id] = cooldown_of(skill)
	_since_hurt = minf(_since_hurt, 1.0)
	skill_fired.emit(Game.class_data().skills.find(skill))
	skill = _ranked(skill)
	if skill.has("star"):
		if _valid_target(target): _face(_flat(target.global_position-global_position), 1.0, 60.0)
		var star_aim := target.global_position if _valid_target(target) else global_position
		var star_duration := StarSkillSequence.launch(self, skill, target, star_aim)
		_cast_until = Time.get_ticks_msec() + int(star_duration * 1000.0)
		AudioManager.play_sfx(SkillSound.cast(skill), -5.0)
		Game.daily_progress("skills", 1)
		return
	var delay := float(skill.hit_delay) * (1.0 - _haste())
	visual.skill_action(skill, delay)
	_cast_until = Time.get_ticks_msec() + int(delay * 1000.0) + 90
	if target and _valid_target(target):
		_face(_flat(target.global_position - global_position), 1.0, 60.0)
	AudioManager.play_sfx(SkillSound.cast(skill), -4.0)
	Game.daily_progress("skills", 1)
	var snapshot: WeakRef = weakref(target) if is_instance_valid(target) else null
	var aim := target.global_position if _valid_target(target) else global_position + Vector3(sin(_facing), 0, cos(_facing)) * 4.0
	var color: Color = skill.color
	# Wind-up effect while the cast animation plays.
	SkillShow.anticipate(field, skill, global_position, delay, aim, visual)
	if String(skill.id) == "judgment_ray":
		JudgmentRaySequence.launch(field, self, target, delay, _judgment_hit.bind(skill), visual)
		return
	if skill.shape == "blast":
		var landing := 0.55 if String(skill.get("special", "")) in ["meteor", "rain"] else 0.0
		SkillInk.telegraph(field, skill, Vector3(aim.x, global_position.y, aim.z), float(skill.radius), delay + landing)
	elif skill.shape == "burst":
		SkillInk.telegraph(field, skill, global_position, float(skill.radius), delay)
	# Bind the wind-up to this hero; leaving a zone discards unfinished casts.
	var cast := create_tween()
	cast.tween_interval(delay)
	cast.tween_callback(_finish_cast.bind(skill, snapshot, aim, weakref(field)))


func _finish_cast(skill: Dictionary, target_ref: WeakRef, aim: Vector3, field_ref: WeakRef) -> void:
	var cast_field := field_ref.get_ref() as Node3D
	if _dead or not is_instance_valid(cast_field) or cast_field != field or cast_field.is_queued_for_deletion():
		return
	var mob := target_ref.get_ref() as Mob if target_ref != null else null
	_resolve(skill, mob, aim)


func _resolve(skill: Dictionary, mob: Mob, aim: Vector3) -> void:
	if _dead or not is_instance_valid(field) or field.is_queued_for_deletion():
		return
	if String(skill.id) == "judgment_ray":
		JudgmentRaySequence.launch(field, self, mob, 0.001, _judgment_hit.bind(skill))
		return
	var color: Color = skill.color
	var mult: float = float(skill.get("mult", 0.0)) * rank_mult(skill)
	var origin := visual.skill_emission_position()
	var forward := Vector3(sin(_facing), 0, cos(_facing))
	var show_center := global_position
	if String(skill.shape) in ["single", "chain", "fan"] and _valid_target(mob):
		show_center = mob.global_position
	elif String(skill.shape) == "blast":
		show_center = Vector3(mob.global_position.x if _valid_target(mob) else aim.x, 0.0, mob.global_position.z if _valid_target(mob) else aim.z)
	if String(skill.id) not in ["armageddon", "thunder_storm"]:
		SkillShow.play(field, skill, show_center, global_position)
	var landing_sound := SkillSound.landing(skill)
	if landing_sound != &"":
		AudioManager.play_sfx(landing_sound, -2.0)
	match String(skill.shape):
		"self":
			_apply_self_fx(skill)
		"summon":
			_summon(skill, mult)
		"single":
			if not _valid_target(mob):
				return
			if bool(skill.get("projectile", false)):
				_shoot(skill, mob, mult, origin, 1.0)
			else:
				_deal(mob, mult, color, skill.vfx, true, skill)
				if skill.has("pierce"):
					var spec: Dictionary = skill.pierce
					var tip := mob.global_position + Vector3(0, 1.0, 0)
					VfxKit.arrow(field, color, origin, tip + (tip - origin).normalized() * float(spec.get("len", 6.0)) * 0.6, 0.28)
					for extra in Pierce.victims(get_tree(), global_position, mob.global_position, spec, mob):
						_deal(extra, mult * float(spec.get("k", 0.7)), color, skill.vfx, true, skill)
		"fan":
			var list := mobs_in_range(float(skill.range))
			if _valid_target(mob):
				list.erase(mob)
				list.push_front(mob)
			var count := int(skill.hits)
			for i in mini(count, maxi(list.size(), 1)):
				var victim: Mob = list[i] if i < list.size() else mob
				if _valid_target(victim):
					_shoot(skill, victim, mult, origin, 1.0)
			if list.is_empty():
				for i in count:
					var angle := (i - 1) * 0.25
					VfxKit.arrow(field, color, origin, origin + forward.rotated(Vector3.UP, angle) * 9.0, 0.3)
		"chain":
			var hit: Array[Mob] = []
			var current := mob
			var from := origin
			for i in int(skill.hits):
				if not _valid_target(current):
					break
				SkillTableau.link(field, skill, from, current.hit_point())
				_deal(current, mult * pow(0.85, i), color, skill.vfx, true, skill)
				hit.append(current)
				from = current.hit_point()
				var next: Mob = null
				var best := 7.0
				for node in get_tree().get_nodes_in_group("mobs"):
					var other := node as Mob
					if other and not other.is_dead() and not hit.has(other):
						var d := (other.global_position - current.global_position).length()
						if d < best:
							best = d
							next = other
				current = next
		"burst":
			var radius := float(skill.radius)
			var hits := 0
			for victim in mobs_in_range(radius + 0.6):
				_deal(victim, mult, color, skill.vfx, true, skill)
				hits += 1
			if skill.get("fx", {}).has("heal"):
				_heal(float(skill.fx.heal))
		"blast":
			var center := Vector3(aim.x, 0.0, aim.z)
			if _valid_target(mob):
				center = Vector3(mob.global_position.x, 0.0, mob.global_position.z)
			var radius := float(skill.radius)
			if String(skill.id) == "thunder_storm":
				ThunderStormSequence.launch(field, self, center, radius, _storm_candidates, _storm_hit.bind(skill, mult))
			elif String(skill.id) == "armageddon":
				ArmageddonSequence.launch(field, self, center, radius, mult, _armageddon_impact.bind(skill))
			elif skill.get("special", "") == "meteor":
				VfxKit.meteor(field, center, color, 0.55, radius, func(): _blast_damage(skill, center, radius, mult), String(skill.id) == "hell_meteor")
			elif skill.get("special", "") == "rain":
				_arrow_rain(skill, center, radius, mult)
			else:
				_blast_damage(skill, center, radius, mult)


func _judgment_hit(victim: Node3D, skill: Dictionary) -> void:
	if victim is Mob and _valid_target(victim):
		_deal(victim, float(skill.mult) * rank_mult(skill), skill.color, skill.vfx, true, skill)


func _shoot(skill: Dictionary, mob: Mob, mult: float, from: Vector3, scale: float) -> void:
	var color: Color = skill.color
	var to := mob.hit_point()
	var flight := clampf(from.distance_to(to) / 20.0, 0.12, 0.6)
	SkillTableau.flight(field, skill, from, to, flight, scale)
	var mob_ref: WeakRef = weakref(mob)
	get_tree().create_timer(flight).timeout.connect(func():
		if _dead:
			return
		var victim: Mob = mob_ref.get_ref() as Mob
		if _valid_target(victim):
			if skill.get("special", "") == "boom":
				VfxKit.shockwave(field, victim.global_position + Vector3(0, 0.15, 0), color, 2.2)
			_deal(victim, mult, color, skill.vfx, true, skill)
	, CONNECT_ONE_SHOT)


func _armageddon_impact(index: int, center: Vector3, radius: float, mult: float, skill: Dictionary) -> void:
	if _dead or not is_instance_valid(field) or field.is_queued_for_deletion():
		return
	# The main impact knocks enemies back. Repeated fragments do not push them
	# out of their own damage areas, but still apply damage, crits and burn.
	_blast_damage(skill, center, radius, mult, index == 0)


func _blast_damage(skill: Dictionary, center: Vector3, radius: float, mult: float, knockback := true) -> void:
	for node in get_tree().get_nodes_in_group("mobs"):
		var victim := node as Mob
		if victim and not victim.is_dead() and _flat(victim.global_position - center).length() <= radius + victim.body_radius():
			_deal(victim, mult, skill.color, skill.vfx, knockback, skill)


func _arrow_rain(skill: Dictionary, center: Vector3, radius: float, mult: float) -> void:
	var color: Color = skill.color
	for i in 14:
		var angle := randf() * TAU
		var spot := center + Vector3(cos(angle), 0, sin(angle)) * randf() * radius
		get_tree().create_timer(i * 0.07).timeout.connect(func():
			VfxKit.arrow(field, color, spot + Vector3(1.5, 12.0, 0.5), spot + Vector3(0, 0.2, 0), 0.28)
		, CONNECT_ONE_SHOT)
	get_tree().create_timer(0.55).timeout.connect(func():
		if _dead:
			return
		_blast_damage(skill, center, radius, mult)
	, CONNECT_ONE_SHOT)


## Calls the skill's creatures (replacing the same skill's earlier ones; at most 5 in all).
func _summon(skill: Dictionary, mult: float) -> void:
	var spec: Dictionary = skill.summon
	_summons = _summons.filter(func(s): return is_instance_valid(s))
	for old in _summons.duplicate():
		if old.skill_id == skill.id:
			old.queue_free()
			_summons.erase(old)
	var count := SkillRank.summon_count(skill, Game.effective_rank(skill))
	for i in count:
		var s := Summon.new()
		s.setup(self, String(skill.id), spec, mult * HeroStats.SKILL_POWER, i, count, maxi(1, Game.effective_rank(skill)))
		field.add_child(s)
		_summons.append(s)
	while _summons.size() > 5:
		var oldest: Summon = _summons.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.7, 0), String(skill.name), skill.color, 0.6)


func _summons_alive(skill_id: String) -> int:
	var n := 0
	for s in _summons:
		if is_instance_valid(s) and s.skill_id == skill_id:
			n += 1
	return n


## The Bard's full star set: its songs ring this much stronger for everyone they reach.
const SONG_SET_BOOST := 1.15


func _apply_self_fx(skill: Dictionary) -> void:
	var fx: Dictionary = skill.get("fx", {})
	var color: Color = skill.color
	if fx.has("recall"):
		recall_party()
	if fx.has("heal"):
		# A stance (self_only) keeps its heal to the caster too.
		_heal(float(fx.heal), not (fx.get("buff") is Dictionary and BuffBook.is_self_only(fx.buff)))
	if fx.has("buff"):
		var buff: Dictionary = fx.buff
		if BuffBook.is_song(buff) and StarProgression.has_full_set(Game.profile, "bard"):
			buff = BuffBook.boost_song(buff, SONG_SET_BOOST)
		receive_buff(buff, color, String(skill.name), false, String(skill.id))
		# A stance (self_only) is the caster's own; every other buff reaches the team.
		if not BuffBook.is_self_only(buff):
			_share_buff(buff, color, String(skill.name), String(skill.id))


# --- The Dark Lord's raven and Summon -----------------------------------------

## One raven strike: a share of the Lord's attack (the star set makes it hit harder).
const RAVEN_MULT := 0.8
## Single mode strikes harder; a group strike lands this share on each of the pack.
const SINGLE_FOCUS := 1.25
const GROUP_SHARE := 0.6
var raven: DarkRaven
## Raven strikes so far (tests and the playtest tool read it).
var raven_strikes := 0


## A Dark Lord has a raven on the arm; any other class does not.
func _sync_raven() -> void:
	if Game.class_id() == &"darklord":
		raven = DarkRaven.ensure(self)
		raven.attack = bool(int(Game.profile.flags.get("raven_attack", 1)))
		raven.mode = clampi(int(Game.profile.flags.get("raven_mode", DarkRaven.Mode.AUTO)), 0, 2)
	elif raven != null:
		DarkRaven.remove(self)
		raven = null


## The raven button: sends the raven at the hero's target (it then picks fights on
## its own) or calls it back to the arm. Remembered with the character.
func set_raven_attack(on: bool) -> void:
	if raven == null:
		return
	raven.attack = on
	Game.profile.flags["raven_attack"] = 1 if on else 0
	if not on and raven.state != DarkRaven.State.PERCH:
		raven.state = DarkRaven.State.RETURN


## The raven mode button: single, group or auto (DarkRaven.Mode), remembered.
func set_raven_mode(value: int) -> void:
	if raven == null:
		return
	raven.mode = clampi(value, 0, 2)
	Game.profile.flags["raven_mode"] = raven.mode


## Single and group: the hero's target, else the monster nearest the hero (the
## fight it is in). Auto: the raven's own prey, the monster nearest the raven
## anywhere around the hero.
func raven_target() -> Mob:
	var own := raven != null and raven.mode == DarkRaven.Mode.AUTO
	if not own and _valid_target(target) and _flat(target.global_position - global_position).length() <= 16.0:
		return target
	var from := raven.global_position if own and raven.is_inside_tree() else global_position
	var best: Mob = null
	var best_d := 1.0e9
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and _valid_target(mob) and mob.hostile:
			var reach := _flat(mob.global_position - global_position).length()
			if reach > (14.0 if own else 8.0):
				continue
			var d := _flat(mob.global_position - from).length()
			if d < best_d:
				best_d = d
				best = mob
	return best


## One raven strike: a single focused strike, or (group) a share of it on every
## monster around the one it dives on.
func raven_strike(mob: Mob, group := false) -> void:
	if not _valid_target(mob):
		return
	var mult := RAVEN_MULT * (1.3 if StarProgression.has_full_set(Game.profile, "darklord") else 1.0)
	raven_strikes += 1
	if group:
		for other in DarkRaven.pack(get_tree(), mob.global_position, DarkRaven.GROUP_RADIUS):
			_deal(other, mult * GROUP_SHARE, DarkRaven.VIOLET, &"slash", false)
		return
	if raven != null and raven.mode == DarkRaven.Mode.SINGLE:
		mult *= SINGLE_FOCUS
	_deal(mob, mult, DarkRaven.VIOLET, &"slash", false)


## Summon (MU Online): every party member is pulled to the hero's side at once,
## with a flash where each one left and where it arrives.
func recall_party() -> void:
	var k := 0
	for node in get_tree().get_nodes_in_group("companions"):
		var ally := node as Node3D
		if not is_instance_valid(ally) or ally.is_queued_for_deletion():
			continue
		# In a guild war the player's Summon gathers its own party, not the whole guild.
		if not GuildWarMatch.buff_reaches(self, ally):
			continue
		var angle := _facing + PI + (float(k) - 1.5) * 0.7
		var spot := global_position + Vector3(sin(angle), 0, cos(angle)) * 2.2
		VfxKit.flash(field, ally.global_position + Vector3(0, 1.0, 0), Color("b06bff"), 1.6)
		ally.global_position = spot + Vector3(0, 0.3, 0)
		VfxKit.flash(field, spot + Vector3(0, 1.0, 0), Color("ffd36b"), 1.8)
		VfxKit.shockwave(field, spot + Vector3(0, 0.1, 0), Color("8a4dff"), 1.8)
		k += 1
	VfxKit.shockwave(field, global_position + Vector3(0, 0.1, 0), Color("ffd36b"), 4.0)


## Buff skills reach the whole team: companions and summoned creatures get them too
## (in a guild war only the hero's own party and its summons: GuildWarMatch.buff_reaches).
func _share_buff(buff: Dictionary, color: Color, label: String, skill_id := "") -> void:
	for node in get_tree().get_nodes_in_group("companions") + get_tree().get_nodes_in_group("summons"):
		if is_instance_valid(node) and node.has_method("receive_party_buff") and not node.is_dead() and GuildWarMatch.buff_reaches(self, node):
			node.receive_party_buff(buff, color, label, skill_id)


## A buff from a skill or from a companion: {atk, def, speed, crit, secs}.
func receive_buff(buff_data: Dictionary, color: Color, label := "", from_ally := false, skill_id := "") -> void:
	var prepared := buff_data.duplicate()
	if prepared.has("shield"): prepared["shield_left"] = int(float(stats.max_hp)*float(prepared.shield))
	_buffs = BuffBook.insert(_buffs, prepared, color, label, from_ally, skill_id)
	refresh_stats()
	_sync_auras(Time.get_ticks_msec())
	# Persistent buff halo and the skill silhouette carry this feedback.
	if label != "":
		BattleVfx.floating_text(field, global_position + Vector3(0, 2.7, 0), label, color, 0.6)
	AudioManager.play_sfx(&"buff")


## Healing from a companion.
func receive_heal(fraction: float) -> void:
	_heal(fraction)


func _heal(fraction: float, share := true) -> void:
	var amount := int(float(stats.max_hp) * fraction * (1.2 if StarProgression.has_full_set(Game.profile,"priest") else 1.0))
	var before: int = Game.profile.hp
	Game.profile.hp = mini(stats.max_hp, Game.profile.hp + amount)
	VfxKit.heal(field, global_position)
	BattleVfx.floating_text(field, global_position + Vector3(0, 2.6, 0), "+%d" % (Game.profile.hp - before), Color("6dff9a"), 1.0)
	for node in get_tree().get_nodes_in_group("companions"):
		if share and node.has_method("heal_fraction") and node.global_position.distance_to(global_position) < 9.0:
			node.heal_fraction(fraction * 0.6)
	AudioManager.play_sfx(&"heal")


## Applies one hit: damage roll, crit, mitigation, skill effects, juice.
func _deal(mob: Mob, mult: float, color: Color, vfx: StringName, melee: bool, skill := {}) -> void:
	if not _valid_target(mob):
		return
	var raw := float(stats.atk) * mult * randf_range(0.92, 1.08) * (1.0 - _enemy_mark("weaken")) * gem_atk_mult()
	if not skill.is_empty():
		raw *= HeroStats.SKILL_POWER
	if _star_retaliation and not skill.is_empty() and StarProgression.has_full_set(Game.profile,"warrior"):
		raw *= 1.2
		_star_retaliation = false
	if StarProgression.has_full_set(Game.profile,"archer"):
		if _star_combo_target != mob.get_instance_id(): _star_combo_target=mob.get_instance_id(); _star_combo_count=0
		_star_combo_count+=1
		if _star_combo_count>=6: raw*=1.25; _star_combo_count=0
	var crit := randf() < float(stats.crit)
	if crit:
		raw *= crit_mult()
		if StarProgression.has_full_set(Game.profile,"assassin"):
			raw *= 1.1
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(mob.stats.def)))))
	if skill.has("star"):
		pass # StarSkillSequence owns exactly one authored impact per contact beat.
	elif not skill.is_empty():
		SkillTableau.contact(field, skill, mob.hit_point(), crit)
	else:
		VfxKit.impact(field, mob.hit_point(), color if color != Color.WHITE else Color("fff0c0"), 1.4 if crit else 1.0)
	var killed := mob.take_hit(amount, crit, color)
	_leech(amount)
	AudioManager.play_sfx(&"crit" if crit else &"hit_physical", -3.0)
	var stop := HitFeel.stop_for(crit, mult if not skill.is_empty() else 0.0)
	if stop > 0.0:
		HitFeel.hitstop(get_tree(), stop)
	HitFeel.debris(field, mob.hit_point(), skill)
	if killed:
		return
	if melee:
		mob.knock_back(global_position, 3.0)
	var fx: Dictionary = skill.get("fx", {})
	if fx.has("repel"):
		mob.shove_out(global_position, Mob.REPEL_DISTANCE)
	if fx.has("stun"):
		mob.apply_stun(float(fx.stun))
	if fx.has("slow"):
		mob.apply_slow(float(fx.slow))
	if fx.has("burn"):
		mob.apply_burn(HeroStats.burn_dps(float(stats.atk) * rank_mult(skill), float(fx.burn[0]), float(mob.stats.def)), float(fx.burn[1]))
		mob.burn_source = self
	if fx.has("taunt") and mob.has_method("taunt"):
		mob.taunt(self, float(fx.taunt))
	# Marks (the Bard, Death Mark, star skills): armour cracked, strength sapped.
	if fx.get("shred") is Array:
		mob.apply_shred(float(fx.shred[0]), float(fx.shred[1]))
	if fx.get("weaken") is Array:
		mob.apply_weaken(float(fx.weaken[0]), float(fx.weaken[1]))


# ---------------------------------------------------------------------------
# Taking damage, dying
# ---------------------------------------------------------------------------

## A boss move chills / mires the hero: walking speed drops for [param seconds].
func apply_slow(seconds: float) -> void:
	if _dead:
		return
	if Time.get_ticks_msec() >= _slow_until:
		BattleVfx.floating_text(field, global_position + Vector3(0, 2.7, 0), "ช้าลง!", Color("9fe8ff"), 0.9)
	_slow_until = maxi(_slow_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func take_damage(raw: float, _attacker: Node = null) -> void:
	if _dead or Time.get_ticks_msec() < _invulnerable_until or safe_zone:
		return
	if randf() < float(stats.dodge):
		BattleVfx.floating_text(field, global_position + Vector3(0, 2.4, 0), "หลบ!", Color("9fe8ff"), 0.9)
		return
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, effective_def()))))
	amount = BuffBook.absorb(_buffs, amount)
	_reflect(amount, _attacker)
	if StarProgression.has_full_set(Game.profile,"warrior"):
		amount=int(ceil(amount*0.9))
		_star_retaliation=true
	Game.profile.hp = maxi(0, Game.profile.hp - amount)
	_since_hurt = 0.0
	dismount()
	BattleVfx.damage_number(field, global_position + Vector3(0, 2.4, 0), str(amount), true, 1.1)
	visual.flash()
	AudioManager.play_sfx(&"hit_special", -2.0)
	if Time.get_ticks_msec() >= _cast_until:
		visual.action("Hit_A", 1.2)
	if Game.profile.hp <= 0:
		_die()


## DEF the hero mitigates with: lower while an enemy Bard's armour crack is on it.
func effective_def() -> float:
	return float(stats.def) * (1.0 - _enemy_mark("shred")) * gem_def_mult()


# ---------------------------------------------------------------------------
# Gem abilities (special gems and 12-gem sets, HeroStats.compute)
# ---------------------------------------------------------------------------

## Crit multiplier of the hero's hits: HeroStats.CRIT_DAMAGE plus onyx gems (crit_dmg).
func crit_mult() -> float:
	return HeroStats.CRIT_DAMAGE + float(stats.get("crit_dmg", 0.0))


func _hp_rate() -> float:
	return float(Game.profile.hp) / maxf(float(stats.get("max_hp", 1)), 1.0)


## Ruby set (เลือดเดือด): ATK ×(1 + GEM_SET_FURY) while HP is under FURY_HP.
func gem_atk_mult() -> float:
	if String(stats.get("gem_set", "")) == "ruby" and Game.profile.hp > 0 and _hp_rate() < FURY_HP:
		return 1.0 + HeroStats.GEM_SET_FURY
	return 1.0


## Amethyst set (ป้อมปราการ): DEF ×(1 + GEM_SET_BULWARK) while HP is under BULWARK_HP.
func gem_def_mult() -> float:
	if String(stats.get("gem_set", "")) == "amethyst" and Game.profile.hp > 0 and _hp_rate() < BULWARK_HP:
		return 1.0 + HeroStats.GEM_SET_BULWARK
	return 1.0


## Pearl gems: the hero heals by its share (lifesteal) of the damage it deals.
## Fractions carry over; the green "+N" is throttled to one every LEECH_TEXT_MS.
func _leech(dealt: int) -> void:
	var share := float(stats.get("lifesteal", 0.0))
	if share <= 0.0 or dealt <= 0 or _dead:
		return
	_leech_left += float(dealt) * share
	if _leech_left < 1.0:
		return
	var heal := int(_leech_left)
	_leech_left -= float(heal)
	var before: int = Game.profile.hp
	Game.profile.hp = mini(int(stats.max_hp), before + heal)
	_leech_unshown += Game.profile.hp - before
	var now := Time.get_ticks_msec()
	if _leech_unshown >= 1 and now - _leech_text_at >= LEECH_TEXT_MS and is_instance_valid(field):
		_leech_text_at = now
		BattleVfx.floating_text(field, global_position + Vector3(0, 2.3, 0), "+%d" % _leech_unshown, Color("6dff9a"), 0.7)
		_leech_unshown = 0


## The worn gem set at work: fury / bulwark switch on and off with HP (a Thai note
## when one switches on, at most every GEM_NOTE_MS), emerald heals in combat and
## sapphire restores MP on their periods. Topaz lives in HeroStats.compute.
func _gem_set_tick(delta: float) -> void:
	var gem_set := String(stats.get("gem_set", ""))
	var fury := gem_atk_mult() > 1.0
	if fury and not _fury_on:
		_gem_note("ruby", "เลือดเดือด! พลังโจมตี +%d%%" % int(round(HeroStats.GEM_SET_FURY * 100.0)), Color("ff4a5a"))
	_fury_on = fury
	var bulwark := gem_def_mult() > 1.0
	if bulwark and not _bulwark_on:
		_gem_note("amethyst", "ป้อมปราการ! พลังป้องกัน +%d%%" % int(round(HeroStats.GEM_SET_BULWARK * 100.0)), Color("c46bff"))
	_bulwark_on = bulwark
	var period := EMERALD_PERIOD if gem_set == "emerald" else (SAPPHIRE_PERIOD if gem_set == "sapphire" else 0.0)
	# Emerald heals only in combat (hit or attacking in the last few seconds).
	if period <= 0.0 or (gem_set == "emerald" and (safe_zone or _since_hurt > 4.0)):
		_gem_regen_time = 0.0
		return
	_gem_regen_time += delta
	if _gem_regen_time < period:
		return
	_gem_regen_time -= period
	if gem_set == "emerald":
		var before: int = Game.profile.hp
		Game.profile.hp = mini(int(stats.max_hp), before + maxi(1, int(float(stats.max_hp) * GEM_REGEN_SHARE)))
		if Game.profile.hp > before and is_instance_valid(field):
			BattleVfx.floating_text(field, global_position + Vector3(0, 2.3, 0), "+%d" % (Game.profile.hp - before), Color("4ae07a"), 0.7)
	else:
		Game.profile.mp = mini(int(stats.max_mp), Game.profile.mp + maxi(1, int(float(stats.max_mp) * GEM_REGEN_SHARE)))


func _gem_note(gem_set: String, text: String, color: Color) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_gem_note_at.get(gem_set, -GEM_NOTE_MS)) < GEM_NOTE_MS:
		return
	_gem_note_at[gem_set] = now
	if is_instance_valid(field):
		BattleVfx.floating_text(field, global_position + Vector3(0, 2.9, 0), text, color, 0.9)


## The strength of an enemy mark on the hero right now (0 once it ran out).
func _enemy_mark(key: String) -> float:
	var now := Time.get_ticks_msec()
	if key == "shred":
		return _enemy_shred if now < _enemy_shred_until else 0.0
	if key == "weaken":
		return _enemy_weaken if now < _enemy_weaken_until else 0.0
	return 0.0


## Seconds left of an enemy mark on the hero (enemy Bards do not mark it twice).
func debuff_left(key: String) -> float:
	var until := _enemy_shred_until if key == "shred" else (_enemy_weaken_until if key == "weaken" else 0)
	return maxf(0.0, float(until - Time.get_ticks_msec()) / 1000.0)


## An enemy Bard's mark (arena rival, guild fighter; monsters never mark): a player
## feels half of it for 40% of the time, the stronger mark wins, and it wears off on
## its own (a new zone builds a new hero).
func apply_enemy_debuff(key: String, fraction: float, seconds: float) -> void:
	if _dead or safe_zone or not (key in Mob.MARKS):
		return
	var cap := Mob.SHRED_CAP if key == "shred" else Mob.WEAKEN_CAP
	var f := clampf(fraction, 0.0, cap) * Mob.PLAYER_MARK
	if f <= 0.0 or seconds <= 0.0:
		return
	var current := _enemy_mark(key)
	if f + 0.0001 < current:
		return
	var now := Time.get_ticks_msec()
	var until := now + int(seconds * Mob.PLAYER_MARK_TIME * 1000.0)
	if key == "shred":
		_enemy_shred = f
		_enemy_shred_until = maxi(_enemy_shred_until, until)
	else:
		_enemy_weaken = f
		_enemy_weaken_until = maxi(_enemy_weaken_until, until)
	if f > current + 0.0001 and now - int(_mark_word_at.get(key, -100000)) >= 1200 and Mob.mark_word_ok():
		_mark_word_at[key] = now
		var word: Array = Mob.MARK_WORDS[key]
		BattleVfx.floating_text(field, global_position + Vector3(0, 2.35 + float(word[2]), 0), String(word[0]), word[1], 0.7)
		visual.flash(word[1], 0.25)


## Thorn buffs (the Defender's Thorn Guard, Unbreakable): a share of the damage
## taken goes back to the attacker. Reflected damage never reflects again, and
## against players (rivals, guild fighters) it is halved.
func _reflect(taken: int, attacker: Node) -> void:
	var share := BuffBook.reflect(_buffs)
	if share <= 0.0 or attacker == null or not is_instance_valid(attacker) or not attacker.has_method("take_hit"):
		return
	if attacker.has_method("is_dead") and attacker.is_dead():
		return
	if attacker is Rival:
		share *= 0.5
	var back := maxi(1, int(round(float(taken) * share)))
	attacker.take_hit(back, false, Color("ffb46a"), null)
	if attacker is Node3D:
		VfxKit.sparks(field, (attacker as Node3D).global_position + Vector3(0, 1.0, 0), Color("ffb46a"), 8, 3.0, 0.35)
		_reflect_flash(attacker as Node3D)


## The mirror on the shield: a flash at the great shield and a spark lane racing
## back to the attacker. Rate-limited so a crowd of hits stays one flash.
func _reflect_flash(attacker: Node3D) -> void:
	var now := Time.get_ticks_msec()
	if now - _reflect_ms < 150 or not is_instance_valid(visual) or not VfxBudget.can_decorate(3):
		return
	_reflect_ms = now
	var shield := visual.skill_emission_position()
	VfxKit.flash(field, shield, Color("fff1c8"), 1.6, 0.18)
	VfxArt.star_flash(field, shield, Color("ffd27a"), 1.5, 0.3)
	ClassFlourish._lance_streak(field, shield, attacker.global_position + Vector3.UP, Color("ffb46a"), Color("fff1c8"), 0.5, 0.3)


func _die() -> void:
	if _dead:
		return
	_dead = true
	dismount()
	_enemy_shred_until = 0
	_enemy_weaken_until = 0
	set_auto(false)
	engaged = false
	_pending = {}
	set_target(null)
	visual.hold_last_frame("Death_A")
	AudioManager.play_sfx(&"faint")
	Game.profile["deaths"] = int(Game.profile.get("deaths", 0)) + 1
	died.emit()


func revive() -> void:
	_dead = false
	visual.release()
	visual.play("Idle")
	_invulnerable_until = Time.get_ticks_msec() + 2500


func level_up_fx() -> void:
	VfxKit.level_up(field, global_position)
	BattleVfx.floating_text(field, global_position + Vector3(0, 3.0, 0), "เลเวลอัป!", Color("ffe27a"), 1.5)
	AudioManager.play_sfx(&"level_up")


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v


## Saves from before the character creator have no look: they get the boy model.
func _look() -> Dictionary:
	var look: Dictionary = Game.profile.get("look", {})
	return look if look.has("gender") else {"gender": 0}


func _storm_candidates() -> Array:
	return get_tree().get_nodes_in_group("mobs")

func _storm_hit(victim: Node3D, skill: Dictionary, mult: float) -> void:
	if victim is Mob and not victim.is_dead():
		_deal(victim, mult, skill.color, skill.vfx, false, skill)
