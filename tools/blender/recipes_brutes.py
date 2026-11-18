"""Remaster recipes for the fierce monsters (team "brutes"): orcs, demons, golems, ninjas,
yetis, dinos and their bosses. Same pipeline as remaster_monsters.py (see its docstring):

    /opt/bpy5/bin/python tools/blender/recipes_brutes.py [big/Demon ...]

writes assets/models/monsters/remaster/<dir>/<Name>.glb (all recipes with no argument).
remaster_monsters.py registers these recipes too. Design rule: no blush, no googly eyes -
glowing slit / narrow eyes under heavy lids, brows, tusks, horns, scars, runes, fur.
Several rigs are shared by tinted monsters (MonsterData "tint" multiplies Skin / Detail /
Glow): their skin is painted in light, low-saturation tones so every tint reads, while
bone, tusks and fixed-colour eyes sit on the untinted Ivory / IvoryGlow materials.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
import kit_brutes as K  # noqa: E402
from mathutils import Vector  # noqa: E402

L.export = K.export  # unlit Glow, base colour factors (no-op for other models)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "models", "monsters")
OUT = os.path.join(SRC, "remaster")

C = L.srgb
SKIN, DETAIL, GLOW, IVORY, IVORY_GLOW = K.SKIN, K.DETAIL, K.GLOW, K.IVORY, K.IVORY_GLOW
SKIN_FUR, SKIN_HIDE = "Skin_Fur", "Skin_Hide"  # temporary slots (merged into Skin before export)
WHITE = C("ffffff")


# ---------------------------------------------------------------- big/Demon

def demon(arm, body):
    """hell_orc (red) and void_emperor (violet boss): a horned, winged demon lord.
    Burnt-black hands and feet, lighter chest, glowing ember cracks over the chest and
    arms (tinted: lava red / void violet), fiery untinted eyes under a scowling brow,
    ivory fangs and lower tusks, obsidian-to-bone horns, the halo turned into a glowing
    ring of hellfire."""
    keys = K.regions(body)
    BODY, DARK, EYE, PUPIL = "b25868", "666966", "c5c7d0", "606266"
    K.tag_regions(body, keys)
    L.delete_faces(body, ("R_" + EYE, "R_" + PUPIL))
    crisp = K.split_where(body, lambda p: body.data.materials[p.material_index].name == "R_" + DARK)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4100)
    L.relax(body, 2, 0.4)
    L.clean(crisp, quads=False)
    halo = K.face_islands(crisp, lambda p: abs(p.center.x) < 0.42 and p.center.z > 2.7 and abs(p.center.y) < 0.42)
    K.retag(crisp, {v for _c, _h, vs in halo for v in vs}, "R_halo")
    L.join(body, crisp)

    chest, main, back, burnt = C("f0d2c8"), C("cf9e94"), C("94635f"), C("2e2228")

    def paint(region, co, n, info):
        bone = info["bone"]
        r = region[2:]
        if r == "halo":
            return C("fff0d8"), GLOW  # the halo, turned into a ring of hellfire
        if r == DARK:
            if bone == "Middle1.L" or bone.startswith(("Index", "Pinky", "Thumb", "Middle")):
                # the trident: dark iron, bright edges
                return L.mix(C("2a2830"), C("8a8898"), L.smooth(0.0, 0.03, info["bump"])), IVORY

            if bone == "Head":  # horns: obsidian roots, bone tips
                t = L.smooth(2.5, 3.0, co.z)
                return L.mix(C("1e1820"), C("efe2c8"), t ** 1.3), IVORY
            # wing frame
            return L.mix(C("231c22"), C("4a3a40"), L.smooth(1.7, 2.3, co.z)), IVORY
        if bone == "Neck" and co.y > 0.4:  # wing membrane, darker to the edges
            d = (co - Vector((0.0, 0.5, 1.9))).length
            return L.mix(C("d6a49a"), C("5a3438"), L.smooth(0.35, 1.15, d))
        c = L.mix(back, main, L.smooth(0.45, -0.2, n.y))
        c = L.mix(c, chest, L.smooth(-0.35, -0.9, n.y) * L.smooth(0.9, 1.4, co.z) * L.smooth(2.3, 1.9, co.z))
        # burnt extremities: hands, forearm ends, feet and shins
        ext = max(L.smooth(1.25, 1.75, abs(co.x)), L.smooth(0.55, 0.15, co.z))
        c = L.mix(c, burnt, ext * 0.92)
        return c

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    lid = C("b07a74")
    for sx in (-1.0, 1.0):
        c = Vector((0.31 * sx, -0.47, 2.2))
        gaze = Vector((0.28 * sx, -1.0, 0.05)).normalized()
        K.fierce_eye(parts, c, 0.135, gaze, sx, C("fff6b0"), C("ff7a10"), head, lid=lid, open_=0.5,
                     glow_mat=IVORY_GLOW)
        # heavy brow ridge, low over the nose
        K.ridge(parts, Vector((0.5 * sx, -0.4, 2.42)), Vector((0.07 * sx, -0.6, 2.3)), 0.075, C("8a5550"), head,
                bulge=Vector((0, -0.05, 0.04)), tip=0.7)
        # upper fangs hanging over the lip, lower tusks jutting up
        K.fang(parts, Vector((0.14 * sx, -0.6, 1.98)), Vector((0.05 * sx, -0.25, -1.0)), 0.2, 0.045, head)
        K.fang(parts, Vector((0.26 * sx, -0.58, 1.86)), Vector((0.12 * sx, -0.3, 1.0)), 0.24, 0.055, head,
               root=C("d8c6a0"), bend=Vector((0.02 * sx, -0.05, 0.0)))
        # bone spikes on the shoulders
        for k, (dx, dz) in enumerate(((0.0, 0.0), (0.18, -0.06), (-0.16, -0.04))):
            p, n = K.dir_hit(surf, Vector((0.62 * sx + dx * sx, 0.15, 1.8)), Vector((0.35 * sx, 0.2, 1.0)))
            if p is not None:
                K.horn(parts, p - n * 0.03, (n + Vector((0.2 * sx, 0.1, 0.5))).normalized(), 0.26 - 0.06 * k,
                       0.06 - 0.01 * k, p, C("231c22"), C("efe2c8"), seg=8, rings=5)
    p, n = K.front_hit(surf, 0.0, 1.96)
    with parts.on(DETAIL):
        parts.stroke(p, n, [(x / 8.0 * 0.32, -0.04 * (1.0 - (x / 8.0) ** 2) - 0.02 * abs(x / 8.0)) for x in
                            range(-8, 9)], 0.05, C("2a0e12"), lift=0.012, taper=True)
    # Ember cracks: over the chest and down the arms.
    rng = random.Random(11)
    ember = C("ffe2c0")
    for (x, z, head_a, ln) in ((0.25, 1.55, -1.9, 0.55), (-0.3, 1.45, -1.2, 0.5), (0.05, 1.2, -1.6, 0.45),
                               (0.4, 1.25, -2.2, 0.35), (-0.15, 1.75, -0.6, 0.35)):
        p, n = K.front_hit(surf, x, z)
        if p is not None:
            K.glow_path(parts, p, n, K.crack_path(rng, ln, 6, 0.3, heading=head_a), 0.055, ember)
    for sx in (-1.0, 1.0):
        for k in range(2):
            p, n = K.dir_hit(surf, Vector((0.9 * sx + 0.3 * k * sx, 0.05, 1.82)), Vector((0, -0.3, 1.0)))
            if p is not None:
                K.glow_path(parts, p, n, K.crack_path(rng, 0.35, 5, 0.25, heading=0.0 if sx > 0 else math.pi), 0.035,
                            ember, up=Vector((0, -1, 0)))
    # a row of spines down the back
    for k, z in enumerate((2.45, 2.2, 1.95, 1.7, 1.45)):
        p, n = K.dir_hit(surf, Vector((0, 0.1, z)), Vector((0, 1.0, 0.15)))
        if p is not None:
            K.horn(parts, p - n * 0.03, (n + Vector((0, 0.0, 0.45))).normalized(), 0.34 - 0.035 * k, 0.07 - 0.007 * k,
                   p, C("231c22"), C("efe2c8"), seg=8, rings=5)
    K.join_parts(body, parts.to_object())
    K.bake_ao(body)


# ---------------------------------------------------------------- big/BlueDemon

def stone_golem(arm, body):
    """thunder_golem (yellow) and void_golem (violet): the goblin rig recut as a stone
    golem - flat-shaded faceted slate (untinted, so both share real stone), glowing cracks,
    eye slits, mouth and chest core on Glow (tinted: lightning yellow / void violet),
    boulder pauldrons and crystal growths that take the tint, a stone club with rune bands."""
    keys = K.regions(body)
    BODY, CLUB, WRAP, EYE, PUPIL, CLOTH = "79a6b7", "bfa985", "c5c7d0", "c5c7d0", "606266", "d2be5d"
    K.tag_regions(body, keys)
    groups = L.dominant_groups(body)
    L.delete_faces(body, ("R_" + PUPIL,), where=lambda c, n, g: n == "R_" + EYE and g == "Head")
    club = K.split_where(body, lambda p: body.data.materials[p.material_index].name in ("R_" + CLUB, "R_" + WRAP))
    L.clean(body)
    L.decimate_to(body, 2900)
    L.relax(body, 1, 0.3)
    L.clean(club, quads=False)
    L.join(body, club)
    lo, hi = L.bounds(body)
    slate_hi, slate, slate_lo = C("d4d4d2"), C("a6a8ac"), C("676a72")

    def stone(co, n, seed=0):
        c = L.mix(slate_lo, slate, L.smooth(0.0, 1.3, co.z))
        c = L.mix(c, slate_hi, L.smooth(1.6, 2.7, co.z) * 0.7 + max(0.0, n.z) * 0.25)
        j = K.hash01(co * 3.0, seed) - 0.5
        return c * (1.0 + j * 0.22)

    def paint(region, co, n, info):
        r = region[2:]
        cen = info["poly"]
        if r == CLUB:
            return stone(cen, n, 3) * 0.85, IVORY
        if r == WRAP:
            return L.mix(C("4a3a2c"), C("7a6450"), K.hash01(cen * 9.0)), IVORY  # leather grip
        if r == CLOTH:
            return C("5a4a3a"), IVORY
        return stone(cen, n), IVORY

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    glow, glow_core = C("fff6dc"), C("ffffff")
    for sx in (-1.0, 1.0):
        p, n = K.front_hit(surf, 0.33 * sx, 2.28)
        gaze = (n + Vector((0, -0.6, 0))).normalized()
        up = K.rot_about(Vector((0, 0, 1)), gaze, 0.42 * sx)
        side = gaze.cross(up).normalized()
        b = K.Matrix((side, up, gaze)).transposed()
        slit = [(sx * (-0.15 + 0.3 * i / 8.0), -0.06 + 0.12 * i / 8.0 + 0.03 * math.sin(math.pi * i / 8.0))
                for i in range(9)]
        with parts.on(DETAIL):
            parts.stroke(p, n, slit, 0.15, C("1e2028"), lift=0.014, weights=head)
        with parts.on(GLOW):
            parts.stroke(p, n, slit, 0.07, glow_core, lift=0.03, weights=head)
        # brow: a heavy slab of rock jutting over the eye slit
        K.ridge(parts, p + side * 0.2 * sx + up * 0.13 - gaze * 0.03, p - side * 0.2 * sx + up * 0.1 - gaze * 0.03,
                0.085, lambda t: stone(Vector((0, 0, 2.3)), Vector((0, 0, 1))) * (0.95 - 0.1 * t), head,
                bulge=gaze * 0.06 + up * 0.03, tip=0.75, mat=IVORY, seg=7, rings=5)
    # a jagged glowing mouth
    p, n = K.front_hit(surf, 0.0, 1.98)
    mouth = [(-0.3, 0.02), (-0.2, -0.03), (-0.1, 0.01), (0.0, -0.05), (0.1, 0.01), (0.2, -0.03), (0.3, 0.02)]
    with parts.on(DETAIL):
        parts.stroke(p, n, mouth, 0.1, C("1e2028"), lift=0.012, taper=False, weights=head)
    K.glow_path(parts, p, n, mouth, 0.04, glow_core)
    # chest core: a glowing gem set in a dark ring, cracks running out of it
    p, n = K.front_hit(surf, 0.0, 1.45)
    with parts.on(DETAIL):
        parts.decal(p, n, K.ellipse(0.17, 0.2, 16), C("1e2028"), rings=2)
    with parts.on(GLOW):
        parts.ellipsoid(p - n * 0.03, (0.11, 0.08, 0.15), K.basis(n), color=None, weights=p, seg=4, rings=4,
                        color_fn=lambda u: L.mix(glow_core, glow, abs(u.z)))
    rng = random.Random(7)
    for a in (0.5, 1.4, 2.4, 3.6, 4.6, 5.6):
        d = Vector((math.cos(a), 0, math.sin(a)))
        q, m = K.front_hit(surf, d.x * 0.24, 1.45 + d.z * 0.24)
        if q is not None:
            path = K.crack_path(rng, 0.45, 5, 0.25, heading=a)
            with parts.on(DETAIL):
                parts.stroke(q, m, path, 0.07, C("1e2028"), lift=0.01)
            K.glow_path(parts, q, m, path, 0.03, glow)
    # cracks over the back, the arms and the thighs
    for (c, d, heading, ln) in ((Vector((0, 0, 1.6)), Vector((0.2, 1, 0.3)), 1.2, 0.7),
                                (Vector((0, 0, 1.2)), Vector((-0.3, 1, -0.1)), -0.4, 0.6),
                                (Vector((0.95, 0.05, 1.82)), Vector((0, -0.2, 1)), 0.1, 0.5),
                                (Vector((-0.95, 0.05, 1.82)), Vector((0, -0.2, 1)), 3.0, 0.5),
                                (Vector((0.35, 0.2, 0.6)), Vector((0.6, -1, 0)), 1.7, 0.35),
                                (Vector((-0.35, 0.2, 0.6)), Vector((-0.6, -1, 0)), 1.4, 0.35),
                                (Vector((0, 0, 2.3)), Vector((0.2, -0.4, 1.0)), 0.2, 0.35)):
        q, m = K.dir_hit(surf, c, d)
        if q is not None:
            path = K.crack_path(rng, ln, 6, 0.3, heading=heading)
            with parts.on(DETAIL):
                parts.stroke(q, m, path, 0.065, C("1e2028"), lift=0.01)
            K.glow_path(parts, q, m, path, 0.028, glow)
    # boulder pauldrons and crystal growths (crystals take the tint)
    for sx in (-1.0, 1.0):
        q, m = K.dir_hit(surf, Vector((0.75 * sx, 0.15, 1.75)), Vector((0.3 * sx, 0.1, 1.0)))
        if q is not None:
            K.rock(parts, q + m * 0.05, 0.3, lambda u: stone(Vector((0, 0, 2.0)), u) * 0.95, q, seed=int(10 + sx),
                   squash=(1.15, 1.0, 0.7), up=m)
            for k in range(3):
                dd = (m + Vector((0.35 * sx * (k - 1), 0.5 + 0.2 * k, 0.6))).normalized()
                K.crystal(parts, q + m * 0.18 + Vector((0.1 * sx * (k - 1), 0.12, 0.0)), dd, 0.42 - 0.08 * abs(k - 1),
                          0.08, q, C("c8ccd8"), C("ffffff"), mat=SKIN)
    for k, (x, z) in enumerate(((0.3, 2.0), (-0.25, 1.75), (0.05, 1.35))):
        q, m = K.dir_hit(surf, Vector((x, 0.0, z)), Vector((x * 0.6, 1.0, 0.25)))
        if q is not None:
            K.crystal(parts, q - m * 0.03, (m + Vector((0, 0.1, 0.55))).normalized(), 0.5 - 0.08 * k, 0.1, q,
                      C("c8ccd8"), C("ffffff"), mat=SKIN)
    # rune bands of light around the club
    cv = [v.co for v, g in zip(body.data.vertices, L.dominant_groups(body)) if g == "Middle1.L"]
    for yb in (-0.62, -1.0):
        ring = [v for v in cv if abs(v.y - yb) < 0.22]
        if ring:
            cx = sum(v.x for v in ring) / len(ring)
            cz = sum(v.z for v in ring) / len(ring)
            rad = max(math.hypot(v.x - cx, v.z - cz) for v in ring)
            with parts.on(GLOW):
                parts.frustum(Vector((cx, yb + 0.025, cz)), Vector((0, -1, 0)), rad * 0.8, rad * 0.8, 0.05,
                              lambda t, side_: glow, {"Middle1.L": 1.0}, seg=10)
    K.join_parts(body, parts.to_object())
    K.flat(body, (IVORY, SKIN))
    K.bake_ao(body, strength=0.5)


# ---------------------------------------------------------------- big/Alien

def swamp_beast(arm, body):
    """swamp_dino: a bog monster. Mottled moss-and-mud hide (darker back, sallow belly),
    warts, moss hanging off the shoulders and head, the curly feelers turned into dripping
    swamp-weed fronds, sickly glowing slit eyes under heavy lids, a jagged maw with
    yellowed teeth. Painted through its green tint (pre-compensated)."""
    tint = (0.7, 1.3, 0.7)
    P = lambda h: K.pre(C(h), tint)  # noqa: E731
    keys = K.regions(body)
    BODY, WEED, BELLY, MOUTH, PUPIL = "9b70a8", "97b77e", "c5c7d0", "a17e93", "606266"
    K.tag_regions(body, keys)
    L.delete_faces(body, ("R_" + PUPIL,), where=lambda c, n, g: n == "R_" + BELLY and g == "Head")
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4400)
    L.relax(body, 2, 0.4)
    back, hide, belly, mud = C("5f7834"), C("86a04a"), C("d6cf86"), C("6e6034")

    def paint(region, co, n, info):
        r = region[2:]
        if r == WEED:  # swamp weed: dark roots, yellow-green tips, banded
            if abs(co.x) > 0.55:  # the curls by the ears
                t = L.smooth(0.6, 1.05, abs(co.x))
            elif co.z > 2.7:  # the horns
                t = L.smooth(2.6, 3.5, co.z)
            else:  # the snout
                t = 0.45
            c = L.mix(C("2e5a22"), C("b8e05a"), t)
            c = L.mix(c, C("1e4018"), L.smooth(0.55, 0.8, K.noise(co, 6.0, 3)) * 0.5)
            return K.pre(c, tint)
        if r == MOUTH:
            return K.pre(L.mix(C("200a0c"), C("6a2026"), L.smooth(-0.6, -0.2, n.y) * 0.5), tint)
        c = L.mix(back, hide, L.smooth(0.5, -0.4, n.y))
        if r == BELLY or (co.y < -0.3 and abs(co.x) < 0.45 and 0.9 < co.z < 1.8):
            c = L.mix(c, belly, 0.85 if r == BELLY else 0.5)
        m = K.fbm(co, 1.6, 7)
        c = L.mix(c, C("3e4a1e"), L.smooth(0.55, 0.75, m) * 0.55)  # dark blotches
        c = L.mix(c, C("b8c070"), L.smooth(0.42, 0.3, m) * 0.4)  # sallow patches
        c = L.mix(c, mud, L.smooth(0.7, 0.15, co.z))  # mud-caked legs
        return K.pre(c, tint)

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    lid = P("6a8238")
    for sx in (-1.0, 1.0):
        c = Vector((0.3 * sx, -0.43, 2.3))
        gaze = Vector((0.3 * sx, -1.0, 0.0)).normalized()
        K.fierce_eye(parts, c, 0.13, gaze, sx, C("f4ff8a"), C("7ab018"), head, lid=lid, open_=0.48,
                     glow_mat=IVORY_GLOW, slant=0.3)
        K.ridge(parts, Vector((0.48 * sx, -0.36, 2.52)), Vector((0.08 * sx, -0.58, 2.42)), 0.075, P("56702e"), head,
                bulge=Vector((0, -0.05, 0.03)), tip=0.7)
    # jagged yellowed teeth around the maw
    p, n = K.front_hit(surf, 0.0, 1.98)
    for k, x in enumerate((-0.13, -0.065, 0.0, 0.065, 0.13)):
        q, m = K.front_hit(surf, x * 1.2, 2.07)
        if q is not None:
            K.fang(parts, q + Vector((0, 0.02, 0)), Vector((0.1 * x, -0.35, -1.0)), 0.12 + 0.04 * (k % 2), 0.034, head,
                   root=C("b8a868"), tip_col=C("f0e8c0"), seg=6, rings=3)
        q, m = K.front_hit(surf, x * 0.9, 1.9)
        if q is not None and k % 2 == 0:
            K.fang(parts, q + Vector((0, 0.02, 0)), Vector((0.1 * x, -0.35, 1.0)), 0.1, 0.03, head,
                   root=C("b8a868"), tip_col=C("f0e8c0"), seg=6, rings=3)
    # warts over the back, shoulders and crown
    rng = random.Random(4)
    placed = []
    for d in K.fibonacci(160):
        if d.y < -0.35 and abs(d.x) < 0.6:
            continue
        p, n = K.dir_hit(surf, Vector((0, 0.05, 1.7)), d)
        if p is None or p.z < 0.7 or any((p - q).length < 0.22 for q in placed) or len(placed) > 26:
            continue
        placed.append(p)
        s = rng.uniform(0.035, 0.065)
        parts.ellipsoid(p, (s, s, s * 0.6), K.basis(n), color=None, weights=p, seg=6, rings=4,
                        color_fn=lambda u: K.pre(L.mix(C("5a6a2e"), C("c4d07a"), L.smooth(-0.2, 0.9, u.z)), tint))
    # moss hanging off the shoulders, the back of the head and the arms
    dirs = [d for d in K.fibonacci(90) if d.z > 0.15 and d.y > -0.2]
    K.tufts(parts, surf, Vector((0, 0.1, 1.9)), dirs, 0.22, 0.045, K.pre(C("3e6a24"), tint), K.pre(C("b4dc5a"), tint),
            seed=5, per=2, droop=0.9, lift_out=0.5, skip=lambda p, n: p.z < 1.6, seg=5, rings=3)
    for sx in (-1.0, 1.0):
        arm_dirs = [Vector((0.0, 0.3, 1.0)).normalized()]
        for k in range(5):
            K.tufts(parts, surf, Vector((sx * (0.6 + 0.22 * k), 0.15, 1.82)), arm_dirs, 0.2, 0.04,
                    K.pre(C("3e6a24"), tint), K.pre(C("b4dc5a"), tint), seed=10 + k, per=2, droop=1.2,
                    lift_out=0.3, seg=5, rings=3)
    # slime sheen streaks on the head and belly
    for (x, z) in ((-0.25, 2.65), (0.18, 1.45)):
        p, n = K.front_hit(surf, x, z)
        if p is not None:
            with parts.on(DETAIL):
                parts.stroke(p, n, [(math.cos(a) * 0.12, math.sin(a) * 0.1) for a in
                                    [math.radians(d) for d in range(100, 180, 15)]], 0.035,
                             K.pre(C("d8f0a0"), tint), lift=0.016)
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, shade=Vector((0.5, 0.55, 0.45)))


# ---------------------------------------------------------------- big/Dino

def claws(parts, arm, side, length=0.16, radius=0.04, root=C("4a3a30"), tip_col=C("e8dcc4"), toes=None):
    """Hooked claws on a big rig's finger tips (and optionally toes [(point, direction)])."""
    for f in ("Index3", "Middle3", "Pinky3", "Thumb2"):
        b = arm.data.bones["%s.%s" % (f, side)]
        d = (b.tail_local - b.head_local).normalized()
        K.fang(parts, b.tail_local - d * 0.04, (d + Vector((0, -0.2, -0.5))).normalized(), length, radius,
               {b.name: 1.0}, root=root, tip_col=tip_col, bend=Vector((0, 0, -length * 0.35)), seg=6, rings=4)
    for (p, d) in toes or ():
        K.fang(parts, p, d, length * 0.9, radius * 1.1, p, root=root, tip_col=tip_col,
               bend=Vector((0, 0, -length * 0.3)), seg=6, rings=4)


