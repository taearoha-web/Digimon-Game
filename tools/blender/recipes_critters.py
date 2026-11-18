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


def D(hex_or_tuple, gamma=0.55):
    """A colour as it should SHOW in game. The game's vertex-colour path darkens and
    saturates mid-tones (a linear value reads roughly as if it were sRGB), so plain
    C() suits the bright pastel critters but crushes muted ones (rot, mud, stone) to near
    black: D() lifts the linear value part of the way back."""
    c = L.srgb(hex_or_tuple)
    return V((c.x ** gamma, c.y ** gamma, c.z ** gamma))
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
    hide, hide_hi, under = D("173a26"), D("3f8a4a"), D("a8d84a")
    neon, neon_hi = D("8cff2a"), D("eaff8a")

    def paint(name, co, n, info):
        if name == "Frog_Secondary" and _frog_is_belly(co):
            return L.mix(D("6a9a2a"), under, L.smooth(1.0, 1.9, co.z))
        c = L.mix(hide, hide_hi, L.smooth(0.3, 2.4, co.z) * 0.5 + max(0.0, -n.y) * 0.35)
        return L.mix(c, D("4a7a3a"), max(0.0, -n.z) * 0.4)

    K.paint_body(body, paint, lambda *a: "keep")
    surf, parts = start(body)
    parts.mode = "keep"
    for sx in (-1.0, 1.0):
        K.fierce_eye(parts, V((0.31 * sx, -0.43, 2.46)), 0.205, V((0.3 * sx, -1.0, 0.1)).normalized(), D("ffb02a"),
                     D("ff1a1a"), {"Head": 1.0}, lid=D("1f4a2a"), slant=0.4, side=sx, slit=True, pupil_w=0.5,
                     iris=0.8, sclera=D("ffd23a"), glow=True, lid_drop=1.7)
    _frog_toes(parts, arm, body, lambda u: L.mix(D("1a3a1a"), D("4a8a2a"), L.smooth(-0.5, 0.8, u.z)),
               lambda u: L.mix(D("1a3a1a"), D("4a8a2a"), L.smooth(-0.5, 0.8, u.z)))
    p, n = M.front_hit(surf, 0.0, 2.2)
    grim = [(x / 10.0 * 0.26, -0.07 * (x / 10.0) ** 2 + 0.02) for x in range(-10, 11)]
    parts.stroke(p, n, grim, 0.045, D("050805"), lift=0.012, taper=False)
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
    saddle, side, cream = D("847c72"), D("cec6b8"), D("f8f2e8")

    def paint(name, co, n, info):
        if name == "Eye_Black":
            return D("1a1416")
        if name == "Dog_Secondary":
            return L.mix(cream, WHITE, L.smooth(0.3, 0.9, co.z) * 0.5)
        c = L.mix(side, saddle, L.smooth(0.0, 0.8, n.z * 0.6 + n.y * 0.6))
        return L.mix(c, cream, max(0.0, -n.z) * 0.5)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name == "Eye_Black" else "skin")
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        K.fierce_eye(parts, V((0.52 * sx, -0.72, 0.78)), 0.19, V((0.4 * sx, -1.0, 0.05)).normalized(),
                     D("ffe066"), D("f0a020"), {"Head": 1.0}, lid=D("b8b0a4"), slant=0.4, side=sx, slit=False,
                     iris=0.92, lid_drop=1.75)
        p, n = M.front_hit(surf, 0.5 * sx, 1.05)
        parts.stroke(p, n, [(0.22 * sx, 0.08), (0.06 * sx, 0.0), (-0.1 * sx, -0.07)], 0.08, D("4a403a"), lift=0.02)
        # Upright pointed ears with dark tips and a pale inner ear.
        p, n = M.dir_hit(surf, V((0, 0, 0.9)), V((0.52 * sx, -0.2, 0.6)))
        parts.blob(p - n * 0.08, (0.24, 0.1), V((0.45 * sx, -0.15, 1.0)).normalized(), 0.62, None,
                   weights={"Head": 1.0}, seg=10, rings=7, tip=0.08, up=V((0, -1, 0)),
                   color_fn=lambda t: L.mix(saddle, D("3a3430"), L.smooth(0.55, 0.95, t)))
        with parts.use("keep"):
            parts.blob(p - n * 0.02 + V((0, -0.06, 0.02)), (0.13, 0.05), V((0.45 * sx, -0.3, 1.0)).normalized(),
                       0.42, None, weights={"Head": 1.0}, seg=8, rings=5, tip=0.1, up=V((0, -1, 0)),
                       color_fn=lambda t: L.mix(D("b8948a"), D("e0bcb0"), t))
        fur_tufts(parts, surf, V((0, -0.2, 0.6)), [V((sx, -0.35, -0.3)), V((sx, 0.1, -0.1))], 0.3, side, cream,
                  weights={"Head": 1.0}, seed=5 + int(sx))
        p, n = M.front_hit(surf, 0.12 * sx, 0.3)
        if p is not None:
            K.fang(parts, p - n * 0.02, V((0, -0.25, -1)), 0.14, 0.04, {"Head": 1.0})
    p, n = M.front_hit(surf, 0.0, 0.33)
    parts.stroke(p, n, [(x / 8.0 * 0.22, -0.04 * (1 - (x / 8.0) ** 2)) for x in range(-8, 9)], 0.035, D("2a1a1a"),
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
    back, breast, spike_dk = D("cbbfae"), D("fff8ec"), D("6a5a4a")

    def paint(name, co, n, info):
        if name == "Birb_Beak":
            return L.mix(D("c86418"), D("ffc04a"), L.smooth(-0.2, 0.8, n.z) * 0.7 + L.smooth(0.0, 0.6, co.z) * 0.3)
        if name == "Birb_Secondary":
            return L.mix(spike_dk, D("efe6d8"), L.smooth(0.08, -0.02, info["bump"]))
        c = L.mix(breast, back, L.smooth(-0.6, 0.6, n.y * 0.8 + n.z * 0.4))
        return L.mix(c, D("a89880"), L.smooth(0.05, 0.15, info["bump"]) * 0.6)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name == "Birb_Beak" else "skin")
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        K.fierce_eye(parts, V((0.55 * sx, -0.95, 1.0)), 0.25, V((0.5 * sx, -1.0, 0.0)).normalized(), D("fff060"),
                     D("ff7a1a"), {"Head": 1.0}, lid=D("e4dacb"), slant=0.45, side=sx, slit=False, iris=0.92,
                     lid_drop=1.85)
        p, n = M.front_hit(surf, 0.55 * sx, 1.36)
        parts.stroke(p, n, [(0.3 * sx, 0.12), (0.08 * sx, 0.02), (-0.16 * sx, -0.1)], 0.11, D("3a2a20"), lift=0.02)
    scallops(parts, surf, V((0, -0.4, 1.0)), [V((x, -0.6, z)) for x in (-0.6, -0.2, 0.2, 0.6) for z in (-0.6, -0.3)],
             0.12, D("bfae96"))
    scallops(parts, surf, V((0, -0.4, 1.0)), [V((x, 1.0, z)) for x in (-0.5, 0.0, 0.5) for z in (-0.2, 0.3, 0.8)],
             0.14, D("9a8a74"))
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


