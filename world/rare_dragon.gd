class_name RareDragon
extends Node
## The rare dragon (มังกรแก้วเจ็ดสี), a node of every zone flagged "rare_dragon"
## (เกาะลอยฟ้าเทพมังกร): a few times a Thai day, at minutes nobody can learn by habit but
## the same for everyone (WorldEvents.rare_now), a prismatic crystal dragon comes to one
## of the field's camps (WorldEvents.rare_camp) for WorldEvents.RARE_LENGTH seconds.
##
## - Everyone on the server hears of it (Announcer, kind "rare": a jade banner and a line
##   in the world chat, wherever the hero is) and the HUD's event chip counts its minutes
##   down (WorldEvents.rare_text).
## - In the zone: an alert (the zone's banner naming the camp, a roar), a jade
##   diamond on the minimap (kept on the rim when far) and a pillar of rainbow light over
##   it that shows from across the field (one unshaded additive mesh: no light, no
##   particles).
## - It is the field's own boss and more in strength (tune: HP_SCALE times its HP), is the god
##   skill's eastern dragon in rainbow crystal (CelestialDragon "prism"), and fights with telegraphed
##   moves (BossAttack). The world players hunting nearby join in once the hero's side
##   has engaged it (FieldPlayer._join_rare), holding back so the kill stays the hero's.
## - When the window ends it flies off. When it falls, the hero's side that dealt most of
##   the damage (Mob.party_share, the golden monster's rule) is paid
##   SkyIsleLoot.rare_drops, once a window per hero (profile.flags[RARE_FLAG]); jackpots
##   among them are told to the server (SkyIsleLoot.announce), and so is the kill.
## - Online it is one of the zone's shared monsters (EntitySync kind "rare"): the zone's
##   host spawns it, the others see its mirror (MirrorMob) with the same pillar, alert and
##   minimap mark, and a new host takes it over as it stands (Zone.adopt_shared).

const ID: StringName = &"prism_dragon"
## Mob meta: the window (WorldEvents.rare_now) this dragon belongs to.
const META := "rare_dragon"
## Over the field boss's stats (MonsterData.stats_for of zone.boss): a raid-lite fight for
## one ★300 hero in the field's gear. Raised at the owner's request: twice the health it
## had (2x the boss's, now 4x) and 2.5x the bite it had (0.85x the boss's attack before the
## Dragon God's own went up 5x, SkyIsleData.BOSS_ATK: 0.85 * 2.5 / 5 of it now). Its two
## lightning moves alternate from the first one, every SLAM_EVERY seconds (MonsterData
## "slam_every", BossAttack.start) instead of a field boss's 8.
const HP_SCALE := 4.0
const ATK_SCALE := 0.425
const SLAM_EVERY := 5.0
const EXP_SCALE := 3.0
## Without a field boss: this many times the camp's toughest monster.
const NO_BOSS_HP := 60.0
const PILLAR_HEIGHT := 46.0
const LABEL_RANGE := 70.0
const ALERT_SFX: StringName = &"cry_roar"
## World players that fight it at once, and the share of the damage they stop at
## (FieldPlayer._join_rare), so the prize stays with the hero that fights it.
const HELPERS := 2
const HELPER_SHARE := 0.35
const SHOUTS := ["มังกรแก้วเจ็ดสีมาแล้ว รุม!", "มังกรแก้วอยู่นี่ ช่วยกันตี!", "ระวังสายฟ้าของมังกรแก้ว หลบ!", "มังกรแก้วเจ็ดสี! อย่าให้หนี"]