def sand_raptor(arm, body):
    """sand_dino (plus the summoner's green beast and the jade drake, which repaint it):
    a desert raptor-dino. Its hue lives in the Dino_Main / Dino_Secondary base colours
    (so a template's "paint" still recolours it); the vertex paint carries the pattern:
    dark tiger bands over the back, mottled scales, pale throat. Lit amber slit eyes under
    horned brows, ivory fangs, hooked claws on hands and feet."""
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4300)
    L.relax(body, 2, 0.4)
    body["base_colors"] = '{"Dino_Main": "e2b67e", "Dino_Secondary": "f4e2b8"}'

    def paint(name, co, n, info):
        if name == "Dino_Teeth":
            return L.mix(C("d8c8a0"), C("fffaf0"), L.smooth(2.1, 1.8, co.z)), IVORY
        if name == "Dino_Tongue":
            return L.mix(C("8a2a34"), C("e0607a"), L.smooth(-0.3, 0.6, n.z)), IVORY
        if name == "Dino_Secondary":
            if co.y < -0.05 and co.z < 2.3:  # belly plates: pale, ribbed
                v = 0.93 + 0.07 * math.cos(co.z * 26.0)
                return Vector((v, v, v)), "Dino_Secondary"
            # crest and back plates: dark roots, pale tips
            t = L.smooth(-0.02, 0.12, info["bump"])
            return L.mix(C("b08a6a"), C("ffffff"), t), "Dino_Secondary"
        c = L.mix(C("ffffff"), C("e4d8cc"), L.smooth(-0.3, 0.5, n.y))  # shaded back
        throat = L.smooth(-0.3, -0.85, n.y) * L.smooth(2.4, 1.6, co.z) * L.smooth(0.9, 1.3, co.z)
        c = L.mix(c, C("fff8ec"), throat)
        # tiger bands across the back and down the limbs
        band = math.sin(co.z * 9.0 + K.noise(co, 2.0, 5) * 3.0) if n.y > -0.2 else -1.0
        c = L.mix(c, C("a8785a"), L.smooth(0.5, 0.9, band) * L.smooth(-0.3, 0.3, n.y) * 0.55)
        c = L.mix(c, C("8a7060"), L.smooth(0.6, 0.8, K.noise(co, 9.0, 2)) * 0.25)  # scale mottling
        c = L.mix(c, C("6a5040"), L.smooth(0.35, 0.05, co.z) * 0.6)  # dusty feet
        return c, "Dino_Main"

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    for sx in (-1.0, 1.0):
        c = Vector((0.36 * sx, -0.4, 2.5))
        gaze = Vector((0.45 * sx, -1.0, 0.0)).normalized()
        K.fierce_eye(parts, c, 0.125, gaze, sx, C("ffd040"), C("c86010"), head, lid=C("c8a070"), open_=0.5,
                     glow_mat=IVORY, slant=0.28, lid_mat="Dino_Main")
        # horned brow scutes
        K.horn(parts, Vector((0.36 * sx, -0.42, 2.66)), Vector((0.5 * sx, 0.3, 0.6)).normalized(), 0.2, 0.06, head,
               C("6a5040"), C("f4e8d0"), mat="Dino_Secondary", seg=8, rings=5)
        K.ridge(parts, Vector((0.56 * sx, -0.3, 2.66)), Vector((0.14 * sx, -0.55, 2.6)), 0.06, C("b89070"), head,
                bulge=Vector((0, -0.04, 0.03)), tip=0.7, mat="Dino_Main")
        side = "L" if sx > 0 else "R"
        toes = []
        for k in (-1, 0, 1):
            toes.append((Vector((0.36 * sx + 0.09 * k, -0.18, 0.08)), Vector((0.2 * k, -1.0, -0.3)).normalized()))
        claws(parts, arm, side, toes=toes)
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, shade=Vector((0.62, 0.52, 0.5)))


