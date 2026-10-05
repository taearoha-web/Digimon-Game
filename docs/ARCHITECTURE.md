# Architecture

## Layers

```
┌───────────────────────── Presentation ─────────────────────────┐
│ UI screens (ui/**), HUD, BattleScene/BattleUI, WorldMap, VFX,    │
│ ChibiAvatar, DigimonVisual, PlaceholderDigimonFactory            │
├───────────────────────── Game services ────────────────────────┤
│ BattleController · DamageCalculator · BattleAI · BattleRewards   │
│ Leveling · EvolutionService · RecruitmentService · ItemService   │
│ EquipmentService · ShopService                                   │
│ QuestManager (autoload) · NameValidator · TextVars               │
├───────────────────────── Runtime state ────────────────────────┤
│ GameState (autoload): PlayerProfile, DigimonRoster(DigimonInstance│
│ …), Inventory, QuestLog, WorldState  — serialised by SaveManager │
├───────────────────────── Static data ──────────────────────────┤
│ GameData (autoload) → DigimonSpecies, SkillData/SkillEffect,     │
│ ItemData, QuestData/QuestObjective, DialogueData/Line, NpcData,  │
│ EncounterTable/SpawnEntry, MapData, ShopData, StarterRoster,     │
│ TypeChart,                                                       │
│ RecruitmentConfig, CustomizationCatalog                          │
└──────────────────────────────────────────────────────────────────┘
```

Services are static functions or plain `RefCounted` objects that receive
their inputs explicitly (e.g. evolution checks take an
`{inventory, quest_log, flags}` context), which keeps them unit-testable.

## Scene flow

`SceneManager` owns every scene change (fade → threaded load → swap → fade)
and passes parameters through `SceneManager.params`.

```
boot → main_menu → character_creation → starter_selection → player_name
     → confirmation (GameState.start_new_game + autosave) → intro
     → map:starter_zone   (wild monsters are fought live in the map)
         ⇅ (Gateway portals: goto_map(target_map, target_spawn, {from_portal}))
       map:data_forest
       (scripted turn-based fights: WorldMap.start_battle → battle ⇄ map)
```

### Adding a zone

1. `maps/<zone>/<zone>_builder.gd` extending `ZoneBuilderBase`: implement
   `get_height()`, `_ground_color()` and `_build_scenery()` (helpers:
   `_multimesh`, `_data_pillar`, `_data_cubes`, `_sky_islands`, colliders,
   `paths` + `distance_to_paths`).
2. `maps/<zone>/<zone>.gd` = `extends WorldMap`.
3. `tools/build_<zone>_scene.gd` using `tools/zone_scene_kit.gd` to place
   spawn points, NPCs, portals, pickups, triggers, spawners and waypoints.
4. `data/maps/<zone>.tres` (`MapData`: scene, default spawn, music,
   battle arena) and a `Portal` in an existing zone targeting it.

Wild monsters are fought in the map itself (see **Field combat** below).
Scripted turn-based battles (bosses, trainers): the world stores the player transform, sets
`GameState.pending_battle` (a `BattleRequest`) and calls
`SceneManager.goto_battle()`. The battle applies rewards to `GameState` and
returns with `{"from_battle": true}`; the world restores the player position
(or the respawn point after a defeat).

## Events

`EventBus` decouples systems. Gameplay emits facts, listeners react:

| Signal | Emitted by | Used by |
|---|---|---|
| `npc_talked` | QuestManager.apply_npc_action | quest TALK objectives |
| `area_entered` | AreaTrigger | quests, HUD banner |
| `battle_won` | BattleScene | quest WIN objectives |
| `digimon_recruited` | BattleScene | quests, autosave |
| `item_obtained` | Inventory (via GameState) | quest COLLECT objectives |
| `digimon_leveled_up` | battle / quest rewards | REACH_LEVEL objectives |
| `quest_*` | QuestManager | HUD, NPC markers, popups |
| `dialogue_started/finished` | DialogueBox | WorldMap input lock |
| `toast_requested` | anyone | ToastLayer |

## Field combat (real-time, in the map)

`WorldMap` owns a `FieldCombat` node (`systems/combat/field_combat.gd`):

