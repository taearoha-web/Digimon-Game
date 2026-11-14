# เกาะลอยฟ้าเทพมังกร (Sky Isle of the Dragon God): build plan and contract

The owner asked for a new ★300 hunting field with five things that make farming exciting.
Four teams build it in parallel worktrees on top of the contract stubs committed with this
file. Keep the names below; replace the stub bodies.

## What the owner asked for (verbatim rates)

- Map: ★300, "เกาะลอยฟ้าเทพมังกร".
- New weapon (อาวุธเทพมังกร): 0.5% a kill.
- 300★ wings: 0.1% a kill. The isle drops NO other wings.
- Costume fragment: 0.1% a kill (50 fragments make the isle-only costume).
- New mount's egg: 0.1% a kill.
- Everything else drops as on the Poseidon field (ห้วงสมุทรอสูร = EndgameFields.kill_drops and the
  zone's jewel_drop / set_core_drop), without the Lv.100 wings.
- Jackpot drops are announced to the whole server.
- Monsters also drop treasure chests that roll a random prize when opened.
- A rare monster appears at random a few times a day, with a map-wide alert.

## Shared names (already in the tree as stubs)

| Name | File | Owner |
|---|---|---|
| `SkyIsleData.ID = &"sky_dragon_isle"`, `TITLE`, `ENTRY_STAR = 300`, `zone()`, `has_monster()`, `monster()` | data/sky_isle_data.gd | map |
| zone flags `"sky_isle_loot": true`, `"rare_dragon": true` | zone dictionary | map sets them |
| `DragonGearData.weapon(cls, rng)`, `.wings(cls, rng)`, `.is_item/.is_weapon/.is_wings`, item key `"dragon": 1` | data/dragon_gear_data.gd | gear |
| `SkyIsleLoot.kill_drops(cls, boss, elite, fortune, roll)`, `.rare_drops(cls, roll)`, `.is_jackpot(item)`, `.announce(item, who)`; rates `WEAPON_DROP/WING_DROP/FRAGMENT_DROP/EGG_DROP`; ids `FRAGMENT/EGG/CHEST/COSTUME/MOUNT` | data/sky_isle_loot.gd | collectibles |
| `Zone._sky_isle_loot(mob, from)` (called for zones with `sky_isle_loot`) | world/zone.gd | collectibles |
| `Announcer.broadcast(text, kind)` (`kind`: "jackpot" or "rare") | systems/core/announcer.gd | world |
| rare dragon spawn on zones with `rare_dragon` (calls `SkyIsleLoot.rare_drops`, `Announcer.broadcast`) | world/zone.gd + data/world_events.gd | world |

## Teams

- **map**: the zone (floating islands art, sky, props, music), the dragon bestiary and boss
  (the Dragon God), balance for a ★300 hero in the 250★ set, how the hero travels there,
  every per-zone registry and its test (music, sky, props, art direction, world map).
- **gear**: the Dragon God weapon of all 10 classes and the 300★ wings of all 10 classes
  (stats, requirement, looks, icons, forge/enhance rules, save validation on both sides).
- **collectibles**: the drop table, treasure chests (item + opening), costume fragments and
  the isle-only costume, the egg and the new mount, the jackpot announcement text, save
  validation for the new stackables.
- **world**: the rare dragon event, the announcement banner/chat/online relay, AI world
  players on the isle and their chatter about it.

## Rules for every team

- Do not rename or change the signature of anything in the table.
- Shared files (world/zone.gd, data/item_data.gd, systems/core/game.gd,
  hosting/accounts/server/accounts.js, .github/workflows/validate.yml): keep edits small
  and local to your feature so the merges stay easy.
- A team must not depend on another team's finished work: code against the stubs.
- Performance: phones. No lights, no GPU particles; cache meshes and materials; respect
  VfxBudget, GameSettings.quality and MemoryGuard like the existing art does.
- CC0 / code-built assets only.
