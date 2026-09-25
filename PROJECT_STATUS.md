# PROJECT STATUS — Digimon Adventure RPG Prototype

> **Continuity rule:** any agent/session continuing this project must first read
> `PROJECT_STATUS.md`, `DEVELOPMENT_PLAN.md`, `TODO.md` and `CHANGELOG.md`,
> inspect the repository, and continue from the current implementation.
> Never restart the project or delete working features to rewrite them.

_Last updated: 2026-09-25 (session 1, v0.2.0)_

## Current phase

**Phase 18 — Playable vertical slice validation: reached**, plus the first
content expansion (v0.2.0): a second zone (**Data Forest**) behind the
Gateway, **shops** and **equipment chips**. Work now shifts to device testing,
polish and more content (see `TODO.md`).

## Completed systems (implemented = scenes + scripts + data + UI + wiring exist)

| Area | Status | Main files |
|---|---|---|
| Project foundation, autoloads, folders | ✅ | `project.godot`, `systems/core/*` |
| Data architecture (species, skills, items, quests, dialogue, NPCs, encounters, maps, configs) | ✅ | `systems/**/*_data.gd`, `data/**.tres`, `tools/generate_data.gd` |
| UI theme (fonts, buttons, panels, bars, sliders, toggles) | ✅ | `ui/theme/*`, `tools/generate_theme.gd` |
| Scene management (fades, threaded loading, params, toasts) | ✅ | `systems/core/scene_manager.gd` |
| Main menu (Continue / New / Load / Settings / Quit, 3D showcase) | ✅ | `ui/main_menu/*` |
| Character creation (body type, hair, face, skin, eyes, clothes, colours, accessories, randomize/reset, live rotatable preview) | ✅ | `ui/new_game/character_creation.gd`, `characters/player/*` |
| Starter selection (data-driven cards, 3D previews, stats, skill, evolution preview) | ✅ | `ui/new_game/starter_selection.gd`, `data/config/starter_roster.tres` |
| Player name (validation, sanitising) → Confirmation → Intro | ✅ | `ui/new_game/*`, `systems/player/name_validator.gd` |
| Starter Zone map (terrain, river, bridge, plaza, training grounds, meadow, forests, gateway, digital landmarks) | ✅ | `maps/starter_zone/*`, `shaders/*` |
| Data Forest map (zone 2: crystal trees, mushrooms, Crystal Lake, Old Ruins, Ranger Camp, groves, fireflies, return gateway) | ✅ | `maps/data_forest/*`, `tools/build_data_forest_scene.gd` |
| Zone toolkit (shared builder base + scene kit) | ✅ | `maps/zone_builder_base.gd`, `tools/zone_scene_kit.gd` |
| Area travel (portals between maps, spawn points, autosave on transition) | ✅ | `systems/world/portal.gd`, `maps/world_map.gd` |
| Shops (Pip in the plaza, Lumi in the forest; buy/sell, quantities) | ✅ | `systems/shop/*`, `ui/menus/shop_panel.gd`, `data/shops/*` |
| Equipment chips (5 chips, one per Digimon, Gear tab + detail view, saved) | ✅ | `systems/inventory/equipment_service.gd`, `ui/menus/inventory_panel.gd`, `ui/components/digimon_detail_view.gd` |
| Per-map battle arenas | ✅ | `scenes/battle/battle_scene.gd` (`ARENA_THEMES`), `MapData.battle_arena` |
| Player controller (camera-relative walk/run, gravity, slopes, collisions) | ✅ | `characters/player/player_controller.gd` |
| Mobile controls (analog joystick, camera drag + pinch, multitouch buttons) + PC fallback | ✅ | `systems/input/*` |
| Third-person camera (smooth follow, spring-arm collision, zoom) | ✅ | `systems/camera/third_person_camera.gd` |
| Partner follow AI (NavigationAgent3D, catch-up, teleport, idle) | ✅ | `digimon/partner_follower.gd` |
| Animation architecture (procedural AnimationPlayer clips, contract names) | ✅ | `systems/animation/procedural_animator.gd` |
| NPC system, dialogue UI, signposts, terminal, pickups, triggers, portal | ✅ | `characters/npc/npc.gd`, `ui/dialogue/*`, `systems/world/*` |
| Quest system + tracker/compass + quest log (4 quests) | ✅ | `systems/quests/*`, `ui/hud/hud.gd`, `ui/menus/quest_panel.gd` |
| Battle system (turn order by Speed, skills with reusable effects, items, defend, switch, escape, befriend, statuses) | ✅ | `systems/battle/*`, `scenes/battle/*`, `ui/battle/*` |
| Damage formula (centralised: ATK/DEF, power, level, variance, crit, type, buffs) | ✅ | `systems/battle/damage_calculator.gd` |
| EXP / level-ups / learnsets / level-up UI | ✅ | `systems/digimon/leveling.gd`, `ui/popups/popup_queue.gd` |
| Evolution (data-driven requirements, cutscene, stat comparison) | ✅ | `systems/digimon/evolution_service.gd`, `ui/popups/evolution_screen.gd` |
| Recruitment (in-battle Befriend + post-battle offer) & Collection screen | ✅ | `systems/recruitment/*`, `ui/menus/collection_panel.gd` |
| Party (max 3, reorder, lead = field partner, storage swap) | ✅ | `systems/party/digimon_roster.gd`, `ui/menus/party_panel.gd` |
| Inventory & items (categories, stacks, use effects, targets) | ✅ | `systems/inventory/*`, `ui/menus/inventory_panel.gd` |
| Save/load (3 slots + autosave, versioned, migration, backups, corrupt-safe) | ✅ | `systems/core/save_manager.gd`, `ui/menus/save_load_panel.gd` |
| Autosave (starter confirmed, quest reward, recruit, evolution, area transition, app paused) | ✅ | various |
| Settings (music/SFX/UI volume, graphics quality, camera sensitivity, invert Y, FPS) | ✅ | `systems/core/settings_manager.gd`, `ui/menus/settings_panel.gd` |
| Pause menu (Digimon, Party, Inventory, Quests, Settings, Save, Title, Return) | ✅ | `ui/menus/pause_menu.gd` |
| Audio manager + original synthesized SFX (49) and music (6) | ✅ | `systems/core/audio_manager.gd`, `audio/*`, `tools/generate_placeholder_audio.py` |
| Battle VFX (data-driven presets, projectiles, particles, floating numbers) | ✅ | `vfx/battle_vfx.gd` |
| Tests (unit + integration) and QA tools | ✅ | `tests/*`, `tools/check_scripts.gd` |
| Android / iOS export presets (landscape) | ✅ | `export_presets.cfg` |
| Thai localisation (default) + English, runtime switch in Settings | ✅ | `i18n/th.po`, `systems/core/l10n.gd`, `tools/i18n_extract.py` |
| Web build (Godot 4.3 single-threaded, gzip-packed ~13 MB, loading page) | ✅ tested in headless Chromium (iPhone landscape viewport, touch); not yet on a real iPhone | `tools/package_web.py`, `tools/web/artifact_shell.html` |

