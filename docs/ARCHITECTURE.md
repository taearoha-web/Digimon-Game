# Architecture

## Layers

```
┌───────────────────────── Presentation ─────────────────────────┐
│ UI screens (ui/**), HUD, BattleScene/BattleUI, WorldMap, VFX,    │
│ ChibiAvatar, DigimonVisual, PlaceholderDigimonFactory            │
├───────────────────────── Game services ────────────────────────┤
│ BattleController · DamageCalculator · BattleAI · BattleRewards   │
│ Leveling · EvolutionService · RecruitmentService · ItemService   │
│ QuestManager (autoload) · NameValidator · TextVars               │
├───────────────────────── Runtime state ────────────────────────┤
│ GameState (autoload): PlayerProfile, DigimonRoster(DigimonInstance│
│ …), Inventory, QuestLog, WorldState  — serialised by SaveManager │
├───────────────────────── Static data ──────────────────────────┤
│ GameData (autoload) → DigimonSpecies, SkillData/SkillEffect,     │
│ ItemData, QuestData/QuestObjective, DialogueData/Line, NpcData,  │
│ EncounterTable/SpawnEntry, MapData, StarterRoster, TypeChart,    │
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
     → map:starter_zone ⇄ battle
```

Battles: the world stores the player transform, sets
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

## Battle pipeline

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