# ================================================================ atlas helpers

def tex_is(info, hexcol, tol=0.08):
    t = info.get("tex")
    return t is not None and (t - C(hexcol)).length < tol


def atlas_eyes(body, min_n=150):
    """Drops the atlas eyeballs (grey lid balls of min_n+ vertices) and their pupil bars;
    returns the eyeball centres and radii."""
    out = []
    kill = []
    for vs, c, size, col in K.island_info(body):
        if K.is_grey(col, K.ATLAS_LID) and len(vs) >= min_n:
            out.append((c, max(size) * 0.5))
            kill.append(vs)
        elif K.is_grey(col, K.ATLAS_PUPIL, 0.03) and len(vs) < 30 and abs(c.x) > 0.25:
            kill.append(vs)
    import bmesh
    dead = set().union(*kill) if kill else set()
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in dead], context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    return sorted(out, key=lambda e: e[0].x)


# ================================================================ blob/Cat  village cat, summon cat

def tabby_cat(arm, body):
    """Cute tabby (the village cats, the summon cat): warm ginger fur with soft darker tabby
    stripes, white muzzle and chest, pink nose and inner ears, green sparkly eyes, whiskers."""
    eyes = atlas_eyes(body)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 3600)
    ginger, ginger_hi, stripe, cream = C("f4a860"), C("ffd090"), C("c86a34"), C("fff4e6")

    def paint(name, co, n, info):
        if tex_is(info, "893f5e", 0.12):
            return C("ffaabb")  # inner ear
        dark = tex_is(info, "714e23", 0.1)
        if dark and co.y < -0.68 and co.z < 0.65 and abs(co.x) < 0.3:
            return C("ff8fa0") if co.z > 0.42 else C("5a3020")  # nose / mouth line
        c = L.mix(ginger, ginger_hi, max(0.0, n.z) * 0.6)
        if dark:
            c = stripe
        muzzle = max(0.0, -n.y) * L.smooth(0.75, 0.3, co.z) + max(0.0, -n.z) * 0.8
        return L.mix(c, cream, L.smooth(0.25, 0.6, muzzle))

    K.paint_body(body, paint, tex=True)
    surf, parts = start(body)
    for (c, r) in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        cute_eye(parts, c + V((0, -0.02, 0.02)), r * 0.92, V((0.45 * sx, -1.0, 0.05)).normalized(), C("0e3a1a"),
                 C("7ae05a"), {"Head": 1.0}, iris=0.66, pupil=0.3, oval=1.3)
        p, n = M.front_hit(surf, 0.62 * sx, 0.42)
        if p is not None:
            M.cheek(parts, p, n, 0.1, 0.06, C("ff8f9a"))
            for k in (-1, 0, 1):
                parts.stroke(p + V((0.05 * sx, 0, 0.04 * k)), n,
                             [(0.0, 0.0), (0.18 * sx, 0.03 * k), (0.34 * sx, 0.07 * k)], 0.025, C("5a3a2a"), lift=0.02)
    finish(body, parts)


