class_name DragonBoss
extends Mob
## The Ancient Dragon King of the mechanics dungeon (DungeonData, DragonRun): the abyss
## dragon's body in tomb green. Three mechanics need the party's roles; AI party members
## (Companion) read the statics here and the hero is told what to do (Game.say):
## - "ดวงตาเพลิง" (spread): MARK_COUNT random players are marked; after MARK_TIME each mark
##   explodes for SPREAD_HIT of max HP on EVERYONE within SPREAD_RADIUS of the marked one.
##   A marked player standing alone (nobody else in range) takes half (ALONE_TAKEN).
## - "กรงเล็บทำลายล้าง" (cone): a telegraphed cone from the boss towards its current
##   victim for CONE_TIME, then CONE_HIT of max HP (lethal-ish) to everyone inside. A tank
##   (one who taunted it lately, or a Defender) takes TANK_TAKEN of it, a warded player (a
##   shield / guard / an ally's defence buff, a Priest's) WARD_TAKEN. Without a Defender in
##   the party the boss alternates its target each cone and the target must side-step.
## - "ศิลามังกร" (target switch): at CRYSTAL_AT[k] of its HP it becomes invulnerable and
##   raises CRYSTALS crystals (DragonCrystal); both must die within CRYSTAL_TIME or it
##   heals CRYSTAL_HEAL and raises them again. phase_changed fires when a crystal phase
##   begins and ends (DragonRun revives the fallen then).
## - Enrage after ENRAGE_TIME seconds of fighting: ENRAGE_ATK times harder, twice as fast.
## The ground shapes are a few cheap meshes, tracked by VfxBudget.

const CYCLE := 9.0
const MARK_COUNT := 2
const MARK_TIME := 3.0
const SPREAD_RADIUS := 4.0
const SPREAD_HIT := 0.9
const ALONE_TAKEN := 0.5
const CONE_TIME := 2.5
const CONE_RANGE := 13.0
const CONE_HALF_ANGLE := 0.56
const CONE_HIT := 1.6
const TANK_TAKEN := 0.3
const WARD_TAKEN := 0.45
const TAUNT_MEMORY := 8.0
const CRYSTALS := 2
const CRYSTAL_AT := [0.7, 0.35]
const CRYSTAL_TIME := 20.0
const CRYSTAL_HEAL := 0.15
const ENRAGE_TIME := 360.0
const ENRAGE_ATK := 3.0
const ENRAGE_HASTE := 0.5
const MOVES := ["cone", "spread"]
const TITLES := {"cone": "กรงเล็บทำลายล้าง", "spread": "ดวงตาเพลิง"}
const COLOR := Color("5cf28a")
const MARK_COLOR := Color("ff7a2a")
const CONE_COLOR := Color("ff3a50")
const CRYSTAL_COLOR := Color("8ae6ff")

## The dragon in play (null when none): companions read it.
static var active: DragonBoss

var zone_ref: Node3D
## Seconds of fighting so far (the enrage clock).
var elapsed := 0.0
var enraged := false
## Specials landed, crystal phases begun, heals from unbroken crystals (tests).
var specials := 0
var crystal_phases := 0
var heals := 0
## Ground warnings now: {kind ("mark" | "cone"), left, victim (WeakRef), ...}.
var telegraphs: Array[Dictionary] = []
var crystals: Array[Mob] = []
## Seconds left to break the crystals (while a crystal phase is on).
var crystal_left := 0.0
var crystal_stats: Dictionary = {}
var _crystal_phase_on := false
var _cycle := 5.0
var _haste := 1.0
var _next := 0
var _taunter: WeakRef
var _taunt_at := -100.0
var _last_cone: WeakRef
var _shapes: Array[Node3D] = []
var _shield: MeshInstance3D
var _aura: MeshInstance3D
var _name_timer := 0.0
var _rng := RandomNumberGenerator.new()


