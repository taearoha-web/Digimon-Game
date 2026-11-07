class_name PetCrowd
extends Node
## Everyone else's pets in a zone (the hero's own is Zone.pet): every AI player has a pet
## (PetData.of_player: a world player, a member of the hero's party) and real online
## players show the one their game sent (RemotePlayer, Online `pet`). This one node gives
## each of them its pet, on a phone budget:
##   - only the CAP nearest owners within VIEW metres of the hero have a pet out (the
##     hero's party always first); one farther than HIDE, or pushed out of the nearest,
##     puts it away. At most BUILD_PER_TICK new pets a tick, so a crowd walking in does
##     not cost one long frame.
##   - where its owner fights (a field, the tower, the raid: a world player hunting, a
##     party member) it is a Pet in "lite" form: it fights what the owner fights, scaled
##     to the owner's level like the hero's pet, without effects, words or sounds, and
##     monsters leave it alone (no health bar, it never falls).
##   - where nobody fights (the village) and for pictures of other games' players (online
##     players, mirrored world players) it is a PetFollower: a model and a follow-lerp.
##     Put-away followers are kept (a few per pet) and handed out again.
## No pets at all where PetData.allowed_in says none come (the duels, the guild war): the
## zone does not make a crowd there. It lives in the zone and goes with it.

## Within this many metres of the hero an owner may get its pet out; a pet farther than
## HIDE is put away (and is not drawn past it either).
const VIEW := 34.0
const HIDE := 40.0
## Most other players' pets out at once, by graphics quality; fewer under memory pressure.
const CAPS := [6, 10, 12]
const PRESSURE_CAPS := [6, 4]
## Seconds between two looks at who is around, and new pets per look.
const EVERY := 0.3
const BUILD_PER_TICK := 2
## Metres of head start a pet already out has in the ranking.
const KEEP_EDGE := 3.0
## Spare followers kept per pet.
const SPARES := 3

const FOLLOW := 0
const FIGHT := 1

## Off (tests, measurements): no other players' pets anywhere.
static var enabled := true

var zone: Zone
## Owner instance id -> {owner (WeakRef), id, mode, pet (Node3D or null)}.
var entries: Dictionary = {}
var _spares: Dictionary = {}
var _timer := 0.0


func setup(p_zone: Zone) -> void:
	zone = p_zone
	name = "PetCrowd"


## A real player's pet fights on its owner's game; the `pet_act` it sends shows here on
## the follower (PetSync, PetFollower.act): pictures only, never damage.
func _enter_tree() -> void:
	if not Online.message.is_connected(_on_online):
		Online.message.connect(_on_online)


func _exit_tree() -> void:
	if Online.message.is_connected(_on_online):
		Online.message.disconnect(_on_online)


func _on_online(type: String, data: Dictionary) -> void:
	if type != "pet_act" or zone == null or not is_instance_valid(zone):
		return
	var a := PetSync.parse(data, zone.zone_id)
	if a.is_empty():
		return
	var who := Online.remote_node(String(a.from))
	if who == null:
		return
	var f := pet_for(who) as PetFollower
	if f != null:
		f.act(a)


## The pet [param who] walks with: a party member's or world player's from its sheet
## (member "pet", else picked from its name), an online player's from its state; "" for none.
static func pet_of(who: Node) -> String:
	if who is RemotePlayer:
		return PetData.clean_id((who as RemotePlayer).player.get("pet", ""))
	if who is Companion:
		var m: Dictionary = (who as Companion).member
		var id := PetData.clean_id(m.get("pet", ""))
		return id if id != "" else PetData.of_player(String(m.get("name", "")))
	return ""


## The most pets out at once here and now.
static func cap() -> int:
	var c := int(CAPS[clampi(GameSettings.quality, 0, 2)])
	if MemoryGuard.pressure > 0:
		c = mini(c, int(PRESSURE_CAPS[clampi(MemoryGuard.pressure - 1, 0, 1)]))
	return c


## The pet out with [param who] now (a Pet or a PetFollower), null for none.
func pet_for(who: Node) -> Node3D:
	var e: Dictionary = entries.get(who.get_instance_id(), {})
	var pet: Variant = e.get("pet")
	return pet as Node3D if pet != null and is_instance_valid(pet) else null