def ghoul_cat(arm, body):
    """Undead ghoul cat (ghoul_hound only): mangy grey-green fur, a stitched scar over the
    skull, bare bone ribs, sunken black sockets with glowing sickly pupils, jagged fangs,
    ragged tufts. Painted final colours (untinted): eerie, not cute."""
    eyes = atlas_eyes(body)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 3600)
    rot, rot_dk, pale, bone = D("a8b494"), D("707e60"), D("c8d0b0"), D("ece6cc")

    def paint(name, co, n, info):
        if tex_is(info, "893f5e", 0.12):
            return D("6a3a4a")  # inner ear, raw
        dark = tex_is(info, "714e23", 0.1)
        if dark and co.y < -0.68 and co.z < 0.65 and abs(co.x) < 0.3:
            return D("2a1a1a")
        c = L.mix(rot_dk, rot, L.smooth(-0.4, 0.8, n.z) * 0.7 + 0.2)
        if dark:
            c = L.mix(rot_dk, D("4a5640"), 0.6)  # old tabby stripes, now rot
        mott = 0.5 + 0.5 * math.sin(co.x * 9.0 + co.z * 7.0) * math.sin(co.y * 8.0 - co.z * 5.0)
        c = L.mix(c, D("6a6a48"), L.smooth(0.7, 0.95, mott) * 0.6)
        return L.mix(c, pale, max(0.0, -n.z) * 0.4)

    K.paint_body(body, paint, lambda *a: "keep", tex=True)
    surf, parts = start(body)
    parts.mode = "keep"
    for (c, r) in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        gaze = V((0.45 * sx, -1.0, 0.0)).normalized()
        # Sunken socket: a dark ring painted around a small glowing ember of a pupil.
        p, n = M.dir_hit(surf, c, gaze)
        if p is None:
            continue
        parts.decal(p, n, M.ellipse(r * 0.95, r * 0.75, 18, rot=0.35 * sx), D("140c10"), rings=2)
        with parts.use("glow"):
            parts.sphere_cap(c - gaze * r * 0.35, r * 0.62, gaze, (0.42, 0.42), None, {"Head": 1.0}, lift=0.0,
                             seg=14, rings=3, detail=False,
                             color_fn=lambda x, y: L.mix(D("faff9a"), D("8aff2a"), L.smooth(0.0, 1.0, math.hypot(x, y))))
        parts.sphere_cap(c - gaze * r * 0.35, r * 0.62, gaze, (0.08, 0.3), D("0a0a06"), {"Head": 1.0}, lift=0.02,
                         seg=10, rings=1)
        # Heavy brow ridge.
        q, qn = M.front_hit(surf, c.x * 1.0, c.z + r * 1.1)
        if q is not None:
            parts.stroke(q, qn, [(0.24 * sx, 0.08), (0.05 * sx, -0.02), (-0.12 * sx, -0.08)], 0.09, D("1a1a14"),
                         lift=0.02)
    # Stitched scar over the skull.
    p, n = M.dir_hit(surf, V((0, 0, 0.9)), V((0.25, -0.6, 1.0)))
    if p is not None:
        path = [(-0.35, 0.05), (-0.12, -0.02), (0.1, 0.03), (0.32, -0.04)]
        parts.stroke(p, n, path, 0.06, D("5a2a2a"), lift=0.014, taper=False, up=V((0, 1, 0)))
        for k in range(5):
            x = -0.3 + 0.15 * k
            parts.stroke(p, n, [(x, -0.08), (x + 0.02, 0.08)], 0.025, D("1a1410"), lift=0.022, taper=False,
                         up=V((0, 1, 0)))
    # Bare ribs on both flanks.
    for sx in (-1.0, 1.0):
        for k in range(3):
            q, qn = M.dir_hit(surf, V((0, 0.1, 0.7)), V((sx, 0.4 + 0.25 * k, -0.15 * k)))
            if q is not None:
                parts.stroke(q, qn, [(-0.14, 0.12), (0.0, 0.0), (0.14, -0.12)], 0.05, bone, lift=0.014,
                             up=V((0, 0, 1)))
    # Jagged fangs.
    for x, ln in ((-0.2, 0.2), (-0.08, 0.13), (0.07, 0.15), (0.19, 0.22)):
        q, qn = M.front_hit(surf, x, 0.32)
        if q is not None:
            K.fang(parts, q - qn * 0.02, V((x * 0.5, -0.3, -1.0)), ln, 0.045, {"Head": 1.0}, color=D("e8e0b0"))
    # Ragged tufts down the spine.
    fur_tufts(parts, surf, V((0, 0, 0.8)), [V((0, 0.2 * k, 1.0 - 0.3 * k)).normalized() for k in range(1, 5)], 0.26,
              rot_dk, D("9aa888"), weights=None, count=3, seed=13, spread=0.7)
    finish(body, parts)


# ================================================================ blob/Fish  mud_fish

def mud_fish(arm, body):
    """Toxic mud fish (mud_fish only): murky olive-brown scales, sickly yellow-green belly,
    glowing toxic spots, catfish barbels, slit yellow eyes, the toothy maw kept and yellowed.
    Painted final colours (untinted)."""
    eyes = atlas_eyes(body)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5000)
    mud, mud_dk, belly, toxic = D("8c8a48"), D("5e5c30"), D("c8d468"), D("9cff3a")

    def paint(name, co, n, info):
        if tex_is(info, "8d909e", 0.08):
            return L.mix(D("c8b878"), D("f0e8c0"), L.smooth(0.0, 0.08, info["bump"]))  # teeth
        if tex_is(info, "5b374b", 0.1):
            return D("2a1418")  # maw
        if tex_is(info, "ca8f2d", 0.12):
            return L.mix(D("7a7a30"), D("d8d050"), L.smooth(-0.02, 0.1, info["bump"]))  # side fins
        if tex_is(info, "00adaf", 0.15):
            return L.mix(D("4a4a24"), D("a8b040"), L.smooth(-0.02, 0.12, info["bump"]))  # dorsal fins
        c = L.mix(mud_dk, mud, L.smooth(-0.3, 0.8, n.z * 0.5 + n.y * 0.4) * 0.5 + 0.3)
        sc = 0.5 + 0.5 * math.sin(co.z * 14.0 + abs(co.x) * 6.0) * math.sin(co.y * 12.0)
        c = L.mix(c, mud_dk, L.smooth(0.75, 0.95, sc) * 0.5)
        return L.mix(c, belly, L.smooth(0.1, 0.7, -n.z) * 0.8)

    K.paint_body(body, paint, lambda *a: "keep", tex=True)
    surf, parts = start(body)
    parts.mode = "keep"
    for (c, r) in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        K.fierce_eye(parts, c, r * 0.9, V((0.55 * sx, -1.0, 0.1)).normalized(), D("fff04a"), D("d8a010"),
                     {"Head": 1.0}, lid=D("4a4a24"), slant=0.5, side=sx, slit=True, pupil_w=0.1, iris=0.8,
                     sclera=D("d8d890"), lid_drop=1.5)
    # Barbels (whiskers) from the corners of the maw.
    for sx in (-1.0, 1.0):
        p, n = M.front_hit(surf, 0.42 * sx, 0.45)
        if p is not None:
            parts.blob(p, 0.035, V((0.8 * sx, -0.6, -0.3)).normalized(), 0.7, None, weights={"Head": 1.0}, seg=6,
                       rings=6, tip=0.25, bend=V((0.1 * sx, 0, -0.3)),
                       color_fn=lambda t: L.mix(D("4a4a24"), D("a8b048"), t))
    with parts.use("glow"):
        placed = []
        for d in M.fibonacci(60):
            if d.y < -0.3 or len(placed) >= 10:
                continue
            p, n = M.dir_hit(surf, V((0, -0.1, 1.1)), d)
            if p is None or n.z < -0.3 or any((p - q).length < 0.35 for q in placed):
                continue
            placed.append(p)
            parts.decal(p, n, M.ellipse(0.06, 0.06, 10), toxic, rings=1)
    finish(body, parts)