const PRISM_SHADER := """
shader_type spatial;
render_mode unshaded;
varying vec3 world_pos;
vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Flat facets from the surface's own slope: every triangle a face of the crystal.
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float facing = abs(n.z);
	float band = dot(n, vec3(0.37, 0.61, 0.70)) * 1.25 + world_pos.y * 0.22 + TIME * 0.11;
	vec3 rainbow = hue(band);
	float rim = pow(1.0 - facing, 2.0);
	vec3 glass = mix(vec3(0.90, 0.97, 1.0), rainbow, 0.62) * (0.58 + 0.42 * facing);
	ALBEDO = glass + rainbow * rim * 0.55 + vec3(1.0) * pow(facing, 22.0) * 0.32;
}
"""
const PILLAR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float height = 46.0;
varying float up;
vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}
void vertex() {
	up = VERTEX.y / height + 0.5;
}
void fragment() {
	float core = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
	vec3 rainbow = hue(up * 1.4 - TIME * 0.22);
	ALBEDO = mix(vec3(0.72, 1.0, 0.93), rainbow, 0.5);
	ALPHA = core * (0.62 - 0.5 * up) * (0.85 + 0.15 * sin(TIME * 3.0 + up * 9.0));
}
"""

static var _prism: ShaderMaterial
static var _pillar: ShaderMaterial
static var _pillar_mesh: CylinderMesh
static var _ring_mesh: TorusMesh

var zone: Zone
## The dragon this game spawned (or took over), and the window it last spawned one for.
var mob: Mob
var window := -1
var _alerted := -1
var _in := 0.5
## The prizes paid in this zone, oldest first: {window, items} (tests).
var prizes: Array = []


## The zone's rare dragon node (made when the zone is flagged for one), or null.
static func attach(p_zone: Zone) -> RareDragon:
	if p_zone == null or not bool(p_zone.data.get("rare_dragon", false)):
		return null
	var old := of(p_zone)
	if old != null:
		return old
	var node := RareDragon.new()
	node.name = "RareDragon"
	node.zone = p_zone
	p_zone.add_child(node)
	return node


static func of(p_zone: Node) -> RareDragon:
	if p_zone == null or not is_instance_valid(p_zone):
		return null
	return p_zone.get_node_or_null("RareDragon") as RareDragon


## The living rare dragon of `p_zone` (this game's own or the host's mirror), or null.
static func live(p_zone: Node) -> Mob:
	var node := of(p_zone)
	return node.find() if node != null else null


func _process(delta: float) -> void:
	_in -= delta
	if _in > 0.0:
		return
	_in = 1.0
	tick()


## The living dragon in this zone, whoever hosts it.
func find() -> Mob:
	if mob != null and is_instance_valid(mob) and not mob.is_dead() and not mob.is_queued_for_deletion():
		return mob
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group("mobs"):
		var m := node as Mob
		if m != null and m.has_meta(META) and not m.is_dead() and not m.is_queued_for_deletion() and m.get_parent() == zone:
			return m
	return null


## Once a second: the alert when a dragon is seen, and (unless another player hosts the
## zone's monsters) its coming and going with the window.
func tick() -> void:
	if zone == null or not is_instance_valid(zone) or not zone.is_built or not Game.has_profile:
		return
	var seen := find()
	if seen != null and int(seen.get_meta(META, -1)) != _alerted:
		_alerted = int(seen.get_meta(META, -1))
		alert(seen)
	if zone.sync != null and zone.sync.is_mirror():
		mob = null
		return
	var event := WorldEvents.rare_now(WorldPresence.clock())
	if mob != null and is_instance_valid(mob) and not mob.is_dead() and not mob.is_queued_for_deletion():
		if event.is_empty() or int(event.window) != int(mob.get_meta(META, -1)):
			flee()
		return
	mob = null
	if event.is_empty() or zone._camps.is_empty():
		return
	var win := int(event.window)
	if win == window or WorldEvents.rare_done(win):
		return
	if int(Game.paragon().level) < int(zone.data.get("star", 0)):
		return
	spawn(win)


## The dragon of `win` comes to its camp.
func spawn(win: int) -> Mob:
	var camps: Array = zone._camps
	var camp: Dictionary = camps[WorldEvents.rare_camp(win, camps.size())]
	var roll := RandomNumberGenerator.new()
	roll.seed = hash("rarespot|%d" % win)
	var angle := roll.randf() * TAU
	var r := sqrt(roll.randf()) * maxf(0.5, float(camp.radius) * 0.5)
	var spot := Vector3(camp.pos.x + cos(angle) * r, 0, camp.pos.y + sin(angle) * r)
	var m := Mob.new()
	m.setup(ID, level_for(zone.data, camp), spot, zone.hero)
	tune(m, zone.data, true)
	m.set_meta(META, win)
	m.position = spot + Vector3(0, 0.3, 0)
	zone.add_child(m)
	dress(m)
	window = win
	mob = m
	_alerted = win
	alert(m)
	return m


static func level_for(data: Dictionary, camp: Dictionary) -> int:
	if data.has("boss"):
		return int(data.boss.get("level", 100))
	return int((camp.get("levels", [1, 1]) as Array)[1])


## Its strength in the field `data`: the field boss's stats (the toughest camp monster's
## without one) scaled by the constants above. `fresh`: also its HP (a mirror taken over
## keeps the HP it had).
static func tune(m: Mob, data: Dictionary, fresh: bool) -> void:
	var base: Dictionary
	var hp_scale := HP_SCALE
	if data.has("boss"):
		base = MonsterData.stats_for(StringName(data.boss.monster), int(data.boss.get("level", m.level)))
	else:
		base = m.stats
		for camp in data.get("camps", []):
			for id in camp.get("monsters", []):
				var s := MonsterData.stats_for(StringName(id), m.level)
				if int(s.hp) > int(base.hp) or base == m.stats:
					base = s
		hp_scale = NO_BOSS_HP
	m.stats = m.stats.duplicate()
	m.stats["hp"] = maxi(1, int(float(base.hp) * hp_scale))
	m.stats["atk"] = maxi(1, int(float(base.atk) * ATK_SCALE))
	m.stats["def"] = int(base.def)
	m.stats["exp"] = int(float(base.exp) * EXP_SCALE)
	m.stats["gold"] = int(float(base.gold) * EXP_SCALE)
	if fresh:
		m.max_hp = int(m.stats.hp)
		m.hp = m.max_hp


## Its look, on a Mob already in the tree (a real one or a mirror): crystal facets in
## rainbow colours over the whole rig, a name seen from afar, the pillar of light and a
## ring on the ground. One shared material each; nothing is made twice.
static func dress(m: Mob) -> void:
	if m == null or not is_instance_valid(m) or m.has_meta("rare_dressed"):
		return
	m.set_meta("rare_dressed", true)
	# The eastern crystal dragon (CelestialDragon "prism") is glass already: its own shader
	# turns its scales to rainbow facets. A rig (an old mirror) wears the crystal material.
	if m.visual != null and m.visual.model != null and not m.visual is CelestialDragonVisual:
		for node in m.visual.model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, prism_material())
	if m._label != null:
		m._label.modulate = WorldEvents.RARE_COLOR
		m._label.visibility_range_end = LABEL_RANGE
	var beacon := Node3D.new()
	beacon.name = "RareBeacon"
	m.add_child(beacon)
	var pillar := MeshInstance3D.new()
	pillar.name = "Pillar"
	pillar.mesh = _pillar_shape()
	pillar.material_override = pillar_material()
	pillar.position.y = PILLAR_HEIGHT * 0.5
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.extra_cull_margin = PILLAR_HEIGHT
	beacon.add_child(pillar)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = _ring_shape()
	ring.material_override = pillar_material()
	ring.position.y = 0.12
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(ring)


static func prism_material() -> ShaderMaterial:
	if _prism == null:
		var shader := Shader.new()
		shader.code = PRISM_SHADER
		_prism = ShaderMaterial.new()
		_prism.shader = shader
	return _prism


static func pillar_material() -> ShaderMaterial:
	if _pillar == null:
		var shader := Shader.new()
		shader.code = PILLAR_SHADER
		_pillar = ShaderMaterial.new()
		_pillar.shader = shader
		_pillar.set_shader_parameter("height", PILLAR_HEIGHT)
	return _pillar


static func _pillar_shape() -> CylinderMesh:
	if _pillar_mesh == null:
		_pillar_mesh = CylinderMesh.new()
		_pillar_mesh.top_radius = 0.7
		_pillar_mesh.bottom_radius = 1.5
		_pillar_mesh.height = PILLAR_HEIGHT
		_pillar_mesh.radial_segments = 12
		_pillar_mesh.rings = 1
		_pillar_mesh.cap_top = false
		_pillar_mesh.cap_bottom = false
	return _pillar_mesh


static func _ring_shape() -> TorusMesh:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 3.0
		_ring_mesh.outer_radius = 3.5
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 6
	return _ring_mesh


## The map-wide alert for the hero standing in the zone: the zone's banner, which names
## the camp, and a roar (the server-wide banner and chat line come from Announcer.tick).
func alert(m: Mob) -> void:
	var where := ""
	var best := INF
	for camp in zone._camps:
		var d := Vector2(m.global_position.x - float(camp.pos.x), m.global_position.z - float(camp.pos.y)).length() if m.is_inside_tree() else INF
		if d < best and String(camp.get("name", "")) != "":
			best = d
			where = String(camp.name)
	zone.banner_requested.emit(("%s อยู่ที่ %s! ตามลำแสงไป" % [WorldEvents.NAME_RARE, where]) if where != "" else ("%s ปรากฏตัวแล้ว! ตามลำแสงไป" % WorldEvents.NAME_RARE))
	AudioManager.play_sfx(ALERT_SFX, 2.0, 0.0)


## The window is over: it flies off.
func flee() -> void:
	if mob == null or not is_instance_valid(mob):
		mob = null
		return
	Game.say("%s บินหนีไปแล้ว!" % WorldEvents.NAME_RARE, &"info")
	VfxKit.flash(zone, mob.hit_point(), WorldEvents.RARE_COLOR, 3.0)
	mob.remove_from_group("mobs")
	if is_instance_valid(zone.hero) and zone.hero.target == mob:
		zone.hero.set_target(null)
	mob.queue_free()
	mob = null


## A new host of the zone took the dragon over from its mirror (Zone.adopt_shared).
func adopt(m: Mob) -> void:
	mob = m
	window = int(m.get_meta(META, -1))
	_alerted = window
	tune(m, zone.data, false)
	dress(m)


## It fell (Zone._on_mob_died, a real one or a mirror): the window is spent for this
## hero; the side that dealt most of the damage is paid, once a window.
func died(m: Mob) -> void:
	var win := int(m.get_meta(META, -1))
	var paid := WorldEvents.rare_done(win)
	Game.profile.flags[WorldEvents.RARE_FLAG] = win
	if not paid:
		DragonHunt.on_rare(m.party_share())
	Game.mark_dirty()
	if m == mob:
		mob = null
	var beacon := m.get_node_or_null("RareBeacon") as Node3D
	if beacon != null:
		beacon.visible = false
	if paid or m.party_share() < 0.5:
		Game.world_chat.emit(Announcer.SPEAKER, "%s ถูกปราบแล้ว!" % WorldEvents.NAME_RARE, WorldEvents.RARE_COLOR)
		return
	var from := m.global_position
	var drops: Array = SkyIsleLoot.rare_drops(Game.class_id(), zone._event_rng)
	prizes.append({"window": win, "items": drops})
	for item in drops:
		if not item is Dictionary or (item as Dictionary).is_empty():
			continue
		zone._spawn_loot(item, 0, from)
		if SkyIsleLoot.is_jackpot(item):
			SkyIsleLoot.announce(item)
	VfxKit.sparks(zone, from + Vector3(0, 1.4, 0), WorldEvents.RARE_COLOR, 40, 6.0, 1.0)
	zone.banner_requested.emit("ปราบ%sแล้ว!" % WorldEvents.NAME_RARE)
	Announcer.rare_slain()