## The dragon: `scaled` already DungeonData.monster_stats "boss".
func setup_dungeon(p_zone: Node3D, scaled: Dictionary, p_home: Vector3, p_hero: Node3D, p_crystal_stats: Dictionary, seed_value: int) -> void:
	setup(DungeonData.BOSS_MODEL, int(scaled.level), p_home, p_hero)
	zone_ref = p_zone
	template = template.duplicate(true)
	template["name"] = DungeonData.BOSS_NAME
	template["tint"] = DungeonData.BOSS_TINT
	template["color"] = COLOR
	# Its moves are its own (never the abyss dragon's inferno).
	template.erase("behavior")
	template.erase("behavior2")
	stats["hp"] = int(scaled.hp)
	stats["atk"] = int(scaled.atk)
	stats["def"] = int(scaled.def)
	hp = int(scaled.hp)
	max_hp = hp
	crystal_stats = p_crystal_stats
	_rng.seed = seed_value
	_slam_timer = 999.0


func _ready() -> void:
	super._ready()
	active = self
	_label.visibility_range_end = 40.0
	_aura = MeshInstance3D.new()
	_aura.mesh = MeshKit.torus()
	_aura.material_override = _material(COLOR, 0.55)
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aura)
	_aura.position = Vector3(0, 0.05, 0)
	_aura.scale = Vector3(4.6, 0.2, 4.6)
	_refresh_name()


func _exit_tree() -> void:
	if active == self:
		active = null
	_clear_shapes()


## Never leashes home in its own arena.
func _leash() -> float:
	return 999.0


## Its moves come from tick(), not the generic slam.
func _begin_slam() -> void:
	_slam_timer = 999.0


## A taunt holds it twice as long and is remembered: the tank takes the claw well.
func taunt(by: Node3D, seconds: float) -> void:
	if by != null and is_instance_valid(by):
		_taunter = weakref(by)
		_taunt_at = elapsed
	super.taunt(by, seconds * 2.0)


## Behind its crystals nothing hurts it.
func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
	if shielded():
		BattleVfx.floating_text(get_parent(), top_point() + Vector3(0, 0.6, 0), "ไร้เทียมทาน", CRYSTAL_COLOR, 0.9)
		add_threat(attacker, float(mini(amount, 1)))
		provoke()
		return false
	return super.take_hit(amount, crit, color, attacker)


## Invulnerable while a crystal phase is on.
func shielded() -> bool:
	return _crystal_phase_on


## Its own phases: the crystal phases at CRYSTAL_AT.
func _check_phase() -> void:
	if _crystal_phase_on or crystal_phases >= CRYSTAL_AT.size():
		return
	if float(hp) / float(maxi(1, max_hp)) <= float(CRYSTAL_AT[crystal_phases]):
		begin_crystals()


## Raises the crystals and goes invulnerable (a phase change).
func begin_crystals() -> void:
	if _dead or _crystal_phase_on:
		return
	_crystal_phase_on = true
	crystal_phases += 1
	phase = crystal_phases
	crystal_left = CRYSTAL_TIME
	telegraphs.clear()
	_clear_shapes()
	_winding = false
	_raise_crystals()
	var parent := get_parent() as Node3D
	VfxKit.shockwave(parent, global_position + Vector3(0, 0.1, 0), CRYSTAL_COLOR, 9.0)
	BattleVfx.burst(parent, global_position + Vector3(0, 0.8, 0), CRYSTAL_COLOR, 40, 1.8)
	visual.flash(CRYSTAL_COLOR, 1.2)
	BattleVfx.floating_text(parent, top_point() + Vector3(0, 0.9, 0), "ศิลามังกร!", CRYSTAL_COLOR, 1.6)
	Game.screen_flash.emit(Color(0.4, 0.9, 1.0), 0.3)
	_banner("สลับเป้า! %s ไร้เทียมทาน — ทำลาย%s %d ก้อนภายใน %d วินาที" % [DungeonData.BOSS_NAME, DungeonData.CRYSTAL_NAME, CRYSTALS, int(CRYSTAL_TIME)])
	_update_shield()
	phase_changed.emit(self, phase)