# ---------------------------------------------------------------- big/Orc

def forest_orc(arm, body):
    """forest_orc: a hulking woodland orc. Moss-green hide with darker back and war-paint
    stripes, a dark leaf-and-hair mohawk, big ivory tusks under a heavy scowl, small
    ember eyes, a scar over one eye, a necklace of fangs, a gnarled wooden club with
    iron spikes."""
    L.delete_faces(body, ("Eye_Black",), where=lambda c, n, g: n == "Eye_White" and c.z > 2.2)
    L.clean(body)
    wood = L.split_off(body, ("Middle1.L", "Index1.L", "Pinky1.L", "Thumb1.L"))
    L.subdivide(body, 1)
    L.decimate_to(body, 4300)
    L.relax(body, 2, 0.4)
    L.join(body, wood)
    hide_hi, hide, back = C("bcd474"), C("94b456"), C("688c42")

    def paint(name, co, n, info):
        bone = info["bone"]
        if name == "Wood":
            return L.mix(C("3e2818"), C("8a6040"), K.noise(co * Vector((1, 0.3, 1)), 9.0, 1)), IVORY
        if name == "Metal":
            return L.mix(C("4a4a52"), C("c8ccd4"), L.smooth(0.0, 0.04, info["bump"])), IVORY
        if name == "Eye_White":  # the tusks and teeth
            return L.mix(C("c8b890"), C("fffaf0"), L.smooth(1.85, 2.15, co.z)), IVORY
        if name == "Gold":
            return C("e0b040"), IVORY
        if name == "Orc_Hair":
            return L.mix(C("2e2216"), C("6a5236"), L.smooth(2.6, 3.1, co.z))
        if name == "Tongue":
            return C("7a2a30")
        if name == "Orc_Mouth":
            return C("2a0e10")
        if name == "Belt":
            return L.mix(C("3a2a1a"), C("6a4a30"), K.noise(co, 12.0, 4))
        c = L.mix(back, hide, L.smooth(0.4, -0.3, n.y))
        c = L.mix(c, hide_hi, L.smooth(-0.4, -0.9, n.y) * L.smooth(1.2, 1.9, co.z) * 0.6)
        c = L.mix(c, C("587a36"), L.smooth(0.58, 0.78, K.fbm(co, 2.2, 3)) * 0.35)
        if name == "Orc_Secondary":  # war paint bands, soft
            c = L.mix(c, C("3e5a2a"), 0.55)
        return c

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    for sx in (-1.0, 1.0):
        c = Vector((0.26 * sx, -0.5, 2.34))
        gaze = Vector((0.25 * sx, -1.0, 0.0)).normalized()
        K.fierce_eye(parts, c, 0.1, gaze, sx, C("ffe070"), C("e04010"), head, lid=C("7a9a48"), open_=0.45,
                     glow_mat=IVORY_GLOW, pupil="dot", slant=0.4)
        K.ridge(parts, Vector((0.45 * sx, -0.45, 2.5)), Vector((0.04 * sx, -0.66, 2.42)), 0.075, C("6a8c40"), head,
                bulge=Vector((0, -0.05, 0.03)), tip=0.75)
        # big lower tusks
        K.fang(parts, Vector((0.24 * sx, -0.58, 1.95)), Vector((0.25 * sx, -0.3, 1.0)), 0.34, 0.075, head,
               root=C("c8b890"), bend=Vector((0.04 * sx, -0.06, 0.0)))
    # a scar across the left eye
    p, n = K.front_hit(surf, 0.28, 2.36)
    with parts.on(DETAIL):
        parts.stroke(p, n, [(-0.06, 0.2), (0.0, 0.05), (0.04, -0.06), (0.09, -0.2)], 0.035, C("c08068"), lift=0.03)
    # a necklace of fangs
    for k in range(-3, 4):
        a = k * 0.32
        q, m = K.dir_hit(surf, Vector((0, 0.05, 1.85)), Vector((math.sin(a), -math.cos(a), -0.25)))
        if q is not None:
            K.fang(parts, q + m * 0.03, Vector((0, -0.25, -1.0)), 0.13 - 0.015 * abs(k), 0.03, q,
                   root=C("c8b890"), seg=6, rings=3)
            parts.ellipsoid(q + m * 0.02, (0.025, 0.025, 0.025), color=C("6a4a30"), weights=q, seg=6, rings=4)
    K.join_parts(body, parts.to_object())
    K.bake_ao(body)