# ================================================================ blob/Pigeon  volt_pigeon

def volt_pigeon(arm, body):
    """Thunder bird (volt_pigeon only): electric-blue plumage fading to a pale belly, a
    crest and wing tips that flash yellow, glowing lightning zigzags on both sides, a
    bright beak, determined glowing eyes. Painted final colours (untinted)."""
    eyes = atlas_eyes(body)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4200)
    blue, blue_dk, belly, volt = D("4a9aff"), D("2a4ad0"), D("d0ecff"), D("fff04a")

    def paint(name, co, n, info):
        if tex_is(info, "ca8f2d", 0.12):
            return L.mix(D("ff9a1a"), D("ffe04a"), L.smooth(0.4, 0.8, co.z))  # beak
        if tex_is(info, "232426", 0.05):
            return D("2a1a0a")
        if tex_is(info, "8d909e", 0.06):
            return D("1a2a8a")  # brow over the beak
        if abs(co.x) > 0.75:  # wing feathers
            return L.mix(blue_dk, volt, L.smooth(0.95, 1.18, abs(co.x)))
        c = L.mix(blue_dk, blue, L.smooth(-0.6, 0.7, n.z * 0.7 - n.y * 0.4) * 0.8 + 0.2)
        return L.mix(c, belly, L.smooth(0.2, 0.8, -n.z) * 0.8)

    K.paint_body(body, paint, lambda *a: "keep", tex=True)
    surf, parts = start(body)
    parts.mode = "keep"
    for (c, r) in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        K.fierce_eye(parts, c + V((0, -0.03, 0)), r * 0.85, V((0.5 * sx, -1.0, 0.05)).normalized(), D("ffec5a"),
                     D("ff9a1a"), {"Head": 1.0}, lid=D("2a3aaa"), slant=0.4, side=sx, slit=False, iris=0.92,
                     glow=True, lid_drop=1.8)
    with parts.use("glow"):
        for sx in (-1.0, 1.0):
            p, n = M.dir_hit(surf, V((0, -0.1, 0.8)), V((sx, 0.2, -0.1)))
            if p is not None:
                K.zigzag(parts, p, n, 0.55, volt, mode="glow", turn=0.25 * sx)
    # Crest of spiky feathers, yellow-tipped.
    for k in range(-2, 3):
        p, n = M.dir_hit(surf, V((0, -0.1, 0.9)), V((0.15 * k, 0.1, 1.0)))
        if p is not None:
            parts.blob(p - n * 0.05, (0.09, 0.05), V((0.35 * k, 0.4, 1.0)).normalized(), 0.45 - 0.05 * abs(k), None,
                       weights={"Head": 1.0}, seg=8, rings=5, tip=0.1, up=V((0, 1, 0)),
                       color_fn=lambda t: L.mix(blue, volt, L.smooth(0.5, 0.9, t)))
    finish(body, parts)


# ================================================================ cute/Deer  sky_hound

def cloud_deer(arm, body):
    """Cloud deer (sky_hound only): sky-white fur with a pale blue blush of dusk, cloud puffs
    around the neck and ears, pale gold antlers, a soft pink nose, big starry eyes and a
    small closed smile instead of the gaping mouth."""
    def junk(c, size, col, n):
        if n in (51, 37) and abs(c.x) > 0.35:
            return True  # eyes and lower lids
        if c.y < -0.45 and 0.35 < c.z < 0.8 and abs(c.x) < 0.3 and n <= 18:
            return True  # teeth, mouth
        return False
    K.delete_islands(body, junk)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4200)
    fur, fur_lo, sky = C("fbfcff"), C("dfe8f8"), C("a8c8f0")

    def paint(name, co, n, info):
        t = info.get("tex") or V((0.3, 0.3, 0.3))
        if tex_is(info, "686247", 0.07) and co.z > 1.2:
            return L.mix(C("e8c87a"), C("fff2c8"), L.smooth(1.3, 1.85, co.z))  # antlers
        if abs(co.x) > 0.4 and co.z > 1.1 and co.y > -0.1:
            return L.mix(C("ffc8d8"), fur, L.smooth(-0.2, 0.5, n.y))  # ears
        if tex_is(info, "212121", 0.05) and co.y < -0.5:
            return C("f2f4fb")  # the old big nose patch and mouth, now fur
        c = L.mix(fur_lo, fur, L.smooth(0.2, 1.2, co.z))
        return L.mix(c, sky, max(0.0, n.y) * 0.35 + max(0.0, -n.z) * 0.3)

    K.paint_body(body, paint, tex=True)
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        cute_eye(parts, V((0.46 * sx, -0.44, 0.92)), 0.2, V((0.5 * sx, -1.0, 0.0)).normalized(), C("1a2a6a"),
                 C("8ac8ff"), {"Head": 1.0}, iris=0.68, pupil=0.34, oval=1.25)
        p, n = M.front_hit(surf, 0.5 * sx, 0.62)
        if p is not None:
            M.cheek(parts, p, n, 0.09, 0.055, C("ffb0c8"))
    p, n = M.front_hit(surf, 0.0, 0.92)
    if p is not None:
        parts.ellipsoid(p + n * 0.03, (0.1, 0.06, 0.075), color=None, weights={"Head": 1.0}, seg=10, rings=7,
                        color_fn=lambda u: L.mix(C("ff8fa8"), C("ffd0dc"), L.smooth(-0.3, 0.9, u.z)))
    # A soft muzzle over the old gaping mouth, with a small closed smile.
    parts.ellipsoid(V((0, -0.56, 0.6)), (0.3, 0.16, 0.22), color=None, weights={"Head": 1.0}, seg=14, rings=9,
                    color_fn=lambda u: L.mix(C("e8eefa"), WHITE, L.smooth(-0.8, 0.5, u.z)))
    for sx in (-1.0, 1.0):
        parts.blob(V((0, -0.715, 0.6)), (0.018, 0.012), V((sx, 0.15, 0.0)).normalized(), 0.11, C("6a4a5a"),
                   weights={"Head": 1.0}, seg=6, rings=4, tip=0.6, bend=V((0, 0.02, 0.035)))
    # Cloud puffs: a fluffy collar and tufts by the ears.
    rng = random.Random(21)
    for i in range(10):
        a = 2.0 * math.pi * i / 10
        p, n = M.dir_hit(surf, V((0, 0, 0.35)), V((math.cos(a), math.sin(a), -0.35)))
        if p is None:
            continue
        s = rng.uniform(0.13, 0.18)
        parts.ellipsoid(p + n * 0.06, (s, s, s * 0.85), color=None, weights=p, seg=10, rings=7,
                        color_fn=lambda u: L.mix(C("cfe0f8"), WHITE, L.smooth(-0.7, 0.6, u.z)))
    for sx in (-1.0, 1.0):
        p, n = M.dir_hit(surf, V((0, 0, 1.0)), V((sx, 0.1, 0.55)))
        if p is not None:
            for k in range(3):
                parts.ellipsoid(p + n * 0.04 + V((0.06 * k * sx, 0.05 * k, 0.04 * k)), (0.1, 0.1, 0.09),
                                color=None, weights={"Head": 1.0}, seg=8, rings=6,
                                color_fn=lambda u: L.mix(C("d8e6fa"), WHITE, L.smooth(-0.7, 0.6, u.z)))
    finish(body, parts)


