# Latest handoff: v0.9.4 · build afb9ddca

This snapshot includes all changes through 12 October 2026. Read `../START_HERE_FOR_CLAUDE.md` and `../VERSION.json` first. The older release history below is preserved as historical documentation. Current source/data and `docs/play` are the latest complete version.

# Toon Tale

A cute, solo 3D action RPG for landscape phone browsers, built with **Godot 4.3** and the GL Compatibility renderer. Version **0.7.7** releases cached resources after map changes and shares hit-particle geometry to reduce long-session memory pressure. Version **0.7.6** gives all 35 buff skills distinct persistent art, separates two self buffs from two incoming ally buffs, and groups status effects below the hero with enemy health at the top centre. Bag and merchant lists retain their position after selling. The 0.7.4 art update refines all 152 skill presentations with weapon-bound charges, weighted motion, elemental surfaces and staged dissolves. The ending remains at the final Void Emperor. All 152 illustrated skill icons, authored effects, release-synchronized choreography and corrected weapon grips remain available, alongside numeric stat allocation, equipped head portraits and cloud accounts. Combat has no camera shake, automatic zoom or phone vibration. Armageddon retains eleven real hits spaced 0.5 seconds apart.

## World players and the guilds Alpha and Neverdie (October 2026)

- **Twenty world players** with fixed names, classes and guilds (`data/world_players.gd`): Alpha — Kaito (Warrior), Shadow_Fang (Assassin), น้องแพรวา (Priest), LanceKung (Lancer), SkyArrow (Archer), Mintty (Mage), Rinrada (Summoner), ป้อมปราการ (Defender), เมจิกหมูกรอบ (Mage), ข้าวเหนียวมะม่วง (Archer); Neverdie — Zerox (Warrior), BlackLotus (Assassin), TonkatsuX (Defender), นักล่าตะวัน (Archer), Fiora (Lancer), Yoyo (Priest), แม่หมอมิว (Priest), PhantomZ (Summoner), ไฟร์บอลเด้ง (Mage), Raijin (Warrior).
- Nobody runs them on a server. Each keeps a **daily play schedule** by play style (hardcore, regular, student, night owl, weekend, casual; Thai time, jittered per day, seeded by name and day, so every device sees the same thing at the same moment), and its level and stars are the EXP a real player earns in those hours: the auto-hunt rates `tests/tools/pace_probe.tscn` measured in the real fields (Lv.3 meadow to ★175 eclipse realm, warrior/mage) times the player's efficiency (13–20%: deaths, town trips, slower hands). The world opened on 25 Oct 2026 at 22:00 Thai time with everyone at Lv.1; hardcore players reach Lv.100 on day 1–2 and ★200 in about 10–13 days, regulars and students in about 4 weeks, weekend players in 7–9 weeks, casual players in 3–4 months; 20 hours after ★200 a player completes its class's divine set (`tests/tools/world_timeline.tscn` prints every player's milestones).
- While online a player spends the first minutes of a session in the village and the last few selling, and otherwise hunts in the field that fits its level (then the star fields by stars, the lotus sanctum at ★200). `world/world_presence.gd` shows the ones online in the hero's zone (2/3/4 at once by quality) as `characters/field_player.gd`: the companion's class AI on its own, with the stat points and skill ranks a player has, rare gear of its level enhanced as it goes (star sets past Lv.100), its own potions, backing off when losing, leaving monsters the hero is fighting alone, moving between camps, levelling up on screen as its schedule says, and walking back in from the entrance after a fall. Name tags and minimap dots carry the guild colour; milestones (job levels, Lv.100, ★50/100/150/200, the divine set) are announced like server messages.
- **Kill credit**: monsters remember the damage taken from the hero's side and from world players (`Mob.party_share`); the hero earns EXP by its share and gets the loot and quest kill only with most of the damage.
- **Guild registrar** (นายทะเบียนกิลด์) by the arena in the village: both rosters with class, level, stars and where each member is (online in which field, or when last seen), and, from **Lv.100** (`Game.GUILD_LEVEL`), the button to join a guild or move to the other (`ui/guild_screen.gd`, `Game.guild()` / `join_guild()`, saved as flag `guild`); below Lv.100 the rosters can be viewed. The **guild war** now needs a guild and is Alpha against Neverdie: the hero with seven of its guild (online members first, then the strongest) against the eight of the other ten whose total power comes closest; everyone fights at Lv.100 ★200 (war rules) in the gear grade their progress has reached, and a resumed war lines up the members as they were when it began.
- `tests/integration/world_players_test.tscn` (264 checks: roster, schedules and progress over 160 days, fields they may enter, real hunting in a field, kill credit, logging off, guild join/move, the war line-up and a real war, the registrar and lobby screens). Screenshots: `tests/tools/world_players_shots.tscn -- OUT_DIR [DAYS]`; field survival: `tests/tools/world_field_probe.tscn -- [DAYS] [SECONDS]`.

## Bigger hunting fields (October 2026)

- The eleven hunting fields (Lv.1 meadow to the Lv.100 void) grew from a 52 m to a **74 m** playable radius (`Zone.HUNT_RADIUS`; the tower and the arena keep 52 m) and gained **four outer camps** each (`ZoneData.OUTER_CAMPS`: named camps of the field's own monsters two kinds at a time, a few levels wide inside the field's band, 8 monsters each, 6 in the void) with side trails from the main path. A field now has nine camps and about 82 monsters (70 in the void). Field bosses, their spot and their drops are unchanged; star fields and the lotus sanctum keep their authored layouts.
- Cost on the zone-switch probe: build time about the same (far camps sleep until the hero comes near), draw calls and triangles at the entrance no higher, video memory about +3 MB.

## Hero looks: six characters on two bodies (October 2026)

- The creator offers three characters per body (boy: ฮีโร่ดั้งเดิม, นักล่าเงินจันทร์, อัศวินทองฟ้า; girl: นักผจญภัยดั้งเดิม, เจ้าหญิงซากุระ, ภูตป่าดำขลับ), and each part can be changed alone: hair colour (9), skin tone (6), eye colour (6) and an accessory (bow, flower clip, glasses, gold earrings). No new model ships: download size and memory are unchanged.
- `characters/chibi_look.gd` holds the palettes, styles and accessories. `shaders/chibi_outfit.gdshader` recolours the body's own texture inside a baked mask, `assets/models/heroes/chibi_*_look_mask.png` (R: hair and brow geometry 255, the rest of the head 128; G: the eye 128, the iris 255, painted per texel from its 3D position so the lids, lashes and liner keep their colour), which `tools/chibi_look_mask.py` bakes from the rig's Hair_*/Brow_*/Eye_* skin weights and the eyes' 3D position.
- Look keys `style`, `skin_tone`, `hair_tint`, `eye_tint`, `acc` are 0 for the original texture (save validation accepts no negative numbers), so existing saves look exactly as before. Rivals and guild fighters wear one of the three styles, picked without drawing extra random numbers.
- `tests/integration/chibi_look_test.tscn` (80 checks). Previews: `tests/tools/chibi_look_preview.tscn -- OUT_DIR styles|hair_tint|skin_tone|eye_tint|acc face|full|back` with `tools/chibi_look_sheet.py`, and `tests/tools/creator_shot.tscn`.

## Critical hits and class balance (October 2026)

- **Critical chance** starts at **10%** for every class (**15%** for Archer and Assassin) and can reach **100%**. DEX adds 0.025% per point, gear crit counts at a fifth of the rating items carry (a full +10 set of the best gear gives about 30%; socketed topaz counts in full), job advancement adds half of what it used to, then passives, star points and buffs. Typical totals: about 15% (Archer/Assassin about 34%) at Lv.30, 20–35% (45–60%) at Lv.100, 45–60% (75–90%) with ★200 gear, up to 100% under crit buffs (`systems/core/hero_stats.gd`).
- DEX speeds attacks and skills with diminishing returns (about 13% at 130 DEX, 27% at 600, towards 40%), so DEX classes no longer sit at the speed cap.
- Burn, poison and bleed per second are reduced by the target's defence like the hit itself (they used to ignore it, which made area poisons dominate the late fields).
- **Assassin** is no longer the strongest class by far (it was about ×2.4 of the median): basic attack ×0.5, lower area skills (Oblivion Requiem, Abyss Vortex, Midnight Execution, Umbral Lacerate, Eclipse Requiem), Night Lord ATK +35%, Shadow Sovereign ATK +55%, 4-piece star set crits +10%.
- **Single-target skills finish harder than area skills**: every single-target skill (and summon) carries ×1.15 and every area skill (burst, blast, fan, chain) ×0.7 on top of its authored multiplier (`ClassData.SINGLE_EDGE` / `AREA_SHARE`), and `flow_test` checks that in each level band each class's strongest single-target skill out-hits its strongest area skill per enemy. Crown Breaker joins the other single-target star skills at ×27; the Priest's Judgement and Divine Judgment now smite one enemy.
- **All eight classes balanced**: `ClassData.TUNE` holds a [single-target, area] factor per class for skills unlocked at Lv.1-35, 36-75 and 76-100/star, iterated with the probe below until each class's overall strength (single target and pack combined) sits within about ±10–15% of the median at Lv.26, Lv.70 and Lv.100 ★200, Priest and Defender a little under. Classes keep a niche within ×0.8–1.25 where their kit allows (Mage and Priest are area casters: weaker alone, stronger in a crowd). Archer and Lancer basic attacks ×0.8. Late bosses gained health (`MonsterData.ZONE_TUNING`) so boss fights keep their designed length now that single-target skills hit harder.
- `tests/tools/class_dps_probe.tscn -- SECONDS ZONE [classes] [LEVEL]` measures every class's real-time damage per second on a fixed training ground: one target with the best single-target bar, then a pack of six with the best area bar.

## Session report: summary first (October 2026)

- A pasted **รายงานการหลุด** is often cut short by the chat app (an iPhone report of a 19-minute session arrived with only its first 6 minutes). The report now opens with `previousSummary`: how the session ended, its error counts, every recorded event, the first and the last five samples, the growth between them, and a one-line-per-sample `timeline` (seconds, WASM heap, video memory, objects, nodes, fps, worst frame, visibility, zone). Even a truncated paste then shows the whole session's trend. `node tools/test_web_session.mjs` covers the shape.
- `tests/tools/soak.tscn -- crystal_valley 1200 summoner` soaks a Lv.100 class with 200 stars, star gear and its top loadout (a summoner's includes the fairy, the legion and the elder dragon), re-acquiring the hero after a respawn; it prints video memory, live monsters and summons per sample. A 20-minute summoner soak in Crystal Valley stays flat (objects ~6.1k, static ~187 MB, 5 summons).
- `tests/tools/web_hunt_probe.tscn` is the same hunt in the real Web export (copy it to `probe/`, point `run/main_scene` at it, export to `build/probe`, then `node tests/tools/web_probe.mjs build/probe "zone=crystal_valley&n=900" 1700`). `web_probe.mjs` now prints `MEM` lines every 30 s with the Chromium renderer's and GPU process's resident size and the JS heap, memory Godot's counters cannot see. 15 simulated minutes in Crystal Valley: WASM heap flat at 120,586,240 bytes, video ~91 MB, JS heap flat, renderer 448–552 MB without a trend. Neither run is an iPhone; they rule out a steady leak in the summoner's hunt, not a WebKit limit.

## Version 0.7.9

- A v0.7.8 iPhone report shows WASM heap capacity growing from 144,703,488 to 619,511,808 bytes while objects increase from roughly 5,190 to 17,569, with stable node/resource counts and visible foreground play in Void. This narrows the investigation beyond scene cache retention.
- Godot 4.3's default Web **Sample** audio path retains playback objects after repeated sounds ([confirmed engine issue #96068](https://github.com/godotengine/godot/issues/96068), [engine fix #96572](https://github.com/godotengine/godot/pull/96572)). Toon Tale now forces **Stream** playback for music, ambience, SFX and UI, and overrides the Web project default. Project settings use `0=Stream`, unlike the player's enum `1=Stream`.
- On the same Godot 4.3 binary, 1,000 WAV plays in forced Sample mode retain 2,000 objects. The shipped mixed WAV/Ogg fixture retains 2,248 objects in Sample mode and 0 in the configured Stream mode. It repeats actual pool playback and validates every music/ambient/SFX/UI player's configuration. This reproduces the engine retention path on native; it does not prove the iPhone reload cause or substitute for a physical-device test.
- Session reports now include a sound-play counter and the observed player playback mode, so a further device run can check whether objects stabilize. Graphics, effect art, saves and gameplay timing are unchanged by this audio fix.

## Version 0.7.8

- Adapt static weapon/accessory mesh merging and distant-monster dormancy from Claude's [field-performance PR #81](https://github.com/taearoha-web/Digimon-Game/pull/81). High-quality art geometry, textures and nearby combat remain unchanged. Merged gear caches are limited to 64 entries and released on zone unload. Bosses, active fights, returning or burning monsters stay awake.
- The iPhone restart was reported again after v0.7.7 during unattended auto-hunting. Its cause is still unconfirmed; native skill cleanup tests do not reproduce a WebKit process restart.
- Hidden browser pages pause combat and audio while preserving an already-open menu/account pause. Visible gameplay requests an optional screen wake lock; iOS/battery policy may deny it. Auto-hunting does not continue while the app is hidden or locked.
- Poll the account/background/report pause mask as a primitive number instead of parsing the full account JSON five times per second.
- A local diagnostic ring retains at most 60 recent samples, 24 events and 24,000 characters per session record. It captures WASM heap capacity (not live allocation), Godot counters, visibility, render size, zone and hunting state. GPU/video counters may be unavailable on the Web and are not total device memory. It records context loss and coarse error categories without error text, credentials or save content. No automatic upload is performed.
- After an interrupted session, the loader offers **ดูรายงานการหลุดครั้งก่อน**. The same report is available under **ตั้งค่า → รายงานการหลุด**. Copy and share it for diagnosis. Reloads and intentional app closure can also leave an interrupted record; it is not proof of an out-of-memory crash.
- `tests/tools/long_hunt.tscn -- OUT.json 900 meadow mage` exercises actual auto-hunt, HUD, drops and saves at time scale 1 with separate wall and simulation clocks. Run only with isolated XDG save folders. Software GL can advance simulation slower than wall time; neither result verifies an iPhone.

## Version 0.7.7

- Leaving a map or returning to the title drops static ownership of its nature meshes, character material overrides, outfit parts and scenery palettes. Live nodes retain their exact materials and textures; high-quality art is preserved. Nature and generated palette caches are bounded even while a map is active.
- Hit particles reuse one immutable GPU quad with independent colour/material overrides, avoiding a new mesh allocation for every burst.
- The 12-map GL test measures resources after each map is removed: final retained video memory fell from 126,565,224 to 70,093,799 bytes. These native software-renderer measurements identify avoidable retention, but do not establish the cause of an iPhone process restart or guarantee that iOS cannot discard the game.
- `session_memory_test` exercises 608 naturally expiring skill casts without deleting their containing field. Object/resource/orphan counts must remain stable after warmup. `travel_memory` captures comparable empty-scene snapshots after real map transitions.

## Version 0.7.6

- Judgment Ray is now a dedicated single-target celestial verdict: an engraved heaven seal, tilted orbital rings, a tracking target seal, a descending gold/ivory column, an expanding impact wave and dissolving rune fragments. A 1.05-second base invocation raises and lowers the staff onto the real hit frame; DEX haste remaps both motion and damage together. It still deals exactly one hit with unchanged damage scaling, base MP 130, cooldown 12 seconds and range 14. Hero, companion and rival share the guarded sequence. Target/caster death, interruption, zone changes and duel completion cancel pending damage; pause freezes all phases. Shared meshes and budgeted ornaments preserve the essential column and seals at every quality.
- Thunder Storm art uses a taller, sculpted smoke-grey cloud with rolling mist, drifting surface detail and gold/blue electrical veins that pulse with each wave. Broad gold lightning has a pale core, layered blue corona, branching arcs and expanding impact fractures. The smoke-grey ground seal has concentric borders, 24 lightning runes, counter-turning star geometry and a mist band; its outer boundary matches the damage radius. Cloud motion and seal rotation freeze on pause. Shared cached geometry and globally budgeted flourishes keep overlapping effects bounded; essential lightning and the range seal remain visible when that budget is full. No lights, camera effects or full-screen flashes are added.
- Thunder Storm now forms one smoke-grey cloud over an Ice Storm-sized area (base radius 9, same rank scaling). Three waves independently choose up to five distinct living enemies each, 0.75 seconds apart; targets may recur across waves. Each strike deals the original 6.2× attack multiplier before rank/crit/defence. MP and cooldown are charged once. Pausing freezes the sequence; caster death, leaving the zone or ending a duel cancels it.
- Each character receives at most **2 self-cast skill buffs + 2 ally skill buffs**, independently. A third replaces the oldest in its own group immediately. Recasting the same skill refreshes its duration/potency and moves it to newest; multiple stats still cost one slot. Summons and instant healing do not consume buff slots.
- 35 authored persistent silhouettes: steel shield plates, cyan energy hexagons, gold sacred protection, violet mirages, leaf wards, blossoms, feathers, claws, blades and focus eyes. Casting and persistent palettes match. No universal green bubble.
- Forest Blessing grows four intertwined vine arches with broad translucent leaves, gold veins, blooming flower crowns, drifting fireflies and an opening botanical seal. The character remains visible through the centre.
- Shared cached geometry, one bounded decorative mesh per active buff, no persistent particles/lights, material prewarming, immediate removal on overwrite/expiry. Companion self buffs now share the stat stack with incoming buffs.
- Own and ally buff rows (with `n/2` counts) sit below the hero status card; summons wrap into compact chips. Target HP moves to top centre; a selected boss uses the boss bar without a duplicate. Safe-area layout and existing manual camera controls are retained.
- Verified with actual Godot GL rendering and isolated saves. Native software-renderer results do not establish iPhone frame rate.

## Version 0.7.5

- Selling from the bag or merchant preserves the scroll position, including several inventory/gold notifications in the same frame. The buy and sell lists retain their positions independently.
- Potions and the town scroll are bought in lots: − and + on the merchant row step through 1, 5, 10, 20, 50 and 99 bottles, and the buy button shows and charges the total. A full bag still tops up a potion it already carries; a new kind needs a free slot (no gold is taken otherwise).
- Removing the last row clamps to the new end of the list; empty bags return to zero. Entering a different menu tab starts normally, and fresh touch/mouse input takes priority over a pending restoration.
- `sale_scroll_test` presses the real sale controls while paused and checks consecutive rendered frames, repeated sales, selection, exact proceeds, stacked items, bottom-of-list removal and empty lists.

## Version 0.7.4

- All 152 skills share a four-beat presentation: weapon-bound preparation, weighted release, skill-appropriate contact and an independent painted dissolve. Nineteen gesture mappings preserve the exact contact frame under haste, with smoother recovery; rivals share the same motion system.
- Projectiles now start at the equipped weapon socket for heroes and companions. Charges follow the live skeleton, cancel with an interrupted animation or deleted caster, and freeze with pause. Socket geometry refreshes when equipment changes.
- Sword ribbons have fine layered edges; elemental projectiles use crystals, halos or flame tails. Ice grows as faceted shafts with narrow ground fractures and scattering chips; shields unfold; wind coils rise; wings spread; healing petals open; summoned creatures emerge through open gates at their actual positions.
- Surface treatment distinguishes ice fissures, flowing fire, organic veins and arcane filigree. Every cast dissolves its own materials. Removed duplicate broad shockwaves and summon pillars improve battlefield readability without hiding real projectile bodies or wind-up range warnings.
- Armageddon's rock cracks widen during descent and its ten fragments scatter along varied arcs. Damage, eleven-hit count, 0.5-second cadence and camera stability are preserved.
- Geometry is shared and prewarmed. Existing low/medium/high limits remain; no postprocessing, new lights or higher particle limits are needed. `skill_craft_test` checks real equipped sockets on three rigs, cast interruption, pause and material isolation. `combat_perf` accepts an optional `overlap` flag for 48 overlapping presentation casts alongside the six real ultimate casts.

## Version 0.7.3

- The ending plays after defeating the Void Emperor in the final Void field. Magma Dragon, Abyss Dragon and the emperor's tower appearances do not trigger it.
- Finale narration and earlier quest descriptions follow the full journey. Boss rewards and quest progression are preserved.
- A separate completion flag lets characters who saw the former magma ending earn the final-stage ending. The replay button unlocks with this new victory; it survives saves and backup transfers.
- The victory delay waits through pause menus and cannot leak into a different save or a departed field.

## Version 0.7.2

- Combat holds the player's chosen zoom: skills never pulse the field of view, and target locking no longer pulls the camera back. Manual pinch/wheel zoom and camera collision avoidance remain available.
- All hit, critical-hit, received-damage and area-impact camera shake is removed, including every Armageddon fragment. Skill art, hit timing and damage are unchanged.
- Phone vibration and its Settings toggle are removed. Older saved vibration preferences are ignored; existing graphics and camera settings still load.

## Version 0.7.1

- Swords, staffs and wands use their actual handle origins. Shields face outward and attach at the back handle of each of their ten models. Priests hold books at the upper edge, and bows attach to the left hand with the right hand at the string.
- Standing, walking, running and flying use class-specific carry poses. Casters bend the elbow to keep long staffs and lanterns upright with a small forward lean; the hanging lantern stays in front. Spear attacks share a reachable grip between both hands and use a stable elbow bend.
- Starting a skill blends from the current pose; recovery resumes the latest movement request. Running cadence responds when movement speed changes without restarting the clip. Contact times, damage, cooldowns and animation lengths are preserved.
- `WeaponPoses` loads 21 small baked arm-track libraries (one per rig/class). The authoring solve runs offline via `tools/bake_weapon_poses.gd`; no runtime IK, skeleton duplication or new per-frame gear solver is added.
- `weapon_motion_test` checks all ten weapon tiers against actual grip geometry, samples full motion loops and spear/bow attacks, and checks transitions. `tests/tools/weapon_motion_review.tscn` captures equipped front/side/rear poses; `weapon_motion_showcase.tscn` records movement and attacks from the actual renderer.

## Version 0.7.0

- All 152 active skills have distinct original illustrated icons, keyed by skill ID. The hotbar, loadout picker, trainer and buff/summon timers share the same cached 192px art. `tools/make_skill_icons.py` authors the vector sources with explicit per-skill compositions; `skill_icons_test` checks every imported raster, uniqueness and real HUD cooldown/locked states.
- `SkillChoreography` explicitly maps all 152 skills to 19 gestures and 35 visual signatures. The existing animation clips are sampled so their contact frame matches the actual release, including haste; recovery restores locomotion and hit/death actions can interrupt safely.
- `SkillTableau` replaces universal layers with effects appropriate to each skill: broad sword cuts, spear thrusts, feathered bow shots, water spirals, ice crowns, forked lightning, flowering heals, woodland spirits and staged ultimates. Shared geometry and two lightweight ink shaders keep the existing quality budgets.
- Projectile bodies and range indicators survive budget saturation. Decorative rain/meteor impacts follow the real damage timing; hero and companion differences are respected. Spell art never schedules damage or modifies skill stats.
- Validation fixtures: `skill_choreography_test`, `skill_presentation_test`, `vfx_mesh_cache_test`, `armageddon_test`, and `tests/tools/skill_art_showcase.tscn`. The showcase captures actual hero casts, with optional Godot movie output.

## Play

- Left joystick / WASD: move. Drag the right side / right mouse: turn the camera. Pinch / mouse wheel: zoom.
- Sword button / Space: lock a nearby monster and auto-attack. Eight skills sit in one row along the bottom; keyboard shortcuts are 1–8.
- Far-right vertical controls, top to bottom: HP potion, MP potion, auto hunting, target switch. Walk manually to stop auto hunting.
- Menu / I: character, equipment, skills, quests, achievements and settings. H/M use potions; Tab switches targets.

Every hero begins as a **Vagabond**. Customize face, hair, skin and outfit, then choose Warrior, Archer, Mage, Priest, Summoner, Lancer, Defender or Assassin at **Lv.10**. The Defender fights with one great shield: it bashes, quakes the ground, provokes enemies onto itself and reflects their blows. The Assassin fights with twin daggers out of the shadows: the fastest attacks and hardest critical hits, shadow steps, poison, thrown knives and smoke, with its own daggers, star and divine sets and layered shadow wings (models authored by `tools/make_assassin_gear.py`): torn bat wings over a smaller under wing, a fan of kunai, shadow tendrils and, on the star pair, a phantom double and a black-sun halo with a turning corona, all animated by `characters/shadow_wing_art.gd`. Every Assassin skill also gets a layered shadow composition (`combat/shadow_skill_art.gd`): phantom assassins, crossing crescent cuts, flying and falling daggers, a crescent moon, a black sun, rifts, death sigils, smoke shells, bat wings and dagger crowns. Advance at **Lv.20 / 40 / 60 / 80**. Arrange eight skills from each class's active skill pool and upgrade passive skills.

## Adventure

Travel from Mistwood village through ten hunting fields to Lv.100, with the Void field available for endgame adventures. Equip weapons and outfits that appear on the hero, enhance equipment to +10, socket gems, collect set bonuses and earn wings. Travel with one AI companion with follow, aggressive or guard behavior. The village provides shops, storage, healing, skill training, quests and travel crystals.

After Lv.100, earn **Paragon** levels, collect star equipment in the Void, and climb the **Void Tower**. Ranked arena opponents are **AI**, not online players; stronger ranks can heal and dodge. Daily quests and achievements provide additional goals.

## Version 0.6.0

- On the hosted Toon Tale site, create a game ID (3–24 lowercase letters, digits or underscores) and password (10–128 characters), then use the same account on another phone or computer. Passwords are hashed server-side; browser sessions use secure, HttpOnly cookies.
- Existing four-slot local saves can be imported into an account after reviewing character summaries. Guest characters remain separate from account characters. Save revisions prevent another device from silently overwriting newer progress.
- Offline drafts stay on the device and retry when connected. Conflicting progress asks which whole save to use and keeps a local backup; gold and items are never merged automatically. One game tab per browser owns the save filesystem.
- Keep the recovery code shown during registration: it resets a forgotten password and revokes old sessions. Settings → บัญชี / เซฟออนไลน์ opens account status, manual sync and logout.
- Cloud accounts require the site's Worker/D1 backend; a standalone static/GitHub Pages export retains local play and backup-code transfer, but cannot provide online login by itself.

## Version 0.5.2

- Browser/mobile combat defaults to continuous motion. The optional cinematic hitstop is available under Settings; graphics quality does not control it.
- High quality retains the authored effect layers, with a 1920 px canvas long-edge budget rather than full 3x Retina resolution. Medium/low use 1600/1280 px; changes apply immediately and input follows the canvas rectangle after rotation.
- Reuses bounded caches of skill meshes, prebuilds authored templates during field loading, and warms meteor shaders before combat. Animated material instances remain independent.
- Buff/summon HUD timers refresh at 20 Hz. Terrain shares identical vertices, and foliage bounds omit empty space while retaining wind movement and distance-culling centres.
- The illustrated Toon Tale iPhone home-screen icon remains available in the web build.

## Version 0.5.1

- All ten summoner lantern designs rotate 180 degrees around the shaft so the hanging orb faces forward; shared by heroes, companions and equipment previews. Existing saves receive the fix automatically.
- Armageddon keeps all eleven hits and their damage, with **0.5 seconds between hits**. Fragment flight, fuse and cleanup timing follow the same cadence.

## Version 0.5.0

- All **152 active skills** use class-specific 3D shapes, textured particles and layered cast/impact timing. Higher unlock levels add more layers, bounded by graphics quality and effect budgets.
- Six final skills have distinct silhouettes: descending swords, a phoenix arrow, Armageddon, winged cathedral light, an elder dragon and a spiral lance. Projectile impacts happen on arrival.
- **Armageddon** drops a giant meteor, then detonates **10 fragments at one-second intervals**. All eleven hits cause real area damage through the existing critical-hit, rank and burn systems; MP and cooldown are charged once. Each fragment deals 12% of the main hit, totaling 2.2 times the previous direct damage if every hit connects. Burn refreshes the existing status rather than stacking ten independent burns.
- Caster death, field changes and pause safely stop or suspend the cast. Cosmetic saturation does not suppress damage or essential projectile silhouettes.
- Uses original, unmodified **CC0** particle textures from **Kenney** and **RPicster**; licenses, source URLs and SHA-256 manifests are included under `assets/vfx/`.
- Actual-character animation capture and Hero/Companion combat tests cover the new sequence, cancellation, rank scaling and resource cleanup.

## Version 0.4.0

- Authored palettes, silhouettes and animation timing for all **152 active skills** across Vagabond and all six professions. Painted sword arcs, feathered arrows, petal healing, winged blessings, layered wards and elemental fire, ice and vines.
- All **11 hunting fields**, the **Void Tower**, **wave arena** and **ranked coliseum** receive surface and environment treatments. Natural vegetation clusters, irregular trails, layered mountain silhouettes, shoreline habitats and regional boss landmarks distinguish the fields; special arenas have their own architecture and worn surfaces.
- The expanded Japanese village, six-class equipment, wings and existing gameplay from the latest upstream version are preserved.
- Every decorative elemental mesh respects graphics-quality budgets, including delayed shards and ground effects. Essential projectile visuals and combat resolution retain their original lifetimes.
- Art catalogue tools capture every active skill and all 15 locations from the actual renderer. Headless checks cover recipe completeness, effect budgets and scene cleanup.

## Version 0.3.1

- Eight skills now sit in a single bottom row. HP potion, MP potion, auto and target form a vertical column at the far right. Layout checks cover three aspect ratios and phone safe-area insets.

## Version 0.3.0

- Softer landscape colors, regional landmarks, cottage details and natural camp clearings.
- Sculpted hair, layered eyes and catchlights, blinking, softer character/monster outlines and material finish.
- Class-specific crests, ribbons and elemental accents across all **102 active skills**. Decorative effect limits follow graphics quality and crowding.
- Navy, cream and gold interface, equipped hero preview on the save screen, responsive creator and single-row bottom skill bank.
- Quest rewards track the actual EXP curve; EXP overflowing Lv.100 continues into Paragon.
- Save imports show a preview and destination, validate nested data and preserve the current save if writing fails. Restoring a character rebuilds the active scene.
- The web loader decompresses files as streams to avoid accumulating another complete compressed buffer.

## Saves

Four save slots are stored in the current browser/device. Use **Settings → สำรอง / นำเข้าเซฟ** to copy a backup code before changing devices or clearing browser data. Review the character and destination slot before restoring. Arena/tower backups resume safely in town. Saves are local; there is no account or cloud synchronization.

## Run and validate

Open `project.godot` with Godot 4.3, or:

```bash
godot --headless --editor --import --path .
godot --path .
godot --headless --path . -s res://tools/check_scripts.gd
godot --headless --path . -s res://tests/integration/character_finish_test.gd
godot --headless --path . res://tests/integration/save_progression_test.tscn
godot --headless --fixed-fps 60 --path . res://tests/integration/armageddon_test.tscn
godot --headless --path . res://tests/integration/skill_presentation_test.tscn
godot --headless --path . res://tests/integration/art_direction_test.tscn -- skills
godot --headless --path . res://tests/integration/element_fx_budget_test.tscn
godot --headless --path . res://tests/integration/scenery_bounds_test.tscn
godot --headless --path . res://tests/integration/vfx_mesh_cache_test.tscn
godot --headless --path . res://tests/integration/smooth_hitstop_test.tscn
godot --headless --path . res://tests/integration/flow_test.tscn -- hud
godot --headless --path . res://tests/tools/ui_polish_review.tscn
godot --headless --path . res://tests/integration/flow_test.tscn
node tools/test_web_loader.mjs
node tools/test_web_resolution.mjs
```

Tests create and delete game saves: run them with a separate `XDG_DATA_HOME` on Linux. The GitHub Actions workflow pins Godot 4.3 and isolates save, UI and integration fixtures. Character checks cover blinking, hair geometry and material reuse; the headless UI check verifies touch-control spacing and all eight populated skill slots. The balance simulator is a rough combat estimate, not a complete playthrough: `godot --headless --path . -s res://tools/balance.gd`.

For rendered Armageddon verification, omit `--headless` and retain `--fixed-fps 60`. This fixture accelerates gameplay eightfold; fixed frame steps keep checks inside the meteor descent and first-impact windows even on a slow software renderer. The same assertions cover all eleven damage events, casting costs, pause, cancellation and visual cleanup.

## Build the browser game

Install the matching Godot 4.3 Web export templates. The project uses the single-threaded web export.

```bash
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
python3 tools/package_web.py --pages docs/play
```

`build/web_artifact` is suitable for static hosting. `docs/play` adds the web app manifest and iPhone home-screen metadata. Publishing source changes alone does not rebuild the existing browser bundle; export and package it before publishing a release.

## Visual review

Version 0.5.0 actual combat frames: [Armageddon](docs/screenshots/v0.5.0/armageddon.jpg), [Gladiator](docs/screenshots/v0.5.0/gladiator.jpg), [Meteor Arrow](docs/screenshots/v0.5.0/meteor_arrow.jpg), [Last Judgement](docs/screenshots/v0.5.0/last_judgement.jpg), [Elder Dragon](docs/screenshots/v0.5.0/elder_dragon.jpg), [Ragnarok Lance](docs/screenshots/v0.5.0/ragnarok_lance.jpg).

Record the actual level-100 heroes and combat effects as PNG animation frames:

```bash
godot --path . --fixed-fps 24 res://tests/tools/spectacle_showcase.tscn -- /tmp/toon-spectacle ultimates 24 1280 720 2
```


Version 0.4.0 captures: [all 15 locations](docs/screenshots/v0.4.0/all-stages.jpg), [Warrior](docs/screenshots/v0.4.0/skills-warrior.jpg), [Archer](docs/screenshots/v0.4.0/skills-archer.jpg), [Mage](docs/screenshots/v0.4.0/skills-mage.jpg), [Priest](docs/screenshots/v0.4.0/skills-priest.jpg), [Summoner](docs/screenshots/v0.4.0/skills-summoner.jpg), [Lancer](docs/screenshots/v0.4.0/skills-lancer.jpg), and [eight-skill HUD](docs/screenshots/v0.4.0/hud.png).

Earlier captures: [heroes](docs/screenshots/v0.3.0/heroes.png), [representative skill effects](docs/screenshots/v0.3.0/skills.png), [eight-slot HUD](docs/screenshots/v0.3.1/hud.png), and [inventory](docs/screenshots/v0.3.0/inventory.png).

```bash
godot --rendering-driver opengl3 --path . res://tests/tools/art_catalog.tscn -- /tmp/toon-art zones all 2
godot --rendering-driver opengl3 --path . res://tests/tools/art_catalog.tscn -- /tmp/toon-art skills all 2
godot --rendering-driver opengl3 --path . res://tests/tools/tour.tscn -- /tmp/toon-shots warrior field
godot --rendering-driver opengl3 --path . res://tests/tools/look_preview.tscn -- /tmp/heroes.png classes
godot --rendering-driver opengl3 --path . res://tests/tools/monster_preview.tscn -- /tmp/monsters.png zone:meadow
godot --rendering-driver opengl3 --path . res://tests/tools/ui_polish_review.tscn -- /tmp/toon-ui-shots
```

Inspect menus, touch targets, boss telegraphs and crowded skill effects on representative phones. Desktop software-renderer timings do not establish mobile performance.

## Credits

See [ASSET_CREDITS.md](ASSET_CREDITS.md). KayKit Adventurers and Quaternius models are CC0. Fonts are SIL OFL. Audio credits and source licenses are retained with the project.