# ---------------------------------------------------------------- big/Orc_Skull

def skull_orc(arm, body):
    """skull_orc and bone_lord (blood-red boss): an orc under a real bone skull helm.
    Aged ivory skull with cracks (untinted), pitch-black sockets with ember eyes burning
    deep inside, curling bone horns from its temples, a blood-red mohawk, grey-green hide
    with dark war stripes (tinted towards dried blood for the bone lord), iron spikes."""
    L.clean(body)
    iron = K.split_where(body, lambda p: body.data.materials[p.material_index].name in ("Metal", "Wood"))
    L.subdivide(body, 1)
    L.decimate_to(body, 4300)
    L.relax(body, 2, 0.35)
    L.clean(iron, quads=False)
    L.join(body, iron)
    bone_hi, bone, bone_lo = C("f6eedc"), C("e0d0b0"), C("a89272")

    def paint(name, co, n, info):
        if name == "MushroomKing_Main":
            socket = 0.1 < abs(co.x) < 0.43 and 2.12 < co.z < 2.42 and co.y > -0.6
            nose = abs(co.x) < 0.09 and 2.0 < co.z < 2.16 and co.y > -0.72
            if socket or nose:
                return C("120a0a"), IVORY
            c = L.mix(bone_lo, bone, L.smooth(1.8, 2.3, co.z))
            c = L.mix(c, bone_hi, max(0.0, n.z) * 0.5 + max(0.0, -n.y) * 0.2)
            c = L.mix(c, C("8a7458"), L.smooth(0.6, 0.8, K.fbm(co, 4.0, 2)) * 0.35)  # stains
            if 1.86 < co.z < 2.02 and co.y < -0.6:  # teeth gaps
                c = L.mix(c, C("3a2a20"), L.smooth(0.75, 0.95, math.cos(co.x * 52.0)) * 0.8)
            return c, IVORY
        if name == "Metal":
            return L.mix(C("3a3a42"), C("c4c8d0"), L.smooth(0.0, 0.05, info["bump"])), IVORY
        if name == "Wood":
            return L.mix(C("3a2618"), C("7a5636"), K.noise(co, 10.0, 1)), IVORY
        if name == "Orc_Mouth":  # the mohawk
            return L.mix(C("5a0e18"), C("d8343e"), L.smooth(2.6, 3.2, co.z))
        if name.startswith("Belt"):
            return L.mix(C("3e2a1c"), C("7a5636"), K.noise(co, 12.0, 4))
        c = L.mix(C("6c7a54"), C("a4b07e"), L.smooth(0.4, -0.4, n.y))
        c = L.mix(c, C("56603e"), L.smooth(0.6, 0.8, K.fbm(co, 2.5, 6)) * 0.4)
        if name == "Orc_Secondary":
            c = L.mix(c, C("2e3420"), 0.7)
        return c

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    for sx in (-1.0, 1.0):
        c = Vector((0.26 * sx, -0.54, 2.27))
        with parts.on(IVORY_GLOW):
            parts.ellipsoid(c, (0.075, 0.05, 0.06), color=None, weights=head, seg=10, rings=6,
                            color_fn=lambda u: L.mix(C("ff3010"), C("fff0a0"), L.smooth(-0.9, -0.2, u.y)))
        # curling bone horns from the temples
        K.horn(parts, Vector((0.46 * sx, -0.3, 2.55)), Vector((0.8 * sx, 0.1, 0.5)).normalized(), 0.55, 0.11, head,
               C("a89272"), C("fff6e4"), bend=Vector((0.05 * sx, 0.12, 0.35)), rings_col=C("8a7458"), bands=5)
    # cracks over the skull
    rng = random.Random(3)
    for (x, z, a) in ((0.2, 2.62, -1.2), (-0.3, 2.55, -2.0), (0.05, 2.75, -1.5)):
        p, n = K.front_hit(surf, x, z)
        if p is not None:
            with parts.on(DETAIL):
                parts.stroke(p, n, K.crack_path(rng, 0.22, 4, 0.3, heading=a), 0.025, C("4a3a2a"), lift=0.012,
                             weights=head)
    K.join_parts(body, parts.to_object())
    K.bake_ao(body)


