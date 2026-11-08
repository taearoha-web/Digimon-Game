class_name MirrorFighter
extends GuildFighter
## A guild-war fighter of the party leader's war (EntitySync) shown in a member's game:
## built from the same roster entry (look, gear, mount, name, guild colours), so it looks
## and is targeted like the leader's GuildFighter, but it has no AI. It glides to the
## leader's snapshots, falls and comes back when the leader's does, and a hit on it goes
## to the leader as `ent_hit` (the leader's fighter takes it, war scale and all).

var eid := 0
var sync: EntitySync
var goal := Vector3.ZERO
var goal_yaw := 0.0
var _acting := false


## Turns a roster entry sent as text (var_to_str) back into a Dictionary; anything that
## could build an object is refused.
static func decode(text: String) -> Dictionary:
	if text.length() > 12000:
		return {}
	for bad in ["Object(", "Resource(", "SubResource(", "ExtResource(", "Callable(", "Signal(", "RID("]:
		if text.contains(bad):
			return {}
	var v: Variant = str_to_var(text)
	if not (v is Dictionary):
		return {}
	var info: Dictionary = v
	if not (info.get("member") is Dictionary) or not (info.get("profile") is Dictionary) or not (info.get("look") is Dictionary):
		return {}
	if not ((info.profile as Dictionary).get("equip") is Dictionary):
		return {}
	return info


static func build(p_sync: EntitySync, p_eid: int, d: Dictionary, p_hero: Node3D, war: GuildWarMatch) -> MirrorFighter:
	var info := decode(String(d.get("f", "")))
	if info.is_empty():
		return null
	info["mults"] = {"hp": 1.0, "atk": 1.0, "def": 1.0}
	info["difficulty"] = float(info.get("difficulty", 0.5))
	var team := clampi(int(d.get("team", TEAM_ENEMY)), TEAM_ALLY, TEAM_ENEMY)
	var spawn := Vector3(float(d.get("sx", d.get("x", 0.0))), 0.3, float(d.get("sz", d.get("z", 0.0))))
	var f := MirrorFighter.new()
	f.sync = p_sync
	f.eid = p_eid
	f.setup_fighter(info, team, p_hero, spawn, String(d.get("g", "")))
	f.max_hp = maxi(1, int(d.get("mhp", f.max_hp)))
	f.hp = clampi(int(d.get("hp", f.max_hp)), 0, f.max_hp)
	f.stats["def"] = float(d.get("def", f.stats.def))
	f.party = -1
	f.siege = war
	f.goal = Vector3(float(d.get("x", spawn.x)), 0.0, float(d.get("z", spawn.z)))
	f.goal_yaw = float(d.get("y", 0.0))
	f._yaw = f.goal_yaw
	f.position = f.goal + Vector3(0, 0.3, 0)
	f.set_meta("mirror_eid", p_eid)
	return f


## In the tree: the leader's crown, the war's lists (HUD, minimap), a fallen one lies down.
func after_enter(d: Dictionary) -> void:
	visual.rotation.y = _yaw
	_frozen = false
	if bool(d.get("lead", false)):
		make_leader()
	if siege != null and is_instance_valid(siege):
		if team == TEAM_ALLY:
			siege.allies.append(self)
		else:
			siege.enemies.append(self)
			if is_leader:
				siege.enemy_leader = self
	if bool(d.get("dead", false)) or hp <= 0:
		_fall()


func _exit_tree() -> void:
	if siege != null and is_instance_valid(siege):
		siege.allies.erase(self)
		siege.enemies.erase(self)
		if siege.enemy_leader == self:
			siege.enemy_leader = null


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _bar_until > 0.0 and GameClock.msec() * 0.001 > _bar_until and (_ring == null or not _ring.visible):
		_bar.visible = false
		_bar_until = 0.0
	var moved := EntitySync.glide(self, goal, goal_yaw, delta)
	_animate(moved, delta, self)


