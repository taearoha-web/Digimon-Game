class_name Minimap
extends Control
## Round radar in the corner: the hero in the middle, monsters (red), the boss
## (big gold), the golden monster (gold), your companion (cyan), portals (blue) and villagers (yellow);
## in the village each district's outline in its own colour.
## The map turns with the camera so "up" is where you are looking.

const RADIUS := 66.0
const WORLD_RADIUS := 34.0

var zone: Zone
var _timer := 0.0
## What the last draw put down, [position in this control, radius] each (tests check
## that every marker stays inside the round map).
var drawn: Array = []


func _init() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0 + 8.0, RADIUS * 2.0 + 8.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 and visible:
		_timer = 0.12
		queue_redraw()


func _to_map(world: Vector3, origin: Vector3, yaw: float) -> Vector2:
	var rel := world - origin
	var basis := Basis(Vector3.UP, yaw)
	var right := basis * Vector3.RIGHT
	var forward := basis * Vector3(0, 0, -1)
	return Vector2(rel.dot(right), -rel.dot(forward)) * (RADIUS / WORLD_RADIUS)


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, RADIUS + 3.0, Color(0.02, 0.04, 0.12, 0.35))
	draw_circle(c, RADIUS, Color(0.06, 0.1, 0.22, 0.55))
	draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.7), 2.5, true)
	drawn.clear()
	if zone == null or not is_instance_valid(zone) or zone.hero == null:
		return
	var origin := zone.hero.global_position
	var yaw := zone.camera_rig.yaw if zone.camera_rig else 0.0
	for camp in zone._camps:
		var p := _to_map(Vector3(camp.pos.x, 0, camp.pos.y), origin, yaw)
		_ring(c, p, float(camp.radius) * RADIUS / WORLD_RADIUS, Color(0.5, 1.0, 0.6, 0.35))
	if zone.is_town:
		for district in JapanVillage.DISTRICTS:
			_district(c, district, origin, yaw)
	for portal in zone.portals:
		_dot(c, _to_map(portal.pos, origin, yaw), Color("5ad0ff"), 5.0, true)
	var pet_quest := zone.is_town and PetData.quest_open(Game.profile)
	for npc in zone.npcs:
		# The pet keeper while the starter quest is open: a big orange diamond (kept on the rim
		# when far, so it shows the way).
		if pet_quest and npc.role == "pet":
			_dot(c, _to_map(npc.global_position, origin, yaw), Color("ff9a3a"), 6.0, true)
		else:
			_dot(c, _to_map(npc.global_position, origin, yaw), Color("ffd84a"), 3.5)
	for node in zone.get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and not mob.is_dead():
			var mark := mob_marker(mob)
			_dot(c, _to_map(mob.global_position, origin, yaw), mark[0], mark[1])
	for buddy in zone.companions:
		if is_instance_valid(buddy):
			_dot(c, _to_map(buddy.global_position, origin, yaw), Color("5af0ff") if not buddy.is_dead() else Color("667788"), 4.0)
	for node in zone.get_tree().get_nodes_in_group("world_players"):
		var other := node as FieldPlayer
		if other and other.visible and not other.is_dead():
			_dot(c, _to_map(other.global_position, origin, yaw), WorldPlayers.GUILD_COLORS.get(WorldPlayers.guild_at(other.world_index, int(other.member.level)), Color.WHITE), 3.5)
	# The castle siege: the altar (in its holder's colour) is always on the map, on the rim when far.
	if zone.gw_match != null:
		_dot(c, _to_map(SiegeArena.ALTAR, origin, yaw), zone.gw_match._owner_color(), 7.0, true)
		# Every other guild's leader in its crown's colour, on the rim when far: the ones to hunt down.
		for t in range(1, zone.gw_match.team_count()):
			var lead: GuildFighter = zone.gw_match.ai_leader(t)
			if lead != null and is_instance_valid(lead) and not lead.is_dead():
				_dot(c, _to_map(lead.global_position, origin, yaw), LeaderMark.guild_color(t), 6.5, true)
		# Ours when the player picked a member to lead it: the one to keep alive.
		var ours: GuildFighter = zone.gw_match.ally_leader
		if ours != null and is_instance_valid(ours) and not ours.is_dead():
			_dot(c, _to_map(ours.global_position, origin, yaw), LeaderMark.guild_color(GuildFighter.TEAM_ALLY), 6.0, true)
	# The hero: an arrow showing where they face relative to the camera.
	var facing := zone.hero._facing - yaw
	var dir := Vector2(sin(facing), -cos(facing))
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([c + dir * 8.0, c - dir * 5.0 + side * 5.0, c - dir * 5.0 - side * 5.0]), Color("ffffff"))
	if zone.day_night != null:
		_draw_clock(c)


