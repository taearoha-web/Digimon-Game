"""Team critters' remaster recipes (see remaster_monsters.py for the pipeline).

    /opt/bpy5/bin/python tools/blender/recipes_critters.py [big/Bunny ...]

Same contract as remaster_monsters.RECIPES, built with kit_critters' material set so
eyes, teeth and glowing marks stay untinted ("Keep..." materials). A few outputs are
VARIANTS of a shared rig for one monster only (big/FrogKing = toad_king): they are
written to remaster/<dir>/<Variant>.glb and that monster's "model" points at
"remaster/<dir>/<Variant>" directly.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
import kit_critters as K  # noqa: E402
import remaster_monsters as M  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

C = L.srgb
WHITE = C("ffffff")
V = Vector


def start(body, parts_cls=K.KParts):
    surf = L.Surface(body)
    return surf, parts_cls(surf)


def finish(body, parts, **ao):
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, **ao)


def cute_eye(parts, *a, **kw):
    with parts.use("keep"):
        M.sparkly_eye(parts, *a, **kw)


# ================================================================ big/Frog (pilot fix + variants)

def _frog_base(body):
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)


def _frog_is_belly(co):
    return abs(co.x) < 0.45 and co.z < 2.2 and co.y < 0.0


def _frog_toes(parts, arm, body, pad_fn, toe_fn):
    groups = L.dominant_groups(body)
    for sx in (-1.0, 1.0):
        side = "L" if sx > 0 else "R"
        for f in ("Index3", "Middle3", "Pinky3", "Thumb2"):
            b = arm.data.bones["%s.%s" % (f, side)]
            parts.ellipsoid(b.tail_local, (0.065, 0.065, 0.055), color=None, weights={b.name: 1.0}, seg=7, rings=4,
                            color_fn=pad_fn)
        foot = [body.data.vertices[i].co for i, g in enumerate(groups) if g == "Foot." + side]
        if foot:
            fy = min(v.y for v in foot)
            fz = min(v.z for v in foot)
            cx = sum(v.x for v in foot) / len(foot)
            for k in (-1, 0, 1):
                parts.ellipsoid(V((cx + 0.13 * k, fy + 0.05 + 0.03 * abs(k), fz + 0.05)), (0.07, 0.07, 0.05),
                                color=None, weights={"Foot." + side: 1.0}, seg=7, rings=4, color_fn=toe_fn)


def yellow_frog(arm, body):
    """Cute yellow poison frog (also lotus_frog, the summon frog): the pilot look, with the
    eyes and the cream belly on untinted materials so every tint keeps them clean."""
    _frog_base(body)
    yellow_top, yellow_low, belly, spot = C("ffe14d"), C("ffc233"), C("fff2b8"), C("2a2350")

    def paint(name, co, n, info):
        if name == "Frog_Secondary":
            return L.mix(belly, C("fffbe6"), L.smooth(1.0, 1.8, co.z)) if _frog_is_belly(co) else spot
        c = L.mix(yellow_low, yellow_top, L.smooth(0.5, 2.5, co.z))
        c = L.mix(c, C("ff9a1e"), max(0.0, n.y) * 0.25)
        return L.mix(c, C("fff3a0"), max(0.0, -n.z) * 0.4)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name == "Frog_Secondary" and _frog_is_belly(c)
                 else "skin")
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        cute_eye(parts, V((0.31 * sx, -0.43, 2.46)), 0.205, V((0.35 * sx, -1.0, 0.12)).normalized(),
                 C("2a1606"), C("e89a14"), {"Head": 1.0}, iris=0.62, pupil=0.36)
        p, n = M.front_hit(surf, 0.37 * sx, 2.22)
        M.cheek(parts, p, n, 0.075, 0.045, C("ff9a78"))
    _frog_toes(parts, arm, body, lambda u: L.mix(C("ffd36a"), C("fff4b0"), L.smooth(-0.5, 0.8, u.z)),
               lambda u: L.mix(C("ffc84a"), C("fff0a0"), L.smooth(-0.5, 0.8, u.z)))
    p, n = M.front_hit(surf, 0.0, 2.2)
    smile = [(x / 10.0 * 0.2, -0.06 * (1.0 - (x / 10.0) ** 2)) for x in range(-10, 11)]
    parts.stroke(p, n, smile, 0.04, C("7a3410"), lift=0.012)
    for d, s in [(V((0.35, 1.0, 0.3)), 0.11), (V((-0.4, 1.0, -0.2)), 0.09), (V((0.1, 1.0, -0.6)), 0.08),
                 (V((-0.2, 1.0, 0.8)), 0.07), (V((0.6, 0.6, -0.4)), 0.06), (V((-0.75, 0.3, 0.1)), 0.06)]:
        p, n = M.dir_hit(surf, V((0, 0.1, 1.6)), d)
        if p is not None:
            parts.decal(p, n, M.ellipse(s, s * 0.85, 16, rot=0.4), spot, rings=2)
    for sx in (-1.0, 1.0):
        p, n = M.dir_hit(surf, V((0.35 * sx, 0.2, 0.75)), V((0.8 * sx, 0.3, 0.2)))
        if p is not None:
            parts.decal(p, n, M.ellipse(0.07, 0.06, 14), spot, rings=2)
    finish(body, parts)


def toxic_frog(arm, body):
    """Deadly dart frog (toxic_frog only): near-black green hide laced with glowing neon
    venom stripes and glands, narrow glowing red eyes, a grim mouth dripping venom.
    Painted final colours (untinted)."""
    _frog_base(body)
    hide, hide_hi, under = C("173a26"), C("3f8a4a"), C("a8d84a")
    neon, neon_hi = C("8cff2a"), C("eaff8a")

    def paint(name, co, n, info):
        if name == "Frog_Secondary" and _frog_is_belly(co):
            return L.mix(C("6a9a2a"), under, L.smooth(1.0, 1.9, co.z))
        c = L.mix(hide, hide_hi, L.smooth(0.3, 2.4, co.z) * 0.5 + max(0.0, -n.y) * 0.35)
        return L.mix(c, C("4a7a3a"), max(0.0, -n.z) * 0.4)

    K.paint_body(body, paint, lambda *a: "keep")
    surf, parts = start(body)
    parts.mode = "keep"
    for sx in (-1.0, 1.0):
        K.fierce_eye(parts, V((0.31 * sx, -0.43, 2.46)), 0.205, V((0.3 * sx, -1.0, 0.1)).normalized(), C("ffb02a"),
                     C("ff1a1a"), {"Head": 1.0}, lid=C("1f4a2a"), slant=0.4, side=sx, slit=True, pupil_w=0.5,
                     iris=0.8, sclera=C("ffd23a"), glow=True, lid_drop=1.7)
    _frog_toes(parts, arm, body, lambda u: L.mix(C("1a3a1a"), C("4a8a2a"), L.smooth(-0.5, 0.8, u.z)),
               lambda u: L.mix(C("1a3a1a"), C("4a8a2a"), L.smooth(-0.5, 0.8, u.z)))
    p, n = M.front_hit(surf, 0.0, 2.2)
    grim = [(x / 10.0 * 0.26, -0.07 * (x / 10.0) ** 2 + 0.02) for x in range(-10, 11)]
    parts.stroke(p, n, grim, 0.045, C("050805"), lift=0.012, taper=False)
    with parts.use("glow"):
        q, qn = M.front_hit(surf, 0.2, 2.13)
        parts.ellipsoid(q + qn * 0.02, (0.03, 0.03, 0.055), color=neon, weights={"Head": 1.0}, seg=8, rings=6)
        # Neon venom stripes: down the spine sides and along each flank, eye to thigh.
        for sx in (-1.0, 1.0):
            for (y0, sweep) in ((0.6, 0.55), (0.0, 1.0)):
                path = []
                for k in range(9):
                    t = k / 8.0
                    p, n = M.dir_hit(surf, V((0, 0.15, 2.35 - 1.5 * t)), V((sx * sweep, y0 + 0.4, 0.15 - 0.2 * t)))
                    if p is not None:
                        path.append((p, n))
                for (p0, n0), (p1, n1) in zip(path, path[1:]):
                    d = p1 - p0
                    side = n0.cross(d).normalized() * 0.04
                    mid = (p0 + p1) * 0.5
                    parts.decal(mid, n0, [(-0.04, -d.length * 0.55), (0.04, -d.length * 0.55),
                                          (0.04, d.length * 0.55), (-0.04, d.length * 0.55)], neon, rings=1,
                                up=d.normalized(), lift=0.014)
        # Glowing venom glands.
        rng = random.Random(11)
        placed = []
        for d in M.fibonacci(80):
            if d.y < 0.1 or len(placed) >= 9:
                continue
            p, n = M.dir_hit(surf, V((0, 0.1, 1.5)), d)
            if p is None or p.z < 0.7 or any((p - q).length < 0.32 for q in placed):
                continue
            placed.append(p)
            s = rng.uniform(0.05, 0.08)
            parts.ellipsoid(p + n * 0.005, (s, s, s * 0.55), M.basis(n), color=None, weights=p, seg=8, rings=5,
                            color_fn=lambda u: L.mix(neon, neon_hi, L.smooth(-0.2, 1.0, u.z)))
        for sx in (-1.0, 1.0):
            for k in range(3):
                p, n = M.dir_hit(surf, V((0.35 * sx, 0.2, 1.0 - 0.25 * k)), V((0.9 * sx, -0.3, 0.1)))
                if p is not None:
                    parts.decal(p, n, M.ellipse(0.05, 0.04, 10), neon, rings=1)
            # Bands across the arms (seen from the front and the game camera above).
            for k in range(4):
                x = 0.55 + 0.32 * k
                p, n = M.dir_hit(surf, V((x * sx, 0.17, 1.82)), V((0, -0.3, 1.0)))
                if p is not None:
                    parts.decal(p, n, M.ellipse(0.06, 0.05, 12), neon, rings=1, lift=0.014)
            # Flank spots seen from the front.
            for k, (x, z) in enumerate(((0.5, 1.75), (0.55, 1.35), (0.45, 0.95), (0.62, 2.05))):
                p, n = M.front_hit(surf, x * sx, z)
                if p is not None:
                    parts.decal(p, n, M.ellipse(0.045, 0.04, 10), neon, rings=1)
    finish(body, parts)


def toad_king(arm, body):
    """Royal toad boss (toad_king only): stout warty royal-purple body with a golden belly,
    an ermine collar, a jewelled gold crown, heavy-lidded haughty eyes, a stern wide mouth."""
    _frog_base(body)
    L.decimate_to(body, 4200)
    purple, dusk, wart, gold, ink = C("8a4fc8"), C("40206e"), C("b48ae8"), C("ffd36a"), C("2a1240")

    def paint(name, co, n, info):
        if name == "Frog_Secondary":
            return L.mix(C("e8a83a"), gold, L.smooth(0.8, 1.9, co.z)) if _frog_is_belly(co) else ink
        c = L.mix(dusk, purple, L.smooth(0.3, 2.4, co.z) * 0.6 + max(0.0, -n.y) * 0.4)
        c = L.mix(c, C("2e1650"), max(0.0, n.y) * 0.4)
        return L.mix(c, C("c8a0e8"), max(0.0, -n.z) * 0.4)

    K.paint_body(body, paint, lambda *a: "keep")
    # Stouter (after painting, so the belly keeps its shape): belly and hips out, broader jowls.
    K.scale_region(body, lambda c: c.z < 2.0 and abs(c.x) < 0.75, V((0, 0.15, 1.3)), (1.22, 1.22, 1.0),
                   lambda c: L.smooth(0.3, 0.9, c.z) * L.smooth(2.05, 1.6, c.z))
    K.scale_region(body, lambda c: c.z >= 1.95 and abs(c.x) < 0.7, V((0, 0.0, 2.25)), (1.12, 1.06, 1.0),
                   lambda c: L.smooth(1.95, 2.15, c.z))
    body.data.update()
    surf, parts = start(body)
    parts.mode = "keep"
    eye_c = [V((0.33 * sx, -0.45, 2.46)) for sx in (-1.0, 1.0)]
    for sx, c in zip((-1.0, 1.0), eye_c):
        K.fierce_eye(parts, c, 0.205, V((0.3 * sx, -1.0, 0.05)).normalized(), C("fff0a0"),
                     C("e0901a"), {"Head": 1.0}, lid=C("7a46b8"), slant=0.12, side=sx, slit=True, pupil_w=0.5,
                     iris=0.72, sclera=C("fff6dc"), lid_drop=1.1)
    _frog_toes(parts, arm, body, lambda u: L.mix(C("c88a1a"), gold, L.smooth(-0.5, 0.8, u.z)),
               lambda u: L.mix(C("c88a1a"), gold, L.smooth(-0.5, 0.8, u.z)))
    p, n = M.front_hit(surf, 0.0, 2.2)
    stern = [(x / 10.0 * 0.32, -0.06 * (x / 10.0) ** 2 + 0.01) for x in range(-10, 11)]
    parts.stroke(p, n, stern, 0.05, C("1a0a28"), lift=0.012, taper=False)
    # Warts on the back and crown of the head.
    rng = random.Random(4)
    for d in M.fibonacci(30):
        if d.y < 0.0:
            continue
        p, n = M.dir_hit(surf, V((0, 0.1, 1.5)), d)
        if p is None or p.z < 0.7 or abs(p.x) > 0.8:
            continue
        s = rng.uniform(0.04, 0.075)
        parts.ellipsoid(p, (s, s, s * 0.6), M.basis(n), color=None, weights=p, seg=7, rings=4,
                        color_fn=lambda u: L.mix(C("6a3aa8"), C("d2b0f2"), L.smooth(-0.2, 1.0, u.z)))
    # Ermine collar around the neck.
    neck = V((0, 0.12, 1.98))
    for i in range(15):
        a = 2.0 * math.pi * i / 15
        d = V((math.cos(a), math.sin(a) * 0.9, -0.1))
        p, n = M.dir_hit(surf, neck, d)
        if p is None or (p - neck).length > 0.75:
            continue
        parts.ellipsoid(p + n * 0.05, (0.14, 0.14, 0.11), color=None, weights={"Torso": 0.5, "Neck": 0.5}, seg=7,
                        rings=5, color_fn=lambda u: L.mix(C("dcd6ea"), WHITE, L.smooth(-0.6, 0.7, u.z)))
        if i % 3 == 0:
            parts.ellipsoid(p + n * 0.18 + V((0, 0, -0.03)), (0.028, 0.028, 0.05), color=C("1a1420"),
                            weights={"Torso": 0.5, "Neck": 0.5}, seg=6, rings=4)
    # Jewelled gold crown.
    apex, _an = M.dir_hit(surf, V((0, 0.0, 2.3)), V((0, 0.2, 1)))
    gold_hi, gold_dk = C("fff0a0"), C("c8841a")
    base = apex - V((0, 0, 0.08))
    w = {"Head": 1.0}
    parts.frustum(base, V((0, 0, 1)), 0.36, 0.43, 0.24,
                  lambda t, side: L.mix(gold_dk, C("ffd84a"), 0.35 + 0.65 * t) if side else C("8a1030"), w, seg=24)
    for i in range(5):
        a = math.pi * 0.5 + 2.0 * math.pi * i / 5
        rim = base + V((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.2))
        dd = V((math.cos(a) * 0.2, math.sin(a) * 0.2, 1.0)).normalized()
        parts.blob(rim, (0.1, 0.06), dd, 0.26, None, weights=w, seg=8, rings=5, tip=0.2,
                   color_fn=lambda a_: L.mix(gold_dk, gold_hi, a_), up=V((math.cos(a), math.sin(a), 0)))
        parts.ellipsoid(rim + dd * 0.27, (0.05, 0.05, 0.05), color=None, weights=w, seg=8, rings=5,
                        color_fn=lambda u: L.mix(C("1a8a5a"), C("b0ffd8"), L.smooth(0.0, 1.0, u.z)))
    parts.ellipsoid(base + V((0, -0.42, 0.12)), (0.09, 0.045, 0.1), color=None, weights=w, seg=12, rings=8,
                    color_fn=lambda u: L.mix(C("c4103c"), C("ff8aa8"), L.smooth(-0.3, 1.0, u.z)))
    finish(body, parts)


# ================================================================ big/MushroomKing (pilot fix)

def mush_king(arm, body):
    """Mushroom monarch (mush_king, the summon treant): the lanky Quaternius body made
    sturdy - thick trunk-like legs, broad belly, strong arms, a grander cap - with a
    velvet cape, a white moustache, stern royal eyes and the jewelled crown."""
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    K.thicken(body, arm, {"UpperLeg.L", "UpperLeg.R", "LowerLeg.L", "LowerLeg.R"}, 1.55)
    K.thicken(body, arm, {"UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R"}, 1.4,
              along=lambda k: 1.0 + 0.1 * k)
    trunk = V((0, 0.22, 0))
    K.scale_region(body, lambda c: abs(c.x) < 0.9 and 0.45 < c.z < 2.15,
                   V((0, 0.22, 1.3)), (1.32, 1.3, 1.0), lambda c: L.smooth(0.45, 0.85, c.z) * L.smooth(2.15, 1.8, c.z))
    del trunk
    L.decimate_to(body, 3500)
    L.relax(body, 2, 0.35)
    cap_top, cap_rim, gill = C("8fdcff"), C("3a8fd8"), C("fff1d9")
    skin_top, skin_low = C("fff1de"), C("dcae7e")
    leaf_top, leaf_low = C("a6e35a"), C("4f9e3a")

    def paint(name, co, n, info):
        bone = info["bone"]
        held = bone.startswith(("Middle", "Index", "Pinky", "Thumb")) and co.x > 1.35
        if name == "Orc_Main":
            return L.mix(leaf_low, leaf_top, L.smooth(0.42, 0.86, co.z))
        if name == "MushroomKing_Secondary":
            if bone in ("Head", "Neck"):
                c = L.mix(cap_rim, cap_top, L.smooth(2.7, 3.5, co.z))
                return L.mix(c, gill, L.smooth(-0.1, -0.6, n.z))
            return L.mix(cap_rim, C("bfe9ff"), L.smooth(0.0, 0.08, info["bump"]))
        if held:
            return C("f8e3c4")
        c = L.mix(skin_low, skin_top, L.smooth(0.3, 2.4, co.z))
        return L.mix(c, C("fff8ee"), max(0.0, -n.y) * 0.25)

    K.paint_body(body, paint)
    # A grander cap (after painting: the cap keeps its colours).
    groups = L.dominant_groups(body)
    for v in body.data.vertices:
        if groups[v.index] in ("Head", "Neck") and v.co.z > 2.62:
            d = v.co - V((0, -0.12, 2.75))
            v.co = V((0, -0.12, 2.75)) + V((d.x * 1.2, d.y * 1.2, d.z * 1.12))
    body.data.update()
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        K.fierce_eye(parts, V((0.335 * sx, -0.36, 2.29)), 0.19, V((0.3 * sx, -1.0, -0.02)).normalized(),
                     C("ffcf5a"), C("c0501a"), {"Head": 1.0}, lid=C("f2d2aa"), slant=0.28, side=sx, slit=False,
                     iris=0.66, lid_drop=1.6)
        p, n = M.front_hit(surf, 0.33 * sx, 2.5)
        parts.stroke(p, n, [(0.2 * sx, 0.07), (0.05 * sx, 0.01), (-0.1 * sx, -0.05)], 0.09, C("5a3018"),
                     lift=0.02)
    # Royal white moustache, curling out.
    p, n = M.front_hit(surf, 0.0, 2.08)
    for sx in (-1.0, 1.0):
        parts.blob(p + n * 0.05 + V((0.02 * sx, 0, 0.02)), (0.13, 0.085), V((sx, -0.3, -0.25)), 0.42, None,
                   weights={"Head": 1.0}, seg=10, rings=7, tip=0.4, bend=V((0.03 * sx, -0.02, 0.16)),
                   color_fn=lambda a: L.mix(C("eee6da"), WHITE, a))
    M.cap_spots(parts, surf, V((0, -0.15, 2.95)), 10, 0.17, C("ffffff"), min_z=0.0)
    # Velvet cape with an ermine hem, hanging from the shoulders.
    red, red_dk, ermine = C("d23a4a"), C("7a1430"), C("fbf6ee")

    def cape_col(u, v, outside):
        if v > 0.85:
            return L.mix(ermine, C("e6e0f0"), 0.3 if outside else 0.6)
        if not outside:
            return L.mix(red_dk, C("4a0a1e"), 0.5)
        return L.mix(red, red_dk, L.smooth(0.0, 1.0, v) * 0.5 + abs(u) * 0.4)

    K.cape(parts, V((0, 0.2, 0)), 1.95, 0.38, 0.62, 0.95, math.radians(200), cape_col,
           {"Torso": 0.75, "Abdomen": 0.25}, flare=0.15)
    # Ermine mantle over the shoulders (covers where the cape hangs from).
    neck = V((0, 0.2, 1.95))
    for i in range(16):
        a = 2.0 * math.pi * i / 16
        p, n = M.dir_hit(surf, neck, V((math.cos(a), math.sin(a) * 0.9, -0.25)))
        if p is None or (p - neck).length > 0.95:
            continue
        parts.ellipsoid(p + n * 0.06, (0.17, 0.17, 0.12), color=None, weights={"Torso": 0.6, "Neck": 0.4}, seg=7,
                        rings=5, color_fn=lambda u: L.mix(C("dcd6ea"), WHITE, L.smooth(-0.6, 0.7, u.z)))
        if i % 2 == 0:
            parts.ellipsoid(p + n * 0.22 + V((0, 0, -0.03)), (0.03, 0.03, 0.055), color=C("1a1420"),
                            weights={"Torso": 1.0}, seg=6, rings=4)
    # The crown.
    apex, _an = M.dir_hit(surf, V((0, -0.15, 3.0)), V((0, 0, 1)))
    gold, gold_dark = C("ffd84a"), C("e39a1c")
    base = apex - V((0, 0, 0.12))
    w = {"Head": 1.0}
    with parts.use("keep"):
        parts.frustum(base, V((0, 0, 1)), 0.45, 0.54, 0.34,
                      lambda t, side: L.mix(gold_dark, gold, 0.35 + 0.65 * t) if side else C("8a1030"), w, seg=28)
        for i in range(5):
            a = math.pi * 0.5 + 2.0 * math.pi * i / 5
            rim = base + V((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.29))
            d = V((math.cos(a) * 0.25, math.sin(a) * 0.25, 1.0)).normalized()
            parts.blob(rim, (0.11, 0.065), d, 0.32, None, weights=w, seg=8, rings=5, tip=0.25,
                       color_fn=lambda along: L.mix(gold_dark, C("fff2a0"), along),
                       up=V((math.cos(a), math.sin(a), 0)))
            parts.ellipsoid(rim + d * 0.32, (0.065, 0.065, 0.065), color=None, weights=w, seg=8, rings=5,
                            color_fn=lambda u: L.mix(C("ff3b6b"), C("ffc2d4"), L.smooth(0.0, 1.0, u.z)))
        parts.ellipsoid(base + V((0, -0.51, 0.17)), (0.11, 0.05, 0.12), color=None, weights=w, seg=12, rings=8,
                        color_fn=lambda u: L.mix(C("c4103c"), C("ff8aa8"), L.smooth(-0.3, 1.0, u.z)))
    finish(body, parts)


# ================================================================ meadow pilot fixes

def green_slime(arm, body):
    """The pilot's green slime with a relaxed wide grin (it read as shocked) and the AO
    baked on the jelly alone, so no dark crease rings the big eye."""
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4200)
    L.inflate(body, 0.02)
    lo, hi = L.bounds(body)
    height = hi.z - lo.z
    L.paint_body(body, M.jelly_paint(C("d2f78a"), C("86dc5c"), C("4dab4f"), C("b9f58a"), height, tip=C("f4ffb0")))
    L.bake_ao(body)  # the jelly only: the eye and decals added below don't occlude it
    surf, parts = start(body, L.Parts)
    M.sparkly_eye(parts, V((0.015, -0.74, 0.86)), 0.4, V((0.0, -1.0, -0.02)).normalized(), C("5a2a0a"),
                  C("f6b032"), {"Head": 1.0}, iris=0.6, pupil=0.32)
    for sx in (-1.0, 1.0):
        p, n = M.front_hit(surf, 0.58 * sx, 0.52)
        M.cheek(parts, p, n, 0.14, 0.085, C("ff7a8a"))
    p, n = M.front_hit(surf, 0.0, 0.36)
    # Wide, shallow grin: a gentle open crescent, flat on top.
    pts = [(math.cos(a) * 0.23, math.sin(a) * 0.075) for a in [math.pi + math.pi * i / 16 for i in range(17)]]
    pts += [(0.23 * (1.0 - 2.0 * i / 6.0), 0.012) for i in range(1, 6)]
    parts.decal(p, n, pts, C("2f4a1a"), rings=3)
    parts.decal(p + V((0, 0, -0.035)), n, M.ellipse(0.1, 0.03, 12), C("ff8a8a"), lift=0.02, rings=1)
    parts.decal(p + V((0.08, 0, 0.0)), n, [(-0.028, 0.012), (0.0, -0.045), (0.028, 0.012)], WHITE, lift=0.022,
                rings=1)
    p, n = M.front_hit(surf, -0.62, 1.0)
    M.gloss(parts, p, n, 0.22, C("f6ffe0"))
    M.bubbles(parts, surf, [(V((0.85, -0.5, -0.4)), 1.0), (V((-0.85, -0.45, -0.5)), 0.7),
                            (V((0.6, 0.8, -0.3)), 0.8), (V((-0.5, 0.85, -0.45)), 0.6)], C("86dc5c"), 0.07)
    L.join_parts(body, parts.to_object())


def wild_chicken(arm, body):
    """The pilot's furious chicken with a real fanned tail: arching glossy dark sickle
    feathers over a fan of golden ones (a jungle fowl's tail), instead of a stubby wedge."""
    L.delete_faces(body, ("Eye_White",), where=lambda c, n, g: n == "Eye_Black" and abs(c.x) > 0.36)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4600)
    L.relax(body, 4, 0.5, ("Chicken_Main",))
    lo, hi = L.bounds(body)
    height = hi.z - lo.z
    cream_top, cream_low, shade = C("fffdf7"), C("f4e7d4"), C("e6d5c4")
    comb_top, comb_low = C("ff6a52"), C("d92a34")
    beak_top, beak_low = C("ffcb52"), C("f28a1e")

    def paint(name, co, n, info):
        if name == "Chicken_Main":
            if abs(co.x) > 0.66:
                return L.mix(shade, C("ffffff"), L.smooth(0.72, 1.1, abs(co.x)))
            c = L.mix(cream_low, cream_top, L.smooth(0.15, 0.95, co.z / height))
            return L.mix(c, C("ffffff"), max(0.0, -n.y) * 0.35)
        if name == "Chicken_Red":
            return L.mix(comb_low, comb_top, L.smooth(-0.02, 0.1, info["bump"]))
        if name == "Beak":
            return L.mix(beak_low, beak_top, L.smooth(0.3, 0.8, co.z))
        return C("5a2414")

    K.paint_body(body, paint)
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        cute_eye(parts, V((0.5 * sx, -0.38, 0.77)), 0.34, V((0.5 * sx, -1.0, 0.06)).normalized(),
                 C("2e170c"), C("c46a1c"), {"Head": 1.0}, iris=0.58, pupil=0.32)
        p, n = M.front_hit(surf, 0.44 * sx, 1.17)
        parts.stroke(p, n, [(0.2 * sx, 0.07), (0.05 * sx, 0.02), (-0.1 * sx, -0.06)], 0.085, C("7a2c1c"),
                     lift=0.02)
        p, n = M.front_hit(surf, 0.6 * sx, 0.36)
        M.cheek(parts, p, n, 0.12, 0.075, C("ff8f8a"))
        foot = V((0.32 * sx, -0.42, 0.05))
        for k in (-1, 0, 1):
            d = V((0.35 * k + 0.12 * sx, -1.0, -0.05)).normalized()
            parts.blob(foot, (0.08, 0.06), d, 0.3, None, weights={"Body": 1.0}, seg=8, rings=5, tip=0.8,
                       color_fn=lambda along: L.mix(C("ff9a2a"), C("ffc35a"), along))
    # Tail: a fan of seven golden feathers darkening to the tips, then three long arching
    # sickle feathers over it, glossy green-black with a teal sheen (a jungle fowl's tail).
    root, rn = M.dir_hit(surf, V((0, 0, 0.95)), V((0, 1.0, 0.25)))
    root = root - rn * 0.08
    u = V((0, 0.25, 0.97)).normalized()
    for k in range(-3, 4):
        a = k * 0.3
        d = (V((1, 0, 0)) * math.sin(a) + u * math.cos(a)).normalized()
        parts.blob(root + V((0.04 * k, 0.0, 0.0)), (0.2, 0.05), d, 1.25 - 0.1 * abs(k), None,
                   weights={"Body": 1.0}, seg=10, rings=7, tip=0.6, up=V((0, 1, 0)), bend=V((0.0, 0.12, -0.03)),
                   color_fn=lambda t: L.mix(C("e88a2a"), C("2a3a3a"), L.smooth(0.4, 0.95, t)))
    for k in (-1, 0, 1):
        d = (V((1, 0, 0)) * math.sin(k * 0.3) + V((0, 0.3, 0.95))).normalized()
        parts.blob(root + V((0.06 * k, 0.1, 0.08)), (0.17, 0.05), d, 1.45 - 0.12 * abs(k), None,
                   weights={"Body": 1.0}, seg=10, rings=9, tip=0.3, up=V((0, 1, 0)), bend=V((0.15 * k, 0.45, -0.3)),
                   color_fn=lambda t: L.mix(C("1d2a2a"), C("2f8a7a"), L.smooth(0.2, 0.95, t) * 0.7))
    finish(body, parts, strength=0.38, shade=V((0.86, 0.66, 0.58)))


