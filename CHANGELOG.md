# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

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
