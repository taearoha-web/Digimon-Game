class_name BossAttack
extends Node
## Signature moves of the field bosses (MonsterData "behavior" / "behavior2").
## Same contract as StarAttack: every danger circle is drawn and its position
## locked when the move starts, so nothing chases a dodging player. Each shot
## lands at its own time; an actor takes one hit per wave and at most MAX_HITS
## per move. Stun, death or a leash reset cancels shots that have not landed.
## Phase 0-1 bosses use "behavior"; in phase 2 they alternate "behavior2" and
## "behavior" (replacing the generic slam + meteor barrage).

const MAX_HITS := 2
const RECOVER := 0.3
const PUDDLE_TICK := 0.8
const PUDDLE_DAMAGE := 0.3
const P2_INTERVAL := 6.0

## style picks the strike effect and colour; slow is seconds of hero slow on hit.
const MOVES := {
	"spore_bloom": {"th": "สปอร์ระเบิด", "style": "spore", "slow": 2.5},
	"cap_stomp": {"th": "หมวกเห็ดกระทืบ", "style": "spore", "slow": 0.0},
	"flame_breath": {"th": "ลมหายใจเพลิง", "style": "fire", "slow": 0.0},
	"flame_fan": {"th": "เปลวไฟพัด", "style": "fire", "slow": 0.0},
	"quicksand": {"th": "ทรายดูด", "style": "sand", "slow": 3.0},
	"sand_cross": {"th": "พายุทรายกากบาท", "style": "sand", "slow": 0.0},
	"freeze_ring": {"th": "วงแหวนน้ำแข็ง", "style": "ice", "slow": 3.0},
	"avalanche": {"th": "หิมะถล่ม", "style": "ice", "slow": 2.0},
	"lava_lines": {"th": "กำแพงลาวา", "style": "fire", "slow": 0.0},
	"magma_geysers": {"th": "ลาวาพุ่ง", "style": "fire", "slow": 0.0},
	"bone_spikes": {"th": "หนามกระดูกผุด", "style": "bone", "slow": 0.0},
	"bone_rain": {"th": "ฝนกระดูก", "style": "bone", "slow": 0.0},
	"tongue_lash": {"th": "ลิ้นฟาดพิษ", "style": "poison", "slow": 0.0},
	"poison_pools": {"th": "บ่อพิษ", "style": "poison", "slow": 0.0},
	"chain_lightning": {"th": "สายฟ้าไล่ตาม", "style": "bolt", "slow": 0.0},
	"thunder_cage": {"th": "กรงสายฟ้า", "style": "bolt", "slow": 0.0},
	"solar_wedge": {"th": "รัศมีสุริยะ", "style": "light", "slow": 0.0},
	"sun_pillars": {"th": "เสาแสงทอง", "style": "light", "slow": 0.0},
	"inferno_spiral": {"th": "เกลียวไฟนรก", "style": "fire", "slow": 0.0},
	"inferno_twin": {"th": "เกลียวไฟคู่", "style": "fire", "slow": 0.0},
	"rift_trail": {"th": "รอยแยกมิติ", "style": "void", "slow": 0.0},
	"event_horizon": {"th": "ขอบฟ้าเหตุการณ์", "style": "void", "slow": 0.0},
}
const STYLE_COLORS := {
	"spore": Color("8fe05a"), "fire": Color("ff6a2a"), "sand": Color("e8c06a"), "ice": Color("9fe8ff"),
	"bone": Color("e8e0d0"), "poison": Color("9ae04a"), "bolt": Color("7ab8ff"), "light": Color("ffd84a"),
	"void": Color("b05aff"),
}

var mob: Mob
var move := ""
var style := "fire"
var slow := 0.0
var shots: Array[Dictionary] = []
var age := 0.0
var landed: Array[bool] = []
var last_impact := 0.0
var released := false
var warned: Node3D
var hit_counts := {}
var hit_waves := {}
var puddles: Array[Dictionary] = []


static func has_moves(template: Dictionary) -> bool:
	return MOVES.has(String(template.get("behavior", "")))


static func title(move_id: String) -> String:
	return String(MOVES.get(move_id, {}).get("th", move_id))


## The move for this slam: phase 2 alternates the enraged variant with the base one.
static func pick(actor: Mob) -> String:
	var base := String(actor.template.get("behavior", ""))
	var alt := String(actor.template.get("behavior2", ""))
	if actor.phase >= 2 and MOVES.has(alt):
		actor._boss_moves += 1
		return alt if actor._boss_moves % 2 == 1 else base
	return base