func _raise_crystals() -> void:
	var parent := get_parent() as Node3D
	for c in crystals:
		if is_instance_valid(c) and not c.is_dead():
			c.queue_free()
	crystals.clear()
	for i in CRYSTALS:
		var angle := TAU * float(i) / float(CRYSTALS) + PI * 0.5 + _rng.randf_range(-0.3, 0.3)
		var spot := Vector3(global_position.x, 0.0, global_position.z) + Vector3(cos(angle), 0, sin(angle)) * 8.0
		var c := DragonCrystal.new()
		c.setup_crystal(int(crystal_stats.get("level", level)), spot, hero, crystal_stats)
		c.position = spot + Vector3(0, 0.3, 0)
		c.set_meta("tomb_crystal", true)
		parent.add_child(c)
		c.provoke(false)
		crystals.append(c)
		VfxKit.pillar(parent, spot, CRYSTAL_COLOR, 6.0, 1.2, 0.6)


## Both crystals fell in time: vulnerable again (a phase change).
func end_crystals() -> void:
	if not _crystal_phase_on:
		return
	_crystal_phase_on = false
	crystal_left = 0.0
	_cycle = 2.0
	var parent := get_parent() as Node3D
	VfxKit.shockwave(parent, global_position + Vector3(0, 0.1, 0), COLOR, 8.0)
	visual.flash(Color(1.0, 0.4, 0.3), 1.0)
	BattleVfx.floating_text(parent, top_point() + Vector3(0, 0.9, 0), "โล่แตก!", Color("ffd84a"), 1.5)
	_banner("ศิลาแตกหมด! %s รับความเสียหายได้แล้ว รุมบอส!" % DungeonData.BOSS_NAME)
	_update_shield()
	phase_changed.emit(self, phase)


## The crystals stood too long: it heals and raises them again.
func _crystals_failed() -> void:
	heals += 1
	hp = mini(max_hp, hp + int(round(float(max_hp) * CRYSTAL_HEAL)))
	_bar.set_ratio(float(hp) / float(max_hp))
	var parent := get_parent() as Node3D
	VfxKit.heal(parent, global_position, CRYSTAL_COLOR)
	BattleVfx.floating_text(parent, top_point() + Vector3(0, 0.9, 0), "+%d%% HP" % int(CRYSTAL_HEAL * 100.0), Color("6dff9a"), 1.4)
	_banner("ช้าไป! %s ฟื้น HP %d%% และเรียก%sขึ้นใหม่ — ทำลายทั้งสองก้อนให้ทัน" % [DungeonData.BOSS_NAME, int(CRYSTAL_HEAL * 100.0), DungeonData.CRYSTAL_NAME])
	crystal_left = CRYSTAL_TIME
	_raise_crystals()


func enrage() -> void:
	if enraged or _dead:
		return
	enraged = true
	phase = 9
	_atk_scale *= ENRAGE_ATK
	_haste *= ENRAGE_HASTE
	_speed *= 1.3
	visual.flash(Color(1.0, 0.1, 0.1), 2.0)
	VfxKit.shockwave(get_parent(), global_position + Vector3(0, 0.1, 0), Color("ff0a2a"), 12.0)
	Game.screen_flash.emit(Color(1.0, 0.05, 0.1), 0.5)
	_banner("%s คลั่งสุดขีด! (หมดเวลา) โจมตีแรง x%d" % [DungeonData.BOSS_NAME, int(ENRAGE_ATK)])
	_refresh_name()


func _process(delta: float) -> void:
	tick(delta)


