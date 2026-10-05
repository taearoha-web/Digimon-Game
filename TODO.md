# TODO

## Now (high value)
- [ ] Test on a physical Android device: touch feel (joystick size/dead zone,
      camera sensitivity), FPS on Low/Medium/High, safe-area insets, back button

## Gameplay
- [ ] Zone 3 (e.g. a mountain or data city) reachable from the Data Forest
- [ ] Chip upgrades / rarer chips as battle drops
- [ ] Nickname prompt when a Digimon joins
- [ ] "Forget a skill" prompt when learning a 5th skill while 4 are equipped
- [ ] Trainer/NPC battles (BattleRequest.is_wild = false already supported)
- [ ] More quests (daily training, recruit a specific species, reach Lv 10)
- [ ] Ultimate/Mega stages for starter lines
- [ ] Friendship-based evolution branches (requirements already supported)
- [ ] Day/night tint and ambient creatures

## Presentation
- [x] Replace placeholder Digimon models with real art (Quaternius CC0)
- [ ] Replace the procedural player/NPC avatars and world scenery with real art
- [ ] Proper portrait icons for species (`DigimonSpecies.icon_path`)
- [ ] Footstep / ambient loops, per-skill SFX variety
- [ ] Camera auto-recentre option while moving
- [ ] Minimap

## Tech
- [ ] Localisation: extract UI strings to CSV/PO, language option in Settings
- [ ] Merge static placeholder meshes per character to cut draw calls further
- [ ] CI job running `tests/test_runner.tscn` and the vertical slice test
- [ ] Profile navmesh bake time on device (consider pre-baked navmesh)

## Done (session 1)
- [x] Phases 1–18 of DEVELOPMENT_PLAN.md (see PROJECT_STATUS.md)
- [x] Zone 2 "Data Forest" behind the Gateway (builder, scene, quest, spawns, music)
- [x] Shops (Pip in the plaza, Lumi in the forest) — Data Coins sink
- [x] Equipment chips (Gear tab, detail view, saved per Digimon)
- [x] Per-map battle arena palettes