# ================================================================ big/Cactoro  giant_cactus

def giant_cactus(arm, body):
    """Giant saguaro (giant_cactus): a grumpy desert giant - deep ribbed green with pale
    rib ridges, big white spine clusters that read at range, stern amber eyes under heavy
    brows, a grim mouth, its sombrero, desert flowers on the shoulders and hat."""
    drop_islands(body, lambda c, size, mat: mat == "Cactoro_Secondary" and c.z < 3.0)  # the old brown spikes
    drop_islands(body, lambda c, size, mat: mat in ("Eye_White", "Eye_Black"))
    L.clean(body, fill_holes=12)
    L.decimate_to(body, 4400)
    green_top, green_low, rib = D("7ac850"), D("2f7a3a"), D("b8e888")
    straw_top, straw_low = D("ffd27a"), D("c8802e")

    def paint(name, co, n, info):
        if co.z > 3.1:  # sombrero
            if name == "Cactoro_Red":
                return D("e8443a")
            if name == "Cactoro_Main":
                return D("2fa85a")
            return L.mix(straw_low, straw_top, max(0.0, n.z) * 0.8 + 0.2)
        c = L.mix(green_low, green_top, L.smooth(0.0, 2.8, co.z) * 0.6 + max(0.0, n.z) * 0.3)
        a = math.atan2(co.y - 0.1, co.x)
        if abs(co.x) < 0.75:
            c = L.mix(c, rib, L.smooth(0.8, 0.97, math.cos(a * 8.0)) * 0.7)
        return c

    K.paint_body(body, paint)
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        K.fierce_eye(parts, V((0.33 * sx, -0.36, 2.3)), 0.17, V((0.3 * sx, -1.0, 0.0)).normalized(), D("ffd86a"),
                     D("d8801a"), {"Head": 1.0}, lid=D("3f8a42"), slant=0.3, side=sx, slit=False, iris=0.85,
                     lid_drop=1.7)
        p, n = M.front_hit(surf, 0.34 * sx, 2.55)
        parts.stroke(p, n, [(0.22 * sx, 0.07), (0.06 * sx, 0.0), (-0.1 * sx, -0.06)], 0.1, D("1f4a24"), lift=0.02)
    p, n = M.front_hit(surf, 0.0, 2.05)
    parts.stroke(p, n, [(x / 8.0 * 0.2, -0.04 * (x / 8.0) ** 2) for x in range(-8, 9)], 0.04, D("1a2a14"), lift=0.014,
                 taper=False)
    spine_clusters(parts, surf, V((0, 0.1, 1.5)), 34,
                   lambda p: (p.y < -0.25 and abs(p.x) < 0.55 and 1.85 < p.z < 2.75) or p.z > 3.0,
                   length=0.3, radius=0.055, z_range=(0.3, 3.0), seed=7)
    for sx, x in ((-1.0, 1.75), (1.0, 1.75)):
        p, n = M.dir_hit(surf, V((x * sx, 0.1, 1.85)), V((0.0, -0.2, 1.0)))
        if p is not None:
            M.flower(parts, p, n, 0.22, D("ff5fa2"), D("ffe066"), weights=p)
    p, n = M.dir_hit(surf, V((0.15, -0.25, 3.5)), V((-0.6, -0.8, 0.3)))
    if p is not None:
        M.flower(parts, p, n, 0.3, D("ff7a3a"), D("ffe066"), weights={"Head": 1.0}, turn=0.3)
    finish(body, parts)


# ================================================================ big/Fish  ice_fish, abyss_angler