## One step of the fight: the enrage clock, the crystal timer, the warnings on the ground
## and the move cycle. Only while it fights. Tests drive it with big deltas: one move
## starts per call at most.
func tick(delta: float) -> void:
	if _dead or not hostile:
		return
	elapsed += delta
	if not enraged and elapsed >= ENRAGE_TIME:
		enrage()
	_name_timer -= delta
	if _name_timer <= 0.0:
		_name_timer = 0.5
		_refresh_name()
		_update_shield()
	if _crystal_phase_on:
		crystals = crystals.filter(func(c): return is_instance_valid(c) and not c.is_dead())
		if crystals.is_empty():
			end_crystals()
		else:
			crystal_left -= delta
			if crystal_left <= 0.0:
				_crystals_failed()
		_slam_timer = 999.0
		return
	_tick_telegraphs(delta)
	if not telegraphs.is_empty():
		_slam_timer = 999.0
		return
	if _stun > 0.0:
		return
	_cycle -= delta
	if _cycle <= 0.0:
		force_special(MOVES[_next])
		_next = (_next + 1) % MOVES.size()


## The players it may mark or claw: the hero, the companions and the real party members
## (never summons).
func players() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for t in _targets():
		if t == hero or t.is_in_group("companions") or t.is_in_group("world_players") or t.is_in_group("remote_players"):
			if not out.has(t):
				out.append(t)
	return out


## Whether the party has a Defender (the hero's class or a member's).
func has_defender() -> bool:
	for p in players():
		if _is_defender(p):
			return true
	return false


## Starts a move's warning now (tests, and the cycle).
func force_special(kind: String) -> void:
	if _dead or _crystal_phase_on or not telegraphs.is_empty():
		return
	_cycle = CYCLE * _haste * _rng.randf_range(0.85, 1.15)
	var parent := get_parent() as Node3D
	match kind:
		"spread":
			var pool := players()
			var marked: Array[Node3D] = []
			while marked.size() < MARK_COUNT and not pool.is_empty():
				var v: Node3D = pool.pop_at(_rng.randi() % pool.size())
				marked.append(v)
			if marked.is_empty():
				return
			var names: PackedStringArray = []
			var hero_marked := false
			for v in marked:
				telegraphs.append({"kind": "mark", "left": MARK_TIME, "victim": weakref(v), "center": v.global_position, "radius": SPREAD_RADIUS, "shape": _ground_ring(v.global_position, SPREAD_RADIUS, 0.3, 0.9, MARK_COLOR)})
				BattleVfx.floating_text(parent, v.global_position + Vector3(0, 3.0, 0), "ดวงตาเพลิง!", MARK_COLOR, 1.4)
				if v == hero:
					hero_marked = true
				names.append(name_of(v))
			if hero_marked:
				Game.say("คุณถูกมาร์ค \"ดวงตาเพลิง\"! กระจายตัว: วิ่งออกห่างทุกคนเกิน %d เมตร ก่อน %d วินาที" % [int(SPREAD_RADIUS), int(MARK_TIME)], &"warning")
			else:
				Game.say("ดวงตาเพลิงมาร์ค %s! กระจายตัว: อย่าเข้าใกล้คนที่ถูกมาร์คใน %d เมตร" % [" และ ".join(names), int(SPREAD_RADIUS)], &"warning")
		"cone":
			var victim: Node3D = _victim if _alive(_victim) else null
			if not has_defender():
				victim = _alternate_target(victim)
			if victim == null:
				victim = _pick_victim()
			if victim == null:
				return
			_victim = victim
			_victim_timer = maxf(_victim_timer, CONE_TIME + 1.0)
			_last_cone = weakref(victim)
			var origin := Vector3(global_position.x, 0.0, global_position.z)
			var dir := Vector3(victim.global_position.x - origin.x, 0.0, victim.global_position.z - origin.z)
			if dir.length_squared() < 0.01:
				dir = Vector3(sin(_yaw), 0, cos(_yaw))
			dir = dir.normalized()
			telegraphs.append({"kind": "cone", "left": CONE_TIME, "victim": weakref(victim), "origin": origin, "dir": dir, "shape": _ground_cone(origin, dir)})
			_yaw = atan2(dir.x, dir.z)
			visual.rotation.y = _yaw
			var who := name_of(victim)
			if victim == hero:
				if _is_defender(hero):
					Game.say("\"กรงเล็บทำลายล้าง\" เล็งคุณ! ล่อบอส: ยั่วยุ / เบ่งเลือดแล้วรับไว้" , &"warning")
				else:
					Game.say("\"กรงเล็บทำลายล้าง\" เล็งคุณ! หลบออกข้าง ๆ ให้พ้นกรวยแดง (หรือให้ผู้พิทักษ์ยั่วยุ / นักบวชใส่โล่)", &"warning")
			else:
				Game.say("%s เล็ง \"กรงเล็บทำลายล้าง\" ใส่ %s! ผู้พิทักษ์ยั่วยุรับแทน นักบวชใส่โล่ คนอื่นอย่ายืนในกรวย" % [DungeonData.BOSS_NAME, who], &"warning")
	if telegraphs.is_empty():
		return
	_winding = true
	var wind := CONE_TIME if kind == "cone" else MARK_TIME
	visual.flash(Color(1.0, 0.5, 0.3), wind)
	visual.action("attack", int(wind * 1000.0))
	_anim_lock = GameClock.msec() + int(wind * 1000.0)
	BattleVfx.floating_text(parent, top_point() + Vector3(0, 0.9, 0), String(TITLES[kind]) + "!", Color("d8ffb0"), 1.4)