def spine_clusters(parts, surf, center, count, keep_clear, seed=5, length=0.24, radius=0.045, z_range=(0.15, 1.9),
                   spine=C("fff6d8"), spine_root=C("d8c690"), areole=C("f4f0e2")):
    """Cactus areoles: a fuzzy pale dot with three stiff spines, big enough to read at game
    distance (outlined like the body)."""
    rng = random.Random(seed)
    placed = []
    for d in M.fibonacci(count * 3):
        if d.z < -0.3 or len(placed) >= count:
            continue
        p, n = M.dir_hit(surf, center, d)
        if p is None or not (z_range[0] < p.z < z_range[1]) or keep_clear(p):
            continue
        if any((p - q).length < length * 1.3 for q in placed):
            continue
        placed.append(p)
        parts.decal(p, n, M.ellipse(radius * 1.2, radius * 1.2, 8), areole, rings=1)
        for k in range(3):
            a = 2.0 * math.pi * k / 3 + rng.uniform(0, 1)
            t_, b_, _n = L.frame(n)
            dd = (n * 1.0 + (t_ * math.cos(a) + b_ * math.sin(a)) * 0.75).normalized()
            parts.blob(p - n * 0.01, radius * 0.6, dd, length * rng.uniform(0.85, 1.1), None, weights=p, seg=4,
                       rings=2, tip=0.05, color_fn=lambda t: L.mix(spine_root, spine, t))