def frost_fish(arm, body):
    """Frost fish-man (ice_fish; the abyss angler under its teal tint): pale scales over a
    darker back, fins with ribbed rays, a crest of ice-crystal spines, white teeth and cold
    glowing eyes - a predator that suits sky ice and the deep alike."""
    drop_islands(body, lambda c, size, mat: (mat == "Eye_White" and c.z > 2.3) or mat == "Eye_Black")
    L.clean(body)
    L.decimate_to(body, 4600)
    L.relax(body, 2, 0.3, ("Fish_Main",))
    back, side, belly = D("7c8ca4"), D("c8d4e2"), D("f4f8fc")

    def paint(name, co, n, info):
        if name == "Eye_White":
            return D("fbfbf4")
        if name == "Mouth":
            return D("2a1424")
        if name == "Fish_Flaps":
            return L.mix(D("9aa8c0"), D("eef4fa"), L.smooth(-0.02, 0.06, info["bump"]))
        if name == "Fish_Secondary" and co.y > 0.2:
            return D("dfe8f4")  # dorsal fins
        if name == "Fish_Secondary":
            return L.mix(belly, WHITE, L.smooth(1.0, 2.0, co.z))
        c = L.mix(side, back, L.smooth(-0.2, 0.7, n.y * 0.7 + n.z * 0.3))
        sc = 0.5 + 0.5 * math.sin(co.z * 11.0 + abs(co.x) * 5.0) * math.sin(co.y * 10.0 + co.x * 3.0)
        c = L.mix(c, back, L.smooth(0.8, 0.97, sc) * 0.4)
        return L.mix(c, belly, max(0.0, -n.y) * 0.25)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name in ("Eye_White", "Mouth") else "skin")
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        c = V((0.31 * sx, -0.4, 2.43))
        with parts.use("keep"):
            K.fierce_eye(parts, c, 0.16, V((0.35 * sx, -1.0, 0.0)).normalized(), D("f0ffff"), D("4ad8ff"),
                         {"Head": 1.0}, lid=D("6a7a94"), slant=0.45, side=sx, slit=True, pupil_w=0.1, iris=0.9,
                         glow=True, sclera=D("1a2a3a"), lid_drop=1.8)
    # Ice-crystal spines along the dorsal ridge.
    with parts.use("keep"):
        for k, (y, z, ln) in enumerate(((0.05, 3.5, 0.5), (0.4, 3.25, 0.45), (0.7, 2.85, 0.4), (0.85, 2.4, 0.36),
                                        (0.9, 1.95, 0.3))):
            p, n = M.dir_hit(surf, V((0, 0.0, z - 0.2)), V((0, y + 0.3, 0.8)))
            if p is None:
                continue
            for sx in (-1.0, 1.0):
                d = (n + V((0.35 * sx, 0, 0.3))).normalized()
                parts.blob(p - n * 0.05 + V((0.06 * sx, 0, 0)), (0.07, 0.05), d, ln, None, weights=p, seg=6, rings=4,
                           tip=0.05, color_fn=lambda t: L.mix(D("8ad8f8"), D("f4ffff"), t))
    finish(body, parts)


# ================================================================ big/Monkroose  volt_bunny, jade_monk, guardian

def thunder_monkey(arm, body):
    """Fierce monkey warrior (volt_bunny 'thunder monkey'; jade_monk; the guardian
    summon): sturdier limbs, light fur with darker gauntlet-like arms and legs, a dark
    mask around glaring amber eyes, cream muzzle, fangs, cheek ruffs and a crest of fur.
    Near-neutral paint so the yellow / jade / bronze tints each land."""
    eyes = atlas_eyes(body)
    L.clean(body)
    K.thicken(body, arm, {"UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R"}, 1.25)
    K.thicken(body, arm, {"UpperLeg.L", "UpperLeg.R", "LowerLeg.L", "LowerLeg.R"}, 1.3)
    L.subdivide(body, 1)
    L.decimate_to(body, 5200)
    fur, fur_hi, limb, mask, cream = D("ddd2bc"), D("f4ecda"), D("8a6e4e"), D("4a4036"), D("fff6e4")

    def paint(name, co, n, info):
        orange = tex_is(info, "9c632e", 0.1)
        dark = tex_is(info, "635c43", 0.06)
        head = co.z > 1.95
        if dark:
            return mask
        if orange and head:
            if co.y < -0.45 and abs(co.x) < 0.35:
                if co.y < -0.78 and co.z > 2.1:
                    return D("2a2024")  # nose
                return L.mix(D("efe2c8"), cream, max(0.0, n.z) * 0.5)  # muzzle
            if abs(co.x) > 0.5:
                return D("e8b8a0")  # inner ears
            return limb  # crown spots
        if orange and abs(co.x) > 0.55 or orange and co.z < 0.75:
            return L.mix(limb, D("6a5038"), L.smooth(1.4, 0.4, abs(co.x)) * 0.3)
        c = L.mix(fur, fur_hi, max(0.0, n.z) * 0.4 + max(0.0, -n.y) * 0.3)
        return L.mix(c, D("b8aa90"), max(0.0, n.y) * 0.35)

    K.paint_body(body, paint, tex=True)
    # A shorter snout: the long orange mongoose muzzle read as a duck bill.
    K.scale_region(body, lambda c: c.z > 1.9 and c.y < -0.35 and abs(c.x) < 0.4, V((0, -0.35, 2.2)),
                   (0.9, 0.62, 0.9), lambda c: L.smooth(-0.35, -0.55, c.y))
    body.data.update()
    surf, parts = start(body)
    for (c, r) in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        K.fierce_eye(parts, c + V((0, -0.02, 0)), r * 0.95, V((0.3 * sx, -1.0, 0.0)).normalized(), D("ffe27a"),
                     D("e88a1a"), {"Head": 1.0}, lid=mask, slant=0.45, side=sx, slit=False, iris=0.9, lid_drop=1.75)
        p, n = M.front_hit(surf, c.x, c.z + r * 1.3)
        if p is not None:
            parts.stroke(p, n, [(0.2 * sx, 0.07), (0.05 * sx, 0.0), (-0.1 * sx, -0.07)], 0.08, D("2a2018"), lift=0.02)
        fur_tufts(parts, surf, V((0, -0.2, 2.2)), [V((sx, -0.4, -0.4))], 0.24, fur, fur_hi, weights={"Head": 1.0},
                  seed=31 + int(sx))
    p, n = M.front_hit(surf, 0.0, 2.08)
    if p is not None:
        for sx in (-1.0, 1.0):
            K.fang(parts, p + V((0.07 * sx, 0.02, 0.0)), V((0, -0.3, -1)), 0.11, 0.032, {"Head": 1.0})
    fur_tufts(parts, surf, V((0, 0, 2.4)), [V((0, -0.2, 1)), V((0, 0.4, 1)), V((0, 0.8, 0.6))], 0.3, limb, fur,
              weights={"Head": 1.0}, seed=33)
    finish(body, parts)


