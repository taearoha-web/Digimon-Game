class_name Pierce
extends RefCounted
## Spear thrusts that run on through the monsters lined up behind the target.
## A skill opts in with  "pierce": {"n": extra victims, "len": reach, "w": half width, "k": damage kept per victim}.


## The extra monsters on the line from [param from] through [param through], nearest first.
static func victims(tree: SceneTree, from: Vector3, through: Vector3, spec: Dictionary, exclude: Node) -> Array[Mob]:
	var out: Array[Mob] = []
	var line := Vector3(through.x - from.x, 0.0, through.z - from.z)
	if line.length() < 0.05:
		return out
	var dir := line.normalized()
	var reach := float(spec.get("len", 6.0))
	var width := float(spec.get("w", 1.3))
	var found: Array = []
	for node in tree.get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob == null or mob == exclude or mob.is_dead():
			continue
		var rel := Vector3(mob.global_position.x - from.x, 0.0, mob.global_position.z - from.z)
		var along := rel.dot(dir)
		if along <= 0.0 or along > reach:
			continue
		if absf(rel.cross(dir).y) <= width + mob.body_radius():
			found.append([along, mob])
	found.sort_custom(func(a, b): return a[0] < b[0])
	for entry in found:
		if out.size() >= int(spec.get("n", 2)):
			break
		out.append(entry[1])
	return out
