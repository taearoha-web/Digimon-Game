class_name ItemLook
extends RefCounted
## What an item looks like. A look id picks a 3D model that the hero wears or
## holds and that is rendered into the inventory icon:
##   weapons "sword_5" "bow_3" "staff_9" "wand_0"  (WeaponKit, 12 designs each)
##   armor   "armor_<style>_<tier>"                (a stock outfit from the KayKit pack, tinted by tier)
##   helm    "helm_<0..11>"
##   boots / ring / amulet  "<slot>_<tier>"        (icons only)
## Items store no look: it is derived from slot, level and uid, so old saves work.

const ICON_DIR := "res://assets/icons/items/"
const ARMOR_STYLES := [["rogue", "rogue"], ["ranger", "rogue"], ["ranger", "barbarian"], ["barbarian", "mage"], ["knight", "mage"], ["knight", "knight"], ["knight", "mage"], ["mage", "knight"], ["knight", "knight"], ["knight", "mage"]]
const ARMOR_TINTS := [Color(1, 1, 1), Color(0.86, 1.06, 0.86), Color(0.85, 0.96, 1.25), Color(1.3, 1.1, 0.7), Color(1.15, 0.85, 1.3), Color(1.35, 0.8, 0.75),
		Color(1.1, 1.0, 1.45), Color(1.3, 1.22, 0.9), Color(1.3, 0.98, 0.68), Color(1.2, 1.12, 0.95)]
const CAPES := {
	"knight": ["Knight", "Knight_Cape"], "mage": ["Mage", "Mage_Cape"], "ranger": ["Ranger", "Ranger_Cape"], "rogue": ["Rogue", "Rogue_Cape"],
}
# helm designs: [part or proc, tint]
const HELMS := [
	{"proc": "cap", "tint": Color("c9a66b")},
	{"proc": "cap", "tint": Color("c0392b")},
	{"part": ["Barbarian", "Barbarian_BearHat"], "tint": Color(1, 1, 1)},
	{"proc": "bandana", "tint": Color("3e9a5a")},
	{"proc": "iron", "tint": Color("a9b2c0")},
	{"part": ["Knight", "Knight_Helmet"], "tint": Color(1.3, 0.9, 0.6)},
	{"part": ["Knight", "Knight_Helmet"], "tint": Color(1, 1, 1)},
	{"part": ["Mage", "Mage_Hat"], "tint": Color(0.8, 0.95, 1.4)},
	{"part": ["Mage", "Mage_Hat"], "tint": Color(1.7, 0.7, 0.5)},
	{"proc": "horned", "tint": Color("8a95a8")},
	{"proc": "crown", "tint": Color("ffc93c")},
	{"part": ["Mage", "Mage_Hat"], "tint": Color(1.9, 1.6, 0.35)},
	# Lv.61-70: thunder helms
	{"proc": "winged", "tint": Color("7a8aff")},
	{"part": ["Mage", "Mage_Hat"], "tint": Color(1.2, 1.2, 2.0)},
	# Lv.71-80: angel crowns
	{"proc": "winged", "tint": Color("ffe27a")},
	{"proc": "halo_crown", "tint": Color("fff0b0")},
	# Lv.81-90: war-god crowns
	{"proc": "flame_crown", "tint": Color("ff8a4a")},
	{"proc": "halo_crown", "tint": Color("ffb04a")},
	# Lv.91-100: eternal legend
	{"proc": "grand_crown", "tint": Color("e0b040")},
	{"proc": "grand_crown", "tint": Color("d89a30")},
]


const BOOT_TINTS := [Color(0.9, 0.75, 0.6), Color(0.85, 0.8, 0.7), Color(0.85, 0.9, 1.1), Color(0.7, 1.0, 0.8), Color(1.2, 0.7, 0.65), Color(0.95, 0.8, 1.2), Color(0.8, 0.85, 1.5), Color(1.5, 1.4, 1.0), Color(1.5, 1.0, 0.7), Color(1.7, 1.6, 1.4)]


