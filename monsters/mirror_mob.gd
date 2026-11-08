class_name MirrorMob
extends Mob
## A monster of a party member's game (the zone host's, EntitySync) shown in this one:
## the same model, height, tint and aura as the real one (MonsterData), but no AI and no
## physics of its own. It glides to where the host's snapshots put it, its HP bar follows
## the host's HP, it draws the host's telegraphs (mirror_cast) and it plays the boss
## phases. Everything that targets monsters finds it in the group "mobs" like any Mob;
## a hit on it goes to the host as `ent_hit` (the damage number shows here at once), a
## stun, slow, burn, mark or taunt too. It dies only when the host says so (mirror_dead):
## then Mob._die pays this game's EXP and loot through the zone, as if the hero had
## killed it, but only when this game earned it (EntitySync.earns: the hero's side or a
## party member here dealt damage). A new host made of this game turns it into a real Mob
## (EntitySync._take_over).

var eid := 0
var sync: EntitySync
## "" (a field monster), "field_boss", "world_boss" or "golden".
var kind := ""
var goal := Vector3.ZERO
var goal_yaw := 0.0
var flags := 0
## Damage the hero's side dealt to it here (sent to the host as ent_hit).
var dealt := 0
var _acting := false
## 1 when this game rolls the kill's reward, 0 when it took no part (mirror_dead).
var _reward := 1.0


func setup_mirror(p_sync: EntitySync, p_eid: int, d: Dictionary, p_hero: Node3D) -> void:
	sync = p_sync
	eid = p_eid
	var at := Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0)))
	setup(StringName(String(d.get("m", "pink_slime"))), clampi(int(d.get("lv", 1)), 1, 999), at, p_hero)
	kind = String(d.get("k", ""))
	match kind:
		"field_boss":
			set_meta("field_boss", true)
		"world_boss":
			template = template.duplicate()
			template["name"] = "%s %s" % [WorldEvents.NAME_BOSS, String(template.name)]
			set_meta("world_boss", int(d.get("day", 0)))
		"golden":
			template = template.duplicate()
			template["name"] = WorldEvents.NAME_GOLDEN
			template["tint"] = WorldEvents.GOLDEN_COLOR
			set_meta("golden", int(d.get("win", -1)))
	max_hp = maxi(1, int(d.get("mhp", max_hp)))
	hp = clampi(int(d.get("hp", max_hp)), 1, max_hp)
	hostile = int(d.get("h", 0)) != 0
	goal = at
	goal_yaw = float(d.get("y", 0.0))
	_yaw = goal_yaw
	if d.has("hx") and d.has("hz"):
		home = Vector3(float(d.get("hx", 0.0)), 0.0, float(d.get("hz", 0.0)))
	# Already raging (a late join or a new host's word): no shock for the old phases.
	phase = clampi(int(d.get("p", 0)), 0, 3)
	position = at + Vector3(0, 0.3, 0)
	set_meta("mirror_eid", eid)


func _ready() -> void:
	super._ready()
	visual.rotation.y = _yaw
	_bar.set_ratio(float(hp) / float(max_hp))
	if kind == "golden":
		_label.modulate = WorldEvents.GOLDEN_COLOR
		_label.visibility_range_end = 26.0
		var sparkle := VfxKit.buff_emitter(self, WorldEvents.GOLDEN_COLOR)
		sparkle.name = "GoldenSparkle"
		sparkle.emitting = true


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_tick_status(delta)
	if _bar_until > 0.0 and GameClock.msec() * 0.001 > _bar_until and (_ring == null or not _ring.visible):
		_bar.visible = false
		_bar_until = 0.0
	var moved := EntitySync.glide(self, goal, goal_yaw, delta)
	_animate(moved, delta, self)


## The host's latest word on it: where it stands and faces, its HP, its state (flags).
func mirror_state(x: float, z: float, yaw: float, p_hp: int, p_max: int, p_flags: int) -> void:
	if _dead:
		return
	goal.x = x
	goal.z = z
	goal_yaw = yaw
	flags = p_flags
	if p_max > 0:
		max_hp = p_max
	var shown := clampi(p_hp, 1, max_hp)
	if shown != hp:
		hp = shown
		_bar.set_ratio(float(hp) / float(max_hp))
		if hp < max_hp:
			_bar.visible = true
			_bar_until = GameClock.msec() * 0.001 + 6.0
	var angry := (p_flags & EntitySync.F_HOSTILE) != 0
	if angry and not hostile:
		hostile = true
		_flash_alert()
	elif not angry:
		hostile = false
	var acting := (p_flags & EntitySync.F_ACTING) != 0
	if acting and not _acting and GameClock.msec() >= _anim_lock:
		visual.action("attack", 450)
		_anim_lock = GameClock.msec() + 450
	_acting = acting
	var p := (p_flags >> 4) & 3
	if p > phase:
		mirror_phase(p)