def cactus_hat(arm, body):
    """The pilot's sombrero cactus with spine clusters that read at game distance."""
    L.delete_small_islands(body, 3, ("Cactoro_Secondary",))
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    hat = L.split_off(body, ("Head3",))
    L.clean(body, fill_holes=8)
    L.subdivide(body, 1)
    L.decimate_to(body, 3000)
    L.clean(hat, quads=False)
    L.join(body, hat)
    green_top, green_low, rib = C("b4e870"), C("4fae4a"), C("d8f59a")
    straw_top, straw_low = C("ffd27a"), C("d98b38")

    def paint(name, co, n, info):
        if info["bone"] == "Head3":
            if name == "Cactoro_Red":
                return C("ef4b4b")
            if name == "Cactoro_Main":
                return C("42c46a")
            return L.mix(straw_low, straw_top, max(0.0, n.z) * 0.8 + 0.2)
        c = L.mix(green_low, green_top, L.smooth(0.0, 1.9, co.z))
        if abs(co.x) < 0.95:
            a = math.atan2(co.y, co.x)
            c = L.mix(c, rib, L.smooth(0.82, 0.98, math.cos(a * 7.0)) * 0.75)
        return c

    K.paint_body(body, paint)
    surf, parts = start(body)
    groups = L.dominant_groups(body)
    cute_eye(parts, V((0.01, -0.72, 1.12)), 0.39, V((0.0, -1.0, -0.05)).normalized(), C("10204a"),
             C("3d9be8"), {"Head": 1.0}, iris=0.6, pupil=0.32)
    p, n = M.front_hit(surf, 0.0, 0.55)
    M.smile_mouth(parts, p, n, 0.16, 0.12, C("3a2a12"), C("ff7f86"))
    for sx in (-1.0, 1.0):
        p, n = M.front_hit(surf, 0.5 * sx, 0.68)
        M.cheek(parts, p, n, 0.12, 0.075, C("ff8a80"))
    spine_clusters(parts, surf, V((0, 0, 1.0)), 26,
                   lambda p: (p.y < -0.2 and abs(p.x) < 0.66 and 0.3 < p.z < 1.62) or
                   surf.weights_at(p).get("Head3", 0.0) > 0.2, length=0.27, radius=0.05)
    for sx, petal, middle in ((-1.0, C("ff7ab6"), C("ffe066")), (1.0, C("ffd84a"), C("ff9a3a"))):
        side = [v.co for v in body.data.vertices if v.co.x * sx > 0.5 and groups[v.index] != "Head3"]
        tip = max(side, key=lambda v: v.z + abs(v.x) * 0.6)
        p, n = M.dir_hit(surf, tip - V((0.25 * sx, 0, 0.25)), V((0.4 * sx, -0.3, 1.0)))
        if p is not None:
            M.flower(parts, p, (n + V((0, -0.4, 0.3))).normalized(), 0.2, petal, middle, weights=p)
    hat = [v.co for v in body.data.vertices if groups[v.index] == "Head3"]
    hat_center = sum(hat, V()) / len(hat)
    pose = L.pose_matrix(arm, "Head3")
    want = pose.inverted() @ (pose @ hat_center + V((-0.45, -0.8, 0.55)))
    p, n = surf.toward(want + (want - hat_center).normalized() * 2.0, hat_center)
    if p is not None:
        M.flower(parts, p, n, 0.3, C("ff5fa2"), C("ffe066"), weights={"Head3": 1.0}, turn=0.3)
    finish(body, parts)