# ---------------------------------------------------------------- big/Ninja

def slit_eyes(parts, surf, x, z, w, h, slant, core, rim, weights, band=None, mat=GLOW, lift=0.03):
    """Glowing eye slits painted onto a face, optionally over a dark band (mask opening)."""
    for sx in (-1.0, 1.0):
        p, n = K.front_hit(surf, x * sx, z)
        if p is None:
            continue
        path = [(sx * (-w * 0.5 + w * i / 8.0), -h * 0.5 * (1.0 - i / 8.0) * slant + h * 0.35 *
                 math.sin(math.pi * i / 8.0)) for i in range(9)]
        if band is not None:
            with parts.on(DETAIL):
                parts.stroke(p, n, path, h * 2.2, band, lift=lift * 0.5, weights=weights)
        with parts.on(mat):
            parts.stroke(p, n, path, h, core, lift=lift, weights=weights)


def shadow_ninja(arm, body):
    """shadow_ninja, rift_stalker (cyan) and abyss_merman (teal): a masked assassin.
    The bare face becomes a cloth mask with glowing eye slits (tinted), deep-shadowed
    hood and suit with lighter folds, bandage-wrapped hands and shins, a blood-red sash
    and trailing scarf, steel katanas with gold guards (untinted)."""
    L.delete_faces(body, ("Eye_Black",), where=lambda c, n, g: n == "Eye_White" and g == "Head")
    L.clean(body)
    names = [m.name for m in body.data.materials]
    groups = L.dominant_groups(body)
    steel = K.split_where(body, lambda p: names[p.material_index] in ("Eye_White", "Birb_Secondary", "Gold") or
                          groups[p.vertices[0]] == "Middle1.L" or
                          (names[p.material_index] == "Ninja_Main" and p.center.y > 0.4 and p.center.z > 2.25))
    L.subdivide(body, 1)
    L.decimate_to(body, 4300)
    L.relax(body, 2, 0.4)
    L.clean(steel, quads=False)
    L.join(body, steel)
    suit_hi, suit, suit_lo = C("7c7c9a"), C("48485e"), C("2a2a38")

    def paint(name, co, n, info):
        bone = info["bone"]
        if name in ("Eye_White", "Birb_Secondary"):
            return L.mix(C("7a8090"), C("f4f8ff"), L.smooth(-0.01, 0.03, info["bump"]) * 0.6 + max(0.0, n.z) * 0.4), \
                IVORY
        if name == "Gold":
            return L.mix(C("8a5a18"), C("ffd860"), max(0.0, n.z) * 0.7 + 0.2), IVORY
        if name == "Ninja_Main" and (bone == "Middle1.L" or (co.y > 0.4 and co.z > 2.25)):
            # hilts: dark wrap with a diamond pattern
            return L.mix(C("1a1a22"), C("5a5060"), L.smooth(0.6, 0.9, math.sin(co.x * 40) * math.sin(co.z * 40))), IVORY
        if name == "Belt":
            if co.z > 0.5:  # the sash
                return L.mix(C("6a0c14"), C("c8283a"), max(0.0, -n.y) * 0.6 + 0.2), IVORY
            return C("2a2420")  # soles
        if name == "Ninja_Secondary":
            if bone == "Head":  # the face, now a cloth mask
                return L.mix(suit_lo, suit, 0.6 + 0.4 * max(0.0, n.z))
            # bandage wraps on hands and shins
            u = co.x * 9.0 + co.z * 14.0 if abs(co.x) > 1.0 else co.z * 22.0 + co.y * 6.0
            return L.mix(C("e8e2d6"), C("9a9488"), L.smooth(0.7, 0.95, math.sin(u))), IVORY
        c = L.mix(suit_lo, suit, L.smooth(-0.2, 0.7, n.z) * 0.6 + L.smooth(0.3, -0.6, n.y) * 0.4)
        c = L.mix(c, suit_hi, L.smooth(0.03, 0.09, info["bump"]) * 0.7)  # folds catch the light
        return c

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    slit_eyes(parts, surf, 0.27, 2.25, 0.3, 0.06, 0.6, C("ffffff"), C("e8f0ff"), head, band=C("0e0e14"))
    # a trailing scarf from the back of the neck
    for k, (dx, ln) in enumerate(((0.1, 1.1), (-0.12, 0.85))):
        base = Vector((dx, 0.5, 2.05))
        with parts.on(IVORY):
            parts.blob(base, (0.13, 0.03), Vector((dx * 2.0, 1.0, -0.55)).normalized(), ln, None,
                       weights={"Torso": 1.0}, seg=10, rings=8, tip=0.55, up=Vector((0, 0.5, 1)),
                       bend=Vector((0.15 * (1 - 2 * k), 0.1, -0.25)),
                       color_fn=lambda t: L.mix(C("8a1420"), C("d8344a"), t))
    with parts.on(IVORY):
        parts.ellipsoid(Vector((0.0, 0.42, 2.1)), (0.2, 0.1, 0.12), color=C("a81c2c"), weights={"Torso": 1.0}, seg=10,
                        rings=6)
    K.join_parts(body, parts.to_object())
    K.bake_ao(body)