## Without a Defender the claw goes to someone else each time.
func _alternate_target(current: Node3D) -> Node3D:
	var pool := players()
	if pool.size() <= 1:
		return current if current != null else (pool[0] if not pool.is_empty() else null)
	var last: Node3D = _last_cone.get_ref() as Node3D if _last_cone != null else null
	var options: Array[Node3D] = []
	for p in pool:
		if p != last:
			options.append(p)
	if options.is_empty():
		options = pool
	return options[_rng.randi() % options.size()]


func _tick_telegraphs(delta: float) -> void:
	if telegraphs.is_empty():
		return
	var done := true
	for t in telegraphs:
		if t.kind == "mark":
			var v: Node3D = (t.victim as WeakRef).get_ref() as Node3D
			if v != null and is_instance_valid(t.shape):
				(t.shape as Node3D).global_position = Vector3(v.global_position.x, 0.06, v.global_position.z)
				t["center"] = v.global_position
		t["left"] = float(t.left) - delta
		if float(t.left) > 0.0:
			done = false
	if not done:
		return
	var fired := telegraphs.duplicate()
	telegraphs.clear()
	_clear_shapes()
	_winding = false
	specials += 1
	var hit := {}
	for t in fired:
		_land(t, hit)


func _land(t: Dictionary, hit: Dictionary) -> void:
	var parent := get_parent() as Node3D
	match String(t.kind):
		"mark":
			var v: Node3D = (t.victim as WeakRef).get_ref() as Node3D
			if v == null or not _alive(v):
				return
			var center: Vector3 = v.global_position
			VfxKit.shockwave(parent, center + Vector3(0, 0.1, 0), MARK_COLOR, SPREAD_RADIUS)
			BattleVfx.burst(parent, center + Vector3(0, 0.6, 0), MARK_COLOR, 26, 1.4)
			var others: Array[Node3D] = []
			for p in players():
				if p != v and inside_circle(p.global_position, center, SPREAD_RADIUS):
					others.append(p)
			var share := SPREAD_HIT * (ALONE_TAKEN if others.is_empty() else 1.0)
			if not hit.has(v):
				hit[v] = true
				_hit(v, share)
				BattleVfx.floating_text(parent, center + Vector3(0, 3.2, 0), "กระจายตัวได้!" if others.is_empty() else "ระเบิดใส่ทีม!", Color("ffd0a0") if others.is_empty() else Color("ff5a5a"), 1.1)
			for p in others:
				if hit.has(p):
					continue
				hit[p] = true
				_hit(p, SPREAD_HIT)
		"cone":
			var origin: Vector3 = t.origin
			var dir: Vector3 = t.dir
			VfxKit.slash_arc(parent, origin + Vector3(0, 1.2, 0), atan2(dir.x, dir.z), CONE_COLOR, 6.0)
			BattleVfx.burst(parent, origin + dir * 5.0 + Vector3(0, 0.6, 0), CONE_COLOR, 36, 1.6)
			for p in players():
				if hit.has(p) or not inside_cone(p.global_position, origin, dir):
					continue
				hit[p] = true
				var share := CONE_HIT
				var word := "กรงเล็บทำลายล้าง!"
				var color := Color("ff5a5a")
				if is_tank(p):
					share *= TANK_TAKEN
					word = "รับไว้ได้!"
					color = Color("ffd0a0")
				elif is_warded(p):
					share *= WARD_TAKEN
					word = "โล่กันไว้!"
					color = Color("b0e8ff")
				_hit(p, share)
				BattleVfx.floating_text(parent, p.global_position + Vector3(0, 3.2, 0), word, color, 1.1)