# ================================================================ shared bits

def drop_islands(body, pred):
    """Removes loose pieces where pred(centre, size, material) (Quaternius eyes, floppy ears)."""
    import bmesh
    kill = set()
    for vs, mat in L.islands(body):
        lo, hi = L.bounds(body, vs)
        if pred((lo + hi) * 0.5, hi - lo, mat):
            kill |= vs
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in kill], context="VERTS")
    bm.to_mesh(body.data)
    bm.free()


def fur_tufts(parts, surf, center, dirs, size, c0, c1, weights=None, seg=6, count=3, spread=0.5, seed=1, up=None):
    """Clumps of pointed fur sticking out of the body (cheek ruffs, manes, chest fluff)."""
    rng = random.Random(seed)
    for d in dirs:
        p, n = M.dir_hit(surf, center, d)
        if p is None:
            continue
        t_, b_, _n = L.frame(n)
        for k in range(count):
            a = (k - (count - 1) * 0.5) * spread
            dd = (n + t_ * math.sin(a) * 0.8 + b_ * (-0.35 + rng.uniform(-0.15, 0.15))).normalized()
            parts.blob(p - n * 0.04, (size * 0.45, size * 0.3), dd, size * rng.uniform(0.9, 1.15), None,
                       weights=weights or p, seg=seg, rings=4, tip=0.05, up=up or n,
                       color_fn=lambda t: L.mix(c0, c1, t))


