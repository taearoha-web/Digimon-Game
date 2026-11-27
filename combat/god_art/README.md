Signature art of the god-tier (300 star) skills: one script per skill id
(`<skill id>.gd`), looked up by `GodSkillArt.signature`. Each exposes static
`telegraph`, `wave` and `finale` returning true when it drew that beat.

`_kit_arcane.gd` is shared by the summoner, dark lord and bard signatures: it puts
StarSkillArt layers drawn with the `god_arcane_*` shaders (solid toon bodies, a body
laid along a spline, additive light, alpha-mixed smoke and fire) and builds their
meshes. Scripts whose name starts with `_` are kits, never a skill's own art.

The ★500 Ascension ultimates live here too (AscendSkillData ids). Most replay their
class's god art under the Ascension's heavens (AscendSkillArt.ult_*);
`heavenly_master_fist.gd` (Muay Thai) draws its own show with RamakienArt's engine and
the master / arch / temple / fist figures of RamakienSculpt: a finisher
(AscendSkillData.FINISHERS), so one blow after the ไหว้ครู and a dash, no waves.
