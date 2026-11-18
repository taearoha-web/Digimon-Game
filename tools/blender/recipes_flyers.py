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
    return {"glow": "ffa820", "strength": 1.3}


def dragon_young(arm, body):
    """Dragon: sand_dragon (sand tint), storm_dragon (blue), drake summon (teal), cloud
    whelp, leviathan whelp. A pale stone-and-sand hide with a dark dorsal crest and
    banded belly, so each tint paints the whole beast; lightning-pale glowing eyes."""
    eyes = K.eye_balls(body, ("Eye_White",))
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5600)
    L.relax(body, 2, 0.35, ("Dragon_Main",))
    top, mid, belly = C("9a8676"), C("e8d6b4"), C("fff8e4")
    horn_root, horn_tip = C("7a6a62"), C("fffaf0")
    paint = _dragon_paint(top, mid, belly, C("b0a088"), C("4a4450"), C("d8d0d8"), horn_root, horn_tip,
                          C("3a0e18"), 0.2)
    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    _dragon_face(parts, surf, body, eyes, C("c8b494"), C("5a4a42"), C("fff4c0"), {"Head": 1.0}, horn_root,
                 horn_tip)
    horn_col = lambda t: L.mix(horn_root, horn_tip, L.smooth(0.0, 0.9, t))  # noqa: E731
    # Crest spines over the skull and down the neck; a pair of swept cheek frills.
    K.ridge(parts, surf, Vector((0.0, 0.0, 2.2)), [(Vector((0, 0.6, 1.0)), 0.9), (Vector((0, 1.0, 0.8)), 1.0),
                                                   (Vector((0, 1.0, 0.35)), 0.95), (Vector((0, 1.0, 0.0)), 0.85),
                                                   (Vector((0, 1.0, -0.35)), 0.7)],
            0.42, 0.15, horn_col, tilt=Vector((0, 0.6, 0)))
    for sx in (-1.0, 1.0):
        p, n = dir_hit(surf, Vector((0.0, -0.2, 2.15)), Vector((1.0 * sx, 0.15, -0.05)))
        if p is not None:
            for k, (dz, ln) in enumerate(((0.06, 0.42), (-0.08, 0.32))):
                parts.blob(p - n * 0.04 + Vector((0, 0.05 * k, dz)), (0.07, 0.04), Vector((0.75 * sx, 0.65, -0.05 + dz)),
                           ln, None, weights={"Head": 1.0}, seg=8, rings=5, tip=0.05, color_fn=horn_col)
        p, n = front_hit(surf, 0.1 * sx, 2.05)
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.5, shade=Vector((0.5, 0.48, 0.58)))
    return {"glow": "ffe050", "strength": 1.3}


# ---------------------------------------------------------------- ghosts

def _ghost_paint(top, low, deep, swirl, teeth=C("f4ecdc"), mouth=C("14061e"), top_z=2.6, low_z=0.5):
    def paint(name, co, n, info):
        if name in ("Eye_White",):
            return teeth
        if name in ("Eye_Black",):
            return mouth
        h = L.smooth(low_z, top_z, co.z)
        c = L.mix(low, top, h)
        # Ectoplasm thins out towards hands and tail: deeper colour at the extremities.
        ext = L.smooth(1.2, 2.6, abs(co.x)) + L.smooth(1.0, 0.3, co.z)
        c = L.mix(c, deep, min(1.0, ext) * 0.7)
        c = L.mix(c, swirl, max(0.0, K.fbm(co + Vector((0, 0, co.z * 0.5)), 0.45)) * 0.5)
        return L.mix(c, c * 1.15, max(0.0, -n.y) * 0.25)

    return paint


def _wisps(parts, surf, base_z, col_fn, count=5, spread=0.3, length=0.55, seed=4):
    """Ragged ectoplasm tatters trailing from the lower body."""
    rng = random.Random(seed)
    for k in range(count):
        a = math.pi * 2.0 * k / count + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a) * 0.8 + 0.25, -0.4))
        p, n = dir_hit(surf, Vector((0.0, 0.25, base_z + 0.25)), d)
        if p is None:
            continue
        axis = (n * 0.35 + Vector((0, 0.35, -1.0))).normalized()
        parts.blob(p - n * 0.05, (0.09, 0.05), axis, length * rng.uniform(0.75, 1.15), None, weights=p, seg=8, rings=6,
                   tip=0.04, color_fn=col_fn, bend=Vector((math.cos(a) * 0.15, 0.2, 0.0)))