static func start(actor: Mob) -> void:
	if not actor._alive(actor._victim):
		return
	var attack := BossAttack.new()
	attack.mob = actor
	attack.move = pick(actor)
	actor._winding = true
	actor._slam_timer = Mob.SLAM_INTERVAL if actor.phase < 2 else P2_INTERVAL
	actor._attack_timer = maxf(actor._attack_timer, 1.8)
	actor.add_child(attack)


func _ready() -> void:
	var info: Dictionary = MOVES[move]
	style = String(info.style)
	slow = float(info.slow)
	var victim: Node3D = mob._victim
	var origin := mob.global_position * Vector3(1, 0, 1)
	var hero_pos := victim.global_position * Vector3(1, 0, 1)
	var forward := hero_pos - origin
	forward = forward.normalized() if forward.length_squared() > 0.01 else Vector3.FORWARD
	var heading := Vector3.ZERO
	if victim is CharacterBody3D:
		heading = (victim as CharacterBody3D).velocity * Vector3(1, 0, 1)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	shots = plan(move, origin, forward, hero_pos, heading, rng)
	var first := 99.0
	for shot in shots:
		last_impact = maxf(last_impact, float(shot.at))
		first = minf(first, float(shot.at))
	landed.resize(shots.size())
	landed.fill(false)
	warned = Node3D.new()
	warned.name = "BossEnemyWarnings"
	mob.get_parent().add_child(warned)
	for shot in shots:
		VfxKit.danger_circle(warned, shot.pos, float(shot.r), float(shot.at))
	var color: Color = STYLE_COLORS[style]
	mob.visual.flash(Color(1.0, 0.3, 0.2), first)
	mob.visual.action("attack", int((last_impact + 0.4) * 1000.0))
	mob._anim_lock = Time.get_ticks_msec() + int((last_impact + 0.4) * 1000.0)
	BattleVfx.floating_text(mob.get_parent(), mob.top_point() + Vector3(0, 0.9, 0), title(move), color, 1.1)


func _process(delta: float) -> void:
	if not is_instance_valid(mob) or mob.is_dead() or mob._returning:
		queue_free()
		return
	if age < last_impact and mob._stun > 0.0:
		queue_free()
		return
	age += delta
	for i in shots.size():
		if not landed[i] and age >= float(shots[i].at):
			landed[i] = true
			_land(shots[i])
	if not released and age >= last_impact + RECOVER:
		_release()
	_tick_puddles()
	if released and puddles.is_empty():
		queue_free()


func _exit_tree() -> void:
	if is_instance_valid(warned):
		warned.queue_free()
	if is_instance_valid(mob) and not released:
		mob._winding = false


func _release() -> void:
	released = true
	mob._winding = false


func _land(shot: Dictionary) -> void:
	_strike_vfx(shot)
	var pos: Vector3 = shot.pos
	var r: float = shot.r
	for actor in mob._targets():
		if _flat(actor.global_position, pos) > r:
			continue
		var key := actor.get_instance_id()
		var waves: Array = hit_waves.get(key, [])
		if int(shot.wave) in waves or int(hit_counts.get(key, 0)) >= MAX_HITS:
			continue
		waves.append(int(shot.wave))
		hit_waves[key] = waves
		hit_counts[key] = int(hit_counts.get(key, 0)) + 1
		_damage(actor, float(shot.dmg))
		if slow > 0.0 and actor.has_method("apply_slow"):
			actor.apply_slow(slow)
	if float(shot.get("linger", 0.0)) > 0.0:
		puddles.append({"pos": pos, "r": r, "until": age + float(shot.linger), "tick": age + PUDDLE_TICK})


func _tick_puddles() -> void:
	for i in range(puddles.size() - 1, -1, -1):
		var puddle := puddles[i]
		if age >= float(puddle.until):
			puddles.remove_at(i)
			continue
		if age < float(puddle.tick):
			continue
		puddle.tick = float(puddle.tick) + PUDDLE_TICK
		var hit := {}
		for actor in mob._targets():
			if _flat(actor.global_position, puddle.pos) <= float(puddle.r) and not hit.has(actor.get_instance_id()):
				hit[actor.get_instance_id()] = true
				_damage(actor, PUDDLE_DAMAGE)


func _damage(actor: Node3D, mult: float) -> void:
	actor.take_damage(float(mob.stats.atk) * mob._atk_scale * mult, mob)


func _flat(a: Vector3, b: Vector3) -> float:
	return ((a - b) * Vector3(1, 0, 1)).length()