def scallops(parts, surf, center, dirs, size, color, up=V((0, 0, 1))):
    """Little feather scallops: painted arcs over a bird's breast / back."""
    for d in dirs:
        p, n = M.dir_hit(surf, center, d)
        if p is None:
            continue
        arc = [(math.cos(a) * size, math.sin(a) * size * 0.7 - size * 0.2) for a in
               [math.pi + math.pi * i / 6 for i in range(7)]]
        parts.stroke(p, n, arc, size * 0.28, color, up=up, lift=0.012)


# ================================================================ big/Bunny  snow_bunny

def snow_bunny(arm, body):
    """Snow bunny: plump snow-white fur with cool lilac shading, cream belly, pink ears and
    nose, buck teeth, ice-blue sparkly eyes, cheek and chest fluff, a pom tail, its carrot."""
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    K.thicken(body, arm, {"UpperLeg.L", "UpperLeg.R", "LowerLeg.L", "LowerLeg.R"}, 1.25)
    K.thicken(body, arm, {"UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R"}, 1.15)
    K.scale_region(body, lambda c: abs(c.x) < 0.8 and 0.5 < c.z < 1.95, V((0, 0.2, 1.3)), (1.12, 1.12, 1.0),
                   lambda c: L.smooth(0.5, 0.9, c.z) * L.smooth(1.95, 1.65, c.z))
    L.decimate_to(body, 5200)
    L.relax(body, 2, 0.3, ("Bunny_Main",))
    fur, fur_shade, belly, pink = C("fffcf8"), C("dcd6ea"), C("fff6ea"), C("ffb3c6")

    def paint(name, co, n, info):
        if name == "Material.024":
            return L.mix(C("e8641a"), C("ffa040"), max(0.0, n.z) * 0.6 + 0.3)
        if name == "Material.011":
            return L.mix(C("3f9a2a"), C("8ad84a"), 0.5 + 0.5 * n.z)
        if name == "Bunny_Secondary":
            if co.z > 2.45:
                return L.mix(pink, C("ffd6e0"), L.smooth(2.5, 3.2, co.z))  # inner ears
            if co.z > 2.04 and co.y < -0.5:
                return C("ff8fa8")  # nose
            if co.z > 1.8 and co.y < -0.45:
                return C("fffdf6")  # buck teeth
            return L.mix(belly, WHITE, L.smooth(1.0, 1.8, co.z))
        c = L.mix(fur_shade, fur, L.smooth(0.2, 1.8, co.z) * 0.7 + max(0.0, n.z) * 0.3)
        return L.mix(c, C("c8c2dc"), max(0.0, n.y) * 0.25)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name in ("Material.024", "Material.011") or
                 (name == "Bunny_Secondary" and 1.8 < c.z < 2.04 and c.y < -0.45) else "skin")
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        cute_eye(parts, V((0.33 * sx, -0.36, 2.29)), 0.19, V((0.3 * sx, -1.0, 0.05)).normalized(),
                 C("1a2a5a"), C("7ac8ff"), {"Head": 1.0}, iris=0.64, pupil=0.34)
        p, n = M.front_hit(surf, 0.42 * sx, 2.06)
        M.cheek(parts, p, n, 0.09, 0.055, C("ff9ab0"))
    fur_tufts(parts, surf, V((0, -0.1, 2.1)), [V((sx, -0.5, -0.25)) for sx in (-1.0, 1.0)], 0.2, fur_shade, fur,
              weights={"Head": 1.0}, seed=2)
    fur_tufts(parts, surf, V((0, 0.1, 1.7)), [V((x, -1.0, 0.1)) for x in (-0.45, 0.0, 0.45)], 0.22, fur_shade,
              WHITE, weights={"Torso": 1.0}, seed=3, count=2)
    p, n = M.dir_hit(surf, V((0, 0.2, 0.95)), V((0, 1, 0.1)))
    if p is not None:
        parts.ellipsoid(p + n * 0.12, (0.24, 0.22, 0.22), color=None, weights={"Hips": 1.0}, seg=12, rings=8,
                        color_fn=lambda u: L.mix(fur_shade, WHITE, L.smooth(-0.8, 0.6, u.z)))
        fur_tufts(parts, surf, p + n * 0.1, [n], 0.18, fur_shade, WHITE, weights={"Hips": 1.0}, count=3, seed=4)
    finish(body, parts)