static func tier_of(item: Dictionary) -> int:
	return _tier(item)


static func boots_tint(item: Dictionary) -> Color:
	return BOOT_TINTS[clampi(_tier(item), 0, 9)]


static func _tier(item: Dictionary) -> int:
	return ItemData.tier_for(int(item.get("level", 1)))


static func _variant(item: Dictionary) -> int:
	return hash(str(item.get("uid", ""))) & 1


static func _kind_of_base(base: String) -> String:
	return "bow" if base == "crossbow" else base


## Look id of an item (icon file name).
static func look_of(item: Dictionary) -> String:
	if item.get("kind", "") != "equip":
		return ""
	var slot: String = item.slot
	var tier := _tier(item)
	match slot:
		"weapon":
			return WeaponKit.look_for(_kind_of_base(str(item.get("base", "sword"))), tier, _variant(item))
		"armor":
			return "armor_%s_%d" % [ARMOR_STYLES[tier][_variant(item)], tier]
		"helm":
			return "helm_%d" % (tier * 2 + _variant(item))
		"wings":
			return "wings_%s" % String(item.get("wing", "atk"))
		_:
			return "%s_%d" % [slot, tier]


static func weapon_look(item: Variant, default_kind: StringName) -> String:
	if item is Dictionary:
		return look_of(item)
	return WeaponKit.look_for(_kind_of_base(String(default_kind)), 0, 0)


static func armor_look(item: Dictionary) -> Dictionary:
	var tier := _tier(item)
	var style: String = ARMOR_STYLES[tier][_variant(item)]
	return {"style": style, "tint": ARMOR_TINTS[tier], "cape": CAPES.get(style)}


static func helm_look(item: Dictionary) -> Dictionary:
	return HELMS[clampi(_tier(item) * 2 + _variant(item), 0, HELMS.size() - 1)]


static func icon(item: Dictionary) -> Texture2D:
	if item.get("kind", "") == "gem":
		return icon_for_id("gem_" + String(item.id).split("_")[0])
	if item.get("kind", "") == "potion":
		var pid := String(item.id)
		var path := "res://assets/icons/ui/heart_potion.svg" if pid.begins_with("hp") else ("res://assets/icons/ui/mana_potion.svg" if pid.begins_with("mp") else "res://assets/icons/ui/quest.svg")
		return load(path) as Texture2D
	var id := look_of(item)
	if id == "":
		return null
	if id.begins_with("wings_"):
		return wing_icon(id.trim_prefix("wings_"))
	return icon_for_id(id)


static var _wing_icons := {}


## A pair of wings drawn into a 128px icon (no art file needed).
static func wing_icon(kind: String) -> Texture2D:
	if _wing_icons.has(kind):
		return _wing_icons[kind]
	var info: Dictionary = ItemData.WING_INFO.get(kind, ItemData.WING_INFO["atk"])
	var main: Color = info.color
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var count := 5 if kind != "def" else 6
	for side in [-1.0, 1.0]:
		for k in count:
			var angle := deg_to_rad(18.0 + k * 15.0)
			var length := 52.0 * (0.62 + 0.38 * float(k) / float(count - 1))
			var tint: Color = main.lightened(0.35) if k % 2 == 0 else main.darkened(0.15)
			var steps := int(length)
			for i in steps:
				var t := float(i) / float(steps)
				var x: float = 64.0 + side * (sin(angle) * length * t + 5.0)
				var y: float = 84.0 - cos(angle) * length * t
				var radius := (6.5 if kind == "def" else 5.0) * (1.0 - t * 0.7)
				_stamp(img, x, y, radius, tint.lerp(Color.WHITE, t * 0.2))
	var tex := ImageTexture.create_from_image(img)
	_wing_icons[kind] = tex
	return tex


