# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [0.2.0] — 2026-09-25 — Second zone, shops and equipment

### Added
- **Data Forest** (zone 2) behind the Starter Zone Gateway: procedural
  `DataForestBuilder` (crystal trees, glowing mushrooms, Crystal Lake with
  crystal spires and lily pads, Old Ruins with a monolith, Ranger Camp,
  groves, fireflies), return gateway, 3 signs, 7 pickups, 6 area triggers,
  3 encounter spawners (`forest_grove`, `old_ruins`: Lv 6–11 incl. rare
  Champions), forest music and a forest battle-arena palette.
- **Lumi** (Forest Ranger): new quest *Forest Survey* (visit the lake and the
  ruins, win 3 battles) and the *Ranger Supplies* shop.
- **Shops:** `ShopData` resources (`data/shops/`), `ShopService` (buy/sell
  rules), `ShopPanel` (Buy/Sell tabs, quantity, totals). NPC service
  `&"shop"` opens after small talk only. New vendor **Pip** in the plaza.
  Items now have `buy_price` and `sell_price` (half price).
- **Equipment chips:** new `EQUIPMENT` item category and 5 chips (Power,
  Guard, Speed, Focus, Vital). One chip per Digimon (`held_item_id`, saved);
  bonuses apply to stats in and out of battle. Equip from the Inventory
  *Gear* tab or from the Digimon details (Equip / Swap / Remove). Byte's
  quest now rewards a Power Chip.
- `ZoneBuilderBase` (shared terrain/boundary/scatter/prop toolkit) and
  `tools/zone_scene_kit.gd` (shared scene-assembly helpers) so new zones are
  one builder + one layout script.
- Tests: `test_equipment_and_shop.gd` (5 tests), data-integrity checks for
  shops, equipment bonuses, portal targets/spawns, map music and spawner
  tables; the vertical-slice test now also covers the shop, equipping a chip,
  travelling to the Data Forest, Lumi's quest and travelling back.
- Screenshot tour `forest`.

### Changed
- `tools/generate_data.gd` only creates missing resources by default
  (`-- --update=<path token>` / `-- --overwrite` to rewrite), so editor edits
  are never lost.
- Pause/menu requests are ignored while dialogue, popups or a battle
  transition are active; HUD badge and HP-bar tint are cached.
- Battle arenas take their palette from `MapData.battle_arena`.
- Integration test fights a Biyomon (Patamon has the type edge) and disables
  ambient encounters while it drives the flow, so it is deterministic.
- Inventory tabs sit in a single row (Items / Gear / Evo / Quest / Key).

### Fixed
- `.gitignore` rule `data_*/` also ignored `maps/data_forest/`; it is now
  anchored to the project root (`/data_*/`).

## [0.1.0] — 2026-09-25 — First playable vertical slice

### Added
- **Foundation:** Godot 4.3+ project (Compatibility renderer, landscape,
  1280×720 base with expand aspect), autoloads (EventBus, Settings, GameData,
  GameState, SaveManager, AudioManager, SceneManager, QuestManager),
  continuity docs, `.gitignore`, export presets (Android, iOS).
- **Data:** resource classes and 100 `.tres` files — 19 species (3 starters,
  their Champions, 5 wild Rookies + Champions, 3 In-Training), 32 skills with
  reusable effects, 10 items, 3 quests, 19 dialogues, 3 NPCs, 2 encounter
  tables, map registry, starter roster, type chart, recruitment config,
  customization catalog. Generators in `tools/`.
- **UI:** generated theme (Fredoka/Nunito OFL fonts, SVG icons), main menu with
  3D showcase, settings, save/load, character creation, starter selection,
  name entry, confirmation, intro, HUD, dialogue box, pause menu (Digimon,
  Party, Inventory, Quests, Settings, Save), popups (quest rewards, level-up,
  evolution prompt), evolution cutscene, battle UI, results, recruit offer,
  toasts, modal dialogs, safe-area container.
- **Characters:** chibi Tamer builder with shared body-type system (male/female
  proportions), hairstyles, faces, clothes, accessories; 12 original
  placeholder Digimon body plans; procedural animation clips following the
  animation contract.
- **World:** procedural Starter Zone (terrain, river + walls, bridge, plaza,
  training grounds, tall-grass meadow, forests, rocks, flowers, data cubes,
  data pillars, sky islands, gateway, boundary), custom sky/water/grass
  shaders, NPCs with quest markers, signposts, recovery terminal, pickups,
  area triggers, encounter spawners, portal.
- **Gameplay:** camera-relative player controller, third-person spring-arm
  camera, virtual joystick, camera drag/pinch, multitouch buttons, keyboard &
  mouse fallback, partner follow AI with navigation, quest system, turn-based
  battles (speed order, skills, items, defend, switch, escape, befriend,
  statuses, crits, type/attribute advantage), EXP/level-ups/learnsets,
  data-driven evolution, recruitment, party/collection, inventory,
  save/load/autosave with versioning, backups and migration.
- **Audio:** AudioManager with Music/SFX/UI buses, crossfades and pooled
  voices; 48 synthesized SFX and 5 music tracks (looping).
- **QA:** unit tests (46 tests / 841 assertions), headless vertical-slice
  integration test, script/scene/resource checker, screenshot tours.

### Fixed during development
- Anchor presets collapsing UI (`set_anchors_and_offsets_preset`).
- Washed-out colours (toon specular off; sRGB vertex/instance colours).
- Terrain collision now built from height data (works headless).
- Name clashes with built-ins (`Area3D.priority`, `Node._input`, `SceneTree.root`).