# ================================================================ blob/Dog  sand_wolf (+ summon wolf)

def sand_wolf(arm, body):
    """Wolf (sand_wolf; the summon's blue wolf): upright pointed ears instead of floppy dog
    ears, a darker saddle over light fur, cream muzzle, narrow amber eyes, fangs, cheek ruffs
    and a bushy tail. Painted near-neutral so the sand / ice tints both land."""
    drop_islands(body, lambda c, size, mat: mat == "Dog_Main" and c.z > 1.0 and abs(c.x) > 0.6)  # floppy ears
    drop_islands(body, lambda c, size, mat: mat == "Eye_White" or (mat == "Eye_Black" and abs(c.x) > 0.4))
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 3200)
    saddle, side, cream = C("aaa298"), C("d8d2c6"), C("f8f2e8")

    def paint(name, co, n, info):
        if name == "Eye_Black":
            return C("1a1416")
        if name == "Dog_Secondary":
            return L.mix(cream, WHITE, L.smooth(0.3, 0.9, co.z) * 0.5)
        c = L.mix(side, saddle, L.smooth(0.0, 0.8, n.z * 0.6 + n.y * 0.6))
        return L.mix(c, cream, max(0.0, -n.z) * 0.5)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name == "Eye_Black" else "skin")
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        K.fierce_eye(parts, V((0.52 * sx, -0.72, 0.78)), 0.19, V((0.4 * sx, -1.0, 0.05)).normalized(),
                     C("ffe066"), C("f0a020"), {"Head": 1.0}, lid=C("b8b0a4"), slant=0.4, side=sx, slit=False,
                     iris=0.72, lid_drop=1.35)
        p, n = M.front_hit(surf, 0.5 * sx, 1.05)
        parts.stroke(p, n, [(0.22 * sx, 0.08), (0.06 * sx, 0.0), (-0.1 * sx, -0.07)], 0.08, C("4a403a"), lift=0.02)
        # Upright pointed ears with dark tips and a pale inner ear.
        p, n = M.dir_hit(surf, V((0, 0, 0.9)), V((0.52 * sx, -0.2, 0.6)))
        parts.blob(p - n * 0.08, (0.24, 0.1), V((0.45 * sx, -0.15, 1.0)).normalized(), 0.62, None,
                   weights={"Head": 1.0}, seg=10, rings=7, tip=0.08, up=V((0, -1, 0)),
                   color_fn=lambda t: L.mix(saddle, C("3a3430"), L.smooth(0.55, 0.95, t)))
        with parts.use("keep"):
            parts.blob(p - n * 0.02 + V((0, -0.06, 0.02)), (0.13, 0.05), V((0.45 * sx, -0.3, 1.0)).normalized(),
                       0.42, None, weights={"Head": 1.0}, seg=8, rings=5, tip=0.1, up=V((0, -1, 0)),
                       color_fn=lambda t: L.mix(C("b8948a"), C("e0bcb0"), t))
        fur_tufts(parts, surf, V((0, -0.2, 0.6)), [V((sx, -0.35, -0.3)), V((sx, 0.1, -0.1))], 0.3, side, cream,
                  weights={"Head": 1.0}, seed=5 + int(sx))
        p, n = M.front_hit(surf, 0.12 * sx, 0.3)
        if p is not None:
            K.fang(parts, p - n * 0.02, V((0, -0.25, -1)), 0.14, 0.04, {"Head": 1.0})
    p, n = M.front_hit(surf, 0.0, 0.33)
    parts.stroke(p, n, [(x / 8.0 * 0.22, -0.04 * (1 - (x / 8.0) ** 2)) for x in range(-8, 9)], 0.035, C("2a1a1a"),
                 lift=0.016)
    p, n = M.dir_hit(surf, V((0, 0, 0.5)), V((0, 1, 0.2)))
    if p is not None:
        parts.blob(p - n * 0.1, (0.24, 0.22), V((0, 0.8, 0.6)).normalized(), 0.85, None, weights={"Body": 1.0},
                   seg=10, rings=8, tip=0.35, bend=V((0, 0.1, 0.25)),
                   color_fn=lambda t: L.mix(saddle, cream, L.smooth(0.6, 1.0, t)))
    finish(body, parts)