static func _stamp(img: Image, cx: float, cy: float, radius: float, color: Color) -> void:
	for yy in range(int(cy - radius), int(cy + radius) + 1):
		for xx in range(int(cx - radius), int(cx + radius) + 1):
			if xx < 0 or yy < 0 or xx >= 128 or yy >= 128:
				continue
			if Vector2(xx - cx, yy - cy).length() <= radius:
				img.set_pixel(xx, yy, color)


static func icon_for_id(id: String) -> Texture2D:
	var path := ICON_DIR + id + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func all_icon_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.append_array(WeaponKit.all_looks())
	for tier in 10:
		for style in ["rogue", "ranger", "barbarian", "mage", "knight"]:
			if style in ARMOR_STYLES[tier]:
				ids.append("armor_%s_%d" % [style, tier])
	for i in HELMS.size():
		ids.append("helm_%d" % i)
	for kind in ["boots", "ring", "amulet"]:
		for tier in 10:
			ids.append("%s_%d" % [kind, tier])
	for gem_id in ItemData.GEMS:
		ids.append("gem_" + gem_id)
	return ids


## The Node3D rendered for an icon, oriented so it reads well from the front.
static func build_icon_node(id: String) -> Node3D:
	var kind := id.rsplit("_", true, 1)[0]
	var holder := Node3D.new()
	if kind in WeaponKit.KINDS:
		var w := WeaponKit.build(id)
		holder.add_child(w)
		if kind == "bow":
			w.rotation_degrees = Vector3(90, 0, 0)
		else:
			holder.rotation_degrees = Vector3(0, 0, -38)
		if (kind == "staff" or kind == "spear") and not WeaponKit.has_model(kind):
			holder.set_meta("frame", Vector3(0.5, 0.65, 1.9))
		return holder
	if id.begins_with("armor_"):
		var bits := id.split("_")
		var tint: Color = ARMOR_TINTS[int(bits[2])]
		var glb := {"knight": "Knight", "mage": "Mage", "rogue": "Rogue", "barbarian": "Barbarian", "ranger": "Ranger"}[bits[1]] as String
		_add_mesh_part(holder, glb, "%s_Body" % glb, tint)
		var flourish := GearKit.armor_flourish(int(bits[2]))
		flourish.position = Vector3(0, 0.9, 0)
		holder.add_child(flourish)
		return holder
	if id.begins_with("helm_"):
		# Shown on a head so the shape reads; hats are in head-bone space (bone at y 1.24).
		var spec: Dictionary = HELMS[int(id.split("_")[1])]
		_add_mesh_part(holder, "Knight", "Knight_Head", Color.WHITE)
		var hat_holder := Node3D.new()
		hat_holder.position = Vector3(0, 1.24, 0)
		holder.add_child(hat_holder)
		if spec.has("part"):
			var part := HeroParts.get_part(spec.part[0], spec.part[1])
			if part.kind == "skinned":
				_add_mesh_part(holder, spec.part[0], spec.part[1], spec.tint)
			else:
				_add_mesh_part(hat_holder, spec.part[0], spec.part[1], spec.tint)
		else:
			hat_holder.add_child(GearKit.hat(spec.proc, spec.tint))
		return holder
	if id.begins_with("gem_"):
		holder.add_child(GearKit.gem(id.trim_prefix("gem_")))
		return holder
	for slot in ["boots", "ring", "amulet"]:
		if id.begins_with(slot + "_"):
			holder.add_child(GearKit.trinket(slot, int(id.split("_")[1])))
			if slot == "boots":
				holder.rotation_degrees = Vector3(12, -50, 0)
			return holder
	return null


static func _add_mesh_part(parent: Node3D, glb: String, node_name: String, tint: Color) -> void:
	var part := HeroParts.get_part(glb, node_name)
	if part.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = part.mesh
	if part.kind == "attach":
		mi.transform = part.xform
	for i in mi.mesh.get_surface_count():
		var source := mi.mesh.surface_get_material(i) as StandardMaterial3D
		if source:
			var copy := source.duplicate() as StandardMaterial3D
			copy.albedo_color = source.albedo_color * tint
			mi.set_surface_override_material(i, copy)
	parent.add_child(mi)