# ================================================================ big/Birb  lava_dino

def lava_dino(arm, body):
    """Little lava dragon (lava_dino only): basalt-black scaly hide split by glowing magma
    cracks, a molten belly, an obsidian beak with ember nostrils, horns and spikes that heat
    to orange at the tips, ember eyes. Painted final colours (untinted)."""
    eyes = atlas_eyes(body)
    L.clean(body)
    K.thicken(body, arm, {"UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R"}, 1.2)
    K.thicken(body, arm, {"UpperLeg.L", "UpperLeg.R", "LowerLeg.L", "LowerLeg.R"}, 1.25)
    L.subdivide(body, 1)
    L.decimate_to(body, 5000)
    rock, rock_hi = D("2a1c1c"), D("5a3a32")

    def paint(name, co, n, info):
        if tex_is(info, "94261e", 0.1):
            return L.mix(D("1a1214"), D("4a3a3a"), max(0.0, n.z) * 0.6)  # obsidian beak
        if tex_is(info, "959391", 0.1):
            if abs(co.x) < 0.45 and co.y < 0.0 and co.z < 2.0:
                return L.mix(D("ff4a10"), D("ffd04a"), L.smooth(0.9, 1.9, co.z))  # molten belly
            return L.mix(rock_hi, D("ff8a2a"), L.smooth(0.0, 0.12, info["bump"]))  # horns / spikes
        c = L.mix(rock, rock_hi, max(0.0, n.z) * 0.5 + max(0.0, -n.y) * 0.2)
        sc = 0.5 + 0.5 * math.sin(co.z * 13.0 + co.x * 4.0) * math.sin(co.x * 12.0 + co.y * 9.0)
        return L.mix(c, D("6a4a40"), L.smooth(0.85, 0.98, sc) * 0.5)

    K.paint_body(body, paint, tex=True)
    # Belly faces glow: pick them by their painted colour (molten orange).
    me = body.data
    col = me.color_attributes["Col"]
    for poly in me.polygons:
        cc = col.data[poly.loop_indices[0]].color
        if cc[0] > 0.6 and cc[2] < 0.2:
            poly.material_index = K.MODES["glow"]
        else:
            poly.material_index = K.MODES["keep"]
    surf, parts = start(body)
    parts.mode = "keep"
    for (c, r) in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        K.fierce_eye(parts, c, r * 0.9, V((0.35 * sx, -1.0, 0.0)).normalized(), D("fff07a"), D("ff6a10"),
                     {"Head": 1.0}, lid=D("3a2624"), slant=0.5, side=sx, slit=True, pupil_w=0.1, iris=0.92,
                     glow=True, sclera=D("2a1410"), lid_drop=1.75)
    with parts.use("glow"):
        # Ember nostrils.
        for sx in (-1.0, 1.0):
            p, n = M.front_hit(surf, 0.08 * sx, 2.42)
            if p is not None:
                parts.decal(p, n, M.ellipse(0.03, 0.02, 8), D("ffb02a"), rings=1, lift=0.02)
        # Magma cracks over the hide.
        rng = random.Random(17)
        for d in M.fibonacci(46):
            p, n = M.dir_hit(surf, V((0, 0.15, 1.5)), d)
            if p is None or (abs(p.x) < 0.45 and p.y < 0.0 and 0.8 < p.z < 2.0):
                continue
            pts = [(0.0, 0.0)]
            for k in range(4):
                x, y = pts[-1]
                pts.append((x + rng.uniform(-0.06, 0.06), y + rng.uniform(0.05, 0.09) * (1 if k % 2 else -1) + 0.02))
            parts.stroke(p, n, pts, 0.035, D("ff7a1a"), lift=0.014, up=V((0, 0, 1)))
    finish(body, parts)


# ================================================================ cute/YellowDragon  sun_dino, nova_drake, jade_qilin, gold_wyrmling

