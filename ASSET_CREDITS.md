# Asset Credits

| Asset | Source | License |
|---|---|---|
| `assets/models/characters/**`, `assets/models/weapons/**` (heroes, villagers, animations) | KayKit Adventurers Character Pack 1.0 and 2.0 (FREE) by Kay Lousberg | CC0 (`LICENSE-KayKit.txt`) |
| `assets/models/monsters/{big,blob,flying}/**` | "Ultimate Monsters" by Quaternius | CC0 (`LICENSE-Quaternius.txt`) |
| `assets/models/monsters/cute/**` | "Cute Animated Monsters" by Quaternius | CC0 (`LICENSE-Quaternius.txt`) |
| `assets/models/nature/**` (trees, bushes, rocks, plants) | "Ultimate Stylized Nature" by Quaternius | CC0 (`LICENSE-Quaternius.txt`) |
| `assets/fonts/*` | Fredoka, Nunito, Mitr, Noto Sans Thai | SIL Open Font License 1.1 (OFL files alongside) |
| `assets/icons/**` | Hand-written SVG for this project | Project |
| `assets/vfx/kenney-particles/**` | [Particle Pack 1.1 by Kenney](https://kenney.nl/assets/particle-pack) | CC0-1.0 (`LICENSE.txt` and original-file SHA-256 hashes in `SOURCE.json`) |
| `assets/vfx/rpicster/**` | [Godot Particle and VFX Textures by RPicster](https://github.com/RPicster/Godot-particle-and-vfx-textures), 256 px alpha textures | CC0-1.0 (`LICENSE.txt` and original-file SHA-256 hashes in `SOURCE.json`) |
| `audio/**` | Synthesized by `tools/generate_placeholder_audio.py` | Project |

The nature pack ships without textures; `NatureKit` and `shaders/foliage.gdshader` / `rock.gdshader`
recolour it procedurally.

## Sound effects (CC0)

| Files | Source |
|---|---|
| `audio/sfx/ui_*.ogg`, `hit_*.ogg`, `crit.ogg`, `portal.ogg`, `step.ogg`, `chop.ogg` | Kenney (kenney.nl): Interface Sounds, Impact Sounds, RPG Audio, CC0 |
| `audio/ambient/wind.ogg` | Wind Loop by sketchman3 (opengameart.org), CC0 |
| `audio/ambient/fire.ogg` | Fire Crackle by Pag (opengameart.org), CC0 |
| `audio/ambient/water.ogg`, `hum.ogg` | 30 CC0 SFX Loops by rubberduck (opengameart.org), CC0 |

Music and the remaining effects are synthesized for this project.

## Star expansion monster families (CC0)

| Files | Source | License / evidence |
|---|---|---|
| `assets/models/monsters/star/{Fox,Deer,Stag,Alpaca,Husky,Wolf,Bull,Horse_White}.glb` | [Ultimate Animated Animals by Quaternius](https://quaternius.com/packs/ultimateanimatedanimals.html); source bytes from the [pinned public mirror](https://github.com/benjaminpjones/catch-the-animal/tree/cf8e52eeb64429a210cebb4b12fe62b3ab06af2b/models/glTF) because original Drive downloads reached their quota | CC0-1.0; author-page license evidence and exact original/download/runtime SHA-256 hashes in `assets/vendor/star_monsters/` |
| `assets/models/monsters/star/Skeleton_*.glb` | [KayKit Character Pack Skeletons 1.0 by Kay Lousberg](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0/tree/15b62b9bad122f72926c10fb14d622c73819fa54) | CC0-1.0; original `LICENSE-KayKit-Skeletons.txt`, exact original and runtime SHA-256 hashes retained |

These are 12 newly imported base models, used for 28 enemy definitions. Elite and boss variants share their family base model and add original bone-attached geometry; they are not claimed to be 28 distinct downloaded meshes. Runtime files retain six authored animation clips and original mesh/rig data, remove unused animation buffers and rename clips to gameplay aliases. `StarMonsterArt` decorations are original project geometry. Vendoring used a closed-roster custom integrity/admission receipt because the `game-dev` CLI was not installed; engine import and runtime rendering are separate validations.

## Uploaded 100-star class wings (v0.9.2)

Six GLB wing models supplied by the user in `ปีก ดาว100.rar` for this game. Names and original designs retained; geometry combined and simplified for the web runtime. These uploads are not described as CC0. Source hashes, conversion details and rendered checks are recorded with the star-wing asset package.

## Uploaded divine equipment and Lotus Sanctum (v0.9.3)

In v0.9.4, the divine wardrobe uses colour masks on the original chibi body and compact original ChibiGear trims, matching the level 1–100 silhouette. Armour colours the shirt, trousers and gloves; boots have their own mask; headpieces are hair-visible circlets. Uploaded weapons, shields and books retain their supplied models. The uploaded wardrobe source and provenance remain archived; wardrobe shells are no longer attached at runtime.

`assets/models/divine_gear/` uses the six class collections provided in `ชุด+อาวุธ200ดาว.rar`: พันดาบเทวะ, พฤกษาเทพ, มังกรเทพเพลิง, นภาจักรวาล, เซราฟิม and ราชินีผีเสื้อ. Supplied male/female shirts, trousers and gloves form each armor item; headpieces and boots are separate equipment. Uploaded weapons, shield and grimoires retain their designs. Runtime processing combines materials, reduces geometry and transfers wardrobe deformation to the existing hero rigs. These user uploads are not described as CC0. Source/runtime hashes and processing details are retained in the package's `PROVENANCE.json`.

Lotus Sanctum monsters reuse the CC0 Quaternius Ultimate Monsters models already in `assets/models/monsters/` (Ghost, YellowDragon, Frog, Monkroose, Armabee_Evolved, Goleling_Evolved, Alpaking_Evolved), tinted in data. `world/divine_region_art.gd` and the divine attack effects are original project geometry. Repeated scenery is batched. Native software rendering checks do not establish iPhone performance.