def ghost(arm, body):
    """Ghost: ghost (violet), abyss_ghost (blood-red tint), elemental summon (blue),
    lotus sprite (pink). A pale ectoplasm spook with hollow sockets and burning pinpoint
    eyes, a jagged grin and tattered wisps; pale base so every tint becomes its glow."""
    eyes = [e for e in K.eye_balls(body, ("Eye_White",)) if e[0].z > 1.85]
    L.delete_faces(body, where=lambda c, n, g: (n == "Eye_White" and c.z > 1.82) or (n == "Eye_Black" and c.z > 2.0))
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5200)
    L.relax(body, 2, 0.35, ("Ghost_Main",))
    top, low, deep, swirl = C("efe6ff"), C("a48ae6"), C("4a2a8a"), C("ffffff")
    L.paint_body(body, _ghost_paint(top, low, deep, swirl, top_z=2.8, low_z=0.6))
    surf = L.Surface(body)
    parts = K.FParts(surf)
    for c, r in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        K.hollow_eye(parts, c, r * 1.0, Vector((0.3 * sx, -1.0, 0.0)), {"Head": 1.0}, lid_col=C("cbb8f6"),
                     tilt=0.55, open_=0.45, pupil=0.48, sink=0.6)
    _wisps(parts, surf, 0.55, lambda t: L.mix(C("8a6ad0"), C("3a1a70"), t), count=5, length=0.5)
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.4, shade=Vector((0.55, 0.5, 0.8)))
    return {"glow": "8af2ff", "strength": 1.5}


def skull_ghost(arm, body):
    """Ghost_Skull: grave_ghost (cold blue), star_wraith (violet), eclipse wraith. A cracked
    bone skull with embers burning deep in its sockets over a shadowy wraith body that
    frays into tatters; faint star motes in the shadow."""
    L.clean(body)
    skull = L.split_off(body, ("Head",))
    L.subdivide(body, 1)
    L.decimate_to(body, 4200)
    L.relax(body, 2, 0.35)
    L.clean(skull, quads=False)
    L.join(body, skull)
    bone_top, bone_low, crevice = C("fbf4e4"), C("d8cbb4"), C("2a1a2c")
    shade_top, shade_low, mote = C("5a4a9a"), C("1c1438"), C("c8d8ff")

    def paint(name, co, n, info):
        if name == "c_a58c72":
            c = L.mix(bone_low, bone_top, L.smooth(1.5, 2.5, co.z))
            c = L.mix(c, crevice, L.smooth(-0.01, -0.06, info["bump"]) * 0.85)
            return c
        h = L.smooth(0.4, 2.4, co.z)
        c = L.mix(shade_low, shade_top, h)
        c = L.mix(c, shade_low * 0.6, L.smooth(1.3, 2.6, abs(co.x)) * 0.6)
        star = K.fbm(co, 0.08, 1)
        return L.mix(c, mote, L.smooth(0.42, 0.55, star))

    L.paint_body(body, paint)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    # Embers in the sockets (the hollows sit at about x +-0.28, z 1.95).
    for sx in (-1.0, 1.0):
        c = Vector((0.27 * sx, -0.3, 1.95))
        p, n = surf.toward(Vector((0.27 * sx, -5.0, 1.95)), c)
        if p is None:
            continue
        g = p + Vector((0.0, -0.02, -0.01))
        parts.ellipsoid(g, (0.115, 0.05, 0.1), color=None, weights={"Head": 1.0}, detail="glow", seg=10, rings=6,
                        color_fn=lambda u: L.mix(C("e8f8ff"), C("7ad0ff"), L.smooth(0.3, -0.8, u.z)))
        # A cruel slant: shadowed brow ridge over the socket, low at the nose.
        p3, n3 = front_hit(surf, 0.27 * sx, 2.1)
        if p3 is not None:
            parts.stroke(p3, n3, [(0.17 * sx, 0.05), (0.05 * sx, 0.0), (-0.1 * sx, -0.07)], 0.06, crevice,
                         lift=0.012)
        # Brow crack running up from the socket.
        p2, n2 = front_hit(surf, 0.18 * sx, 2.25)
        if p2 is not None:
            parts.stroke(p2, n2, [(0.0, -0.06), (0.04 * sx, 0.02), (0.01 * sx, 0.09), (0.06 * sx, 0.17), (0.04 * sx, 0.24)], 0.02,
                         crevice, lift=0.01, taper=True)
    _wisps(parts, surf, 0.5, lambda t: L.mix(C("3a2a6a"), C("120a24"), t), count=6, length=0.55, seed=9)
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.45, shade=Vector((0.5, 0.48, 0.7)))
    return {"glow": "a8ecff", "strength": 1.7}


