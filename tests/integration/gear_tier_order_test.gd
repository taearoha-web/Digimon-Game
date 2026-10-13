extends Node
## Star gear is graded by its tier, not by luck: in every slot and every stat the
## weakest piece of a tier beats the best piece of the tier below (50 < 100 <
## 150 < 200 stars), and the class set from the Lotus Sanctum beats the best
## 200-star piece in every stat. The sanctum set stays the rarest drop (0.5%).
##   godot --headless --path . res://tests/integration/gear_tier_order_test.tscn
var failures := 0
var checks := 0
const SAMPLES := 600
const STAT_KEYS := ["atk", "def", "hp", "mp", "crit"]


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## Per stat: [lowest, highest] over many rolls. Casters' matk counts as attack.
func _range(make: Callable) -> Dictionary:
	var lo := {}
	var hi := {}
	for i in SAMPLES:
		var stats: Dictionary = make.call().stats
		for key in STAT_KEYS:
			var value := float(stats.get(key, 0)) + (float(stats.get("matk", 0)) if key == "atk" else 0.0)
			lo[key] = minf(float(lo.get(key, INF)), value)
			hi[key] = maxf(float(hi.get(key, -INF)), value)
	return {"lo": lo, "hi": hi}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for cls in ClassData.IDS:
		for slot in ItemData.SLOTS:
			var ranges := {}
			for stars in StarProgression.TIERS:
				ranges[stars] = _range(func(): return StarProgression.item(cls, stars, slot, rng))
			for t in range(1, 4):
				var lower: Dictionary = ranges[StarProgression.TIERS[t - 1]]
				var higher: Dictionary = ranges[StarProgression.TIERS[t]]
				for key in STAT_KEYS:
					check(float(higher.lo[key]) > float(lower.hi[key]),
						"%s %s %s: %d* weakest %.3f beats %d* best %.3f" % [cls, slot, key, StarProgression.TIERS[t], higher.lo[key], StarProgression.TIERS[t - 1], lower.hi[key]])
			# The older random gear (up to Lv.100 + 20 stars, mythic included) is
			# below the weakest 50-star piece in every defining stat of the slot.
			var legacy := _range(func(): return ItemData.generate(rng.randi_range(1, StarProgression.LEGACY_TOP_LEVEL), cls, rng, 4, slot))
			var top_legacy := _range(func(): return ItemData.generate(StarProgression.LEGACY_TOP_LEVEL, cls, rng, 4, slot))
			for key in StarProgression.DEFINING[slot]:
				var ceiling := StarProgression.legacy_ceiling(slot, key)
				check(float(ranges[50].lo[key]) > ceiling, "%s %s %s: 50* weakest %.3f beats the older gear's best possible %.3f" % [cls, slot, key, ranges[50].lo[key], ceiling])
				check(float(ranges[50].lo[key]) > float(legacy.hi[key]) and float(ranges[50].lo[key]) > float(top_legacy.hi[key]), "%s %s %s: 50* beats sampled Lv.120 mythic" % [cls, slot, key])
			if slot in DivineGearData.SLOTS:
				var divine := _range(func(): return DivineGearData.item(cls, slot, rng))
				for key in STAT_KEYS:
					check(float(divine.lo[key]) > float(ranges[200].hi[key]),
						"%s %s %s: class set weakest %.3f beats 200* best %.3f" % [cls, slot, key, divine.lo[key], ranges[200].hi[key]])
	# Mythic (red) star pieces exist, are rare, and keep their tier's ordering:
	# the sweeps above already include them, so check that they really appear.
	var mythic := 0
	var total := 0
	for stars in StarProgression.TIERS:
		for i in 1500:
			var piece := StarProgression.item(&"warrior", stars, "weapon", rng)
			total += 1
			if int(piece.rarity) == ItemData.RARITY_NAMES.size() - 1:
				mythic += 1
				check(int(piece.sockets) == ItemData.sockets_for(4), "mythic star piece has three sockets")
			else:
				check(int(piece.rarity) == 3, "other star pieces stay legendary")
	var share := float(mythic) / float(total)
	check(share > 0.05 and share < 0.11, "about 8%% of star pieces are mythic (%.3f)" % share)
	check(is_equal_approx(DivineGearData.drop_chance(false), 0.005), "the class set drops from an ordinary enemy only 0.5%")
	check(DivineGearData.drop_chance(false) < Zone.STAR_GEAR_NORMAL / 10.0, "rarer than a star-tier piece by far")
	print("GEAR TIER ORDER: ", "PASS" if failures == 0 else "FAIL", " | ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)