## A tank for the claw: it taunted the boss in the last TAUNT_MEMORY seconds, or it is
## a Defender (the hero's class or a companion's).
func is_tank(v: Node) -> bool:
	if _taunter != null and _taunter.get_ref() == v and elapsed - _taunt_at <= TAUNT_MEMORY:
		return true
	return _is_defender(v)


static func _is_defender(v: Node) -> bool:
	if v is Hero:
		return Game.class_id() == &"defender"
	if v is Companion:
		return StringName((v as Companion).member.get("class", "")) == &"defender"
	return false


## Warded: a running shield (absorb), guard or an ally's defence buff (a Priest's) on it.
static func is_warded(v: Node) -> bool:
	var entries: Array = []
	if v is Hero:
		entries = (v as Hero)._buffs
	elif v is Companion:
		entries = (v as Companion)._book.buffs
	var now := Time.get_ticks_msec()
	for b in entries:
		if int(b.get("until", 0)) <= now:
			continue
		if int(b.get("shield_left", 0)) > 0 or float(b.get("guard", 0.0)) > 0.0:
			return true
		if bool(b.get("ally", false)) and float(b.get("def", 0.0)) > 0.0:
			return true
	return false


## `fraction` of the victim's max HP after its own DEF (the raw hit is scaled back up
## through HeroStats.mitigate); guards and shields still cut it.
func _hit(victim: Node3D, fraction: float) -> void:
	fraction *= _atk_scale
	var raw := float(stats.atk) * fraction * 4.0
	if victim is Hero:
		var h := victim as Hero
		raw = fraction * float(h.stats.max_hp) * (100.0 + maxf(h.effective_def(), 0.0)) / 100.0
	elif victim is Companion:
		var c := victim as Companion
		raw = fraction * float(c.max_hp) * (100.0 + maxf(float(c.stats.def) * (1.0 + c._book.total("def")), 0.0)) / 100.0
	Mob.strike(victim, raw, self)


static func inside_circle(point: Vector3, center: Vector3, radius: float) -> bool:
	return Vector2(point.x - center.x, point.z - center.z).length() <= radius


static func inside_cone(point: Vector3, origin: Vector3, dir: Vector3, margin := 0.0) -> bool:
	var d := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
	var dist := d.length()
	if dist > CONE_RANGE + margin:
		return false
	if dist < 0.5:
		return true
	return d.normalized().angle_to(Vector3(dir.x, 0.0, dir.z).normalized()) <= CONE_HALF_ANGLE + (margin / maxf(dist, 1.0))


static func name_of(v: Node3D) -> String:
	if v is Hero:
		return "คุณ"
	if v is Companion:
		return String((v as Companion).member.get("name", "เพื่อน"))
	if v != null and v.has_method("display_name"):
		return str(v.call("display_name"))
	return "เพื่อน"