def little_dragon(arm, body):
    """Little dragon (sun_dino, nova_drake, jade_qilin, gold_wyrmling tints): confident
    slit-pupil eyes under its brow ridges (no blush, no googly eyes), ivory horns and fangs,
    a pale scaled belly, darker scaled back, wings with darker bones over a lighter membrane.
    Near-neutral paint so the sun / supernova / jade / gold tints each land."""
    def junk(c, size, col, n):
        return n in (51, 37) and abs(c.x) > 0.3 and 0.7 < c.z < 1.0 and c.y < -0.3  # eyes and lids
    K.delete_islands(body, junk)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5200)
    hide, back, belly = D("f2e4c4"), D("c4a87e"), D("fff8e6")
    ivory, ivory_dk = D("fff6e0"), D("c8a874")

    def paint(name, co, n, info):
        t = info.get("tex")
        if abs(co.x) > 0.62 and co.z > 0.75:  # wings
            bone = tex_is(info, "302d15", 0.05) or tex_is(info, "372e13", 0.05)
            return D("8a6a4c") if bone else L.mix(D("d8bc94"), D("f0dcb8"), L.smooth(0.8, 1.3, co.z))
        if 1.05 < co.z and abs(co.x) > 0.2 and t is not None and t.length > 0.2 and co.y > -0.45:
            return L.mix(ivory_dk, ivory, L.smooth(1.0, 1.6, co.z))  # horns
        if (tex_is(info, "27250f", 0.03) or tex_is(info, "2b2910", 0.03)) and info["bone"].startswith("Eyebrow"):
            return D("5a4430")  # brow ridges
        if co.y < -0.45 and 0.55 < co.z < 0.7 and abs(co.x) < 0.25 and t is not None and t.length > 0.15:
            return ivory  # teeth
        if co.y < -0.35 and 0.3 < co.z < 0.72 and abs(co.x) < 0.3 and t is not None and t.length < 0.06:
            return D("6a1a2a")  # mouth
        c = L.mix(hide, back, L.smooth(-0.2, 0.7, n.y * 0.8 + n.z * 0.3))
        sc = 0.5 + 0.5 * math.sin(co.z * 16.0 + co.x * 5.0) * math.sin(co.x * 15.0 - co.y * 9.0)
        c = L.mix(c, back, L.smooth(0.82, 0.97, sc) * 0.35 * max(0.0, n.y + 0.3))
        return L.mix(c, belly, L.smooth(0.2, 0.8, -n.y) * L.smooth(0.95, 0.5, co.z))

    K.paint_body(body, paint, tex=True)
    me = body.data
    col = me.color_attributes["Col"]
    keep = {tuple(round(x, 3) for x in ivory), tuple(round(x, 3) for x in D("6a1a2a"))}
    for poly in me.polygons:
        cc = tuple(round(x, 3) for x in col.data[poly.loop_indices[0]].color[:3])
        if cc in keep:
            poly.material_index = K.MODES["keep"]
    K.bake_ao(body, strength=0.35)  # the hide alone: eyes and brows added below cast no dirty shade
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        K.fierce_eye(parts, V((0.41 * sx, -0.44, 0.88)), 0.2, V((0.45 * sx, -1.0, 0.0)).normalized(), D("fff07a"),
                     D("e88a10"), {"Head": 1.0}, lid=D("d8c49c"), slant=0.3, side=sx, slit=True, pupil_w=0.12,
                     iris=0.9, lid_drop=1.9, lid_size=0.8)
    K.join_parts(body, parts.to_object())


# ================================================================ blob/Mushnub_Evolved  venom_mush

def venom_mush(arm, body):
    """Venom toadstool (venom_mush only): a deep purple cap blushing to magenta at the rim,
    acid-green poison spikes, a pale lilac stalk with dark veins, narrow glowing eyes, a
    jagged yellowed grin dripping venom, glowing spores. Painted final colours (untinted)."""
    eyes = atlas_eyes(body)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 5200)
    cap, cap_rim, gill = D("4a1468"), D("c43aa8"), D("2a0a30")
    stalk, vein = D("e2d4e2"), D("8a6a9a")

    def paint(name, co, n, info):
        if tex_is(info, "2e6e89", 0.1):
            c = L.mix(cap_rim, cap, L.smooth(2.8, 3.9, co.z))
            return L.mix(c, gill, L.smooth(-0.1, -0.6, n.z))
        if tex_is(info, "ca8f2d", 0.12):
            return L.mix(D("3a8a1a"), D("e4ff5a"), L.smooth(0.0, 0.22, info["bump"]))  # poison spikes
        if tex_is(info, "8d909e", 0.08):
            return L.mix(D("b8a868"), D("f4ecc0"), L.smooth(0.0, 0.06, info["bump"]))  # teeth
        if tex_is(info, "5b374b", 0.1):
            return D("2a0a1e")
        v = 0.5 + 0.5 * math.sin(co.z * 7.0 + math.atan2(co.y, co.x) * 5.0)
        c = L.mix(stalk, vein, L.smooth(0.9, 0.99, v) * 0.6)
        return L.mix(c, D("b8a0c0"), max(0.0, -n.z) * 0.4 + max(0.0, n.y) * 0.2)

    K.paint_body(body, paint, lambda *a: "keep", tex=True)
    surf, parts = start(body)
    parts.mode = "keep"
    for (c, r) in eyes:
        sx = 1.0 if c.x > 0 else -1.0
        K.fierce_eye(parts, c, r * 0.75, V((0.4 * sx, -1.0, 0.0)).normalized(), D("f4ff8a"), D("7aff1a"),
                     {"Head": 1.0}, lid=D("c8b4cc"), slant=0.55, side=sx, slit=True, pupil_w=0.09, iris=0.9,
                     glow=True, sclera=D("1a0a1a"), lid_drop=1.85)
    with parts.use("glow"):
        for sx in (-1.0, 1.0):
            p, n = M.front_hit(surf, 0.55 * sx, 0.7)
            if p is not None:
                parts.ellipsoid(p + n * 0.03 + V((0, 0, -0.06)), (0.05, 0.05, 0.09), color=D("9cff3a"),
                                weights={"Head": 1.0}, seg=8, rings=6)
        placed = []
        for d in M.fibonacci(70):
            if d.z < 0.2 or len(placed) >= 12:
                continue
            p, n = M.dir_hit(surf, V((0, -0.3, 3.2)), d)
            if p is None or any((p - q).length < 0.45 for q in placed):
                continue
            placed.append(p)
            parts.decal(p, n, M.ellipse(0.07, 0.07, 10), D("d8ff7a"), rings=1)
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
    "blob/Cat": tabby_cat,
    "blob/CatGhoul": ghoul_cat,
    "blob/Fish": mud_fish,
    "blob/Pigeon": volt_pigeon,
    "cute/Deer": cloud_deer,
    "big/Cactoro": giant_cactus,
    "big/Fish": frost_fish,
    "big/Monkroose": thunder_monkey,
    "big/Birb": lava_dino,
    "cute/YellowDragon": little_dragon,
    "blob/Mushnub_Evolved": venom_mush,
}
SOURCE = {"big/FrogToxic": "big/Frog", "big/FrogKing": "big/Frog", "blob/CatGhoul": "blob/Cat"}


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
