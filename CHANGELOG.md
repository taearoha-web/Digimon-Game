# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [0.5.0] — 2026-10-05 — Real-time combat in the map

### Changed
- **Wild monsters are now fought directly in the map** instead of switching to
  a battle scene. Touching a monster or the old "Fight!" button no longer
  starts a battle; the turn-based scene stays for scripted fights
  (`WorldMap.start_battle(BattleRequest)`).
- Wild monsters have HP bars, fight back (0.6 s red-flash telegraph, melee or
  ranged by skill), hunt your partner when hurt (Virus types on sight, nearby
  monsters join), and give up when you get far away.
- Out of combat the partner slowly recovers HP, and SP regenerates over time
  (faster when resting) instead of refilling after each battle.

### Added
- **Skill bar on the right edge of the HUD**: the partner's (up to 4) skills
  as round buttons with element colour, an aim glyph, cooldown sweep, SP cost
  and name; "Area" tag on area skills. Tap a skill → the partner runs at the
  locked-on monster and uses it. Small buttons below: next target, swap
  partner. Target frame (name + HP) under the quest tracker.
- **Single-target and area skills**: `SkillData.shape` (SINGLE / BURST around
  the caster / BLAST around the target), `cast_range`, `area_radius`,
  `cooldown`. 14 skills are area skills; every starter begins with one
  single-target and one area skill.
- Kills grant EXP (participants full, bench half), drops, level-up /
  evolution popups, quest progress and possible recruitment on the spot.
- Fainted partner → the next healthy party member steps in; whole party
  fainted → you wake up at the Recovery Terminal.
- Keyboard: `1`–`4` skills, `R` next target. First-time hint toast.
- Systems: `FieldCombat`, `FieldSkillResolver`, `FieldRewards`
  (`systems/combat/`), `FieldHpBar`, `SkillBar`, `SkillButton`.
- Tests: `test_field_combat.gd` (unit) and `field_combat_test.tscn`
  (integration: area skills, monsters hurting the partner, faint swap, wipe);
  the vertical slice now fights in the field and still covers the scripted
  turn-based battle. Screenshot tour `field`.

## [0.4.0] — 2026-10-05 — Real monster models

### Changed
- **Every Digimon now uses a real animated 3D model** instead of the
  procedural placeholder: Quaternius "Ultimate Monsters" (CC0) in
  `assets/models/monsters/`, picked to match each species' look and
  evolution line (e.g. Koromon → pink blob, Agumon → dino, Greymon →
  orange dragon, Togemon → cactus). The placeholder factory stays as a
  fallback when `model_path` is empty or missing.
- `DigimonVisual` normalises imported models: scales them to the new
  `DigimonSpecies.model_target_height`, puts the feet on the ground (or
  hovering for flyers), adds a blob shadow and maps the model's own clip
  names to the creature animation contract (`CLIP_ALIASES`).
- Species descriptions no longer end with "(Original placeholder model.)".

### Added
- `test_species_models`: every model loads, has a sane height and resolves
  idle / walk / attack / hurt / defeat / victory.

## [0.3.0] — 2026-09-25 — Thai language

### Added
- **Thai translation of the whole game** (`i18n/th.po`, ~700 strings):
  menus, HUD, battle messages, dialogue, quests, items, skills, Digimon
  names/descriptions, NPCs, places, signposts and 3D labels. Thai is the
  default language; Settings → Language switches ไทย / English at runtime.
- Thai fonts as fallbacks in the UI theme: Noto Sans Thai (text) and Mitr
  (headings), both SIL OFL. ICU text-server data is exported so Thai
  lines wrap between words.
- `L10n` helper (`systems/core/l10n.gd`): `L10n.t()` for formatted and
  static-code strings; data resources are translated in memory by
  `GameData.apply_locale()` (the .tres files stay English).
- `tools/i18n_extract.py`: lists player-facing strings missing from the
  catalog (`i18n/untranslated.txt` lists intentional exceptions).
- `test_translations.gd`: catalog loaded, placeholders (`%s`, `{name}`,
  BBCode) preserved in every translation, data fully translated, language
  switching works both ways.
- **Fight! button**: when a wild Digimon is within ~3.6 m, the HUD action
  button (right side, next to Sprint) turns into a red "สู้!" / "Fight!"
  button that starts the battle. Bumping into a Digimon still works.
  Interactables can now set their own button icon and colour.
- **Fullscreen**: the web page requests fullscreen when you tap Play, and
  Settings → Graphics has a Fullscreen switch (desktop, Android, iPad;
  iPhone browsers do not allow page fullscreen, so it is hidden there).
- **GitHub Pages site** (`docs/play/`, `tools/package_web.py --pages`):
  full page with a web-app manifest and iOS home-screen tags, so on iPhone
  "Add to Home Screen" launches the game fullscreen. `docs/.nojekyll`
  serves the files as-is.
- `tests/integration/traversal_test.tscn`: walks the player along routes
  with simulated joystick input and real physics (bridge both ways, plaza
  to training grounds, forest paths).

### Fixed
- **The Starter Zone bridge could not be crossed**: its deck was a ~25 cm
  ledge above the path. Sloped approach boards (collision + visuals) now
  lead onto both ends.
- A refused encounter (grace period, dialogue, fainted party) no longer
  leaves that wild Digimon un-fightable.
- Camera spun wildly when dragging with the right thumb while the left
  thumb held the joystick (Web build): Godot's Web `ScreenDrag.relative`
  can be computed against another finger. Camera and 3D previews now use
  their own per-finger deltas (with a spike clamp).
- Saved settings from older versions no longer force English: a language
  is only kept when the player picked it (`language_chosen`).
- Stat-change battle messages use whole-sentence templates so languages
  can reorder words.

## [0.2.1] — 2026-09-25 — Web build (play on iPhone)

### Added
- "Web" export preset (single-threaded, WebGL 2, virtual keyboard) and
  `tools/package_web.py` + `tools/web/artifact_shell.html`: gzip-packed
  build (~10 MB) with a Thai/English loading page, download progress and a
  portrait "rotate your phone" overlay.
- Phone browsers (`web_ios` / `web_android`) use the mobile graphics defaults.

### Fixed
- Name entry on the web: the phone keyboard can change the text without a
  `text_changed` signal, so the name screen now polls the field.
- Version string updated to 0.2.0 (main-menu footer).

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