# ================================================================ blob/Birb  gold_birb, sand_birb

def peck_birb(arm, body):
    """Fierce pecking bird (gold_birb / sand_birb tints): pale scalloped plumage, darker
    tipped crest and wing spikes, a hooked horn beak, red glaring eyes under heavy brows."""
    drop_islands(body, lambda c, size, mat: mat in ("Eye_White", "Eye_Black"))
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4200)
    back, breast, spike_dk = C("cbbfae"), C("fff8ec"), C("6a5a4a")

    def paint(name, co, n, info):
        if name == "Birb_Beak":
            return L.mix(C("c86418"), C("ffc04a"), L.smooth(-0.2, 0.8, n.z) * 0.7 + L.smooth(0.0, 0.6, co.z) * 0.3)
        if name == "Birb_Secondary":
            return L.mix(spike_dk, C("efe6d8"), L.smooth(0.08, -0.02, info["bump"]))
        c = L.mix(breast, back, L.smooth(-0.6, 0.6, n.y * 0.8 + n.z * 0.4))
        return L.mix(c, C("a89880"), L.smooth(0.05, 0.15, info["bump"]) * 0.6)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name == "Birb_Beak" else "skin")
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        K.fierce_eye(parts, V((0.55 * sx, -0.95, 1.0)), 0.25, V((0.5 * sx, -1.0, 0.0)).normalized(), C("fff060"),
                     C("ff7a1a"), {"Head": 1.0}, lid=C("e4dacb"), slant=0.45, side=sx, slit=False, iris=0.66,
                     lid_drop=1.65)
        p, n = M.front_hit(surf, 0.55 * sx, 1.36)
        parts.stroke(p, n, [(0.3 * sx, 0.12), (0.08 * sx, 0.02), (-0.16 * sx, -0.1)], 0.11, C("3a2a20"), lift=0.02)
    scallops(parts, surf, V((0, -0.4, 1.0)), [V((x, -0.6, z)) for x in (-0.6, -0.2, 0.2, 0.6) for z in (-0.6, -0.3)],
             0.12, C("bfae96"))
    scallops(parts, surf, V((0, -0.4, 1.0)), [V((x, 1.0, z)) for x in (-0.5, 0.0, 0.5) for z in (-0.2, 0.3, 0.8)],
             0.14, C("9a8a74"))
    finish(body, parts)