## Incomplete / partial systems

* **Zone 3**: none yet — the Data Forest has only the gateway home.
* **Chips**: fixed flat bonuses; no upgrades/rarities or battle drops yet.
* **Nicknames**: supported in data (`DigimonInstance.nickname`), no UI yet.
* **Skill replacement UI** exists (equip/unequip in Party/Collection), but no
  "forget skill" prompt — new skills beyond 4 are simply known, not equipped.
* **Real assets**: all placeholders (by design).
* **Device testing**: not yet run on physical Android/iOS hardware.

## Current known bugs / caveats

* First-ever import of a fresh clone prints "missing resource" errors for fonts
  and icons (theme loads before import finishes). Harmless; gone after import.
* Headless (dummy renderer) runs print `mesh_get_surface_count` errors from
  rendering-only calls. Harmless; not present with a real renderer.
* Navmesh bake prints "agent_radius is ceiled to cell_size" warning on 4.3 when
  agent radius isn't a multiple of cell size (currently 0.6 / 0.3 = OK).
* Partner may briefly clip through thin props while teleport-recovering.
* The Crystal Lake barrier is an invisible cylinder collider; its top creates
  an unreachable navmesh island (harmless).
* Wild Digimon can spawn inside the Old Ruins ring near the monolith; they
  are pushed out by physics.
* `tools/generate_data.gd` / scene build tools regenerate resource IDs when
  asked to overwrite files (content unchanged, diff noise only).