# ---------------------------------------------------------------- bees

def _compound(centre, dark, mid, rim):
    """Faceted compound-eye paint around an eyeball centre."""
    def col(co):
        d = (co - centre).normalized()
        f = K.scales(d, 0.11)
        c = L.mix(mid, dark, L.smooth(-0.2, 0.7, d.z))
        c = L.mix(c, rim, L.smooth(0.4, 1.0, -d.y) * L.smooth(0.3, -0.5, d.z) * 0.5)
        return L.mix(c, dark * 0.5, f * 0.8)
    return col


def _bee(arm, body, chitin_top, chitin_low, stripe_a, stripe_b, eye_dark, eye_mid, eye_rim, wing_root, wing_tip,
         stinger_col, ice=False):
    eyes = K.eye_balls(body, ("Eye_White",))
    snap = K.Snapshot(body, ("Armabee_Main", "Armabee_Secondary"))
    L.delete_faces(body, ("Eye_Black",))
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5600)
    L.relax(body, 2, 0.3, ("Armabee_Main", "Armabee_Secondary"))
    eye_cols = [_compound(c, eye_dark, eye_mid, eye_rim) for c, r in eyes]

    def paint(name, co, n, info):
        if name == "Eye_White":
            k = 0 if (len(eyes) < 2 or abs(co.x - eyes[0][0].x) < abs(co.x - eyes[1][0].x)) else 1
            return eye_cols[k](co)
        if name == "Wings":
            # Membrane: smoky root, clear pale blade, dark veins.
            t = L.smooth(0.4, 2.0, abs(co.x))
            c = L.mix(wing_root, wing_tip, t)
            vein = abs(math.sin((co.y * 1.3 + abs(co.x) * 0.45) * 9.0))
            return L.mix(c, wing_root * 0.6, L.smooth(0.12, 0.0, vein) * 0.7)
        if name == "Teeth":
            return L.mix(C("e8dcc4"), C("fffaf0"), L.smooth(-0.01, 0.05, info["bump"]))
        if name == "Tongue":
            return C("5a1a4a")
        stripe = 0.0
        if name in ("Armabee_Secondary", "Armabee_Main"):
            stripe = 1.0 if snap.region(co) == "Armabee_Secondary" else 0.0
        if stripe > 0.0:
            c = L.mix(stripe_b, stripe_a, L.smooth(-0.6, 0.6, n.z) * 0.6 + 0.4 * max(0.0, -n.y))
            c = L.mix(c, c * 0.8, abs(K.fbm(co, 0.12, 2)) * 0.35)
            if stripe >= 1.0:
                return c
        k = L.mix(chitin_low, chitin_top, L.smooth(-0.5, 0.8, n.z))
        # Hard chitin catches a cool rim of light.
        k = L.mix(k, L.mix(k, C("8aa0d0"), 0.5), L.smooth(0.55, 0.95, abs(n.x)) * 0.45)
        return L.mix(k, c, stripe) if stripe > 0.0 else k

    K.paint_body_glow(body, paint, glow=lambda name, co, bone: 2 if name == "Wings" else 0)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    for c, r in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        # A glint on the compound eye, and a chitin brow plate scowling over it.
        parts.sphere_cap(c, r, Vector((0.2 * sx, -1.0, 0.6)).normalized(), (0.16, 0.11), WHITE, {"Head": 1.0},
                         lift=0.02, seg=12, rings=2)
        a = c + Vector((0.9 * sx, -0.25, 0.85)).normalized() * r * 1.05
        b = c + Vector((-0.75 * sx, -0.6, 0.35)).normalized() * r * 1.05
        parts.blob(a, (r * 0.32, r * 0.16), b - a, (b - a).length * 1.2, None, weights={"Head": 1.0}, seg=10,
                   rings=6, tip=0.5, up=Vector((0, -1, 0.3)),
                   color_fn=lambda t: L.mix(chitin_top, chitin_low, t))
    # Stinger out of the abdomen tip, with a venom-lit point.
    lo, hi = L.bounds(body)
    axis = Vector((0.0, 0.55, -1.0)).normalized()
    p, n = dir_hit(surf, Vector((0.0, 0.1, lo.z + 0.6)), axis)
    if p is not None:
        parts.blob(p - axis * 0.05, 0.11, axis, 0.42, None, weights=p, seg=10, rings=6, tip=0.05,
                   color_fn=lambda t: L.mix(chitin_low, chitin_top, t))
        parts.blob(p + axis * 0.28, 0.035, axis, 0.18, None, weights=p, seg=6, rings=4, tip=0.05,
                   detail="glow", color_fn=lambda t: stinger_col)
    if ice:
        # Frost crystals along the back.
        rng = random.Random(3)
        for k in range(7):
            d = Vector((rng.uniform(-0.6, 0.6), 1.0, rng.uniform(-0.2, 0.9)))
            p, n = dir_hit(surf, Vector((0.0, 0.0, 1.9)), d)
            if p is None:
                continue
            s = rng.uniform(0.7, 1.15)
            parts.blob(p - n * 0.04, (0.07 * s, 0.05 * s), (n + Vector((0, 0, 0.4))).normalized(), 0.38 * s, None,
                       weights=p, seg=6, rings=3, tip=0.05,
                       color_fn=lambda t: L.mix(C("a8d8f8"), C("ffffff"), t))
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.4)