# ================================================================ flying/Pigeon  snow_pigeon (+ falcon)

def snow_pigeon(arm, body):
    """Snow pigeon: soft white plumage with silver wing bars and grey flight-feather tips,
    a pearly underwing, a warm beak, round orange pigeon eyes."""
    drop_islands(body, lambda c, size, mat: (mat == "Eye_White" and 0.3 < abs(c.x) < 0.5) or
                 (mat == "Eye_Black" and abs(c.x) > 0.3))
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5200)
    top, under, bar, tip = C("eef1f6"), C("ffffff"), C("b8c0cc"), C("8a94a4")

    def paint(name, co, n, info):
        if name == "Pigeon_Secondary":
            return L.mix(C("d88a4a"), C("ffc890"), L.smooth(2.0, 2.3, co.z))
        if name == "Eye_Black":
            return C("6a3a2a")
        if name == "Eye_White":
            return C("f6f7fb") if abs(co.x) > 0.5 else C("dfe4ec")
        if abs(co.x) > 0.62:  # wings
            r = abs(co.x)
            c = L.mix(top, bar, L.smooth(1.1, 1.2, r) * L.smooth(1.45, 1.35, r))
            return L.mix(c, tip, L.smooth(1.75, 2.0, r))
        return L.mix(under, top, L.smooth(-0.3, 0.5, n.y * 0.6 + n.z * 0.6))

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name in ("Pigeon_Secondary", "Eye_Black") else
                 "skin")
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        cute_eye(parts, V((0.39 * sx, -0.27, 2.21)), 0.25, V((0.45 * sx, -1.0, 0.05)).normalized(),
                 C("6a1e08"), C("ff9a2a"), {"Head": 1.0}, iris=0.6, pupil=0.3)
        p, n = M.front_hit(surf, 0.5 * sx, 1.98)
        if p is not None:
            M.cheek(parts, p, n, 0.08, 0.05, C("ffb0b8"))
    fur_tufts(parts, surf, V((0, 0, 2.1)), [V((0, -1, -0.8))], 0.2, C("e6eaf0"), WHITE, count=3, seed=9)
    finish(body, parts)


# ================================================================ registry / runner

RECIPES = {
    "big/Frog": yellow_frog,
    "big/FrogToxic": toxic_frog,
    "big/FrogKing": toad_king,
    "big/MushroomKing": mush_king,
    "blob/GreenBlob": green_slime,
    "blob/Chicken": wild_chicken,
    "blob/Cactoro": cactus_hat,
    "big/Bunny": snow_bunny,
    "blob/Dog": sand_wolf,
    "blob/Birb": peck_birb,
    "flying/Pigeon": snow_pigeon,
}
SOURCE = {"big/FrogToxic": "big/Frog", "big/FrogKing": "big/Frog"}


def build(name):
    import bpy
    L.reset()
    arm, body = L.load(os.path.join(M.SRC, SOURCE.get(name, name) + ".gltf"))
    clips = sorted(a.name for a in bpy.data.actions)
    before = L.tri_count(body)
    RECIPES[name](arm, body)
    out = os.path.join(M.OUT, name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    K.export(arm, body, out, clips)
    print("REMASTER %s tris %d -> %d, %d bytes, clips %s" % (name, before, L.tri_count(body), os.path.getsize(out),
                                                          ",".join(clips)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