## Next development task

0. Try the web build on a real iPhone (Safari and the Claude app viewer):
   loading, touch, audio, frame rate, name keyboard.
1. Test on a physical Android device (touch feel, performance, safe areas,
   draw calls in the Data Forest on Low/Medium).
2. Nickname prompt when recruiting; "forget a skill" prompt.
3. Zone 3 from the Data Forest (use `ZoneBuilderBase` + `zone_scene_kit.gd`,
   see `docs/ARCHITECTURE.md` → *Adding a zone*).

## Important architecture decisions

* Godot **4.3+**, GDScript, **Compatibility renderer** everywhere (widest
  Android support); validated on 4.3.0 and 4.6.0.
* **Landscape only** (`sensor_landscape`), base viewport 1280×720,
  `canvas_items` stretch with `expand` aspect → works on 16:9, 19.5:9, 20:9.
* **Static species data never mutates**; per-Digimon state is
  `DigimonInstance`. Evolution only swaps `species_id`.
* **Rules/presentation split**: `BattleController` returns events; the scene
  animates them. All damage through `DamageCalculator`.
* **Localisation**: English source strings are the keys (`i18n/th.po`).
  Controls auto-translate plain text; formatted/static strings use
  `L10n.t()`; data resources are translated in memory by
  `GameData.apply_locale()`. New text must be added to `i18n/th.po`
  (`python3 tools/i18n_extract.py` lists what is missing).
* **Data folders are auto-discovered** by `GameData`; `.tres` files are the
  source of truth. `tools/generate_data.gd` only writes MISSING files unless
  run with `-- --update=<path token>` or `-- --overwrite`.
* Zone `.tscn` files hold gameplay objects; static scenery is procedural
  (`StarterZoneBuilder` / `DataForestBuilder` on `ZoneBuilderBase`,
  deterministic seeds). Re-running `tools/build_*_scene.gd` OVERWRITES manual
  scene edits.
* Equipment is an item category: a held chip leaves the inventory and is
  stored as `DigimonInstance.held_item_id`; bonuses are added in
  `DigimonInstance.get_stat()` so battles, UI and HP use them automatically.
* NPC services (`NpcData.service`): `heal_party`, `shop` (opens only after
  small talk, never over a quest offer/turn-in).
* Placeholders are **original** procedural meshes/animations/audio;
  replacement points documented in `docs/ASSET_REPLACEMENT.md`.
* Touch HUD controls use custom multitouch controls (`TouchButton`,
  `VirtualJoystick`, `TouchCameraArea`) because regular Buttons only see the
  emulated first touch.

## File locations

* Autoloads: `systems/core/`, `systems/quests/quest_manager.gd`
* Data: `data/**` (species, skills, items, quests, dialogue, npcs, encounters, maps, shops, config)
* Scenes: `scenes/boot/boot.tscn` (main), `ui/**.tscn`, `maps/starter_zone/starter_zone.tscn`, `maps/data_forest/data_forest.tscn`, `scenes/battle/battle_scene.tscn`, `characters/player/player.tscn`
* Tools: `tools/` (generators, `check_scripts.gd`, `godot_env.sh`)
* Tests: `tests/unit/`, `tests/integration/`, `tests/tools/` (screenshot tours)
* Docs: `README.md`, `docs/ARCHITECTURE.md`, `docs/ASSET_REPLACEMENT.md`, `docs/screenshots/`

## Test results (latest)

| Check | Godot 4.3.0 | Godot 4.6.0 |
|---|---|---|
| `tools/check_scripts.gd` (load every .gd/.tscn/.tres) | 0 failures (274 files) | 0 failures (274 files) |
| Unit tests `tests/test_runner.tscn` | 56/56 pass, 2623 assertions | 52/52 pass, 1074 assertions |
| Integration `tests/integration/vertical_slice_test.tscn` | PASS (56 checks) | PASS (54 checks, v0.2) |
| Traversal `tests/integration/traversal_test.tscn` (walk routes with real physics) | PASS (5 routes) | — |
| Screenshot tours (menus / world / battle / forest) at 1280×720 | rendered OK (Mesa llvmpipe, Compatibility) | — |

Not verifiable here (must be checked on devices / in the editor): real touch
input on hardware, Android back button, device safe-area insets, audio output,
performance on a mid-range phone.
