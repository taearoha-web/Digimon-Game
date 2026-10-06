class_name Minimap
extends Control
## Round radar in the corner: the hero in the middle, monsters (red), the boss
## (big gold), your companion (cyan), portals (blue) and villagers (yellow).
## The map turns with the camera so "up" is where you are looking.

const RADIUS := 66.0
const WORLD_RADIUS := 34.0

var zone: Zone
var _timer := 0.0


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
	if zone == null or not is_instance_valid(zone) or zone.hero == null:
		return
	var origin := zone.hero.global_position
	var yaw := zone.camera_rig.yaw if zone.camera_rig else 0.0
	for camp in zone._camps:
		var p := _to_map(Vector3(camp.pos.x, 0, camp.pos.y), origin, yaw)
		if p.length() < RADIUS * 1.6:
			draw_arc(c + p, float(camp.radius) * RADIUS / WORLD_RADIUS, 0, TAU, 24, Color(0.5, 1.0, 0.6, 0.35), 1.5, true)
	for portal in zone.portals:
		_dot(c, _to_map(portal.pos, origin, yaw), Color("5ad0ff"), 5.0, true)
	for npc in zone.npcs:
		_dot(c, _to_map(npc.global_position, origin, yaw), Color("ffd84a"), 3.5)
	for node in zone.get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and not mob.is_dead():
			_dot(c, _to_map(mob.global_position, origin, yaw), Color("ffcf3a") if mob.is_boss else (Color("ff5a5a") if mob.hostile else Color("c46a6a")), 6.0 if mob.is_boss else 3.0)
	for buddy in zone.companions:
		if is_instance_valid(buddy):
			_dot(c, _to_map(buddy.global_position, origin, yaw), Color("5af0ff") if not buddy.is_dead() else Color("667788"), 4.0)
	# The hero: an arrow showing where they face relative to the camera.
	var facing := zone.hero._facing - yaw
	var dir := Vector2(sin(facing), -cos(facing))
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([c + dir * 8.0, c - dir * 5.0 + side * 5.0, c - dir * 5.0 - side * 5.0]), Color("ffffff"))


func _dot(c: Vector2, p: Vector2, color: Color, r: float, diamond := false) -> void:
	if p.length() > RADIUS - r:
		p = p.normalized() * (RADIUS - r)   # keep far things on the rim
		color.a = 0.6
	if diamond:
		draw_colored_polygon(PackedVector2Array([c + p + Vector2(0, -r), c + p + Vector2(r, 0), c + p + Vector2(0, r), c + p + Vector2(-r, 0)]), color)
	else:
		draw_circle(c + p, r, color)