## Seconds left before the enrage.
func enrage_left() -> float:
	return maxf(0.0, ENRAGE_TIME - elapsed)


func _refresh_name() -> void:
	if enraged:
		template["name"] = "%s · คลั่ง!" % DungeonData.BOSS_NAME
	else:
		var left := int(ceil(enrage_left()))
		template["name"] = "%s · คลั่งใน %d:%02d%s" % [DungeonData.BOSS_NAME, left / 60, left % 60, (" · ศิลา %d วิ" % int(ceil(crystal_left))) if _crystal_phase_on else ""]
	if is_instance_valid(_label):
		_label.text = "Lv.%d %s" % [level, DungeonData.BOSS_NAME]


func _update_shield() -> void:
	var on := shielded()
	if on and not is_instance_valid(_shield):
		_shield = MeshInstance3D.new()
		_shield.mesh = MeshKit.sphere_low()
		_shield.material_override = _material(CRYSTAL_COLOR, 0.22)
		_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_shield)
		var r := float(template.get("height", 6.0)) * 0.55
		_shield.position = Vector3(0, r * 0.9, 0)
		_shield.scale = Vector3.ONE * r
	elif not on and is_instance_valid(_shield):
		_shield.queue_free()
		_shield = null


func _banner(text: String) -> void:
	if zone_ref != null and is_instance_valid(zone_ref) and zone_ref.has_signal("banner_requested"):
		zone_ref.banner_requested.emit(text)
	Game.say(text, &"warning")


# --- What the AI reads --------------------------------------------------------------

## Escape step for `who` at `point`: a marked player away from the nearest other player
## within SPREAD_RADIUS, an unmarked one away from a marked player it stands near, a
## non-tank inside the claw's cone out of it sideways; Vector3.INF when nothing threatens.
static func danger_escape(point: Vector3, who: Node3D) -> Vector3:
	if active == null or not is_instance_valid(active) or active.is_dead():
		return Vector3.INF
	var margin := 1.0
	for t in active.telegraphs:
		var kind := String(t.kind)
		if kind == "mark":
			var v: Node3D = (t.victim as WeakRef).get_ref() as Node3D
			if v == null or not is_instance_valid(v):
				continue
			if v == who:
				# Marked: away from the closest other player within reach.
				var nearest: Node3D = null
				var best := SPREAD_RADIUS + margin
				for p in active.players():
					if p == who:
						continue
					var d := Vector3(point.x - p.global_position.x, 0.0, point.z - p.global_position.z).length()
					if d < best:
						best = d
						nearest = p
				if nearest != null:
					return _away(point, nearest.global_position, active.global_position)
			else:
				var d := Vector3(point.x - v.global_position.x, 0.0, point.z - v.global_position.z)
				if d.length() <= SPREAD_RADIUS + margin:
					return _away(point, v.global_position, active.global_position)
		elif kind == "cone":
			if active.is_tank(who) or active.is_warded(who):
				continue
			var origin: Vector3 = t.origin
			var dir: Vector3 = t.dir
			if inside_cone(point, origin, dir, margin):
				var side := Vector3(dir.z, 0.0, -dir.x)
				var rel := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
				return side if rel.dot(side) >= 0.0 else -side
	return Vector3.INF


static func _away(point: Vector3, from: Vector3, boss_at: Vector3) -> Vector3:
	var d := Vector3(point.x - from.x, 0.0, point.z - from.z)
	if d.length_squared() < 0.04:
		d = Vector3(point.x - boss_at.x, 0.0, point.z - boss_at.z)
		if d.length_squared() < 0.01:
			d = Vector3.BACK
	return d.normalized()


## A companion with a provoke should use it on the dragon while a claw is aimed at a
## non-tank, or while the dragon is on someone else.
static func wants_taunt(by: Node, target: Node) -> bool:
	if active == null or not is_instance_valid(active) or active.is_dead() or target != active:
		return false
	for t in active.telegraphs:
		if String(t.kind) == "cone":
			var v: Node3D = (t.victim as WeakRef).get_ref() as Node3D
			return v != by and not (v != null and active.is_tank(v))
	return active._victim != by