func mirror_state(x: float, z: float, yaw: float, p_hp: int, p_max: int, p_flags: int) -> void:
	goal.x = x
	goal.z = z
	goal_yaw = yaw
	if p_max > 0:
		max_hp = p_max
	var down := (p_flags & EntitySync.F_DEAD) != 0
	if down and not _dead:
		_fall()
		return
	if not down and _dead:
		_rise()
	if _dead:
		return
	var shown := clampi(p_hp, 1, max_hp)
	if shown != hp:
		hp = shown
		_bar.set_ratio(float(hp) / float(max_hp))
		if hp < max_hp:
			_bar.visible = true
			_bar_until = GameClock.msec() * 0.001 + 6.0
	var acting := (p_flags & EntitySync.F_ACTING) != 0
	if acting and not _acting and GameClock.msec() >= _cast_until and _rv != null and is_instance_valid(_rv.hero_visual):
		var clips: Array = class_data.get("attack", {}).get("anims", ["Attack_A"])
		_rv.hero_visual.action(String(clips[_combo % maxi(1, clips.size())]), 1.0)
		_combo += 1
		_cast_until = GameClock.msec() + 450
	_acting = acting


func take_hit(amount: int, crit: bool, _color := Color.WHITE, _attacker: Node = null) -> bool:
	if _dead or amount <= 0:
		return false
	if is_instance_valid(sync):
		sync.forward(self, amount, crit)
	var shown := int(ceil(float(amount) * war_scale))
	hp = maxi(1, hp - shown)
	_bar.set_ratio(float(hp) / float(max_hp))
	_bar.visible = true
	_bar_until = GameClock.msec() * 0.001 + 6.0
	BattleVfx.damage_number(get_parent(), top_point(), str(shown) + ("!" if crit else ""), team == TEAM_ALLY, 1.35 if crit else 1.0)
	visual.flash(Color(1, 1, 1))
	return false


## Nothing here hurts a mirror: the leader's game decides.
func take_damage(_raw: float, _attacker: Node = null) -> void:
	pass


func heal_fraction(_fraction: float) -> void:
	pass


func _fx(key: String, value: Variant) -> void:
	if is_instance_valid(sync):
		sync.forward_fx(self, key, value)


func apply_stun(seconds: float) -> void:
	_fx("stun", seconds)


func apply_slow(seconds: float) -> void:
	_fx("slow", seconds)


func apply_freeze(seconds: float) -> void:
	_fx("freeze", seconds)


func apply_burn(dps: float, seconds: float) -> void:
	_fx("burn", [dps, seconds])


func apply_shred(fraction: float, seconds: float) -> void:
	_fx("shred", [fraction, seconds])


func apply_weaken(fraction: float, seconds: float) -> void:
	_fx("weaken", [fraction, seconds])


func taunt(_by: Node3D, seconds: float) -> void:
	_fx("taunt", seconds)


func knock_back(_from: Vector3, _strength := 2.5) -> void:
	pass


func shove_out(_center: Vector3, _radius: float) -> void:
	pass


## The leader's fighter fell: it lies down here (the hero scores it when it dealt the blow).
func mirror_dead(d: Dictionary) -> void:
	if _dead:
		return
	_fall()
	if siege != null and is_instance_valid(siege) and siege.mirror:
		siege.mirror_fell(self, String(d.get("killer", "")))


func _fall() -> void:
	if _dead:
		return
	hp = 0
	_dead = true
	hostile = false
	set_targeted(false)
	_bar.visible = false
	_alert.visible = false
	_label.visible = false
	collision_layer = 0
	_buff_art.clear(self)
	deaths += 1
	dismount()
	visual.hold("die")
	VfxKit.flash(get_parent(), hit_point(), Color("ffe9a0"), 1.6)


func _rise() -> void:
	_dead = false
	hp = max_hp
	hostile = true
	collision_layer = 1 << 2
	velocity = Vector3.ZERO
	global_position = goal + Vector3(0, 0.3, 0)
	_label.visible = true
	_bar.set_ratio(1.0)
	_bar.visible = false
	if _rv and _rv.hero_visual:
		_rv.hero_visual.release()
		_rv.hero_visual.play("Idle")
	ride()
	VfxKit.flash(get_parent(), global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.8)