def poison_bee(arm, body):
    """Armabee: poison_bee. Glossy black chitin with acid-yellow bands, red faceted
    compound eyes under scowling brow plates, smoky veined wings with a faint sheen and a
    venom-lit stinger."""
    _bee(arm, body, C("3a3848"), C("0e0c14"), C("e8f048"), C("8ab020"), C("3a0606"), C("c8281a"), C("ff9a5a"),
         C("6a6a7a"), C("e8f4ff"), C("b8ff40"))
    return {"glow": "a8ff30", "strength": 1.6, "glow2": "b8d8f0", "strength2": 0.35}


def ice_bee(arm, body):
    """Armabee_Evolved: ice_bee (icy tint), gold pollen bee. Pale steel chitin and frost-white
    bands, ice crystals on the back, deep blue compound eyes, glittering wings, an icy
    stinger and mandibles."""
    _bee(arm, body, C("56648a"), C("181e34"), C("ffffff"), C("cfe4f8"), C("0a1440"), C("3a6ad0"), C("b0e0ff"),
         C("7a8aa0"), C("f4fbff"), C("a8f0ff"), ice=True)
    return {"glow": "a0f0ff", "strength": 1.6, "glow2": "c8e8ff", "strength2": 0.35}


# ---------------------------------------------------------------- bats

