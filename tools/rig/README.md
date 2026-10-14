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