## A companion with a party defence buff (a Priest) should cast it now: a claw is aimed
## at someone who is neither a tank nor warded.
static func wants_ward(_by: Node) -> bool:
	if active == null or not is_instance_valid(active) or active.is_dead():
		return false
	for t in active.telegraphs:
		if String(t.kind) == "cone":
			var v: Node3D = (t.victim as WeakRef).get_ref() as Node3D
			return v != null and is_instance_valid(v) and not active.is_tank(v) and not is_warded(v)
	return false


## While the dragon fights, a fallen companion waits for a phase change (DragonRun raises
## it) instead of standing up by itself.
static func holds_fallen() -> bool:
	return active != null and is_instance_valid(active) and not active.is_dead() and active.hostile


## The crystal a companion at `point` should hit now (the nearest living one), or null.
static func priority_target(point: Vector3) -> Mob:
	if active == null or not is_instance_valid(active) or active.is_dead() or not active.shielded():
		return null
	var best: Mob = null
	var best_d := INF
	for c in active.crystals:
		if not is_instance_valid(c) or c.is_dead():
			continue
		var d := Vector3(point.x - c.global_position.x, 0.0, point.z - c.global_position.z).length()
		if d < best_d:
			best_d = d
			best = c
	return best


# --- Ground shapes -------------------------------------------------------------------

## A ring and a disc that fills over the warning.
func _ground_ring(center: Vector3, radius: float, fill_alpha: float, edge_alpha: float, color: Color) -> MeshInstance3D:
	var parent := get_parent() as Node3D
	if parent == null:
		parent = self
	var holder := MeshInstance3D.new()
	holder.mesh = MeshKit.torus()
	holder.material_override = _material(color, edge_alpha)
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(holder)
	holder.global_position = Vector3(center.x, 0.06, center.z)
	holder.scale = Vector3(radius, radius * 0.06, radius)
	VfxBudget.track_decoration(holder)
	var fill := MeshInstance3D.new()
	fill.mesh = MeshKit.cylinder()
	var fill_mat := _material(color, fill_alpha * 0.3)
	fill.material_override = fill_mat
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(fill)
	fill.scale = Vector3(0.15, 0.3, 0.15)
	var tween := fill.create_tween().set_parallel(true)
	tween.tween_property(fill, "scale", Vector3(1.0, 0.3, 1.0), MARK_TIME)
	tween.tween_property(fill_mat, "albedo_color:a", fill_alpha, MARK_TIME)
	_shapes.append(holder)
	return holder


## A flat red fan on the ground from `origin` along `dir`.
func _ground_cone(origin: Vector3, dir: Vector3) -> MeshInstance3D:
	var parent := get_parent() as Node3D
	if parent == null:
		parent = self
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := atan2(dir.x, dir.z)
	var steps := 12
	for i in steps:
		var a0 := base - CONE_HALF_ANGLE + 2.0 * CONE_HALF_ANGLE * float(i) / float(steps)
		var a1 := base - CONE_HALF_ANGLE + 2.0 * CONE_HALF_ANGLE * float(i + 1) / float(steps)
		for p in [Vector3.ZERO, Vector3(sin(a1), 0, cos(a1)) * CONE_RANGE, Vector3(sin(a0), 0, cos(a0)) * CONE_RANGE]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var mat := _material(CONE_COLOR, 0.25)
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = Vector3(origin.x, 0.07, origin.z)
	VfxBudget.track_decoration(mesh)
	var tween := mesh.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.75, CONE_TIME)
	_shapes.append(mesh)
	return mesh


func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _clear_shapes() -> void:
	for s in _shapes:
		if is_instance_valid(s):
			s.queue_free()
	_shapes.clear()