## The world's time of day on a small pill at the foot of the map (zones that follow the
## clock, DayNight): a drawn sun or crescent moon, then "เช้า 07:30" and the like.
func _draw_clock(c: Vector2) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var h := DayNight.hour()
	var text := "%s %s" % [DayNight.phase_label(h), DayNight.clock_text(h)]
	var font_size := 12
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pill := Rect2(c.x - (width + 22.0) * 0.5, c.y + RADIUS - 13.0, width + 22.0, 17.0)
	draw_rect(pill, Color(0.03, 0.05, 0.14, 0.78))
	var icon := pill.position + Vector2(8.5, 8.5)
	var night := DayNight.phase(h) == &"night"
	if night:
		draw_circle(icon, 5.0, Color("f4ecc8"))
		draw_circle(icon + Vector2(2.4, -1.6), 4.2, Color(0.03, 0.05, 0.14, 1.0))
	else:
		draw_circle(icon, 4.2, Color("ffcf4a") if DayNight.phase(h) == &"day" else Color("ff9c52"))
	var at := Vector2(pill.position.x + 17.0, pill.position.y + 13.0)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("e8efff") if night else Color("fff4dc"))


## A monster's dot, [colour, radius]: the boss big gold, the golden monster (มอนทองคำ,
## WorldEvents) a bright gold dot, others red (darker while not hostile).
static func mob_marker(mob: Mob) -> Array:
	if mob.has_meta("golden"):
		return [WorldEvents.GOLDEN_COLOR, 5.0]
	if mob.is_boss:
		return [Color("ffcf3a"), 6.0]
	return [Color("ff5a5a") if mob.hostile else Color("c46a6a"), 3.0]


## A hunting camp's ring, only the part that lies inside the round map (a camp near
## the edge shows as an arc; one beyond it is not drawn).
func _ring(c: Vector2, p: Vector2, ring_r: float, color: Color) -> void:
	var inner := RADIUS - 2.5
	if p.length() - ring_r >= inner:
		return
	var run := PackedVector2Array()
	for i in 33:
		var q := p + Vector2.from_angle(TAU * float(i) / 32.0) * ring_r
		if q.length() <= inner:
			run.append(c + q)
			drawn.append([c + q, 0.75])
			continue
		if run.size() >= 2:
			draw_polyline(run, color, 1.5, true)
		run.clear()
	if run.size() >= 2:
		draw_polyline(run, color, 1.5, true)


## A village district's outline (its rect, or the plaza's circle), only where it lies
## inside the round map.
func _district(c: Vector2, district: Dictionary, origin: Vector3, yaw: float) -> void:
	var world := PackedVector2Array()
	if district.has("radius"):
		var centre: Vector2 = district.center
		for i in 33:
			world.append(centre + Vector2.from_angle(TAU * float(i) / 32.0) * float(district.radius))
	else:
		var r: Rect2 = district.rect
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for k in 4:
			var a: Vector2 = corners[k]
			var b: Vector2 = corners[k + 1]
			var steps := maxi(1, int(a.distance_to(b) / 3.0))
			for i in steps:
				world.append(a.lerp(b, float(i) / float(steps)))
		world.append(r.position)
	var points := PackedVector2Array()
	for w in world:
		points.append(_to_map(Vector3(w.x, 0, w.y), origin, yaw))
	_clipped(c, points, Color(district.color, 0.6), 2.0)


## Draws a map-space polyline, only the parts inside the round map.
func _clipped(c: Vector2, points: PackedVector2Array, color: Color, width: float) -> void:
	var inner := RADIUS - 2.5
	var run := PackedVector2Array()
	for q in points:
		if q.length() <= inner:
			run.append(c + q)
			drawn.append([c + q, 0.75])
			continue
		if run.size() >= 2:
			draw_polyline(run, color, width, true)
		run.clear()
	if run.size() >= 2:
		draw_polyline(run, color, width, true)


func _dot(c: Vector2, p: Vector2, color: Color, r: float, diamond := false) -> void:
	if p.length() > RADIUS - r - 1.0:
		p = p.normalized() * (RADIUS - r - 1.0)   # keep far things on the rim
		color.a = 0.6
	drawn.append([c + p, r])
	if diamond:
		draw_colored_polygon(PackedVector2Array([c + p + Vector2(0, -r), c + p + Vector2(r, 0), c + p + Vector2(0, r), c + p + Vector2(-r, 0)]), color)
	else:
		draw_circle(c + p, r, color)
