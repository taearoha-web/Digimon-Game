# Legend summon pipeline

Turns a dense, unrigged textured model (e.g. 450k triangles, 2048px maps) into a
phone-ready summon: ~20k triangles, one 1024px colour atlas, a humanoid skeleton,
skin weights and the clips MonsterVisual plays (Idle, Walk, Run, Attack, HitReact, Death).

    pip install numpy scipy trimesh fast-simplification xatlas pillow
    python3 tools/rig/bake_texture.py source.glb baked.glb 20000 1024
    python3 tools/rig/build_rig.py baked.glb tools/rig/poseidon.json assets/models/monsters/summon/Poseidon.glb

1. `bake_texture.py` welds UV seams, decimates, unwraps a fresh atlas (xatlas) and
   re-bakes the colour from the source surface, so seams never crack.
2. `build_rig.py` places the joints from the spec (positions in the model's height-1
   space, the model facing +Z), weights by distance to the bone segments, smooths the
   weights over the mesh and keeps the weapon with the chest. The source meshes are one
   fused surface (cloth, ribbons and weapon touch everywhere), so the clips move the
   body as a whole: hover, lean, twist, breathe, a free arm and the head.

The 18 MB sources are not kept in the repository.

## Clips and the rig check (no source needed)

`rerig_legend.py` rebuilds a shipped glb in place: it keeps the triangles and texture,
rebuilds the skeleton from the spec and recomputes the skin weights and clips. It then
skins every clip and writes `rig_report.json`: the largest and 99.9th-percentile change
of a mesh edge's length in centimetres at game height (a tear shows there first).
Running it again on its own output gives the same rig.

    python3 tools/rig/rerig_legend.py assets/models/monsters/summon/WindKing.glb tools/rig/windking.json tools/rig/rig_report.json
    python3 tools/rig/rerig_legend.py assets/models/monsters/summon/Poseidon.glb tools/rig/poseidon.json tools/rig/rig_report.json

**Weights** (`legend_weights.py`). The decimated legends are one fused surface (the free
hand welded to the robe, the staff to the cloth at the feet, the legs to each other), so
weights alone cannot let those parts move apart. Three steps:

1. *Parts*: every triangle gets the bone that dominates it. Limbs claim only the surface
   within `core` of their bone, so robes, scarves and skirt panels belong to the torso.
   The weapon is its own part, held rigid in the hand. Islands under `min_part`
   triangles join their neighbours.
2. *Seams*: parts that do not share a joint are cut apart where they touch (the shared
   vertices are doubled; the triangle count is unchanged). Every pair in a group must
   share a joint, so a chain like forearm - upper arm - spine - hips cannot glue an elbow
   to the robe. An upper arm stays joined to the torso only within `shoulder_radius`.
3. *Weights*: distance weights restricted to each side's allowed bones, smoothed over the
   cut surface (`smooth`), with the cloth away from the body relaxed further
   (`cloth_smooth`) so a stride spreads over the whole panel.

Secondary chains (spec `extra`, e.g. the Monkey King's tail) are extra bones that claim
the surface within their `radius` and trail their parent in every clip.

**Clips** (`legend_clips.py`): character animation as code, sampled at 30 fps.
Legs use two-bone IK from foot targets, so feet plant while the hips bob, sway and turn.
Walk and Run are real gait cycles (stance / swing, heel strike and toe off, hip bob,
weight shift, counter-rotating chest and arms). The weapon arm uses IK to a hand target
plus an aim direction for the weapon. Half the wrist twist goes into the forearm.
Actions are Hermite-keyed: anticipation, strike on the LegendMoves `impact` second,
follow-through, recovery.

**Preview** (`legend_preview.py`): contact sheets (front, three-quarter, side; edges that change by
4 cm or more in red) and 15 fps GIFs of every clip, rendered in software.

    CELL=300 python3 tools/rig/legend_preview.py assets/models/monsters/summon/WindKing.glb tools/rig/windking.json /tmp/out Walk,Attack 7
