# Development Plan — Digimon Adventure RPG Prototype

The goal is a **playable vertical slice** of a 3D mobile monster RPG in Godot 4
(GDScript, landscape, touch-first, keyboard/mouse fallback).

Priorities (highest first):

1. Project runs without errors
2. Complete playable game loop
3. Mobile controls feel good
4. Save data works
5. UI looks like a real game
6. Expandable architecture
7. Visual polish

## Vertical slice target

Launch → Main Menu → New Game → Character creation (body, hair, face, skin,
clothes, accessories) → Starter selection (Agumon / Gabumon / Patamon) →
Player name → Confirmation → Intro → Digital World Starter Zone → partner
follows player → talk to NPC → receive quest → explore → encounter wild
Digimon → battle → skills → victory → EXP / level up → possible recruitment →
return to NPC → quest complete → reward → save → keep exploring.

## Phases

| # | Phase | Key deliverables |
|---|-------|------------------|
| 1 | Foundation & architecture | project.godot, folders, autoloads, data classes, data registry, theme |
| 2 | Main menu / New game | Boot, Main Menu, SceneManager transitions |
| 3 | Character customization | CharacterAppearance, catalog, ChibiAvatar builder, creation screen with live 3D preview |
| 4 | Starter selection | StarterRoster data, cards, 3D preview, name entry, confirmation, intro |
| 5 | World / player / camera / joystick | Starter Zone map, PlayerController, ThirdPersonCamera, VirtualJoystick, touch camera, HUD |
| 6 | Partner follow | PartnerFollower with NavigationAgent3D, catch-up teleport |
| 7 | NPC / dialogue / quests | NPC, DialogueBox, QuestManager, quest UI, first quest |
| 8 | Battle system | BattleController (logic), BattleScene (presentation), BattleUI |
| 9 | Stats / skills / EXP | Leveling, skill effects, level-up UI |
| 10 | Recruitment & collection | RecruitmentService, befriend action, Collection screen |
| 11 | Party | DigimonRoster, Party screen, reorder, switch in battle |
| 12 | Evolution | EvolutionService, requirements, Evolution screen |
| 13 | Inventory & items | Inventory, ItemService, Inventory screen, pickups |
| 14 | Save / load / autosave | SaveManager (versioned, migration, backups), Save/Load UI |
| 15 | Mobile UI polish | Theme, safe areas, aspect ratios, touch target sizes |
| 16 | Audio / VFX / feedback | AudioManager, placeholder synth audio, particles, screen shake |
| 17 | Optimization & QA | Draw calls, MultiMesh props, quality levels, tests |
| 18 | Vertical slice validation | Automated flow test, screenshots, docs |

Phases are internal milestones; work continues through them without stopping.

## Architecture overview

```
Autoloads (only where justified)
  EventBus      – global signals between decoupled systems
  Settings      – user settings (ConfigFile), applies audio/graphics
  GameData      – read-only registry of data resources (species, skills, …)
  GameState     – the running save: profile, roster, inventory, quests, world
  SaveManager   – versioned JSON saves, backups, migration, autosave
  AudioManager  – buses, music crossfade, pooled SFX
  SceneManager  – scene registry, fades, threaded loading, scene params
  QuestManager  – quest rules; listens to EventBus, updates GameState.quest_log

Static data (Resources, res://data/**.tres)   ← never mutated at runtime
  DigimonSpecies, EvolutionPath, SkillData, SkillEffect, ItemData,
  QuestData, QuestObjective, DialogueData, DialogueLine, NpcData,
  EncounterTable, SpawnEntry, MapData, StarterRoster, RecruitmentConfig,
  TypeChart, CustomizationCatalog

Runtime state (RefCounted, serialised to dictionaries)
  DigimonInstance, DigimonRoster, Inventory, QuestLog, PlayerProfile,
  CharacterAppearance, WorldState

Services (static, pure logic, unit-tested)
  DamageCalculator, Leveling, EvolutionService, RecruitmentService,
  ItemService, BattleController, NameValidator

Presentation
  ChibiAvatar, DigimonVisual (+ PlaceholderDigimonFactory),
  ProceduralAnimator, UI scenes, HUD, BattleScene
```

## Asset policy

No copyrighted Digimon assets. All visuals are original procedural
placeholders built from primitives; audio is synthesised by
`tools/generate_placeholder_audio.py`. Fonts are SIL OFL (Fredoka, Nunito).
Replacement points are documented in `docs/ASSET_REPLACEMENT.md`.