def _bat(arm, body, fur_top, fur_low, chest, membrane, membrane_edge, inner_ear, nose, ear_z, glow_ball,
         crown=False):
    eyes = [e for e in K.eye_balls(body, ("c_8f92a0",)) if abs(e[0].x) < 0.8]
    snap = K.Snapshot(body)
    L.delete_faces(body, ("c_1e1f22",), where=lambda c, n, g: n == "c_8f92a0" and abs(c.x) < 0.8)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5400 if not crown else 5800)
    L.relax(body, 2, 0.3, ("c_738636",))

    def paint(name, co, n, info):
        bone = info["bone"]
        region = snap.region(co)
        if name == "c_8f92a0":  # wing claws
            return L.mix(C("4a3a3a"), C("fff4e0"), L.smooth(-0.01, 0.06, info["bump"]))
        if name == "c_a58c72":  # fangs
            return L.mix(C("e8dcc4"), C("fffaf0"), L.smooth(-0.01, 0.04, info["bump"]))
        if name == "c_cc9129":  # crown of fire
            return L.mix(C("ff6a10"), C("fff0a0"), L.smooth(3.05, 3.5, co.z))
        on_wing = bone.startswith("Wing")
        if name == "c_5b354a" and on_wing:
            # Leathery membrane: dark near the finger bones, thin and lit at the edge, veins.
            t = L.smooth(0.6, 1.8, abs(co.x)) * 0.5 + L.smooth(0.5, 1.3, co.y) * 0.5
            c = L.mix(membrane, membrane_edge, t)
            vein = abs(math.sin(math.atan2(co.y - 0.3, abs(co.x) - 0.4) * 7.0))
            return L.mix(c, membrane * 0.6, L.smooth(0.15, 0.0, vein) * 0.5)
        if name == "c_5b354a":
            if bone == "Torso" or co.z < 1.75:
                return C("6a1a26")  # inside of the mouth
            return nose  # the nose-leaf ridge
        if on_wing:
            return L.mix(fur_low, fur_top, 0.4) * 0.8  # wing-finger bones
        # Fur: streaky (stretched noise), pale chest, darker crown; pink inside the ears.
        streak = K.fbm(Vector((co.x * 3.0, co.y * 3.0, co.z * 0.8)), 0.12, 2)
        c = L.mix(fur_low, fur_top, L.smooth(1.6, 2.8, co.z))
        c = L.mix(c, chest, L.smooth(-0.2, -0.8, n.y) * L.smooth(2.1, 1.6, co.z) * 0.8)
        c = L.mix(c, c * 0.7, max(0.0, streak) * 0.8)
        c = L.mix(c, c * 1.2, max(0.0, -streak) * 0.5)
        if co.z > ear_z and n.y < -0.2 and abs(co.x) > 0.25:
            c = L.mix(c, inner_ear, L.smooth(-0.2, -0.6, n.y) * L.smooth(ear_z, ear_z + 0.2, co.z))
        return c

    K.paint_body_glow(body, paint, glow=lambda name, co, bone: 2 if name == "c_cc9129" else 0)
    surf = L.Surface(body)
    parts = K.FParts(surf)
    for c, r in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        K.fierce_eye(parts, c, r * 0.8, Vector((0.3 * sx, -1.0, 0.0)), {"Head": 1.0}, fur_top * 0.9,
                     brow=fur_top * 0.7, ball=glow_ball, slit=(0.08, 0.45), tilt=0.6, open_=0.3, lower_lid=0.6)
    if not crown:
        # Two long fangs over the lower lip.
        lo_eye = min(c.z for c, r in eyes)
        for sx in (-1.0, 1.0):
            p, n = front_hit(surf, 0.13 * sx, lo_eye - 0.42)
            if p is not None:
                K.fang(parts, p - n * 0.03, Vector((0.0, -0.3, -1.0)), 0.24, 0.05, {"Head": 1.0})
    K.join_parts(body, parts.to_object())
    L.bake_ao(body, strength=0.45, shade=Vector((0.6, 0.45, 0.5)))


def blood_bat(arm, body):
    """Goleling: blood_bat. A vampire bat: streaky dark fur with a paler chest, pink inner
    ears, thin veined membranes, burning red slit eyes under a heavy brow, long fangs."""
    _bat(arm, body, C("a06a5e"), C("5a3438"), C("d8a090"), C("3a1a22"), C("b05a5a"), C("e88a90"), C("8a4c4c"),
         2.55, C("ff6060"))
    return {"glow": "ff3020", "strength": 1.6}


def flame_bat(arm, body):
    """Goleling_Evolved: flame_bee (fire bat), temple guardian. A soot-furred fire bat
    whose crown burns (emissive), ember-gold eyes, a fanged roaring maw."""
    _bat(arm, body, C("b08060"), C("5a3a2a"), C("e8c090"), C("3a1e18"), C("e08040"), C("f0a070"), C("8a5a40"),
         2.95, C("ffd060"), crown=True)
    return {"glow": "ffc040", "strength": 1.5, "glow2": "ff9020", "strength2": 1.3}


RECIPES = {
    "flying/Goleling": blood_bat,
    "flying/Goleling_Evolved": flame_bat,
    "flying/Armabee": poison_bee,
    "flying/Armabee_Evolved": ice_bee,
    "flying/Ghost_Skull": skull_ghost,
    "flying/Ghost": ghost,
    "flying/Dragon": dragon_young,
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