## How [param who] gets its pet here: fighting along or only following.
func mode_for(who: Node) -> int:
	if zone.is_town or who is RemotePlayer or (who is FieldPlayer and (who as FieldPlayer).puppet):
		return FOLLOW
	return FIGHT


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = EVERY
	refresh()


## Looks at who is around and gives out / puts away pets (the crowd does this every EVERY
## seconds; tests call it to see the result at once).
func refresh(build_all := false) -> void:
	if not enabled or zone == null or not is_instance_valid(zone.hero):
		_release_all()
		return
	var from := zone.hero.global_position
	var seen := {}
	var ranked: Array = []
	for group in ["companions", "world_players", "remote_players"]:
		for node in get_tree().get_nodes_in_group(group):
			var who := node as Node3D
			if who == null or seen.has(who) or who is Hero or who is GuildFighter or who.is_queued_for_deletion():
				continue
			seen[who] = true
			var id := pet_of(who)
			if id == "" or not who.visible or not who.is_inside_tree():
				continue
			var d := Vector2(who.global_position.x - from.x, who.global_position.z - from.z).length()
			var key := who.get_instance_id()
			var has_pet := pet_for(who) != null
			# The hero's party has its pets out wherever its members are.
			var first := (who is Companion and zone.companions.has(who as Companion)) or (who is RemotePlayer and (who as RemotePlayer).in_party)
			if d > (HIDE if has_pet else VIEW) and not first:
				continue
			# A pet already out keeps its place against one a few metres nearer (no flicker
			# at the edge of the CAP nearest).
			var score := -1.0 if first else d - (KEEP_EDGE if has_pet else 0.0)
			ranked.append({"who": who, "id": id, "key": key, "score": score})
	ranked.sort_custom(func(a, b): return float(a.score) < float(b.score))
	var keep := {}
	var built := 0
	for k in mini(cap(), ranked.size()):
		var r: Dictionary = ranked[k]
		var who: Node3D = r.who
		var mode := mode_for(who)
		var e: Dictionary = entries.get(r.key, {})
		var pet: Node3D = pet_for(who)
		if pet != null and (int(e.get("mode", -1)) != mode or String(e.get("id", "")) != String(r.id)):
			_release(e)
			pet = null
		if pet == null:
			if built >= BUILD_PER_TICK and not build_all:
				continue
			built += 1
			pet = _make(who, String(r.id), mode)
		entries[r.key] = {"owner": weakref(who), "id": r.id, "mode": mode, "pet": pet}
		keep[r.key] = true
	for key in entries.keys():
		if not keep.has(key):
			_release(entries[key])
			entries.erase(key)


func _make(who: Node3D, id: String, mode: int) -> Node3D:
	if mode == FIGHT:
		var pet := Pet.new()
		pet.setup_pet(who, id)
		zone.add_child(pet)
		return pet
	var spare: Array = _spares.get(id, [])
	var f: PetFollower = null
	while not spare.is_empty() and f == null:
		var s: Variant = spare.pop_back()
		if s != null and is_instance_valid(s):
			f = s
	if f == null:
		f = PetFollower.new()
		zone.add_child(f)
		f.build(id)
	f.attach(who)
	return f


func _release(e: Dictionary) -> void:
	var pet: Variant = e.get("pet")
	if pet == null or not is_instance_valid(pet):
		return
	if pet is PetFollower:
		var f := pet as PetFollower
		var spare: Array = _spares.get(f.pet_id, [])
		spare = spare.filter(func(s): return s != null and is_instance_valid(s))
		if spare.size() < SPARES:
			f.detach()
			spare.append(f)
			_spares[f.pet_id] = spare
			return
	(pet as Node).queue_free()


func _release_all() -> void:
	for key in entries:
		_release(entries[key])
	entries.clear()


## Pets out now (followers and fighting ones), and how many fight.
func out_count() -> int:
	var n := 0
	for key in entries:
		if pet_for_entry(entries[key]) != null:
			n += 1
	return n


func pet_for_entry(e: Dictionary) -> Node3D:
	var pet: Variant = e.get("pet")
	return pet as Node3D if pet != null and is_instance_valid(pet) else null