## The hero's (or its party's) hit: shown here, counted by the host.
func take_hit(amount: int, crit: bool, _color := Color.WHITE, attacker: Node = null) -> bool:
	if _dead or amount <= 0:
		return false
	# The AI world players hunting here are not in the online party: their swings count
	# for nothing on the host's monster.
	if attacker != null and is_instance_valid(attacker) and attacker.is_in_group("world_players") and not attacker.is_in_group("companions"):
		return false
	set_dormant(false)
	dealt += amount
	if is_instance_valid(sync):
		sync.forward(self, amount, crit)
	hp = maxi(1, hp - amount)
	_bar.set_ratio(float(hp) / float(max_hp))
	_bar.visible = true
	_bar_until = GameClock.msec() * 0.001 + 6.0
	BattleVfx.damage_number(get_parent(), top_point(), str(amount) + ("!" if crit else ""), false, 1.35 if crit else 1.0)
	visual.flash(Color(1, 1, 1))
	if not is_boss and GameClock.msec() >= _anim_lock:
		visual.action("hurt", 320)
		_anim_lock = GameClock.msec() + 320
	return false


func _fx(key: String, value: Variant) -> void:
	if is_instance_valid(sync):
		sync.forward_fx(self, key, value)


func apply_stun(seconds: float) -> void:
	_fx("stun", seconds)
	super.apply_stun(seconds)


func apply_slow(seconds: float) -> void:
	_fx("slow", seconds)


func apply_freeze(seconds: float) -> void:
	_fx("freeze", seconds)
	super.apply_freeze(seconds)


## The host's monster burns (its HP comes back with the snapshots); nothing ticks here.
func apply_burn(dps: float, seconds: float) -> void:
	_fx("burn", [dps, seconds])


func apply_shred(fraction: float, seconds: float) -> void:
	_fx("shred", [fraction, seconds])
	super.apply_shred(fraction, seconds)


func apply_weaken(fraction: float, seconds: float) -> void:
	_fx("weaken", [fraction, seconds])
	super.apply_weaken(fraction, seconds)


func taunt(by: Node3D, seconds: float) -> void:
	_fx("taunt", seconds)
	super.taunt(by, seconds)


## Where it stands is the host's business.
func knock_back(_from: Vector3, _strength := 2.5) -> void:
	pass


func shove_out(_center: Vector3, _radius: float) -> void:
	pass


## Its phases come from the host (mirror_phase).
func _check_phase() -> void:
	pass


## A game that earned the kill pays it in full (each rolls its own drop); one that took no
## part gets nothing (mirror_dead).
func party_share() -> float:
	return _reward


## The host's monster fell: the zone pays this game's EXP and loot when it earned them.
func mirror_dead(data: Dictionary) -> void:
	if _dead:
		return
	if is_instance_valid(sync) and not sync.earns(eid, data, dealt):
		_reward = 0.0
		EntitySync.no_credit(self)
	hp = 0
	_bar.set_ratio(0.0)
	_die()


## A boss crossed a threshold on the host: the same shock, words and rage here.
func mirror_phase(p: int) -> void:
	if p <= phase:
		return
	phase = p
	var color: Color = template.get("color", Color("ff6a4a"))
	VfxKit.shockwave(get_parent(), global_position + Vector3(0, 0.1, 0), color, 7.0)
	BattleVfx.burst(get_parent(), global_position + Vector3(0, 0.6, 0), color, 40, 1.6)
	if phase == 2:
		visual.flash(Color(1.0, 0.2, 0.15), 1.0)
		BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.9, 0), "คลั่ง!", Color("ff4a4a"), 1.5)
	else:
		BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.9, 0), "เรียกพวก!", Color("ffd84a"), 1.4)


## A telegraphed move on the host: the same danger circles, the windup and its name.
func mirror_cast(d: Dictionary) -> void:
	if _dead or not is_inside_tree():
		return
	var parent := get_parent() as Node3D
	var first := 99.0
	var last := 0.0
	var circles: Variant = d.get("c", [])
	if circles is Array:
		for c in circles:
			if not (c is Array) or (c as Array).size() < 4:
				continue
			var secs := clampf(float(c[3]), 0.1, 6.0)
			first = minf(first, secs)
			last = maxf(last, secs)
			VfxKit.danger_circle(parent, Vector3(float(c[0]), 0.0, float(c[1])), clampf(float(c[2]), 0.3, 30.0), secs)
	if first > 50.0:
		first = 0.5
		last = 0.5
	visual.flash(Color(1.0, 0.3, 0.2), first)
	visual.action(String(d.get("a", "attack")), int((last + 0.4) * 1000.0))
	_anim_lock = GameClock.msec() + int((last + 0.4) * 1000.0)
	var title := String(d.get("n", ""))
	if title != "":
		BattleVfx.floating_text(parent, top_point() + Vector3(0, 0.9, 0), title, Color("ffb3a0"), 1.1)
