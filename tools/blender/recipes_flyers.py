"""Remaster recipes for the flying monsters (team "flyers"): dragons, ghosts, bees, bats,
wizards. Same pipeline as remaster_monsters.py (see its docstring), plus kit_flyers:
emissive Glow materials for eyes / runes / embers, so they keep their colour under every
MonsterData tint.

    /opt/bpy5/bin/python tools/blender/recipes_flyers.py [flying/Dragon ...]

Design rule: these are eerie or fierce creatures - no blush, no cute eyes: glowing slit
or hollow eyes under heavy lids, fangs, horns, scales, chitin, bone, ragged ectoplasm.
Base colours stay fairly light where a model is shared by strongly tinted monsters, so
each tint still reads as its own creature.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
import kit_flyers as K  # noqa: E402
from mathutils import Vector  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "models", "monsters")
OUT = os.path.join(SRC, "remaster")

C = L.srgb
WHITE = C("ffffff")
UP = Vector((0, 0, 1))


def front_hit(surf, x, z, from_y=-6.0):
    return surf.toward(Vector((x, from_y, z)), Vector((x, 0.0, z)))


def dir_hit(surf, center, direction):
    d = direction.normalized()
    return surf.toward(center + d * 8.0, center)


# ---------------------------------------------------------------- dragons

def _dragon_paint(top, mid, belly, plate_line, membrane, membrane_edge, horn_root, horn_tip, mouth, scale_size,
                  wing_bones=("Wing1", "Wing2", "Wing3", "Wing4")):
    def paint(name, co, n, info):
        bone = info["bone"]
        on_wing = bone.startswith(wing_bones)
        if name == "Dragon_Horn":
            # Horns, wing claws and fangs: dark root to pale ivory tip, faint growth rings.
            t = L.smooth(-0.02, 0.12, info["bump"])
            c = L.mix(horn_root, horn_tip, t)
            return L.mix(c, c * 0.8, 0.5 + 0.5 * math.sin(co.length * 40.0) * (1.0 - t))
        if name == "Dragon_Secondary":
            if on_wing:
                # Membrane: thin and warm towards the trailing edge (light through it).
                t = L.smooth(1.6, 2.4, co.z) * 0.4 + L.smooth(0.5, 1.4, co.y) * 0.6
                c = L.mix(membrane, membrane_edge, t)
                return L.mix(c, c * 0.7, K.fbm(co, 0.35) * 0.5 + 0.2)
            if bone == "Head":
                return mouth
            # Belly plates: horizontal bands with dark seams.
            band = abs(math.sin(co.z * math.pi / 0.17))
            return L.mix(belly, plate_line, L.smooth(0.35, 0.0, band) * 0.85)
        # Main hide: dark crest, warm sides, pale underside, Voronoi scales.
        back = max(0.0, n.y) * 0.7 + max(0.0, n.z) * 0.6
        c = L.mix(mid, top, L.smooth(0.25, 0.8, back))
        c = L.mix(c, belly, L.smooth(-0.15, -0.75, n.z) * 0.6 + max(0.0, -n.y) * L.smooth(1.9, 1.3, co.z) * 0.4)
        g = K.scales(co, scale_size)
        c = L.mix(c, c * 0.6, g * (0.4 + 0.3 * L.smooth(0.4, 0.9, back)))
        return L.mix(c, c * 1.12, L.smooth(0.0, 0.05, info["bump"]))

    return paint


def _dragon_face(parts, surf, body, eyes, hide, brow, glow_ball, weights, horn_root, horn_tip, big=True):
    for c, r in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        gaze = Vector((0.35 * sx, -1.0, 0.05)).normalized()
        K.fierce_eye(parts, c, r * 0.98, gaze, weights, hide, brow=brow, ball=glow_ball, slit=(0.09, 0.55),
                     tilt=0.5, open_=0.3, brow_size=1.25 if big else 1.0, lower_lid=0.55)


def dragon_elder(arm, body):
    """Dragon_Evolved: fire_dragon (untinted), magma / abyss / gold dragons (tinted), prism,
    shrine, elder summon. Amber hide that every tint turns into its own fire."""
    eyes = K.eye_balls(body, ("Eye_White",))
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    L.decimate_to(body, 5200)
    L.relax(body, 2, 0.35, ("Dragon_Main",))
    # Golden-amber hide with a red crest: untinted it is a fire dragon; the gold tint
    # needs green in the base to read gold, the abyss / magma tints darken it to crimson.
    top, mid, belly = C("9a2c14"), C("f2aa4c"), C("fff2b8")
    horn_root, horn_tip = C("3a2a2a"), C("fff0d0")
    paint = _dragon_paint(top, mid, belly, C("c8782e"), C("8a2a18"), C("ffb050"), horn_root, horn_tip,
                          C("5a0a14"), 0.2)
    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    _dragon_face(parts, surf, body, eyes, C("c85a24"), C("7a2a12"), C("ffe08a"), {"Head": 1.0}, horn_root,
                 horn_tip)
    horn_col = lambda t: L.mix(horn_root, horn_tip, L.smooth(0.0, 0.9, t))  # noqa: E731
    # Two great swept-back horns and a pair of smaller ones under them.
    for sx in (-1.0, 1.0):
        p, n = dir_hit(surf, Vector((0.0, -0.2, 2.35)), Vector((0.55 * sx, 0.35, 0.85)))
        if p is not None:
            K.fang(parts, p - n * 0.05, Vector((0.35 * sx, 0.85, 0.55)), 0.95, 0.13, {"Head": 1.0},
                   col_root=horn_root, col_tip=horn_tip)
        p, n = dir_hit(surf, Vector((0.0, -0.3, 2.2)), Vector((0.95 * sx, 0.1, 0.1)))
        if p is not None:
            parts.blob(p - n * 0.04, (0.07, 0.05), Vector((0.8 * sx, 0.6, -0.1)), 0.42, None, weights={"Head": 1.0},
                       seg=8, rings=5, tip=0.05, color_fn=horn_col)
    # Dorsal spines from the crown down the neck, back and tail.
    K.ridge(parts, surf, Vector((0.0, 0.0, 2.0)), [(Vector((0, 1.0, 1.2)), 0.9), (Vector((0, 1.0, 0.7)), 1.0),
                                                   (Vector((0, 1.0, 0.3)), 1.0), (Vector((0, 1.0, 0.0)), 0.95),
                                                   (Vector((0, 1.0, -0.3)), 0.9)],
            0.5, 0.17, horn_col, tilt=Vector((0, 0.6, 0)))
    for z, s in ((1.25, 0.85), (1.0, 0.75), (0.75, 0.65), (0.5, 0.55), (0.3, 0.45)):
        p, n = surf.toward(Vector((0.0, 5.0, z + 0.25)), Vector((0.0, 0.3, z)))
        if p is not None:
            parts.blob(p - n * 0.04, (0.16 * s, 0.06 * s), (n + Vector((0, 0.3, -0.4))).normalized(), 0.48 * s, None,
                       weights=p, seg=8, rings=5, tip=0.05, color_fn=horn_col, up=Vector((1, 0, 0)))
    # Nostrils that smoulder.
    for sx in (-1.0, 1.0):
        p, n = front_hit(surf, 0.1 * sx, 2.05)
        if p is not None:
            parts.decal(p, n, [(math.cos(a) * 0.04, math.sin(a) * 0.025) for a in
                               [i * math.pi / 6 for i in range(12)]], C("2a0806"), rings=1, lift=0.01)
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.5, shade=Vector((0.55, 0.42, 0.45)))
    return {"glow": "ffc040", "strength": 2.2}


RECIPES = {
    "flying/Dragon_Evolved": dragon_elder,
}


def build(name):
    import bpy
    L.reset()
    arm, body = L.load(os.path.join(SRC, name + ".gltf"))
    K.atlas_regions(body)
    clips = sorted(a.name for a in bpy.data.actions)
    before = L.tri_count(body)
    opts = RECIPES[name](arm, body) or {}
    out = os.path.join(OUT, name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    K.export(arm, body, out, clips, glow=opts.get("glow", "ffc040"), glow2=opts.get("glow2"),
             strength=opts.get("strength", 1.6), strength2=opts.get("strength2", 1.6))
    print("REMASTER %s tris %d -> %d, %d bytes, clips %s" % (name, before, L.tri_count(body), os.path.getsize(out),
                                                          ",".join(clips)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