## Strike effects use the budget-gated VfxKit / BattleVfx helpers only.
func _strike_vfx(shot: Dictionary) -> void:
	var parent := mob.get_parent()
	var pos: Vector3 = shot.pos
	var r: float = shot.r
	var color: Color = STYLE_COLORS[style]
	if float(shot.get("linger", 0.0)) > 0.0:
		VfxKit.ground_circle(parent, pos, color, r, float(shot.linger))
		BattleVfx.burst(parent, pos + Vector3(0, 0.4, 0), color, 10, 0.9)
		return
	match style:
		"fire":
			VfxKit.fire_ring(parent, pos, color, r * 0.8, 8, 0.8)
			BattleVfx.burst(parent, pos + Vector3(0, 0.4, 0), color, 10, 0.9)
		"ice":
			VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), color, r)
			VfxKit.spikes(parent, pos, r * 0.8, color, 5, 1.6)
		"bone":
			VfxKit.spikes(parent, pos, r * 0.8, color, 6, 2.2)
			BattleVfx.burst(parent, pos + Vector3(0, 0.4, 0), color, 8, 0.8)
		"bolt":
			VfxKit.lightning(parent, pos + Vector3(0.3, 9.0, 0.3), pos, color)
			VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), color, r)
		"light", "void":
			VfxKit.pillar(parent, pos, color, 9.0, r * 0.55, 0.45)
			VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), color, r)
		_:
			VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), color, r)
			BattleVfx.burst(parent, pos + Vector3(0, 0.4, 0), color, 12, 1.0)


# ---------------------------------------------------------------------------
# Patterns: pure functions of the locked positions, so tests can inspect them.
# A shot is {pos, r (m), at (s after start), dmg (x atk), wave, linger?}.
# ---------------------------------------------------------------------------