# ---------------------------------------------------------------- big/Yeti

def yeti(arm, body):
    """yeti, yeti_king (icy blue boss) and crystal_yeti: a shaggy snow brute. Thick
    white fur in drooping clumps over the head, shoulders, back and arms, a dark
    blue-grey hide on the face, hands and feet, ram horns, icy glowing eyes under a
    shaggy brow, yellowed fangs in a roaring mouth, ice crystals on the shoulders
    (tinted: they turn deep blue on the king)."""
    L.delete_faces(body, ("Eye_White",), where=lambda c, n, g: n == "Eye_Black" and c.z > 2.15)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 3400)
    L.relax(body, 2, 0.4)
    fur_hi, fur, fur_lo = C("ffffff"), C("e6ecf2"), C("a8b4c4")
    hide_hi, hide = C("9ab0c8"), C("6a82a0")

    def paint(name, co, n, info):
        if name == "Yeti_Teeth":
            return L.mix(C("d8c898"), C("fffaf0"), 0.6), IVORY
        if name in ("Tongue", "Eye_Black"):
            return C("6a2034") if name == "Tongue" else C("1a0a14"), IVORY
        if name == "Yeti_Secondary" and info["bone"] not in ("Body", "Torso", "Abdomen"):
            c = L.mix(hide, hide_hi, max(0.0, n.z) * 0.5 + 0.2)
            return L.mix(c, C("2e3a4c"), L.smooth(0.6, 0.8, K.noise(co, 8.0, 2)) * 0.3), SKIN_HIDE
        c = L.mix(fur_lo, fur, L.smooth(-0.3, 0.6, n.z) * 0.6 + 0.3)
        c = L.mix(c, fur_hi, L.smooth(0.45, 0.75, K.fbm(co, 5.0, 8)) * 0.6)  # fur clumps
        return c, SKIN_FUR

    K.displace(body, 0.07, lambda co, n: 0.0 if co.z < 0.2 else L.smooth(0.45, 0.75, K.noise(co, 5.0, 8)))
    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    for sx in (-1.0, 1.0):
        c = Vector((0.29 * sx, -0.5, 2.3))
        gaze = Vector((0.25 * sx, -1.0, 0.0)).normalized()
        K.fierce_eye(parts, c, 0.105, gaze, sx, C("e8fbff"), C("3a9ae8"), head, lid=C("6a82a0"), open_=0.45,
                     glow_mat=IVORY_GLOW, pupil="dot", slant=0.4)
        # big lower fangs
        K.fang(parts, Vector((0.17 * sx, -0.6, 1.9)), Vector((0.15 * sx, -0.3, 1.0)), 0.22, 0.05, head,
               root=C("c8b888"))
        # ram horns curling back and down from the crown
        K.horn(parts, Vector((0.38 * sx, -0.12, 2.6)), Vector((0.85 * sx, 0.3, 0.55)).normalized(), 0.65, 0.14, head,
               C("5a5050"), C("e8dcc8"), bend=Vector((0.12 * sx, -0.05, -0.55)), rings_col=C("3a3030"), bands=6, seg=12,
               rings=10)
    # fur: shaggy fringes wherever the fur meets bare hide (face rim, wrists, ankles) ...
    for p, across, n in K.border_points(body, SKIN_FUR, SKIN_HIDE, 0.1):
        if p.y < -0.25 and 1.6 < p.z < 2.7 and abs(p.x) < 0.55:
            continue  # not over the face
        d = (across + n * 0.7 + Vector((0, 0, -0.35))).normalized()
        with parts.on(DETAIL):
            parts.blob(p - n * 0.03, (0.09, 0.045), d, 0.2, None, weights=p, seg=6, rings=3, tip=0.3, up=n,
                       color_fn=lambda t: L.mix(fur, fur_hi, t))
    # ... and spiky clumps breaking the silhouette over the crown, shoulders and back
    def bare(p, n):
        return p.y < -0.25 or p.z < 1.3 or abs(p.x) > 1.3
    K.tufts(parts, surf, Vector((0, 0.05, 1.6)), K.fibonacci(70), 0.24, 0.1, fur, fur_hi, seed=2, per=1,
            droop=0.55, lift_out=0.7, skip=bare, seg=6, rings=3, flat=0.5, tip=0.3, mat=DETAIL)
    for sx in (-1.0, 1.0):
        # shaggy brow over the eyes
        K.tufts(parts, surf, Vector((0.3 * sx, -0.2, 2.45)), [Vector((0.2 * sx, -1.0, 0.5)).normalized()], 0.2,
                0.07, fur, fur_hi, weights=head, seed=40, per=3, droop=0.7, lift_out=0.5, seg=6, rings=3,
                flat=0.45, tip=0.4, mat=DETAIL)
        # ice crystals on the shoulders (they take the tint)
        q, m = K.dir_hit(surf, Vector((0.7 * sx, 0.2, 1.9)), Vector((0.2 * sx, 0.4, 1.0)))
        if q is not None:
            for k in range(3):
                dd = (m + Vector((0.4 * sx * (k - 1), 0.3, 0.4))).normalized()
                K.crystal(parts, q - m * 0.02 + Vector((0.08 * sx * (k - 1), 0.05 * k, 0)), dd, 0.38 - 0.08 * abs(k - 1),
                          0.08, q, C("b8e4ff"), C("f4fcff"), mat=SKIN)
    K.join_parts(body, parts.to_object())
    K.merge_materials(body, {SKIN_FUR: SKIN, SKIN_HIDE: SKIN})
    K.bake_ao(body, strength=0.4, shade=Vector((0.62, 0.7, 0.86)))


RECIPES = {
    "big/Demon": demon,
    "big/BlueDemon": stone_golem,
    "big/Alien": swamp_beast,
    "big/Dino": sand_raptor,
    "big/Orc": forest_orc,
    "big/Orc_Skull": skull_orc,
    "big/Ninja": shadow_ninja,
    "big/Yeti": yeti,
}


def build(name):
    import bpy
    L.reset()
    arm, body = L.load(os.path.join(SRC, name + ".gltf"))
    clips = sorted(a.name for a in bpy.data.actions)
    before = L.tri_count(body)
    RECIPES[name](arm, body)
    out = os.path.join(OUT, name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    L.export(arm, body, out, clips)
    print("REMASTER %s tris %d -> %d, %d bytes, mats %s" % (name, before, L.tri_count(body), os.path.getsize(out),
                                                         ",".join(m.name for m in body.data.materials)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