* The player moves; the lead partner fights. The HUD `SkillBar` (right edge)
  shows the partner's equipped skills (`SkillButton` = element colour, aim
  glyph, cooldown sweep, SP cost, name). `FieldCombat.use_skill()` locks the
  target (nearest, hostile first), sends the partner at it
  (`PartnerFollower.engage`) and fires the skill once it is within
  `SkillData.get_engage_range()`.
* `SkillData` field data: `shape` (SINGLE / BURST around the caster / BLAST
  around the target), `cast_range`, `area_radius`, `cooldown` (set in
  `tools/generate_data.gd`, `FIELD_AREA` + defaults).
* `FieldSkillResolver` applies one skill to one target and returns plain
  events (damage via `DamageCalculator`, heal, stat, status, drain, SP). Turn
  counts become seconds; `tick()` advances status / stat-stage timers.
  Pure logic, unit-tested in `tests/unit/test_field_combat.gd`.
* `WildDigimon` has an own `DigimonInstance` + `BattleCombatant`, an HP bar,
  hunts the partner when provoked (Virus types on sight; neighbours within 6 m
  join), telegraphs hits (0.6 s windup), uses its damaging skills, and gives up
  at the leash distance. `EncounterSpawner.set_encounters_enabled(false)` keeps
  monsters calm (used by tests and screenshot tours).
* Kills use `FieldRewards` (EXP: participants full, bench 50%; drops;
  recruit roll → joins directly), emit `battle_won` for quests, and queue the
  usual level-up / evolution popups. Fainted partner → next healthy member
  steps in; nobody left → `party_wiped` → Recovery Terminal.
* Balance knobs: `FieldCombat.PLAYER_DAMAGE_SCALE`, `WildDigimon.DAMAGE_SCALE`,
  SP / HP regeneration constants, `DamageCalculator` stays the single formula.

## Battle pipeline (scripted turn-based fights)

1. `BattleController.setup(party, enemy, request, inventory, rng)`
2. `start()` → intro events
3. `submit(command)` validates, asks `BattleAI` for the enemy command, sorts
   actions (non-skill actions first, then skill priority, then **Speed**, tie
   broken randomly), executes them, checks faints, runs end-of-turn statuses.
4. Each skill is a list of `SkillEffect`s resolved generically: DAMAGE (via
   `DamageCalculator`), HEAL, BUFF/DEBUFF (stat stages ±4), STATUS (see
   `StatusEffects`), RESTORE_SP, DRAIN.
5. The scene plays the events (animations, VFX presets from `BattleVfx`,
   floating numbers, HP bars, messages).
6. `BattleRewards` computes EXP (participants full, bench 50%), drops and the
   post-battle recruitment roll.

Damage formula (`DamageCalculator`):

```
level_factor = 2·Lv/5 + 2
base   = (level_factor · Power · ATK / DEF) / 40 + 2
damage = base · 2.5 · same-element(1.2) · type · critical(1.5) · random(0.85–1.0) · defend(0.5)
type   = element chart (TypeChart) × attribute triangle (Vaccine > Virus > Data > Vaccine)
```

## Save format

`user://saves/slot_N.json` (N = 1..3) and `autosave.json`:

```json
{
  "version": 1, "game_version": "0.1.0", "saved_at": 1758800000,
  "meta": { "player_name": "…", "lead_name": "…", "lead_level": 5, … },
  "state": { "profile": {…}, "roster": {…}, "inventory": {…},
             "quests": {…}, "world": {…} },
  "settings": { … }
}
```

* Writes go to `.tmp`, are re-read and validated, then replace the real file;
  the previous file becomes `.bak`.
* Loading falls back to `.bak` when the main file is unreadable; a fully
  corrupt slot is reported in the UI and never crashes the game.
* `SaveManager.migrate()` upgrades old versions step by step
  (`_migrate_v0` → v1 exists as an example).

## Performance notes (mid-range Android)

* Compatibility renderer, toon materials without specular, MSAA and
  3D resolution scale per quality level; shadows off on Low.
* Shared unit meshes and cached materials (`MeshKit`); trees, rocks, grass,
  flowers and data cubes are MultiMeshes (a handful of draw calls); grass sway
  and cube bobbing run in shaders.
* Wild Digimon AI thinks ~3×/s and sleeps beyond 55 m; spawners check on a
  timer with per-region caps; interaction checks run ~8×/s.
* HUD refreshes on events plus a 0.5 s timer, not every frame.
* Navmesh baked once on a thread at map load.