static func plan(move_id: String, o: Vector3, f: Vector3, h: Vector3, heading: Vector3, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var side := Vector3(-f.z, 0, f.x)
	var reach := (h - o).length()
	match move_id:
		"spore_bloom":
			for p in _around(h, 4, 2.5, 5.5, rng):
				out.append(_shot(p, 2.3, 1.3, 1.1, 0))
			out.append(_shot(h, 2.3, 1.3, 1.1, 0))
		"cap_stomp":
			out.append(_shot(o, 3.4, 1.2, 1.5, 0))
			for p in _ring(o, 7.5, 8, rng.randf() * TAU, []):
				out.append(_shot(p, 2.6, 2.0, 1.4, 1))
		"flame_breath":
			for i in 5:
				out.append(_shot(o + f * (3.0 + 2.2 * i), 1.9, 1.0 + 0.18 * i, 1.3, i))
		"flame_fan":
			var n := 0
			for angle in [-0.9, 0.0, 0.9]:
				for j in 3:
					out.append(_shot(o + f.rotated(Vector3.UP, angle) * (3.5 + 3.0 * j), 1.8, 1.2 + 0.2 * j, 1.3, n))
					n += 1
		"quicksand":
			out.append(_shot(h, 3.0, 1.5, 1.0, 0))
			for p in _around(h, 3, 3.5, 6.0, rng):
				out.append(_shot(p, 3.0, 1.5, 1.0, 0))
		"sand_cross":
			var n := 0
			for k in 4:
				for j in 2:
					out.append(_shot(o + f.rotated(Vector3.UP, k * PI * 0.5) * (3.8 + 3.4 * j), 2.0, 1.3 + 0.3 * j, 1.4, n))
					n += 1
		"freeze_ring":
			for p in _ring(o, 6.2, 8, rng.randf() * TAU, []):
				out.append(_shot(p, 2.6, 1.4, 1.3, 0))
		"avalanche":
			var n := 0
			for j in 3:
				for lateral in [-6.5, 0.0, 6.5]:
					out.append(_shot(o + f * (3.5 + 3.0 * j) + side * lateral, 2.0, 1.2 + 0.15 * j, 1.4, n))
					n += 1
		"lava_lines":
			var gaps := [rng.randi() % 5, 0]
			gaps[1] = (gaps[0] + 1 + rng.randi() % 4) % 5
			for row in 2:
				for slot in 5:
					if slot == gaps[row]:
						continue
					out.append(_shot(o + f * (5.0 + 4.0 * row) + side * (-6.0 + 3.0 * slot), 1.6, 1.2 + 0.7 * row, 1.4, row))
		"magma_geysers":
			var spots: Array[Vector3] = [h]
			spots.append_array(_around(h, 5, 2.5, 6.0, rng))
			for i in spots.size():
				out.append(_shot(spots[i], 2.0, 1.0 + 0.3 * i, 1.3, i))
		"bone_spikes":
			var gap := rng.randi() % 10
			for p in _ring(o, 5.5, 10, 0.0, [gap, (gap + 1) % 10]):
				out.append(_shot(p, 1.6, 1.4, 1.5, 0))
		"bone_rain":
			var spots: Array[Vector3] = [h]
			spots.append_array(_around(h, 7, 2.5, 6.5, rng))
			for i in spots.size():
				out.append(_shot(spots[i], 1.6, 1.1 if i < 4 else 1.9, 1.1, 0 if i < 4 else 1))
		"tongue_lash":
			var length := clampf(reach + 1.5, 5.5, 11.0)
			var n := 0
			var d := 2.2
			while d <= length:
				out.append(_shot(o + f * d, 1.3, 0.9 + 0.12 * n, 1.4, n))
				n += 1
				d += 2.0
			var puddle := _shot(o + f * length, 2.4, 0.9 + 0.12 * n, 0.6, n)
			puddle["linger"] = 4.0
			out.append(puddle)
		"poison_pools":
			var spots: Array[Vector3] = [h]
			spots.append_array(_around(h, 2, 3.5, 5.5, rng))
			for p in spots:
				var puddle := _shot(p, 2.6, 1.3, 0.8, 0)
				puddle["linger"] = 4.5
				out.append(puddle)
		"chain_lightning":
			var dir := heading.normalized() if heading.length() > 0.5 else f
			for i in 4:
				out.append(_shot(h + dir * (3.2 * i), 1.9, 1.1 + 0.3 * i, 1.4, i))
		"thunder_cage":
			for p in _ring(h, 5.0, 6, rng.randf() * TAU, []):
				out.append(_shot(p, 1.6, 1.3, 1.2, 0))
			out.append(_shot(h, 2.4, 2.1, 1.5, 1))
		"solar_wedge":
			var start := rng.randi() % 8
			for wave in 2:
				var skip: Array = []
				for k in 3:
					skip.append((start + 4 * wave + k) % 8)
				for p in _ring(o, 6.0, 8, 0.0, skip):
					out.append(_shot(p, 2.2, 1.3 + wave, 1.5, wave))
			out.append(_shot(o, 3.2, 2.3, 1.5, 1))
		"sun_pillars":
			var spots: Array[Vector3] = [h]
			spots.append_array(_around(h, 5, 2.5, 6.0, rng))
			for i in spots.size():
				out.append(_shot(spots[i], 1.8, 1.0 + 0.5 * (i >> 1), 1.3, i >> 1))
		"inferno_spiral":
			var a0 := atan2(f.z, f.x)
			for i in 8:
				var a := a0 + 0.85 * i
				out.append(_shot(o + Vector3(cos(a), 0, sin(a)) * (3.0 + i), 1.9, 1.0 + 0.2 * i, 1.4, i))
		"inferno_twin":
			var a0 := atan2(f.z, f.x)
			for arm in 2:
				for i in 5:
					var a := a0 + arm * PI + 0.9 * i
					out.append(_shot(o + Vector3(cos(a), 0, sin(a)) * (3.0 + 1.4 * i), 1.9, 1.0 + 0.25 * i, 1.4, i + 5 * arm))
		"rift_trail":
			for i in 6:
				var lateral := 2.4 if i % 2 == 0 else -2.4
				out.append(_shot(o + f * (3.0 + 2.2 * i) + side * lateral, 1.8, 1.0 + 0.2 * i, 1.5, i))
		"event_horizon":
			out.append(_shot(h, 2.2, 1.4, 1.4, 0))
			for p in _around(h, 3, 3.0, 6.0, rng):
				out.append(_shot(p, 2.2, 1.4, 1.4, 0))
			for p in _ring(o, 8.0, 6, rng.randf() * TAU, []):
				out.append(_shot(p, 2.4, 2.2, 1.5, 1))
	return out


static func _shot(pos: Vector3, r: float, at: float, dmg: float, wave: int) -> Dictionary:
	return {"pos": pos * Vector3(1, 0, 1), "r": r, "at": at, "dmg": dmg, "wave": wave}


## [param n] spots evenly spread (with jitter) around [param c], lo..hi metres out.
static func _around(c: Vector3, n: int, lo: float, hi: float, rng: RandomNumberGenerator) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var base := rng.randf() * TAU
	for i in n:
		var a := base + TAU * float(i) / float(n) + rng.randf_range(-0.25, 0.25)
		out.append(c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(lo, hi))
	return out


static func _ring(c: Vector3, radius: float, n: int, offset: float, skip: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in n:
		if i in skip:
			continue
		var a := offset + TAU * float(i) / float(n)
		out.append(c + Vector3(cos(a), 0, sin(a)) * radius)
	return out
